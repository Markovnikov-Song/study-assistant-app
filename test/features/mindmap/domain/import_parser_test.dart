import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/mindmap/domain/import_parser.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Build a minimal XMind ZIP with the given content.xml text.
Uint8List _buildXMindZip(String contentXml) {
  final archive = Archive();
  final bytes = utf8.encode(contentXml);
  archive.addFile(ArchiveFile('content.xml', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Flatten a tree into a pre-order list.
List<TreeNode> _flatten(List<TreeNode> roots) {
  final result = <TreeNode>[];
  void visit(TreeNode n) {
    result.add(n);
    for (final c in n.children) {
      visit(c);
    }
  }

  for (final r in roots) {
    visit(r);
  }
  return result;
}

// ── parseMarkdown ─────────────────────────────────────────────────────────────

void main() {
  group('ImportParser.parseMarkdown', () {
    test('parses heading levels correctly', () {
      const md = '''
# Root
## Child A
### Grandchild
## Child B
''';
      final result = ImportParser.parseMarkdown(md);
      expect(result, isA<ImportSuccess>());
      final roots = (result as ImportSuccess).roots;

      expect(roots.length, 1);
      expect(roots[0].text, 'Root');
      expect(roots[0].depth, 1);

      expect(roots[0].children.length, 2);
      expect(roots[0].children[0].text, 'Child A');
      expect(roots[0].children[0].depth, 2);

      expect(roots[0].children[0].children.length, 1);
      expect(roots[0].children[0].children[0].text, 'Grandchild');
      expect(roots[0].children[0].children[0].depth, 3);

      expect(roots[0].children[1].text, 'Child B');
      expect(roots[0].children[1].depth, 2);
    });

    test('parses list items with indentation', () {
      const md = '''
- Item A
  - Item B
    - Item C
- Item D
''';
      final result = ImportParser.parseMarkdown(md);
      expect(result, isA<ImportSuccess>());
      final roots = (result as ImportSuccess).roots;

      expect(roots.length, 2);
      expect(roots[0].text, 'Item A');
      expect(roots[0].depth, 1);
      expect(roots[0].children[0].text, 'Item B');
      expect(roots[0].children[0].depth, 2);
      expect(roots[0].children[0].children[0].text, 'Item C');
      expect(roots[0].children[0].children[0].depth, 3);
      expect(roots[1].text, 'Item D');
    });

    test('parses * list items', () {
      const md = '* Alpha\n* Beta\n';
      final result = ImportParser.parseMarkdown(md);
      expect(result, isA<ImportSuccess>());
      final roots = (result as ImportSuccess).roots;
      expect(roots.length, 2);
      expect(roots[0].text, 'Alpha');
    });

    test('returns noStructure error for plain text with no structure', () {
      const md = 'Just some plain text without any headings or lists.';
      final result = ImportParser.parseMarkdown(md);
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.noStructure);
    });

    test('returns noStructure error for empty string', () {
      final result = ImportParser.parseMarkdown('');
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.noStructure);
    });

    test('returns noStructure error for whitespace-only string', () {
      final result = ImportParser.parseMarkdown('   \n\n  \t  \n');
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.noStructure);
    });

    test('truncates node text to 200 characters', () {
      final longText = 'A' * 250;
      final md = '# $longText';
      final result = ImportParser.parseMarkdown(md);
      expect(result, isA<ImportSuccess>());
      final roots = (result as ImportSuccess).roots;
      expect(roots[0].text.length, 200);
    });

    test('all nodes have unique nodeIds', () {
      const md = '# A\n## B\n## C\n### D\n';
      final result = ImportParser.parseMarkdown(md);
      final nodes = _flatten((result as ImportSuccess).roots);
      final ids = nodes.map((n) => n.nodeId).toSet();
      expect(ids.length, nodes.length);
    });

    test('depth mapping: # count equals node depth', () {
      const md = '# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6\n';
      final result = ImportParser.parseMarkdown(md);
      final nodes = _flatten((result as ImportSuccess).roots);
      expect(nodes[0].depth, 1);
      expect(nodes[1].depth, 2);
      expect(nodes[2].depth, 3);
      expect(nodes[3].depth, 4);
      expect(nodes[4].depth, 5);
      expect(nodes[5].depth, 6);
    });
  });

  // ── parseXMind ─────────────────────────────────────────────────────────────

  group('ImportParser.parseXMind', () {
    test('parses a valid XMind ZIP correctly', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<xmap-content>
  <sheet>
    <topic id="root">
      <title>Root Topic</title>
      <children>
        <topics type="attached">
          <topic id="c1">
            <title>Child 1</title>
          </topic>
          <topic id="c2">
            <title>Child 2</title>
            <children>
              <topics type="attached">
                <topic id="gc1">
                  <title>Grandchild</title>
                </topic>
              </topics>
            </children>
          </topic>
        </topics>
      </children>
    </topic>
  </sheet>
</xmap-content>''';

      final bytes = _buildXMindZip(xml);
      final result = ImportParser.parseXMind(bytes);

      expect(result, isA<ImportSuccess>());
      final roots = (result as ImportSuccess).roots;
      expect(roots.length, 1);
      expect(roots[0].text, 'Root Topic');
      expect(roots[0].depth, 1);
      expect(roots[0].children.length, 2);
      expect(roots[0].children[0].text, 'Child 1');
      expect(roots[0].children[1].text, 'Child 2');
      expect(roots[0].children[1].children[0].text, 'Grandchild');
    });

    test('returns parseFailure for corrupted ZIP bytes', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final result = ImportParser.parseXMind(bytes);
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.parseFailure);
    });

    test('returns parseFailure when content.xml is missing', () {
      final archive = Archive();
      final bytes = Uint8List.fromList([]);
      archive.addFile(ArchiveFile('other.xml', bytes.length, bytes));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final result = ImportParser.parseXMind(zipBytes);
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.parseFailure);
    });

    test('truncates long node text to 200 characters', () {
      final longTitle = 'X' * 300;
      final xml = '''<?xml version="1.0"?>
<xmap-content>
  <sheet>
    <topic id="r">
      <title>$longTitle</title>
    </topic>
  </sheet>
</xmap-content>''';
      final bytes = _buildXMindZip(xml);
      final result = ImportParser.parseXMind(bytes);
      expect(result, isA<ImportSuccess>());
      expect((result as ImportSuccess).roots[0].text.length, 200);
    });
  });

  // ── parseFreeMind ──────────────────────────────────────────────────────────

  group('ImportParser.parseFreeMind', () {
    test('parses a valid FreeMind .mm file', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.0.1">
  <node TEXT="Root">
    <node TEXT="Child A">
      <node TEXT="Grandchild" />
    </node>
    <node TEXT="Child B" />
  </node>
</map>''';

      final result = ImportParser.parseFreeMind(xml);
      expect(result, isA<ImportSuccess>());
      final roots = (result as ImportSuccess).roots;
      expect(roots.length, 1);
      expect(roots[0].text, 'Root');
      expect(roots[0].depth, 1);
      expect(roots[0].children.length, 2);
      expect(roots[0].children[0].text, 'Child A');
      expect(roots[0].children[0].children[0].text, 'Grandchild');
      expect(roots[0].children[1].text, 'Child B');
    });

    test('returns parseFailure for invalid XML', () {
      const xml = 'this is not xml <<< broken';
      final result = ImportParser.parseFreeMind(xml);
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.parseFailure);
    });

    test('returns parseFailure when no <map> element found', () {
      const xml = '<?xml version="1.0"?><root><node TEXT="A"/></root>';
      final result = ImportParser.parseFreeMind(xml);
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.parseFailure);
    });

    test('truncates long node text to 200 characters', () {
      final longText = 'Y' * 300;
      final xml = '<?xml version="1.0"?><map><node TEXT="$longText"/></map>';
      final result = ImportParser.parseFreeMind(xml);
      expect(result, isA<ImportSuccess>());
      expect((result as ImportSuccess).roots[0].text.length, 200);
    });
  });

  // ── parseFile ──────────────────────────────────────────────────────────────

  group('ImportParser.parseFile', () {
    test('dispatches .xmind extension to parseXMind', () {
      const xml = '''<?xml version="1.0"?>
<xmap-content>
  <sheet>
    <topic id="r"><title>Root</title></topic>
  </sheet>
</xmap-content>''';
      final bytes = _buildXMindZip(xml);
      final result = ImportParser.parseFile(bytes, 'my_map.xmind');
      expect(result, isA<ImportSuccess>());
    });

    test('dispatches .mm extension to parseFreeMind', () {
      const xml = '<?xml version="1.0"?><map><node TEXT="Root"/></map>';
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final result = ImportParser.parseFile(bytes, 'my_map.mm');
      expect(result, isA<ImportSuccess>());
    });

    test('returns unsupportedFormat for unknown extension', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = ImportParser.parseFile(bytes, 'document.pdf');
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.unsupportedFormat);
    });

    test('returns unsupportedFormat for .txt extension', () {
      final bytes = Uint8List.fromList(utf8.encode('# Hello'));
      final result = ImportParser.parseFile(bytes, 'notes.txt');
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.unsupportedFormat);
    });

    test('extension matching is case-insensitive', () {
      const xml = '<?xml version="1.0"?><map><node TEXT="Root"/></map>';
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final result = ImportParser.parseFile(bytes, 'my_map.MM');
      expect(result, isA<ImportSuccess>());
    });
  });

  // ── parseOcrLines ──────────────────────────────────────────────────────────

  group('ImportParser.parseOcrLines', () {
    test('converts OcrLines to TreeNodes with correct depth', () {
      final lines = [
        OcrLine(text: 'Root', confidence: 0.9, indentLevel: 0),
        OcrLine(text: 'Child', confidence: 0.8, indentLevel: 1),
        OcrLine(text: 'Grandchild', confidence: 0.7, indentLevel: 2),
      ];

      final result = ImportParser.parseOcrLines(lines);
      expect(result, isA<ImportSuccess>());
      final roots = (result as ImportSuccess).roots;

      expect(roots.length, 1);
      expect(roots[0].text, 'Root');
      expect(roots[0].depth, 1);
      expect(roots[0].children[0].text, 'Child');
      expect(roots[0].children[0].depth, 2);
      expect(roots[0].children[0].children[0].text, 'Grandchild');
      expect(roots[0].children[0].children[0].depth, 3);
    });

    test('skips lines where isSelected == false', () {
      final lines = [
        OcrLine(text: 'Visible', confidence: 0.9, indentLevel: 0, isSelected: true),
        OcrLine(text: 'Hidden', confidence: 0.8, indentLevel: 1, isSelected: false),
        OcrLine(text: 'Also Visible', confidence: 0.7, indentLevel: 0, isSelected: true),
      ];

      final result = ImportParser.parseOcrLines(lines);
      expect(result, isA<ImportSuccess>());
      final nodes = _flatten((result as ImportSuccess).roots);
      expect(nodes.length, 2);
      expect(nodes.any((n) => n.text == 'Hidden'), isFalse);
    });

    test('skips lines with empty text', () {
      final lines = [
        OcrLine(text: 'Valid', confidence: 0.9, indentLevel: 0),
        OcrLine(text: '   ', confidence: 0.8, indentLevel: 0),
        OcrLine(text: '', confidence: 0.7, indentLevel: 0),
      ];

      final result = ImportParser.parseOcrLines(lines);
      expect(result, isA<ImportSuccess>());
      final nodes = _flatten((result as ImportSuccess).roots);
      expect(nodes.length, 1);
      expect(nodes[0].text, 'Valid');
    });

    test('returns noStructure when all lines are deselected', () {
      final lines = [
        OcrLine(text: 'A', confidence: 0.9, indentLevel: 0, isSelected: false),
        OcrLine(text: 'B', confidence: 0.8, indentLevel: 0, isSelected: false),
      ];

      final result = ImportParser.parseOcrLines(lines);
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.noStructure);
    });

    test('returns noStructure for empty list', () {
      final result = ImportParser.parseOcrLines([]);
      expect(result, isA<ImportError>());
      expect((result as ImportError).type, ImportErrorType.noStructure);
    });

    test('truncates long text to 200 characters', () {
      final lines = [
        OcrLine(text: 'Z' * 300, confidence: 0.9, indentLevel: 0),
      ];
      final result = ImportParser.parseOcrLines(lines);
      expect(result, isA<ImportSuccess>());
      expect((result as ImportSuccess).roots[0].text.length, 200);
    });

    test('indentLevel 0 maps to depth 1', () {
      final lines = [
        OcrLine(text: 'A', confidence: 0.9, indentLevel: 0),
      ];
      final result = ImportParser.parseOcrLines(lines);
      expect((result as ImportSuccess).roots[0].depth, 1);
    });
  });
}
