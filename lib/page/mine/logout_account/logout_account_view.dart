import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/single/markdown.dart';

import 'logout_account_logic.dart';

// ignore: must_be_immutable
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
      body: Column(
        children: [
          LimitedBox(
            maxHeight: Get.height - 110, // 设置最大高度限制
            child: MarkdownPage(
              title: 'logoutAccount'.tr,
              url:
                  "https://imboy.pub/doc/notice_of_cancellation_$lang.md?vsn=$appVsn",
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Obx(
                () => Radio(
                  value: state.selectedValue.value,
                  groupValue: 'read_and_agree',
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (String? value) {
                    iPrint('read_and_agree val $value;');
                    logic.changeValue(state.selectedValue.value);
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: InkWell(
                  child: Text(
                    'readAgreeParam'.trArgs(['logoutNotice'.tr]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                  ),
                  onTap: () {
                    logic.changeValue(state.selectedValue.value);
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundedElevatedButton(
                text: 'applyParam'.trArgs(['buttonLogout'.tr]),
                highlighted: true,
                size: Size(Get.width - 200, 48),
                onPressed: () async {
                  if (state.selectedValue.value != 'read_and_agree') {
                    EasyLoading.showInfo(
                      '${'readAgreeParam'.trArgs(['logoutNotice'.tr])} ?',
                    );
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
            ],
          ),
        ],
      ),
    );
  }
}
