import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/tools/document/block_converter.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  test('BlockConverter with five blocks', () {
    final blocks = [
      LectureBlock(
        id: '1',
        type: 'heading',
        text: 'Introduction',
        level: 1,
        source: 'ai',
      ),
      LectureBlock(
        id: '2',
        type: 'paragraph',
        text: 'This is a paragraph with some text.',
        source: 'ai',
        spans: [
          LectureSpan(
            start: 0,
            end: 4,
            bold: true,
            italic: false,
            code: false,
          ),
        ],
      ),
      LectureBlock(
        id: '3',
        type: 'code',
        text: 'print("Hello, World!")',
        language: 'python',
        source: 'ai',
      ),
      LectureBlock(
        id: '4',
        type: 'list',
        text: 'First item in the list',
        source: 'ai',
      ),
      LectureBlock(
        id: '5',
        type: 'quote',
        text: 'This is a quote',
        source: 'ai',
      ),
    ];

    // Convert blocks to Quill Delta
    final delta = BlockConverter.blocksToQuillDelta(blocks);
    
    // Convert back to blocks
    final roundTripBlocks = BlockConverter.quillDeltaToBlocks(
      delta,
      existingBlocks: blocks,
    );

      // print('Original blocks: ${blocks.length}');
      // print('Round trip blocks: ${roundTripBlocks.length}');
    
    for (int i = 0; i < roundTripBlocks.length; i++) {
      // print('Block $i: type=${roundTripBlocks[i].type}, text="${roundTripBlocks[i].text}"');
    }
    
    expect(roundTripBlocks.length, equals(blocks.length));
  });
}
