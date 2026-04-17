import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/tools/document/block_converter.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  test('Debug code block with newline', () {
    final blocks = [
      LectureBlock(
        id: '1',
        type: 'code',
        text: 'def hello_world():\n    print("Hello, World!")',
        language: 'python',
        source: 'ai',
      ),
    ];

    // Convert blocks to Quill Delta
    final delta = BlockConverter.blocksToQuillDelta(blocks);
    
    // ignore: unused_local_variable
    final ops = delta.toJson() as List<dynamic>;
    
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
