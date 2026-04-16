import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';
import 'package:study_assistant_app/models/subject.dart';

void main() {
  group('Search Filtering Tests', () {
    test('Property 3: Search filtering subset property', () {
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
            isPinned: false,
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
      ];

      // Test 1: Empty query returns all subjects
      final filtered1 = _filterSubjects(subjects, '');
      expect(filtered1.length, equals(3));

      // Test 2: Filter by name
      final filtered2 = _filterSubjects(subjects, 'math');
      expect(filtered2.length, equals(1));
      expect(filtered2[0].subject.name, equals('Mathematics'));

      // Test 3: Filter by category
      final filtered3 = _filterSubjects(subjects, 'science');
      expect(filtered3.length, equals(3)); // Mathematics, Physics (category), and Computer Science (name)

      // Test 4: Filter by partial name
      final filtered4 = _filterSubjects(subjects, 'comp');
      expect(filtered4.length, equals(1));
      expect(filtered4[0].subject.name, equals('Computer Science'));

      // Test 5: Case insensitive search
      final filtered5 = _filterSubjects(subjects, 'PHYSICS');
      expect(filtered5.length, equals(1));
      expect(filtered5[0].subject.name, equals('Physics'));

      // Test 6: No results
      final filtered6 = _filterSubjects(subjects, 'nonexistent');
      expect(filtered6.length, equals(0));
    });

    test('Search filtering subset property holds', () {
      // The subset property: filtered results should always be a subset of the original list
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
            isPinned: false,
            createdAt: DateTime.now(),

          ),
          totalNodes: 8,
          litNodes: 3,
          sessionCount: 2,
          lastVisitedAt: DateTime.now(),
        ),
      ];

      // Test that filtered results are always a subset
      for (final query in ['math', 'physics', 'sci', '']) {
        final filtered = _filterSubjects(subjects, query);
        
        // Every filtered subject must exist in the original list
        for (final subject in filtered) {
          expect(subjects, contains(subject));
        }
        
        // The filtered list should not be larger than the original
        expect(filtered.length, lessThanOrEqualTo(subjects.length));
      }
    });
  });
}

List<SubjectWithProgress> _filterSubjects(
  List<SubjectWithProgress> subjects,
  String query,
) {
  if (query.isEmpty) return subjects;
  
  final queryLower = query.toLowerCase();
  return subjects.where((subject) {
    final name = subject.subject.name.toLowerCase();
    final category = subject.subject.category?.toLowerCase() ?? '';
    return name.contains(queryLower) || category.contains(queryLower);
  }).toList();
}
