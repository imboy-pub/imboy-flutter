import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
      EasyLoading.showError(t.common.withdrawAmountError);
      return;
    }
    if (amountYuan > maxBalanceYuan) {
      EasyLoading.showError(t.common.insufficientBalance);
      return;
    }

    final amountCents = (amountYuan * 100).toInt();
    final account = _accountController.text.trim();

    EasyLoading.show(status: t.common.loading);
    final success = await WalletApi().withdraw(
      amount: amountCents,
      method: _selectedMethod,
      account: account,
    );

    if (success) {
      EasyLoading.showSuccess(t.common.withdrawSuccess);
      // 刷新钱包余额 / Refresh wallet state
      ref.invalidate(walletProvider);
      if (mounted) Navigator.pop(context);
    } else {
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final balanceYuan = walletState.balance / 100.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(t.common.withdraw), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 余额展示卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            AppColors.darkSurfaceGrouped,
                            AppColors.darkSurfaceGrouped,
                          ]
                        : [
                            AppColors.lightSurfaceGrouped,
                            AppColors.lightSurfaceGrouped,
                          ],
                  ),
                  borderRadius: AppRadius.borderRadiusLarge,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.common.smallChange,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '￥${balanceYuan.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 提现渠道选择
              Text(
                t.common.withdrawMethod,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            t.common.withdrawMethod.contains('Method')
                                ? 'Alipay'
                                : '支付宝',
                          ),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            t.common.withdrawMethod.contains('Method')
                                ? 'WeChat'
                                : '微信',
                          ),
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
              const SizedBox(height: 24),

              // 提现账号输入
              Text(
                t.common.withdrawAccount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountController,
                decoration: InputDecoration(
                  hintText: t.common.withdrawAccountEmpty,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return t.common.withdrawAccountEmpty;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 提现金额输入
              Text(
                t.common.withdrawConfirm.contains('Confirm')
                    ? 'Withdrawal Amount'
                    : '提现金额',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: '￥ ',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                ),
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
              const SizedBox(height: 48),

              // 提现按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _handleWithdraw(balanceYuan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iosRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                  ),
                  child: Text(
                    t.common.withdrawConfirm,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
