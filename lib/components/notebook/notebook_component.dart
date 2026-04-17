// Learning OS — Component Layer
// NotebookComponent wraps the existing NotebookListPage logic behind ComponentInterface.
// Phase 2: ComponentInterface implementation for Notebook.

import '../../core/component/component_interface.dart';

/// Component ID used for registration in ComponentRegistry.
const kNotebookComponentId = 'notebook';

/// Wraps the Notebook (笔记本) feature as a Learning OS Component.
///
/// open()  — initialises the notebook context (subjectId, notebookId).
/// write() — saves a note entry to the notebook.
/// read()  — retrieves notes matching the query filters.
/// close() — clears the active context.
class NotebookComponent implements ComponentInterface {
  ComponentContext? _context;

  @override
  Future<void> open(ComponentContext context) async {
    _context = context;
  }

  @override
  Future<void> write(ComponentData data) async {
    // Payload keys:
    //   'notebook_id' (int)    — target notebook identifier
    //   'content'     (String) — note content (Markdown)
    //   'title'       (String) — optional note title
    //   'note_type'   (String) — 'general' | 'mistake'
    assert(
      _context != null,
      'NotebookComponent.write() called before open()',
    );
    // Business logic will be wired in Phase 3.
  }

  @override
  Future<ComponentData> read(ComponentQuery query) async {
    assert(
      _context != null,
      'NotebookComponent.read() called before open()',
    );
    // Filters: 'notebook_id', 'note_type', 'subject_id'
    return ComponentData(
      componentId: kNotebookComponentId,
      dataType: 'notes',
      payload: const {},
    );
  }

  @override
  Future<void> close() async {
    _context = null;
  }
}
