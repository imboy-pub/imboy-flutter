import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../personal_info/personal_info_logic.dart';
import '../update/update_view.dart';

class MoreView extends StatelessWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(PersonalInfoLogic());

    logic.genderTitle.value = UserRepoLocal.to.current.genderTitle;
    logic.sign.value = UserRepoLocal.to.current.sign;
    logic.region.value = UserRepoLocal.to.current.region;
    // ignore: prefer_function_declarations_over_variables
    Function deleteFirst = (String val) {
      List items = val.split(" ");
      // debugPrint("> on deleteFirst ${items.length} ${items.toString()}");
      if (items.length < 3) {
        return val;
      }
      return items[items.length - 2] + " " + items[items.length - 1];
    };
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(automaticallyImplyLeading: true, title: 'more_info'.tr),
      body: n.Column([
        LabelRow(
          title: 'gender'.tr,
          isLine: true,
          lineWidth: Get.isDarkMode ? 0.5 : 1.0,
          isRight: true,
          trailing: Obx(() => Text(
                logic.genderTitle.value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )),
          onPressed: () {
            Get.to(
              () => UpdatePage(
                  title: 'set_param'.trArgs(['gender'.tr]),
                  value: UserRepoLocal.to.current.gender.toString(),
                  field: 'gender',
                  callback: (gender) async {
                    bool ok = await logic.changeInfo({
                      "field": "gender",
                      "value": gender,
                    });
                    if (ok) {
                      Map<String, dynamic> payload =
                          UserRepoLocal.to.current.toMap();
                      payload["gender"] = int.parse(gender);
                      UserRepoLocal.to.changeInfo(payload);
                      logic.genderTitle.value =
                          UserRepoLocal.to.current.genderTitle;
                    }
                    return ok;
                  }),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            )?.then((value) {
              // iPrint(" then $value");
              // if (value != null && value is String) {
              // }
            });
          },
        ),
        LabelRow(
          title: 'region'.tr,
          isLine: true,
          lineWidth: Get.isDarkMode ? 0.5 : 1.0,
          isRight: true,
          trailing: Obx(
            () => Text(
              deleteFirst(logic.region.value),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          onPressed: () {
            Get.to(
              () => UpdatePage(
                  title: 'set_param'.trArgs(['region'.tr]),
                  value: logic.region.value,
                  field: 'region',
                  callback: (region) async {
                    bool ok = await logic
                        .changeInfo({"field": "region", "value": region});
                    if (ok) {
                      Map<String, dynamic> payload =
                          UserRepoLocal.to.current.toMap();
                      payload["region"] = region;
                      UserRepoLocal.to.changeInfo(payload);
                      logic.region.value = region;
                    }
                    return ok;
                  }),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            )?.then((value) {
              // iPrint(" then $value");
              // if (value != null && value is String) {
              // }
            });
          },
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            // backgroundColor: Theme.of(context).colorScheme.surface,
            //取消圆角边框
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
            margin: const EdgeInsets.only(
              left: 20.0,
            ),
            child: n.Row([
              SizedBox(
                child: Text(
                  'signature'.tr,
                  style: const TextStyle(fontSize: 17.0),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                  child: Obx(
                    () => Text(
                      logic.sign.value == ''
                          ? 'not_filled'.tr
                          : logic.sign.value,
                      style: const TextStyle(
                        // color: AppColors.MainTextColor,
                        fontSize: 14.0,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: logic.sign.value == ""
                          ? TextAlign.right
                          : TextAlign.left,
                    ),
                  ),
                ),
              ),
              navigateNextIcon
            ]),
          ),
          onPressed: () {
            Get.to(
              () => UpdatePage(
                  title: 'set_param'.trArgs(['signature'.tr]),
                  value: UserRepoLocal.to.current.sign,
                  field: 'text',
                  callback: (sign) async {
                    bool ok = await logic.changeInfo({
                      "field": "sign",
                      "value": sign,
                    });
                    if (ok) {
                      Map<String, dynamic> payload =
                          UserRepoLocal.to.current.toMap();
                      payload["sign"] = sign;
                      UserRepoLocal.to.changeInfo(payload);
                      logic.sign.value = UserRepoLocal.to.current.sign;
                    }
                    return ok;
                  }),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            )?.then((value) {
              // iPrint(" then $value");
              // if (value != null && value is String) {
              // }
            });
          },
        ),
      ]),
    );
  }
}
