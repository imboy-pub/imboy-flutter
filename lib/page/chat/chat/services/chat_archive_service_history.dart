part of 'chat_archive_service.dart';

/// 归档历史行 → [MessageRepo.batchInsertOfflineMessages] 期望形状（P1-2）
///
/// 后端 encode_history_msg 已把 from_id/to_id → from/to，chat_type 为
/// 'c2c'/'c2g'。此处只补两点：① chat_type → type（C2C/C2G）；② C2G 行的
/// to 为 null，用 group_id 兜底作群会话键。完整信封仅解包正文，其余（msg_type/e2ee/
/// created_at 等）原样透传。纯函数，供单测覆盖字段映射正确性。
Map<String, dynamic> archiveRowToOfflineShape(Map<String, dynamic> row) {
  final chatType = (row['chat_type'] ?? '').toString().toLowerCase();
  final type = chatType == 'c2g' ? 'C2G' : 'C2C';
  final out = Map<String, dynamic>.from(row);
  out['type'] = type;
  final envelope = row['payload'];
  if (envelope is Map &&
      row['msg_id'] != null &&
      envelope['id']?.toString() == row['msg_id']?.toString() &&
      envelope['type'] == type &&
      envelope.containsKey('payload')) {
    out['payload'] = envelope['payload'];
    if (envelope.containsKey('action')) out['action'] = envelope['action'];
  }

  if (type == 'C2G') {
    final to = out['to'];
    if (to == null || to.toString().isEmpty) {
      final gid = row['group_id'];
      if (gid != null) {
        out['to'] = gid;
      }
    }
  }
  return out;
}
