import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'dark_model_logic.dart';

/// 深色模式页面
class DarkModelPage extends StatelessWidget {
  final logic = Get.put(DarkModelLogic());
  final state = Get.find<DarkModelLogic>().state;

  DarkModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    logic.configLocalTheme();

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'darkModel'.tr,
      ),
      backgroundColor: colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 跟随系统设置
          ListTile(
            leading: Icon(
              Icons.brightness_auto,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            title: Text(
              'followSystem'.tr,
              style: const TextStyle(fontSize: 16),
            ),
            subtitle: Text(
              'followSystemTips'.tr,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Obx(
              () => CupertinoSwitch(
                value: state.switchValue.value,
                onChanged: (value) {
                  logic.configSwitchOnChanged(value);
                },
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),

          // 分隔线
          Obx(
            () => state.switchValue.value
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
          ),

          // 主题选择
          Obx(
            () => state.switchValue.value
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      // 浅色主题
                      ListTile(
                        leading: Icon(
                          Icons.light_mode_outlined,
                          color: state.selectIndex.value == 2
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        title: Text(
                          'normalModel'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            color: state.selectIndex.value == 2
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        trailing: state.selectIndex.value == 2
                            ? Icon(
                                Icons.check,
                                color: colorScheme.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => logic.tapDarkItem(index: 2),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 8),

                      // 深色主题
                      ListTile(
                        leading: Icon(
                          Icons.dark_mode_outlined,
                          color: state.selectIndex.value == 3
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        title: Text(
                          'darkModel'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            color: state.selectIndex.value == 3
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        trailing: state.selectIndex.value == 3
                            ? Icon(
                                Icons.check,
                                color: colorScheme.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () => logic.tapDarkItem(index: 3),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
          ),

          // OLED模式和护眼模式设置
          /*
          Obx(
            () => state.selectIndex.value == 3
                ? Column(
                    children: [
                      const SizedBox(height: 24),
                      
                      // 分隔线
                      Divider(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 深色模式增强选项标题
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '深色模式增强',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // OLED优化模式
                      ListTile(
                        leading: Icon(
                          Icons.smartphone,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        title: const Text(
                          'OLED优化模式',
                          style: TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          '为OLED屏幕优化，使用纯黑背景节省电量',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Obx(
                             () {
                               final themeManager = Get.find<ThemeManager>();
                               return CupertinoSwitch(
                                 value: themeManager.themeSettings.isOLEDMode,
                                 onChanged: (value) {
                                   themeManager.toggleOLEDMode();
                                 },
                               );
                             },
                           ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 护眼模式
                      ListTile(
                        leading: Icon(
                          Icons.remove_red_eye_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        title: const Text(
                          '护眼模式',
                          style: TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          '减少蓝光，使用暖色调保护视力',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Obx(
                             () {
                               final themeManager = Get.find<ThemeManager>();
                               return CupertinoSwitch(
                                 value: themeManager.themeSettings.isEyeCareMode,
                                 onChanged: (value) {
                                   themeManager.toggleEyeCareMode();
                                 },
                               );
                             },
                           ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          */
        ],
      ),
    );
  }
}
