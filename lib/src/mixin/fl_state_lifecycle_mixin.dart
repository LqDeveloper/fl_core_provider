import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../lifecycle/fl_lifecycle_manager.dart';
import '../lifecycle/fl_lifecycle_state.dart';
import '../lifecycle/fl_route_observer.dart';
import '../lifecycle/lifecycle_route_aware.dart';
import '../render_objects/custom_render_indexed_stack.dart';

mixin FlStateLifecycleMixin<T extends StatefulWidget> on State<T>
    implements LifecycleRouteAware {
  bool _didRunOnContextReady = false;
  ModalRoute? _modalRoute;
  Animation<double>? _routeAnimation;

  String? get routeName => _modalRoute?.settings.name;

  Object? get arguments => _modalRoute?.settings.arguments;

  bool get isInPageView => _isInPageView;
  bool _isInPageView = false;
  RenderSliver? _renderSliver;
  bool _isIndexStack = false;
  CustomRenderIndexedStack? _renderIndexedStack;
  StreamSubscription<int?>? _indexStackSub;

  int get pageIndex => -1;

  int _currentIndex = -1;

  bool _hasAppeared = false;
  bool _hasResume = false;
  bool _hasDispose = false;

  ScrollNotificationObserverState? _scrollState;

  final StreamController<FlLifecycleState> _lifecycleController =
      StreamController.broadcast();

  Stream<FlLifecycleState> get lifecycleStream => _lifecycleController.stream;
  StreamSubscription<bool>? _foregroundSub;
  StreamSubscription<AppLifecycleState>? _lifecycleSub;

  @override
  void initState() {
    super.initState();
    _foregroundSub = FlLifecycleManager.instance.stream.listen((value) {
      if (value) {
        onAppForeground();
        onLifecycleStateChanged(FlLifecycleState.onAppForeground);
      } else {
        onAppBackground();
        onLifecycleStateChanged(FlLifecycleState.onAppBackground);
      }
    });
    _lifecycleSub = FlLifecycleManager.instance.lifecycle.listen((state) {
      appLifecycleChanged(state);
    });

    onPageInit();
    onLifecycleStateChanged(FlLifecycleState.onPageInit);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (_hasDispose) {
        return;
      }
      _initRenderState();
      onPagePostFrame();
      onLifecycleStateChanged(FlLifecycleState.onPagePostFrame);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRunOnContextReady) {
      _didRunOnContextReady = true;
      _modalRoute = ModalRoute.of(context);
      if (_modalRoute == null) {
        return;
      }
      FlRouteObserver.instance.subscribe(_modalRoute!, this);
      onPageContextReady(
        _modalRoute?.settings.name,
        _modalRoute?.settings.arguments,
      );
      onLifecycleStateChanged(FlLifecycleState.onPageContextReady);
      _routeAnimation = _modalRoute?.animation;
      _routeAnimation?.addStatusListener(_handlerAnimationStatus);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (kDebugMode) {
      onPageReassemble();
      onLifecycleStateChanged(FlLifecycleState.onPageReassemble);
    }
  }

  @override
  void dispose() {
    _hasDispose = true;
    _renderSliver = null;
    _renderIndexedStack = null;
    unawaited(_indexStackSub?.cancel());
    unawaited(_foregroundSub?.cancel());
    unawaited(_lifecycleSub?.cancel());
    _routeAnimation?.removeStatusListener(_handlerAnimationStatus);
    _routeAnimation = null;
    _checkNotifyPageStop();
    FlRouteObserver.instance.unsubscribe(this);
    _disposeScrollState();
    _modalRoute = null;
    onPageDispose();
    onLifecycleStateChanged(FlLifecycleState.onPageDispose);
    unawaited(_lifecycleController.close());
    super.dispose();
  }

  ///forward -> completed -> reverse -> dismissed
  void _handlerAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      onPageEnterAnimationEnd();
      onLifecycleStateChanged(FlLifecycleState.onPageEnterAnimationEnd);
    } else if (status == AnimationStatus.dismissed) {
      onPageLeaveAnimationEnd();
      onLifecycleStateChanged(FlLifecycleState.onPageLeaveAnimationEnd);
    }
  }

  void _initRenderState() {
    _findAncestorRenderObj();
    if (_renderSliver != null && _renderSliver is RenderSliverFillViewport) {
      _isInPageView = true;
      assert(pageIndex > -1, "当前页面位于PageView中，必须设置pageIndex ");
      _scrollState = ScrollNotificationObserver.maybeOf(context);
      _scrollState?.addListener(_scrollNotification);
      return;
    } else if (_renderIndexedStack != null ||
        _renderIndexedStack is CustomRenderIndexedStack) {
      _isIndexStack = true;
      assert(pageIndex > -1, "当前页面位于CustomRenderIndexedStack中，必须设置pageIndex ");
      _checkIndexStackIndex();
      return;
    } else {
      _notifyPageStart();
    }
  }

  void _findAncestorRenderObj({int maxCycleCount = 10}) {
    final obj = context.findRenderObject();
    if (obj == null) {
      return;
    }
    var currentCycleCount = 1;
    var parent = obj.parent;
    while (parent != null && currentCycleCount <= maxCycleCount) {
      if (parent is RenderSliver) {
        _renderSliver = parent;
        return;
      } else if (parent is CustomRenderIndexedStack) {
        _renderIndexedStack = parent;
        return;
      }
      parent = parent.parent;
      currentCycleCount++;
    }
  }

  void _checkIndexStackIndex() {
    if (!_isIndexStack) {
      return;
    }
    if (_indexStackSub != null) {
      unawaited(_indexStackSub?.cancel());
      _indexStackSub = null;
    }
    final index = _renderIndexedStack?.index ?? 0;
    _checkCurrentPageIndex(index);
    _indexStackSub = _renderIndexedStack?.stream.listen((val) {
      if (val == null) {
        return;
      }
      _checkCurrentPageIndex(val);
    });
  }

  void _scrollNotification(ScrollNotification notification) {
    if (notification.depth > 0) {
      return;
    }
    if (notification is ScrollUpdateNotification) {
      _handlePageView(notification: notification);
    }
  }

  void _handlePageView({required ScrollNotification notification}) {
    if (!_isInPageView) {
      return;
    }
    if (notification.metrics is! PageMetrics) {
      return;
    }
    final metrics = notification.metrics as PageMetrics;
    final index = metrics.page!.round();
    _checkCurrentPageIndex(index);
  }

  void _checkCurrentPageIndex(int index) {
    if (index != _currentIndex) {
      if (index == pageIndex) {
        Future.delayed(Duration.zero, () {
          if (!_hasDispose) {
            _notifyPageStart();
          }
        });
      } else {
        _notifyPageStop();
      }
      if (_currentIndex != -1) {
        onPageViewChanged(_currentIndex, index);
      }
      _currentIndex = index;
    }
  }

  void _disposeScrollState() {
    _scrollState?.removeListener(_scrollNotification);
    _scrollState = null;
  }

  void _checkNotifyPageStart() {
    if (_isInPageView || _isIndexStack) {
      if (_currentIndex != pageIndex) {
        return;
      }
      _notifyPageStart();
    } else {
      _notifyPageStart();
    }
  }

  void _checkNotifyPageResume() {
    if (_hasAppeared) {
      _notifyPageResume();
    }
  }

  void _checkNotifyPagePause() {
    if (_hasAppeared) {
      _notifyPagePause();
    }
  }

  void _checkNotifyPageStop() {
    if (_isInPageView || _isIndexStack) {
      if (_currentIndex != pageIndex) {
        return;
      }
      _notifyPageStop();
    } else {
      _notifyPageStop();
    }
  }

  void _notifyPageStart() {
    if (_hasAppeared) {
      return;
    }
    _hasAppeared = true;
    onPageStart();
    onLifecycleStateChanged(FlLifecycleState.onPageStart);
    _notifyPageResume();
  }

  void _notifyPageResume() {
    if (_hasResume) {
      return;
    }
    _hasResume = true;
    onPageResume();
    onLifecycleStateChanged(FlLifecycleState.onPageResume);
  }

  void _notifyPagePause() {
    if (!_hasResume) {
      return;
    }
    _hasResume = false;
    onPagePause();
    onLifecycleStateChanged(FlLifecycleState.onPagePause);
  }

  void _notifyPageStop() {
    if (!_hasAppeared) {
      return;
    }
    _hasAppeared = false;
    _notifyPagePause();
    onPageStop();
    onLifecycleStateChanged(FlLifecycleState.onPageStop);
  }

  ///*********************************************
  @protected
  void onPageInit() {}

  @protected
  void onPageContextReady(String? routeName, Object? arguments) {}

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

  @protected
  void onAppResume() {}

  @protected
  void onAppInactive() {}

  @protected
  void onAppPause() {}

  @protected
  void onAppForeground() {}

  @protected
  void onAppBackground() {}

  @protected
  @mustCallSuper
  void onLifecycleStateChanged(FlLifecycleState state) {
    _lifecycleController.add(state);
  }

  @protected
  void onPageViewChanged(int from, int to) {}

  ///*********************RouteAware*************************
  @override
  void routePageStart() {
    _checkNotifyPageStart();
  }

  @override
  void routePageResume() {
    _checkNotifyPageResume();
  }

  @override
  void routePagePause() {
    _checkNotifyPagePause();
  }

  @override
  void routePageStop() {
    _checkNotifyPageStop();
  }

  void appLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onAppResume();
        onLifecycleStateChanged(FlLifecycleState.onAppResume);
        break;
      case AppLifecycleState.inactive:
        onAppInactive();
        onLifecycleStateChanged(FlLifecycleState.onAppInactive);
        break;
      case AppLifecycleState.paused:
        onAppPause();
        onLifecycleStateChanged(FlLifecycleState.onAppPause);
        break;
      default:
        break;
    }
  }
}
