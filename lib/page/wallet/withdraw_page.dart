import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/page/wallet/widget/wallet_form.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key});

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  String _selectedMethod = 'alipay'; // 'alipay' or 'wechat'

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _handleWithdraw(double maxBalanceYuan) async {
    if (!_formKey.currentState!.validate()) return;

    final amountYuan = double.tryParse(_amountController.text) ?? 0.0;
    if (amountYuan < 1.0) {
      AppLoading.showError(t.common.withdrawAmountError);
      return;
    }
    if (amountYuan > maxBalanceYuan) {
      AppLoading.showError(t.common.insufficientBalance);
      return;
    }

    final amountCents = (amountYuan * 100).toInt();
    final account = _accountController.text.trim();
    final methodLabel = _selectedMethod == 'alipay'
        ? t.common.withdrawAlipay
        : t.common.withdrawWechat;

    final confirmed = await _confirmWithdraw(amountYuan, methodLabel, account);
    if (!confirmed || !mounted) return;

    AppLoading.show(status: t.common.loading);
    final success = await WalletApi().withdraw(
      amount: amountCents,
      method: _selectedMethod,
      account: account,
    );

    if (success) {
      AppLoading.showSuccess(t.common.withdrawSuccess);
      // 刷新钱包余额 / Refresh wallet state
      ref.invalidate(walletProvider);
      if (mounted) Navigator.pop(context);
    } else {
      AppLoading.showError(t.common.operationFailedAgainLater);
    }
  }

  // 支付宝邮箱格式（简化 RFC5322 校验，与常见前端实践一致）
  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  // 中国大陆手机号格式：1 开头 11 位数字，第二位 3-9
  static final RegExp _phonePattern = RegExp(r'^1[3-9]\d{9}$');

  // 微信号格式：6-20 位，字母开头，允许字母/数字/下划线/短横线
  static final RegExp _wechatPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]{5,19}$');

  /// 按所选提现渠道校验收款账号格式：
  /// 支付宝 = 邮箱或手机号；微信 = 微信号规则。
  String? _validateAccount(String? value) {
    final account = value?.trim() ?? '';
    if (account.isEmpty) {
      return t.common.withdrawAccountEmpty;
    }
    if (_selectedMethod == 'alipay') {
      if (!_emailPattern.hasMatch(account) &&
          !_phonePattern.hasMatch(account)) {
        return '请输入正确的支付宝邮箱或手机号';
      }
    } else {
      if (!_wechatPattern.hasMatch(account)) {
        return '请输入正确的微信号（6-20位，字母开头）';
      }
    }
    return null;
  }

  /// 提现二次确认：展示金额 + 渠道 + 账号摘要，用户确认后才发起请求。
  Future<bool> _confirmWithdraw(
    double amountYuan,
    String methodLabel,
    String account,
  ) async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(t.common.withdrawConfirm),
            content: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.common.withdrawAmountLabel}：￥${amountYuan.toStringAsFixed(2)}',
                  ),
                  AppSpacing.verticalTiny,
                  Text('${t.common.withdrawMethod}：$methodLabel'),
                  AppSpacing.verticalTiny,
                  Text('${t.common.withdrawAccount}：$account'),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(t.common.buttonCancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(t.common.withdrawConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final balanceYuan = walletState.balance / 100.0;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: AppBar(title: Text(t.common.withdraw)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 余额展示卡片
              Container(
                width: double.infinity,
                padding: AppSpacing.allLarge,
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(brightness),
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.common.smallChange,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.getTextColor(
                          brightness,
                          isSecondary: true,
                        ),
                      ),
                    ),
                    AppSpacing.verticalSmall,
                    Text(
                      '￥${balanceYuan.toStringAsFixed(2)}',
                      style: context.textStyle(
                        FontSizeType.extraLargeTitle,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.verticalRegular,

              // 提现金额（hero）
              WalletAmountField(
                controller: _amountController,
                label: t.common.withdrawAmountLabel,
                accent: AppColors.primary,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.common.withdrawAmountError;
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 1.0) {
                    return t.common.withdrawAmountError;
                  }
                  return null;
                },
              ),
              AppSpacing.verticalRegular,

              // 提现渠道选择
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.tiny,
                ),
                child: Text(
                  t.common.withdrawMethod,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.getTextColor(
                      brightness,
                      isSecondary: true,
                    ),
                  ),
                ),
              ),
              AppSpacing.verticalSmall,
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment, size: 20),
                          AppSpacing.horizontalSmall,
                          Text(t.common.withdrawAlipay),
                        ],
                      ),
                      selected: _selectedMethod == 'alipay',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedMethod = 'alipay');
                        }
                      },
                    ),
                  ),
                  AppSpacing.horizontalRegular,
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 20),
                          AppSpacing.horizontalSmall,
                          Text(t.common.withdrawWechat),
                        ],
                      ),
                      selected: _selectedMethod == 'wechat',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedMethod = 'wechat');
                        }
                      },
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalRegular,

              // 提现账号
              WalletFieldCard(
                child: TextFormField(
                  controller: _accountController,
                  decoration: walletInputDecoration(
                    hint: _selectedMethod == 'alipay'
                        ? '${t.common.withdrawAccount}（邮箱或手机号）'
                        : '${t.common.withdrawAccount}（微信号）',
                  ),
                  validator: _validateAccount,
                ),
              ),
              AppSpacing.verticalSmall,

              WalletBalanceHint(balanceYuan: balanceYuan),
              AppSpacing.verticalTiny,
              // 手续费与到账时效说明：后端暂无手续费/时效字段，展示静态提示
              // ponytail: static hint, wire to real fee/ETA once wallet API returns them
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.tiny,
                ),
                child: Text(
                  '免手续费，预计 T+1 到账（以实际到账时间为准）',
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.getTextColor(
                      brightness,
                      isSecondary: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              WalletPrimaryButton(
                label: t.common.withdrawConfirm,
                color: AppColors.getIosRed(brightness),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _handleWithdraw(balanceYuan);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
