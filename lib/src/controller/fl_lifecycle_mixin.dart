import 'package:flutter/material.dart';

import 'package:meta/meta.dart';

import '../lifecycle/fl_lifecycle_manager.dart';
import '../lifecycle/fl_lifecycle_state.dart';

/// 页面 + App 生命周期管理 mixin
///
/// 通过 [onLifecycleChanged] 统一接收页面路由状态和 App 前台/后台状态，
/// 将其分发到对应的模板方法（[onPageInit]、[onAppResume]、[onAppPause] 等）。
///
/// 页面生命周期（由路由框架驱动）：
///   onPageInit → onPageContextReady → onPagePostFrame → onPageStart
///   → onPageResume ←→ onPagePause (页面可见/不可见)
///   → onPageStop → onPageDispose
///
/// App 生命周期（由 [FlLifecycleManager] 驱动）：
///   onAppResume(inactive) → onAppForeground ↔ onAppBackground
///   → onAppPause(paused) → (循环)
mixin FlLifecycleMixin on ChangeNotifier {
  // ── 内部状态 ──────────────────────────────────────────────────────

  String? _routeName;
  Object? _arguments;
  FlLifecycleState _lifecycleState = FlLifecycleState.onPageInit;
  bool _isInPageView = false;

  // ── 公开 getter ───────────────────────────────────────────────────

  String? get routeName => _routeName;
  Object? get arguments => _arguments;
  FlLifecycleState get lifecycleState => _lifecycleState;
  bool get isPageResume => _lifecycleState.isPageResume;
  bool get isPagePause => _lifecycleState.isPagePause;
  bool get isInPageView => _isInPageView;

  /// App 当前是否处于前台（同步读取，不依赖 stream）
  bool get isForeground => FlLifecycleManager.instance.isForeground;

  // ── 内部 setter（仅框架调用） ──────────────────────────────────────

  @internal
  set isInPageView(bool value) {
    _isInPageView = value;
  }

  /// 设置当前页面路由信息（仅框架内部调用）
  @internal
  void setupRouteInfo(String? name, Object? arguments) {
    _routeName = name;
    _arguments = arguments;
  }

  // ── 生命周期分发入口（仅框架调用） ──────────────────────────────────

  @internal
  @mustCallSuper
  void onLifecycleChanged(
    FlLifecycleState state, {
    BuildContext? context,
    String? routeName,
    Object? arguments,
  }) {
    _lifecycleState = state;
    switch (state) {
      case FlLifecycleState.onPageInit:
        onPageInit();
        break;
      case FlLifecycleState.onPageContextReady:
        setupRouteInfo(routeName, arguments);
        onPageContextReady(context);
        break;
      case FlLifecycleState.onPagePostFrame:
        onPagePostFrame();
        break;
      case FlLifecycleState.onPageReassemble:
        onPageReassemble();
        break;
      case FlLifecycleState.onPageStart:
        onPageStart();
        break;
      case FlLifecycleState.onPageResume:
        onPageResume();
        break;
      case FlLifecycleState.onPageEnterAnimationEnd:
        onPageEnterAnimationEnd();
        break;
      case FlLifecycleState.onPagePause:
        onPagePause();
        break;
      case FlLifecycleState.onPageStop:
        onPageStop();
        break;
      case FlLifecycleState.onPageLeaveAnimationEnd:
        onPageLeaveAnimationEnd();
        break;
      case FlLifecycleState.onPageDispose:
        onPageDispose();
        break;
      case FlLifecycleState.onAppResume:
        onAppResume();
        break;
      case FlLifecycleState.onAppInactive:
        onAppInactive();
        break;
      case FlLifecycleState.onAppPause:
        onAppPause();
        break;
      case FlLifecycleState.onAppForeground:
        onAppForeground();
        break;
      case FlLifecycleState.onAppBackground:
        onAppBackground();
        break;
    }
  }

  // ── 页面生命周期回调模板（子类覆写） ──────────────────────────────

  @protected
  void onPageInit() {}

  @protected
  void onPageContextReady(BuildContext? context) {}

  @protected
  void onPagePostFrame() {}

  @protected
  void onPageReassemble() {}

  @protected
  void onPageStart() {}

  @protected
  void onPageResume() {}

  @protected
  void onPageEnterAnimationEnd() {}

  @protected
  void onPagePause() {}

  @protected
  void onPageStop() {}

  @protected
  void onPageLeaveAnimationEnd() {}

  @protected
  void onPageDispose() {}

  // ── App 生命周期回调模板（子类覆写） ───────────────────────────────

  /// App 从后台返回前台（对应 [AppLifecycleState.resumed]）
  @protected
  void onAppResume() {}

  /// App 即将进入非活跃状态（对应 [AppLifecycleState.inactive]）
  @protected
  void onAppInactive() {}

  /// App 进入后台（对应 [AppLifecycleState.paused]）
  @protected
  void onAppPause() {}

  /// App 切换到前台（由 [FlLifecycleManager] 判定，过滤了 transient 中断）
  @protected
  void onAppForeground() {}

  /// App 切换到后台（由 [FlLifecycleManager] 判定）
  @protected
  void onAppBackground() {}
}
