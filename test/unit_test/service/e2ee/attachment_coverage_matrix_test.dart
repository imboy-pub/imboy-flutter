/// C04（附件完整覆盖与卫生）—— 八个生产上传入口的全覆盖矩阵 + 转发/重试 trace
///
/// ## 证据分两层
///
/// **层 1（静态接线契约）**：八个生产入口（文件/相机图片/相机视频/文件选择图片/
/// 相册图片/相册视频/语音/位置缩略图）各自把 `_sealFor(messageId, '<attachmentId>')`
/// 产出的 seal 传给 `AttachmentApi`，且 anchor_msg_id 与最终消息 ID 同值
/// （`attachment_seal_wiring_test` 已锁大半；本文件补 **attachmentId 集合与
/// seal 透传的精确枚举**，让「新增入口漏接线」变成集合差集变红）。
///
/// **层 2（运行时矩阵）**：四类入口最终都汇聚到同一个漏斗
/// `AttachmentApi.uploadViaPresign(seal: …)`（图片实体/视频入口内部同样调它）。
/// 矩阵对每个 (入口 × attachmentId) 组合注入 fake presign/PUT/confirm，
/// 逐格断言：binding → 封装 → PUT 密文（非明文）→ confirm 仅密文元数据 →
/// descriptor 回填 → **接收侧 openForMessage 完整还原**，且全矩阵 content key /
/// base nonce 两两互异（每对象独立）。
///
/// ## 转发与重试 trace（计划 C04 任务 1）
///
/// - 转发：`buildForwardPayload` 语义是「源 metadata 原样展开、目标会话字段
///   覆盖」——附件密文 object_key 与 descriptor（含 content key）随消息复制，
///   但新消息的 binding 输入已变 ⇒ 接收侧拒绝打开（fail-closed，不泄漏）；
///   转发进明文会话时由 `carriesContentKey` 出网闸门拦下。
/// - 重试：PUT 层重试上传**同一份密文字节**（同 key/nonce，绝不 re-seal）；
///   整链重传则生成**全新** key/nonce（跨对象/跨会话从不复用 nonce）。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/e2ee/retry_plaintext_guard.dart';
import 'package:imboy/store/api/attachment_api.dart';

/// 八个生产入口的矩阵行定义。
///
/// [sealCallsInHandler] 是该入口在 `attachment_handler.dart` 里发起的
/// `_sealFor(messageId, …)` 的 attachmentId 序列（相机/相册视频各产生
/// video + video_thumb 两笔）。
class _Entry {
  final String name;
  final String apiMethod;
  final List<String> sealCallsInHandler;
  const _Entry(this.name, this.apiMethod, this.sealCallsInHandler);
}

const List<_Entry> _entries = <_Entry>[
  _Entry('文件', 'uploadBytesViaPresignMeta', ['file']),
  _Entry('相机图片', 'uploadImageEntityViaPresign', ['image']),
  _Entry('相机视频', 'uploadVideoViaPresign', ['video', 'video_thumb']),
  _Entry('文件选择图片', 'uploadBytesViaPresignMeta', ['image']),
  _Entry('相册图片', 'uploadImageEntityViaPresign', ['image']),
  _Entry('相册视频', 'uploadVideoViaPresign', ['video', 'video_thumb']),
  _Entry('语音', 'uploadBytesViaPresignMeta', ['voice']),
  _Entry('位置缩略图', 'uploadBytesViaPresignCompat', ['location_thumb']),
];

/// 每个 (入口, attachmentId) 格运行时的捕获产物。
class _CellResult {
  final String attachmentId;
  final AttachmentDescriptor descriptor;
  final Uint8List putBytes;
  final Map<String, dynamic> confirmBody;
  final Uint8List plaintext;
  const _CellResult(
    this.attachmentId,
    this.descriptor,
    this.putBytes,
    this.confirmBody,
    this.plaintext,
  );
}

/// 对一个 (attachmentId) 格跑完整上传漏斗（注入 fake presign/PUT/confirm）。
Future<_CellResult> _runCell(
  String attachmentId, {
  String messageId = 'msg-1',
}) {
  final plaintext = Uint8List.fromList(
    List<int>.generate(100, (i) => (i * 31 + attachmentId.hashCode) & 0xFF),
  );
  final binding = AttachmentBinding.compute(
    messageId: messageId,
    conversationId: 'c2c:1001:2002',
    senderUid: '1001',
  );
  final seal = AttachmentSealRequest(
    bindingHash: binding,
    attachmentId: attachmentId,
    chunkSize: 32,
  );
  Map<String, dynamic>? confirmBody;
  Uint8List? putBytes;
  return AttachmentApi.uploadViaPresign(
    plaintext,
    '$attachmentId.bin',
    'application/octet-stream',
    scope: 'c2c',
    scopeRef: 'c2c:1001:2002',
    anchorMsgId: messageId,
    seal: seal,
    presignFn: (f, m) async => IMBoyHttpResponse.success(<String, dynamic>{
      'put_url': 'https://example.invalid/put',
      'object_key': 'u1001/2026/10/$attachmentId.bin',
    }),
    putFn: (url, b, mime, process) async {
      putBytes = b;
    },
    confirmFn: (body) async {
      confirmBody = body;
      return IMBoyHttpResponse.success(<String, dynamic>{});
    },
  ).then((_) {
    return _CellResult(
      attachmentId,
      seal.descriptor!,
      putBytes!,
      confirmBody!,
      plaintext,
    );
  });
}

/// 接收侧：按消息字段重算 binding 并开封（openForMessage 的生产语义）。
Uint8List _openAsReceiver(
  _CellResult cell, {
  String messageId = 'msg-1',
  String chatType = 'C2C',
  String fromUid = '1001',
  String toUid = '2002',
}) {
  final payload = <String, dynamic>{
    AttachmentSealPolicy.descriptorPayloadKey: cell.descriptor.toMap(),
    'peer_id': toUid,
    'file_hash256': cell.confirmBody['file_hash256'],
  };
  return AttachmentOpener.openForMessage(
    payload: payload,
    objectBytes: cell.putBytes,
    messageId: messageId,
    chatType: chatType,
    fromUid: fromUid,
    toUid: toUid,
  )!;
}

bool _containsBytes(Uint8List hay, List<int> needle) {
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

void main() {
  final handlerSource = File('lib/page/chat/chat/attachment_handler.dart')
      .readAsStringSync();
  final apiSource = File('lib/store/api/attachment_api.dart')
      .readAsStringSync();

  group('层 1：静态接线契约（八个入口精确枚举）', () {
    test('⚠️ handler 里 _sealFor 的 attachmentId 全集恰为六种、十笔（8 入口）', () {
      final calls = RegExp(r"_sealFor\(\s*messageId,\s*'([a-z_]+)'\s*\)")
          .allMatches(handlerSource)
          .map((m) => m.group(1)!)
          .toList();
      // file×1 + image×3 + video×2 + video_thumb×2 + voice×1 + location_thumb×1
      expect(calls, hasLength(10));
      final expected = <String, int>{
        'file': 1,
        'image': 3,
        'video': 2,
        'video_thumb': 2,
        'voice': 1,
        'location_thumb': 1,
      };
      final actual = <String, int>{};
      for (final c in calls) {
        actual[c] = (actual[c] ?? 0) + 1;
      }
      expect(actual, equals(expected));
    });

    test('矩阵定义与源码一致：每个入口声明的 API 方法都存在且透传 seal', () {
      // 取「方法定义 → 下一个顶层 static 成员」之间的方法体，
      // 避免匹配到方法体内的同名列调用。
      String bodyOf(String name) {
        final def = RegExp('static [^\\n]*\\b$name\\(').firstMatch(apiSource);
        expect(def, isNotNull, reason: '找不到 $name 的定义');
        final start = def!.end;
        final next = RegExp('\\n  static ')
            .allMatches(apiSource.substring(start));
        var end = apiSource.length;
        for (final m in next) {
          end = start + m.start;
          break;
        }
        return apiSource.substring(start, end);
      }

      for (final e in _entries) {
        expect(
          handlerSource,
          contains(e.apiMethod),
          reason: '${e.name} 入口应调用 ${e.apiMethod}',
        );
      }
      // 字节/实体/compat 三个包装方法内部都要把 seal 传给共同漏斗 uploadViaPresign
      for (final method in [
        'uploadBytesViaPresignMeta',
        'uploadImageEntityViaPresign',
        'uploadBytesViaPresignCompat',
      ]) {
        expect(bodyOf(method), contains('seal:'), reason: '$method 未透传 seal');
      }
      // 视频入口（uploadVideoViaPresign）双 seal 透传
      final videoBody = bodyOf('uploadVideoViaPresign');
      expect(videoBody, contains('seal: videoSeal'));
      expect(videoBody, contains('seal: thumbSeal'));
    });

    test('descriptor 的唯一出网通道是消息 payload（不上 presign/confirm）', () {
      // confirmBody 的构造段里不得出现 descriptor 数据或密钥字段字面量。
      // （类名引用 AttachmentDescriptor.supportedCipher 是合法的常量引用，
      // 按数据字段断言而非按类名。）
      final confirmSection = apiSource.substring(
        apiSource.indexOf('final Map<String, dynamic> confirmBody'),
        apiSource.indexOf('final IMBoyHttpResponse confirmResp'),
      );
      expect(confirmSection, isNot(contains('descriptor.toMap')));
      expect(confirmSection, isNot(contains("'content_key'")));
      expect(confirmSection, isNot(contains("'base_nonce'")));
      expect(confirmSection, isNot(contains("'plain_sha256'")));
      // handler 侧 descriptor 只进 metadata 的 descriptorPayloadKey
      final withDescriptor = handlerSource.substring(
        handlerSource.indexOf('Map<String, dynamic> _withDescriptor'),
        handlerSource.indexOf('/// 处理文件选择'),
      );
      expect(withDescriptor, contains('descriptorPayloadKey'));
      expect(
        withDescriptor.indexOf('descriptorPayloadKey'),
        withDescriptor.lastIndexOf('descriptorPayloadKey'),
      );
    });

    test('附件 URL 规范未被破坏：受限资源不走 publicUrl 直读', () {
      // 既有规范：消息附件必须经 AssetsService.viewUrl 授权；
      // 上传链源码不得出现 publicUrl（公开资源直读）调用。
      expect(handlerSource, isNot(contains('publicUrl')));
      expect(apiSource, isNot(contains('publicUrl')));
    });
  });

  group('层 2：运行时矩阵（入口 × attachmentId 逐格全链）', () {
    // 每格 = 一个 _sealFor 调用点（10 格 = 8 入口）。
    final cells = <_CellResult>[];

    setUpAll(() async {
      for (final e in _entries) {
        for (final attachmentId in e.sealCallsInHandler) {
          cells.add(await _runCell(attachmentId));
        }
      }
    });

    test('矩阵规模：8 入口 → 10 格', () {
      expect(cells, hasLength(10));
      expect(cells.map((c) => c.attachmentId).toSet(), {
        'file',
        'image',
        'video',
        'video_thumb',
        'voice',
        'location_thumb',
      });
    });

    test('每格：PUT 的是密文——与明文不同，且无明文 16 字节窗口', () {
      for (final c in cells) {
        expect(c.putBytes, isNot(equals(c.plaintext)));
        expect(
          c.putBytes.length,
          equals(c.plaintext.length + c.descriptor.chunkCount * 16),
        );
        for (var off = 0; off + 16 <= c.plaintext.length; off += 8) {
          expect(
            _containsBytes(c.putBytes, c.plaintext.sublist(off, off + 16)),
            isFalse,
            reason: '${c.attachmentId}：明文偏移 $off 起 16 字节出现在密文里',
          );
        }
      }
    });

    test('每格：confirm 仅密文元数据（密文哈希/大小 + cipher + scope + anchor）', () {
      for (final c in cells) {
        expect(
          c.confirmBody['file_hash256'],
          equals(sha256.convert(c.putBytes).toString()),
        );
        expect(
          c.confirmBody['file_hash256'],
          isNot(equals(sha256.convert(c.plaintext).toString())),
        );
        expect(c.confirmBody['size'], equals(c.putBytes.length));
        expect(c.confirmBody['cipher'], equals('AES-256-GCM'));
        expect(c.confirmBody['anchor_msg_id'], equals('msg-1'));
        expect(c.confirmBody['scope'], equals('c2c'));
        // 白名单：confirm 不携带任何其他字段（尤其不得有 key/nonce/明文哈希）
        expect(c.confirmBody.keys.toSet(), {
          'object_key',
          'file_hash256',
          'mime_type',
          'size',
          'cipher',
          'scope',
          'scope_ref',
          'anchor_msg_id',
        });
      }
    });

    test('每格：descriptor 回填自洽（object_key/plainSize/chunkCount）', () {
      for (final c in cells) {
        expect(c.descriptor.objectKey, contains(c.attachmentId));
        expect(c.descriptor.plainSize, equals(c.plaintext.length));
        expect(
          c.descriptor.chunkCount,
          equals(
            AttachmentDescriptor.expectedChunkCount(c.plaintext.length, 32),
          ),
        );
      }
    });

    test('⚠️ 每格：接收侧 openForMessage 用消息字段完整还原明文', () {
      for (final c in cells) {
        expect(
          _openAsReceiver(c),
          equals(c.plaintext),
          reason: '${c.attachmentId} 接收侧还原失败',
        );
      }
    });

    test('⚠️ 全矩阵 content key 两两互异（同会话两个附件对象 key 不同）', () {
      final keys = cells.map((c) => c.descriptor.contentKey).toList();
      for (var i = 0; i < keys.length; i++) {
        for (var j = i + 1; j < keys.length; j++) {
          expect(keys[i], isNot(equals(keys[j])));
        }
      }
    });

    test('⚠️ 全矩阵 base nonce 两两互异（nonce 从不跨对象复用）', () {
      final nonces = cells.map((c) => c.descriptor.baseNonce).toList();
      for (var i = 0; i < nonces.length; i++) {
        for (var j = i + 1; j < nonces.length; j++) {
          expect(nonces[i], isNot(equals(nonces[j])));
        }
      }
    });

    test('每格：密文哈希两两互异（服务端无法跨对象去重关联）', () {
      final hashes = cells.map((c) => c.confirmBody['file_hash256']).toList();
      expect(hashes.toSet().length, equals(hashes.length));
    });

    test('C2G 会话同样全链可用（群成员用消息字段还原）', () async {
      // 换一个会话形态重跑一格：C2G 的 conversation_id = group_id
      final plaintext = Uint8List.fromList(
        List<int>.generate(80, (i) => (i * 41 + 3) & 0xFF),
      );
      const messageId = 'msg-g1';
      final binding = AttachmentBinding.compute(
        messageId: messageId,
        conversationId: 'g-9',
        senderUid: '1001',
      );
      final seal = AttachmentSealRequest(
        bindingHash: binding,
        attachmentId: 'image',
        chunkSize: 32,
      );
      Uint8List? putBytes;
      await AttachmentApi.uploadViaPresign(
        plaintext,
        'g.jpg',
        'image/jpeg',
        scope: 'group',
        scopeRef: 'g-9',
        anchorMsgId: messageId,
        seal: seal,
        presignFn: (f, m) async => IMBoyHttpResponse.success(<String, dynamic>{
          'put_url': 'https://example.invalid/put',
          'object_key': 'g/2026/10/g.jpg',
        }),
        putFn: (url, b, mime, process) async {
          putBytes = b;
        },
        confirmFn: (body) async =>
            IMBoyHttpResponse.success(<String, dynamic>{}),
      );
      // 群里另一个成员（既非发送者也不在 uk3 里）按消息字段开封
      final payload = <String, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: seal.descriptor!.toMap(),
      };
      expect(
        AttachmentOpener.openForMessage(
          payload: payload,
          objectBytes: putBytes!,
          messageId: messageId,
          chatType: 'C2G',
          fromUid: '1001',
          toUid: 'g-9',
        ),
        equals(plaintext),
      );
    });
  });

  group('转发 trace：descriptor 随消息复制后的三种命运', () {
    late _CellResult cell;

    setUpAll(() async {
      cell = await _runCell('image', messageId: 'msg-src');
    });

    test('转发语义：源 metadata 原样展开 → descriptor 与密文 object_key 一起被复制', () {
      // SendToNotifier.buildForwardPayload 的语义 = {...?sourceMetadata, 目标覆盖}。
      // 这里以同一语义构造（该函数是纯静态展开，见 send_to_provider.dart），
      // 并用源码契约锁住「不剔除 attachment_descriptor」。
      final sourceMetadata = <String, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: cell.descriptor.toMap(),
        'peer_id': '2002',
        'file_hash256': cell.confirmBody['file_hash256'],
      };
      final forwarded = <String, dynamic>{
        ...sourceMetadata,
        'text': '',
        'peer_id': 3003,
        'conversation_uk3': 'C2C_1001_3003',
      };
      expect(
        forwarded[AttachmentSealPolicy.descriptorPayloadKey],
        isNotNull,
        reason: '转发会原样携带含 content key 的 descriptor',
      );

      final providerSource = File('lib/page/chat/send_to/send_to_provider.dart')
          .readAsStringSync();
      expect(
        providerSource,
        isNot(contains('descriptorPayloadKey')),
        reason: 'buildForwardPayload 未对 descriptor 做任何特殊处理（原样复制）',
      );
      expect(
        providerSource,
        contains('...?sourceMetadata'),
        reason: '转发的 payload 语义必须仍是源 metadata 展开',
      );
    });

    test('⚠️ 命运一（加密目标会话）：新消息 binding 已变 → 拒绝打开（fail-closed）', () {
      // 转发消息拿到新 message_id；AAD 绑定的是原消息三元组，
      // 接收侧重算必然失配 → 拒绝，绝不返回半截明文。
      final payload = <String, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: cell.descriptor.toMap(),
      };
      expect(
        () => AttachmentOpener.openForMessage(
          payload: payload,
          objectBytes: cell.putBytes,
          messageId: 'msg-forwarded',
          chatType: 'C2C',
          fromUid: '1001',
          toUid: '3003',
        ),
        throwsA(isA<AttachmentOpenException>()),
        reason: '转发的密文在新消息下必须打不开（ATT-01），坏图而非泄漏',
      );
    });

    test('⚠️ 命运二（明文目标会话）：content key 不得明文出网（闸门拦截）', () {
      final forwardedPayload = <String, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: cell.descriptor.toMap(),
        'text': '',
      };
      // 出网闸门（chat_network_service 明文分支判据）+ 重发闸门（同一判据）
      expect(AttachmentSealPolicy.carriesContentKey(forwardedPayload), isTrue);
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: false,
          e2ee: null,
          carriesContentKey: AttachmentSealPolicy.carriesContentKey(
            forwardedPayload,
          ),
        ),
        isTrue,
        reason: '策略翻成明文也拦：明文出网的钥匙比明文附件更糟',
      );
    });

    test('命运三（本会话消息重放）：同 id 同会话 → 仍可打开（非转发场景回归锚点）', () {
      expect(
        _openAsReceiver(cell, messageId: 'msg-src'),
        equals(cell.plaintext),
      );
    });
  });

  group('重试 trace：同密文重试 + 跨会话重传不复用', () {
    test('⚠️ PUT 层重试：三次尝试上传同一份密文（key/nonce 不变，绝不 re-seal）', () async {
      final plaintext = Uint8List.fromList(
        List<int>.generate(100, (i) => (i * 53 + 5) & 0xFF),
      );
      final seal = AttachmentSealRequest(
        bindingHash: AttachmentBinding.compute(
          messageId: 'msg-retry',
          conversationId: 'c2c:1001:2002',
          senderUid: '1001',
        ),
        attachmentId: 'file',
        chunkSize: 32,
      );
      Uint8List? putBytes;
      await AttachmentApi.uploadViaPresign(
        plaintext,
        'r.bin',
        'application/octet-stream',
        seal: seal,
        presignFn: (f, m) async => IMBoyHttpResponse.success(<String, dynamic>{
          'put_url': 'https://example.invalid/put',
          'object_key': 'u1001/2026/10/r.bin',
        }),
        // 模拟弱网：前两次 PUT 失败，第三次成功。
        // uploadViaPresign 默认 putFn 走 _putToGarage → putWithRetry，
        // 这里注入的 putFn 直接编排 putWithRetry 以观察每次尝试的字节。
        putFn: (url, bytes, mime, process) async {
          putBytes = bytes;
          final attempts = <Uint8List>[];
          await AttachmentApi.putWithRetry(
            url,
            bytes,
            mime,
            process: process,
            singlePut: (u, b, m, p) async {
              attempts.add(b);
              if (attempts.length < 3) {
                throw Exception('network flap');
              }
            },
            delay: (_) async {},
          );
          expect(attempts, hasLength(3));
          // 三次尝试是同一份密文：同 key、同 nonce、同明文 ⇒ 同字节。
          // 若任何一次尝试发生 re-seal（新 key/nonce），字节必然不同。
          expect(attempts[1], equals(attempts[0]));
          expect(attempts[2], equals(attempts[0]));
          expect(attempts[0], equals(putBytes));
        },
        confirmFn: (body) async =>
            IMBoyHttpResponse.success(<String, dynamic>{}),
      );
      expect(putBytes, isNotNull);
      expect(putBytes, isNot(equals(plaintext)));
    });

    test('⚠️ 整链重传：重新走 uploadViaPresign → 全新 key 与 nonce（不复用）', () async {
      Future<AttachmentDescriptor> uploadOnce() async {
        final seal = AttachmentSealRequest(
          bindingHash: AttachmentBinding.compute(
            messageId: 'msg-retry',
            conversationId: 'c2c:1001:2002',
            senderUid: '1001',
          ),
          attachmentId: 'file',
          chunkSize: 32,
        );
        await AttachmentApi.uploadViaPresign(
          Uint8List.fromList(List<int>.generate(100, (i) => i & 0xFF)),
          'r2.bin',
          'application/octet-stream',
          seal: seal,
          presignFn: (f, m) async =>
              IMBoyHttpResponse.success(<String, dynamic>{
                'put_url': 'https://example.invalid/put',
                'object_key': 'u1001/2026/10/r2.bin',
              }),
          putFn: (url, b, mime, process) async {},
          confirmFn: (body) async =>
              IMBoyHttpResponse.success(<String, dynamic>{}),
        );
        return seal.descriptor!;
      }

      final d1 = await uploadOnce();
      final d2 = await uploadOnce();
      // 同 attachmentId、同 binding、同明文：重传必须换全新 key/nonce，
      // 否则两次上传在同一 key 下重复 nonce 派生序列（灾难）。
      expect(d1.contentKey, isNot(equals(d2.contentKey)));
      expect(d1.baseNonce, isNot(equals(d2.baseNonce)));
    });

    test('重试后的密文仍可被接收侧还原（正向锚点）', () async {
      final cell = await _runCell('voice', messageId: 'msg-retry-ok');
      expect(
        _openAsReceiver(cell, messageId: 'msg-retry-ok'),
        equals(cell.plaintext),
      );
    });
  });
}
