import 'package:dio/dio.dart';
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
      final intent = _toDetectedIntent(result, subjects: subjects);
      return _withMindmapContext(intent, userInput, subjects);
    } catch (_) {
      // 后端不可用或超时，降级为本地规则
      final intent = await _fallback.detect(userInput, subjects: subjects);
      return _withMindmapContext(intent, userInput, subjects);
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
      case 'create_mini_app':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, ...result.data},
        );
      case 'make_quiz':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, ...result.data},
        );
      case 'generate_mindmap':
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
          params: {
            'actionId': actionId,
            'render_type': 'navigate',
            'route': '/toolkit/notebooks',
          },
        );
      case 'open_course_space':
        return DetectedIntent(
          type: IntentType.tool,
          params: {
            'actionId': actionId,
            'render_type': 'navigate',
            'route': '/course-space',
          },
        );
      case 'recommend_mistake_practice':
        return DetectedIntent(
          type: IntentType.tool,
          params: {
            'actionId': actionId,
            'render_type': 'navigate',
            'route': '/toolkit/mistake-book',
          },
        );
      case 'start_feynman':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, ...result.data},
        );
      case 'explain_concept':
        return DetectedIntent(
          type: IntentType.tool,
          params: {'actionId': actionId, ...result.data},
        );
      case 'unknown_intent':
      default:
        return DetectedIntent.none;
    }
  }

  DetectedIntent _withMindmapContext(
    DetectedIntent intent,
    String userInput,
    List<Subject>? subjects,
  ) {
    if (intent.params['actionId'] != 'generate_mindmap') {
      return intent;
    }

    final params = <String, dynamic>{...intent.params};
    final subjectId =
        _subjectIdFromParams(params) ??
        _findMentionedSubjectId(userInput, subjects);
    if (subjectId != null) {
      params['subjectId'] = subjectId;
      params['route'] = '/course-space/$subjectId?generate=1';
    } else {
      params['route'] = params['route'] ?? '/mindmap-entry?generate=1';
    }
    params['render_type'] = 'navigate';
    return DetectedIntent(type: IntentType.tool, params: params);
  }

  int? _subjectIdFromParams(Map<String, dynamic> params) {
    final raw =
        params['subjectId'] ?? params['subject_id'] ?? params['subject'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  int? _findMentionedSubjectId(String userInput, List<Subject>? subjects) {
    if (subjects == null) return null;
    final input = userInput.toLowerCase();
    for (final subject in subjects) {
      if (subject.name.isNotEmpty &&
          input.contains(subject.name.toLowerCase())) {
        return subject.id;
      }
    }
    return null;
  }

  /// 检测规划意图并提取参数
  /// 调用后端 API 提取参数，返回提取的参数和缺失参数列表
  Future<PlanningIntentResult> detectPlanningIntent(String text) async {
    try {
      final response = await _casService.extractPlanningParams(text);
      return PlanningIntentResult.fromJson(response);
    } on DioException {
      // 网络错误时返回本地提取结果作为降级
      return _localExtractPlanningParams(text);
    } catch (_) {
      return _localExtractPlanningParams(text);
    }
  }

  /// 本地规则降级提取规划参数
  PlanningIntentResult _localExtractPlanningParams(String text) {
    // 简单的本地规则提取
    final params = <String, dynamic>{};
    final missingParams = <String>[];

    // 提取学科
    final subjects = ['数学', '语文', '英语', '物理', '化学', '生物', '历史', '地理', '政治'];
    String? foundSubject;
    for (final subject in subjects) {
      if (text.contains(subject)) {
        foundSubject = subject;
        break;
      }
    }

    if (foundSubject != null) {
      params['subject'] = foundSubject;
    } else {
      missingParams.add('subject');
    }

    // 提取日期
    if (text.contains('下周') ||
        text.contains('下个月') ||
        text.contains('期末') ||
        text.contains('期中')) {
      params['exam_date'] = _extractDateFromText(text);
    } else {
      missingParams.add('exam_date');
    }

    // 提取范围
    if (text.contains('前') || text.contains('全书') || text.contains('全部')) {
      params['exam_scope'] = _extractScopeFromText(text);
    } else {
      missingParams.add('exam_scope');
    }

    // 默认每日2小时
    params['daily_hours'] = 2.0;

    final isComplete = missingParams.isEmpty;

    return PlanningIntentResult(
      type: isComplete ? IntentType.planning : IntentType.none,
      params: params,
      missingParams: missingParams,
      isComplete: isComplete,
    );
  }

  String? _extractDateFromText(String text) {
    if (text.contains('下周')) return '下周';
    if (text.contains('下个月')) return '下个月';
    if (text.contains('期末')) return '期末';
    if (text.contains('期中')) return '期中';
    return null;
  }

  String? _extractScopeFromText(String text) {
    final match = RegExp(r'前(\d+)章').firstMatch(text);
    if (match != null) {
      return '前${match.group(1)}章';
    }
    if (text.contains('全书') || text.contains('全部')) {
      return '全书';
    }
    return null;
  }
}

/// 规划意图识别结果
class PlanningIntentResult {
  final IntentType type;
  final Map<String, dynamic> params;
  final List<String> missingParams;
  final bool isComplete;

  const PlanningIntentResult({
    required this.type,
    this.params = const {},
    this.missingParams = const [],
    this.isComplete = false,
  });

  factory PlanningIntentResult.fromJson(Map<String, dynamic> json) {
    return PlanningIntentResult(
      type: IntentType.planning,
      params: json['params'] as Map<String, dynamic>? ?? {},
      missingParams:
          (json['missing_params'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isComplete: json['is_complete'] as bool? ?? false,
    );
  }

  factory PlanningIntentResult.empty() {
    return const PlanningIntentResult(
      type: IntentType.none,
      params: {},
      missingParams: [],
      isComplete: false,
    );
  }
}
