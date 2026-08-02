/// P3-1：备份载荷的 Megolm inbound session 段（换设备后群聊历史可恢复）。
///
/// == 为什么需要 ==
///
/// 备份载荷此前只含 RSA 私钥（`e2ee_local_backup_service.packBackupBytes`），
/// 而群聊密文由 Megolm inbound session 解密。换设备后新 deviceId 拿不到任何
/// Megolm session → **群聊历史全灭**（用户可感知的最大洞，见
/// standard/gap-matrix.md B4）。
///
/// == 范围（有意如此）==
///
/// - **收**：`megolm_inbound_<scope>:<sessionId>` —— 群聊/单聊 Megolm 收包密钥，
///   是「读历史」所需的全部材料，且天然只读（不含发送侧棘轮态）。
/// - **不收 Olm session pickle**：Olm 是 1:1 双棘轮，session 状态含发送侧棘轮
///   位置；跨设备还原会造成 **key reuse / ratchet 分叉**。行业通行做法同样不备份
///   （Signal / Matrix 换设备后 1:1 历史不可恢复），该限制须在 UI 明示而非偷偷绕过。
/// - **不收群旗标 `group_e2ee_mode_*`**：服务端权威，登录后可重拉。
///
/// 本模块是**纯函数**（不碰 storage），使备份格式可脱离 secure storage 单测。
library;

/// 备份载荷中 Megolm 段的字段名（载荷 v2 起存在；v1 载荷无此字段）。
const String kMegolmSectionKey = 'megolm_inbound';

/// secure storage 中 Megolm inbound session 的键前缀（与 GroupSessionService 一致）。
const String kMegolmInboundPrefix = 'megolm_inbound_';

/// 单次备份纳入的 inbound session 条数上限。
///
/// 防超大载荷把备份包撑爆（云备份 put 有体积上限，本地文件有 64MiB 解析上限）。
/// 超出时保留**最先枚举到的** N 条——不静默扩容，也不整包失败。
const int kMaxMegolmSessions = 2000;

/// 从 secure storage 全量键值中筛出 Megolm inbound 段。
///
/// [allEntries] 通常来自 `StorageSecureService.to.readAll()`。
/// 返回 map 的键是**去前缀后的 `scope:sessionId`**（载荷更紧凑，回填时补回前缀）。
Map<String, String> collectMegolmSection(Map<String, String> allEntries) {
  final out = <String, String>{};
  for (final e in allEntries.entries) {
    if (!e.key.startsWith(kMegolmInboundPrefix)) continue;
    if (e.value.isEmpty) continue;
    if (out.length >= kMaxMegolmSessions) break;
    out[e.key.substring(kMegolmInboundPrefix.length)] = e.value;
  }
  return out;
}

/// 解析备份载荷里的 Megolm 段。
///
/// fail-closed 取舍：结构不符一律返回空 map 而非抛错——**旧版备份（v1，无该
/// 字段）必须仍能恢复 RSA 私钥**，不能因为缺少可选段就让整个恢复失败。
/// 值非字符串的条目单条跳过（不整包丢弃）。
Map<String, String> parseMegolmSection(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  for (final e in raw.entries) {
    final k = e.key;
    final v = e.value;
    if (k is! String || k.isEmpty) continue;
    if (v is! String || v.isEmpty) continue;
    if (out.length >= kMaxMegolmSessions) break;
    out[k] = v;
  }
  return out;
}

/// 把解析出的 Megolm 段转成 secure storage 的待写入项（键补回前缀）。
///
/// 返回 key→value；调用方负责真正写入（保持本模块纯函数可测）。
Map<String, String> megolmRestoreEntries(Map<String, String> section) {
  final out = <String, String>{};
  for (final e in section.entries) {
    if (e.key.isEmpty || e.value.isEmpty) continue;
    out['$kMegolmInboundPrefix${e.key}'] = e.value;
  }
  return out;
}
