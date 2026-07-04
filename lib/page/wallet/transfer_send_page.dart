import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/page/wallet/widget/wallet_form.dart';
import 'package:imboy/theme/default/app_colors.dart';
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
      AppLoading.showError(t.common.transferMinAmountError);
      return;
    }
    if (amountYuan > maxBalanceYuan) {
      AppLoading.showError(t.common.insufficientBalance);
      return;
    }

    final amountCents = (amountYuan * 100).toInt();
    final remark = _remarkController.text.trim().isNotEmpty
        ? _remarkController.text.trim()
        : t.common.transferDefaultRemark;

    AppLoading.show(status: t.common.loading);
    final transferId = await WalletApi().sendTransfer(
      receiverUid: widget.toUid,
      amount: amountCents,
      remark: remark,
    );

    if (transferId != null && transferId.isNotEmpty) {
      AppLoading.dismiss();
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
      AppLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final balanceYuan = walletState.balance / 100.0;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      appBar: AppBar(title: Text(t.common.transferSend)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 金额 hero 卡片
              WalletAmountField(
                controller: _amountController,
                label: t.common.transferAmountLabel,
                accent: AppColors.primary,
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
              AppSpacing.verticalRegular,

              // 备注
              WalletFieldCard(
                child: TextFormField(
                  controller: _remarkController,
                  decoration: walletInputDecoration(
                    hint: t.common.transferRemarkLabel,
                  ),
                ),
              ),
              AppSpacing.verticalSmall,

              WalletBalanceHint(balanceYuan: balanceYuan),
              const SizedBox(height: 40),

              WalletPrimaryButton(
                label: t.common.transferConfirm,
                color: AppColors.primary,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _handleSend(balanceYuan);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
