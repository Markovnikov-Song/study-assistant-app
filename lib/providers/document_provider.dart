import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../services/document_service.dart';

final documentServiceProvider = Provider<DocumentService>((ref) => DocumentService());

final documentsProvider = FutureProviderFamily<List<StudyDocument>, int>(
  (ref, subjectId) => ref.watch(documentServiceProvider).getDocuments(subjectId),
);

// 上传状态
class UploadState {
  final bool isUploading;
  final String? error;
  const UploadState({this.isUploading = false, this.error});
}

class DocumentActionsNotifier extends StateNotifier<UploadState> {
  final DocumentService _service;
  final int _subjectId;
  final Ref _ref;
  Timer? _pollTimer;

  DocumentActionsNotifier(this._service, this._subjectId, this._ref)
      : super(const UploadState());

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'md'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    state = const UploadState(isUploading: true);
    try {
      await _service.uploadDocument(
        fileBytes: file.bytes!.toList(),
        filename: file.name,
        subjectId: _subjectId,
      );
      // 立即刷新列表（此时状态为 pending/processing），然后开始轮询
      _ref.invalidate(documentsProvider(_subjectId));
      _startPolling();
    } catch (e) {
      state = UploadState(error: e.toString());
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _ref.invalidate(documentsProvider(_subjectId));
      // 检查是否还有 pending/processing 的文件
      final docs = await _service.getDocuments(_subjectId);
      final stillProcessing = docs.any(
        (d) => d.status == DocumentStatus.pending || d.status == DocumentStatus.processing,
      );
      if (!stillProcessing) {
        _pollTimer?.cancel();
        state = const UploadState();
      }
    });
  }

  Future<void> delete(int docId) async {
    await _service.deleteDocument(docId, _subjectId);
    _ref.invalidate(documentsProvider(_subjectId));
  }

  Future<void> reindex(int docId) async {
    await _service.reindexDocument(docId, _subjectId);
    _ref.invalidate(documentsProvider(_subjectId));
    _startPolling();
  }

  Future<void> reindexAll() async {
    await _service.reindexAll(_subjectId);
    _ref.invalidate(documentsProvider(_subjectId));
    _startPolling();
  }

  void clearError() => state = const UploadState();
}

final documentActionsProvider =
    StateNotifierProviderFamily<DocumentActionsNotifier, UploadState, int>(
  (ref, subjectId) => DocumentActionsNotifier(
    ref.watch(documentServiceProvider),
    subjectId,
    ref,
  ),
);
