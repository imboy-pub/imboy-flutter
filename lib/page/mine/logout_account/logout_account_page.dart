import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

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

  /// 切换选中状态
  void changeValue(String val) {
    state = state.copyWith(
      selectedValue: val == 'read_and_agree' ? '' : 'read_and_agree',
    );
  }

  /// 导出用户数据
  Future<String?> exportUserData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userApi = ref.read(userApiProvider);
      final data = await userApi.exportUserData();
      if (data == null) {
        state = state.copyWith(isLoading: false);
        return null;
      }
      // 将 JSON 数据写入临时文件
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
        error: t.operationFailedAgainLater,
      );
      return null;
    }
  }

  /// 注销账户
  Future<bool> applyLogout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 使用 userApiProvider 调用 API
      final userApi = ref.read(userApiProvider);
      bool result = await userApi.applyLogout();
      state = state.copyWith(isLoading: false);
      return result;
    } on Exception {
      state = state.copyWith(
        isLoading: false,
        error: t.operationFailedAgainLater,
      );
      return false;
    }
  }
}

class LogoutAccountPage extends ConsumerWidget {
  const LogoutAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final state = ref.watch(logoutAccountProvider);
    final agreed = state.selectedValue == 'read_and_agree';

    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.logoutAccount,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              // 导出数据按钮
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: AppRadius.borderRadiusCell,
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(Icons.download, color: AppColors.primary),
                  title: Text(t.exportMyData),
                  subtitle: Text(
                    t.exportDataDesc,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: state.isLoading
                      ? null
                      : () async {
                          EasyLoading.show(status: t.loading);
                          final filePath = await ref
                              .read(logoutAccountProvider.notifier)
                              .exportUserData();
                          EasyLoading.dismiss();
                          if (filePath == null) return;
                          final result = await SharePlus.instance.share(
                            ShareParams(
                              files: [XFile(filePath)],
                              text: t.exportMyData,
                            ),
                          );
                          if (result.status == ShareResultStatus.success) {
                            EasyLoading.showSuccess(t.exportDataSuccess);
                          }
                        },
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: agreed,
                title: Text(t.readAgreeParam(param: t.logoutAccount)),
                onChanged: state.isLoading
                    ? null
                    : (_) {
                        ref
                            .read(logoutAccountProvider.notifier)
                            .changeValue(state.selectedValue);
                      },
              ),
              if (state.error != null && state.error!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(state.error!, style: TextStyle(color: cs.error)),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: agreed && !state.isLoading
                      ? () async {
                          final ok = await ref
                              .read(logoutAccountProvider.notifier)
                              .applyLogout();
                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.of(context).maybePop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t.operationFailedAgainLater),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iosRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.iosRed.withValues(
                      alpha: 0.3,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusCell,
                    ),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          t.logoutAccount,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
