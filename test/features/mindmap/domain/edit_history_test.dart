import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/mindmap/domain/edit_history.dart';

void main() {
  group('EditHistory', () {
    test('initial state cannot undo or redo', () {
      final history = EditHistory();

      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });

    test('push enables undo and clears redo', () {
      final history = EditHistory();

      history.push('s0');
      history.push('s1');

      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });

    test('undo and redo return expected snapshots', () {
      final history = EditHistory();
      history.push('s0');
      history.push('s1');

      expect(history.undo('s2'), 's1');
      expect(history.canRedo, isTrue);
      expect(history.redo('s1'), 's2');
    });

    test('undo returns null when stack is empty', () {
      final history = EditHistory();
      expect(history.undo('current'), isNull);
    });

    test('redo returns null when stack is empty', () {
      final history = EditHistory();
      expect(history.redo('current'), isNull);
    });

    test('keeps at most 50 undo snapshots', () {
      final history = EditHistory();
      for (var i = 0; i < 60; i++) {
        history.push('s$i');
      }

      var count = 0;
      var current = 'latest';
      while (history.canUndo) {
        current = history.undo(current) ?? current;
        count += 1;
      }

      expect(count, 50);
    });
  });
}
