import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../controller/fl_lifecycle_mixin.dart';
import 'fl_context_extension.dart';
import 'lifecycle_observer_widget.dart';

/// 创建带生命周期感知的 Controller 并注入子树
///
/// 内部组合 [ChangeNotifierProvider] 与 [LifecycleObserverWidget]：
/// - 通过 [create] 创建控制器实例并注入 widget 树
/// - 通过 [LifecycleObserverWidget] 将页面生命周期事件转发给 controller
/// - 支持 [builder]（接收 controller）或 [child]（纯 widget）两种渲染模式
class FlStateBuilder<T extends FlLifecycleMixin> extends StatelessWidget {
  final int? pageIndex;
  final T Function(BuildContext context) create;
  final Widget Function(BuildContext context, T controller)? builder;
  final Widget? child;

  const FlStateBuilder({
    required this.create,
    super.key,
    this.pageIndex,
    this.child,
    this.builder,
  }) : assert(
         child != null || builder != null,
         'child 和 builder 至少需要提供一个',
       );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<T>(
      create: create,
      child: Builder(
        builder: (innerContext) {
          final controller = innerContext.rc<T>();
          return LifecycleObserverWidget<T>(
            pageIndex: pageIndex,
            controller: controller,
            builder: (cxt) {
              if (builder != null) {
                return builder!(cxt, controller);
              }
              return child!;
            },
          );
        },
      ),
    );
  }
}
