import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/theme.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';

import 'select_region_logic.dart';

// ignore: must_be_immutable
class SelectRegionPage extends StatelessWidget {
  String parent;
  List children;

  final Future<bool> Function(String, String) callback;
  final Future<bool> Function(String) outCallback;

  SelectRegionPage({
    super.key,
    required this.parent,
    required this.children,
    required this.callback,
    required this.outCallback,
  });

  final logic = Get.put(SelectRegionLogic(), tag: "SelectRegionPage");

  // SelectRegionLogic logic = Get.find();

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      logic.valueOnChange(false);
    });
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        titleWidget: n.Row([
          Expanded(
            child: Text(
              'set_region'.tr,
              textAlign: TextAlign.center,
              style: AppStyle.navAppBarTitleStyle,
            ),
            // 中间用Expanded控件
          ),
          Obx(
            () => ElevatedButton(
              onPressed: () async {
                var nav = Navigator.of(context);
                bool res = await outCallback(logic.selectedVal.value);
                // iPrint("logic.selectedVal.value ${logic.selectedVal.value}");
                if (res) {
                  int t = logic.selectedVal.value.split(" ").length;
                  // iPrint("logic.selectedVal.value $t");
                  for (var i = 0; i < t; i++) {
                    nav.pop();
                  }
                }
              },
              // ignore: sort_child_properties_last
              child: n.Padding(
                  left: 10,
                  right: 10,
                  child: Text(
                    'button_accomplish'.tr,
                    textAlign: TextAlign.center,
                  )),
              style: logic.valueChanged.isTrue
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        Colors.green,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        Colors.white,
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    )
                  : ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        Colors.green.withOpacity(0.6),
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        Colors.white.withOpacity(0.6),
                      ),
                      minimumSize:
                          MaterialStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
            ),
          ),
        ]),
      ),
      body: n.Column([
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 34.0),
          width: Get.width,
          height: 40.0,
          child: Obx(() => Text(
                logic.selectedVal.value.isEmpty
                    ? 'all'.tr
                    : logic.selectedVal.value,
                style: const TextStyle(fontSize: 12),
              )),
        ),
        Expanded(
          child: ListView.builder(
            itemBuilder: (BuildContext context, int index) {
              return logic.getListItem(
                context: context,
                parent: parent,
                model: children[index],
                callback: (a, b) async {
                  return true;
                },
                outCallback: outCallback,
                margin: const EdgeInsets.only(left: 16, right: 16),
              );
            },
            itemCount: children.length,
          ),
        ),
      ])
        // ..mainAxisSize = MainAxisSize.min
        ..useParent((v) => v..bg = Theme.of(context).colorScheme.background),
    );
  }
}
