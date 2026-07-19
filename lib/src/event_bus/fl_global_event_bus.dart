import 'dart:async';

import 'fl_event_bus.dart';
import 'i_event_bus.dart';

/// 全局事件总线访问点
///
/// 提供静态方法访问全局事件总线。默认使用 [FlEventBus] 实现，
/// 通过 [configure] 可注入 mock 实现用于单元测试：
///
/// ```dart
/// class MockEventBus implements IEventBus { ... }
///
/// setUp(() => FlGlobalEventBus.configure(MockEventBus()));
/// tearDown(() => FlGlobalEventBus.destroy());
/// ```
///
/// ## 内存管理
///
/// 底层 `StreamController.broadcast()` 在应用生命周期内常驻。
/// 在 Route 生命周期终点（[State.dispose]）或页面栈 pop 时调用
/// [destroy] 释放 StreamController，避免老生代对象堆积。
class FlGlobalEventBus {
  static IEventBus? _bus;

  /// 配置全局事件总线实例
  ///
  /// 通常用于测试中注入 mock 实现。传入 [bus] 后，
  /// 所有通过 [observeEvent] / [dispatchEvent] 的调用都会路由到此实例。
  /// 旧实例会被 [destroy] 释放。
  static void configure(IEventBus bus) {
    if (_bus != null && _bus != bus) {
      unawaited(_bus!.destroy());
    }
    _bus = bus;
  }

  /// 销毁全局总线，释放 StreamController 资源
  ///
  /// 关闭底层 [StreamController]，断开所有订阅者引用链：
  /// ```
  /// _bus → FlEventBus._streamController → _BroadcastStreamController → _SubscriptionList
  ///                                                                       └─ 闭包 → State/Controller
  /// ```
  /// 调用后 GC 可回收旧实例及其关联对象（老生代 Mark-Sweep）。
  ///
  /// 如有代码继续调用 [observeEvent] / [dispatchEvent]，
  /// 触发延迟重建（lazy init），自动创建新实例，不会崩溃。
  ///
  /// 推荐调用时机：
  /// - `State.dispose()` 或 `FlRouteObserver` pop 回调中
  /// - 应用进入 `AppLifecycleState.detached` 时
  /// - 测试 `tearDown` 中
  static Future<void> destroy() async {
    final bus = _bus;
    _bus = null; // 先置空，确保并发调用安全
    if (bus != null) {
      await bus.destroy();
    }
  }

  /// 重置为默认实现（等效于 [destroy] 但不 await）
  ///
  /// 保留以兼容测试场景。推荐直接使用 [destroy]。
  static void reset() {
    unawaited(destroy());
  }

  static IEventBus get _instance => _bus ??= FlEventBus();

  /// 订阅指定类型的事件
  static Stream<T> observeEvent<T>() {
    return _instance.on<T>();
  }

  /// 发布事件
  static void dispatchEvent<T>(T event) {
    _instance.fire(event);
  }
}
