import 'dart:async';

import 'package:flutter/material.dart';

import 'fl_global_event_bus.dart';

mixin FlStateEventBusMixin<S extends StatefulWidget> on State<S> {
  final List<StreamSubscription> _subscriptions = [];

  Stream<T> _on<T>() {
    return FlGlobalEventBus.observeEvent<T>();
  }

  @protected
  void observeEvent<T>(void Function(T event) onData) {
    final sub = _on<T>().listen(onData);
    _subscriptions.add(sub);
  }

  @protected
  void dispatchEvent<T>(T event) {
    FlGlobalEventBus.dispatchEvent<T>(event);
  }

  @override
  @mustCallSuper
  void dispose() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    super.dispose();
  }
}
