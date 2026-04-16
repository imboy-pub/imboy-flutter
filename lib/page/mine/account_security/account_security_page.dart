import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
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
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.accountSecurity,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, t.sectionLoginCredentials),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildTile(
                  context,
                  title: t.bindEmail,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const BindEmailPage(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildTile(
                  context,
                  title: t.bindMobile,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const BindMobilePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.08,
          color: AppColors.iosGray,
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppColors.iosGray,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Divider(
        height: 0.33,
        thickness: 0.33,
        color: AppColors.iosSeparator.withValues(alpha: 0.6),
      ),
    );
  }
}
