import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notebook.dart';
import '../services/notebook_service.dart';

// ── Service Provider ──────────────────────────────────────────────────────────

final notebookServiceProvider =
    Provider<NotebookService>((ref) => NotebookService());

// ── Notebook List ─────────────────────────────────────────────────────────────

class NotebookListNotifier extends AsyncNotifier<List<Notebook>> {
  NotebookService get _service => ref.read(notebookServiceProvider);

  @override
  Future<List<Notebook>> build() => _service.getNotebooks();

  Future<void> createNotebook(String name) async {
    await _service.createNotebook(name);
    ref.invalidateSelf();
  }

  Future<void> updateNotebook(
    int id, {
    String? name,
    bool? isPinned,
    bool? isArchived,
    int? sortOrder,
  }) async {
    await _service.updateNotebook(
      id,
      name: name,
      isPinned: isPinned,
      isArchived: isArchived,
      sortOrder: sortOrder,
    );
    ref.invalidateSelf();
  }

  Future<void> deleteNotebook(int id) async {
    await _service.deleteNotebook(id);
    ref.invalidateSelf();
  }
}

final notebookListProvider =
    AsyncNotifierProvider<NotebookListNotifier, List<Notebook>>(
  NotebookListNotifier.new,
);

// ── Notebook Notes (by notebookId) ────────────────────────────────────────────

class NotebookNotesNotifier
    extends FamilyAsyncNotifier<Map<int?, List<Note>>, int> {
  NotebookService get _service => ref.read(notebookServiceProvider);

  @override
  Future<Map<int?, List<Note>>> build(int arg) =>
      _service.getNotebookNotes(arg);
}

final notebookNotesProvider = AsyncNotifierProviderFamily<NotebookNotesNotifier,
    Map<int?, List<Note>>, int>(
  NotebookNotesNotifier.new,
);

// ── Note Detail (by noteId) ───────────────────────────────────────────────────

class NoteDetailNotifier extends FamilyAsyncNotifier<Note, int> {
  NotebookService get _service => ref.read(notebookServiceProvider);

  @override
  Future<Note> build(int arg) => _service.getNote(arg);

  Future<void> updateNote({String? title, String? originalContent}) async {
    await _service.updateNote(arg, title: title, originalContent: originalContent);
    ref.invalidateSelf();
  }

  Future<({String title, List<String> outline})> generateTitle() async {
    final result = await _service.generateTitle(arg);
    ref.invalidateSelf();
    return result;
  }

  Future<int> importToRag() async {
    final docId = await _service.importToRag(arg);
    ref.invalidateSelf();
    return docId;
  }
}

final noteDetailProvider =
    AsyncNotifierProviderFamily<NoteDetailNotifier, Note, int>(
  NoteDetailNotifier.new,
);
