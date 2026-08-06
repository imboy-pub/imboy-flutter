/// E2EE-061 Slice 3 —— `attachment_descriptor` codec 验收（ATT-03 的结构部分）
///
/// ⚠️ 与 Slice 2 同理：「一律拒绝」的 parser 在拒收矩阵上恒得满分，
/// 因此每组都配正向可用性锚点（合法 descriptor **必须**被接受并原样往返）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';

Uint8List _bytes(int fill, int len) =>
    Uint8List.fromList(List<int>.filled(len, fill));

/// 合法样本：100 字节明文、32 字节分块 → 4 块
Map<String, dynamic> validMap({
  Map<String, dynamic>? patch,
  bool thumb = false,
}) {
  final m = <String, dynamic>{
    'attachment_id': 'att-0001',
    'object_key': 'u10086/2026/07/abc.bin',
    'content_key': base64Url.encode(_bytes(0x11, 32)),
    'cipher': 'AES-256-GCM',
    'chunk_size': 32,
    'chunk_count': 4,
    'base_nonce': base64Url.encode(_bytes(0x22, 12)),
    'plain_size': 100,
    'plain_sha256': base64Url.encode(_bytes(0x33, 32)),
    'mime': 'application/octet-stream',
    'name': 'abc.bin',
  };
  if (thumb) {
    m['thumb'] = <String, dynamic>{
      'attachment_id': 'att-0001-thumb',
      'object_key': 'u10086/2026/07/abc-thumb.bin',
      'content_key': base64Url.encode(_bytes(0x44, 32)),
      'cipher': 'AES-256-GCM',
      'chunk_size': 32,
      'chunk_count': 1,
      'base_nonce': base64Url.encode(_bytes(0x55, 12)),
      'plain_size': 20,
      'plain_sha256': base64Url.encode(_bytes(0x66, 32)),
      'mime': 'image/jpeg',
      'name': 'abc-thumb.jpg',
    };
  }
  if (patch != null) m.addAll(patch);
  return m;
}

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  group('1. 正向可用性：合法 descriptor 必须被接受并原样往返', () {
    test('map 往返：解析后再序列化恒等', () {
      final m = validMap();
      expect(AttachmentDescriptor.fromMap(m).toMap(), equals(m));
    });

    test('带 thumb 的 map 往返', () {
      final m = validMap(thumb: true);
      expect(AttachmentDescriptor.fromMap(m).toMap(), equals(m));
    });

    test('canonical CBOR 往返：字段值逐项还原', () {
      final d = AttachmentDescriptor.fromMap(validMap(thumb: true));
      final back = AttachmentDescriptor.fromCanonicalBytes(
        d.toCanonicalBytes(),
      );
      expect(back.attachmentId, equals(d.attachmentId));
      expect(back.objectKey, equals(d.objectKey));
      expect(back.contentKey, equals(d.contentKey));
      expect(back.baseNonce, equals(d.baseNonce));
      expect(back.plainSha256, equals(d.plainSha256));
      expect(back.chunkCount, equals(d.chunkCount));
      expect(back.plainSize, equals(d.plainSize));
      expect(back.thumb?.contentKey, equals(d.thumb?.contentKey));
    });

    test('canonical 编码确定性：同一 descriptor 恒产出同一串字节', () {
      final a = AttachmentDescriptor.fromMap(validMap()).toCanonicalBytes();
      final b = AttachmentDescriptor.fromMap(validMap()).toCanonicalBytes();
      expect(a, equals(b));
    });

    test('无 thumb 时不产出 thumb 键（不写 null 占位）', () {
      expect(
        AttachmentDescriptor.fromMap(validMap()).toMap(),
        isNot(contains('thumb')),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('2. chunk_count 自洽：谎报块数的直接闸门', () {
    test('对照组：整除与不整除两种边界的期望值', () {
      // 100/32 → 4（向上取整）；128/32 → 4（整除）
      expect(AttachmentDescriptor.expectedChunkCount(100, 32), equals(4));
      expect(AttachmentDescriptor.expectedChunkCount(128, 32), equals(4));
      expect(AttachmentDescriptor.expectedChunkCount(129, 32), equals(5));
      expect(AttachmentDescriptor.expectedChunkCount(1, 32), equals(1));
    });

    test('空文件取 1 块而非 0（0 块 = 一个字节都没被认证）', () {
      expect(AttachmentDescriptor.expectedChunkCount(0, 32), equals(1));
      final d = AttachmentDescriptor.fromMap(
        validMap(patch: {'plain_size': 0, 'chunk_count': 1}),
      );
      expect(d.chunkCount, equals(1));
    });

    test('谎报少一块（截断）→ 拒收', () {
      expect(
        () => AttachmentDescriptor.fromMap(validMap(patch: {'chunk_count': 3})),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('谎报多一块 → 拒收', () {
      expect(
        () => AttachmentDescriptor.fromMap(validMap(patch: {'chunk_count': 5})),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('改 plain_size 但不改 chunk_count → 拒收', () {
      expect(
        () =>
            AttachmentDescriptor.fromMap(validMap(patch: {'plain_size': 300})),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('改 chunk_size 但不改 chunk_count → 拒收', () {
      expect(
        () => AttachmentDescriptor.fromMap(validMap(patch: {'chunk_size': 64})),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('三者同步改动 → 接受（自洽即可，本闸门不是"只准一种取值"）', () {
      final d = AttachmentDescriptor.fromMap(
        validMap(
          patch: {'plain_size': 300, 'chunk_size': 64, 'chunk_count': 5},
        ),
      );
      expect(d.chunkCount, equals(5));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('3. 严格 parser：字段缺失 / 类型 / 未知键', () {
    void rejects(Map<String, dynamic> m, String why) {
      expect(
        () => AttachmentDescriptor.fromMap(m),
        throwsA(isA<AttachmentDescriptorException>()),
        reason: why,
      );
    }

    for (final k in [
      'attachment_id',
      'object_key',
      'content_key',
      'cipher',
      'chunk_size',
      'chunk_count',
      'base_nonce',
      'plain_size',
      'plain_sha256',
      'mime',
      'name',
    ]) {
      test('缺少必填字段 "$k" → 拒收', () {
        rejects(validMap()..remove(k), '$k 是必填');
      });
    }

    test('未知字段 → 拒收（静默忽略等于给未来的降级字段留后门）', () {
      rejects(validMap(patch: {'legacy_plaintext_url': 'https://x/y'}), '未知键');
    });

    test('int 字段传 String → 拒收（不做强制转换）', () {
      rejects(validMap(patch: {'chunk_count': '4'}), '类型不符');
    });

    test('String 字段传 int → 拒收', () {
      rejects(validMap(patch: {'mime': 1}), '类型不符');
    });

    test('thumb 不是 map → 拒收', () {
      rejects(validMap(patch: {'thumb': 'nope'}), 'thumb 类型');
    });

    test('base64url 非法 → 拒收', () {
      rejects(validMap(patch: {'content_key': '!!!not-base64!!!'}), '编码非法');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('4. 安全字段的长度与取值 fail-closed', () {
    void rejects(Map<String, dynamic> patch, String why) {
      expect(
        () => AttachmentDescriptor.fromMap(validMap(patch: patch)),
        throwsA(isA<AttachmentDescriptorException>()),
        reason: why,
      );
    }

    test('content_key 不是 32 字节 → 拒收', () {
      rejects({
        'content_key': base64Url.encode(_bytes(0x11, 16)),
      }, '128-bit 不是 AES-256');
    });

    test('base_nonce 不是 12 字节 → 拒收', () {
      rejects({
        'base_nonce': base64Url.encode(_bytes(0x22, 16)),
      }, 'GCM nonce 长度');
    });

    test('plain_sha256 不是 32 字节 → 拒收', () {
      rejects({
        'plain_sha256': base64Url.encode(_bytes(0x33, 20)),
      }, 'SHA-256 全长');
    });

    test('cipher 不是 AES-256-GCM → 拒收（不做套件协商）', () {
      rejects({'cipher': 'AES-128-GCM'}, '弱套件');
      rejects({'cipher': 'none'}, '明文伪装成一种"套件"');
    });

    test('空 attachment_id / object_key / mime / name → 拒收', () {
      rejects({'attachment_id': ''}, '空 id 会让不同附件共用同一 AAD');
      rejects({'object_key': ''}, '空对象标识');
      rejects({'mime': ''}, '空 mime');
      rejects({'name': ''}, '空文件名');
    });

    test('plain_size 为负 → 拒收', () {
      rejects({'plain_size': -1, 'chunk_count': 1}, '负长度');
    });

    test('plain_size 超过上传上限 → 拒收', () {
      final over = AttachmentDescriptor.maxPlainSize + 1;
      rejects({'plain_size': over, 'chunk_size': over, 'chunk_count': 1}, '越界');
    });

    test('chunk_size < 1 → 拒收', () {
      rejects({'chunk_size': 0}, '零长分块');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('5. 缩略图必须独立（设计 §3.3：缩略图不加密 = 预览即泄漏）', () {
    test('正向：独立 key + 独立 nonce 的 thumb 被接受', () {
      expect(
        AttachmentDescriptor.fromMap(validMap(thumb: true)).thumb,
        isNotNull,
      );
    });

    test('thumb 与主体复用 content_key → 拒收', () {
      final m = validMap(thumb: true);
      (m['thumb'] as Map<String, dynamic>)['content_key'] = m['content_key'];
      expect(
        () => AttachmentDescriptor.fromMap(m),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('thumb 与主体复用 base_nonce → 拒收', () {
      final m = validMap(thumb: true);
      (m['thumb'] as Map<String, dynamic>)['base_nonce'] = m['base_nonce'];
      expect(
        () => AttachmentDescriptor.fromMap(m),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('thumb 里再套 thumb → 拒收（防无界嵌套）', () {
      final m = validMap(thumb: true);
      final t = m['thumb'] as Map<String, dynamic>;
      final inner = validMap();
      inner['attachment_id'] = 'att-0001-thumb-thumb';
      inner['content_key'] = base64Url.encode(_bytes(0x77, 32));
      inner['base_nonce'] = base64Url.encode(_bytes(0x88, 12));
      t['thumb'] = inner;
      expect(
        () => AttachmentDescriptor.fromMap(m),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });

    test('thumb 自身同样受全部严格校验（坏 cipher 传不进去）', () {
      final m = validMap(thumb: true);
      (m['thumb'] as Map<String, dynamic>)['cipher'] = 'none';
      expect(
        () => AttachmentDescriptor.fromMap(m),
        throwsA(isA<AttachmentDescriptorException>()),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('6. toString 不得泄漏密钥', () {
    // HOTFIX-01 的教训：日志/异常里不得出现消息正文。
    // descriptor 里躺着的是**能解开整个附件的密钥**，一次 '$d' 就写进日志了。
    test('toString 不含 content_key / base_nonce 的任何编码形式', () {
      final d = AttachmentDescriptor.fromMap(validMap(thumb: true));
      final s = d.toString();
      final keyB64 = base64Url.encode(d.contentKey);
      final nonceB64 = base64Url.encode(d.baseNonce);
      expect(s, isNot(contains(keyB64)));
      expect(s, isNot(contains(nonceB64)));
      // 原始字节的十进制/十六进制形态同样不得出现
      expect(s, isNot(contains(d.contentKey.join(','))));
      expect(s, contains('<redacted>'));
    });

    test('正向可用性：toString 仍带得出可诊断的非敏感字段', () {
      final s = AttachmentDescriptor.fromMap(validMap()).toString();
      expect(s, contains('att-0001'));
      expect(s, contains('chunk_count: 4'));
    });
  });
}
