import 'package:flutter/material.dart';

import '../controller/fl_base_controller.dart';
import 'fl_selector_ids.dart';

/// 基于 [FlSelectorIds] 的抽象视图基类
///
/// 子类只需实现：
/// - [observeIds] — 需要监听的 ID 列表
/// - [buildWidget] — 根据 controller 数据构建 UI
///
/// 内部自动使用 [FlSelectorIds] 包装，仅在 [observeIds] 对应的数据变化时
/// 触发 [buildWidget] 重建。
abstract class FlSelectorView<E extends Enum, T extends FlBaseController<E>>
    extends StatelessWidget {
  const FlSelectorView({super.key});

  List<E> get observeIds;

  @override
  Widget build(BuildContext context) {
    return FlSelectorIds<E, T>(
      ids: observeIds,
      builder: (context, controller, _) => buildWidget(context, controller),
    );
  }

  Widget buildWidget(BuildContext context, T controller);
}
