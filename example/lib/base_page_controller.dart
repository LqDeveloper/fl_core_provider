import 'package:fl_core_provider/fl_core_provider.dart';
import 'package:flutter/foundation.dart';

class BasePageController<T extends Enum> extends FlBaseController<T> {
  @override
  List<T> get shouldNotifyIds => [];

  @override
  void onPageStart() {
    super.onPageStart();
    debugPrint("$runtimeType ---onPageStart");
  }

  @override
  void onPageStop() {
    super.onPageStop();
    debugPrint("$runtimeType ---onPageStop");
  }

  @override
  void onPageResume() {
    super.onPageResume();
    debugPrint("$runtimeType ---onPageResume");
  }

  @override
  void onPagePause() {
    super.onPagePause();
    debugPrint("$runtimeType ---onPagePause");
  }
}
