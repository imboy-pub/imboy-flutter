import 'dart:math';

/// E2EE-062：Olm prekey claim 的**幂等键**。
///
/// 服务端已在 `olm_handler` / `olm_identity_logic` 上实现了按
/// `(claimed_by, user_id, device_id, claim_request_id)` 的幂等租约
/// （imboy 迁移 49 的部分唯一索引），但客户端从不发送 `request_id`，
/// **生产流量一条也走不到幂等路径**——一次网络超时后的重投仍会再消费一条
/// one-time prekey，把对端 OTK 池逼向耗尽、进而复用同一条 fallback prekey
/// （前向保密显著下降）。本类补上客户端这一半。
///
/// == 生命周期（安全方向：宁可少去重，绝不多去重）==
///
/// 幂等键的作用域是**一次建会话尝试**，不是「一对设备」：
///
/// - 首次为某对端设备 claim → 铸一个新 id 并挂起；
/// - 该次尝试失败后的重投（MessageRetry 的 3/5/10/20s 退避重发会重新进入
///   `_establishOutboundSession`）→ 拿到**同一个 id** → 服务端命中租约，
///   返回同一条 key，池不再减少；
/// - 一旦成功建出会话 → [complete] 丢弃该 id。之后若因会话被销毁 / ratchet
///   重置而**重新**建会话，会铸新 id 并正常消费一条新 OTK。
///
/// 反过来做（用 `peerUid:peerDeviceId` 派生一个恒定 id）会把该对端此后所有
/// 会话都钉死在同一条已消费的 OTK 上——one-time prekey 的一次性被破坏，
/// 比重复消费严重得多。故此处只做进程内挂起，不做持久化：
/// 进程重启后重投会消费一条新 OTK，与今天的行为一致（无回归），
/// 且方向是安全的那一侧。
class OlmClaimRequestId {
  OlmClaimRequestId._();

  /// 服务端 `olm_handler:normalize_request_id/1` 的字符集与长度白名单。
  /// 不合规的 id 会被服务端**静默降级为空**（幂等失效且无任何信号），
  /// 因此客户端必须自证合规。
  static final RegExp _serverWhitelist = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');

  static final Map<String, String> _pending = <String, String>{};
  static final Random _random = Random.secure();

  static String _key(String peerUid, String peerDeviceId) =>
      '$peerUid:$peerDeviceId';

  /// 取该对端设备当前挂起的幂等键；没有则铸一个新的。
  static String issue(String peerUid, String peerDeviceId) {
    return _pending.putIfAbsent(_key(peerUid, peerDeviceId), _mint);
  }

  /// 会话已成功建立 → 丢弃挂起的幂等键，下次是一次全新的 claim。
  static void complete(String peerUid, String peerDeviceId) {
    _pending.remove(_key(peerUid, peerDeviceId));
  }

  /// 128 bit 随机 hex（32 字符，服务端 varchar(64) 内）。
  ///
  /// **不从 uid / device_id 派生**：`claim_request_id` 会在服务端落库并保留到
  /// 审计保留期，派生等于把对端标识多写进一列；随机值同样能唯一标识一次尝试。
  static String _mint() {
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buf.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  /// 是否会被服务端接受（不被 `normalize_request_id/1` 降级为空）。
  static bool isServerAcceptable(String id) => _serverWhitelist.hasMatch(id);

  /// 仅供测试：清空挂起表，避免用例间相互影响。
  static void resetForTest() => _pending.clear();
}
