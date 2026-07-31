import 'package:flutter/widgets.dart';

import 'package:imboy/i18n/strings.g.dart';

/// 给非文字消息补一句"谁发的 + 什么类型"。
///
/// 图片/语音/视频/文件这四类渲染的都是 flyer_chat 的 widget，里面只有缩略图、
/// 波形和图标——读屏用户从上往下翻聊天记录时，这些消息全是哑的，既听不出是
/// 什么，也听不出是自己发的还是对方发的。
///
/// 不用 `ExcludeSemantics` 包住 [child]：文件消息的文件名、语音消息的时长
/// 都是有用信息，这里只在外层加一句限定，不吞掉里面本来读得出来的东西。
Widget semanticMessage({
  required bool isSentByMe,
  required String kind,
  required Widget child,
}) {
  final who = isSentByMe ? t.main.sentByMe : t.chat.myReceivedTab;
  return Semantics(button: true, label: '$who$kind', child: child);
}
