import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cas_service.dart';
import 'models/action_result.dart';

// ── Service Provider ──────────────────────────────────────────────────────────

final casServiceProvider = Provider<CasService>((ref) => CasService());

// ── State ─────────────────────────────────────────────────────────────────────

class CasDispatchState {
  final bool isLoading;
  final ActionResult? lastResult;
  /// 非空时触发 ParamFillCard，等待用户补全参数
  final List<ParamRequest>? pendingParams;
  /// 已收集的参数（用于多轮补全）
  final Map<String, dynamic> collectedParams;

  const CasDispatchState({
    this.isLoading = false,
    this.lastResult,
    this.pendingParams,
    this.collectedParams = const {},
  });

  CasDispatchState copyWith({
    bool? isLoading,
    ActionResult? lastResult,
    List<ParamRequest>? pendingParams,
    bool clearPending = false,
    Map<String, dynamic>? collectedParams,
  }) {
    return CasDispatchState(
      isLoading: isLoading ?? this.isLoading,
      lastResult: lastResult ?? this.lastResult,
      pendingParams: clearPending ? null : (pendingParams ?? this.pendingParams),
      collectedParams: collectedParams ?? this.collectedParams,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CasDispatchNotifier extends StateNotifier<CasDispatchState> {
  final CasService _service;

  CasDispatchNotifier(this._service) : super(const CasDispatchState());

  /// 分发用户输入（或携带已收集参数重新分发）
  Future<ActionResult> dispatch(
    String text, {
    Map<String, dynamic> collectedParams = const {},
    String? sessionId,
  }) async {
    state = state.copyWith(isLoading: true, clearPending: true);

    // 将已收集参数拼接到文本后面（后端 IntentMapper 会解析 params 字段）
    // 实际上直接传 text，后端会从 intent 中提取参数
    // 已收集参数通过 session 机制传递（简化实现：直接在 text 中附加上下文）
    final result = await _service.dispatch(text, sessionId: sessionId);

    if (result.renderType == RenderType.paramFill) {
      // 缺参：设置 pendingParams，等待用户补全
      state = state.copyWith(
        isLoading: false,
        lastResult: result,
        pendingParams: result.missingParams,
        collectedParams: {...result.collectedParams, ...collectedParams},
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        lastResult: result,
        clearPending: true,
        collectedParams: const {},
      );
    }

    return result;
  }

  /// 用户填写了一个参数，追加到 collectedParams
  /// 当所有必填参数都填完后，自动重新 dispatch
  Future<ActionResult?> fillParam(
    String name,
    dynamic value,
    String originalText, {
    String? sessionId,
  }) async {
    final updated = {...state.collectedParams, name: value};
    final remaining = state.pendingParams
        ?.where((p) => p.required && !updated.containsKey(p.name))
        .toList();

    state = state.copyWith(collectedParams: updated);

    if (remaining == null || remaining.isEmpty) {
      // 所有必填参数已补全，重新 dispatch
      // 将参数信息附加到文本中让后端识别
      final paramsText = updated.entries
          .map((e) => '${e.key}=${e.value}')
          .join(', ');
      final enrichedText = '$originalText [params: $paramsText]';
      return dispatch(enrichedText, collectedParams: updated, sessionId: sessionId);
    }

    // 还有未填参数，更新 pendingParams
    state = state.copyWith(pendingParams: remaining);
    return null;
  }

  /// 用户取消参数补全
  void cancelFill() {
    state = state.copyWith(
      clearPending: true,
      collectedParams: const {},
      lastResult: ActionResult.cancelled(),
    );
  }

  /// 重置状态
  void reset() {
    state = const CasDispatchState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final casDispatchProvider =
    StateNotifierProvider<CasDispatchNotifier, CasDispatchState>((ref) {
  return CasDispatchNotifier(ref.watch(casServiceProvider));
});
