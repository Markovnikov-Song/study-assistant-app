import 'dart:async';

/// 所有 EventBus 事件的基类
abstract class AppEvent {
  const AppEvent();
}

/// 全局事件总线（单例），基于 StreamController.broadcast()
class AppEventBus {
  AppEventBus._();
  static final instance = AppEventBus._();

  final _controller = StreamController<AppEvent>.broadcast();

  /// 监听特定类型的事件
  Stream<T> on<T extends AppEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  /// 发布事件
  void fire(AppEvent event) => _controller.add(event);

  /// 释放资源（App 退出时调用）
  void dispose() => _controller.close();
}
