import 'dart:async';

import '../infrastructure/cs_api.dart';

/// CS-APP-02（CS-DEC-02 / CS-RUNTIME-04）：坐席 presence 控制器。
///
/// 诚实在线约束（与 Web 端 CS-WEB-05 同语义）：
///   * **只有前台状态（resumed）才发心跳**——paused/detached/hidden 一律
///     停发（后台不保持假 online；90 秒无心跳服务端自然 offline）；
///   * resumed/回前台：立即补一次心跳并触发 [onResync]（resume 重同步）；
///   * 心跳失败 → 状态置 unknown（不保留旧 online 显示——本地不造状态）；
///   * 心跳间隔服务端冻结 30 秒（间隔可注入供测试）。
///
/// [onResync] 供页面层 resume 后重拉权威数据（queue/会话/未读），与
/// CS-RUNTIME-04「resume 后重同步」一一对应。
class CsPresenceController {
  CsPresenceController({
    required CsApi csApi,
    required this.orgId,
    this.interval = const Duration(seconds: 30),
    this.onResync,
    this.onPresenceChanged,
  }) : _api = csApi;

  final CsApi _api;
  final String orgId;
  final Duration interval;

  /// resume 重同步钩子（CS-RUNTIME-04）：页面层回前台后重拉权威数据
  /// （queue/会话/未读）。
  final Future<void> Function()? onResync;

  /// lastPresence 变化通知（成功/失败/手动切换后；页面 setState 重建
  /// presence 展示）。通知不携带参数——读取 [lastPresence]。
  final void Function()? onPresenceChanged;

  /// 最近一次服务端派生状态；null = 从未成功（不显示任何运行态）。
  CsPresence? lastPresence;

  /// 是否处于「应报 online」的前台。后台（paused 等）为 false——心跳暂停。
  bool foreground = true;

  bool _started = false;
  Timer? _timer;
  bool _beating = false;

  /// 启动周期心跳（幂等；重复 start 不叠加 timer）。
  void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(interval, (_) => beat());
    // 启动即一次（前台假设；调用方在后台态启动时应先置 foreground=false）。
    unawaited(beat());
  }

  /// 停止心跳（页面 dispose / 切换 Org 时调用；不发「offline」——服务端
  /// 90 秒无心跳自然判 offline，客户端不产生额外写请求）。
  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// App lifecycle 变化（WidgetsBindingObserver 桥接）。
  ///
  /// resumed：回前台 → 立即心跳 + 触发重同步；
  /// paused/inactive/detached/hidden：离场 → 停发（不谎报 online）。
  Future<void> onAppLifecycleStateChanged(String state) async {
    switch (state) {
      case 'resumed':
        foreground = true;
        await beat();
        await onResync?.call();
      case 'paused':
      case 'detached':
      case 'hidden':
        foreground = false;
      case 'inactive':
        // 短暂过渡态（来电/下拉通知）：不打断前台假设，也不主动补发。
        break;
      default:
        break;
    }
  }

  /// 单次心跳：仅前台发送；失败置 lastPresence=null（诚实降级——本地不
  /// 造状态，断网时不得显示 online）。并发保护：in-flight 心跳不重入。
  Future<void> beat() async {
    if (!foreground || _beating) return;
    _beating = true;
    try {
      lastPresence = await _api.seatHeartbeat(orgId);
    } on Object {
      // on Object（非仅 Exception）：API 面已把形状异常折成 CsApiException，
      // 这里再兜住任何剩余错误——心跳链路永不向 UI 抛。
      lastPresence = null;
    } finally {
      _beating = false;
      onPresenceChanged?.call();
    }
  }

  /// 手动 away / 恢复自动（PUT；结果回填 lastPresence）。手动 away 优先
  /// 于自动 online 的派生优先级在服务端（cs_presence:derive），客户端只
  /// 回填服务端事实。
  Future<void> setManualStatus(String? manualStatus) async {
    lastPresence = await _api.setSeatPresence(orgId, manualStatus);
    onPresenceChanged?.call();
  }
}

/// CS-APP-02：ACK 单调裁决（纯函数）。
///
/// 返回应发送的 ACK 目标（最大已见消息 id）；`current` 为本地已 ACK 单调
/// 水位（多标签页/重入共享 ref）。规则：
///   * `seen` 为空（消息未加载/空会话）→ null（不发）；
///   * `seen <= current`（旧值）→ null（服务端本就 no-op，本地也不发）；
///   * 否则返回 `seen`（推进水位由调用方回写）。
String? nextAckTarget({required String? current, required String? seen}) {
  final cur = current;
  final seenId = seen;
  if (seenId == null || seenId.isEmpty) return null;
  if (cur != null && cur.isNotEmpty && _compareTsid(seenId, cur) <= 0) {
    return null;
  }
  return seenId;
}

/// TSID 十进制字符串比较（等长字典序；长度不同先比长度）。
int _compareTsid(String a, String b) {
  if (a.length != b.length) return a.length.compareTo(b.length);
  return a.compareTo(b);
}
