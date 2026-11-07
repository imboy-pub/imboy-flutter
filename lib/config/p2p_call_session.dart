import 'package:flutter/widgets.dart' show OverlayEntry;

bool p2pCallScreenOn = false;

/// 当前活动通话（来电弹窗或通话 overlay）的 msgId。
/// busy/bye 等终态信令按它判定归属：迟到的旧通话信令只收敛对应记录，
/// 不得改写全局通话状态或弹窗/计时器（CALL-11 / UX_SPEC §8）。
String? p2pCallMsgId;

/// 通话页的信令订阅是否已就绪。
/// openCallScreen 插入 overlay 后到页面 _initData 建立事件订阅之间存在短暂
/// 窗口，期间到达的 answer/bye 若直接 fire 事件总线会因无监听者而永久
/// 丢失；此窗口内信令一律入 pending 队列。
bool p2pCallSignalingReady = false;

OverlayEntry? p2pEntry;
