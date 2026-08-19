import 'package:flutter/material.dart';

import '../controller/fl_lifecycle_mixin.dart';
import 'fl_page_mixin.dart';

abstract class FlBasePage<T extends FlLifecycleMixin> extends StatelessWidget
    with FlPageMixin<T> {
  const FlBasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return getProviderWidget(context);
  }
}
