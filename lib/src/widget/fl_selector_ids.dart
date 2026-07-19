import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../controller/fl_base_controller.dart';
import 'fl_context_extension.dart';

/// 基于注册 ID 的选择性重建组件
///
/// 结合 [FlBaseController] 的 [FlNotifyMixin] 机制，监听一组 ID 的版本号变化。
/// 当任意注册 ID 被通知更新时，通过 [Selector] 比对哈希值选择性触发 builder 重建。
///
/// 用法：
/// ```dart
/// FlSelectorIds(
///   ids: [PageId.title, PageId.count],
///   builder: (context, controller, child) => Text('...'),
/// )
/// ```
typedef CustomSelectorBuilder<E extends Enum, T extends FlBaseController<E>> =
    Widget Function(BuildContext context, T controller, Widget? child);

class FlSelectorIds<E extends Enum, T extends FlBaseController<E>>
    extends StatelessWidget {
  final List<E> ids;
  final CustomSelectorBuilder<E, T> builder;
  final Widget? child;

  const FlSelectorIds({
    required this.ids,
    required this.builder,
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.rc<T>();
    assert(controller.containsMultiId(ids), 'ids: $ids 中包含未注册的 id');
    return Selector<T, int>(
      child: child,
      selector: (_, controller) => controller.updateMultiIdValue(ids),
      builder: (context, _, Widget? child) => builder(context, controller, child),
    );
  }
}
