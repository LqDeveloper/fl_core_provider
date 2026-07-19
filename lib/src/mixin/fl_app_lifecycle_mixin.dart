import 'dart:async';

import 'package:meta/meta.dart';

import '../lifecycle/fl_lifecycle_manager.dart';

mixin FlAppLifecycleMixin {
  StreamSubscription<bool>? _sub;
  bool _hasInit = false;

  void onInit() {
    if (_hasInit) {
      return;
    }
    _hasInit = true;
    _sub = FlLifecycleManager.instance.stream.listen((value) {
      if (value) {
        onAppForeground();
      } else {
        onAppBackground();
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _hasInit = false;
  }

  @protected
  void onAppForeground() {}

  @protected
  void onAppBackground() {}
}
