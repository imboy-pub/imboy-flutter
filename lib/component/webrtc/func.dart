import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/page/chat/p2p_call_screen/incoming_call_view.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_page.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 被叫还在来电页等待接听时，暂存主叫提前发送的 ICE 信令。
///
/// 来电页没有 PeerConnection 事件订阅；如果此时直接 fire 到事件总线，
/// candidate 会被丢弃，公网环境下尤其容易只剩 host candidate，最终表现
/// 为接听后黑屏、无声或 ICE 超时。接听后由通话页取出并按原顺序消费。
final Map<String, List<Map<String, dynamic>>> _pendingWebRTCSignals = {};

void queuePendingWebRTCSignal(Map<String, dynamic> data) {
  final peerId = data['from']?.toString();
  if (peerId == null || peerId.isEmpty) return;
  (_pendingWebRTCSignals[peerId] ??= <Map<String, dynamic>>[]).add(data);
}

List<Map<String, dynamic>> takePendingWebRTCSignals(String peerId) {
  return _pendingWebRTCSignals.remove(peerId) ?? <Map<String, dynamic>>[];
}

void clearPendingWebRTCSignals(String peerId, {String? msgId}) {
  if (msgId == null) {
    _pendingWebRTCSignals.remove(peerId);
    return;
  }
  final pending = _pendingWebRTCSignals[peerId];
  pending?.removeWhere((data) => data['id'] == msgId);
  if (pending?.isEmpty ?? false) _pendingWebRTCSignals.remove(peerId);
}

// 保存每通来电的实际路由；持久化/响铃尚未完成时没有路由可关闭。
final Map<String, DialogRoute<void>> _incomingCallRoutes = {};

void closeIncomingCallScreen(String msgId) {
  final route = _incomingCallRoutes.remove(msgId);
  if (route != null && route.isActive) {
    route.navigator?.removeRoute(route);
  }
}

/// 通话 overlay 期间的系统返回键（Android）处理器：由通话页注册，
/// 行为 = 最小化为悬浮窗（与微信/FaceTime 一致），而不是弹掉底层业务路由。
void Function()? p2pCallSystemBackHandler;

/// 通话页注册的"返回当前通话"处理器（CALL-10）：重复呼叫提示弹窗用它
/// 取消最小化回到全屏通话；通话页关闭时置空。
void Function()? p2pCallRestoreHandler;

/// 通话页的返回键吸收层：通话页是 OverlayEntry 而非路由，Android 系统返回
/// 会直接 pop 底层 go_router 路由。推一个透明哑路由拦截返回并转发给上面的
/// 处理器；通话页关闭时随 overlay 一起移除。
Route<void>? _p2pCallBackdropRoute;

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
    iPrint('> rtc sendWebRTCMsg($event): 丢弃——NetworkMonitor 无网络');
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
  Map<String, dynamic> option, {
  // 测试替换持久化/信令；正常入口继续使用既有服务。
  MessagingFacade? messaging,
  Future<bool> Function(String event)? sendSignal,
}) async {
  if (!context.mounted || !AppFeatureRegistry.isEnabled(FeatureKeys.rtc)) {
    return;
  }
  Future<bool> signal(String event) =>
      sendSignal?.call(event) ??
      sendWebRTCMsg(event, {}, msgId: msgId, to: peer.peerId.toString());

  if (p2pCallScreenOn) {
    // 本机已在通话/已有来电展示中：主动回 busy，避免对端毫无提示地
    // 一直响铃到 60s 超时（双方几乎同时互相呼叫时的常见场景）。
    await signal('busy');
    return;
  }
  p2pCallScreenOn = true;
  // 登记"当前活动通话"标识：busy/bye 等终态信令据此区分本通与旧通
  // （CALL-11）。来电被拒/超时后清除；接听后由通话页 initSession 沿用。
  p2pCallMsgId = msgId;
  final messages = messaging ?? MessagingFacade.instance;

  final sid = sessionId(peer.peerId.toString());
  // LK-APP-01：会话仅承载信令标识（peerId/sid/media），媒体面由 LiveKit
  // Room 管理，不再有跨页共享的 RTCPeerConnection 注册表。
  final WebRTCSession s = WebRTCSession(
    peerId: peer.peerId.toString(),
    sid: sid,
    media: option['media']?.toString(),
  );
  option['msgId'] = msgId;

  var incomingHandled = false;
  Timer? incomingTimer;
  void cancelIncomingTimer() {
    final timer = incomingTimer;
    incomingTimer = null;
    timer?.cancel();
    if (timer != null && identical(gTimer, timer)) gTimer = null;
  }

  void releaseIncoming() {
    clearPendingWebRTCSignals(peer.peerId.toString(), msgId: msgId);
    cancelIncomingTimer();
    // 异步收尾只复位本通拥有的登记；同一联系人重拨后也不能动新通话。
    if (p2pCallMsgId == msgId) {
      p2pCallScreenOn = false;
      p2pCallMsgId = null;
      p2pCallSignalingReady = false;
    }
    closeIncomingCallScreen(msgId);
  }

  Future<void> declineIncoming() async {
    if (incomingHandled) return;
    incomingHandled = true;
    releaseIncoming();
    messages.markAsRead('C2C', peer.peerId.toString(), [msgId]);
    messages.changeLocalMsgState(msgId, 5);
    try {
      if (!await signal('busy')) {
        iPrint('> rtc declineIncoming: busy signal was not sent');
      }
    } on Object catch (error) {
      iPrint('> rtc declineIncoming: busy signal failed: $error');
    }
  }

  await messages.addLocalMsg(
    media: option['media'] as String,
    caller: false,
    msgId: msgId,
    peer: peer,
  );
  // liveness 复查（CALL-06 竞态）：持久化期间主叫可能已取消——busy 经
  // message_webrtc 终态 handler 清掉本通登记（p2pCallMsgId）。此时不得
  // 再起 60s 铃窗、不得发 ringing、不得弹出全屏来电。
  if (!context.mounted ||
      !AppFeatureRegistry.isEnabled(FeatureKeys.rtc) ||
      p2pCallMsgId != msgId) {
    await declineIncoming();
    return;
  }

  incomingTimer = Timer(const Duration(seconds: 60), () {
    if (incomingHandled) return;
    incomingHandled = true;
    releaseIncoming();
    messages.changeLocalMsgState(msgId, 5);
  });
  gTimer = incomingTimer;

  await signal('ringing');

  // DONE(2026-04-04): 标记来电消息为已读
  messages.markAsRead('C2C', peer.peerId.toString(), [msgId]);

  // liveness 复查（同上）：ringing 往返期间主叫可能已取消。
  if (!context.mounted ||
      !AppFeatureRegistry.isEnabled(FeatureKeys.rtc) ||
      p2pCallMsgId != msgId) {
    await declineIncoming();
    return;
  }

  // 显式保存 DialogRoute，取消/超时/接听仅移除本通路由，不猜测栈顶归属。
  final navigator = Navigator.of(context, rootNavigator: true);
  if (!navigator.mounted) {
    await declineIncoming();
    return;
  }
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) => IncomingCallView(
      avatar: peer.avatar,
      nickname: peer.nickname,
      media: option['media'] as String,
      onDecline: declineIncoming,
      onAccept: () {
        if (incomingHandled) return;
        if (!context.mounted ||
            !AppFeatureRegistry.isEnabled(FeatureKeys.rtc) ||
            p2pCallMsgId != msgId) {
          unawaited(declineIncoming());
          return;
        }
        incomingHandled = true;
        // DONE(2026-04-04): 标记消息已读
        messages.markAsRead('C2C', peer.peerId.toString(), [msgId]);
        cancelIncomingTimer();
        closeIncomingCallScreen(msgId);
        option['msgId'] = msgId;
        openCallScreen(context, peer, session: s, option, caller: false);
      },
    ),
  );
  _incomingCallRoutes[msgId] = route;
  unawaited(
    navigator.push<void>(route).whenComplete(() {
      if (identical(_incomingCallRoutes[msgId], route)) {
        _incomingCallRoutes.remove(msgId);
      }
    }),
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
  // 所有入口（包括通话记录回拨和已保存的点击回调）都复核当前 RTC 门。
  if (!context.mounted || !AppFeatureRegistry.isEnabled(FeatureKeys.rtc)) {
    return;
  }
  if (p2pEntry != null) {
    // CALL-10：已有通话 overlay 时不重复创建邀请；用户主动呼出/回拨
    // 给出"正在通话"提示并提供返回当前通话（programmatic 接听路径除外）。
    // 提示弹窗 fire-and-forget：不阻塞入口调用方（await showDialog 会等
    // 弹窗关闭才返回，呼出入口将无法继续处理后续手势）。
    if (caller) unawaited(_showCallInProgressDialog());
    return;
  }
  // 来电弹窗还开着（p2pCallScreenOn 已置位但尚未接听）时禁止再发起呼出：
  // overlay 会盖死来电弹窗使其失去关闭路径，只剩 60s 超时兜底。
  if (p2pCallScreenOn && caller) {
    iPrint('> rtc openCallScreen: 来电待接听中，忽略新的呼出请求');
    unawaited(_showCallInProgressDialog(canRestore: false));
    return;
  }
  p2pCallScreenOn = true;
  p2pCallSignalingReady = false;

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
        // p2pCallSignalingReady 等信令/回调层立即复位；
        // p2pCallScreenOn / p2pCallMsgId 属"活动通话归属"状态，紧随的页面
        // dispose 与 cleanUpP2P 按归属判定复位（CALL-11）：异步收尾窗口内
        // 对端重拨接管登记时，不得在此无条件抹掉新一通的登记。
        p2pCallSignalingReady = false;
        p2pCallSystemBackHandler = null;
        p2pCallRestoreHandler = null;
        final route = _p2pCallBackdropRoute;
        _p2pCallBackdropRoute = null;
        if (route != null && route.isActive) {
          navigatorKey.currentState?.removeRoute(route);
        }
      },
    ),
  );

  navigatorKey.currentState?.overlay?.insert(p2pEntry!);

  // 返回键吸收层（见 _p2pCallBackdropRoute 注释）。透明、不参与布局，
  // 仅把系统返回转为"最小化通话"。
  final nav = navigatorKey.currentState;
  if (nav != null) {
    _p2pCallBackdropRoute = RawDialogRoute<void>(
      barrierColor: null,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            p2pCallSystemBackHandler?.call();
          }
        },
        child: const SizedBox.shrink(),
      ),
    );
    nav.push(_p2pCallBackdropRoute!);
  }
}

/// CALL-10：已有活动通话时重复呼出的反馈弹窗。通话 overlay 已建立时
/// 提供"返回当前通话"（取消最小化），否则只提示不提供入口。
Future<void> _showCallInProgressDialog({bool canRestore = true}) async {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  final restore = canRestore ? p2pCallRestoreHandler : null;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(t.common.calling),
      content: Text(t.common.callInProgressHint),
      actions: [
        if (restore != null)
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              restore();
            },
            child: Text(t.common.returnToCall),
          ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(t.common.ok),
        ),
      ],
    ),
  );
}
