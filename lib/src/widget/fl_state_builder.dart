import 'package:fl_state_lifecycle/fl_state_lifecycle.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../controller/fl_lifecycle_mixin.dart';
import 'fl_context_extension.dart';

/// 创建带生命周期感知的 Controller 并注入子树
///
/// 内部组合 [ChangeNotifierProvider] 与 [LifecycleObserverWidget]：
/// - 通过 [create] 创建控制器实例并注入 widget 树
/// - 通过 [LifecycleObserverWidget] 将页面生命周期事件转发给 controller
/// - 支持 [builder]（接收 controller）或 [child]（纯 widget）两种渲染模式
class FlStateBuilder<T extends FlLifecycleMixin> extends StatelessWidget {
  final bool observePageView;
  final bool observeAppLifecycle;
  final T Function(BuildContext context) create;
  final Widget Function(BuildContext context, T controller) builder;

  const FlStateBuilder({
    required this.create,
    super.key,
    this.observePageView = false,
    this.observeAppLifecycle = false,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<T>(
      create: create,
      child: Builder(
        builder: (innerContext) {
          final controller = innerContext.rc<T>();
          return FlPageView(
            observePageView: observePageView,
            observeAppLifecycle: observeAppLifecycle,
            onStateChanged: (cxt, state) {
              controller.onLifecycleChanged(state, context: cxt);
            },
            onRouteParam: (_, name, arguments) {
              controller.setupRouteInfo(name, arguments);
            },
            onPageViewChanged: (_, from, to) {
              controller.onPageViewChanged(from, to);
            },
            child: builder(context, controller),
          );
        },
      ),
    );
  }
}
