// Learning OS — Component Layer
// MistakeBookComponent wraps the existing MistakeBookPage logic behind ComponentInterface.
// Phase 2: ComponentInterface implementation for MistakeBook.

import '../../core/component/component_interface.dart';
import '../../models/notebook.dart';
import '../../services/notebook_service.dart';

/// Component ID used for registration in ComponentRegistry.
const kMistakeBookComponentId = 'mistake_book';

/// Wraps the MistakeBook (错题本) feature as a Learning OS Component.
///
/// open()  — initialises the mistake book context (subjectId, sessionId).
/// write() — records a mistake entry (pending review).
/// read()  — retrieves mistake entries matching the query filters.
/// close() — clears the active context.
class MistakeBookComponent implements ComponentInterface {
  ComponentContext? _context;
  final NotebookService _service = NotebookService();

  @override
  Future<void> open(ComponentContext context) async {
    _context = context;
  }

  Future<Notebook?> _findMistakeNotebook() async {
    final notebooks = await _service.getNotebooks();
    for (final nb in notebooks) {
      if (nb.name == '错题本') {
        return nb;
      }
    }
    return null;
  }

  @override
  Future<void> write(ComponentData data) async {
    assert(
      _context != null,
      'MistakeBookComponent.write() called before open()',
    );

    final payload = data.payload;
    final requiredFields = <String>[
      'subject_id',
      'question_content',
      'correct_answer',
    ];
    final missing = requiredFields.where((field) {
      final value = payload[field];
      return value == null || (value is String && value.trim().isEmpty);
    }).toList();
    if (missing.isNotEmpty) {
      throw ArgumentError('Missing required fields: ${missing.join(', ')}');
    }

    final notebook = await _findMistakeNotebook();
    if (notebook == null) {
      throw StateError('MistakeBook notebook not found');
    }

    final notePayload = {
      'notebook_id': notebook.id,
      'subject_id': payload['subject_id'],
      'role': 'user',
      'original_content': payload['question_content'],
      if (payload['title'] != null) 'title': payload['title'],
      'note_type': 'mistake',
      'mistake_status': payload['mistake_status'] ?? 'pending',
      'mistake_details': {
        if (payload['chapter'] != null) 'chapter': payload['chapter'],
        if (payload['error_type'] != null) 'error_type': payload['error_type'],
        'user_answer': payload['user_answer'],
        'correct_answer': payload['correct_answer'],
        if (payload['analysis'] != null) 'analysis': payload['analysis'],
        if (payload['last_reviewed_at'] != null)
          'last_reviewed_at': payload['last_reviewed_at'],
      },
    };

    await _service.createNotes([notePayload]);
  }

  @override
  Future<ComponentData> read(ComponentQuery query) async {
    assert(
      _context != null,
      'MistakeBookComponent.read() called before open()',
    );

    final notebook = await _findMistakeNotebook();
    if (notebook == null) {
      return ComponentData(
        componentId: kMistakeBookComponentId,
        dataType: 'mistakes',
        payload: {'mistakes': []},
      );
    }

    final sections = await _service.getNotebookNotes(notebook.id);
    final mistakes = sections.values
        .expand((list) => list)
        .where((note) => note.noteType == 'mistake')
        .toList();

    final filters = query.filters;
    final subjectId = filters['subject_id'] as int?;
    final chapter = filters['chapter'] as String?;
    final errorType = filters['error_type'] as String?;
    final masteryStatus = filters['mistake_status'] as String?;
    final startTime = filters['start_time'] != null
        ? DateTime.tryParse(filters['start_time'].toString())
        : null;
    final endTime = filters['end_time'] != null
        ? DateTime.tryParse(filters['end_time'].toString())
        : null;

    var filtered = mistakes.where((note) {
      if (subjectId != null && note.subjectId != subjectId) return false;
      if (masteryStatus != null && note.mistakeStatus != masteryStatus) return false;
      if (chapter != null) {
        final details = note.mistakeDetails;
        if (details == null || details['chapter']?.toString() != chapter) return false;
      }
      if (errorType != null) {
        final details = note.mistakeDetails;
        if (details == null || details['error_type']?.toString() != errorType) return false;
      }
      if (startTime != null && note.createdAt.isBefore(startTime)) return false;
      if (endTime != null && note.createdAt.isAfter(endTime)) return false;
      return true;
    }).toList();

    if (filters['stats'] == true) {
      final bySubject = <String, int>{};
      final byErrorType = <String, int>{};
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      var recentCount = 0;

      for (final note in mistakes) {
        final subjectKey = note.subjectId?.toString() ?? 'unknown';
        bySubject[subjectKey] = (bySubject[subjectKey] ?? 0) + 1;
        final details = note.mistakeDetails;
        final errorKey = details?['error_type']?.toString() ?? 'unknown';
        byErrorType[errorKey] = (byErrorType[errorKey] ?? 0) + 1;
        if (note.createdAt.isAfter(sevenDaysAgo)) {
          recentCount += 1;
        }
      }

      return ComponentData(
        componentId: kMistakeBookComponentId,
        dataType: 'mistake_stats',
        payload: {
          'subject_counts': bySubject,
          'error_type_distribution': byErrorType,
          'recent_7d_new': recentCount,
        },
      );
    }

    return ComponentData(
      componentId: kMistakeBookComponentId,
      dataType: 'mistakes',
      payload: {
        'mistakes': filtered
            .map((note) => note.toJson())
            .toList(),
      },
    );
  }

  @override
  Future<void> close() async {
    _context = null;
  }
}
