import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/mine/account_security/account_security_view.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/page/mine/dark_model/dark_model_view.dart';
import 'package:imboy/page/mine/language/language_view.dart';
import 'package:imboy/page/mine/font_size/font_size_view.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/store/provider/app_version_provider.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/single/markdown.dart';

import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'setting_logic.dart';

/// 设置页面 - 使用优化后的主题系统

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final logic = Get.put(SettingLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 使用主题表面色
      appBar: NavAppBar(automaticallyImplyLeading: true, title: 'setting'.tr),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 设置分组容器 - 使用优化后的主题样式
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(0), // 保持原有的方形设计
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.02),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 账户安全 - 使用优化后的主题样式
                  _buildSettingItem(
                    context,
                    title: 'account_security'.tr,
                    leadingIcon: Icons.security,
                    leadingIconColor: AppColors.warning,
                    onTap: () {
                      Get.to(
                        () => AccountSecurityPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),

                  const ModernDivider(height: 8),

                  // 语言设置 - 使用优化后的主题样式
                  _buildSettingItem(
                    context,
                    title: 'language_setting'.tr,
                    leadingIcon: Icons.language,
                    leadingIconColor: AppColors.info,
                    onTap: () {
                      Get.to(
                        () => LanguagePage(),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),

                  // 分割线 - 使用优化后的主题样式
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  // 深色模式 - 使用优化后的主题样式
                  _buildSettingItem(
                    context,
                    title: 'dark_model'.tr,
                    value: logic.themeTypeTips(),
                    leadingIcon: Icons.dark_mode,
                    leadingIconColor: AppColors.textSecondary,
                    onTap: () {
                      Get.to(
                        () => DarkModelPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),

                  // 分割线 - 使用优化后的主题样式
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),

                  // 字体大小 - 使用优化后的主题样式
                  _buildSettingItem(
                    context,
                    title: '字体大小',
                    value:
                        ThemeManager.instance.fontSizeOption.displayName,
                    leadingIcon: Icons.text_fields,
                    leadingIconColor: AppColors.success,
                    onTap: () {
                      Get.to(
                        () => const FontSizePage(),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),
                ],
              ),
            ),

            const ModernDivider(height: 8),

            // 隐私设置分组 - 使用优化后的主题样式
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(0), // 保持原有的方形设计
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.02),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 允许搜索我 - 使用优化后的主题样式
                  Obx(
                    () => _buildSwitchItem(
                      context,
                      title: 'allow_search_me'.tr,
                      subtitle: '其他用户可以通过搜索找到我',
                      value: logic.allowSearch.value,
                      leadingIcon: Icons.search,
                      leadingIconColor: AppColors.info,
                      onChanged: (v) async {
                        iPrint("allowSearch v $v;");
                        bool res = await UserProvider().allowSearch(v ? 1 : 2);
                        iPrint("allowSearch res $res;");

                        if (res) {
                          UserRepoLocal.to.setting.allowSearch = v;
                          UserRepoLocal.to.changeSetting(
                            UserRepoLocal.to.setting,
                          );
                          logic.allowSearch.value = v;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const ModernDivider(height: 8),

            // 帮助和关于分组 - 使用优化后的主题样式
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(0), // 保持原有的方形设计
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.02),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 更新日志 - 使用优化后的主题样式
                  _buildSettingItem(
                    context,
                    title: 'update_log'.tr,
                    leadingIcon: Icons.update,
                    leadingIconColor: AppColors.success,
                    onTap: () {
                      Get.to(
                        () => MarkdownPage(
                          title: 'update_log'.tr,
                          url:
                              "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),

                  // 分割线 - 使用优化后的主题样式
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),

                  // 帮助文档 - 使用优化后的主题样式
                  _buildSettingItem(
                    context,
                    title: 'help_document'.tr,
                    leadingIcon: Icons.help_outline,
                    leadingIconColor: AppColors.info,
                    onTap: () {
                      Get.to(
                        () => MarkdownPage(
                          title: 'help_document'.tr,
                          url:
                              "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/help_document.md",
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),

                  // 分割线 - 使用优化后的主题样式
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: HorizontalLine(
                      height: 0.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  // 关于应用 - 使用优化后的主题样式
                  _buildSettingItem(
                    context,
                    title: 'about_app'.tr,
                    value: "${'version'.tr} $appVsn",
                    leadingIcon: Icons.info_outline,
                    leadingIconColor: AppColors.primaryGreen,
                    onTap: () {
                      final rightDMActions = [
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 10,
                            top: 10,
                            bottom: 10,
                          ),
                          child: RoundedElevatedButton(
                            text: 'check_for_updates'.tr,
                            highlighted: true,
                            onPressed: () async {
                              final AppVersionProvider p = AppVersionProvider();
                              final navigator = Navigator.of(context);
                              final Map<String, dynamic> info = await p.check(
                                appVsn,
                              );
                              final String downLoadUrl =
                                  info['download_url'] ?? '';
                              bool updatable = info['updatable'] ?? false;
                              updatable = downLoadUrl.isEmpty
                                  ? false
                                  : updatable;
                              if (updatable) {
                                await navigator.push(
                                  CupertinoPageRoute(
                                    // "右滑返回上一页"功能
                                    builder: (_) => UpgradePage(
                                      version: info['vsn'],
                                      downLoadUrl: downLoadUrl,
                                      message: info['description'] ?? '',
                                      isForce: 1 == (info['force_update'] ?? 2)
                                          ? true
                                          : false,
                                    ),
                                  ),
                                );
                              } else {
                                EasyLoading.showInfo('now_new_version'.tr);
                              }
                            },
                          ),
                        ),
                      ];
                      Get.to(
                        () => MarkdownPage(
                          title: "${'about'.tr} $appName",
                          rightDMActions: rightDMActions,
                          url:
                              "https://gitee.com/imboy-pub/imboy-flutter/raw/main/README.md",
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),
                ],
              ),
            ),

            // 开发环境切换 - 仅在非生产环境显示
            if (currentEnv != 'pro') ...[
              const ModernDivider(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: _buildSettingItem(
                    context,
                    title: 'switch_environment'.tr,
                    leadingIcon: Icons.developer_mode,
                    leadingIconColor: AppColors.lightError,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightError.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20), // 使用更大的圆角
                        border: Border.all(
                          color: AppColors.lightError.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                             value: currentEnv.isEmpty ? 'dev' : currentEnv, // 确保值不为空且在选项中存在
                             isDense: true,
                             style: ThemeManager.instance.getTextStyle(
                               FontSizeType.small,
                               color: AppColors.lightError,
                               fontWeight: FontWeight.w600,
                             ),
                             items: const [
                               DropdownMenuItem(
                                 value: 'local',
                                 child: Text('Local'),
                               ),
                               DropdownMenuItem(
                                 value: 'dev',
                                 child: Text('Development'),
                               ),
                               DropdownMenuItem(
                                 value: 'pro',
                                 child: Text('Production'),
                               ),
                             ],
                             onChanged: (String? value) {
                               if (strNoEmpty(value)) {
                                 currentEnv = value!;
                                 logic.switchEnvironment(currentEnv);
                               }
                             },
                             icon: Icon(
                               Icons.arrow_drop_down,
                               color: AppColors.lightError,
                             ),
                           ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20), // 底部间距
          ],
        ),
      ),
    );
  }

  /// 构建设置项 - 使用优化后的主题样式
  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? value,
    IconData? leadingIcon,
    Color? leadingIconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // 前导图标 - 使用优化后的主题样式
              if (leadingIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (leadingIconColor ?? AppColors.primaryGreen)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    leadingIcon,
                    color: leadingIconColor ?? AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // 主要内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.normal,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface, // 使用主题文字色
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.small,
                          color: AppColors.textSecondary, // 使用主题次要文字色
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 值显示
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value,
                  style: ThemeManager.instance.getTextStyle(
                    FontSizeType.normal,
                    color: AppColors.textSecondary, // 使用主题次要文字色
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // 尾部组件
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.navigate_next,
                  color: AppColors.textSecondary, // 使用主题次要文字色
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建开关设置项 - 使用优化后的主题样式
  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? leadingIcon,
    Color? leadingIconColor,
  }) {
    return _buildSettingItem(
      context,
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      leadingIconColor: leadingIconColor,
      trailing: SizedBox(
        height: 32.0,
        child: CupertinoSwitch(value: value, onChanged: onChanged),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<SettingLogic>();
    super.dispose();
  }
}
