/// Characterization tests for [ChatPageUtils].
///
/// slice-C-1 (TDD characterization): `chat_page_utils.dart` has 4 production
/// callers in `chat_page.dart:301 / 491 / 496 / 501` but **zero** test
/// coverage. This suite钉死当前契约，防止未来改动悄悄破坏编辑窗口 /
/// 阅后即焚元数据构造 / 消息类型判定这几条已稳定的链路。
///
/// **不依赖**：Widget / Riverpod / SQLite / WebSocket。
/// **依赖**：`NtpHelper._offset` 在单测进程默认为 0，`DateTimeHelper.millisecond()`
/// 退化为 `DateTime.now().millisecondsSinceEpoch`。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/utils/chat_page_utils.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  // 共享 fixture
  const uidMe = 'u_me';
  const uidOther = 'u_other';
  TextMessage buildText({
    String authorId = uidMe,
    DateTime? createdAt,
    String id = 'm1',
    Map<String, dynamic>? metadata,
  }) {
    return TextMessage(
      authorId: authorId,
      createdAt: createdAt,
      id: id,
      text: 'hi',
      metadata: metadata,
    );
  }

  ImageMessage buildImage({
    String authorId = uidMe,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ImageMessage(
      authorId: authorId,
      createdAt: createdAt,
      id: 'img1',
      source: 'http://example.com/a.png',
      metadata: metadata,
    );
  }

  CustomMessage buildCustom({
    String authorId = uidMe,
    Map<String, dynamic>? metadata,
  }) {
    return CustomMessage(
      authorId: authorId,
      id: 'c1',
      metadata: metadata,
    );
  }

  group('canEditMessage', () {
    test('非当前用户发送 → false', () {
      final msg = buildText(
        authorId: uidOther,
        createdAt: DateTime.now().toUtc(),
      );
      expect(ChatPageUtils.canEditMessage(msg, uidMe), isFalse);
    });

    test('非文本消息（图片）→ false', () {
      final msg = buildImage(
        authorId: uidMe,
        createdAt: DateTime.now().toUtc(),
      );
      expect(ChatPageUtils.canEditMessage(msg, uidMe), isFalse);
    });

    test('当前用户 + 文本 + 1 分钟前 → true（15 分钟窗口内）', () {
      final oneMinAgo = DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          );
      final msg = buildText(createdAt: oneMinAgo);
      expect(ChatPageUtils.canEditMessage(msg, uidMe), isTrue);
    });

    test('当前用户 + 文本 + 14 分钟前 → true（边界内）', () {
      final edge = DateTime.now().toUtc().subtract(
            const Duration(minutes: 14),
          );
      final msg = buildText(createdAt: edge);
      expect(ChatPageUtils.canEditMessage(msg, uidMe), isTrue);
    });

    test('当前用户 + 文本 + 16 分钟前 → false（窗口外）', () {
      final over = DateTime.now().toUtc().subtract(
            const Duration(minutes: 16),
          );
      final msg = buildText(createdAt: over);
      expect(ChatPageUtils.canEditMessage(msg, uidMe), isFalse);
    });

    test('createdAt=null → 回退为 now → timeDiffMs=0 → true', () {
      // 当前实现：createdAt 缺失时取 nowMs，timeDiffMs 归零，落在窗口内
      // 此断言钉死行为；若未来想把"缺失时间"当作"超时不可编辑"，需显式修改
      final msg = buildText(createdAt: null);
      expect(ChatPageUtils.canEditMessage(msg, uidMe), isTrue);
    });
  });

  group('isBurnMessage', () {
    test('metadata=null → false', () {
      expect(ChatPageUtils.isBurnMessage(buildText(metadata: null)), isFalse);
    });

    test("metadata['burn']=true → true", () {
      final msg = buildText(metadata: const {'burn': true});
      expect(ChatPageUtils.isBurnMessage(msg), isTrue);
    });

    test("metadata['is_burn']=true → true（兼容旧字段）", () {
      final msg = buildText(metadata: const {'is_burn': true});
      expect(ChatPageUtils.isBurnMessage(msg), isTrue);
    });

    test("burn=false 且 is_burn=false → false", () {
      final msg = buildText(metadata: const {'burn': false, 'is_burn': false});
      expect(ChatPageUtils.isBurnMessage(msg), isFalse);
    });

    test("非 bool 值（字符串 'true'）→ false（严格 == true）", () {
      final msg = buildText(metadata: const {'burn': 'true'});
      expect(ChatPageUtils.isBurnMessage(msg), isFalse);
    });
  });

  group('getBurnAfterMs', () {
    test('metadata=null → 0', () {
      expect(ChatPageUtils.getBurnAfterMs(buildText()), 0);
    });

    test("burn_after_ms 是 int → 原样返回", () {
      final msg = buildText(metadata: const {'burn_after_ms': 30000});
      expect(ChatPageUtils.getBurnAfterMs(msg), 30000);
    });

    test("burn_after_ms 是 String 数字 → parse", () {
      final msg = buildText(metadata: const {'burn_after_ms': '45000'});
      expect(ChatPageUtils.getBurnAfterMs(msg), 45000);
    });

    test("burn_after_ms 是非数字 String → 0", () {
      final msg = buildText(metadata: const {'burn_after_ms': 'abc'});
      expect(ChatPageUtils.getBurnAfterMs(msg), 0);
    });

    test("burn_after_ms 缺失时回退到 expiry_time", () {
      final msg = buildText(metadata: const {'expiry_time': 60000});
      expect(ChatPageUtils.getBurnAfterMs(msg), 60000);
    });

    test("burn_after_ms 优先于 expiry_time", () {
      final msg = buildText(metadata: const {
        'burn_after_ms': 10000,
        'expiry_time': 99999,
      });
      expect(ChatPageUtils.getBurnAfterMs(msg), 10000);
    });

    test("两键都缺 → 0", () {
      final msg = buildText(metadata: const {'other': 'x'});
      expect(ChatPageUtils.getBurnAfterMs(msg), 0);
    });
  });

  group('withBurnMetadata', () {
    test('burnEnabled=false → 原 base 不变（引用相同）', () {
      final base = <String, dynamic>{'msg_type': 'text'};
      final result = ChatPageUtils.withBurnMetadata(
        base: base,
        burnEnabled: false,
        burnAfterMs: 30000,
      );
      expect(identical(result, base), isTrue,
          reason: '不启用时直接返回原 Map，避免无谓复制');
    });

    test('burnEnabled=true → 新 Map + burn=true + burn_after_ms + expire_secs', () {
      final base = <String, dynamic>{'msg_type': 'text'};
      final result = ChatPageUtils.withBurnMetadata(
        base: base,
        burnEnabled: true,
        burnAfterMs: 30000,
      );
      expect(result['burn'], isTrue);
      expect(result['burn_after_ms'], 30000);
      expect(result['expire_secs'], 30, reason: '30000ms → 30s（四舍五入）');
      expect(result['msg_type'], 'text', reason: 'base 字段原样保留');
      expect(identical(result, base), isFalse, reason: '必须返回新 Map 不污染 base');
    });

    test('burnAfterMs=500 → expire_secs=1（四舍五入：500→0.5→1）', () {
      final result = ChatPageUtils.withBurnMetadata(
        base: {},
        burnEnabled: true,
        burnAfterMs: 500,
      );
      expect(result['expire_secs'], 1);
    });

    test('burnAfterMs=499 → 跳过 expire_secs（(499/1000).round()=0）', () {
      // 当前实现 `if (expireSecs > 0)` 过滤掉 0，契约：<=499ms 不写 expire_secs
      final result = ChatPageUtils.withBurnMetadata(
        base: {},
        burnEnabled: true,
        burnAfterMs: 499,
      );
      expect(result.containsKey('expire_secs'), isFalse);
      expect(result['burn_after_ms'], 499);
    });

    test('burnAfterMs=0 → 跳过 expire_secs，但保留 burn=true / burn_after_ms=0', () {
      final result = ChatPageUtils.withBurnMetadata(
        base: {},
        burnEnabled: true,
        burnAfterMs: 0,
      );
      expect(result['burn'], isTrue);
      expect(result['burn_after_ms'], 0);
      expect(result.containsKey('expire_secs'), isFalse);
    });

    test('base 含同名键 → 被 burn 字段覆写', () {
      final result = ChatPageUtils.withBurnMetadata(
        base: {'burn': false, 'burn_after_ms': 9999},
        burnEnabled: true,
        burnAfterMs: 5000,
      );
      expect(result['burn'], isTrue);
      expect(result['burn_after_ms'], 5000);
    });
  });

  group('isTextMessage / isImageMessage (类型判定)', () {
    test('TextMessage → isText=true / isImage=false', () {
      final msg = buildText();
      expect(ChatPageUtils.isTextMessage(msg), isTrue);
      expect(ChatPageUtils.isImageMessage(msg), isFalse);
    });

    test('ImageMessage → isImage=true / isText=false', () {
      final msg = buildImage();
      expect(ChatPageUtils.isImageMessage(msg), isTrue);
      expect(ChatPageUtils.isTextMessage(msg), isFalse);
    });
  });

  group('isVideoMessage / isAudioMessage / isFileMessage (metadata.msg_type)', () {
    test("metadata['msg_type']='video' → isVideo=true", () {
      final msg = buildCustom(metadata: const {'msg_type': MessageType.video});
      expect(ChatPageUtils.isVideoMessage(msg), isTrue);
      expect(ChatPageUtils.isAudioMessage(msg), isFalse);
      expect(ChatPageUtils.isFileMessage(msg), isFalse);
    });

    test("metadata['msg_type']='voice' → isAudio=true", () {
      final msg = buildCustom(metadata: const {'msg_type': MessageType.voice});
      expect(ChatPageUtils.isAudioMessage(msg), isTrue);
      expect(ChatPageUtils.isVideoMessage(msg), isFalse);
    });

    test("metadata['msg_type']='file' → isFile=true", () {
      final msg = buildCustom(metadata: const {'msg_type': MessageType.file});
      expect(ChatPageUtils.isFileMessage(msg), isTrue);
    });

    test('metadata=null → 全 false（不会崩溃）', () {
      final msg = buildCustom(metadata: null);
      expect(ChatPageUtils.isVideoMessage(msg), isFalse);
      expect(ChatPageUtils.isAudioMessage(msg), isFalse);
      expect(ChatPageUtils.isFileMessage(msg), isFalse);
    });

    test("msg_type='text' → 三个 builder 均为 false", () {
      final msg = buildCustom(metadata: const {'msg_type': MessageType.text});
      expect(ChatPageUtils.isVideoMessage(msg), isFalse);
      expect(ChatPageUtils.isAudioMessage(msg), isFalse);
      expect(ChatPageUtils.isFileMessage(msg), isFalse);
    });
  });

  group('getMessageType', () {
    test("有 msg_type → 返回字符串", () {
      final msg = buildCustom(metadata: const {'msg_type': 'video'});
      expect(ChatPageUtils.getMessageType(msg), 'video');
    });

    test('metadata=null → "unknown"', () {
      expect(ChatPageUtils.getMessageType(buildCustom()), 'unknown');
    });

    test('metadata 不含 msg_type → "unknown"', () {
      final msg = buildCustom(metadata: const {'other': 'x'});
      expect(ChatPageUtils.getMessageType(msg), 'unknown');
    });

    test('msg_type=空字符串 → 原样返回 ""（非 "unknown"）', () {
      // 当前实现用 `?? 'unknown'` 只对 null 兜底，空串会原样返回
      // 此断言暴露当前契约；若希望"空串视为未知"需显式改代码
      final msg = buildCustom(metadata: const {'msg_type': ''});
      expect(ChatPageUtils.getMessageType(msg), '');
    });
  });

  group('isFromCurrentUser', () {
    test('authorId == uid → true', () {
      expect(
          ChatPageUtils.isFromCurrentUser(buildText(authorId: uidMe), uidMe),
          isTrue);
    });

    test('authorId != uid → false', () {
      expect(
          ChatPageUtils.isFromCurrentUser(
              buildText(authorId: uidOther), uidMe),
          isFalse);
    });

    test('uid 为空字符串 → false（正常消息 authorId 非空）', () {
      expect(
          ChatPageUtils.isFromCurrentUser(buildText(authorId: uidMe), ''),
          isFalse);
    });
  });
}
