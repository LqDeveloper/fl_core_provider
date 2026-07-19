import 'dart:async';

import 'package:flutter/material.dart';

import '../event_bus/fl_global_event_bus.dart';

mixin FlEventBusMixin on ChangeNotifier {
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  @protected
  Stream<T> onEvent<T>() {
    return FlGlobalEventBus.observeEvent<T>();
  }

  @protected
  void observeEvent<T>(void Function(T event) onData) {
    if (_disposed) return;
    final sub = onEvent<T>().listen(onData);
    _subscriptions.add(sub);
  }

  @protected
  void dispatchEvent<T>(T event) {
    FlGlobalEventBus.dispatchEvent<T>(event);
  }

  @override
  @mustCallSuper
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    super.dispose();
  }
}
