import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:intl/intl.dart';
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

  /// D-04：注销请求状态（deletion_status 接口返回，null=未拉取）
  final Map<String, dynamic>? deletionStatus;

  /// 状态是否已拉取过（防 post-frame 重复拉取）
  final bool statusLoaded;

  const LogoutAccountState({
    this.isLoading = false,
    this.error,
    this.selectedValue = '',
    this.deletionStatus,
    this.statusLoaded = false,
  });

  LogoutAccountState copyWith({
    bool? isLoading,
    String? error,
    String? selectedValue,
    Map<String, dynamic>? deletionStatus,
    bool? statusLoaded,
  }) {
    return LogoutAccountState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedValue: selectedValue ?? this.selectedValue,
      deletionStatus: deletionStatus ?? this.deletionStatus,
      statusLoaded: statusLoaded ?? this.statusLoaded,
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
        // HttpClient fail-open（http_client.dart 吞异常返回 ok:false 响应，
        // 永不抛异常），此分支是实际失败路径：必须设置 error，否则页面
        // iosRed 错误区块（state.error 渲染）永远不可达，用户只见一闪 toast。
        state = state.copyWith(
          isLoading: false,
          error: t.common.operationFailedAgainLater,
        );
        return null;
      }
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/imboy_data_$timestamp.json');
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonStr);
      state = state.copyWith(isLoading: false);
      return file.path;
    } on Exception catch (e) {
      iPrint('[LogoutAccount] 导出用户数据失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: t.common.operationFailedAgainLater,
      );
      return null;
    }
  }

  /// D-04：拉取注销请求状态（宽限期/预期完成时间）
  Future<void> fetchDeletionStatus() async {
    final userApi = ref.read(userApiProvider);
    final data = await userApi.deletionStatus();
    state = state.copyWith(deletionStatus: data, statusLoaded: true);
  }

  /// D-04：撤销注销申请，成功后刷新状态
  Future<bool> cancelLogoutRequest() async {
    final ok = await ref.read(userApiProvider).cancelLogout();
    if (ok) {
      await fetchDeletionStatus();
    }
    return ok;
  }

  Future<bool> applyLogout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userApi = ref.read(userApiProvider);
      bool result = await userApi.applyLogout();
      if (!result) {
        // 同 exportUserData：HttpClient fail-open（http_client.dart 吞异常
        // 返回 ok:false 响应，永不抛异常）下失败不抛异常走 on Exception，
        // 必须显式设置 error，否则注销失败只有一闪 toast、页面 iosRed
        // 错误区块不可达（user_api 内部已 showError 提示）。
        state = state.copyWith(
          isLoading: false,
          error: t.common.operationFailedAgainLater,
        );
        return false;
      }
      state = state.copyWith(isLoading: false);
      return true;
    } on Exception catch (e) {
      iPrint('[LogoutAccount] 注销申请失败: $e');
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

    // D-04：进入页面拉取一次注销状态（宽限期/预期完成时间）
    if (!state.statusLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(logoutAccountProvider.notifier).fetchDeletionStatus();
      });
    }

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
          // D-04：注销状态区块（宽限期横幅 + 撤销入口）
          if (state.statusLoaded && state.deletionStatus != null)
            _buildStatusSection(context, ref, state, brightness),

          // 数据留存说明（D-04：保留类别公示）
          ImBoySettingsSection(
            header: Text(t.account.logoutRetainedHeader.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(
                  t.account.logoutRetainedNote,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),

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

  /// D-04：注销状态区块 —— 宽限期横幅（预期完成时间）+ 撤销入口
  Widget _buildStatusSection(
    BuildContext context,
    WidgetRef ref,
    LogoutAccountState state,
    Brightness brightness,
  ) {
    final status = state.deletionStatus?['status']?.toString();
    if (status != 'requested') {
      return const SizedBox.shrink();
    }
    // 服务端下发毫秒时间戳；直接 toString 会显示成"1793751235679"长串，
    // 格式化为本地日期（解析失败时回退原文，便于排障）。
    final expectedRaw = state.deletionStatus?['expected_deletion_at']
        ?.toString();
    final expectedMs = int.tryParse(expectedRaw ?? '');
    final expected = expectedMs != null
        ? DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.fromMillisecondsSinceEpoch(expectedMs))
        : expectedRaw;
    final retained = state.deletionStatus?['retained_categories'];
    final retainedNote = retained is List && retained.isNotEmpty
        ? '· audit_logs / financial_records'
        : '';

    return ImBoySettingsSection(
      header: Text(context.t.account.logoutPendingHeader.toUpperCase()),
      children: [
        ImBoySettingsTile(
          title: Text(
            context.t.account.logoutPendingBanner(date: expected ?? '-'),
          ),
          subtitle: Text(
            '${context.t.account.logoutRetainedNote} $retainedNote',
          ),
        ),
        ImBoySettingsTile(
          title: Text(
            context.t.account.logoutCancelRequest,
            style: context.textStyle(
              FontSizeType.body,
              color: AppColors.iosRed,
            ),
          ),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.iosRed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CupertinoIcons.xmark_circle,
              color: AppColors.onPrimary,
              size: 18,
            ),
          ),
          onTap: () async {
            final ok = await ref
                .read(logoutAccountProvider.notifier)
                .cancelLogoutRequest();
            if (ok && context.mounted) {
              AppLoading.show(status: context.t.account.logoutCancelledNote);
              AppLoading.dismiss();
            }
          },
        ),
      ],
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
        child: CupertinoButton(
          minimumSize: const Size(0, 50),
          padding: EdgeInsets.zero,
          color: AppColors.getIosRed(brightness),
          borderRadius: BorderRadius.circular(14),
          onPressed: agreed && !state.isLoading
              ? () async {
                  // 注销不可逆：删除按钮前必须二次确认，勿绕过。
                  final confirmed = await showCupertinoDialog<bool>(
                    context: context,
                    builder: (dialogContext) => CupertinoAlertDialog(
                      title: Text(t.account.logoutAccount),
                      content: Text(t.common.privacyLogoutAccountConfirm),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(t.common.buttonCancel),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(t.account.logoutAccount),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;

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
                  // 红色实底按钮上的文字必须显式用 onPrimary：
                  // context.textStyle 携带主题字色（浅色=蓝），叠红底变红底蓝字。
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
