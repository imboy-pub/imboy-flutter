import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 红包消息展现层 / Red Packet Message Builder
class MessageRedPacketBuilder extends ConsumerWidget {
  final CustomMessage message;

  const MessageRedPacketBuilder({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = message.metadata ?? {};
    final greeting = metadata['greeting']?.toString() ?? '恭喜发财，大吉大利';
    final packetId = metadata['id']?.toString() ?? '';

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.iosRed,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleOpenRedPacket(context, ref, packetId),
          borderRadius: AppRadius.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.redeem, color: Colors.yellow, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '查看红包',
                            style: TextStyle(
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
                const Text(
                  'IMBoy 红包',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleOpenRedPacket(BuildContext context, WidgetRef ref, String packetId) async {
    if (packetId.isEmpty) return;

    // 弹出经典“開”字纸红包对话框
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return _RedPacketOpenDialog(
          packetId: packetId,
          onOpened: (amount) {
            Navigator.pop(ctx); // 收起弹窗
            ref.invalidate(walletProvider); // 原子刷新钱包余额
            // 跳转详情页
            context.push('/red_packet_detail', extra: {'packetId': packetId});
          },
          onViewDetail: () {
            Navigator.pop(ctx);
            context.push('/red_packet_detail', extra: {'packetId': packetId});
          },
        );
      },
    );
  }
}

/// “開”字旋转对话框
class _RedPacketOpenDialog extends StatefulWidget {
  final String packetId;
  final void Function(int) onOpened;
  final VoidCallback onViewDetail;

  const _RedPacketOpenDialog({
    required this.packetId,
    required this.onOpened,
    required this.onViewDetail,
  });

  @override
  State<_RedPacketOpenDialog> createState() => _RedPacketOpenDialogState();
}

class _RedPacketOpenDialogState extends State<_RedPacketOpenDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _triggerOpen() async {
    if (_isOpening) return;
    setState(() {
      _isOpening = true;
    });
    _animController.repeat(); // 开始 3D 旋转

    // 延迟 1 秒模拟真实感，发起抢红包
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    final amount = await WalletApi().openRedPacket(widget.packetId);

    if (amount != null) {
      _animController.stop();
      widget.onOpened(amount);
    } else {
      _animController.stop();
      setState(() {
        _isOpening = false;
      });
      // 抢失败了（如已抢完），直接允许查看详情
      widget.onViewDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          height: 400,
          decoration: BoxDecoration(
            color: AppColors.iosRed,
            borderRadius: AppRadius.borderRadiusLarge,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 盖子弧线
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 240,
                child: CustomPaint(
                  painter: _RedPacketHeaderPainter(),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '送你一个红包',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange.shade100,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '大吉大利，恭喜发财',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // “開” 按钮
              Align(
                alignment: const Alignment(0, 0.4),
                child: RotationTransition(
                  turns: _animController,
                  child: GestureDetector(
                    onTap: _triggerOpen,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.shade200, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '開',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 关闭按钮
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RedPacketHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.shade700.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RedPacketMessageTypePlugin implements MessageTypePlugin {
  const RedPacketMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.redPacket}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.redPacket;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return MessageRedPacketBuilder(message: message);
  }
}
