/// W08（channel-group-ux-v2.2 §6.8 C4/D3）：查看更新边界的可见性停留
/// 判定（纯逻辑，时钟由调用方注入，J13 离线向量载体）。
///
/// §6.8 推进条件：当前账号/频道/资格/激活状态匹配，前台 route 为当前
/// 可交互顶层；边界项可见面积 ≥50%，持续 ≥500ms（单调时钟）；模态/
/// 分享/导航覆盖及后台立即重置停留（J13.c）。
///
/// 调用方契约（J13.b 的落点）：
/// - 只有「未筛选的正常更新流」里的边界项才允许 [beginCandidate]；
///   置顶旧帖、筛选结果、单帖跳转、背景预加载、带缺口且不在首页边界
///   的页一律不得调用（调用方分支保证）；
/// - boundary 固定于该次成功内容响应（[onContentResponse]），不从后来
///   未展示的新推送取最大值；
/// - 推进候选**只前进不回退**（客户端侧护栏；服务端另有 GREATEST 兜底，
///   J13.d 双保险）。
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 计算目标项在视口中的可见面积占比（两轴 clamp 乘积）。
/// [itemRect] 与 [viewportRect] 须为同一坐标系（如全局坐标）。
double visibleFraction(Rect itemRect, Rect viewportRect) {
  if (itemRect.isEmpty || viewportRect.isEmpty) return 0;
  final dx =
      math.min(itemRect.right, viewportRect.right) -
      math.max(itemRect.left, viewportRect.left);
  final dy =
      math.min(itemRect.bottom, viewportRect.bottom) -
      math.max(itemRect.top, viewportRect.top);
  if (dx <= 0 || dy <= 0) return 0;
  return (dx * dy) / (itemRect.width * itemRect.height);
}

class ChannelViewTracker {
  ChannelViewTracker({this.holdMs = 500});

  /// 连续可见停留门槛（§6.8：持续 500ms，单调时钟）。
  final int holdMs;

  int? _boundary;
  int? _sinceMs;
  int? _lastSentBoundary;

  /// 当前候选边界（该次成功内容响应固定值；无候选时 null）。
  int? get candidateBoundary => _boundary;

  /// 是否处于连续可见累计中（≥50% 未被遮蔽打断）。
  bool get accumulating => _sinceMs != null;

  /// 新内容响应到达：候选边界固定为该响应值（不取最大值、不并入未
  /// 展示的新推送）。同边界幂等不重置累计。
  void onContentResponse(int boundary) {
    if (_boundary == boundary) return;
    _boundary = boundary;
    _sinceMs = null;
  }

  /// 边界项进入 ≥50% 可见（前台未筛选正常流）。重复调用幂等。
  void beginCandidate({required int nowMs}) {
    if (_boundary == null || _sinceMs != null) return;
    _sinceMs = nowMs;
  }

  /// 任一遮蔽事件：后台/模态/导航覆盖/键盘遮挡致 <50%/离开正常流。
  /// 停留累计立即重置（J13.c），候选边界保留。
  void onObscured() {
    _sinceMs = null;
  }

  /// 是否已达成推进条件：连续可见 ≥holdMs。
  /// 达成时返回候选边界并结束本轮候选（调用方负责发送 mark_viewed，
  /// 成功后调 [markSent]）；未达成返回 null。
  int? advanceIfDue({required int nowMs}) {
    final since = _sinceMs;
    final boundary = _boundary;
    if (since == null || boundary == null) return null;
    if (nowMs - since < holdMs) return null;
    // 客户端护栏：不发送比已发送更旧的边界（服务端 GREATEST 兜底）。
    final last = _lastSentBoundary;
    if (last != null && boundary <= last) {
      _sinceMs = null;
      return null;
    }
    _sinceMs = null;
    return boundary;
  }

  /// mark_viewed 成功后记录（同边界不重复发送）。
  void markSent(int boundary) {
    final last = _lastSentBoundary;
    if (last == null || boundary > last) _lastSentBoundary = boundary;
  }
}
