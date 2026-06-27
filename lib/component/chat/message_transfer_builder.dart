import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 转账消息展现层 / P2P Transfer Message Builder
class MessageTransferBuilder extends ConsumerStatefulWidget {
  final CustomMessage message;

  const MessageTransferBuilder({super.key, required this.message});

  @override
  ConsumerState<MessageTransferBuilder> createState() =>
      _MessageTransferBuilderState();
}

class _MessageTransferBuilderState
    extends ConsumerState<MessageTransferBuilder> {
  bool _isProcessing = false;

  Future<void> _handleAcceptTransfer(String transferId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    AppLoading.show(status: t.common.transferReceiving);

    final success = await WalletApi().acceptTransfer(transferId);
    if (success) {
      AppLoading.showSuccess(t.common.payReceiveSuccess);
      ref.invalidate(walletProvider); // 刷新余额
      // 由于 WebSocket 会对账回显修改状态，在消息列表里该条消息会被重新触发状态构建
      setState(() => _isProcessing = false);
    } else {
      AppLoading.dismiss();
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.message.metadata ?? {};
    final amountCents = (metadata['amount'] as num?)?.toInt() ?? 0;
    final amountYuan = amountCents / 100.0;
    final remark = metadata['remark']?.toString() ?? '转账给好友';
    final transferId = metadata['id']?.toString() ?? '';
    final status =
        metadata['status']?.toString() ??
        'pending'; // pending, accepted, refunded

    final isSender = widget.message.authorId == UserRepoLocal.to.currentUid;
    final borderRadius = MessageSpacing.getBubbleBorderRadius(isSender);

    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';
    final isRefunded = status == 'refunded';

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isAccepted
            ? Colors.orange.shade700.withValues(alpha: 0.6)
            : isRefunded
            ? Colors.grey.shade600
            : Colors.orange.shade800,
        borderRadius: borderRadius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isPending && !isSender) {
              _handleAcceptTransfer(transferId);
            }
          },
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAccepted
                          ? Icons.check_circle_outline
                          : isRefunded
                          ? Icons.replay
                          : Icons.swap_horiz,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '￥${amountYuan.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAccepted
                                ? t.common.transferAccepted
                                : isRefunded
                                ? t.common.transferRefunded
                                : isSender
                                ? t.common.transferPending
                                : t.common.transferTapToReceive,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 16),
                Text(
                  remark,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TransferMessageTypePlugin implements MessageTypePlugin {
  const TransferMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.transfer}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.transfer;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return MessageTransferBuilder(message: message);
  }
}
