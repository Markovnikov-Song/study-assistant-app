import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_task_service.dart';

enum AiTaskKind { chat, solve, lecture, mindmap, quiz, note, review, plan }

enum AiTaskStatus { running, stopped, completed, failed }

typedef AiTaskCancelCallback = FutureOr<void> Function();

class AiTaskSnapshot {
  final String id;
  final AiTaskKind kind;
  final AiTaskStatus status;
  final String title;
  final String? subtitle;
  final String? error;
  final DateTime startedAt;
  final DateTime updatedAt;
  final bool canCancel;

  const AiTaskSnapshot({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    required this.startedAt,
    required this.updatedAt,
    this.subtitle,
    this.error,
    this.canCancel = true,
  });

  bool get isRunning => status == AiTaskStatus.running;

  AiTaskSnapshot copyWith({
    AiTaskStatus? status,
    String? title,
    String? subtitle,
    String? error,
    DateTime? updatedAt,
    bool? canCancel,
  }) {
    return AiTaskSnapshot(
      id: id,
      kind: kind,
      status: status ?? this.status,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      error: error,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      canCancel: canCancel ?? this.canCancel,
    );
  }
}

class AiTaskStartOptions {
  final String id;
  final AiTaskKind kind;
  final String title;
  final String? subtitle;
  final bool keepAwake;
  final bool canCancel;
  final AiTaskCancelCallback? onCancel;

  const AiTaskStartOptions({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.keepAwake = true,
    this.canCancel = true,
    this.onCancel,
  });
}

class AiTaskController extends StateNotifier<List<AiTaskSnapshot>> {
  AiTaskController() : super(const []);

  final Map<String, AiTaskCancelCallback> _cancelCallbacks = {};
  final Set<String> _awakeTaskIds = {};

  Future<void> start(AiTaskStartOptions options) async {
    await _releaseAwake(options.id);

    if (options.onCancel != null) {
      _cancelCallbacks[options.id] = options.onCancel!;
    } else {
      _cancelCallbacks.remove(options.id);
    }

    if (options.keepAwake) {
      _awakeTaskIds.add(options.id);
      await BackgroundTaskService.instance.startTask(
        BackgroundTaskType.aiStreaming,
      );
    }

    final now = DateTime.now();
    final task = AiTaskSnapshot(
      id: options.id,
      kind: options.kind,
      status: AiTaskStatus.running,
      title: options.title,
      subtitle: options.subtitle,
      startedAt: now,
      updatedAt: now,
      canCancel: options.canCancel && options.onCancel != null,
    );

    state = [task, ...state.where((t) => t.id != options.id)].take(20).toList();
  }

  Future<void> complete(String id) async {
    await _finish(id, AiTaskStatus.completed);
  }

  Future<void> stop(String id) async {
    await _finish(id, AiTaskStatus.stopped);
  }

  Future<void> fail(String id, Object error) async {
    await _finish(id, AiTaskStatus.failed, error: error.toString());
  }

  Future<void> cancel(String id) async {
    final callback = _cancelCallbacks[id];
    if (callback != null) {
      try {
        await callback();
      } catch (e) {
        debugPrint('[AiTaskController] cancel callback failed: $e');
      }
    }
    await stop(id);
  }

  Future<void> cancelKind(AiTaskKind kind) async {
    final ids = state
        .where((task) => task.kind == kind && task.isRunning)
        .map((task) => task.id)
        .toList();
    for (final id in ids) {
      await cancel(id);
    }
  }

  Future<void> _finish(String id, AiTaskStatus status, {String? error}) async {
    _cancelCallbacks.remove(id);
    await _releaseAwake(id);

    final now = DateTime.now();
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            status: status,
            updatedAt: now,
            error: error,
            canCancel: false,
          )
        else
          task,
    ];
  }

  Future<void> _releaseAwake(String id) async {
    if (!_awakeTaskIds.remove(id)) return;
    await BackgroundTaskService.instance.endTask(
      BackgroundTaskType.aiStreaming,
    );
  }

  @override
  void dispose() {
    _cancelCallbacks.clear();
    for (final id in _awakeTaskIds.toList()) {
      unawaited(_releaseAwake(id));
    }
    super.dispose();
  }
}

final aiTaskControllerProvider =
    StateNotifierProvider<AiTaskController, List<AiTaskSnapshot>>(
      (ref) => AiTaskController(),
    );

final activeAiTasksProvider = Provider<List<AiTaskSnapshot>>((ref) {
  return ref
      .watch(aiTaskControllerProvider)
      .where((task) => task.isRunning)
      .toList(growable: false);
});

final latestAiTaskProvider = Provider<AiTaskSnapshot?>((ref) {
  final tasks = ref.watch(aiTaskControllerProvider);
  return tasks.isEmpty ? null : tasks.first;
});

final aiTaskByIdProvider = Provider.family<AiTaskSnapshot?, String>((ref, id) {
  for (final task in ref.watch(aiTaskControllerProvider)) {
    if (task.id == id) return task;
  }
  return null;
});
