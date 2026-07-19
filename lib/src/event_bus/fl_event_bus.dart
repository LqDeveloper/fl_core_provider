import 'dart:async';

import 'i_event_bus.dart';

class FlEventBus implements IEventBus {
  final StreamController<dynamic> _streamController;

  StreamController<dynamic> get streamController => _streamController;

  FlEventBus({bool sync = false})
    : _streamController = StreamController<dynamic>.broadcast(sync: sync);

  FlEventBus.customController(StreamController controller)
    : _streamController = controller;

  @override
  Stream<T> on<T>() {
    if (T == dynamic) {
      return streamController.stream as Stream<T>;
    } else {
      return streamController.stream.where((event) => event is T).cast<T>();
    }
  }

  @override
  void fire(dynamic event) {
    if (streamController.isClosed) {
      return;
    }
    streamController.add(event);
  }

  @override
  Future<void> destroy() async {
    await _streamController.close();
  }
}
