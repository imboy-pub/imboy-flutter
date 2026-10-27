/// 会话内消息稳定排序定义（R07 phase1 排序基建，纯 Dart，无平台依赖）。
///
/// 权威顺序键（v35 起落库）：
/// - `conv_seq`：服务端权威会话内序号，NULL=服务端尚未给出（存量旧消息 /
///   兼容窗口），**绝不本地伪造**。
/// - `accepted_at`：首次服务端接受毫秒，NULL=无该事实。
///
/// 会话内升序比较规则（**只在同一会话内使用**；不同会话的 seq 互不可比，
/// 跨会话比较结果无定义，调用方不得依赖）：
///
/// 1. 组次序：无 conv_seq 的历史消息整体排在有 conv_seq 的消息之前
///    （"conv_seq 优先"：有 seq 的消息按权威序排；无 seq 的旧消息不散插
///    进权威段中间）。
/// 2. 有 seq 组内：按 conv_seq 升序（服务端保证唯一）。
/// 3. 回退键（无 seq 组内，及 seq 相等的异常数据兜底）：
///    `accepted_at ?? created_at` 升序（旧消息两列均 NULL 时回退
///    created_at）。
/// 4. 仍相等 → 按 `id`（服务端 msg_id）升序。
/// 5. 仍相等（异常：同会话同 msg_id 不应存在）→ 按 `auto_id` 升序兜底，
///    保证可重复全序（稳定排序，重复执行结果相同）。
///
/// SQL 等价形态见 [orderByAsc]；Dart 侧比较器为 [compareAsc]。两者必须
/// 保持同序（message_order_test 双向守护）。加载更多/定位消息/撤回后
/// 会话头重算（OfflineMessageWriter.recomputeConversationHead，W3 产物）
/// 在接线（R07-wire）时消费本定义，不另造次序。
library;

import 'package:imboy/store/model/message_columns.dart';

/// 消息排序键值对象（从行数据提取，避免比较器依赖完整 Model）。
typedef MessageOrderKey = ({
  int? convSeq,
  int? acceptedAt,
  int createdAt,
  int id,
  int autoId,
});

/// 会话内排序基建（纯静态，无状态）。
class ConversationOrder {
  ConversationOrder._();

  /// 会话内升序 ORDER BY 片段（与 [compareAsc] 同序）。
  ///
  /// 列均使用 MessageColumns 常量；调用方拼接 `WHERE` 后直接使用。
  static String get orderByAsc =>
      '(CASE WHEN ${MessageColumns.convSeq} IS NULL THEN 0 ELSE 1 END) ASC, '
      'COALESCE(${MessageColumns.convSeq}, 0) ASC, '
      'COALESCE(${MessageColumns.acceptedAt}, ${MessageColumns.createdAt}) ASC, '
      '${MessageColumns.id} ASC, '
      '${MessageColumns.autoId} ASC';

  /// 会话内降序（升序取反，用于"最新在前"列表/分页游标）。
  ///
  /// 注意：逐键取反而非字符串逆序——`CASE` 表达式不可简单 DESC 逆用。
  static String get orderByDesc =>
      '(CASE WHEN ${MessageColumns.convSeq} IS NULL THEN 0 ELSE 1 END) DESC, '
      'COALESCE(${MessageColumns.convSeq}, 0) DESC, '
      'COALESCE(${MessageColumns.acceptedAt}, ${MessageColumns.createdAt}) DESC, '
      '${MessageColumns.id} DESC, '
      '${MessageColumns.autoId} DESC';

  /// 会话内升序比较器（全序、可重复；规则见文件头，与 [orderByAsc] 同构）。
  ///
  /// 返回负数表示 a 排在 b 前。
  static int compareAsc(MessageOrderKey a, MessageOrderKey b) {
    // 规则 1：组次序——无 seq 的历史消息排前
    final aHas = a.convSeq != null;
    final bHas = b.convSeq != null;
    if (aHas != bHas) return aHas ? 1 : -1;

    // 规则 2：有 seq 组内按 conv_seq（无 seq 组两值均 null，相等跳过）
    if (aHas && bHas) {
      final c = a.convSeq!.compareTo(b.convSeq!);
      if (c != 0) return c;
    }

    // 规则 3：回退接受时间轴（含 seq 相等的异常兜底路径）
    final aAccepted = a.acceptedAt ?? a.createdAt;
    final bAccepted = b.acceptedAt ?? b.createdAt;
    if (aAccepted != bAccepted) return aAccepted.compareTo(bAccepted);

    // 规则 4：msg_id 定序
    if (a.id != b.id) return a.id.compareTo(b.id);

    // 规则 5：auto_id 全序兜底
    return a.autoId.compareTo(b.autoId);
  }

  /// 降序比较器（= 升序取反）。
  static int compareDesc(MessageOrderKey a, MessageOrderKey b) =>
      -compareAsc(a, b);
}
