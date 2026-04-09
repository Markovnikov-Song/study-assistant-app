import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── State ─────────────────────────────────────────────────────────────────────

@immutable
class MultiSelectState {
  const MultiSelectState({
    this.isActive = false,
    this.selectedMessageIds = const {},
  });

  final bool isActive;
  final Set<int> selectedMessageIds;

  MultiSelectState copyWith({
    bool? isActive,
    Set<int>? selectedMessageIds,
  }) {
    return MultiSelectState(
      isActive: isActive ?? this.isActive,
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MultiSelectNotifier extends StateNotifier<MultiSelectState> {
  MultiSelectNotifier() : super(const MultiSelectState());

  /// 进入多选模式，将 [firstMessageId] 加入选中集合。
  /// 需求：4.1
  void activate(int firstMessageId) {
    state = MultiSelectState(
      isActive: true,
      selectedMessageIds: {firstMessageId},
    );
  }

  /// 切换消息选中/取消选中状态。
  /// 需求：4.3
  void toggle(int messageId) {
    if (!state.isActive) return;
    final current = Set<int>.from(state.selectedMessageIds);
    if (current.contains(messageId)) {
      current.remove(messageId);
    } else {
      current.add(messageId);
    }
    state = state.copyWith(selectedMessageIds: current);
  }

  /// 退出多选模式，清空选中集合。
  /// 需求：4.5
  void cancel() {
    state = const MultiSelectState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final multiSelectProvider =
    StateNotifierProvider<MultiSelectNotifier, MultiSelectState>(
  (ref) => MultiSelectNotifier(),
);
