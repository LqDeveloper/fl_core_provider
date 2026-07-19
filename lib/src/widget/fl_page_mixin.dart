import 'package:flutter/material.dart';

import '../controller/fl_lifecycle_mixin.dart';
import 'fl_state_builder.dart';

/// 页面级 Controller 注入 Mixin
///
/// 提供 [getProviderWidget] 快捷方法，内部使用 [FlStateBuilder] 创建
/// [ChangeNotifierProvider] + [LifecycleObserverWidget]，
/// 将 controller 注入子树并通过 [buildWithController] 渲染页面。
///
/// 子类需实现：
/// - [createController] — 创建 controller 实例
/// - [buildWithController] — 使用 controller 构建页面 UI
/// - [pageIndex]（可选）— PageView 中的索引，默认 -1
mixin FlPageMixin<T extends FlLifecycleMixin> {
  Widget getProviderWidget(BuildContext context) {
    return FlStateBuilder(
      pageIndex: pageIndex,
      create: createController,
      builder: (cxt, controller) => buildWithController(cxt, controller),
    );
  }

  int get pageIndex => -1;

  T createController(BuildContext context);

  Widget buildWithController(BuildContext context, T controller);
}
