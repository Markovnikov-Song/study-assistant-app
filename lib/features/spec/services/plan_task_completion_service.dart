import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/capability/capability_execution_contract.dart';
import '../providers/study_planner_providers.dart';
import 'study_reward_service.dart';

class PlanTaskCompletionService {
  const PlanTaskCompletionService._();

  static Future<void> complete({
    required WidgetRef ref,
    required BuildContext context,
    required CapabilityExecutionContext execution,
    required Map<String, dynamic> result,
    bool popAfterComplete = false,
    String successMessage = '任务已完成',
  }) async {
    if (!execution.isPlanBound) return;

    await ref
        .read(studyPlannerApiServiceProvider)
        .updateItemStatus(
          execution.planId!,
          execution.itemId!,
          'done',
          completionResult: result,
        );

    final updatedPlan = await ref
        .read(studyPlannerApiServiceProvider)
        .getActivePlan();
    ref.invalidate(activePlanProvider);
    ref.invalidate(todayPlanItemsProvider);

    if (!context.mounted) return;
    if (updatedPlan == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      return;
    }

    await StudyRewardService.showTaskCompleted(
      context: context,
      ref: ref,
      plan: updatedPlan,
      completedItemId: execution.itemId!,
      message: successMessage,
      popAfterClose: popAfterComplete,
    );
  }
}
