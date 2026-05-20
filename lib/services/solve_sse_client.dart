import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';

// ── SSE 事件密封类 ────────────────────────────────────────────────────────────

/// 解题 SSE 事件基类
sealed class SolveSSEEvent {
  const SolveSSEEvent();
}

/// 收到一个 token 片段
final class SolveTokenEvent extends SolveSSEEvent {
  final String text;
  const SolveTokenEvent(this.text);
}

/// 流式推送完成，携带后端 session_id（若有）
final class SolveDoneEvent extends SolveSSEEvent {
  /// 后端持久化后的 session_id，用于追问时复用会话
  final int? sessionId;
  const SolveDoneEvent({this.sessionId});
}

/// Python 计算引擎生成的图表事件
final class SolveChartEvent extends SolveSSEEvent {
  /// 图表 PNG 的 Base64 编码
  final String imageBase64;
  const SolveChartEvent(this.imageBase64);
}

/// 推送过程中发生错误
final class SolveErrorEvent extends SolveSSEEvent {
  final String message;
  const SolveErrorEvent(this.message);
}

// ── SSE 客户端 ────────────────────────────────────────────────────────────────

/// 基于 Dio 流式响应的 SSE 客户端，不引入额外依赖。
///
/// 配合后端 JSON 化推送：每条 `data:` 行均为 JSON，
/// 用 `jsonDecode(data)['content']` 提取实际文本内容。
class SolveSSEClient {
  final Dio _dio;

  SolveSSEClient(this._dio);

  /// 连接到 SSE 端点，返回事件流。
  ///
  /// - [url]：完整请求 URL
  /// - [payload]：POST 请求体（MultimodalPayload）
  /// - [token]：JWT Bearer Token
  Stream<SolveSSEEvent> connect({
    required String url,
    required Map<String, dynamic> payload,
    required String token,
  }) {
    // 使用 StreamController 将异步逻辑包装为 Stream
    final controller = StreamController<SolveSSEEvent>();

    _connectInternal(
      url: url,
      payload: payload,
      token: token,
      controller: controller,
    );

    return controller.stream;
  }

  Future<void> _connectInternal({
    required String url,
    required Map<String, dynamic> payload,
    required String token,
    required StreamController<SolveSSEEvent> controller,
  }) async {
    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: payload,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      final stream = response.data!.stream;
      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final raw = buffer.toString();
        final lines = raw.split('\n');
        buffer.clear();

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.startsWith('data: ')) {
            final rawData = line.substring(6);
            final event = _parseDataLine(rawData);
            if (event != null) {
              controller.add(event);
              if (event is SolveDoneEvent || event is SolveErrorEvent) {
                await controller.close();
                return;
              }
            }
          }
        }

        // 保留最后一个可能不完整的行
        if (lines.isNotEmpty) {
          buffer.write(lines.last);
        }
      }

      // 流结束但未收到 [DONE]，补发一个 done 事件
      if (!controller.isClosed) {
        controller.add(const SolveDoneEvent());
        await controller.close();
      }
    } on DioException catch (e) {
      if (!controller.isClosed) {
        final api = ApiException.fromDioException(e);
        controller.add(SolveErrorEvent(api.message));
        await controller.close();
      }
    } catch (_) {
      if (!controller.isClosed) {
        controller.add(
          const SolveErrorEvent('网络异常，请检查连接后重试'),
        );
        await controller.close();
      }
    }
  }

  /// 解析单条 `data:` 行内容，返回对应事件。
  ///
  /// 优先尝试 JSON 解析（配合后端 JSON 化推送）；
  /// JSON 解析失败时降级为裸字符串解析（兼容旧格式）。
  SolveSSEEvent? _parseDataLine(String rawData) {
    if (rawData.isEmpty) return null;

    // ── 优先：JSON 解析（后端 JSON 化推送格式）────────────────────────────
    try {
      final decoded = jsonDecode(rawData) as Map<String, dynamic>;
      final content = decoded['content'] as String? ?? '';

      if (content == '[DONE]') {
        // 从 [DONE] 事件中提取后端 session_id
        final rawSessionId = decoded['session_id'];
        int? sessionId;
        if (rawSessionId is int) {
          sessionId = rawSessionId;
        } else if (rawSessionId is String) {
          sessionId = int.tryParse(rawSessionId);
        }
        return SolveDoneEvent(sessionId: sessionId);
      } else if (content == '[CHART]') {
        // 图表事件：提取 image_base64 字段
        final imageBase64 = decoded['image_base64'] as String?;
        if (imageBase64 != null && imageBase64.isNotEmpty) {
          return SolveChartEvent(imageBase64);
        }
        // 无图表数据时忽略该事件
        return null;
      } else if (content == '[ERROR]') {
        final error = decoded['error'] as String? ?? '未知错误';
        return SolveErrorEvent(error);
      } else {
        return SolveTokenEvent(content);
      }
    } catch (_) {
      // JSON 解析失败，降级为裸字符串（兼容旧格式）
    }

    // ── 降级：裸字符串解析 ────────────────────────────────────────────────
    if (rawData == '[DONE]') {
      return const SolveDoneEvent();
    } else if (rawData.startsWith('[ERROR]')) {
      return SolveErrorEvent(rawData.substring(7).trim());
    } else {
      return SolveTokenEvent(rawData);
    }
  }
}
