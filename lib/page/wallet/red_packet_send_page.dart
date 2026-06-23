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

class RedPacketSendPage extends ConsumerStatefulWidget {
  final String chatType; // 'C2C' (单聊) or 'C2G' (群聊)
  final String toUid; // 对方ID（uid 或 group_id）

  const RedPacketSendPage({
    super.key,
    required this.chatType,
    required this.toUid,
  });

  @override
  ConsumerState<RedPacketSendPage> createState() => _RedPacketSendPageState();
}

class _RedPacketSendPageState extends ConsumerState<RedPacketSendPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _greetingController = TextEditingController();
  String _selectedType = 'fixed'; // 'fixed' (普通红包) or 'random' (拼手气)

  bool get _isGroup => widget.chatType == 'C2G';

  @override
  void dispose() {
    _amountController.dispose();
    _countController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(double maxBalanceYuan) async {
    if (!_formKey.currentState!.validate()) return;

    final amountYuan = double.tryParse(_amountController.text) ?? 0.0;
    if (amountYuan < 0.01) {
      EasyLoading.showError(t.common.rechargeAmountError);
      return;
    }
    if (amountYuan > maxBalanceYuan) {
      EasyLoading.showError(t.common.insufficientBalance);
      return;
    }

    final amountCents = (amountYuan * 100).toInt();
    final count = _isGroup ? (int.tryParse(_countController.text) ?? 1) : 1;
    final greeting = _greetingController.text.trim().isNotEmpty
        ? _greetingController.text.trim()
        : t.common.greetingDefault;

    EasyLoading.show(status: t.common.loading);
    final packetId = await WalletApi().sendRedPacket(
      amount: amountCents,
      count: count,
      type: _isGroup ? _selectedType : 'fixed',
      greeting: greeting,
    );

    if (packetId != null && packetId.isNotEmpty) {
      EasyLoading.dismiss();
      ref.invalidate(walletProvider); // 刷新余额

      // 将结果返回给上一个页面，在 ChatPage 触发 WebSocket 投递
      if (mounted) {
        Navigator.pop(context, {
          'msg_type': 'redPacket',
          'id': packetId,
          'greeting': greeting,
          'amount': amountCents,
          'count': count,
          'type': _isGroup ? _selectedType : 'fixed',
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
        title: Text(t.common.redPacketSend),
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
              // 红包类型切换（仅群聊）
              if (_isGroup) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedType == 'random'
                          ? t.common.redPacketCurrentLucky
                          : t.common.redPacketCurrentNormal,
                      style: context.textStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedType = _selectedType == 'random'
                              ? 'fixed'
                              : 'random';
                        });
                      },
                      child: Text(
                        _selectedType == 'random'
                            ? t.common.redPacketSwitchToNormal
                            : t.common.redPacketSwitchToLucky,
                        style: TextStyle(color: AppColors.iosRed),
                      ),
                    ),
                  ],
                ),
                AppSpacing.verticalRegular,
              ],

              // 红包个数（仅群聊）
              if (_isGroup) ...[
                Text(
                  '红包个数',
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.verticalSmall,
                TextFormField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: '个',
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入红包个数';
                    }
                    final count = int.tryParse(value);
                    if (count == null || count < 1) {
                      return '红包个数必须大于等于 1';
                    }
                    return null;
                  },
                ),
                AppSpacing.verticalXLarge,
              ],

              // 总金额输入
              Text(
                _selectedType == 'random' ? '总金额' : '单个金额',
                style: context.textStyle(
                  FontSizeType.subheadline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.verticalSmall,
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
                    return '请输入金额';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0.01) {
                    return '金额必须大于 0';
                  }
                  return null;
                },
              ),
              AppSpacing.verticalXLarge,

              // 祝福语
              Text(
                '留言/祝福语',
                style: context.textStyle(
                  FontSizeType.subheadline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.verticalSmall,
              TextFormField(
                controller: _greetingController,
                decoration: InputDecoration(
                  hintText: t.common.greetingDefault,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                ),
              ),
              AppSpacing.verticalRegular,

              // 钱包余额提示
              Text(
                '钱包当前余额: ￥${balanceYuan.toStringAsFixed(2)}',
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.getTextColor(
                    Theme.of(context).brightness,
                    isSecondary: true,
                  ),
                ),
              ),
              AppSpacing.verticalXXXLarge,

              // 塞钱发送按钮
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
                    _selectedType == 'random' ? '塞钱发红包' : '放入钱包发送',
                    style: context.textStyle(
                      FontSizeType.medium,
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
