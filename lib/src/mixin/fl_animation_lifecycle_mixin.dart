import 'package:flutter/material.dart';

/// 页面入场/退场动画感知 Mixin — 独立版
mixin FlAnimationLifecycleMixin<T extends StatefulWidget> on State<T> {
  Animation<double>? _routeAnimation;
  bool _disposed = false;
  bool _didRunOnContextReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRunOnContextReady) return;
    _didRunOnContextReady = true;
    final modalRoute = ModalRoute.of(context);
    if (modalRoute == null) return;
    _attachRouteAnimation(modalRoute.animation);
  }

  /// 绑定路由动画对象，自动监听动画状态变化
  @protected
  void _attachRouteAnimation(Animation<double>? animation) {
    _detachRouteAnimation();
    _routeAnimation = animation;
    _routeAnimation?.addStatusListener(_handlerAnimationStatus);
  }

  /// 解绑当前路由动画
  @protected
  void _detachRouteAnimation() {
    _routeAnimation?.removeStatusListener(_handlerAnimationStatus);
    _routeAnimation = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _detachRouteAnimation();
    super.dispose();
  }

  /// forward → completed → reverse → dismissed
  void _handlerAnimationStatus(AnimationStatus status) {
    if (_disposed) return;
    switch (status) {
      case AnimationStatus.forward:
        onPageForward();
        break;
      case AnimationStatus.completed:
        onPageCompleted();
        break;
      case AnimationStatus.reverse:
        onPageReverse();
        break;
      case AnimationStatus.dismissed:
        onPageDismissed();
        break;
    }
  }

  @protected
  void onPageForward() {}

  @protected
  void onPageCompleted() {}

  @protected
  void onPageReverse() {}

  @protected
  void onPageDismissed() {}
}
