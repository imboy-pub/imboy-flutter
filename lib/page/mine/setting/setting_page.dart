import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/single/markdown_page.dart';
import 'package:imboy/service/app_upgrade_service.dart';
import 'package:imboy/modules/security_privacy/public.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

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

/// 设置页面 - 像素级对齐 iOS 设置风 (Inset Grouped)
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

    if (themeMode == ThemeMode.system) {
      return t.main.followSystem;
    }
    if (themeState.isDarkMode) {
      return t.common.enabled;
    }
    return t.common.disabled;
  }

  /// 切换环境
  Future<void> switchEnvironment(String env) async {
    final storage = StorageService.to;
    await storage.setString('env', env);
    await storage.setBool('changedEnv', true);
    await UserRepoLocal.to.quitLogin();
    _restartApp();
  }

  /// 重启应用
  void _restartApp() {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text(t.error.restartRequired),
            content: Text(t.contact.applyChanges),
            actions: <Widget>[
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => exit(0),
                child: Text(t.common.buttonConfirm),
              ),
            ],
          );
        },
      );
    }
  }

  String _normalizeEnvValue(String env) {
    if (env.isEmpty) return 'dev';
    if (env == 'local_home' || env == 'local_office') return 'local';
    return env;
  }

  @override
  Widget build(BuildContext context) {
    final allowSearch = ref.watch(allowSearchProvider);
    final userRepo = ref.watch(userRepoProvider);
    final themeState = ref.watch(themeProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.main.setting,
      slivers: [
        // 常规设置 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.sectionGeneral.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.account.accountSecurity),
                leading: _buildIcon(Icons.security, AppColors.iosOrange),
                onTap: () => context.push('/account_security'),
              ),
              ImBoySettingsTile(
                title: Text(t.common.languageSetting),
                leading: _buildIcon(Icons.language, AppColors.iosBlue),
                onTap: () => context.push('/language'),
              ),
              ImBoySettingsTile(
                title: Text(t.main.darkModel),
                leading: _buildIcon(Icons.dark_mode, AppColors.iosGray),
                trailing: _buildValueTrailing(themeTypeTips(ref)),
                onTap: () => context.push('/dark_model'),
              ),
              ImBoySettingsTile(
                title: Text(t.common.fontSettings),
                leading: _buildIcon(Icons.text_fields, AppColors.iosGreen),
                trailing: _buildValueTrailing(
                  themeState.fontSizeOption.displayName,
                ),
                onTap: () => context.push('/font_size'),
              ),
            ],
          ),
        ),

        // 隐私与安全 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.sectionPrivacySecurity.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.common.allowSearchMe),
                subtitle: Text(t.discovery.otherUsersCanFindMe),
                leading: _buildIcon(Icons.search, AppColors.iosBlue),
                trailing: CupertinoSwitch(
                  value: allowSearch,
                  activeTrackColor: AppColors.getIosBlue(brightness),
                  onChanged: _isUpdatingAllowSearch
                      ? null
                      : (v) => _handleAllowSearchChange(v, userRepo),
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.account.refreshDeviceKey),
                subtitle: Text(t.account.refreshDeviceKeyHint),
                leading: _buildIcon(Icons.refresh, AppColors.iosBlue),
                onTap: _isRefreshingKeys ? null : _handleRefreshDeviceKey,
              ),
              ImBoySettingsTile(
                title: Text(t.group.e2eeKeyManagement),
                subtitle: Text(t.group.e2eeKeyManagementSubtitle),
                leading: _buildIcon(Icons.vpn_key, AppColors.iosGreen),
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => const E2EEKeyRecoveryPage(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 帮助与关于 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.sectionHelpAbout.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.common.updateLog),
                leading: _buildIcon(Icons.update, AppColors.iosGreen),
                onTap: () => _openMarkdown(
                  t.common.updateLog,
                  "asset://docs/changelog.md",
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.common.helpDocument),
                leading: _buildIcon(Icons.help_outline, AppColors.iosBlue),
                onTap: () =>
                    _openMarkdown(t.common.helpDocument, "asset://docs/FAQ.md"),
              ),
              ImBoySettingsTile(
                title: Text(t.main.privacyPolicy),
                leading: _buildIcon(
                  Icons.privacy_tip_outlined,
                  AppColors.iosOrange,
                ),
                onTap: () => _openMarkdown(
                  t.main.privacyPolicy,
                  "asset://docs/privacy-policy.md",
                ),
              ),
              ImBoySettingsTile(
                title: Text(t.common.aboutApp),
                leading: _buildIcon(Icons.info_outline, AppColors.primary),
                trailing: _buildAboutTrailing(),
                onTap: _showAboutDialog,
              ),
            ],
          ),
        ),

        // 开发环境 Section
        if (currentEnv != 'pro')
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              header: const Text('DEVELOPER'),
              children: [
                ImBoySettingsTile(
                  title: Text(t.common.switchEnvironment),
                  leading: _buildIcon(Icons.developer_mode, AppColors.iosRed),
                  trailing: _buildEnvDropdown(),
                ),
              ],
            ),
          ),

        // 退出登录 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Center(child: Text(t.account.logOut)),
                destructive: true,
                trailing: const SizedBox.shrink(),
                onTap: _handleLogout,
              ),
            ],
          ),
        ),

        // 注销账号 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            children: [
              ImBoySettingsTile(
                title: Center(child: Text(t.account.logoutAccount)),
                destructive: true,
                trailing: const SizedBox.shrink(),
                onTap: () => context.push('/logout_account'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: AppColors.onPrimary, size: 20),
    );
  }

  Widget _buildValueTrailing(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.textStyle(
            FontSizeType.subheadline,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        const CupertinoListTileChevron(),
      ],
    );
  }

  Widget _buildAboutTrailing() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUpdate = AppUpgradeService.to.hasUpdate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${t.common.version} $appVsn",
          style: context.textStyle(
            FontSizeType.subheadline,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        if (hasUpdate) ...[
          const SizedBox(width: AppSpacing.small),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.iosRed,
              shape: BoxShape.circle,
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.small),
        const CupertinoListTileChevron(),
      ],
    );
  }

  Widget _buildEnvDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _normalizeEnvValue(currentEnv),
        isDense: true,
        style: context.textStyle(
          FontSizeType.normal,
          color: AppColors.iosRed,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          DropdownMenuItem(value: 'local', child: Text('Local')),
          DropdownMenuItem(value: 'dev', child: Text('Development')),
          DropdownMenuItem(value: 'pro', child: Text('Production')),
        ],
        onChanged: (value) {
          if (strNoEmpty(value)) {
            currentEnv = value!;
            switchEnvironment(currentEnv);
          }
        },
      ),
    );
  }

  void _openMarkdown(String title, String url) {
    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => MarkdownPage(title: title, url: url),
      ),
    );
  }

  Future<void> _handleAllowSearchChange(bool v, UserRepoLocal userRepo) async {
    setState(() => _isUpdatingAllowSearch = true);
    try {
      final userApi = ref.read(userApiProvider);
      bool res = await userApi.allowSearch(v ? 1 : 2);
      if (res) {
        final currentSetting = userRepo.setting;
        final newSetting = UserSettingModel(
          allowSearch: v,
          peopleNearbyVisible: currentSetting.peopleNearbyVisible,
          chatState: currentSetting.chatState,
          fontSize: currentSetting.fontSize,
          enableVisibilityRead: currentSetting.enableVisibilityRead,
          visibilityReadFraction: currentSetting.visibilityReadFraction,
          visibilityReadDelayMs: currentSetting.visibilityReadDelayMs,
          showOnlineStatus: currentSetting.showOnlineStatus,
          allowAddByPhone: currentSetting.allowAddByPhone,
          allowAddByQR: currentSetting.allowAddByQR,
        );
        await userRepo.changeSetting(newSetting);
        ref.invalidate(userRepoProvider);
      } else {
        AppLoading.showError(t.common.tipFailed);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAllowSearch = false);
    }
  }

  Future<void> _handleRefreshDeviceKey() async {
    setState(() => _isRefreshingKeys = true);
    try {
      AppLoading.showToast(t.account.refreshingDeviceKey);
      E2EEService.clearCache();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final currentUid = UserRepoLocal.to.currentUid;
      if (currentUid.isNotEmpty) {
        await E2EEService.getUserDevicePublicKeys(currentUid);
      }
      AppLoading.showSuccess(t.account.deviceKeyRefreshed);
    } catch (e) {
      AppLoading.showError(t.common.tipFailed);
    } finally {
      if (mounted) setState(() => _isRefreshingKeys = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.account.logOut),
        content: Text(t.account.areYouSureLogOut),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await UserRepoLocal.to.quitLogin();
      // ignore: use_build_context_synchronously 已内联 context.mounted 守卫
      if (context.mounted) context.go('/welcome');
    }
  }

  void _showAboutDialog() {
    final rightDMActions = [
      Padding(
        padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
        child: RoundedElevatedButton(
          text: t.common.checkForUpdates,
          highlighted: true,
          onPressed: () async {
            AppLoading.show();
            try {
              final info = await AppUpgradeService.to.manualCheck();
              if (info == null || !info.hasUpdate) {
                AppLoading.showInfo(t.common.nowNewVersion);
              }
            } catch (e) {
              AppLoading.showError(t.common.errorNetwork);
            } finally {
              AppLoading.dismiss();
            }
          },
        ),
      ),
    ];

    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => MarkdownPage(
          title: "${t.common.about} $appName",
          rightDMActions: rightDMActions,
          url: "https://gitee.com/imboy-pub/imboy-flutter/raw/main/README.md",
        ),
      ),
    );
  }
}
