import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../providers/document_provider.dart' show UploadState;
import '../services/exam_service.dart';

final examServiceProvider = Provider<ExamService>((ref) => ExamService());

final pastExamsProvider = FutureProviderFamily<List<PastExamFile>, int>(
  (ref, subjectId) => ref.watch(examServiceProvider).getPastExams(subjectId),
);

final examQuestionsProvider = FutureProviderFamily<List<Map<String, dynamic>>, int>(
  (ref, examId) => ref.watch(examServiceProvider).getQuestions(examId),
);

// ── 历年题操作 ────────────────────────────────────────────────────────────
class ExamActionsNotifier extends StateNotifier<UploadState> {
  final ExamService _service;
  final int _subjectId;
  final Ref _ref;
  Timer? _pollTimer;

  ExamActionsNotifier(this._service, this._subjectId, this._ref)
      : super(const UploadState());

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    state = const UploadState(isUploading: true);
    try {
      await _service.uploadExam(
        fileBytes: file.bytes!,
        filename: file.name,
        subjectId: _subjectId,
      );
      _ref.invalidate(pastExamsProvider(_subjectId));
      _startPolling();
    } catch (e) {
      state = UploadState(error: e.toString());
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _ref.invalidate(pastExamsProvider(_subjectId));
      final exams = await _service.getPastExams(_subjectId);
      final stillProcessing = exams.any(
        (e) => e.status == DocumentStatus.pending || e.status == DocumentStatus.processing,
      );
      if (!stillProcessing) {
        _pollTimer?.cancel();
        state = const UploadState();
      }
    });
  }

  Future<void> delete(int examId) async {
    await _service.deleteExam(examId, _subjectId);
    _ref.invalidate(pastExamsProvider(_subjectId));
  }

  void clearError() => state = const UploadState();
}

final examActionsProvider =
    StateNotifierProviderFamily<ExamActionsNotifier, UploadState, int>(
  (ref, subjectId) => ExamActionsNotifier(ref.watch(examServiceProvider), subjectId, ref),
);

// ── 预测试卷 ──────────────────────────────────────────────────────────────
class GenerationState {
  final bool isLoading;
  final String? result;
  final String? error;

  const GenerationState({this.isLoading = false, this.result, this.error});

  GenerationState copyWith({bool? isLoading, String? result, String? error}) =>
      GenerationState(
        isLoading: isLoading ?? this.isLoading,
        result: result ?? this.result,
        error: error,
      );
}

class PredictedPaperNotifier extends StateNotifier<GenerationState> {
  final ExamService _service;
  final int _subjectId;

  PredictedPaperNotifier(this._service, this._subjectId) : super(const GenerationState());

  Future<void> generate() async {
    state = const GenerationState(isLoading: true);
    try {
      final result = await _service.generatePredictedPaper(_subjectId);
      state = GenerationState(result: result);
    } catch (e) {
      state = GenerationState(error: e.toString());
    }
  }
}

final predictedPaperProvider =
    StateNotifierProviderFamily<PredictedPaperNotifier, GenerationState, int>(
  (ref, subjectId) => PredictedPaperNotifier(ref.watch(examServiceProvider), subjectId),
);

// ── 自定义出题 ────────────────────────────────────────────────────────────
class CustomQuizNotifier extends StateNotifier<GenerationState> {
  final ExamService _service;
  final int _subjectId;

  CustomQuizNotifier(this._service, this._subjectId) : super(const GenerationState());

  Future<void> generate({
    required List<String> questionTypes,
    required Map<String, int> typeCounts,
    required Map<String, int> typeScores,
    required String difficulty,
    String? topic,
  }) async {
    state = const GenerationState(isLoading: true);
    try {
      final result = await _service.generateCustomQuiz(
        subjectId: _subjectId,
        questionTypes: questionTypes,
        typeCounts: typeCounts,
        typeScores: typeScores,
        difficulty: difficulty,
        topic: topic,
      );
      state = GenerationState(result: result);
    } catch (e) {
      state = GenerationState(error: e.toString());
    }
  }
}

final customQuizProvider =
    StateNotifierProviderFamily<CustomQuizNotifier, GenerationState, int>(
  (ref, subjectId) => CustomQuizNotifier(ref.watch(examServiceProvider), subjectId),
);
