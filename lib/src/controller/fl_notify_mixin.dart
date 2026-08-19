import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 内部 ID 标签计数器
class _IdTag<T> {
  _IdTag({required this.name});

  final T name;
  int _value = 0;

  int get value => _value;

  void incrementTag() {
    _value = (_value + 1) % 1000;
  }
}

/// 基于注册 ID 的选择性通知 Mixin
///
/// 通过 [registerIds] 注册需要追踪的 ID，后续调用 [notifyMultiListeners] 或
/// [notifySingleListener] 时只递增对应 ID 的版本号，配合 [updateIdValue] /
/// [updateMultiIdValue] 可供外部 Selector 判断是否需要重建。
///
/// 在 [SchedulerPhase.persistentCallbacks]（build 阶段）中调用 [notifyListeners]
/// 会自动延迟到下一帧执行，避免 "setState during build" 异常。
mixin FlNotifyMixin<T extends Enum> on ChangeNotifier {
  bool _disposed = false;
  final Map<T, _IdTag> _updatedIds = {};
  bool _hasRegister = false;
  bool _notifyScheduled = false;

  @protected
  @mustCallSuper
  @override
  void dispose() {
    logMessage('[dispose]');
    _disposed = true;
    _updatedIds.clear();
    _notifyScheduled = false;
    super.dispose();
  }

  @protected
  @mustCallSuper
  void registerIds(List<T> ids) {
    clearRegisteredIds();
    logMessage('[register] ids: $ids');
    for (final name in ids) {
      _updatedIds[name] = _IdTag(name: name);
    }
    _hasRegister = true;
  }

  @protected
  @mustCallSuper
  void clearRegisteredIds() {
    _updatedIds.clear();
    _hasRegister = false;
  }

  @protected
  @mustCallSuper
  @override
  void notifyListeners() {
    if (_disposed) return;

    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      super.notifyListeners();
      return;
    }

    // build 阶段延迟到下一帧执行，防止 "setState during build" 异常，
    // 同一帧内多次调用只调度一次。
    if (!_notifyScheduled) {
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (!_disposed) {
          super.notifyListeners();
        }
      });
    }
  }

  @protected
  @mustCallSuper
  void notifyMultiListeners(List<T> ids) {
    if (_disposed || ids.isEmpty) return;

    assert(_hasRegister, '$runtimeType: registerIds not call');
    logMessage('[notify] ids: $ids');
    for (final id in ids) {
      assert(containsId(id), '$runtimeType: Id: $id must be register');
      _updatedIds[id]?.incrementTag();
    }
    onNotified(ids);
    notifyListeners();
  }

  @protected
  @mustCallSuper
  void notifySingleListener(T id) {
    if (_disposed) return;

    assert(_hasRegister, '$runtimeType: registerIds not call');
    logMessage('[notify] id: $id');
    assert(containsId(id), '$runtimeType: id: $id must be register');
    _updatedIds[id]?.incrementTag();
    onNotified([id]);
    notifyListeners();
  }

  @internal
  bool containsId(T id) => _updatedIds.containsKey(id);

  @internal
  bool containsMultiId(List<T> ids) => ids.every(containsId);

  @internal
  int updateIdValue(T id) => _updatedIds[id]?.value ?? 0;

  @internal
  int updateMultiIdValue(List<T> ids) {
    var value = 0;
    for (final id in ids) {
      // 多项式哈希组合：31 * h + v，避免简单求和导致的 Selector<int> 碰撞
      value = 31 * value + updateIdValue(id);
    }
    return value;
  }

  @internal
  @protected
  void logMessage(String message) {}

  @protected
  void onNotified(List<T> events) {}
}
