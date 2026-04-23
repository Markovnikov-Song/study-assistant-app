import '../models/subject.dart';

enum IntentType { none, subject, planning, calendar, tool, spec }

class DetectedIntent {
  final IntentType type;
  final Map<String, dynamic> params;

  const DetectedIntent({required this.type, this.params = const {}});

  static const none = DetectedIntent(type: IntentType.none);
}

abstract class IntentDetector {
  Future<DetectedIntent> detect(String userInput, {List<Subject>? subjects});
}

/// 规则匹配意图识别（本地同步，无网络延迟）
/// 优先级：spec > planning > calendar > subject > tool > none
class RuleBasedIntentDetector implements IntentDetector {
  static const _specKeywords = ['系统学习', '完整计划', '从零开始', '全面掌握', '系统掌握', '完整课程'];
  static const _planningKeywords = ['备考', '复习计划', '考试', '学习目标', '期末', '期中', '冲刺', '学习计划'];
  static const _calendarKeywords = ['加到日历', '添加计划', '安排学习', '记到日历', '下周', '明天', '提醒我'];
  static const _toolKeywords = ['笔记', '错题', '记录', '整理', '收藏', '保存到笔记'];

  @override
  Future<DetectedIntent> detect(String userInput, {List<Subject>? subjects}) async {
    final input = userInput.toLowerCase();

    // 优先级 1：Spec 模式
    if (_containsAny(input, _specKeywords)) {
      return const DetectedIntent(type: IntentType.spec);
    }

    // 优先级 2：规划意图
    if (_containsAny(input, _planningKeywords)) {
      return const DetectedIntent(type: IntentType.planning);
    }

    // 优先级 3：日历意图
    if (_containsAny(input, _calendarKeywords)) {
      return DetectedIntent(
        type: IntentType.calendar,
        params: _extractCalendarParams(input),
      );
    }

    // 优先级 4：学科意图（匹配已知学科名）
    if (subjects != null) {
      for (final subject in subjects) {
        if (input.contains(subject.name.toLowerCase())) {
          return DetectedIntent(
            type: IntentType.subject,
            params: {'subjectId': subject.id, 'subjectName': subject.name},
          );
        }
      }
    }

    // 优先级 5：工具意图
    if (_containsAny(input, _toolKeywords)) {
      String toolRoute = '/toolkit/notebooks';
      String toolName = '笔记本';
      if (input.contains('错题')) {
        toolRoute = '/toolkit/mistake-book';
        toolName = '错题本';
      }
      return DetectedIntent(
        type: IntentType.tool,
        params: {'toolRoute': toolRoute, 'toolName': toolName},
      );
    }

    return DetectedIntent.none;
  }

  Map<String, dynamic> _extractCalendarParams(String input) {
    final params = <String, dynamic>{};

    // 简单提取时间关键词
    if (input.contains('明天')) {
      params['date'] = DateTime.now().add(const Duration(days: 1));
    } else if (input.contains('后天')) {
      params['date'] = DateTime.now().add(const Duration(days: 2));
    }

    // 提取时间（如 "9点" "下午3点"）
    final timeMatch = RegExp(r'(\d{1,2})点').firstMatch(input);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1) ?? '');
      if (hour != null) {
        final adjustedHour = input.contains('下午') && hour < 12 ? hour + 12 : hour;
        params['time'] = '${adjustedHour.toString().padLeft(2, '0')}:00';
      }
    }

    return params;
  }

  bool _containsAny(String input, List<String> keywords) {
    return keywords.any((kw) => input.contains(kw));
  }
}
