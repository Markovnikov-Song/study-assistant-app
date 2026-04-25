/// CAS 前端数据模型

enum RenderType { text, card, navigate, modal, paramFill }

/// 参数类型枚举（与后端 ParamType 对应）
enum ParamType { radio, checkbox, number, text, date, topicTree }

/// 单个参数定义（用于 ParamFillCard 渲染）
class ParamRequest {
  final String name;
  final ParamType type;
  final String label;
  final bool required;
  final dynamic defaultValue;
  // radio / checkbox
  final List<String>? options;
  final String? dynamicSource;
  // number
  final double? min;
  final double? max;
  final double? step;
  // text
  final int maxLength;
  // date
  final String? minDate;
  final String? maxDate;

  const ParamRequest({
    required this.name,
    required this.type,
    required this.label,
    this.required = true,
    this.defaultValue,
    this.options,
    this.dynamicSource,
    this.min,
    this.max,
    this.step,
    this.maxLength = 200,
    this.minDate,
    this.maxDate,
  });

  factory ParamRequest.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'text';
    final type = _parseParamType(typeStr);
    return ParamRequest(
      name: json['name'] as String? ?? '',
      type: type,
      label: json['label'] as String? ?? '',
      required: json['required'] as bool? ?? true,
      defaultValue: json['default'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
      dynamicSource: json['dynamic_source'] as String?,
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      step: (json['step'] as num?)?.toDouble(),
      maxLength: (json['max_length'] as num?)?.toInt() ?? 200,
      minDate: json['min_date'] as String?,
      maxDate: json['max_date'] as String?,
    );
  }

  static ParamType _parseParamType(String s) {
    switch (s) {
      case 'radio':      return ParamType.radio;
      case 'checkbox':   return ParamType.checkbox;
      case 'number':     return ParamType.number;
      case 'date':       return ParamType.date;
      case 'topic_tree': return ParamType.topicTree;
      default:           return ParamType.text;
    }
  }
}

/// CAS Action 执行结果
class ActionResult {
  final bool success;
  final String actionId;
  final Map<String, dynamic> data;
  final String? errorCode;
  final String? errorMessage;
  final bool fallbackUsed;

  const ActionResult({
    required this.success,
    required this.actionId,
    required this.data,
    this.errorCode,
    this.errorMessage,
    this.fallbackUsed = false,
  });

  /// 从 render_type 字段解析渲染类型，缺失时默认 text
  RenderType get renderType {
    final s = data['render_type'] as String? ?? 'text';
    switch (s) {
      case 'card':       return RenderType.card;
      case 'navigate':   return RenderType.navigate;
      case 'modal':      return RenderType.modal;
      case 'param_fill': return RenderType.paramFill;
      default:           return RenderType.text;
    }
  }

  /// 缺参时的参数列表
  List<ParamRequest> get missingParams {
    final raw = data['missing_params'] as List?;
    if (raw == null) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ParamRequest.fromJson)
        .toList();
  }

  /// 已收集的参数
  Map<String, dynamic> get collectedParams {
    return (data['collected_params'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// 从 JSON 解析，缺失字段用默认值填充，不抛出异常
  factory ActionResult.fromJson(Map<String, dynamic> json) {
    try {
      return ActionResult(
        success: json['success'] as bool? ?? false,
        actionId: json['action_id'] as String? ?? 'unknown',
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? {},
        errorCode: json['error_code'] as String?,
        errorMessage: json['error_message'] as String?,
        fallbackUsed: json['fallback_used'] as bool? ?? false,
      );
    } catch (_) {
      return ActionResult.localFallback();
    }
  }

  /// 网络失败 / 解析失败时的本地兜底
  factory ActionResult.localFallback({String? message}) => ActionResult(
        success: false,
        actionId: 'system_error',
        data: {
          'render_type': 'text',
          'text': message ?? '服务暂时不可用，请稍后再试',
        },
        errorCode: 'network_error',
        fallbackUsed: true,
      );

  /// 用户取消参数补全时的本地结果
  factory ActionResult.cancelled() => const ActionResult(
        success: false,
        actionId: 'cancelled',
        data: {'render_type': 'text', 'text': '已取消'},
        errorCode: 'user_cancelled',
      );
}

/// Action 摘要（用于前端同步注册表）
class ActionSummary {
  final String actionId;
  final String name;
  final String description;

  const ActionSummary({
    required this.actionId,
    required this.name,
    required this.description,
  });

  factory ActionSummary.fromJson(Map<String, dynamic> json) => ActionSummary(
        actionId: json['action_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}
