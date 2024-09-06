import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/service/storage.dart';

import 'language_state.dart';

class LanguageLogic extends GetxController {
  final state = LanguageState();

  void changeLanguage(String lang) async {
    await Jiffy.setLocale(jiffyLocal(lang));

    StorageService.to.setString(Keys.currentLang, lang);
    state.valueChanged.value = false;
    state.currentLanguage.value = lang;

    List<String> code = lang.split("_");
    Get.updateLocale(Locale(code[0], code[1]));
  }

  /// context 上下文
  /// parent 地区父节点数据
  /// model 当前地区节点数据，如果是叶子节点，类型为String；如果非叶子节点类型为Map
  /// callback 有里面有业务逻辑处理
  /// outCallback 递归调用的时候传递最外层的callback
  Widget getListItem(
    BuildContext context,
    Map<String, String> model,
  ) {
    String id = model['id'] ?? '';
    return Obx(
      () => Container(
        height: 52,
        // ignore: sort_child_properties_last
        child: ListTile(
          title: Text(
            model['title'] ?? '',
            style: TextStyle(
              fontSize: state.selectedLanguage.value == id ? 20 : 16,
              // color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          selected: state.selectedLanguage.value == id,
          selectedColor: Theme.of(context).colorScheme.onPrimary,
          trailing: state.selectedLanguage.value == id
              ? const Text(
                  '√',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.green,
                  ),
                )
              : null,
          onTap: () {
            state.selectedLanguage.value = id;
            state.valueChanged.value =
                state.currentLanguage.value == state.selectedLanguage.value
                    ? false
                    : true;
            // regionSelectedTitle(title);
          },
        ),
        // margin: const EdgeInsets.only(left: 16, right: 16),
        // 下边框
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// 获取系统支持的regionCode列表
  /// pkg = intl_phone_number_input
  List<String> regionCodeList(String? pkg) {
    return state.languageList
        .map((lang) => lang['regionCode'] ?? 'CN')
        .toList();
  }
}
