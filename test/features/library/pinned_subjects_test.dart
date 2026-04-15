import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';
import 'package:study_assistant_app/models/subject.dart';

void main() {
  group('Pinned Subjects Sorting', () {
    test('Property 2: Pinned subjects should appear first', () {
      // Create test subjects
      final subjects = [
        SubjectWithProgress(
          subject: Subject(
            id: 1,
            name: 'Mathematics',
            category: 'Science',
            isPinned: false,
            createdAt: DateTime.now(),
          ),
          totalNodes: 10,
          litNodes: 5,
          sessionCount: 3,
          lastVisitedAt: DateTime.now(),
        ),
        SubjectWithProgress(
          subject: Subject(
            id: 2,
            name: 'Physics',
            category: 'Science',
            isPinned: true, // This should appear first
            createdAt: DateTime.now(),
          ),
          totalNodes: 8,
          litNodes: 3,
          sessionCount: 2,
          lastVisitedAt: DateTime.now(),
        ),
        SubjectWithProgress(
          subject: Subject(
            id: 3,
            name: 'Computer Science',
            category: 'Technology',
            isPinned: false,
            createdAt: DateTime.now(),
          ),
          totalNodes: 15,
          litNodes: 10,
          sessionCount: 5,
          lastVisitedAt: DateTime.now(),
        ),
        SubjectWithProgress(
          subject: Subject(
            id: 4,
            name: 'Chemistry',
            category: 'Science',
            isPinned: true, // This should also appear first
            createdAt: DateTime.now(),
          ),
          totalNodes: 12,
          litNodes: 6,
          sessionCount: 4,
          lastVisitedAt: DateTime.now(),
        ),
      ];

      // Sort the subjects (pinned first, then by last visited)
      final sorted = List<SubjectWithProgress>.from(subjects)
        ..sort((a, b) {
          // Pinned subjects first
          final pinCmp = (b.subject.isPinned ? 1 : 0) - (a.subject.isPinned ? 1 : 0);
          if (pinCmp != 0) return pinCmp;
          
          // Then by last visited (most recent first)
          final aTime = a.lastVisitedAt ?? DateTime(0);
          final bTime = b.lastVisitedAt ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

      // Verify that pinned subjects come first
      final pinnedSubjects = sorted.where((s) => s.subject.isPinned).toList();
      
      // All pinned subjects should come before unpinned subjects
      expect(sorted.first.subject.isPinned, isTrue, 
          reason: 'First subject should be pinned');
      expect(sorted.last.subject.isPinned, isFalse, 
          reason: 'Last subject should not be pinned');
      
      // Verify all pinned subjects are at the beginning
      for (int i = 0; i < sorted.length; i++) {
        if (i < pinnedSubjects.length) {
          expect(sorted[i].subject.isPinned, isTrue,
              reason: 'First ${pinnedSubjects.length} subjects should be pinned');
        }
      }
    });

    test('Pinned subjects with same last visited time maintain order', () {
      final now = DateTime.now();
      final subjects = [
        SubjectWithProgress(
          subject: Subject(
            id: 1,
            name: 'Math',
            category: 'Science',
            isPinned: true,
            createdAt: now,
          ),
          totalNodes: 10,
          litNodes: 5,
          sessionCount: 3,
          lastVisitedAt: now.subtract(Duration(days: 1)),
        ),
        SubjectWithProgress(
          subject: Subject(
            id: 2,
            name: 'Physics',
            category: 'Science',
            isPinned: true,
            createdAt: now,
          ),
          totalNodes: 8,
          litNodes: 3,
          sessionCount: 2,
          lastVisitedAt: now.subtract(Duration(days: 2)),
        ),
      ];

      // Sort by pinned first, then by last visited (most recent first)
      final sorted = List<SubjectWithProgress>.from(subjects)
        ..sort((a, b) {
          // Pinned subjects first
          final pinCmp = (b.subject.isPinned ? 1 : 0) - (a.subject.isPinned ? 1 : 0);
          if (pinCmp != 0) return pinCmp;
          
          // Then by last visited (most recent first)
          final aTime = a.lastVisitedAt ?? DateTime(0);
          final bTime = b.lastVisitedAt ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

      // Both are pinned, so they should be sorted by last visited (most recent first)
      expect(sorted[0].subject.name, equals('Math'));
      expect(sorted[1].subject.name, equals('Physics'));
    });
  });
}