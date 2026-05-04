import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';

/// 安全地将动态类型转换为 int
int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

/// Token配额信息
class TokenQuota {
  final String tier;
  final String tierName;
  final int quotaDaily;
  final int quotaMonthly;
  final int usedToday;
  final int usedThisMonth;
  final int remainingToday;
  final int remainingMonthly;
  final int bonusTokens;
  final int bonusUsed;
  final int remainingBonus;
  final double dailyUsagePercent;
  final double monthlyUsagePercent;
  final bool isBlocked;
  final int rateLimitPerMin;
  final int rateLimitPerHour;
  final int totalTokensAllTime;
  final double totalCostAllTime;
  final double priceMonthly;

  TokenQuota({
    required this.tier,
    required this.tierName,
    required this.quotaDaily,
    required this.quotaMonthly,
    required this.usedToday,
    required this.usedThisMonth,
    required this.remainingToday,
    required this.remainingMonthly,
    required this.bonusTokens,
    required this.bonusUsed,
    required this.remainingBonus,
    required this.dailyUsagePercent,
    required this.monthlyUsagePercent,
    required this.isBlocked,
    required this.rateLimitPerMin,
    required this.rateLimitPerHour,
    required this.totalTokensAllTime,
    required this.totalCostAllTime,
    required this.priceMonthly,
  });

  factory TokenQuota.fromJson(Map<String, dynamic> json) {
    return TokenQuota(
      tier: json['tier'] ?? 'free',
      tierName: json['tier_name'] ?? '免费版',
      quotaDaily: _toInt(json['quota_daily']) ?? 50000,
      quotaMonthly: _toInt(json['quota_monthly']) ?? 0,
      usedToday: _toInt(json['used_today']) ?? 0,
      usedThisMonth: _toInt(json['used_this_month']) ?? 0,
      remainingToday: _toInt(json['remaining_today']) ?? 0,
      remainingMonthly: _toInt(json['remaining_monthly']) ?? 0,
      bonusTokens: _toInt(json['bonus_tokens']) ?? 0,
      bonusUsed: _toInt(json['bonus_used']) ?? 0,
      remainingBonus: _toInt(json['remaining_bonus']) ?? 0,
      dailyUsagePercent: (json['daily_usage_percent'] ?? 0).toDouble(),
      monthlyUsagePercent: (json['monthly_usage_percent'] ?? 0).toDouble(),
      isBlocked: json['is_blocked'] ?? false,
      rateLimitPerMin: _toInt(json['rate_limit_per_min']) ?? 10,
      rateLimitPerHour: _toInt(json['rate_limit_per_hour']) ?? 100,
      totalTokensAllTime: _toInt(json['total_tokens_all_time']) ?? 0,
      totalCostAllTime: (json['total_cost_all_time'] ?? 0).toDouble(),
      priceMonthly: (json['price_monthly'] ?? 0).toDouble(),
    );
  }
}

/// 使用统计摘要
class UsageSummary {
  final int periodDays;
  final int totalTokens;
  final double totalCost;
  final int totalRequests;
  final Map<String, EndpointUsage> byEndpoint;

  UsageSummary({
    required this.periodDays,
    required this.totalTokens,
    required this.totalCost,
    required this.totalRequests,
    required this.byEndpoint,
  });

  factory UsageSummary.fromJson(Map<String, dynamic> json) {
    final byEndpoint = <String, EndpointUsage>{};
    final rawEndpoints = json['by_endpoint'];
    
    // 添加类型检查，避免类型错误
    if (rawEndpoints is Map<String, dynamic>) {
      rawEndpoints.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          byEndpoint[key] = EndpointUsage.fromJson(value);
        }
      });
    }
    
    return UsageSummary(
      periodDays: _toInt(json['period_days']) ?? 30,
      totalTokens: _toInt(json['total_tokens']) ?? 0,
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      totalRequests: _toInt(json['total_requests']) ?? 0,
      byEndpoint: byEndpoint,
    );
  }
}

/// 单个端点的使用统计
class EndpointUsage {
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final double totalCost;
  final int requestCount;

  EndpointUsage({
    required this.totalTokens,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalCost,
    required this.requestCount,
  });

  factory EndpointUsage.fromJson(Map<String, dynamic> json) {
    return EndpointUsage(
      totalTokens: _toInt(json['total_tokens']) ?? 0,
      inputTokens: _toInt(json['input_tokens']) ?? 0,
      outputTokens: _toInt(json['output_tokens']) ?? 0,
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      requestCount: _toInt(json['request_count']) ?? 0,
    );
  }
}

/// 单日使用数据
class DailyUsage {
  final String date;
  final int totalTokens;
  final int requestCount;
  final int inputTokens;
  final int outputTokens;

  DailyUsage({
    required this.date,
    required this.totalTokens,
    required this.requestCount,
    required this.inputTokens,
    required this.outputTokens,
  });

  factory DailyUsage.fromJson(Map<String, dynamic> json) {
    return DailyUsage(
      date: json['date'] ?? '',
      totalTokens: _toInt(json['total_tokens']) ?? 0,
      requestCount: _toInt(json['request_count']) ?? 0,
      inputTokens: _toInt(json['input_tokens']) ?? 0,
      outputTokens: _toInt(json['output_tokens']) ?? 0,
    );
  }
}

/// 使用历史响应
class UsageHistory {
  final List<DailyUsage> data;
  final int totalTokens;
  final int totalRequests;
  final String startDate;
  final String endDate;

  UsageHistory({
    required this.data,
    required this.totalTokens,
    required this.totalRequests,
    required this.startDate,
    required this.endDate,
  });

  factory UsageHistory.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>? ?? [])
        .map((e) => DailyUsage.fromJson(e))
        .toList();
    return UsageHistory(
      data: dataList,
      totalTokens: _toInt(json['total_tokens']) ?? 0,
      totalRequests: _toInt(json['total_requests']) ?? 0,
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }

  /// 获取日期到使用量的映射
  Map<String, DailyUsage> get usageMap {
    return {for (var d in data) d.date: d};
  }
}

/// Token服务
class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  final Dio _dio = DioClient.instance.dio;

  /// 获取当前用户的Token配额
  Future<TokenQuota> getQuota() async {
    try {
      final res = await _dio.get(ApiConstants.tokenQuota);
      return TokenQuota.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取使用统计
  Future<UsageSummary> getUsageSummary({int days = 30}) async {
    try {
      final res = await _dio.get(
        ApiConstants.tokenUsage,
        queryParameters: {'days': days},
      );
      return UsageSummary.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取今日使用统计
  Future<UsageSummary> getTodayUsage() async {
    try {
      final res = await _dio.get(ApiConstants.tokenUsageToday);
      return UsageSummary.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取使用历史（用于日历热力图）
  Future<UsageHistory> getUsageHistory({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;
      
      final res = await _dio.get(
        ApiConstants.tokenUsageHistory,
        queryParameters: params,
      );
      return UsageHistory.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
