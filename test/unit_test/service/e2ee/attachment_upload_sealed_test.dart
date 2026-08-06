/// E2EE-061 Slice 4 —— `uploadViaPresign` 加密接线验收
///
/// 走 `attachment_api.dart` 既有的三个注入 seam（presignFn/putFn/confirmFn），
/// 因此**不碰网络**也能验收真实编排逻辑。
///
/// ⚠️ 两组都必须有：`seal` 为 null 时**逐字节不变**（旧行为零破坏）是本刀
/// 零风险的前提；只验加密分支等于没验「没打破什么」。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/store/api/attachment_api.dart';

Uint8List _plain(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + 7) & 0xFF));

Uint8List _binding() => AttachmentBinding.compute(
  messageId: 'msg-1',
  conversationId: 'c2c:1:2',
  senderUid: '1001',
);

/// 捕获三个 seam 的实参
class _Capture {
  Uint8List? putBytes;
  String? putMime;
  Map<String, dynamic>? confirmBody;
}

Future<String> run(
  Uint8List bytes,
  _Capture cap, {
  AttachmentSealRequest? seal,
}) {
  return AttachmentApi.uploadViaPresign(
    bytes,
    'a.bin',
    'application/octet-stream',
    seal: seal,
    presignFn: (f, m) async => IMBoyHttpResponse.success(<String, dynamic>{
      'put_url': 'https://example.invalid/put',
      'object_key': 'u1001/2026/07/a.bin',
    }),
    putFn: (url, b, mime, process) async {
      cap.putBytes = b;
      cap.putMime = mime;
    },
    confirmFn: (body) async {
      cap.confirmBody = body;
      return IMBoyHttpResponse.success(<String, dynamic>{});
    },
  );
}

void main() {
  group('1. seal 为 null：旧行为逐字节不变（零破坏）', () {
    test('PUT 的是明文本身', () async {
      final pt = _plain(100);
      final cap = _Capture();
      await run(pt, cap);
      expect(cap.putBytes, equals(pt));
    });

    test('confirm 上报明文哈希与明文大小，且不带 cipher', () async {
      final pt = _plain(100);
      final cap = _Capture();
      await run(pt, cap);
      expect(
        cap.confirmBody!['file_hash256'],
        equals(sha256.convert(pt).toString()),
      );
      expect(cap.confirmBody!['size'], equals(100));
      expect(cap.confirmBody!.containsKey('cipher'), isFalse);
    });
  });

  group('2. seal 非 null：上传密文', () {
    late Uint8List pt;
    late _Capture cap;
    late AttachmentSealRequest req;

    setUp(() async {
      pt = _plain(100);
      cap = _Capture();
      req = AttachmentSealRequest(
        bindingHash: _binding(),
        attachmentId: 'att-1',
        chunkSize: 32,
      );
      await run(pt, cap, seal: req);
    });

    test('PUT 的不是明文，且长度是密文长度（每块 +16 字节 tag）', () {
      expect(cap.putBytes, isNot(equals(pt)));
      expect(cap.putBytes!.length, equals(100 + 4 * 16));
    });

    test('⚠️ 明文的任何连续片段都不出现在上传字节里', () {
      final body = cap.putBytes!;
      for (var off = 0; off + 16 <= pt.length; off += 8) {
        final needle = pt.sublist(off, off + 16);
        expect(
          _contains(body, needle),
          isFalse,
          reason: '明文偏移 $off 起的 16 字节原样出现在密文里',
        );
      }
    });

    test('⚠️ 拍板 ①：confirm 上报的是密文哈希，绝不是明文哈希', () {
      expect(
        cap.confirmBody!['file_hash256'],
        equals(sha256.convert(cap.putBytes!).toString()),
      );
      expect(
        cap.confirmBody!['file_hash256'],
        isNot(equals(sha256.convert(pt).toString())),
      );
    });

    test('confirm 上报密文大小并带上 cipher 判别位', () {
      expect(cap.confirmBody!['size'], equals(cap.putBytes!.length));
      expect(cap.confirmBody!['cipher'], equals('AES-256-GCM'));
    });

    test('MIME 按拍板保持真实值（不隐藏），presign 契约无需改动', () {
      expect(cap.putMime, equals('application/octet-stream'));
      expect(cap.confirmBody!['mime_type'], equals('application/octet-stream'));
    });

    test('descriptor 被回填，且 object_key 与实际上传的一致', () {
      expect(req.descriptor, isNotNull);
      expect(req.descriptor!.objectKey, equals('u1001/2026/07/a.bin'));
      expect(req.descriptor!.plainSize, equals(100));
      expect(req.descriptor!.chunkCount, equals(4));
    });

    test('正向可用性：用回填的 descriptor 能把上传字节还原成原明文', () {
      expect(
        AttachmentEncryptor.open(
          ciphertext: cap.putBytes!,
          descriptor: req.descriptor!,
          bindingHash: _binding(),
        ),
        equals(pt),
      );
    });

    test('⚠️ content key 只在 descriptor 内，绝不出现在任何上送字段里', () {
      final keyB64 = base64Url.encode(req.descriptor!.contentKey);
      final serialized = jsonEncode(cap.confirmBody);
      expect(serialized, isNot(contains(keyB64)));
      expect(_contains(cap.putBytes!, req.descriptor!.contentKey), isFalse);
    });
  });

  group('3. fail-closed', () {
    test('空 attachmentId → 构造即抛（不会静默产出可互换的 AAD）', () {
      expect(
        () => AttachmentSealRequest(bindingHash: _binding(), attachmentId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

bool _contains(Uint8List hay, Uint8List needle) {
  if (needle.isEmpty || needle.length > hay.length) return false;
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
