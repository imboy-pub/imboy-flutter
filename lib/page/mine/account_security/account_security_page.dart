import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
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

class AccountSecurityPage extends ConsumerWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.accountSecurity,
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(t.bindEmail),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(CupertinoPageRoute(builder: (_) => const BindEmailPage()));
            },
          ),
          ListTile(
            title: Text(t.bindMobile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const BindMobilePage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
