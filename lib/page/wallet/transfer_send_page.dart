import 'package:flutter/material.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class TransferSendPage extends ConsumerStatefulWidget {
  final String toUid; // 好友 UID

  const TransferSendPage({super.key, required this.toUid});

  @override
  ConsumerState<TransferSendPage> createState() => _TransferSendPageState();
}

class _TransferSendPageState extends ConsumerState<TransferSendPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(double maxBalanceYuan) async {
    if (!_formKey.currentState!.validate()) return;

    final amountYuan = double.tryParse(_amountController.text) ?? 0.0;
    if (amountYuan < 0.1) {
      EasyLoading.showError(t.common.transferMinAmountError);
      return;
    }
    if (amountYuan > maxBalanceYuan) {
      EasyLoading.showError(t.common.insufficientBalance);
      return;
    }

    final amountCents = (amountYuan * 100).toInt();
    final remark = _remarkController.text.trim().isNotEmpty
        ? _remarkController.text.trim()
        : t.common.transferDefaultRemark;

    EasyLoading.show(status: t.common.loading);
    final transferId = await WalletApi().sendTransfer(
      receiverUid: widget.toUid,
      amount: amountCents,
      remark: remark,
    );

    if (transferId != null && transferId.isNotEmpty) {
      EasyLoading.dismiss();
      ref.invalidate(walletProvider); // 刷新余额

      // 将结果返回给上一个页面，在 ChatPage 触发 WebSocket 投递
      if (mounted) {
        Navigator.pop(context, {
          'msg_type': 'transfer',
          'id': transferId,
          'amount': amountCents,
          'remark': remark,
        });
      }
    } else {
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final balanceYuan = walletState.balance / 100.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.common.transferSend),
        elevation: 0,
        backgroundColor: AppColors.iosRed,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.xLarge,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 转账金额输入
              Text(
                '转账金额',
                style: TextStyle(
                  fontSize: FontSizeType.subheadline.size,
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
                    return t.common.enterAmount;
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0.1) {
                    return t.common.transferMinAmountError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 备注说明
              Text(
                '转账备注',
                style: TextStyle(
                  fontSize: FontSizeType.subheadline.size,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarkController,
                decoration: InputDecoration(
                  hintText: t.common.transferDefaultRemark,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 钱包余额提示
              Text(
                '钱包当前余额: ￥${balanceYuan.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: FontSizeType.footnote.size,
                  color: AppColors.getTextColor(
                    Theme.of(context).brightness,
                    isSecondary: true,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 确认按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _handleSend(balanceYuan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iosRed,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                  ),
                  child: Text(
                    '确认转账',
                    style: TextStyle(
                      fontSize: FontSizeType.medium.size,
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
