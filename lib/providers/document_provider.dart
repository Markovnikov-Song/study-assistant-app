import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/document.dart';
import '../services/document_service.dart';

final documentServiceProvider = Provider<DocumentService>((ref) => DocumentService());

final documentsProvider = FutureProviderFamily<List<StudyDocument>, int>(
  (ref, subjectId) => ref.watch(documentServiceProvider).getDocuments(subjectId),
);

class DocumentActions {
  final DocumentService _service;
  final int _subjectId;
  final Ref _ref;

  DocumentActions(this._service, this._subjectId, this._ref);

  Future<void> pickAndUpload() async {
    final picker = ImagePicker();
    // 使用 file_picker 更合适，这里先用 image_picker 占位
    // TODO: 替换为 file_picker 支持 PDF/Word/PPT
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _service.uploadDocument(
      fileBytes: bytes,
      filename: file.name,
      subjectId: _subjectId,
    );
    _ref.invalidate(documentsProvider(_subjectId));
  }

  Future<void> delete(int docId) async {
    await _service.deleteDocument(docId, _subjectId);
    _ref.invalidate(documentsProvider(_subjectId));
  }
}

final documentActionsProvider = ProviderFamily<DocumentActions, int>(
  (ref, subjectId) => DocumentActions(
    ref.watch(documentServiceProvider),
    subjectId,
    ref,
  ),
);
