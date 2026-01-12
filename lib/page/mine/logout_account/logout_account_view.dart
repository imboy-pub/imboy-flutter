import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/single/markdown.dart';

import 'logout_account_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

// ignore: must_be_immutable
class LogoutAccountPage extends StatelessWidget {
  LogoutAccountPage({super.key});

  final logic = Get.put(LogoutAccountLogic());
  final state = Get.find<LogoutAccountLogic>().state;

  String lang = 'cn';

  @override
  Widget build(BuildContext context) {
    String code = LocaleHelper.sysLang('').toLowerCase();
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
              title: t.logoutAccount,
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
                    t.readAgreeParam.replaceAll('{s}', t.logoutNotice),
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
                text: t.applyParam.replaceAll('{s}', t.buttonLogout),
                highlighted: true,
                size: Size(Get.width - 200, 48),
                onPressed: () async {
                  iPrint("> 退出登录按钮点击");
                  if (state.selectedValue.value != 'read_and_agree') {
                    iPrint("> 用户未同意退出协议，selectedValue: ${state.selectedValue.value}");
                    EasyLoading.showInfo(
                      '${t.readAgreeParam.replaceAll('{s}', t.logoutNotice)} ?',
                    );
                    return;
                  }

                  iPrint("> 用户已同意退出协议，开始执行退出逻辑");
                  try {
                    EasyLoading.show(status: '退出登录中...');

                    // 测试：直接清除用户ID并跳转
                    iPrint("> 开始清除用户ID");
                    await StorageService.to.remove(Keys.currentUid);
                    iPrint("> 用户ID清除完成");

                    // 简单检查登录状态
                    bool isLoggedIn = UserRepoLocal.to.isLoggedIn;
                    iPrint("> 当前登录状态: $isLoggedIn");

                    EasyLoading.dismiss();

                    if (!isLoggedIn) {
                      iPrint("> 用户已退出，跳转到登录页面");
                      Get.offAllNamed(AppRoutes.signIn);
                    } else {
                      iPrint("> 用户状态异常，强制跳转");
                      Get.offAll(() => const LoginPage());
                    }
                  } catch (e) {
                    iPrint("> 退出登录过程异常: $e");
                    EasyLoading.dismiss();
                    // 即使出错也强制跳转
                    Get.offAll(() => const LoginPage());
                  }
                },
                // child: const Icon(Icons.volume_up),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  iPrint("> 测试直接跳转按钮点击");
                  Get.offAll(() => const LoginPage());
                },
                child: Text('测试直接跳转'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
