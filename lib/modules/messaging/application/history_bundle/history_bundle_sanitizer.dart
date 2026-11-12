/// `BundleSanitizer` —— 禁止字段递归清理（W2-G / chat_history_bundle_v1）。
///
/// 冻结契约：PLAN_SNAPSHOT §4.5 + backend
/// `docs/reference/chat-history-bundle-contract.md` §4。payload 及**任意嵌套层**
/// （map 值 / list 元素递归）不得包含下列字段；发现即清理并计数（clean+count
/// 模式，返回移除数量供测试断言与上层埋点；不做严格拒绝——拒绝语义由
/// `HistoryBundleBuilder` 的类型白名单负责，sanitizer 是纵深防御）。
///
/// ## 冻结禁止字段清单（精确键名）
///
/// | 类别 | 键 |
/// |------|----|
/// | 原消息 id 快照 | `msg_id` / `message_id` / `original_message_id` |
/// | 源会话对端 | `peer_id` |
/// | 源会话标识 | `conversation_uk3` |
/// | 发送者设备身份 | `sender_did` / `sender_dtype` |
/// | 原 E2EE 外层信封 | `e2ee` 前缀键（`e2ee` / `e2ee_v3` / `e2ee_room_key`…）+ `devices` / `protected_header` |
/// | 原 content key / descriptor | `attachment_descriptor` / `content_key` |
/// | 阅后即焚 | `burn_read_at` |
/// | 服务端内部主键（源会话侧 `*_id`） | `auto_id` / `topic_id` / `from_id` / `to_id` |
/// | 原会话成员列表 | `member_list` / `members` / `receivers` |
///
/// 清理输出是**全新深拷贝**（map/list 全层新建，不与输入共享任何可变引用），
/// 输入 payload 不被修改。不可变契约：**顶层 map 保持普通可变**
/// （DTO 层 [HistoryBundleEntryV1] 加 Map.unmodifiable 壳与 dispatcher
/// 写回需要可变输入），**嵌套层（任意深度的 map/list）全不可变**
/// （`Map`/`List.unmodifiable`）。
library;

/// sanitizer 结果：清理后的新 map + 移除字段计数。
class BundleSanitizeResult {
  const BundleSanitizeResult(this.cleaned, this.removedFieldCount);

  /// 清理后的全新深拷贝。
  ///
  /// 不可变契约：**顶层为普通可变 map**（DTO 层加 `Map.unmodifiable` 壳、
  /// dispatcher `withEntryPayload` 写回都需要可变输入）；**嵌套层全不可变**
  /// （map/list 一律 `Map`/`List.unmodifiable`，修改抛 UnsupportedError），
  /// 且与输入不共享任何可变引用。
  final Map<String, dynamic> cleaned;

  /// 在任意嵌套层被移除的禁止字段出现次数（含 list 内元素）。
  final int removedFieldCount;
}

/// 禁止字段判定与递归清理（纯函数，零副作用、零日志）。
abstract final class BundleSanitizer {
  /// 原消息 id 快照键。
  static const Set<String> _messageIdKeys = <String>{
    'msg_id',
    'message_id',
    'original_message_id',
  };

  /// 源会话上下文 / 设备身份 / 信封 / 密钥 / 焚毁 / 内部主键 / 成员列表。
  static const Set<String> _exactForbiddenKeys = <String>{
    'peer_id',
    'conversation_uk3',
    'sender_did',
    'sender_dtype',
    'devices',
    'protected_header',
    'attachment_descriptor',
    'content_key',
    'header_hash',
    'ciphertext',
    'burn_read_at',
    'auto_id',
    'topic_id',
    'from_id',
    'to_id',
    'member_list',
    'members',
    'receivers',
  };

  /// 判定键是否禁止：精确清单命中，或 `e2ee` 前缀（原 E2EE 外层信封族，
  /// 前缀匹配覆盖 `e2ee` / `e2ee_v3` / `e2ee_room_key` / `e2eeRoomKey` 等
  /// 下划线与驼峰变体）。
  static bool isForbiddenKey(String key) {
    if (_exactForbiddenKeys.contains(key)) return true;
    if (_messageIdKeys.contains(key)) return true;
    return key.startsWith('e2ee');
  }

  /// 递归清理 [input]（任意嵌套 map/list 深度），返回新深拷贝与移除计数。
  static BundleSanitizeResult sanitize(Map<String, dynamic> input) {
    final (cleaned, removed) = _sanitizeMap(input);
    return BundleSanitizeResult(cleaned, removed);
  }

  static (Map<String, dynamic>, int) _sanitizeMap(Map<dynamic, dynamic> input) {
    final out = <String, dynamic>{};
    var removed = 0;
    input.forEach((rawKey, value) {
      final key = rawKey is String ? rawKey : rawKey.toString();
      if (isForbiddenKey(key)) {
        removed++;
        return;
      }
      final (v, r) = _sanitizeValue(value);
      removed += r;
      out[key] = v;
    });
    return (out, removed);
  }

  static (Object?, int) _sanitizeValue(Object? value) {
    if (value is Map) {
      final (map, removed) = _sanitizeMap(value);
      // 嵌套 map 与 list 一律不可变（契约：顶层可变、嵌套层全不可变）
      return (Map<String, dynamic>.unmodifiable(map), removed);
    }
    if (value is List) {
      final out = <dynamic>[];
      var removed = 0;
      for (final e in value) {
        final (v, r) = _sanitizeValue(e);
        removed += r;
        out.add(v);
      }
      return (List<dynamic>.unmodifiable(out), removed);
    }
    return (value, 0);
  }
}
