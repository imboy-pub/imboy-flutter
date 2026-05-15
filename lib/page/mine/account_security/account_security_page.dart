import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/api/user_api.dart';

import 'bind_email_page.dart';
import 'bind_mobile_page.dart';

part 'account_security_page.g.dart';

/// AccountSecurity 模块的状态
class AccountSecurityState {
  const AccountSecurityState();
}

@riverpod
class AccountSecurityNotifier extends _$AccountSecurityNotifier {
  @override
  AccountSecurityState build() {
    return const AccountSecurityState();
  }

  /// 更改邮箱
  Future<bool> changeEmail({
    required String email,
    required String code,
  }) async {
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    bool res = await userApi.changeEmail(email: email, code: code);
    return res;
  }

  /// 更改手机号
  Future<bool> changeMobile({
    required String mobile,
    required String code,
  }) async {
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    bool res = await userApi.changeMobile(mobile: mobile, code: code);
    return res;
  }
}

/// 账号安全页面 - 像素级对齐 iOS 设置风 (Inset Grouped)
class AccountSecurityPage extends ConsumerWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IosPageTemplate(
      title: t.account.accountSecurity,
      child: ImBoySettingsSection(
        header: Text(t.common.sectionLoginCredentials.toUpperCase()),
        children: [
          ImBoySettingsTile(
            title: Text(t.account.bindEmail),
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute<dynamic>(
                  builder: (_) => const BindEmailPage(),
                ),
              );
            },
          ),
          ImBoySettingsTile(
            title: Text(t.account.bindMobile),
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute<dynamic>(
                  builder: (_) => const BindMobilePage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
