/// 多图（imageMulti）转发重封装契约测试
///
/// 源消息 `images[i]` 各带 descriptor（发送侧按源三元组封装）；转发时
/// [AttachmentForward.reSealImages] 必须：
/// - 逐图下载 → 认证解密 → 按目标三元组重封装 → 重上传，并改写 uri /
///   file_hash256 / size / descriptor（attachmentId 沿用源值）；
/// - 明文项原样保留；
/// - 任一项失败 → [AttachmentForwardException]，不留下半转发状态；
/// - [AttachmentForward.decide] 对嵌套钥匙同样走三域一致性判定。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_forward.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/store/api/attachment_api.dart';

const _srcMsg = 'msg-src-multi';
const _srcConv = 'c2c:1001:2002';
const _srcUid = '1001';
const _srcPeer = '2002';
const _fwdUid = '3003';
const _newMsgId = 'msg-fwd-multi';
const _targetConv = 'c2c:3003:4004';

Uint8List _plain(int n, int seed) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + seed) & 0xFF));

Uint8List _srcBinding() => AttachmentBinding.compute(
  messageId: _srcMsg,
  conversationId: _srcConv,
  senderUid: _srcUid,
);

Uint8List _dstBinding() => AttachmentBinding.compute(
  messageId: _newMsgId,
  conversationId: _targetConv,
  senderUid: _fwdUid,
);

/// 源侧第 [i] 张图：发送侧 seal 产物（descriptor + 密文 + 明文）。
({Map<String, dynamic> item, Uint8List cipher, Uint8List plain}) _sealSrc(
  int i,
) {
  final pt = _plain(150 + i, i);
  final s = AttachmentEncryptor.seal(
    plaintext: pt,
    bindingHash: _srcBinding(),
    attachmentId: 'image_$i',
    objectKey: 'u1001/src/$i.bin',
    mime: 'image/jpeg',
    name: 'p$i.jpg',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: 64,
  );
  return (
    item: <String, dynamic>{
      'uri': s.descriptor.objectKey,
      'width': 10,
      'height': 20,
      'size': pt.length,
      'file_hash256': 'src-hash-$i',
      AttachmentSealPolicy.descriptorPayloadKey: s.descriptor.toMap(),
    },
    cipher: s.ciphertext,
    plain: pt,
  );
}

/// 捕获上传链三个 seam（与 attachment_forward_test 同构）。
class _UploadCapture {
  final List<String> objectKeys = [];
  final List<Uint8List> putBytes = [];
  final List<Map<String, dynamic>> confirmBodies = [];

  PresignFn get presignFn => (f, m) async {
    final k = 'u-dest/${objectKeys.length}/$f';
    objectKeys.add(k);
    return IMBoyHttpResponse.success(<String, dynamic>{
      'put_url': 'https://example.invalid/put/${objectKeys.length}',
      'object_key': k,
    });
  };

  PutFn get putFn =>
      (url, b, mime, process) async => putBytes.add(b);

  ConfirmFn get confirmFn => (body) async {
    confirmBodies.add(body);
    return IMBoyHttpResponse.success(<String, dynamic>{});
  };
}

Future<List<Map<String, dynamic>>> _reSeal(
  Map<String, dynamic> sourcePayload,
  Map<String, Uint8List> ciphers,
  _UploadCapture cap, {
  String sourceMessageId = _srcMsg,
}) => AttachmentForward.reSealImages(
  sourcePayload: sourcePayload,
  sourceMessageId: sourceMessageId,
  sourceChatType: 'C2C',
  sourceFromUid: _srcUid,
  sourceToUid: _srcPeer,
  newMessageId: _newMsgId,
  targetScope: 'private',
  targetConversationId: _targetConv,
  forwarderUid: _fwdUid,
  fetchCiphertext: (key) async {
    final c = ciphers[key];
    if (c == null) throw Exception('unknown object $key');
    return c;
  },
  presignFn: cap.presignFn,
  putFn: cap.putFn,
  confirmFn: cap.confirmFn,
);

Map<String, dynamic> _payload(List<Map<String, dynamic>> items) => {
  'peer_id': _srcPeer,
  'conversation_uk3': 'C2C_1001_2002',
  AttachmentSealPolicy.imagesPayloadKey: items,
  'total': items.length,
};

void main() {
  group('1. 全部加密的多图转发', () {
    late _UploadCapture cap;
    late List<({Map<String, dynamic> item, Uint8List cipher, Uint8List plain})>
    src;
    late List<Map<String, dynamic>> out;

    setUp(() async {
      cap = _UploadCapture();
      src = [_sealSrc(0), _sealSrc(1), _sealSrc(2)];
      out = await _reSeal(_payload([for (final s in src) s.item]), {
        for (final s in src) s.item['uri'] as String: s.cipher,
      }, cap);
    });

    test('逐图重上传：N 次 presign/put/confirm，顺序与源一致', () {
      expect(cap.objectKeys, hasLength(3));
      expect(cap.putBytes, hasLength(3));
      expect(cap.confirmBodies, hasLength(3));
      expect([for (final e in out) e['uri']], cap.objectKeys);
    });

    test('接收方按新三元组可逐图打开，内容与原件逐字节一致', () {
      for (var i = 0; i < 3; i++) {
        final d = AttachmentDescriptor.fromMap(
          Map<String, dynamic>.from(
            out[i][AttachmentSealPolicy.descriptorPayloadKey] as Map,
          ),
        );
        expect(d.attachmentId, 'image_$i');
        final opened = AttachmentEncryptor.open(
          ciphertext: cap.putBytes[i],
          descriptor: d,
          bindingHash: _dstBinding(),
        );
        expect(opened, src[i].plain);
      }
    });

    test('新 key / 新 nonce / 新密文 与原件互异；旧 descriptor 在新绑定下打不开', () {
      for (var i = 0; i < 3; i++) {
        final newD = AttachmentDescriptor.fromMap(
          Map<String, dynamic>.from(
            out[i][AttachmentSealPolicy.descriptorPayloadKey] as Map,
          ),
        );
        final oldD = AttachmentDescriptor.fromMap(
          Map<String, dynamic>.from(
            src[i].item[AttachmentSealPolicy.descriptorPayloadKey] as Map,
          ),
        );
        expect(newD.contentKey, isNot(equals(oldD.contentKey)));
        expect(newD.baseNonce, isNot(equals(oldD.baseNonce)));
        expect(cap.putBytes[i], isNot(equals(src[i].cipher)));
        expect(
          () => AttachmentEncryptor.open(
            ciphertext: cap.putBytes[i],
            descriptor: oldD,
            bindingHash: _dstBinding(),
          ),
          throwsA(isA<AttachmentSealException>()),
        );
      }
    });

    test('元素字段改写：file_hash256 / size 替换，其余字段（宽高）保留', () {
      for (var i = 0; i < 3; i++) {
        expect(out[i]['file_hash256'], isNot('src-hash-$i'));
        expect(out[i]['size'], src[i].plain.length);
        expect(out[i]['width'], 10);
        expect(out[i]['height'], 20);
      }
    });

    test('confirm：anchor = 新消息 id、scope = 目标会话', () {
      for (final body in cap.confirmBodies) {
        expect(body['anchor_msg_id'], _newMsgId);
        expect(body['scope'], 'private');
        expect(body['scope_ref'], _targetConv);
      }
    });
  });

  group('2. 混合 / 失败语义', () {
    test('明文项原样保留，只有带 descriptor 的项重上传', () async {
      final cap = _UploadCapture();
      final sealedOne = _sealSrc(1);
      final plainItem = <String, dynamic>{
        'uri': 'u1001/plain/0.jpg',
        'width': 1,
        'height': 1,
      };
      final out = await _reSeal(_payload([plainItem, sealedOne.item]), {
        sealedOne.item['uri'] as String: sealedOne.cipher,
      }, cap);
      expect(cap.objectKeys, hasLength(1));
      expect(out[0], plainItem);
      expect(out[1]['uri'], cap.objectKeys.single);
    });

    test('嵌套 descriptor 非法 → attachment_forward_undecryptable，零上传', () async {
      final cap = _UploadCapture();
      await expectLater(
        _reSeal(
          _payload([
            {'uri': 'x', AttachmentSealPolicy.descriptorPayloadKey: 'bad'},
          ]),
          const {},
          cap,
        ),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_undecryptable',
          ),
        ),
      );
      expect(cap.objectKeys, isEmpty);
    });

    test('images 不是列表 → attachment_forward_undecryptable', () async {
      await expectLater(
        _reSeal({'images': 'nope'}, const {}, _UploadCapture()),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_undecryptable',
          ),
        ),
      );
    });

    test('原件下载失败 → attachment_forward_fetch_failed', () async {
      final s = _sealSrc(0);
      await expectLater(
        _reSeal(_payload([s.item]), const {}, _UploadCapture()),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_fetch_failed',
          ),
        ),
      );
    });

    test('源绑定失配（按错的源消息 id 解）→ attachment_forward_open_failed', () async {
      final s = _sealSrc(0);
      await expectLater(
        _reSeal(
          _payload([s.item]),
          {s.item['uri'] as String: s.cipher},
          _UploadCapture(),
          sourceMessageId: 'wrong-src-msg',
        ),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_open_failed',
          ),
        ),
      );
    });

    test('第二张失败时整条失败：第一张已上传但不会产出结果（无半转发）', () async {
      final cap = _UploadCapture();
      final ok = _sealSrc(0);
      final missing = _sealSrc(1);
      await expectLater(
        _reSeal(_payload([ok.item, missing.item]), {
          ok.item['uri'] as String: ok.cipher,
        }, cap),
        throwsA(isA<AttachmentForwardException>()),
      );
      expect(cap.objectKeys, hasLength(1));
    });
  });

  group('3. decide 与 applyForwardedImages', () {
    test('嵌套钥匙 + 目标明文域 → 拒绝（三域一致性延伸到多图）', () {
      final d = AttachmentForward.decide(
        sourceMetadata: _payload([_sealSrc(0).item]),
        targetPayloadWillBeEncrypted: false,
        sourceMessageId: _srcMsg,
        sourceChatType: 'C2C',
        sourceFromUid: _srcUid,
        sourceToUid: _srcPeer,
      );
      expect(d, isA<ForwardRejected>());
      expect(
        (d as ForwardRejected).reason,
        'attachment_forward_plaintext_target',
      );
    });

    test('嵌套钥匙 + 目标加密 → 重封装', () {
      final d = AttachmentForward.decide(
        sourceMetadata: _payload([_sealSrc(0).item]),
        targetPayloadWillBeEncrypted: true,
        sourceMessageId: _srcMsg,
        sourceChatType: 'C2C',
        sourceFromUid: _srcUid,
        sourceToUid: _srcPeer,
      );
      expect(d, isA<ForwardReSeal>());
    });

    test('明文多图 → 照旧原样转发', () {
      final d = AttachmentForward.decide(
        sourceMetadata: _payload([
          {'uri': 'a'},
        ]),
        targetPayloadWillBeEncrypted: false,
        sourceMessageId: _srcMsg,
        sourceChatType: 'C2C',
        sourceFromUid: _srcUid,
        sourceToUid: _srcPeer,
      );
      expect(d, isA<ForwardNotSealed>());
    });

    test('applyForwardedImages：整体替换 images 与 total，其余键保留', () {
      final base = {
        'text': '',
        'peer_id': 9,
        'images': [
          {'uri': 'old'},
        ],
        'total': 1,
      };
      final out = SendToNotifier.applyForwardedImages(base, [
        {'uri': 'n1'},
        {'uri': 'n2'},
      ]);
      expect(out['images'], [
        {'uri': 'n1'},
        {'uri': 'n2'},
      ]);
      expect(out['total'], 2);
      expect(out['peer_id'], 9);
      expect(base['total'], 1, reason: '纯函数：不改输入');
    });
  });
}
