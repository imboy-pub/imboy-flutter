import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/webrtc/session.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/page/chat/p2p_call_screen/incoming_call_view.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_page.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 发送WebRTC消息
/// 构造 WebRTC 信令请求（纯函数，便于协议对齐测试）。
///
/// 后端契约（imboy `message_router_logic:route_normal_message`）：
///   - 按 `type` 的 `webrtc_` 前缀（大小写不敏感）路由到 `webrtc_ws_logic`；
///   - 取 **`to`** 键解析 ToUid——必须是 `to`，发 `to_id` 会触发后端
///     `{badkey,<<"to">>}` 崩溃；
///   - 整包逐字透传给对端，故对端 `WebRTCSignalingModel` 解析须与此格式对齐。
Map<String, dynamic> buildWebRtcRequest({
  required String event,
  required Map<String, dynamic> payload,
  required String msgId,
  required String to,
  required String from,
  required int ts,
}) {
  return <String, dynamic>{
    'ts': ts,
    'id': msgId,
    'to': to,
    'from': from,
    'type': 'webrtc_$event',
    'payload': payload,
  };
}

Future<bool> sendWebRTCMsg(
  String event,
  Map<String, dynamic> payload, {
  required String msgId,
  required String to,
  String? debug,
}) async {
  // 使用 NetworkMonitorService 检查网络状态
  if (!NetworkMonitorService.to.hasNetwork) {
    return false;
  }

  final request = buildWebRtcRequest(
    event: event,
    payload: payload,
    msgId: msgId,
    to: to,
    from: UserRepoLocal.to.currentUid,
    ts: DateTimeHelper.millisecond(),
  );

  // 解耦：通过事件发送消息
  AppEventBus.fire(
    WebSocketMessageSendRequestEvent(
      message: json.encode(request),
      messageId: msgId,
    ),
  );

  return true;
}

/// 生成会话ID
String sessionId(String peerId) {
  List<String> li = [UserRepoLocal.to.currentUid, peerId];
  li.sort();
  return "${li[0]}-${li[1]}";
}

/// 来电提示弹窗
Future<void> incomingCallScreen(
  BuildContext context,
  String msgId,
  ContactModel peer,
  Map<String, dynamic> option,
) async {
  if (p2pCallScreenOn) {
    // 本机已在通话/已有来电展示中：主动回 busy，避免对端毫无提示地
    // 一直响铃到 60s 超时（双方几乎同时互相呼叫时的常见场景）。
    await sendWebRTCMsg('busy', {}, msgId: msgId, to: peer.peerId.toString());
    return;
  }
  p2pCallScreenOn = true;

  final sid = sessionId(peer.peerId.toString());
  WebRTCSession? s =
      webRTCSessions[sid] ??
      WebRTCSession(
        peerId: peer.peerId.toString(),
        sid: sid,
        media: option['media']?.toString(),
      );
  option['msgId'] = msgId;

  await MessagingFacade.instance.addLocalMsg(
    media: option['media'] as String,
    caller: false,
    msgId: msgId,
    peer: peer,
  );

  gTimer = Timer(const Duration(seconds: 60), () {
    MessagingFacade.instance.changeLocalMsgState(msgId, 5);
    // Check if dialog is still open and close it
    if (navigatorKey.currentState?.overlay != null) {
      navigatorKey.currentState?.pop();
    }
    gTimer?.cancel();
    gTimer = null;
    p2pCallScreenOn = false;
  });

  await sendWebRTCMsg('ringing', {}, msgId: msgId, to: peer.peerId.toString());

  // DONE(2026-04-04): 标记来电消息为已读
  MessagingFacade.instance.markAsRead('C2C', peer.peerId.toString(), [msgId]);

  if (!context.mounted) return;

  // 全屏来电界面（FaceTime / iOS 风格）。沿用 showDialog 的弹出/关闭语义
  // （60s 超时与拒接/接听均通过 pop 关闭），仅将廉价的小弹窗替换为全屏呈现。
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (dialogContext) => IncomingCallView(
      avatar: peer.avatar,
      nickname: peer.nickname,
      media: option['media'] as String,
      onDecline: () async {
        // DONE(2026-04-04): 标记消息已读
        MessagingFacade.instance.markAsRead('C2C', peer.peerId.toString(), [
          msgId,
        ]);
        MessagingFacade.instance.changeLocalMsgState(msgId, 5);
        gTimer?.cancel();
        gTimer = null;
        await sendWebRTCMsg(
          'busy',
          {},
          msgId: msgId,
          to: peer.peerId.toString(),
        );
        p2pCallScreenOn = false;
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
      },
      onAccept: () {
        // DONE(2026-04-04): 标记消息已读
        MessagingFacade.instance.markAsRead('C2C', peer.peerId.toString(), [
          msgId,
        ]);
        gTimer?.cancel();
        gTimer = null;
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        option['msgId'] = msgId;
        openCallScreen(context, peer, session: s, option, caller: false);
      },
    ),
  );
}

/// 打开通话界面
Future<void> openCallScreen(
  BuildContext context,
  ContactModel peer,
  Map<String, dynamic> option, {
  WebRTCSession? session,
  bool caller = true,
}) async {
  if (p2pEntry != null) return;
  p2pCallScreenOn = true;

  final sid = sessionId(peer.peerId.toString());
  session ??= WebRTCSession(
    peerId: peer.peerId.toString(),
    sid: sid,
    media: option['media']?.toString(),
  );
  // 如果已有 session 但 media 未设置，补充 media 信息
  if (session.media == null && option['media'] != null) {
    session.media = option['media']?.toString();
  }
  webRTCSessions[sid] = session;

  p2pEntry = OverlayEntry(
    builder: (context) => P2pCallScreenPage(
      peer: peer,
      session: session!,
      option: option,
      caller: caller,
      closePage: () {
        p2pEntry?.remove();
        p2pEntry = null;
        // Get.delete removed - cleanup is handled by closePage callback
        p2pCallScreenOn = false;
      },
    ),
  );

  navigatorKey.currentState?.overlay?.insert(p2pEntry!);
}
