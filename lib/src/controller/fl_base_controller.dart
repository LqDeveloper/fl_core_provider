import 'package:flutter/material.dart';

import 'fl_event_bus_mixin.dart';
import 'fl_lifecycle_mixin.dart';
import 'fl_notify_mixin.dart';

/// 控制器基类，组合 [FlNotifyMixin]、[FlLifecycleMixin]、[FlEventBusMixin]
///
/// 子类只需实现 [shouldNotifyIds] 定义需要追踪的 ID 列表，
/// 页面初始化时自动注册，Hot Reload 时自动重新注册。
abstract class FlBaseController<T extends Enum> extends ChangeNotifier
    with FlNotifyMixin<T>, FlLifecycleMixin, FlEventBusMixin {
  @override
  @mustCallSuper
  void onPageInit() {
    super.onPageInit();
    registerIds(shouldNotifyIds);
  }

  @override
  @mustCallSuper
  void onPageReassemble() {
    super.onPageReassemble();
    logMessage('[hot-reload] re-register ids: $shouldNotifyIds');
    registerIds(shouldNotifyIds);
  }

  /// 需要追踪通知的 ID 列表（被 [registerIds] 消费）
  List<T> get shouldNotifyIds;
}
