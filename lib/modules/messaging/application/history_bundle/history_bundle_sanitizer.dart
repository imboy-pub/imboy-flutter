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

/// sanitizer 结果：清理后的新 map + 移除字段计数 + 深度超限标志。
class BundleSanitizeResult {
  const BundleSanitizeResult(
    this.cleaned,
    this.removedFieldCount, {
    this.depthExceeded = false,
  });

  /// 清理后的全新深拷贝。
  ///
  /// 不可变契约：**顶层为普通可变 map**（DTO 层加 `Map.unmodifiable` 壳、
  /// dispatcher `withEntryPayload` 写回需要可变输入）；**嵌套层全不可变**
  /// （map/list 一律 `Map`/`List.unmodifiable`，修改抛 UnsupportedError），
  /// 且与输入不共享任何可变引用。
  final Map<String, dynamic> cleaned;

  /// 在任意嵌套层被移除的禁止字段出现次数（含 list 内元素）。
  final int removedFieldCount;

  /// 深度超限标志（S1-M1）：payload 任意分支的容器嵌套深度超过
  /// [BundleSanitizer.defaultMaxDepth] 时为 true（超限子树被丢弃）。
  ///
  /// **调用方必须检查本标志并稳定拒绝**，不得把超深 payload 当作已清理
  /// 通过：builder 对应条目整体拒绝（`bundle_payload_depth_exceeded`）；
  /// dispatcher writeback 路径按 sendFailed 口径整目标失败（接线归
  /// BundleForwardDispatcher，G4 lane）。默认 false，既有两参构造与
  /// 调用点不受影响。
  final bool depthExceeded;
}

/// 禁止字段判定与递归清理（纯函数，零副作用、零日志）。
///
/// 递归带深度上限（[defaultMaxDepth]，默认 16）：攻击者可用深嵌套 JSON
/// 消息体（不受 bundle 256 KiB 约束）把无界递归推成栈溢出（DoS 点）。
/// 超限走**稳定失败**——置位 [BundleSanitizeResult.depthExceeded] 并丢弃
/// 超限子树，绝不栈溢出、绝不静默通过（范式同 e2ee 出站闸
/// `isSealedPayloadDeep` 的 maxDepth fail-closed，71a15d834）。
abstract final class BundleSanitizer {
  /// 递归深度上限：容器（map/list）自顶向下最多嵌套 16 层。
  ///
  /// 口径：顶层 map 不计层，其下第 16 层容器仍合法，第 17 层起
  /// fail-closed。业务 payload（含附件 descriptor）远浅于该上限。
  ///
  /// 口径注（W5-R2 复审 I-4）：本闸 16 层容器 vs
  /// [AttachmentSealPolicy.isSealedPayloadDeep] 的 8 层 wrapper——9-16 层
  /// 干净嵌套可过 sanitize 但会被出网 deep 扫描永久拒发（fail-closed
  /// 方向安全）；真实构建器只产生 ≤2 层。
  static const int defaultMaxDepth = 16;

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

  /// 递归清理 [input]（任意嵌套 map/list，深度上限 [maxDepth]），返回
  /// 新深拷贝、移除计数与深度超限标志（见 [BundleSanitizeResult]）。
  static BundleSanitizeResult sanitize(
    Map<String, dynamic> input, {
    int maxDepth = defaultMaxDepth,
  }) {
    final (cleaned, removed, depthExceeded) = _sanitizeMap(input, maxDepth);
    return BundleSanitizeResult(cleaned, removed, depthExceeded: depthExceeded);
  }

  /// 有界深度探测：[value] 子树内任一容器分支嵌套超过 [maxDepth] 层
  /// 返回 true（口径与 [sanitize] 一致：顶层容器不计层，其下第
  /// [maxDepth]+1 层容器即超限）。递归帧数 ≤ maxDepth+2，永不栈溢出。
  ///
  /// 共用前置闸（S1-M1）：builder 在附件任务深拷贝前探测源 payload、
  /// v1 在 jsonEncode 前探测序列化树。
  static bool depthOverLimit(Object? value, {int maxDepth = defaultMaxDepth}) =>
      _valueOverLimit(value, maxDepth + 1);

  /// 剩余深度预算归零即超限（容器才消耗预算；标量任意层合法）。
  static bool _valueOverLimit(Object? value, int remaining) {
    if (value is Map) {
      if (remaining <= 0) return true;
      for (final v in value.values) {
        if (_valueOverLimit(v, remaining - 1)) return true;
      }
      return false;
    }
    if (value is List) {
      if (remaining <= 0) return true;
      for (final e in value) {
        if (_valueOverLimit(e, remaining - 1)) return true;
      }
      return false;
    }
    return false;
  }

  static (Map<String, dynamic>, int, bool) _sanitizeMap(
    Map<dynamic, dynamic> input,
    int remaining,
  ) {
    final out = <String, dynamic>{};
    var removed = 0;
    var depthExceeded = false;
    input.forEach((rawKey, value) {
      final key = rawKey is String ? rawKey : rawKey.toString();
      if (isForbiddenKey(key)) {
        removed++;
        return;
      }
      final (v, r, d) = _sanitizeValue(value, remaining);
      removed += r;
      depthExceeded = depthExceeded || d;
      out[key] = v;
    });
    return (out, removed, depthExceeded);
  }

  static (Object?, int, bool) _sanitizeValue(Object? value, int remaining) {
    if (value is Map) {
      if (remaining <= 0) {
        // 深度超限：丢弃整棵子树并置位标志——调用方必须稳定拒绝
        // （fail-closed；不得栈溢出、不得静默当清理完成）。
        return (null, 0, true);
      }
      final (map, removed, depthExceeded) = _sanitizeMap(value, remaining - 1);
      // 嵌套 map 与 list 一律不可变（契约：顶层可变、嵌套层全不可变）
      return (Map<String, dynamic>.unmodifiable(map), removed, depthExceeded);
    }
    if (value is List) {
      if (remaining <= 0) {
        return (null, 0, true);
      }
      final out = <dynamic>[];
      var removed = 0;
      var depthExceeded = false;
      for (final e in value) {
        final (v, r, d) = _sanitizeValue(e, remaining - 1);
        removed += r;
        depthExceeded = depthExceeded || d;
        out.add(v);
      }
      return (List<dynamic>.unmodifiable(out), removed, depthExceeded);
    }
    return (value, 0, false);
  }
}
