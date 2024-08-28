import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';

import 'people_info_more_logic.dart';
import 'people_info_same_group_view.dart';

// ignore: must_be_immutable
class PeopleInfoMorePage extends StatelessWidget {
  final String id; // 用户ID
  PeopleInfoMorePage({
    super.key,
    required this.id,
  });

  final logic = Get.put(PeopleInfoMoreLogic());
  final state = Get.find<PeopleInfoMoreLogic>().state;

  Future<void> initData() async {
    logic.initData(id);
  }

  @override
  Widget build(BuildContext context) {
    initData();
    // bool isSelf = UserRepoLocal.to.currentUid == id;
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'social_profile'.tr,
        // backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Obx(
          () => n.Column([
            LabelRow(
              title: 'mutual_groups_with_her'.tr,
              // 10个
              rValue: 'num_unit'.trArgs(['${state.groupCount}']),
              isLine: true,
              lineWidth: 1.0,
              isRight: state.groupCount.value > 0 ? true : false,
              padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
              margin: const EdgeInsets.only(bottom: 10.0),
              onPressed: () {
                if (state.groupCount.value > 0) {
                  Get.to(
                    () => PeopleInfoSameGroupPage(
                      groupList: state.sameGroupList.value,
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                }
              },
            ),
            Visibility(
              visible: strNoEmpty(state.sign.value),
              child: LabelRow(
                title: 'signature'.tr,
                // rValue: sign,
                trailing: SizedBox(
                  width: Get.width - 100,
                  child: n.Row([
                    const SizedBox(width: 20),
                    // use Expanded only within a Column, Row or Flex
                    Expanded(
                        child: Text(
                      state.sign.value,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ))
                  ]),
                ),
                isLine: true,
                lineWidth: 1.0,
                isRight: false,
                isSpacer: false,
                // onPressed: () => Get.to(()=> const FriendCirclePage()),
              ),
            ),
            if (state.source.value.isNotEmpty)
              LabelRow(
                title: 'source'.tr,
                rValue: '${state.sourcePrefix.value} ${state.source.value}',
                // rValue: getSourceTr(source.value),
                isLine: true,
                lineWidth: 1.0,
                isRight: false,
                onPressed: () {},
              ),
          ]),
        ),
      ),
    );
  }
}
