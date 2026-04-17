import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/mindmap_library.dart';

/// Handles exporting a mind-map tree to Markdown text or PNG image.
///
/// Requirements: 11.1–11.3
class ExportService {
  // ── 6.1 toMarkdown ────────────────────────────────────────────────────────

  /// Serialize [roots] to a Markdown heading-outline string.
  ///
  /// Each node produces one line: `'#' * depth + ' ' + node.text`.
  /// Traversal is pre-order (parent before children).
  ///
  /// Requirements: 11.1, 11.2
  static String toMarkdown(List<TreeNode> roots) {
    final buffer = StringBuffer();
    _writeNodes(roots, buffer);
    return buffer.toString();
  }

  static void _writeNodes(List<TreeNode> nodes, StringBuffer buffer) {
    for (final node in nodes) {
      buffer.write('#' * node.depth);
      buffer.write(' ');
      buffer.writeln(node.text);
      if (node.children.isNotEmpty) {
        _writeNodes(node.children, buffer);
      }
    }
  }

  // ── 6.3 toPng ─────────────────────────────────────────────────────────────

  /// Capture the widget identified by [repaintKey] as a PNG [Uint8List].
  ///
  /// The widget must be wrapped in a [RepaintBoundary] with the given key.
  ///
  /// Requirements: 11.3
  static Future<Uint8List> toPng(GlobalKey repaintKey) async {
    final boundary = repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('RepaintBoundary not found');
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ── 6.4 shareMarkdown / savePng ───────────────────────────────────────────

  /// Share [content] via the system share sheet.
  ///
  /// Requirements: 11.2
  static Future<void> shareMarkdown(String content, String filename) async {
    await Share.share(content, subject: filename);
  }

  /// Save [bytes] as a PNG file in the application documents directory.
  ///
  /// Requirements: 11.3
  static Future<void> savePng(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
  }
}
