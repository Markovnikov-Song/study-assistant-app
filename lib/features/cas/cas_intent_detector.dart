import '../../models/subject.dart';
import '../../services/intent_detector.dart';
import 'cas_service.dart';
import 'models/action_result.dart';

/// CAS 意图识别器：优先调用后端 /api/cas/dispatch，
/// 失败/超时时降级为 RuleBasedIntentDetector。
class CasIntentDetector implements IntentDetector {
  final CasService _casService;
  final RuleBasedIntentDetector _fallback = RuleBasedIntentDetector();

  CasIntentDetector(this._casService);

  @override
  Future<DetectedIntent> detect(
    String userInput, {
    List<Subject>? subjects,
  }) async {
    try {
      final result = await _casService
          .dispatch(userInput)
          .timeout(const Duration(seconds: 10));
      return _toDetectedIntent(result, subjects: subjects);
    } catch (_) {
      // 后端不可用或超时，降级为本地规则
      return _fallback.detect(userInput, subjects: subjects);
    }
  }

  /// 将 ActionResult 转换为 DetectedIntent
  DetectedIntent _toDetectedIntent(
    ActionResult result, {
    List<Subject>? subjects,
  }) {
    if (!result.success && result.errorCode != null) {
      return DetectedIntent.none;
    }

    final actionId = result.actionId;

    // 根据 action_id 映射到 IntentType
    switch (actionId) {
      case 'make_quiz':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, ...result.data},
        );
      case 'make_plan':
        return DetectedIntent(
          type: IntentType.planning,
          params: {'actionId': actionId, ...result.data},
        );
      case 'open_calendar':
      case 'add_calendar_event':
        return DetectedIntent(
          type: IntentType.calendar,
          params: {'actionId': actionId, ...result.data},
        );
      case 'open_notebook':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, 'render_type': 'navigate', 'route': '/toolkit/notebooks'},
        );
      case 'open_course_space':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, 'render_type': 'navigate', 'route': '/course-space'},
        );
      case 'recommend_mistake_practice':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, 'render_type': 'navigate', 'route': '/toolkit/mistake-book'},
        );
      case 'unknown_intent':
      default:
        return DetectedIntent.none;
    }
  }
}
