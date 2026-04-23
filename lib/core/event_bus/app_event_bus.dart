import 'dart:async';

/// 全局 EventBus 单例，基于 StreamController.broadcast() 实现跨模块事件广播
class AppEventBus {
  AppEventBus._();
  static final AppEventBus instance = AppEventBus._();

  final _controller = StreamController<AppEvent>.broadcast();

  /// 监听特定类型的事件
  Stream<T> on<T extends AppEvent>() => _controller.stream.whereType<T>();

  /// 发布事件
  void fire(AppEvent event) => _controller.add(event);

  /// 释放资源（应用退出时调用）
  void dispose() => _controller.close();
}

/// 所有 EventBus 事件的基类
abstract class AppEvent {
  const AppEvent();
}
