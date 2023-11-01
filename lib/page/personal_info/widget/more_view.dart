import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
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
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(title: "更多信息".tr),
      body: Column(children: [
        LabelRow(
          label: '性别'.tr,
          isLine: true,
          isRight: true,
          rightW: Obx(() => Text(logic.genderTitle.value)),
          onPressed: () => Get.bottomSheet(
            UpdatePage(
                title: '设置性别'.tr,
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
            backgroundColor: Colors.white,
            // 是否支持全屏弹出，默认false
            isScrollControlled: true,
            enableDrag: false,
          ),
        ),
        LabelRow(
          label: '地区'.tr,
          isLine: true,
          isRight: true,
          rightW: Obx(() => Text(deleteFirst(logic.region.value))),
          onPressed: () => Get.bottomSheet(
            UpdatePage(
                title: '设置地区'.tr,
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
            backgroundColor: Colors.white,
            // 是否支持全屏弹出，默认false
            isScrollControlled: true,
            enableDrag: false,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
            margin: const EdgeInsets.only(
              left: 20.0,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  child: Text(
                    '个性签名'.tr,
                    style: const TextStyle(fontSize: 17.0),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                    child: Obx(
                      () => Text(
                        logic.sign.value == "" ? "未填写" : logic.sign.value,
                        style: const TextStyle(
                          color: AppColors.MainTextColor,
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
                Icon(
                  CupertinoIcons.right_chevron,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                )
              ],
            ),
          ),
          onPressed: () => Get.bottomSheet(
            UpdatePage(
                title: '设置个性签名'.tr,
                value: UserRepoLocal.to.current.sign,
                field: 'text',
                callback: (sign) async {
                  bool ok =
                      await logic.changeInfo({"field": "sign", "value": sign});
                  if (ok) {
                    Map<String, dynamic> payload =
                        UserRepoLocal.to.current.toMap();
                    payload["sign"] = sign;
                    UserRepoLocal.to.changeInfo(payload);
                    logic.sign.value = UserRepoLocal.to.current.sign;
                  }
                  return ok;
                }),
            backgroundColor: Colors.white,
            // 是否支持全屏弹出，默认false
            isScrollControlled: true,
            enableDrag: false,
          ),
        ),
      ]),
    );
  }
}
