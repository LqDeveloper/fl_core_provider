import 'package:flutter/material.dart';
import 'package:fl_core_provider/fl_core_provider.dart';

import '../base_page_controller.dart';

class UpdatePage extends FlBasePage<UpdatePageController> {
  const UpdatePage({super.key});

  @override
  UpdatePageController createController(BuildContext context) {
    return UpdatePageController();
  }

  @override
  Widget buildWithController(
      BuildContext context, UpdatePageController controller) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UpdatePage'),
      ),
      body: Center(
        child: FlSelectorIds<UpdatePageEvent, UpdatePageController>(
            ids: const [UpdatePageEvent.update],
            builder: (_, controller, __) {
              return Text('当前的值是：${controller.count}');
            }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.increase(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum UpdatePageEvent { update }

class UpdatePageController extends BasePageController<UpdatePageEvent> {
  @override
  List<UpdatePageEvent> get shouldNotifyIds => UpdatePageEvent.values;

  int _count = 0;

  int get count => _count;

  void increase() {
    _count++;
    notifySingleListener(UpdatePageEvent.update);
  }
}
