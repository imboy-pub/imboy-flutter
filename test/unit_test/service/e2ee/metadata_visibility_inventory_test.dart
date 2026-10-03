/// C17 元数据可见性 inventory 测试（run-20261003-094804，AC-34 前置）
///
/// 目的：把《privacy-profile.md》现状矩阵中**可静态断言**的部分固化成
/// 合同测试，防止将来无意识地扩大服务器/被动观察者可见的元数据面。
/// 本测试**不改变生产行为**，只做两类断言：
///
/// 1. **运行时合同**：直接调用纯函数（ProtectedFrameV3 构造器），断言
///    PFv3 外层信封与 protected_header 的字段集合恰好等于白名单——
///    新增字段会让测试失败，提示作者把它同步进 visibility 矩阵与
///    privacy-profile.md 并评估元数据影响。
/// 2. **源码合同**：对无法在单测环境实例化的发送路径
///    （sendWsMsg / sendMessage / _encryptC2COlmFanOut / sendInputStatus /
///    buildReadReceiptItem），用与 logger_bypass_guard_test.dart 相同的
///    源码文本断言模式，锁定帧字段集合与关键防漂移锚点。
///
/// 背景：E2EE 只保护内容，不保护元数据。本清单是"今天外露什么"的
/// 底线快照（inventory），不是"应该外露什么"的规范——最小化决策与
/// 开销预算见 docs（imboy 仓）：
/// docs/design/2026-10-03-e2ee-production-excellence/privacy-profile.md
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

/// 从包根读源码文件（flutter test 的 cwd 是包根）。
String readLib(String relPath) => File('lib/$relPath').readAsStringSync();

/// 提取 Dart 源码里第一个以 [opening] 起始的 map 字面量的键名集合。
///
/// 简化实现：从 [opening] 之后做花括号配对（忽略字符串与注释内的
/// 括号），再在配对区间内收集 ` 'key': ` 形式的顶层键。
/// 只服务本文件锁定的锚点（键均为简单标识符、无嵌套同名键需求）。
Set<String> mapLiteralKeys(String source, String opening) {
  final start = source.indexOf(opening);
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: '锚点未找到: $opening（发送路径重构？请同步更新本测试）',
  );
  var depth = 0;
  var i = start;
  var inString = false;
  var stringQuote = '';
  var stringStart = -1;
  final keys = <String>{};
  while (i < source.length) {
    final c = source[i];
    if (inString) {
      // 处理转义（含 \' 换行形式）
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == stringQuote) {
        inString = false;
        // 字符串刚结束：回看这是否是 `'key' :` 形式的 map 键。
        // （进入字符串时开头引号已被消费，普通扫描无法命中正则。）
        final m = RegExp("'([A-Za-z_][A-Za-z0-9_]*)'\\s*:")
            .matchAsPrefix(source, stringStart);
        if (m != null && depth == 1) {
          keys.add(m.group(1)!);
        }
      }
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      stringQuote = c;
      stringStart = i;
      i++;
      continue;
    }
    // 行注释
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      final nl = source.indexOf('\n', i);
      if (nl < 0) break;
      i = nl + 1;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) break;
    }
    i++;
  }
  return keys;
}

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // 1. PFv3 protected_header 字段白名单（运行时合同）
  // ─────────────────────────────────────────────────────────────────────

  /// 这 15 个键是 ADR 15 §3.1 冻结字段。其中绝大多数在传输中以明文
  /// （base64url CBOR）出现，服务器与被动观察者可直接读取：
  /// message_id / scope / conversation_id / sender_uid / sender_did /
  /// destination / message_type / action / created_at_ms / protocol /
  /// protocol_version / session_ref / epoch_or_counter / content_encoding / v。
  /// 变更此清单 = 变更元数据暴露面，必须先更新 privacy-profile.md。
  const protectedHeaderWhitelist = <String>{
    'v',
    'message_id',
    'scope',
    'conversation_id',
    'sender_uid',
    'sender_did',
    'destination',
    'message_type',
    'action',
    'created_at_ms',
    'protocol',
    'protocol_version',
    'session_ref',
    'epoch_or_counter',
    'content_encoding',
  };

  FrameContext sampleContext() => const FrameContext(
    messageId: 'msg-inv-001',
    scope: FrameScope.c2c,
    conversationId: 'c2c:101:202',
    senderUid: '101',
    senderDid: 'did-A',
    destination: '202',
    messageType: 'text',
    action: 'message',
    createdAtMs: 1759400000000,
    protocol: 'olm',
    protocolVersion: 1,
    sessionRef: 'session-ref-1',
    epochOrCounter: 0,
  );

  test('PFv3 protected_header 字段集合 == 白名单（元数据暴露面快照）', () {
    final header = ProtectedFrameV3.buildProtectedHeader(sampleContext());
    expect(header.keys.toSet(), protectedHeaderWhitelist);
  });

  test('PFv3 外层信封字段集合 == 白名单（5 字段，无额外外露）', () {
    final envelope = ProtectedFrameV3.encodeOuterEnvelope(
      context: sampleContext(),
      ciphertext: Uint8List.fromList(List.filled(64, 7)),
      protocolMetadata: const {},
    );
    expect(envelope.keys.toSet(), <String>{
      'meta_version',
      'protected_header',
      'header_hash',
      'ciphertext',
      'protocol_metadata',
    });
  });

  test('PFv3 header 内含时序元数据 created_at_ms（现状固化，非认可）', () {
    final header = ProtectedFrameV3.buildProtectedHeader(sampleContext());
    expect(
      header['created_at_ms'],
      isA<int>(),
      reason:
          'created_at_ms 是服务器可见的毫秒时间戳；移除或加抖动时'
          '请同步更新 privacy-profile.md §时序',
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // 2. WS 发送帧顶层字段（源码合同：sendWsMsg 的 msg map）
  // ─────────────────────────────────────────────────────────────────────

  test('sendWsMsg 顶层 msg 字段集合 == 白名单（9 字段）', () {
    final source = readLib('page/chat/chat/services/chat_network_service.dart');
    final keys = mapLiteralKeys(source, "final Map<String, dynamic> msg = {");
    expect(
      keys,
      <String>{
        'id',
        'type',
        'from',
        'to',
        'msg_type',
        'action',
        'e2ee',
        'payload',
        'created_at',
      },
      reason:
          '发送帧顶层字段即服务器明文可见面；新增字段=扩大暴露面，'
          '必须同步 privacy-profile.md §1 矩阵与 visibility-matrix',
    );
  });

  test('发送帧顶层不携带可推断内容/长度的明文字段', () {
    final source = readLib('page/chat/chat/services/chat_network_service.dart');
    final keys = mapLiteralKeys(source, "final Map<String, dynamic> msg = {");
    // 这些键只允许出现在加密后的 payload 内部（密文），绝不允许提升到
    // 顶层：size/width/height/duration 可直接推断内容长度，text/uri/name
    // 是内容本体。
    const forbidden = <String>{
      'text',
      'uri',
      'size',
      'name',
      'width',
      'height',
      'duration_ms',
      'waveform',
      'thumbhash',
      'file_hash256',
      'mime_type',
    };
    expect(
      keys.intersection(forbidden),
      isEmpty,
      reason:
          '内容/长度可推断字段出现在 WS 帧顶层（明文可见），'
          '违反 E2EE 元数据最小化底线',
    );
  });

  test('加密分支 removeKeys 含 client_send_ts（发送时刻不随密文外露）', () {
    final source = readLib('page/chat/chat/services/chat_network_service.dart');
    expect(
      source.contains("removeKeys: ['client_send_ts']"),
      isTrue,
      reason:
          'sendWsMsg 的 E2EE 分支必须把 client_send_ts 从明文 payload '
          '中移除后再加密；该锚点消失说明时间戳可能进入明文分支或被移入'
          '密文外可见字段——请复核 privacy-profile.md §时序并更新本测试',
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // 3. C2C Olm per-device fan-out 信封（源码合同）
  // ─────────────────────────────────────────────────────────────────────

  test('C2C fan-out e2ee 信封字段集合 == 白名单（6 字段 + devices 映射）', () {
    final source = readLib('page/chat/chat/services/chat_network_service.dart');
    final keys = mapLiteralKeys(
      source,
      "final e2ee = <String, dynamic>{\n      'meta_version': 3,",
    );
    expect(
      keys,
      <String>{
        'meta_version',
        'protocol',
        'version',
        'fan_out',
        'devices',
        'skipped_devices',
      },
      reason:
          'fan-out 信封的 devices 键是「对端设备 ID → 逐设备密文」'
          '映射：服务器可见收件设备列表（设备关系图谱）；skipped_devices '
          '（C07 逐设备套件门卫跳过项）同样向服务器暴露设备 ID 集合，'
          '计入同一图谱面。此结构变更需同步 privacy-profile.md §设备关系',
    );
  });

  test('编辑消息仅向 e2ee 外层附加 edit_of/relay_action 路由引用', () {
    final source = readLib('page/chat/chat/services/chat_network_service.dart');
    // _addEditRoutingMetadata 与 _editOuterMetadata 两个出口都只加这两个键。
    final addMetaBlock = source.indexOf('..[\'edit_of\'] = editOf');
    expect(
      addMetaBlock,
      greaterThan(0),
      reason:
          '_addEditRoutingMetadata 的 edit_of 附加逻辑缺失/重构，'
          '请同步更新本测试锚点',
    );
    expect(source.contains("['edit_of'] = editOf"), isTrue);
    expect(source.contains("'relay_action'"), isTrue);
  });

  // ─────────────────────────────────────────────────────────────────────
  // 4. typing 帧与已读回执（源码合同：明文控制通道字段清单）
  // ─────────────────────────────────────────────────────────────────────

  test('typing 帧 inputMessage 字段集合 == 白名单（8 字段、payload 仅 status）', () {
    final source = readLib('service/message_actions.dart');
    final keys = mapLiteralKeys(source, "final inputMessage = {");
    // 注意：typing 帧不带 created_at 显式时间戳（服务器以到达时间为准）。
    expect(
      keys,
      <String>{
        'id',
        'type',
        'from',
        'to',
        'msg_type',
        'action',
        'e2ee',
        'payload',
      },
      reason:
          'typing 是明文控制帧：服务器可见「谁在何时向谁输入」。'
          '字段集变更需同步 privacy-profile.md §typing',
    );
  });

  test('已读回执 buildReadReceiptItem 字段集合 == 白名单', () {
    final source = readLib('page/chat/chat/services/chat_network_service.dart');
    final keys = mapLiteralKeys(
      source,
      "return <String, dynamic>{\n      'id': Xid().toString(),\n      'type': type,",
    );
    expect(
      keys,
      <String>{
        'id',
        'type',
        'from',
        'to',
        'msg_type',
        'action',
        'e2ee',
        'payload',
        'created_at',
      },
      reason:
          '已读回执 payload 含 msg_ids+read_at（明文）：服务器可见'
          '「谁在何时读了哪些消息」。字段集变更需同步 privacy-profile.md §已读',
    );
  });

  test('typing 发送节流常量为 3 秒（时序指纹抑制的现状锚点）', () {
    final source = readLib(
      'modules/messaging/domain/policy/typing_indicator_rules.dart',
    );
    expect(
      source.contains('const Duration(seconds: 3)'),
      isTrue,
      reason:
          'typing 节流窗口从 3 秒改小时会放大键盘节奏指纹；改大则损伤'
          'UX。任何调整请同步 privacy-profile.md §时序的最小化开销预算',
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // 5. Olm/Megolm protocol_metadata 外露键（源码合同）
  // ─────────────────────────────────────────────────────────────────────

  test('Olm protocol_metadata 键集合 == 白名单（7 键）', () {
    final source = readLib('service/e2ee/olm_protocol.dart');
    final keys = mapLiteralKeys(
      source,
      "return E2eeCiphertext(res.ciphertext, {",
    );
    expect(
      keys,
      <String>{
        'protocol',
        'version',
        'e2ee_suite',
        'peer_uid',
        'peer_device_id',
        'message_type',
        'session_id',
      },
      reason:
          'Olm 信封的 protocol_metadata 以明文随帧传输：含 peer_uid/'
          'peer_device_id（身份与设备关联）与 session_id（会话连续性）。'
          '变更需同步 privacy-profile.md §会话标识',
    );
  });

  test('Megolm protocol_metadata 键集合 == 白名单（5-7 键）', () {
    final source = readLib('service/e2ee/megolm_protocol.dart');
    final keys = mapLiteralKeys(source, "final m = <String, dynamic>{");
    expect(
      keys,
      <String>{'protocol', 'version', 'e2ee_suite', 'session_id'},
      reason:
          'Megolm _meta 基础 4 键（gid/scope 按场景条件附加，'
          '不在基础字面量内）。session_id/gid 明文随帧外露',
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // 6. 密文长度相关性现状（inventory 事实，防"以为已有 padding"的漂移）
  // ─────────────────────────────────────────────────────────────────────

  test('PFv3 信封无 padding 机制：ciphertext 长度直接随明文变化（现状固化）', () {
    // 构造两个仅差一个字符的 inner payload，比较信封 ciphertext 长度：
    // 长度差应≈1（CBOR+base64 后呈线性），证明当前实现没有长度填充。
    // 这不是缺陷断言，而是把"密文长度≈明文长度"这一矩阵事实钉住：
    // 未来引入 padding 后，此测试应更新为断言长度落入固定桶。
    String envelopeFor(String text) {
      final base = sampleContext();
      final ctx = FrameContext(
        messageId: base.messageId,
        scope: base.scope,
        conversationId: base.conversationId,
        senderUid: base.senderUid,
        senderDid: base.senderDid,
        destination: base.destination,
        messageType: text,
        action: base.action,
        createdAtMs: base.createdAtMs,
        protocol: base.protocol,
        protocolVersion: base.protocolVersion,
        sessionRef: base.sessionRef,
        epochOrCounter: base.epochOrCounter,
      );
      final env = ProtectedFrameV3.encodeOuterEnvelope(
        context: ctx,
        ciphertext: Uint8List.fromList(List.filled(64, 7)),
        protocolMetadata: const {},
      );
      // message_type 进入明文 header，长度直接可见
      return env['protected_header'] as String;
    }

    final short = envelopeFor('text').length;
    final long = envelopeFor('custom_type_with_long_name_32b').length;
    expect(
      long - short,
      greaterThan(8),
      reason:
          'protected_header 长度随 message_type 长度线性变化（差>8 '
          'base64 字符）——服务器无需解密即可读出精确长度信息（现状，非缺陷）',
    );
  });
}
