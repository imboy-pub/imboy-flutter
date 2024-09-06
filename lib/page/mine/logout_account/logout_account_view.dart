import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/single/markdown.dart';

import 'logout_account_logic.dart';

class LogoutAccountPage extends StatelessWidget {
  LogoutAccountPage({super.key});

  final logic = Get.put(LogoutAccountLogic());
  final state = Get.find<LogoutAccountLogic>().state;

  String lang = 'cn';

  @override
  Widget build(BuildContext context) {
    String code = sysLang('').toLowerCase();
    // notice_of_cancellation 目前只配置 cn ru en 3个文件
    if (code.contains('en')) {
      lang = 'en';
    } else if (code.contains('ru')) {
      lang = 'ru';
    }
    return Scaffold(
        body: n.Column([
      LimitedBox(
        maxHeight: Get.height - 110, // 设置最大高度限制
        child: MarkdownPage(
          title: 'logout_account'.tr,
          url: "https://imboy.pub/doc/notice_of_cancellation_$lang.md?vsn=$appVsn",
        ),
      ),
      n.Row([
        Obx(() => Radio(
              value: state.selectedValue.value,
              groupValue: 'read_and_agree',
              activeColor: Colors.green, // 设置选中时的颜色
              onChanged: (String? value) {
                iPrint('read_and_agree val $value;');
                logic.changeValue(state.selectedValue.value);
              },
            )),
        SizedBox(
          width: 220,
          child: InkWell(
              child: Text(
                'read_agree_param'.trArgs(['logout_notice'.tr]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
              onTap: () {
                logic.changeValue(state.selectedValue.value);
              }),
        ),
      ])
        // 内容居中
        ..mainAxisAlignment = MainAxisAlignment.center,
      n.Row([
        RoundedElevatedButton(
          text: 'apply_param'.trArgs(['button_logout'.tr]),
          highlighted: true,
          size: Size(Get.width - 200, 48),
          onPressed: () async {
            if (state.selectedValue.value != 'read_and_agree') {
              EasyLoading.showInfo(
                  '${'read_agree_param'.trArgs(['logout_notice'.tr])} ?');
              return;
            }
            bool res = await logic.applyLogout();
            if (res) {
              UserRepoLocal.to.quitLogin();
              Get.offAll(() => const LoginPage());
            }
          },
          // child: const Icon(Icons.volume_up),
        ),
      ])
        // 内容居中
        ..mainAxisAlignment = MainAxisAlignment.center
    ]));
  }
}
