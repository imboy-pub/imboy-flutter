import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/api/user_api.dart';

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

  /// 注销账户
  Future<bool> applyLogout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 使用 userApiProvider 调用 API
      final userApi = ref.read(userApiProvider);
      bool result = await userApi.applyLogout();
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.logoutAccount,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
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
                child: FilledButton(
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
                  child: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.logoutAccount),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
