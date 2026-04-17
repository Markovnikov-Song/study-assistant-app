import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/tools/document/block_converter.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  group('BlockConverter Tests', () {
    test('Property 11: Lecture content round-trip consistency - Test 1', () {
      // Test data: various lecture blocks
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

      // Debug output
      // print('Test 1 - Original blocks: ${blocks.length}');
      // print('Test 1 - Round trip blocks: ${roundTripBlocks.length}');
      
      // Verify the round-trip
      expect(roundTripBlocks.length, equals(blocks.length));
      
      // Check that all blocks have the same type and text
      for (int i = 0; i < blocks.length; i++) {
        expect(roundTripBlocks[i].type, equals(blocks[i].type));
        expect(roundTripBlocks[i].text, equals(blocks[i].text));
        expect(roundTripBlocks[i].source, equals(blocks[i].source));
      }
    });

    test('Property 11: Lecture content round-trip consistency - Test 2', () {
      // Create a complex lecture with various block types
      final blocks = [
        LectureBlock(
          id: '1',
          type: 'heading',
          text: 'Introduction to Programming',
          level: 1,
          source: 'ai',
        ),
        LectureBlock(
          id: '2',
          type: 'paragraph',
          text: 'Programming is the process of creating a set of instructions that tell a computer how to perform a task.',
          source: 'ai',
        ),
        LectureBlock(
          id: '3',
          type: 'code',
          text: 'def hello_world():\n    print("Hello, World!")',
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
          text: 'The only way to learn a new programming language is by writing programs in it.',
          source: 'ai',
        ),
      ];

      // Convert to Quill Delta
      final delta = BlockConverter.blocksToQuillDelta(blocks);
      
      // Convert back to blocks
      final roundTripBlocks = BlockConverter.quillDeltaToBlocks(
        delta,
        existingBlocks: blocks,
      );

      // Debug output
      // print('Test 2 - Original blocks: ${blocks.length}');
      // print('Test 2 - Round trip blocks: ${roundTripBlocks.length}');
      
      // Verify the round-trip
      expect(roundTripBlocks.length, equals(blocks.length));
      
      for (int i = 0; i < blocks.length; i++) {
        expect(roundTripBlocks[i].type, equals(blocks[i].type));
        expect(roundTripBlocks[i].text, equals(blocks[i].text));
        expect(roundTripBlocks[i].source, equals(blocks[i].source));
      }
    });

    test('BlockConverter handles empty blocks', () {
      final blocks = <LectureBlock>[];
      final delta = BlockConverter.blocksToQuillDelta(blocks);
      final roundTripBlocks = BlockConverter.quillDeltaToBlocks(delta);
      
      expect(roundTripBlocks, isEmpty);
    });

    test('BlockConverter preserves text with special characters', () {
      final blocks = [
        LectureBlock(
          id: '1',
          type: 'paragraph',
          text: 'Special characters: & < > " \' &amp; &lt; &gt;',
          source: 'ai',
        ),
      ];

      final delta = BlockConverter.blocksToQuillDelta(blocks);
      final roundTripBlocks = BlockConverter.quillDeltaToBlocks(delta);
      
      expect(roundTripBlocks.length, equals(1));
      expect(roundTripBlocks[0].text, equals(blocks[0].text));
    });
  });
}