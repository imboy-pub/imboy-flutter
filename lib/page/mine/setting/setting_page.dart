import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/single/markdown.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/e2ee_settings.dart';
import 'package:imboy/store/api/app_version_api.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 允许搜索状态的 Provider - 使用 Provider 从存储中读取值
final allowSearchProvider = Provider<bool>((ref) {
  final settingData = StorageService.to.getString('setting');
  if (settingData.isNotEmpty) {
    try {
      final settingMap = jsonDecode(settingData) as Map<String, dynamic>;
      return settingMap['allow_search'] ?? true;
    } catch (e) {
      return true;
    }
  }
  return true;
});

/// E2EE开关状态的 Provider - 从E2EE设置服务读取
final e2eeEnabledProvider = Provider<bool>((ref) {
  return E2EESettings.isEnabled();
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
    iPrint("packageName $packageName");
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(t.restartRequired),
            content: Text(t.applyChanges),
            actions: <Widget>[
              TextButton(
                child: Text(t.buttonConfirm),
                onPressed: () {
                  exit(0);
                },
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
    final e2eeEnabled = ref.watch(e2eeEnabledProvider);
    final userRepo = ref.watch(userRepoProvider);
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(automaticallyImplyLeading: true, title: t.setting),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // 设置分组容器 - 圆角卡片风格
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
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

            // 隐私设置分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                            iPrint("allowSearch v $v;");

                            // 防抖：设置更新状态
                            setState(() => _isUpdatingAllowSearch = true);

                            try {
                              // 使用 userApiProvider 调用 API
                              final userApi = ref.read(userApiProvider);
                              bool res = await userApi.allowSearch(v ? 1 : 2);
                              iPrint("allowSearch res $res;");

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

                  // 端到端加密开关
                  _buildSwitchItem(
                    context,
                    title: '端到端加密',
                    subtitle: '启用后消息将被加密，只有接收方可以解密',
                    value: e2eeEnabled,
                    leadingIcon: Icons.lock,
                    leadingIconColor: AppColors.success,
                    onChanged: (v) async {
                      await E2EESettings.setEnabled(v);
                      // 刷新UI
                      ref.invalidate(e2eeEnabledProvider);
                      EasyLoading.showToast(v ? '已启用端到端加密' : '已关闭端到端加密');
                    },
                  ),

                  // 刷新设备密钥
                  _buildSettingItem(
                    context,
                    title: '刷新设备密钥',
                    subtitle: '如果消息无法解密，点击此按钮刷新密钥',
                    leadingIcon: Icons.refresh,
                    leadingIconColor: AppColors.info,
                    onTap: _isRefreshingKeys
                        ? null
                        : () async {
                            // 防抖：设置刷新状态
                            setState(() => _isRefreshingKeys = true);

                            try {
                              EasyLoading.showToast('正在刷新设备密钥...');
                              // 清除E2EE缓存
                              E2EEService.clearCache();
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

                              // 重新预加载当前用户的设备密钥
                              final currentUid = UserRepoLocal.to.currentUid;
                              if (currentUid.isNotEmpty) {
                                await E2EEService.getUserDevicePublicKeys(
                                  currentUid,
                                );
                              }

                              EasyLoading.showSuccess('设备密钥已刷新');
                              iPrint('E2EE: 设备密钥已手动刷新');
                            } catch (e) {
                              EasyLoading.showError('刷新失败: $e');
                              iPrint('E2EE: 刷新设备密钥失败: $e');
                            } finally {
                              // 恢复刷新状态
                              if (mounted) {
                                setState(() => _isRefreshingKeys = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            ),

            // 帮助和关于分组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                        CupertinoPageRoute(
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
                        CupertinoPageRoute(
                          builder: (_) => MarkdownPage(
                            title: t.helpDocument,
                            url:
                                "https://gitee.com/imboy-pub/imboy-flutter/raw/main/doc/help_document.md",
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: AppRadius.borderRadiusRegular,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).shadowColor.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
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

            // 退出登录按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightErrorContainer,
                    foregroundColor: AppColors.lightError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusRegular,
                      side: BorderSide(
                        color: AppColors.lightError.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    // 显示确认对话框
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(t.logOut),
                        content: Text(t.areYouSureLogOut),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(t.buttonCancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              t.buttonConfirm,
                              style: TextStyle(color: AppColors.lightError),
                            ),
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
                          FontSizeType.normal,
                          color: AppColors.lightError,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 注销账号按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusRegular,
                      side: BorderSide(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        width: 1,
                      ),
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
                          FontSizeType.normal,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
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
            final AppVersionApi p = AppVersionApi();
            final Map<String, dynamic> info = await p.check(appVsn);
            final String downLoadUrl = info['download_url'] ?? '';
            bool updatable = info['updatable'] ?? false;
            updatable = downLoadUrl.isEmpty ? false : updatable;
            if (updatable && mounted) {
              await Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => UpgradePage(
                    version: info['vsn'],
                    downLoadUrl: downLoadUrl,
                    message: info['description'] ?? '',
                    isForce: 1 == (info['force_update'] ?? 2) ? true : false,
                  ),
                ),
              );
            } else {
              EasyLoading.showInfo(t.nowNewVersion);
            }
          },
        ),
      ),
    ];

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => MarkdownPage(
          title: "${t.about} $appName",
          rightDMActions: rightDMActions,
          url: "https://gitee.com/imboy-pub/imboy-flutter/raw/main/README.md",
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: HorizontalLine(
        height: 0.5,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                    borderRadius: BorderRadius.circular(10),
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
                  style: ThemeManager.instance.getTextStyle(
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ],
          ),
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
      trailing: SizedBox(
        height: 28,
        width: 48,
        child: Transform.scale(
          scale: 0.8,
          child: CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
