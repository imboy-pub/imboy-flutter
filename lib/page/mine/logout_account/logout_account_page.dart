import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

part 'logout_account_page.g.dart';

/// LogoutAccount 模块的状态
class LogoutAccountState {
  final bool isLoading;
  final String? error;
  final String selectedValue;

  const LogoutAccountState({
    this.isLoading = false,
    this.error,
    this.selectedValue = '',
  });

  LogoutAccountState copyWith({
    bool? isLoading,
    String? error,
    String? selectedValue,
  }) {
    return LogoutAccountState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedValue: selectedValue ?? this.selectedValue,
    );
  }
}

@riverpod
class LogoutAccountNotifier extends _$LogoutAccountNotifier {
  @override
  LogoutAccountState build() {
    return const LogoutAccountState();
  }

  void changeValue(String val) {
    state = state.copyWith(
      selectedValue: val == 'read_and_agree' ? '' : 'read_and_agree',
    );
  }

  Future<String?> exportUserData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userApi = ref.read(userApiProvider);
      final data = await userApi.exportUserData();
      if (data == null) {
        state = state.copyWith(isLoading: false);
        return null;
      }
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/imboy_data_$timestamp.json');
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonStr);
      state = state.copyWith(isLoading: false);
      return file.path;
    } on Exception {
      state = state.copyWith(
        isLoading: false,
        error: t.common.operationFailedAgainLater,
      );
      return null;
    }
  }

  Future<bool> applyLogout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userApi = ref.read(userApiProvider);
      bool result = await userApi.applyLogout();
      state = state.copyWith(isLoading: false);
      return result;
    } on Exception {
      state = state.copyWith(
        isLoading: false,
        error: t.common.operationFailedAgainLater,
      );
      return false;
    }
  }
}

/// 注销账号页面 - 像素级对齐 iOS 设置风
class LogoutAccountPage extends ConsumerWidget {
  const LogoutAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(logoutAccountProvider);
    final agreed = state.selectedValue == 'read_and_agree';
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.account.logoutAccount,
      useLargeTitle: false,
      bottomWidget: _buildDeleteButton(
        context,
        ref,
        state,
        agreed,
        t,
        brightness,
      ),
      child: Column(
        children: [
          // 导出数据 Section
          ImBoySettingsSection(
            header: Text(t.chat.exportMyData.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(t.chat.exportMyData),
                subtitle: Text(t.chat.exportDataDesc),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.getIosBlue(brightness),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    CupertinoIcons.cloud_download,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                ),
                onTap: state.isLoading
                    ? null
                    : () async {
                        AppLoading.show(status: t.common.loading);
                        final filePath = await ref
                            .read(logoutAccountProvider.notifier)
                            .exportUserData();
                        AppLoading.dismiss();
                        if (filePath == null) return;
                        await SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(filePath)],
                            text: t.chat.exportMyData,
                          ),
                        );
                      },
              ),
            ],
          ),

          // 确认条款 Section
          ImBoySettingsSection(
            header: Text(t.common.confirm.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(
                  t.chat.readAgreeParam(param: t.account.logoutAccount),
                ),
                leading: CupertinoCheckbox(
                  value: agreed,
                  activeColor: AppColors.getIosBlue(brightness),
                  onChanged: state.isLoading
                      ? null
                      : (_) => ref
                            .read(logoutAccountProvider.notifier)
                            .changeValue(state.selectedValue),
                ),
                trailing: const SizedBox.shrink(),
                onTap: () => ref
                    .read(logoutAccountProvider.notifier)
                    .changeValue(state.selectedValue),
              ),
            ],
          ),

          if (state.error != null && state.error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.regular),
              child: Text(
                state.error!,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.iosRed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(
    BuildContext context,
    WidgetRef ref,
    LogoutAccountState state,
    bool agreed,
    Translations t,
    Brightness brightness,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        MediaQuery.of(context).padding.bottom + AppSpacing.regular,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.getIosRed(brightness),
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.getIosRed(
              brightness,
            ).withValues(alpha: 0.3),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: agreed && !state.isLoading
              ? () async {
                  final ok = await ref
                      .read(logoutAccountProvider.notifier)
                      .applyLogout();
                  if (!ok) return;
                  // 账号已在服务端注销：必须级联清理本地残留（token/E2EE缓存/
                  // SQLite连接），否则设备转手或冷启动后仍停留在已注销账号的
                  // 会话状态，与常规登出（setting_page.dart）行为不一致。
                  await UserRepoLocal.to.quitLogin();
                  if (context.mounted) context.go('/welcome');
                }
              : null,
          child: state.isLoading
              ? CupertinoActivityIndicator(color: AppColors.onPrimary)
              : Text(
                  t.account.logoutAccount,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
