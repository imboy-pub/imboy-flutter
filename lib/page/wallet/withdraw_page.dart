import 'package:flutter/material.dart';
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
      AppLoading.dismiss();
    }
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
                    hint: t.common.withdrawAccount,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return t.common.withdrawAccountEmpty;
                    }
                    return null;
                  },
                ),
              ),
              AppSpacing.verticalSmall,

              WalletBalanceHint(balanceYuan: balanceYuan),
              const SizedBox(height: 40),

              WalletPrimaryButton(
                label: t.common.withdrawConfirm,
                color: AppColors.primary,
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
