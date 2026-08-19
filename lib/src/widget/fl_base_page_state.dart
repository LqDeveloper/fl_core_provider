import 'package:flutter/material.dart';

import '../controller/fl_lifecycle_mixin.dart';
import 'fl_page_mixin.dart';

abstract class FlBasePageState<
  S extends StatefulWidget,
  T extends FlLifecycleMixin
>
    extends State<S>
    with FlPageMixin<T>, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return getProviderWidget(context);
  }
}
