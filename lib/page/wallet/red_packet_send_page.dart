import 'package:imboy/component/ui/common_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/page/wallet/widget/wallet_form.dart';
import 'package:imboy/page/wallet/wallet_amount.dart';
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

  /// 收款人显示名。二次确认弹窗原先直接显示 TSID uid，用户无从核对发给谁。
  String _receiverName = '';

  @override
  void initState() {
    super.initState();
    if (!_isGroup) _loadReceiverName();
    // 进页拉真实余额，否则默认 0 会误判"余额不足"（QA#25，同转账页）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(walletProvider.notifier).loadBalance();
    });
  }

  Future<void> _loadReceiverName() async {
    final contact = await ContactRepo().findByUid(widget.toUid);
    if (mounted && contact != null && strNoEmpty(contact.title)) {
      setState(() => _receiverName = contact.title);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _countController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(int maxBalanceFen) async {
    if (!_formKey.currentState!.validate()) return;

    final amountFen = parseYuanToFen(_amountController.text);
    if (amountFen == null || amountFen < 1) {
      AppLoading.showError(t.common.rechargeAmountError);
      return;
    }
    final count = _isGroup ? (int.tryParse(_countController.text) ?? 1) : 1;
    // 金额下限：每个红包至少 0.01 元
    if (amountFen < count) {
      AppLoading.showError(t.common.redPacketAmountTooSmall);
      return;
    }
    if (amountFen > maxBalanceFen) {
      AppLoading.showError(t.common.insufficientBalance);
      return;
    }

    final amountYuan = fenToYuan(amountFen);
    final greeting = _greetingController.text.trim().isNotEmpty
        ? _greetingController.text.trim()
        : t.common.greetingDefault;

    final confirmed = await _confirmSend(amountYuan, count);
    if (!confirmed || !mounted) return;

    AppLoading.show(status: t.common.loading);
    final packetId = await WalletApi().sendRedPacket(
      amount: amountFen,
      count: count,
      type: _isGroup ? _selectedType : 'fixed',
      greeting: greeting,
      // B-11：把聊天页已有的会话上下文一并落库，服务端才能判定越权领取
      scopeType: widget.chatType,
      scopeId: widget.toUid,
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
          'amount': amountFen,
          'count': count,
          'type': _isGroup ? _selectedType : 'fixed',
        });
      }
    } else {
      // B1#16：失败时错误文案由 WalletApi.sendRedPacket 的
      // AppLoading.showError(resp.msg) 透出后端中文消息，页面层不再叠加
      // 兜底文案，避免双提示覆盖。
      AppLoading.dismiss();
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
                    Text(
                      t.common.redPacketReceiverLabel(
                        uid: _receiverName.isEmpty
                            ? widget.toUid
                            : _receiverName,
                      ),
                    ),
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
      appBar: GlassAppBar(title: t.common.redPacketSend),
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
                        // 左侧文案可收缩：英文环境文案长 + 右按钮默认 padding，
                        // 两者硬宽之和在 390pt 屏溢出 4.2px
                        Expanded(
                          child: Text(
                            _isLucky
                                ? t.common.redPacketCurrentLucky
                                : t.common.redPacketCurrentNormal,
                            style: context.textStyle(
                              FontSizeType.medium,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.small,
                          ),
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
                  final amountFen = parseYuanToFen(value);
                  if (amountFen == null || amountFen < 1) {
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
                    enableSuggestions: false,
                    autocorrect: false,
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
                  enableSuggestions: false,
                  autocorrect: false,
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
                  _handleSend(walletState.balance);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
