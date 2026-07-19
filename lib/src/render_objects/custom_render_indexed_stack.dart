import 'dart:async';

import 'package:flutter/rendering.dart';

import 'package:meta/meta.dart';

@internal
class CustomRenderIndexedStack extends RenderIndexedStack {
  final StreamController<int?> _controller = StreamController.broadcast();

  Stream<int?> get stream => _controller.stream;

  CustomRenderIndexedStack({
    super.children,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
    super.index,
  });

  @override
  set index(int? value) {
    super.index = value;
    _controller.add(value);
  }

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }
}
