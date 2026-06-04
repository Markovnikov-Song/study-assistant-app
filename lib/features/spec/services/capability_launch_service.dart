import '../../../core/capability/capability_execution_contract.dart';
import '../../../routes/app_routes.dart';
import '../models/study_plan_models.dart';

class CapabilityLaunchService {
  const CapabilityLaunchService._();

  static String routeForPlanItem(PlanItem item) {
    final context = contextForPlanItem(item);
    return routeForContext(context, subjectId: item.subjectId);
  }

  static CapabilityExecutionContext contextForPlanItem(PlanItem item) {
    final params = {
      ...item.capabilityParams,
      if (item.subjectId != null) 'subject_id': '${item.subjectId}',
      if (item.nodeId.isNotEmpty) 'node_id': item.nodeId,
    };
    final topic = (params['topic'] as String?) ?? item.nodeText;
    final count = params['count'] is int
        ? params['count'] as int
        : int.tryParse('${params['count']}');

    return CapabilityExecutionContext(
      capabilityId: item.capabilityId ?? '',
      topic: topic,
      count: count,
      contentType: params['content_type'] as String?,
      planId: item.planId,
      itemId: item.id,
      params: params,
    );
  }

  static String routeForContext(
    CapabilityExecutionContext context, {
    int? subjectId,
  }) {
    return switch (context.capabilityId) {
      'memory.drill' => appendCapabilityQuery(R.toolkitMemoryDrill, context),
      'quiz.generate' => appendCapabilityQuery(R.toolkitPractice, context),
      'lecture.view' =>
        subjectId != null ? R.courseSpaceSubject(subjectId) : R.mindmapEntry,
      'mindmap.build' =>
        subjectId != null
            ? R.courseSpaceSubject(subjectId, generate: true)
            : R.mindmapGenerate,
      _ => R.toolkit,
    };
  }
}
