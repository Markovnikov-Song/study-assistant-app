import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_plan_models.dart';
import '../services/study_planner_api_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────

final studyPlannerApiServiceProvider = Provider<StudyPlannerApiService>(
  (_) => StudyPlannerApiService(),
);

// ── Active plan ───────────────────────────────────────────────────────────────

final activePlanProvider = FutureProvider<StudyPlan?>((ref) {
  return ref.read(studyPlannerApiServiceProvider).getActivePlan();
});

// ── Today items ───────────────────────────────────────────────────────────────

final todayPlanItemsProvider = FutureProvider<List<PlanItem>>((ref) {
  return ref.read(studyPlannerApiServiceProvider).getTodayItems();
});

// ── Plan summary ──────────────────────────────────────────────────────────────

final planSummaryProvider =
    FutureProvider.family<PlanSummary, int>((ref, planId) {
  return ref.read(studyPlannerApiServiceProvider).getPlanSummary(planId);
});

// ── Spec page phase ───────────────────────────────────────────────────────────

enum SpecPhase { chat, progress, plan }

final specPhaseProvider = StateProvider<SpecPhase>((_) => SpecPhase.chat);

// ── Plan progress polling ─────────────────────────────────────────────────────

/// 轮询规划进度，每 2 秒一次，直到 status = done/failed
final planProgressProvider =
    StreamProvider.family<Map<String, dynamic>, int>((ref, planId) async* {
  final svc = ref.read(studyPlannerApiServiceProvider);
  while (true) {
    final progress = await svc.getPlanProgress(planId);
    yield progress;
    final status = progress['status'] as String? ?? '';
    if (status == 'done' || status == 'failed') break;
    await Future.delayed(const Duration(seconds: 2));
  }
});

// ── Collected plan info (during chat phase) ───────────────────────────────────

class PlanCollectionState {
  final List<int> subjectIds;
  final List<String> subjectNames;
  final DateTime? deadline;
  final int dailyMinutes;

  const PlanCollectionState({
    this.subjectIds = const [],
    this.subjectNames = const [],
    this.deadline,
    this.dailyMinutes = 60,
  });

  bool get isComplete => subjectIds.isNotEmpty && deadline != null;

  PlanCollectionState copyWith({
    List<int>? subjectIds,
    List<String>? subjectNames,
    DateTime? deadline,
    int? dailyMinutes,
  }) =>
      PlanCollectionState(
        subjectIds: subjectIds ?? this.subjectIds,
        subjectNames: subjectNames ?? this.subjectNames,
        deadline: deadline ?? this.deadline,
        dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      );
}

final planCollectionProvider =
    StateProvider<PlanCollectionState>((_) => const PlanCollectionState());
