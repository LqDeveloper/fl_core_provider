import 'package:flutter/material.dart';

import '../render_objects/custom_render_indexed_stack.dart';

/// 基于 [CustomRenderIndexedStack] 的 IndexedStack 实现
///
/// 通过 [Visibility.maintain] 包裹子项，确保非当前页 widget 的视图状态
/// 不会被销毁，同时 [CustomRenderIndexedStack] 精确控制唯一可见子项的
/// 点击穿透和布局表现。
///
/// 适用于 PageView 嵌套 IndexedStack 等需要保持子页面状态的场景。
class FlIndexedStack extends IndexedStack {
  const FlIndexedStack({
    super.key,
    super.alignment = AlignmentDirectional.topStart,
    super.textDirection,
    super.clipBehavior = Clip.hardEdge,
    super.sizing = StackFit.loose,
    super.index = 0,
    super.children = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final wrappedChildren = List<Widget>.generate(children.length, (int i) {
      return Visibility.maintain(visible: i == index, child: children[i]);
    });
    return _CustomRawIndexedStack(
      alignment: alignment,
      textDirection: textDirection,
      clipBehavior: clipBehavior,
      sizing: sizing,
      index: index ?? 0,
      children: wrappedChildren,
    );
  }
}

class _CustomRawIndexedStack extends Stack {
  const _CustomRawIndexedStack({
    super.alignment,
    super.textDirection,
    super.clipBehavior,
    StackFit sizing = StackFit.loose,
    this.index = 0,
    super.children,
  }) : super(fit: sizing);

  final int index;

  @override
  CustomRenderIndexedStack createRenderObject(BuildContext context) {
    return CustomRenderIndexedStack(
      index: index,
      fit: fit,
      clipBehavior: clipBehavior,
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    CustomRenderIndexedStack renderObject,
  ) {
    renderObject
      ..index = index
      ..fit = fit
      ..clipBehavior = clipBehavior
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context);
  }

  @override
  MultiChildRenderObjectElement createElement() {
    return _IndexedStackElement(this);
  }
}

class _IndexedStackElement extends MultiChildRenderObjectElement {
  _IndexedStackElement(_CustomRawIndexedStack super.widget);

  @override
  _CustomRawIndexedStack get widget => super.widget as _CustomRawIndexedStack;

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final idx = widget.index;
    if (children.isNotEmpty && idx >= 0 && idx < children.length) {
      visitor(children.elementAt(idx));
    }
  }
}
