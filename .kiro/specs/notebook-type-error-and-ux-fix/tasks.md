# Implementation Plan — Notebook Type Error & UX Fix

## Tasks

- [x] 1. Fix `Notebook.fromJson` — replace `(json['x'] as num?)?.toInt()` with `_toInt()`
  - Added file-level `_toInt` / `_toIntOrNull` helpers to `lib/models/notebook.dart`
  - `id`, `sort_order` now use `_toInt(json['x'])`
  - _Requirements: 2.3_

- [x] 2. Fix `Note.fromJson` — replace `(json['x'] as num?)?.toInt()` with safe helpers
  - `id`, `notebook_id` use `_toInt()`
  - `subject_id`, `source_session_id`, `source_message_id`, `imported_to_doc_id` use `_toIntOrNull()`
  - _Requirements: 2.1, 2.2_

- [x] 3. Fix `notebook_service.dart` — two hard casts
  - `getNotebookNotes`: `section['subject_id'] as int?` → `_toIntOrNull(section['subject_id'])`
  - `importToRag`: `(res.data['doc_id'] as num).toInt()` → `_toInt(res.data['doc_id'])`
  - Added file-level `_toInt` / `_toIntOrNull` helpers
  - _Requirements: 2.4_

- [x] 4. New note UX — full-screen page instead of bottom sheet
  - `NotebookDetailPage` FAB already calls `NoteCreatePage` (full-screen)
  - `NoteCreatePage` exists at `lib/components/notebook/note_create_page.dart`
  - _Requirements: 2.5_

- [x] 5. Verify — `dart analyze` on all changed files
  - `lib/models/notebook.dart` — 0 issues
  - `lib/services/notebook_service.dart` — 0 issues
