import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:niku/namespace.dart' as n;

import 'dark_model_logic.dart';

class DarkModelPage extends StatelessWidget {
  final logic = Get.put(DarkModelLogic());
  final state = Get.find<DarkModelLogic>().state;

  DarkModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    logic.configLocalTheme();
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'dark_model'.tr,
      ),
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
      body: n.Column([
        Expanded(
          child: ListView.separated(
            itemBuilder: createItemBuilder,
            separatorBuilder: createSeparatorBuilder,
            itemCount: state.switchValue.value ? 1 : 4,
          ),
        ),
      ]),
    );
  }

  Widget createItemBuilder(BuildContext context, int index) {
    Widget body = Container();
    if (index == 0) {
      body = createFirstWidget(context);
    } else if (index == 1) {
      body = n.Padding(
          left: 20,
          right: 20,
          top: 10,
          bottom: 10,
          child: Text(
            'manually'.tr,
            style: const TextStyle(
              fontSize: 14,
              // color: Colors.black54,
            ),
            // style: FontConfig.fontMedium145a5a5a,
          ));
    } else if (index == 2) {
      body = createDarkItemWidget(
        'normal_model'.tr,
        index,
      );
    } else if (index == 3) {
      body = createDarkItemWidget(
        'dark_model'.tr,
        index,
      );
    }
    return body;
  }

  Widget createSeparatorBuilder(BuildContext context, int index) {
    if (index == 2) {
      return n.Padding(
        left: 20,
        right: 20,
        child: const HorizontalLine(height: 0.5),
      );
    } else {
      return Container();
    }
  }

  // 创建跟随系统
  Widget createFirstWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 15,
        bottom: 15,
      ),
      color: Theme.of(context).colorScheme.surface,
      // color: Colors.white,
      child: n.Row([
        Expanded(
          child: n.Column([
            Text(
              'follow_system'.tr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                // color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            // Gaps.vGap5,
            Text(
              'follow_system_tips'.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w200,
                // color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ])
            ..mainAxisAlignment = MainAxisAlignment.center
            ..crossAxisAlignment = CrossAxisAlignment.start,
        ),
        CupertinoSwitch(
          value: state.switchValue.value,
          dragStartBehavior: DragStartBehavior.down,
          onChanged: (value) {
            logic.configSwitchOnChanged(value);
          },
        )
      ])
        ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
    );
  }

  Widget createDarkItemWidget(String text, int index) {
    return InkWell(
      onTap: () {
        logic.tapDarkItem(index: index);
      },
      child: Container(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 10,
          top: 10,
        ),
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).colorScheme.surface,
        ),
        child: n.Row([
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          state.selectIndex.value == index
              ? const Icon(
                  Icons.check,
                  size: 20,
                  color: Colors.green,
                )
              : Container(),
        ])
          ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
      ),
    );
  }

// @override
// configShowBack() {
//   return isShowBack ?? true;
// }
}
