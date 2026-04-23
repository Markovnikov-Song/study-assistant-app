// Learning OS — MCP 连接状态 Provider
// 轮询后端 /api/mcp/status，提供 MCPConnectionSummary 给 UI 层。
// 需求 3.5：区分全部在线 / 仅本地 / 离线模式三种状态。

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import 'mcp_models.dart';

// ── 轮询间隔 ──────────────────────────────────────────────────────────────────

/// 正常状态下的轮询间隔（60 秒）
const _kPollIntervalNormal = Duration(seconds: 60);

/// 离线/降级状态下的轮询间隔（5 分钟，MCP 不是核心功能，不必频繁重试）
const _kPollIntervalDegraded = Duration(minutes: 5);

// ── Provider ──────────────────────────────────────────────────────────────────

/// MCP 连接状态 Provider。
///
/// 使用 [StreamProvider] 定期轮询后端 `/api/mcp/status`。
/// 网络不可用时返回 [MCPConnectionSummary.offline]，不抛出异常。
/// keepAlive 确保全局只有一个轮询实例。
final mcpStatusProvider = StreamProvider<MCPConnectionSummary>((ref) {
  ref.keepAlive();
  return _mcpStatusStream();
});

/// 便捷 Provider：只暴露 [MCPConnectionState] 枚举值。
final mcpConnectionStateProvider = Provider<MCPConnectionState>((ref) {
  return ref.watch(mcpStatusProvider).when(
    data: (summary) => summary.state,
    loading: () => MCPConnectionState.offline,
    error: (_, _) => MCPConnectionState.offline,
  );
});

// ── 轮询流实现 ─────────────────────────────────────────────────────────────────

Stream<MCPConnectionSummary> _mcpStatusStream() async* {
  final dio = DioClient.instance.dio;

  while (true) {
    final summary = await _fetchStatus(dio);
    yield summary;

    // 离线/降级时缩短轮询间隔，更快感知恢复
    final interval = summary.state == MCPConnectionState.allOnline
        ? _kPollIntervalNormal
        : _kPollIntervalDegraded;
    await Future.delayed(interval);
  }
}

Future<MCPConnectionSummary> _fetchStatus(Dio dio) async {
  try {
    final response = await dio
        .get<Map<String, dynamic>>('/api/mcp/status')
        .timeout(const Duration(seconds: 5));

    if (response.data != null) {
      return MCPConnectionSummary.fromJson(response.data!);
    }
    return MCPConnectionSummary.offline;
  } on DioException {
    // 网络不可用或后端未启动，返回离线状态
    return MCPConnectionSummary.offline;
  } on TimeoutException {
    return MCPConnectionSummary.offline;
  } catch (_) {
    return MCPConnectionSummary.offline;
  }
}
