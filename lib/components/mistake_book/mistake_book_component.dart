// Learning OS — Component Layer
// MistakeBookComponent wraps the existing MistakeBookPage logic behind ComponentInterface.
// Phase 2: ComponentInterface implementation for MistakeBook.

import '../../core/component/component_interface.dart';

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

  @override
  Future<void> open(ComponentContext context) async {
    _context = context;
  }

  @override
  Future<void> write(ComponentData data) async {
    // Payload keys:
    //   'content'          (String) — mistake content (Markdown)
    //   'title'            (String) — optional title
    //   'mistake_status'   (String) — 'pending' | 'reviewed'
    assert(
      _context != null,
      'MistakeBookComponent.write() called before open()',
    );
    // Business logic will be wired in Phase 3.
  }

  @override
  Future<ComponentData> read(ComponentQuery query) async {
    assert(
      _context != null,
      'MistakeBookComponent.read() called before open()',
    );
    // Filters: 'mistake_status' ('pending' | 'reviewed'), 'subject_id'
    return ComponentData(
      componentId: kMistakeBookComponentId,
      dataType: 'mistakes',
      payload: const {},
    );
  }

  @override
  Future<void> close() async {
    _context = null;
  }
}
