import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/single/markdown.dart';
import 'package:imboy/service/app_upgrade_service.dart';
import 'package:imboy/modules/security_privacy/public.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 允许搜索状态的 Provider - 使用 Provider 从存储中读取值
final allowSearchProvider = Provider<bool>((ref) {
  final settingData = StorageService.to.getString('setting');
  if (settingData.isNotEmpty) {
    try {
      final settingMap = jsonDecode(settingData) as Map<String, dynamic>;
      return (settingMap['allow_search'] ?? true) as bool;
    } on Exception {
      return true;
    }
  }
  return true;
});

/// 设置页面 - 使用 Riverpod + 优化后的主题系统
class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  // 防抖状态
  bool _isUpdatingAllowSearch = false;
  bool _isRefreshingKeys = false;

  /// 获取主题类型提示文字
  String themeTypeTips(WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // 跟随系统
    if (themeMode == ThemeMode.system) {
      return t.followSystem;
    }

    // 深色模式
    if (themeState.isDarkMode) {
      return t.enabled;
    }

    // 浅色模式
    return t.disabled;
  }

  /// 切换环境
  Future<void> switchEnvironment(String env) async {
    final storage = StorageService.to;
    await storage.setString('env', env);
    await storage.setBool('changedEnv', true);
    await UserRepoLocal.to.quitLogin();
    // 重启应用
    _restartApp();
  }

  /// 重启应用
  void _restartApp() {
    if (kDebugMode) iPrint("packageName $packageName");
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text(t.restartRequired),
            content: Text(t.applyChanges),
            actions: <Widget>[
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  exit(0);
                },
                child: Text(t.buttonConfirm),
              ),
            ],
          );
        },
      );
    }
  }

  /// 规范化环境值，将所有 local 变体映射到 'local'
  String _normalizeEnvValue(String env) {
    if (env.isEmpty) {
      return 'dev'; // 默认值
    }
    // 将 local_home 和 local_office 都映射为 local
    if (env == 'local_home' || env == 'local_office') {
      return 'local';
    }
    return env;
  }

  @override
  Widget build(BuildContext context) {
    final allowSearch = ref.watch(allowSearchProvider);
    final userRepo = ref.watch(userRepoProvider);
    final themeState = ref.watch(themeProvider);

    // iOS 原生感：分组列表页背景（详见 DESIGN.md 第 8.3 节 Inset Grouped List）
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: GlassAppBar(automaticallyImplyLeading: true, title: t.setting),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, t.sectionGeneral),
            Container(
              // iOS 原生感：Inset Grouped Cell 容器（无阴影、仅圆角）
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusCell,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 账户安全
                  _buildSettingItem(
                    context,
                    title: t.accountSecurity,
                    leadingIcon: Icons.security,
                    leadingIconColor: AppColors.warning,
                    onTap: () {
                      context.push('/account_security');
                    },
                  ),

                  _buildDivider(context),

                  // 语言设置
                  _buildSettingItem(
                    context,
                    title: t.languageSetting,
                    leadingIcon: Icons.language,
                    leadingIconColor: AppColors.info,
                    onTap: () {
                      context.push('/language');
                    },
                  ),

                  _buildDivider(context),

                  // 深色模式
                  _buildSettingItem(
                    context,
                    title: t.darkModel,
                    value: themeTypeTips(ref),
                    leadingIcon: Icons.dark_mode,
                    leadingIconColor: AppColors.textSecondary,
                    onTap: () {
                      context.push('/dark_model');
                    },
                  ),

                  _buildDivider(context),

                  // 字体大小
                  _buildSettingItem(
                    context,
                    title: t.fontSettings,
                    value: themeState.fontSizeOption.displayName,
                    leadingIcon: Icons.text_fields,
                    leadingIconColor: AppColors.success,
                    onTap: () {
                      context.push('/font_size');
                    },
                  ),
                ],
              ),
            ),

            _buildSectionHeader(context, t.sectionPrivacySecurity),
            Container(
              // iOS 原生感：Inset Grouped Cell 容器（无阴影、仅圆角）
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusCell,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 允许搜索我
                  _buildSwitchItem(
                    context,
                    title: t.allowSearchMe,
                    subtitle: t.otherUsersCanFindMe,
                    value: allowSearch,
                    leadingIcon: Icons.search,
                    leadingIconColor: AppColors.info,
                    onChanged: _isUpdatingAllowSearch
                        ? null
                        : (v) async {
                            if (kDebugMode) iPrint("allowSearch v $v;");

                            // 防抖：设置更新状态
                            setState(() => _isUpdatingAllowSearch = true);

                            try {
                              // 使用 userApiProvider 调用 API
                              final userApi = ref.read(userApiProvider);
                              bool res = await userApi.allowSearch(v ? 1 : 2);
                              if (kDebugMode) iPrint("allowSearch res $res;");

                              if (res) {
                                // 修复：先保存当前 setting，创建新对象后再保存
                                final currentSetting = userRepo.setting;
                                final newSetting = UserSettingModel(
                                  allowSearch: v,
                                  peopleNearbyVisible:
                                      currentSetting.peopleNearbyVisible,
                                  chatState: currentSetting.chatState,
                                  fontSize: currentSetting.fontSize,
                                  enableVisibilityRead:
                                      currentSetting.enableVisibilityRead,
                                  visibilityReadFraction:
                                      currentSetting.visibilityReadFraction,
                                  visibilityReadDelayMs:
                                      currentSetting.visibilityReadDelayMs,
                                  showOnlineStatus:
                                      currentSetting.showOnlineStatus,
                                  allowAddByPhone:
                                      currentSetting.allowAddByPhone,
                                  allowAddByQR: currentSetting.allowAddByQR,
                                );
                                await userRepo.changeSetting(newSetting);
                                // allowSearchProvider 会自动从存储中读取最新值
                                // 触发 userRepoProvider 失效以刷新 UI
                                ref.invalidate(userRepoProvider);
                              } else {
                                // API 调用失败，显示错误提示
                                if (context.mounted) {
                                  EasyLoading.showError(t.tipFailed);
                                }
                              }
                            } finally {
                              // 恢复更新状态
                              if (mounted) {
                                setState(() => _isUpdatingAllowSearch = false);
                              }
                            }
                          },
                  ),

                  // 刷新设备密钥
                  _buildSettingItem(
                    context,
                    title: t.refreshDeviceKey,
                    subtitle: t.refreshDeviceKeyHint,
                    leadingIcon: Icons.refresh,
                    leadingIconColor: AppColors.info,
                    onTap: _isRefreshingKeys
                        ? null
                        : () async {
                            // 防抖：设置刷新状态
                            setState(() => _isRefreshingKeys = true);

                            try {
                              EasyLoading.showToast(t.refreshingDeviceKey);
                              // 清除E2EE缓存
                              E2EEService.clearCache();
                              await Future<dynamic>.delayed(
                                const Duration(milliseconds: 500),
                              );

                              // 重新预加载当前用户的设备密钥
                              final currentUid = UserRepoLocal.to.currentUid;
                              if (currentUid.isNotEmpty) {
                                await E2EEService.getUserDevicePublicKeys(
                                  currentUid,
                                );
                              }

                              EasyLoading.showSuccess(t.deviceKeyRefreshed);
                              if (kDebugMode) iPrint('E2EE: 设备密钥已手动刷新');
                            } on Exception catch (e) {
                              EasyLoading.showError(t.tipFailed);
                              if (kDebugMode) {
                                iPrint('E2EE: 刷新设备密钥失败: ${e.runtimeType}');
                              }
                            } finally {
                              // 恢复刷新状态
                              if (mounted) {
                                setState(() => _isRefreshingKeys = false);
                              }
                            }
                          },
                  ),

                  _buildDivider(context),

                  // E2EE 密钥恢复
                  _buildSettingItem(
                    context,
                    title: t.e2eeKeyManagement,
                    subtitle: t.e2eeKeyManagementSubtitle,
                    leadingIcon: Icons.vpn_key,
                    leadingIconColor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<dynamic>(
                          builder: (_) => const E2EEKeyRecoveryPage(),
                        ),
                      );
                    },
                  ),

                  // 开发者测试（仅调试模式）
                  if (kDebugMode)
                    _buildSettingItem(
                      context,
                      title: 'E2EE 开发测试',
                      subtitle: '快速验证 E2EE 功能',
                      leadingIcon: Icons.science,
                      leadingIconColor: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute<dynamic>(
                            builder: (_) => const E2EEDevTestPage(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            _buildSectionHeader(context, t.sectionHelpAbout),
            Container(
              // iOS 原生感：Inset Grouped Cell 容器（无阴影、仅圆角）
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusCell,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 更新日志
                  _buildSettingItem(
                    context,
                    title: t.updateLog,
                    leadingIcon: Icons.update,
                    leadingIconColor: AppColors.success,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<dynamic>(
                          builder: (_) => MarkdownPage(
                            title: t.updateLog,
                            url:
                                "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/changelog.md",
                          ),
                        ),
                      );
                    },
                  ),

                  _buildDivider(context),

                  // 帮助文档
                  _buildSettingItem(
                    context,
                    title: t.helpDocument,
                    leadingIcon: Icons.help_outline,
                    leadingIconColor: AppColors.info,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<dynamic>(
                          builder: (_) => MarkdownPage(
                            title: t.helpDocument,
                            url:
                                "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/FAQ.md",
                          ),
                        ),
                      );
                    },
                  ),

                  _buildDivider(context),

                  // 隐私政策
                  _buildSettingItem(
                    context,
                    title: t.privacyPolicy,
                    leadingIcon: Icons.privacy_tip_outlined,
                    leadingIconColor: AppColors.warning,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<dynamic>(
                          builder: (_) => MarkdownPage(
                            title: t.privacyPolicy,
                            url:
                                "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/privacy-policy.md",
                          ),
                        ),
                      );
                    },
                  ),

                  _buildDivider(context),

                  // 关于应用
                  _buildSettingItem(
                    context,
                    title: t.aboutApp,
                    value: "${t.version} $appVsn",
                    leadingIcon: Icons.info_outline,
                    leadingIconColor: AppColors.primary,
                    trailing: AppUpgradeService.to.hasUpdate
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // iOS 原生未读红点（iosRed）
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.iosRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                CupertinoIcons.chevron_right,
                                color: AppColors.iosGray,
                                size: 14,
                              ),
                            ],
                          )
                        : null,
                    onTap: () {
                      _showAboutDialog();
                    },
                  ),
                ],
              ),
            ),

            // 开发环境切换 - 仅在非生产环境显示
            if (currentEnv != 'pro') ...[
              const SizedBox(height: 8),
              Container(
                // iOS 原生感：开发环境 Cell 容器（无阴影）
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: AppRadius.borderRadiusCell,
                ),
                child: _buildSettingItem(
                  context,
                  title: t.switchEnvironment,
                  leadingIcon: Icons.developer_mode,
                  leadingIconColor: AppColors.lightError,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightError.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusLarge,
                      border: Border.all(
                        color: AppColors.lightError.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _normalizeEnvValue(currentEnv),
                        isDense: true,
                        style: ref
                            .read(themeProvider.notifier)
                            .getTextStyle(
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
                            switchEnvironment(currentEnv);
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
            ],

            const SizedBox(height: 16),

            // iOS 原生感：退出登录作为独立 Cell，文字居中 iosRed（详见 DESIGN.md 硬规则 13.2）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: AppColors.iosRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusCell,
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    // iOS 原生感：Cupertino 风格确认对话框（详见 DESIGN.md 第 8.7 节）
                    final confirmed = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text(t.logOut),
                        content: Text(t.areYouSureLogOut),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(t.buttonCancel),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true, // iOS 原生红色破坏性按钮
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(t.buttonConfirm),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      await UserRepoLocal.to.quitLogin();
                      if (context.mounted) {
                        context.go('/welcome');
                      }
                    }
                  },
                  child: Text(
                    t.logOut,
                    style: ref
                        .read(themeProvider.notifier)
                        .getTextStyle(
                          FontSizeType.medium,
                          color: AppColors.iosRed,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // iOS 原生感：注销账号独立 Cell，破坏性操作（详见 DESIGN.md 13.2）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: AppColors.iosRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusCell,
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    context.push('/logout_account');
                  },
                  child: Text(
                    t.logoutAccount,
                    style: ref
                        .read(themeProvider.notifier)
                        .getTextStyle(
                          FontSizeType.medium,
                          color: AppColors.iosRed,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    final rightDMActions = [
      Padding(
        padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
        child: RoundedElevatedButton(
          text: t.checkForUpdates,
          highlighted: true,
          onPressed: () async {
            EasyLoading.show();
            try {
              final info = await AppUpgradeService.to.manualCheck();
              if (!mounted) return;
              if (info == null || !info.hasUpdate) {
                EasyLoading.showInfo(t.nowNewVersion);
              }
              // manualCheck 内部已处理弹窗逻辑（force/recommend/silent）
            } on Exception {
              EasyLoading.showError(t.errorNetwork);
            } finally {
              EasyLoading.dismiss();
            }
          },
        ),
      ),
    ];

    Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (_) => MarkdownPage(
          title: "${t.about} $appName",
          rightDMActions: rightDMActions,
          url: "https://gitee.com/imboy-pub/imboy-flutter/raw/main/README.md",
        ),
      ),
    );
  }

  /// iOS 原生 Section Header：Footnote 13pt 灰色，分组容器上方
  /// 详见 DESIGN.md 第 8.3 节 Inset Grouped List
  Widget _buildSectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.08,
          color: AppColors.iosGray,
        ),
      ),
    );
  }

  /// iOS 原生分隔线：仅在图标文字之后（左 inset 56pt），使用 iosSeparator
  Widget _buildDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: HorizontalLine(
        height: 0.33,
        color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.6),
      ),
    );
  }

  /// 构建设置项 - 优化后的主题样式
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
    return CellPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // 前导图标
            if (leadingIcon != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (leadingIconColor ?? AppColors.primary).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: AppRadius.borderRadiusCell,
                ),
                child: Icon(
                  leadingIcon,
                  color: leadingIconColor ?? AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
            ],

            // 主要内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ref
                        .read(themeProvider.notifier)
                        .getTextStyle(
                          FontSizeType.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: ref
                          .read(themeProvider.notifier)
                          .getTextStyle(
                            FontSizeType.small,
                            color: AppColors.textSecondary,
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
                // 统一走 ref.read(themeProvider.notifier)，与上方 title/subtitle 一致
                // （不再混用 ThemeManager.instance 单例 + Riverpod ref，便于测试隔离）
                style: ref
                    .read(themeProvider.notifier)
                    .getTextStyle(
                      FontSizeType.normal,
                      color: AppColors.textSecondary,
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
              // iOS 原生 Cell 右侧 chevron
              Icon(
                CupertinoIcons.chevron_right,
                color: AppColors.iosGray,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建开关设置项
  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    IconData? leadingIcon,
    Color? leadingIconColor,
  }) {
    return _buildSettingItem(
      context,
      title: title,
      subtitle: subtitle,
      leadingIcon: leadingIcon,
      leadingIconColor: leadingIconColor,
      // iOS 原生感：不缩放 Switch，使用系统蓝（详见 DESIGN.md 第 2.1 双蓝策略）
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.getIosBlue(Theme.of(context).brightness),
      ),
    );
  }
}
