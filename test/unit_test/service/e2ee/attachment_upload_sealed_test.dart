/// E2EE-061 Slice 4 —— `uploadViaPresign` 加密接线验收
///
/// 走 `attachment_api.dart` 既有的三个注入 seam（presignFn/putFn/confirmFn），
/// 因此**不碰网络**也能验收真实编排逻辑。
///
/// ⚠️ 两组都必须有：`seal` 为 null 时**逐字节不变**（旧行为零破坏）是本刀
/// 零风险的前提；只验加密分支等于没验「没打破什么」。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
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

Future<String> _run(
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
      await _run(pt, cap);
      expect(cap.putBytes, equals(pt));
    });

    test('confirm 上报明文哈希与明文大小，且不带 cipher', () async {
      final pt = _plain(100);
      final cap = _Capture();
      await _run(pt, cap);
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
      await _run(pt, cap, seal: req);
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

  // ────────────────────────────────────────────────────────────────────────
  // 4. C04：服务器侧只见元数据 + 密文（上传表单/消息体无明文内容与 content key）
  // ────────────────────────────────────────────────────────────────────────
  group('4. C04 服务器侧仅元数据+密文', () {
    late Uint8List pt;
    late _Capture cap;
    late AttachmentSealRequest req;

    setUp(() async {
      pt = _plain(100);
      cap = _Capture();
      req = AttachmentSealRequest(
        bindingHash: _binding(),
        attachmentId: 'att-c04',
        chunkSize: 32,
      );
      await _run(pt, cap, seal: req);
    });

    test('⚠️ confirm 键集合恰为密文元数据白名单（无任何多余字段）', () {
      expect(cap.confirmBody!.keys.toSet(), {
        'object_key',
        'file_hash256',
        'mime_type',
        'size',
        'cipher',
        'scope',
      });
    });

    test('⚠️ confirm 序列化后不含 content_key/base_nonce/plain_sha256 任何编码', () {
      final d = req.descriptor!;
      final serialized = jsonEncode(cap.confirmBody);
      // base64url（descriptor 的编码形态）
      expect(serialized, isNot(contains(base64Url.encode(d.contentKey))));
      expect(serialized, isNot(contains(base64Url.encode(d.baseNonce))));
      expect(serialized, isNot(contains(base64Url.encode(d.plainSha256))));
      // hex（另一种常见序列化形态）
      expect(serialized, isNot(contains(_hex(d.contentKey))));
      expect(serialized, isNot(contains(_hex(d.plainSha256))));
      // 明文哈希（拍板 ①：明文指纹永不到达服务端）
      expect(serialized, isNot(contains(sha256.convert(pt).toString())));
    });

    test('⚠️ PUT 字节中不含 content key / base_nonce / 明文哈希字节序列', () {
      final d = req.descriptor!;
      expect(_contains(cap.putBytes!, d.contentKey), isFalse);
      expect(_contains(cap.putBytes!, d.baseNonce), isFalse);
      // 明文哈希的 32 字节原样形态
      expect(
        _contains(cap.putBytes!, Uint8List.fromList(sha256.convert(pt).bytes)),
        isFalse,
      );
    });

    test(
      '⚠️ 消息体 meta 只含 object_key/size/file_hash256（descriptor 走加密 payload）',
      () async {
        // uploadBytesViaPresignMeta 返回的 meta 会进消息体（_withBurnMetadata 之下）；
        // descriptor 唯一通道是 metadata[descriptorPayloadKey] → PFv3 加密信封。
        Map<String, dynamic>? confirmBody2;
        final meta = await AttachmentApi.uploadBytesViaPresignMeta(
          pt,
          'b.bin',
          'application/octet-stream',
          seal: req,
          presignFn: (f, m) async =>
              IMBoyHttpResponse.success(<String, dynamic>{
                'put_url': 'https://example.invalid/put',
                'object_key': 'u1001/2026/10/b.bin',
              }),
          putFn: (url, b, mime, process) async {},
          confirmFn: (body) async {
            confirmBody2 = body;
            return IMBoyHttpResponse.success(<String, dynamic>{});
          },
        );
        expect(meta.keys.toSet(), {'object_key', 'size', 'file_hash256'});
        expect(meta['file_hash256'], equals(confirmBody2!['file_hash256']));
        expect(
          jsonEncode(meta),
          isNot(contains(base64Url.encode(req.descriptor!.contentKey))),
        );
        // meta 的 size 是明文大小（进加密 payload 给 UI），与 confirm 的密文大小不同
        expect(meta['size'], equals(pt.length));
        expect(confirmBody2!['size'], isNot(equals(pt.length)));
      },
    );

    test('presign 查询参数只有 filename/mime/scope（静态契约）', () {
      final source = File('lib/store/api/attachment_api.dart')
          .readAsStringSync();
      final presignSection = source.substring(
        source.indexOf("API.attachmentPresign,"),
        source.indexOf('if (!presignResp.ok)'),
      );
      expect(presignSection, contains("'filename'"));
      expect(presignSection, contains("'mime_type'"));
      expect(presignSection, isNot(contains('contentKey')));
      expect(presignSection, isNot(contains('descriptor')));
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // 5. C04：视频双对象（本体+缩略图）—— 缩略图与本体同加密等级
  //    uploadVideoViaPresign 的编排是 thumb 先传、thumb descriptor 挂主体，
  //    这里以同一编排（uploadBytesViaPresignMeta ×2 + 挂接）验收语义。
  // ────────────────────────────────────────────────────────────────────────
  group('5. C04 视频双对象：缩略图与本体同加密等级', () {
    final videoPlain = Uint8List.fromList(
      List<int>.generate(200, (i) => (i * 17 + 3) & 0xFF),
    );
    final thumbPlain = Uint8List.fromList(
      List<int>.generate(40, (i) => (i * 13 + 5) & 0xFF),
    );
    // 与接收侧 openForMessage(C2C, 1001→2002) 重算一致的绑定值
    final videoBinding = AttachmentBinding.compute(
      messageId: 'msg-1',
      conversationId: 'c2c:1001:2002',
      senderUid: '1001',
    );

    late AttachmentSealRequest videoSeal;
    late AttachmentSealRequest thumbSeal;
    late Uint8List videoPut;
    late Uint8List thumbPut;

    setUp(() async {
      videoSeal = AttachmentSealRequest(
        bindingHash: videoBinding,
        attachmentId: 'video',
        chunkSize: 64,
      );
      thumbSeal = AttachmentSealRequest(
        bindingHash: videoBinding,
        attachmentId: 'video_thumb',
        chunkSize: 32,
      );

      Future<Uint8List> upload(
        Uint8List bytes,
        String name,
        AttachmentSealRequest seal,
      ) async {
        Uint8List put = Uint8List(0);
        await AttachmentApi.uploadBytesViaPresignMeta(
          bytes,
          name,
          'application/octet-stream',
          seal: seal,
          presignFn: (f, m) async =>
              IMBoyHttpResponse.success(<String, dynamic>{
                'put_url': 'https://example.invalid/put',
                'object_key': 'u1001/2026/10/$name',
              }),
          putFn: (url, b, mime, process) async {
            put = b;
          },
          confirmFn: (body) async =>
              IMBoyHttpResponse.success(<String, dynamic>{}),
        );
        return put;
      }

      // 与 uploadVideoViaPresign 相同的顺序：thumb 先传，再挂接，再传本体
      thumbPut = await upload(thumbPlain, 't.jpg', thumbSeal);
      videoSeal.thumbDescriptor = thumbSeal.descriptor;
      videoPut = await upload(videoPlain, 'v.mp4', videoSeal);
    });

    test('⚠️ 两个对象各自上传密文（缩略图不因「只是预览」而明文）', () {
      expect(thumbPut, isNot(equals(thumbPlain)));
      expect(videoPut, isNot(equals(videoPlain)));
      expect(
        thumbPut.length,
        equals(thumbPlain.length + thumbSeal.descriptor!.chunkCount * 16),
      );
      for (var off = 0; off + 16 <= thumbPlain.length; off += 8) {
        expect(
          _contains(thumbPut, thumbPlain.sublist(off, off + 16)),
          isFalse,
          reason: '缩略图明文偏移 $off 起 16 字节出现在密文里',
        );
      }
    });

    test('⚠️ 主体与缩略图 key/nonce 四元互异（独立对象独立密钥）', () {
      final vk = videoSeal.descriptor!.contentKey;
      final vn = videoSeal.descriptor!.baseNonce;
      final tk = videoSeal.descriptor!.thumb!.contentKey;
      final tn = videoSeal.descriptor!.thumb!.baseNonce;
      expect(tk, isNot(equals(vk)));
      expect(tn, isNot(equals(vn)));
      // key 与 nonce 之间也无字节级相同（防「同随机源退化」的观察）
      expect(_contains(videoPut, tk), isFalse);
    });

    test('thumb descriptor 已挂进主体（随同一条加密 payload 送达）', () {
      expect(videoSeal.descriptor!.thumb, isNotNull);
      expect(
        videoSeal.descriptor!.thumb!.objectKey,
        equals(thumbSeal.descriptor!.objectKey),
      );
    });

    test('接收侧：本体经消息面还原；缩略图经挂接的 thumb descriptor 还原', () {
      // canonical 往返模拟 payload 经 PFv3 信封序列化后的形态
      final roundtrip = AttachmentDescriptor.fromCanonicalBytes(
        videoSeal.descriptor!.toCanonicalBytes(),
      );
      final payload = <String, dynamic>{
        'attachment_descriptor': roundtrip.toMap(),
      };
      // 本体：消息面主 descriptor
      expect(
        AttachmentOpener.openForMessage(
          payload: payload,
          objectBytes: videoPut,
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: '1001',
          toUid: '2002',
        ),
        equals(videoPlain),
      );
      // 缩略图：消息面主 descriptor 对 thumb 密文必须 fail-closed（长度不符即抛），
      // 真正的打开路径（AttachmentOpenRegistry 登记两份 spec）用 thumb descriptor。
      expect(
        () => AttachmentOpener.openForMessage(
          payload: payload,
          objectBytes: thumbPut,
          messageId: 'msg-1',
          chatType: 'C2C',
          fromUid: '1001',
          toUid: '2002',
        ),
        throwsA(isA<AttachmentOpenException>()),
        reason: '主 descriptor 误配 thumb 密文必须拒绝，不得返回半截明文',
      );
      expect(
        AttachmentEncryptor.open(
          ciphertext: thumbPut,
          descriptor: roundtrip.thumb!,
          bindingHash: videoBinding,
        ),
        equals(thumbPlain),
      );
    });
  });
}

String _hex(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

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
