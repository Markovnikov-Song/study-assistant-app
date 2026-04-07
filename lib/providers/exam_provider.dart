import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/document.dart';
import '../services/exam_service.dart';

final examServiceProvider = Provider<ExamService>((ref) => ExamService());

final pastExamsProvider = FutureProviderFamily<List<PastExamFile>, int>(
  (ref, subjectId) => ref.watch(examServiceProvider).getPastExams(subjectId),
);

final examQuestionsProvider = FutureProviderFamily<List<Map<String, dynamic>>, int>(
  (ref, examId) => ref.watch(examServiceProvider).getQuestions(examId),
);

// ── 历年题操作 ────────────────────────────────────────────────────────────
class ExamActions {
  final ExamService _service;
  final int _subjectId;
  final Ref _ref;

  ExamActions(this._service, this._subjectId, this._ref);

  Future<void> pickAndUpload() async {
    final picker = ImagePicker();
    // TODO: 替换为 file_picker 支持 PDF/Word
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _service.uploadExam(
      fileBytes: bytes,
      filename: file.name,
      subjectId: _subjectId,
    );
    _ref.invalidate(pastExamsProvider(_subjectId));
  }

  Future<void> delete(int examId) async {
    await _service.deleteExam(examId, _subjectId);
    _ref.invalidate(pastExamsProvider(_subjectId));
  }
}

final examActionsProvider = ProviderFamily<ExamActions, int>(
  (ref, subjectId) => ExamActions(ref.watch(examServiceProvider), subjectId, ref),
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
