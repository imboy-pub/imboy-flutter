import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/page/mine/change_password/change_password_page.dart';

import 'bind_email_page.dart';
import 'bind_mobile_page.dart';

part 'account_security_page.g.dart';

/// AccountSecurity 模块的状态
@riverpod
class AccountSecurityNotifier extends _$AccountSecurityNotifier {
  @override
  int build() {
    return 0;
  }

  void refresh() {
    state = state + 1;
  }

  /// 更改邮箱
  Future<bool> changeEmail({
    required String email,
    required String code,
  }) async {
    // 使用 userApiProvider 调用 API
    final userApi = ref.read(userApiProvider);
    bool res = await userApi.changeEmail(email: email, code: code);
    if (res) refresh();
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
    if (res) refresh();
    return res;
  }
}

/// 账号安全页面 - 像素级对齐 iOS 设置风 (Inset Grouped)
class AccountSecurityPage extends ConsumerWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accountSecurityProvider);

    final currentEmail = UserRepoLocal.to.current.email;
    final currentMobile = UserRepoLocal.to.current.mobile;
    final currentAlipay =
        UserRepoLocal.to.current.setting?['alipay'] as String? ?? '';

    final hasBoundEmail = currentEmail.isNotEmpty;
    final hasBoundMobile = currentMobile.isNotEmpty;
    final hasBoundAlipay = currentAlipay.isNotEmpty;

    return IosPageTemplate(
      title: t.account.accountSecurity,
      child: ImBoySettingsSection(
        header: Text(t.common.sectionLoginCredentials.toUpperCase()),
        children: [
          ImBoySettingsTile(
            title: Text(t.account.bindEmail),
            subtitle: Text(
              hasBoundEmail ? _maskEmail(currentEmail) : t.common.notBound,
            ),
            onTap: () {
              if (hasBoundEmail) {
                _showUnbindActionSheet(
                  context: context,
                  ref: ref,
                  type: 'email',
                  value: currentEmail,
                );
              } else {
                Navigator.of(context).push(
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => const BindEmailPage(),
                  ),
                );
              }
            },
          ),
          ImBoySettingsTile(
            title: Text(t.account.bindMobile),
            subtitle: Text(
              hasBoundMobile ? hiddenPhone(currentMobile) : t.common.notBound,
            ),
            onTap: () {
              if (hasBoundMobile) {
                _showUnbindActionSheet(
                  context: context,
                  ref: ref,
                  type: 'mobile',
                  value: currentMobile,
                );
              } else {
                Navigator.of(context).push(
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => const BindMobilePage(),
                  ),
                );
              }
            },
          ),
          ImBoySettingsTile(
            title: const Text('绑定支付宝'),
            subtitle: Text(
              hasBoundAlipay ? _maskAlipay(currentAlipay) : t.common.notBound,
            ),
            onTap: () {
              if (hasBoundAlipay) {
                _showUnbindActionSheet(
                  context: context,
                  ref: ref,
                  type: 'alipay',
                  value: currentAlipay,
                );
              } else {
                _showBindAlipayDialog(context, ref);
              }
            },
          ),
          // ChangePasswordPage 此前只在路由表里注册、全项目零跳转点，
          // 用户登录后无从修改密码。入口挂在本页（账号安全）最自然。
          ImBoySettingsTile(
            title: Text(t.account.changeLoginPassword),
            subtitle: Text(t.account.loginPasswordDesc),
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute<dynamic>(
                  builder: (_) => const ChangePasswordPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showUnbindActionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String type, // 'email', 'mobile', or 'alipay'
    required String value,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          type == 'email'
              ? '邮箱管理'
              : type == 'mobile'
              ? '手机号管理'
              : '支付宝管理',
        ),
        message: Text(
          type == 'email'
              ? '当前绑定邮箱: ${_maskEmail(value)}'
              : type == 'mobile'
              ? '当前绑定手机号: ${hiddenPhone(value)}'
              : '当前绑定支付宝: ${_maskAlipay(value)}',
        ),
        actions: [
          CupertinoActionSheetAction(
            child: Text(
              type == 'email'
                  ? '更换邮箱'
                  : type == 'mobile'
                  ? '更换手机号'
                  : '更换支付宝账号',
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (type == 'email') {
                Navigator.of(context).push(
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => const BindEmailPage(),
                  ),
                );
              } else if (type == 'mobile') {
                Navigator.of(context).push(
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => const BindMobilePage(),
                  ),
                );
              } else if (type == 'alipay') {
                _showBindAlipayDialog(context, ref);
              }
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('解除绑定'),
            onPressed: () {
              Navigator.of(context).pop();
              _showConfirmUnbindDialog(context, ref, type);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: Text(t.common.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showConfirmUnbindDialog(
    BuildContext context,
    WidgetRef ref,
    String type,
  ) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认解除绑定'),
        content: Text(
          type == 'email'
              ? '解除绑定后，你将无法使用该邮箱进行登录或找回密码。'
              : type == 'mobile'
              ? '解除绑定后，你将无法使用该手机号进行登录或找回密码。'
              : '解除绑定后，相关的支付宝结算与提现服务将被停用。',
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(t.common.cancel),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(t.common.confirm),
            onPressed: () async {
              Navigator.of(context).pop();
              AppLoading.show();
              try {
                final userApi = ref.read(userApiProvider);
                final ok = await userApi.updateField(type, '');
                if (ok) {
                  final user = UserRepoLocal.to.current;
                  if (type == 'email') {
                    user.email = '';
                  } else if (type == 'mobile') {
                    user.mobile = '';
                  } else if (type == 'alipay') {
                    user.setting ??= <String, dynamic>{};
                    user.setting!['alipay'] = '';
                  }
                  await UserRepoLocal.to.changeInfo(user.toMap());
                  AppLoading.showSuccess('解绑成功');
                  ref.read(accountSecurityProvider.notifier).refresh();
                } else {
                  AppLoading.showError('解绑失败');
                }
              } catch (e) {
                AppLoading.showError('发生错误: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBindAlipayDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('绑定支付宝'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CupertinoTextField(
              controller: controller,
              placeholder: '请输入支付宝账号(邮箱或手机号)',
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(t.common.cancel),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              child: Text(t.common.confirm),
              onPressed: () async {
                final val = controller.text.trim();
                if (val.isEmpty) {
                  AppLoading.showError('请输入有效的支付宝账号');
                  return;
                }
                Navigator.of(context).pop();
                AppLoading.show();
                try {
                  final userApi = ref.read(userApiProvider);
                  final ok = await userApi.updateField('alipay', val);
                  if (ok) {
                    final user = UserRepoLocal.to.current;
                    user.setting ??= <String, dynamic>{};
                    user.setting!['alipay'] = val;
                    await UserRepoLocal.to.changeInfo(user.toMap());
                    AppLoading.showSuccess('绑定成功');
                    ref.read(accountSecurityProvider.notifier).refresh();
                  } else {
                    AppLoading.showError('绑定失败');
                  }
                } catch (e) {
                  AppLoading.showError('发生错误: $e');
                }
              },
            ),
          ],
        );
      },
    );
  }
}

String _maskEmail(String email) {
  final v = email.trim();
  final at = v.indexOf('@');
  if (at <= 1) return v;
  final name = v.substring(0, at);
  final domain = v.substring(at);
  if (name.length <= 2) return '${name[0]}*$domain';
  return '${name.substring(0, 2)}***$domain';
}

String _maskAlipay(String alipay) {
  final v = alipay.trim();
  if (v.contains('@')) {
    return _maskEmail(v);
  }
  return hiddenPhone(v);
}
