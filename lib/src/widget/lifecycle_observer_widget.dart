import 'package:flutter/material.dart';

import 'package:meta/meta.dart';

import '../controller/fl_lifecycle_mixin.dart';
import '../lifecycle/fl_lifecycle_state.dart';
import '../mixin/fl_state_lifecycle_mixin.dart';

/// 桥接 [FlStateLifecycleMixin] 与 [FlLifecycleMixin] 的生命周期观察组件
///
/// 将 State 的页面生命周期事件（通过 [FlStateLifecycleMixin] 获得）转发给
/// controller，同时将 [isInPageView] 等渲染树状态同步注入 controller。
///
/// [FlLifecycleState.onPageContextReady] 需要 [BuildContext]，因此单独在
/// [onPageContextReady] 中处理，[onLifecycleStateChanged] 中跳过该状态避免重复。
@internal
class LifecycleObserverWidget<T extends FlLifecycleMixin>
    extends StatefulWidget {
  final WidgetBuilder builder;
  final int? pageIndex;
  final T controller;

  const LifecycleObserverWidget({
    required this.builder,
    required this.controller,
    super.key,
    this.pageIndex,
  });

  @override
  State<LifecycleObserverWidget> createState() =>
      _LifecycleObserverWidgetState();
}

class _LifecycleObserverWidgetState extends State<LifecycleObserverWidget>
    with FlStateLifecycleMixin {
  @override
  int get pageIndex => widget.pageIndex ?? -1;

  @override
  Widget build(BuildContext context) => widget.builder(context);

  @override
  void onPageContextReady(String? routeName, Object? arguments) {
    widget.controller.onLifecycleChanged(
      FlLifecycleState.onPageContextReady,
      context: context,
      routeName: routeName,
      arguments: arguments,
    );
  }

  @override
  void onPagePostFrame() {
    super.onPagePostFrame();
    widget.controller.isInPageView = isInPageView;
  }

  @override
  void onLifecycleStateChanged(FlLifecycleState state) {
    super.onLifecycleStateChanged(state);
    if (state != FlLifecycleState.onPageContextReady) {
      widget.controller.onLifecycleChanged(state);
    }
  }
}
