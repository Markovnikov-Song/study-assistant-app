// ─────────────────────────────────────────────────────────────
// background_task_service.dart — 后台任务保活服务
// 确保 AI 输出、下载等异步任务在切换应用时不被中断
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 后台任务类型
enum BackgroundTaskType {
  aiStreaming,  // AI 流式输出
  downloading,  // 文件下载
  uploading,    // 文件上传
  processing,   // 数据处理
}

/// 后台任务保活服务
/// 使用 WakeLock 防止设备休眠和应用被杀
class BackgroundTaskService {
  BackgroundTaskService._();
  static final BackgroundTaskService instance = BackgroundTaskService._();

  // 当前活跃的任务计数
  final Map<BackgroundTaskType, int> _activeTasks = {};

  /// 开始一个后台任务
  /// 会自动启用 WakeLock，防止应用被杀
  Future<void> startTask(BackgroundTaskType type) async {
    _activeTasks[type] = (_activeTasks[type] ?? 0) + 1;
    
    if (_getTotalActiveTasks() == 1) {
      // 第一个任务启动时，启用 WakeLock
      await WakelockPlus.enable();
      debugPrint('[BackgroundTask] WakeLock enabled for $type');
    }
    
    debugPrint('[BackgroundTask] Task started: $type (active: ${_activeTasks[type]})');
  }

  /// 结束一个后台任务
  /// 当所有任务都结束时，自动释放 WakeLock
  Future<void> endTask(BackgroundTaskType type) async {
    if (_activeTasks[type] != null && _activeTasks[type]! > 0) {
      _activeTasks[type] = _activeTasks[type]! - 1;
      
      if (_activeTasks[type] == 0) {
        _activeTasks.remove(type);
      }
      
      debugPrint('[BackgroundTask] Task ended: $type (active: ${_activeTasks[type] ?? 0})');
      
      if (_getTotalActiveTasks() == 0) {
        // 所有任务都结束了，释放 WakeLock
        await WakelockPlus.disable();
        debugPrint('[BackgroundTask] WakeLock disabled - all tasks completed');
      }
    }
  }

  /// 强制结束某类型的所有任务
  Future<void> cancelAllTasks(BackgroundTaskType type) async {
    if (_activeTasks.containsKey(type)) {
      _activeTasks.remove(type);
      debugPrint('[BackgroundTask] All tasks cancelled: $type');
      
      if (_getTotalActiveTasks() == 0) {
        await WakelockPlus.disable();
        debugPrint('[BackgroundTask] WakeLock disabled - all tasks cancelled');
      }
    }
  }

  /// 强制结束所有任务
  Future<void> cancelAll() async {
    _activeTasks.clear();
    await WakelockPlus.disable();
    debugPrint('[BackgroundTask] All tasks cancelled, WakeLock disabled');
  }

  /// 获取当前活跃任务总数
  int _getTotalActiveTasks() {
    return _activeTasks.values.fold(0, (sum, count) => sum + count);
  }

  /// 检查是否有活跃任务
  bool get hasActiveTasks => _getTotalActiveTasks() > 0;

  /// 检查特定类型是否有活跃任务
  bool hasActiveTasksOfType(BackgroundTaskType type) {
    return (_activeTasks[type] ?? 0) > 0;
  }

  /// 获取当前状态（用于调试）
  Map<String, dynamic> getStatus() {
    return {
      'total_active_tasks': _getTotalActiveTasks(),
      'tasks_by_type': _activeTasks.map((k, v) => MapEntry(k.name, v)),
      'wakelock_enabled': _getTotalActiveTasks() > 0,
    };
  }
}
