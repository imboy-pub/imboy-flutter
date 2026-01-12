import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'dark_model_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

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
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.darkModel,
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
              t.followSystem,
              style: const TextStyle(fontSize: 16),
            ),
            subtitle: Text(
              t.followSystemTips,
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
                          t.normalModel,
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
                          t.darkModel,
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
        ],
      ),
    );
  }
}
