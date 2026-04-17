import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../../../models/mindmap_library.dart';

// ── Return types ─────────────────────────────────────────────────────────────

sealed class ImportResult {}

class ImportSuccess extends ImportResult {
  final List<TreeNode> roots;
  ImportSuccess(this.roots);
}

class ImportError extends ImportResult {
  final ImportErrorType type;
  final String message;
  ImportError(this.type, this.message);
}

enum ImportErrorType { unsupportedFormat, parseFailure, noStructure }

// ── OcrLine ───────────────────────────────────────────────────────────────────

class OcrLine {
  final String text;
  final double confidence;
  int indentLevel; // 0-based, adjustable by user
  bool isSelected;

  OcrLine({
    required this.text,
    required this.confidence,
    this.indentLevel = 0,
    this.isSelected = true,
  });
}

// ── ImportParser ──────────────────────────────────────────────────────────────

/// Parses various import formats into a [List<TreeNode>].
///
/// Requirements: 7.1–7.7, 8.1–8.4, 9.4
class ImportParser {
  static const _uuid = Uuid();
  static const int _maxTextLength = 200;

  static String _truncate(String text) =>
      text.length > _maxTextLength ? text.substring(0, _maxTextLength) : text;

  // ── 5.1 parseMarkdown ─────────────────────────────────────────────────────

  /// Parse a Markdown outline (headings + list items) into a [List<TreeNode>].
  ///
  /// - `#` → depth 1, `##` → depth 2, … up to 6 levels
  /// - `-` / `*` list items: indent level inferred from leading spaces
  ///   (every 2 spaces = 1 level), depth = indent_level + 1 (min 1)
  /// - Returns [ImportError.noStructure] when no recognisable structure found.
  ///
  /// Requirements: 8.1–8.4
  static ImportResult parseMarkdown(String text) {
    final lines = text.split('\n');

    // Each entry: (depth, text)
    final items = <({int depth, String nodeText})>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;

      // Heading: starts with one or more '#' followed by a space
      final headingMatch = RegExp(r'^(#{1,6}) (.+)$').firstMatch(line);
      if (headingMatch != null) {
        final depth = headingMatch.group(1)!.length;
        final nodeText = headingMatch.group(2)!.trim();
        if (nodeText.isNotEmpty) {
          items.add((depth: depth, nodeText: _truncate(nodeText)));
        }
        continue;
      }

      // List item: optional leading spaces + '-' or '*' + space + text
      final listMatch = RegExp(r'^( *)[-*] (.+)$').firstMatch(line);
      if (listMatch != null) {
        final spaces = listMatch.group(1)!.length;
        final indentLevel = spaces ~/ 2;
        final depth = indentLevel + 1;
        final nodeText = listMatch.group(2)!.trim();
        if (nodeText.isNotEmpty) {
          items.add((depth: depth, nodeText: _truncate(nodeText)));
        }
        continue;
      }
    }

    if (items.isEmpty) {
      return ImportError(
        ImportErrorType.noStructure,
        '未识别到有效的大纲结构，请使用 # 标题或 - 列表格式',
      );
    }

    return ImportSuccess(_buildTreeFromDepthItems(items));
  }

  // ── 5.4 parseXMind ────────────────────────────────────────────────────────

  /// Parse an XMind file (ZIP containing content.xml).
  ///
  /// Requirements: 7.2, 7.6
  static ImportResult parseXMind(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final contentFile = archive.files.firstWhere(
        (f) => f.name == 'content.xml',
        orElse: () => throw const FormatException('content.xml not found'),
      );

      final xmlText = String.fromCharCodes(contentFile.content as List<int>);
      final doc = XmlDocument.parse(xmlText);

      // Find first <sheet> element
      final sheet = doc.findAllElements('sheet').firstOrNull;
      if (sheet == null) {
        return ImportError(
          ImportErrorType.parseFailure,
          '文件解析失败：未找到工作表',
        );
      }

      // First direct <topic> child of <sheet>
      final rootTopic = sheet.findElements('topic').firstOrNull;
      if (rootTopic == null) {
        return ImportError(
          ImportErrorType.parseFailure,
          '文件解析失败：未找到根节点',
        );
      }

      final roots = [_parseXMindTopic(rootTopic, depth: 1, parentId: null)];
      return ImportSuccess(roots);
    } on FormatException catch (e) {
      return ImportError(ImportErrorType.parseFailure, '文件解析失败：${e.message}');
    } catch (_) {
      return ImportError(ImportErrorType.parseFailure, '文件解析失败，请检查文件是否完整');
    }
  }

  static TreeNode _parseXMindTopic(
    XmlElement topic, {
    required int depth,
    required String? parentId,
  }) {
    final nodeId = _uuid.v4();
    final titleEl = topic.findElements('title').firstOrNull;
    final rawText = titleEl?.innerText.trim() ?? '';
    final text = _truncate(rawText.isEmpty ? '(无标题)' : rawText);

    final children = <TreeNode>[];

    // children > topics[type=attached] > topic
    for (final childrenEl in topic.findElements('children')) {
      for (final topicsEl in childrenEl.findElements('topics')) {
        for (final childTopic in topicsEl.findElements('topic')) {
          if (depth < 6) {
            children.add(_parseXMindTopic(
              childTopic,
              depth: depth + 1,
              parentId: nodeId,
            ));
          }
        }
      }
    }

    return TreeNode(
      nodeId: nodeId,
      text: text,
      depth: depth,
      parentId: parentId,
      isUserCreated: false,
      children: children,
    );
  }

  // ── 5.5 parseFreeMind ─────────────────────────────────────────────────────

  /// Parse a FreeMind `.mm` XML file.
  ///
  /// Root element: `<map>`, nodes: `<node TEXT="...">` recursively nested.
  ///
  /// Requirements: 7.3, 7.6
  static ImportResult parseFreeMind(String xmlText) {
    try {
      final doc = XmlDocument.parse(xmlText);
      final mapEl = doc.findElements('map').firstOrNull;
      if (mapEl == null) {
        return ImportError(ImportErrorType.parseFailure, '文件解析失败：未找到 <map> 根元素');
      }

      final rootNodes = mapEl.findElements('node').toList();
      if (rootNodes.isEmpty) {
        return ImportError(ImportErrorType.parseFailure, '文件解析失败：未找到任何节点');
      }

      final roots = rootNodes
          .map((n) => _parseFreeMindNode(n, depth: 1, parentId: null))
          .toList();

      return ImportSuccess(roots);
    } catch (_) {
      return ImportError(ImportErrorType.parseFailure, '文件解析失败，请检查文件是否完整');
    }
  }

  static TreeNode _parseFreeMindNode(
    XmlElement node, {
    required int depth,
    required String? parentId,
  }) {
    final nodeId = _uuid.v4();
    final rawText = node.getAttribute('TEXT') ?? '';
    final text = _truncate(rawText.trim().isEmpty ? '(无标题)' : rawText.trim());

    final children = <TreeNode>[];
    if (depth < 6) {
      for (final child in node.findElements('node')) {
        children.add(_parseFreeMindNode(child, depth: depth + 1, parentId: nodeId));
      }
    }

    return TreeNode(
      nodeId: nodeId,
      text: text,
      depth: depth,
      parentId: parentId,
      isUserCreated: false,
      children: children,
    );
  }

  // ── 5.6 parseFile ─────────────────────────────────────────────────────────

  /// Dispatch to the appropriate parser based on file extension.
  ///
  /// - `.xmind` → [parseXMind]
  /// - `.mm`    → [parseFreeMind]
  /// - other    → [ImportError.unsupportedFormat]
  ///
  /// Requirements: 7.1, 7.5, 7.7
  static ImportResult parseFile(Uint8List bytes, String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.xmind')) {
      return parseXMind(bytes);
    } else if (lower.endsWith('.mm')) {
      final xmlText = String.fromCharCodes(bytes);
      return parseFreeMind(xmlText);
    } else {
      return ImportError(
        ImportErrorType.unsupportedFormat,
        '不支持该文件格式，请选择 .xmind 或 .mm 文件',
      );
    }
  }

  // ── 5.9 parseOcrLines ─────────────────────────────────────────────────────

  /// Convert a list of [OcrLine] (with [OcrLine.indentLevel]) into a
  /// [List<TreeNode>].
  ///
  /// - Only processes lines where [OcrLine.isSelected] == true
  /// - Skips lines with empty text
  /// - indentLevel 0 → depth 1, 1 → depth 2, …
  ///
  /// Requirements: 9.4
  static ImportResult parseOcrLines(List<OcrLine> lines) {
    final items = <({int depth, String nodeText})>[];

    for (final line in lines) {
      if (!line.isSelected) continue;
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final depth = (line.indentLevel + 1).clamp(1, 6);
      items.add((depth: depth, nodeText: _truncate(text)));
    }

    if (items.isEmpty) {
      return ImportError(
        ImportErrorType.noStructure,
        '未识别到有效的大纲结构',
      );
    }

    return ImportSuccess(_buildTreeFromDepthItems(items));
  }

  // ── Shared tree builder ───────────────────────────────────────────────────

  /// Build a [List<TreeNode>] from a flat list of (depth, text) items,
  /// using a parent-stack approach.
  static List<TreeNode> _buildTreeFromDepthItems(
    List<({int depth, String nodeText})> items,
  ) {
    final roots = <TreeNode>[];
    // Stack entries: (depth, nodeId, children list)
    final stack = <({int depth, String nodeId, List<TreeNode> children})>[];

    for (final item in items) {
      final nodeId = _uuid.v4();
      final children = <TreeNode>[];

      // Pop stack until we find a parent with depth < item.depth
      while (stack.isNotEmpty && stack.last.depth >= item.depth) {
        stack.removeLast();
      }

      final parentId = stack.isNotEmpty ? stack.last.nodeId : null;

      final node = TreeNode(
        nodeId: nodeId,
        text: item.nodeText,
        depth: item.depth,
        parentId: parentId,
        isUserCreated: false,
        children: children,
      );

      if (parentId == null) {
        roots.add(node);
      } else {
        stack.last.children.add(node);
      }

      stack.add((depth: item.depth, nodeId: nodeId, children: children));
    }

    return roots;
  }
}
