import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/library/lecture/block_converter.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  test('Simple BlockConverter test', () {
    // Simple test with one block
    final blocks = [
      LectureBlock(
        id: '1',
        type: 'heading',
        text: 'Introduction',
        level: 1,
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
    
    // Print block details
    for (int i = 0; i < roundTripBlocks.length; i++) {
      // print('Block $i: type=${roundTripBlocks[i].type}, text="${roundTripBlocks[i].text}"');
    }

    // Verify the round-trip
    expect(roundTripBlocks.length, equals(blocks.length));
  });
}
