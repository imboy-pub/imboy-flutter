import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'language_logic.dart';
import 'language_state.dart';

class LanguagePage extends StatelessWidget {
  final LanguageLogic logic = Get.put(LanguageLogic());
  final LanguageState state = Get.find<LanguageLogic>().state;

  LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    state.currentLanguage.value =
        StorageService.to.getString(Keys.currentLang) ?? 'zh_CN';
    state.selectedLanguage.value =
        StorageService.to.getString(Keys.currentLang) ?? 'zh_CN';
    return Scaffold(
      // backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        titleWidget: n.Row([
          Expanded(
            child: Text(
              'language_setting'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 中间用Expanded控件
          ),
          Obx(
            () => ElevatedButton(
              onPressed: () async {
                logic.changeLanguage(state.selectedLanguage.value);
              },
              // ignore: sort_child_properties_last
              child: n.Padding(
                  left: 10,
                  right: 10,
                  child: Text(
                    'button_accomplish'.tr,
                    textAlign: TextAlign.center,
                  )),
              style: state.valueChanged.isTrue
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        // Theme.of(context).colorScheme.background,
                        Colors.green,
                      ),
                      foregroundColor: MaterialStateProperty.all<Color>(
                        Colors.white,
                      ),
                      // minimumSize:
                      //     MaterialStateProperty.all(const Size(88, 40)),
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
                      // minimumSize:
                      //     MaterialStateProperty.all(const Size(88, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
            ),
          ),
        ]),
      ),
      body: n.Column([
        Expanded(
          child: ListView.builder(
            itemBuilder: (BuildContext context, int index) {
              var model = state.languageList[index];
              return logic.getListItem(context, model);
            },
            itemCount: state.languageList.length,
          ),
        ),
      ], mainAxisSize: MainAxisSize.min)
        ..useParent((v) => v..bg = Theme.of(context).colorScheme.background),
    );
  }
}
