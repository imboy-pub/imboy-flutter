import 'package:flutter/widgets.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';

/// Public chat entry for the messaging module. It keeps the existing page in
/// place while callers move to the module import path.
class ChatEntry extends StatelessWidget {
  const ChatEntry({
    super.key,
    this.type = 'C2C',
    required this.peerId,
    required this.peerTitle,
    required this.peerAvatar,
    required this.peerSign,
    this.msgId = '',
    this.options,
  });

  final String type;
  final String peerId;
  final String peerAvatar;
  final String peerTitle;
  final String peerSign;
  final String msgId;
  final Map<String, dynamic>? options;

  @override
  Widget build(BuildContext context) {
    return ChatPage(
      type: type,
      peerId: peerId,
      peerTitle: peerTitle,
      peerAvatar: peerAvatar,
      peerSign: peerSign,
      msgId: msgId,
      options: options,
    );
  }
}
