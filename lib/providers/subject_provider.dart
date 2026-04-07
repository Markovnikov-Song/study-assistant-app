import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../services/subject_service.dart';

final subjectServiceProvider = Provider<SubjectService>((ref) => SubjectService());

final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  return ref.watch(subjectServiceProvider).getSubjects();
});

// 操作类（创建/编辑/删除/置顶/归档）
class SubjectActions {
  final SubjectService _service;
  SubjectActions(this._service);

  Future<void> create(String name, {String? category, String? description}) =>
      _service.createSubject(name, category: category, description: description);

  Future<void> update(int id, {required String name, String? category, String? description}) =>
      _service.updateSubject(id, name: name, category: category, description: description);

  Future<void> delete(int id) => _service.deleteSubject(id);

  Future<void> togglePin(int id) => _service.togglePin(id);

  Future<void> toggleArchive(int id) => _service.toggleArchive(id);
}

final subjectActionsProvider = Provider<SubjectActions>(
  (ref) => SubjectActions(ref.watch(subjectServiceProvider)),
);
