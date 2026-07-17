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
  bool get _isLucky => _selectedType == 'random';

  @override
  void initState() {
    super.initState();
    // 进页拉真实余额，否则默认 0 会误判"余额不足"（QA#25，同转账页）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(walletProvider.notifier).loadBalance();
    });
  }

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
      AppLoading.showError(t.common.rechargeAmountError);
      return;
    }
    if (amountYuan > maxBalanceYuan) {
      AppLoading.showError(t.common.insufficientBalance);
      return;
    }

    final amountCents = (amountYuan * 100).toInt();
    final count = _isGroup ? (int.tryParse(_countController.text) ?? 1) : 1;
    final greeting = _greetingController.text.trim().isNotEmpty
        ? _greetingController.text.trim()
        : t.common.greetingDefault;

    final confirmed = await _confirmSend(amountYuan, count);
    if (!confirmed || !mounted) return;

    AppLoading.show(status: t.common.loading);
    final packetId = await WalletApi().sendRedPacket(
      amount: amountCents,
      count: count,
      type: _isGroup ? _selectedType : 'fixed',
      greeting: greeting,
    );

    if (packetId != null && packetId.isNotEmpty) {
      AppLoading.dismiss();
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
      AppLoading.showError(t.common.operationFailedAgainLater);
    }
  }

  /// 发红包二次确认：展示金额（+群聊个数 / 单聊收款方）摘要，用户确认后才发起请求。
  Future<bool> _confirmSend(double amountYuan, int count) async {
    final amountLabel = _isLucky
        ? t.common.redPacketTotalAmount
        : t.common.redPacketSingleAmount;
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(t.common.redPacketSend),
            content: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$amountLabel：￥${amountYuan.toStringAsFixed(2)}'),
                  if (_isGroup) ...[
                    AppSpacing.verticalTiny,
                    Text(
                      '${t.common.redPacketCount}：$count${t.common.redPacketCountUnit}',
                    ),
                  ] else ...[
                    AppSpacing.verticalTiny,
                    Text(t.common.redPacketReceiverLabel(uid: widget.toUid)),
                  ],
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
                child: Text(t.common.buttonConfirm),
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

    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      appBar: AppBar(title: Text(t.common.redPacketSend)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 红包类型切换（仅群聊）
              if (_isGroup) ...[
                WalletFieldCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.small,
                      vertical: AppSpacing.tiny,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isLucky
                              ? t.common.redPacketCurrentLucky
                              : t.common.redPacketCurrentNormal,
                          style: context.textStyle(
                            FontSizeType.medium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedType = _isLucky ? 'fixed' : 'random';
                          }),
                          child: Text(
                            _isLucky
                                ? t.common.redPacketSwitchToNormal
                                : t.common.redPacketSwitchToLucky,
                            style: TextStyle(color: AppColors.iosRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.verticalRegular,
              ],

              // 金额 hero 卡片
              WalletAmountField(
                controller: _amountController,
                label: _isLucky
                    ? t.common.redPacketTotalAmount
                    : t.common.redPacketSingleAmount,
                accent: AppColors.iosRed,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.common.enterAmount;
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0.01) {
                    return t.common.amountMustPositive;
                  }
                  return null;
                },
              ),
              AppSpacing.verticalRegular,

              // 红包个数（仅群聊）
              if (_isGroup) ...[
                WalletFieldCard(
                  child: TextFormField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: walletInputDecoration(
                      hint: t.common.redPacketCount,
                      suffix: t.common.redPacketCountUnit,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return t.common.redPacketCountEmpty;
                      }
                      final count = int.tryParse(value);
                      if (count == null || count < 1) {
                        return t.common.redPacketCountMin;
                      }
                      return null;
                    },
                  ),
                ),
                AppSpacing.verticalRegular,
              ],

              // 祝福语
              WalletFieldCard(
                child: TextFormField(
                  controller: _greetingController,
                  decoration: walletInputDecoration(
                    hint: t.common.redPacketGreetingLabel,
                  ),
                ),
              ),
              AppSpacing.verticalSmall,

              WalletBalanceHint(balanceYuan: balanceYuan),
              const SizedBox(height: 40),

              WalletPrimaryButton(
                label: _isLucky
                    ? t.common.redPacketStuffLucky
                    : t.common.redPacketStuffNormal,
                color: AppColors.iosRed,
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
