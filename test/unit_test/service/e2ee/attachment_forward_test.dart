/// FWDFIX —— 加密附件转发重封装（AttachmentForward）验收
///
/// 对应 run-20261003-094804 C07 根因结论 / C04 记录的功能缺口：
/// 转发的加密附件在目标会话打不开（binding 失配 fail-closed）。
/// 修复 = 本地认证解密 → 目标会话三元组重封装（新独立 key/nonce）→
/// 重上传（anchor=新消息 id、scope=目标会话）。
///
/// 覆盖：
/// 1. decide 纯判定矩阵（明文源照旧 / 明文目标域拒绝 / 源不可解密拒绝）；
/// 2. C2C↔C2G 跨域转发全链：接收方可打开、内容与原件一致、
///    key/nonce 与原件互异、confirm 键白名单与锚点；
/// 3. 视频双对象（thumb 同生同灭重封装）；
/// 4. 失败路径（下载/解密/上传），无半转发状态；
/// 5. 明文目标域三域一致性（与既有双闸门同语义）；
/// 6. 幂等（重试 = 全新密钥，绝不复用）；
/// 7. payload 覆盖纯函数（applyForwardedAttachment）。
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_forward.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/e2ee/retry_plaintext_guard.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';

Uint8List _plain(int n, [int seed = 7]) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + seed) & 0xFF));

Uint8List _srcBinding() => AttachmentBinding.compute(
  messageId: 'msg-src',
  conversationId: 'c2c:1001:2002',
  senderUid: '1001',
);

Uint8List _srcBindingG() => AttachmentBinding.compute(
  messageId: 'msg-src-g',
  conversationId: 'g-9',
  senderUid: '1001',
);

/// 生成一份「源附件」：发送侧 seal + 上传，拿到 descriptor 与密文。
({AttachmentDescriptor descriptor, Uint8List ciphertext, Uint8List plaintext})
_sealSource({
  required Uint8List bindingHash,
  required String attachmentId,
  required String objectKey,
  Uint8List? plaintext,
  AttachmentDescriptor? thumb,
  int chunkSize = 64,
}) {
  final pt = plaintext ?? _plain(200);
  final sealed = AttachmentEncryptor.seal(
    plaintext: pt,
    bindingHash: bindingHash,
    attachmentId: attachmentId,
    objectKey: objectKey,
    mime: 'image/jpeg',
    name: 'pic.jpg',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: chunkSize,
    thumb: thumb,
  );
  return (
    descriptor: sealed.descriptor,
    ciphertext: sealed.ciphertext,
    plaintext: pt,
  );
}

/// 捕获上传链三个 seam（多次调用按序记录）。
///
/// [label] 用于区分不同 capture 实例产出的 object_key——真实服务端每次
/// presign 都签发全新 key，fake 若按实例各自从 0 计数会在跨实例断言时撞名。
class _UploadCapture {
  _UploadCapture([this.label = 'x']);

  final String label;
  final List<String> objectKeys = [];
  final List<Uint8List> putBytes = [];
  final List<Map<String, dynamic>> confirmBodies = [];

  PresignFn get presignFn => (f, m) async {
    final k = 'u-dest/$label/${objectKeys.length}/$f';
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

/// 默认目标语境：转发者 3003 → C2C 目标会话 c2c:3003:4004。
const _fwdUid = '3003';
const _newMsgId = 'msg-fwd-1';
const _targetC2C = 'c2c:3003:4004';
const _targetG = 'g-77';

Uint8List _dstBinding(String conv) => AttachmentBinding.compute(
  messageId: _newMsgId,
  conversationId: conv,
  senderUid: _fwdUid,
);

void main() {
  group('1. decide 纯判定矩阵', () {
    test('源不带 content key（纯文本/明文附件）→ 照旧原样转发', () {
      final d = AttachmentForward.decide(
        sourceMetadata: {'msg_type': 'text', 'text': 'hi'},
        targetPayloadWillBeEncrypted: false,
        sourceMessageId: 'msg-src',
        sourceChatType: 'C2C',
        sourceFromUid: '1001',
        sourceToUid: '2002',
      );
      expect(d, isA<ForwardNotSealed>());
    });

    test('带 key + 目标加密 + 源三元组完整 → 重封装', () {
      final src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'image',
        objectKey: 'u-src/1/pic.jpg',
      );
      final d = AttachmentForward.decide(
        sourceMetadata: {
          AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
        },
        targetPayloadWillBeEncrypted: true,
        sourceMessageId: 'msg-src',
        sourceChatType: 'C2C',
        sourceFromUid: '1001',
        sourceToUid: '2002',
      );
      expect(d, isA<ForwardReSeal>());
    });

    test('带 key + 目标 payload 不加密（AI 域已确认豁免 / 全局 plaintext）→ 拒绝', () {
      final src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'image',
        objectKey: 'u-src/1/pic.jpg',
      );
      final d = AttachmentForward.decide(
        sourceMetadata: {
          AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
        },
        targetPayloadWillBeEncrypted: false,
        sourceMessageId: 'msg-src',
        sourceChatType: 'C2C',
        sourceFromUid: '1001',
        sourceToUid: '2002',
      );
      expect(d, isA<ForwardRejected>());
      expect(
        (d as ForwardRejected).reason,
        'attachment_forward_plaintext_target',
      );
    });

    test('带 key + 源绑定输入推不出（uk3 前缀非标）→ fail-closed 拒绝', () {
      expect(AttachmentForward.chatTypeFromConversationUk3('C2C_1_2'), 'C2C');
      expect(AttachmentForward.chatTypeFromConversationUk3('c2g:50:9'), 'C2G');
      expect(AttachmentForward.chatTypeFromConversationUk3('weird/uk3'), '');
      expect(AttachmentForward.chatTypeFromConversationUk3(null), '');

      final src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'image',
        objectKey: 'u-src/1/pic.jpg',
      );
      for (final entry in [
        ('', 'C2C', '1001', '2002'), // messageId 空
        ('msg-src', '', '1001', '2002'), // chatType 空
        ('msg-src', 'C2C', '', '2002'), // fromUid 空
        ('msg-src', 'C2C', '1001', ''), // toUid 空
      ]) {
        final d = AttachmentForward.decide(
          sourceMetadata: {
            AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
          },
          targetPayloadWillBeEncrypted: true,
          sourceMessageId: entry.$1,
          sourceChatType: entry.$2,
          sourceFromUid: entry.$3,
          sourceToUid: entry.$4,
        );
        expect(d, isA<ForwardRejected>(), reason: '输入 ${entry.toString()}');
        expect(
          (d as ForwardRejected).reason,
          'attachment_forward_undecryptable',
          reason: '缺绑定输入 = 本机解不开 = 不静默复制旧 descriptor',
        );
      }
    });
  });

  group('2. C2C→C2C 加密会话转发全链', () {
    late ({
      AttachmentDescriptor descriptor,
      Uint8List ciphertext,
      Uint8List plaintext,
    })
    src;
    late _UploadCapture cap;
    late ForwardedAttachment out;

    setUpAll(() async {
      src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'image',
        objectKey: 'u-src/1/pic.jpg',
      );
      cap = _UploadCapture();
      out = await AttachmentForward.reSeal(
        sourcePayload: {
          'uri': 'u-src/1/pic.jpg',
          'file_hash256': 'src-hash',
          'size': src.plaintext.length,
          AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
        },
        sourceMessageId: 'msg-src',
        sourceChatType: 'C2C',
        sourceFromUid: '1001',
        sourceToUid: '2002',
        newMessageId: _newMsgId,
        targetScope: 'c2c',
        targetConversationId: _targetC2C,
        forwarderUid: _fwdUid,
        fetchCiphertext: (objectKey) async => src.ciphertext,
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
    });

    test('接收方（目标会话）可打开，内容与原件逐字节一致', () {
      final opened = AttachmentOpener.openForMessage(
        payload: {
          AttachmentSealPolicy.descriptorPayloadKey: out.descriptor.toMap(),
        },
        objectBytes: cap.putBytes.single,
        messageId: _newMsgId,
        chatType: 'C2C',
        fromUid: _fwdUid,
        toUid: '4004',
      );
      expect(opened, equals(src.plaintext));
    });

    test('新 key / 新 nonce 与原件互异；密文与原件互异（绝不复用）', () {
      expect(
        out.descriptor.contentKey,
        isNot(equals(src.descriptor.contentKey)),
      );
      expect(out.descriptor.baseNonce, isNot(equals(src.descriptor.baseNonce)));
      expect(cap.putBytes.single, isNot(equals(src.ciphertext)));
    });

    test('新消息 id 下按旧 descriptor 打不开（ATT-01 回归锚点仍在）', () {
      expect(
        () => AttachmentEncryptor.open(
          ciphertext: src.ciphertext,
          descriptor: src.descriptor,
          bindingHash: _dstBinding(_targetC2C),
        ),
        throwsA(isA<AttachmentSealException>()),
        reason: '重封装不是「换个绑定重算」——旧密文与新绑定本就必须失配',
      );
    });

    test('confirm 键白名单 + anchor=新消息 id + scope=目标会话', () {
      final body = cap.confirmBodies.single;
      expect(body.keys.toSet(), {
        'object_key',
        'file_hash256',
        'mime_type',
        'size',
        'cipher',
        'scope',
        'scope_ref',
        'anchor_msg_id',
      }, reason: '无 content_key / base_nonce / plain_sha256（C04 白名单不变）');
      expect(body['anchor_msg_id'], _newMsgId);
      expect(body['scope'], 'c2c');
      expect(body['scope_ref'], _targetC2C);
      expect(body['cipher'], AttachmentDescriptor.supportedCipher);
    });

    test('fileHash256 == 新密文哈希（与服务端 confirm 同值）', () {
      expect(
        out.fileHash256,
        equals(sha256.convert(cap.putBytes.single).toString()),
      );
      expect(out.plainSize, src.plaintext.length);
      expect(out.objectKey, cap.objectKeys.single);
    });

    test('原件在源会话仍可打开（重封装不破坏原件）', () {
      expect(
        AttachmentEncryptor.open(
          ciphertext: src.ciphertext,
          descriptor: src.descriptor,
          bindingHash: _srcBinding(),
        ),
        equals(src.plaintext),
      );
    });
  });

  group('3. 跨域转发（C2G↔C2C）', () {
    test('C2C 源 → C2G 目标：群成员按群会话语境可打开', () async {
      final src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'file',
        objectKey: 'u-src/2/a.bin',
      );
      final cap = _UploadCapture();
      final out = await AttachmentForward.reSeal(
        sourcePayload: {
          AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
        },
        sourceMessageId: 'msg-src',
        sourceChatType: 'C2C',
        sourceFromUid: '1001',
        sourceToUid: '2002',
        newMessageId: _newMsgId,
        targetScope: 'group',
        targetConversationId: _targetG,
        forwarderUid: _fwdUid,
        fetchCiphertext: (_) async => src.ciphertext,
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
      // 接收侧：C2G 消息 fromUid=转发者、toUid=gid
      final opened = AttachmentOpener.openForMessage(
        payload: {
          AttachmentSealPolicy.descriptorPayloadKey: out.descriptor.toMap(),
        },
        objectBytes: cap.putBytes.single,
        messageId: _newMsgId,
        chatType: 'C2G',
        fromUid: _fwdUid,
        toUid: _targetG,
      );
      expect(opened, equals(src.plaintext));
      expect(cap.confirmBodies.single['scope'], 'group');
      expect(cap.confirmBodies.single['scope_ref'], _targetG);
    });

    test('C2G 源 → C2C 目标：转发者以群成员身份解出原件，单聊语境重封装', () async {
      final src = _sealSource(
        bindingHash: _srcBindingG(),
        attachmentId: 'video',
        objectKey: 'u-src/3/v.mp4',
      );
      final cap = _UploadCapture();
      final out = await AttachmentForward.reSeal(
        sourcePayload: {
          AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
        },
        sourceMessageId: 'msg-src-g',
        sourceChatType: 'C2G',
        sourceFromUid: '1001', // 原发送者（群内他人）
        sourceToUid: 'g-9',
        newMessageId: _newMsgId,
        targetScope: 'c2c',
        targetConversationId: _targetC2C,
        forwarderUid: _fwdUid, // 转发者=原群会话接收者之一
        fetchCiphertext: (_) async => src.ciphertext,
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
      final opened = AttachmentOpener.openForMessage(
        payload: {
          AttachmentSealPolicy.descriptorPayloadKey: out.descriptor.toMap(),
        },
        objectBytes: cap.putBytes.single,
        messageId: _newMsgId,
        chatType: 'C2C',
        fromUid: _fwdUid,
        toUid: '4004',
      );
      expect(opened, equals(src.plaintext));
    });
  });

  group('4. 视频双对象：thumb 与主体同生同灭重封装', () {
    late ({
      AttachmentDescriptor descriptor,
      Uint8List ciphertext,
      Uint8List plaintext,
    })
    srcThumb;
    late ({
      AttachmentDescriptor descriptor,
      Uint8List ciphertext,
      Uint8List plaintext,
    })
    srcMain;
    late Map<String, Uint8List> store;
    late _UploadCapture cap;
    late ForwardedAttachment out;

    setUpAll(() async {
      final b = _srcBinding();
      srcThumb = _sealSource(
        bindingHash: b,
        attachmentId: 'video_thumb',
        objectKey: 'u-src/4/thumb.jpg',
        plaintext: _plain(48, 11),
      );
      srcMain = _sealSource(
        bindingHash: b,
        attachmentId: 'video',
        objectKey: 'u-src/4/v.mp4',
        thumb: srcThumb.descriptor,
      );
      store = {
        srcThumb.descriptor.objectKey: srcThumb.ciphertext,
        srcMain.descriptor.objectKey: srcMain.ciphertext,
      };
      cap = _UploadCapture();
      out = await AttachmentForward.reSeal(
        sourcePayload: {
          'uri': 'u-src/4/v.mp4',
          'thumb': {
            'file_hash256': 'old-thumb-hash',
            'name': 'thumb.jpg',
            'uri': 'u-src/4/thumb.jpg',
          },
          AttachmentSealPolicy.descriptorPayloadKey: srcMain.descriptor.toMap(),
        },
        sourceMessageId: 'msg-src',
        sourceChatType: 'C2C',
        sourceFromUid: '1001',
        sourceToUid: '2002',
        newMessageId: _newMsgId,
        targetScope: 'c2c',
        targetConversationId: _targetC2C,
        forwarderUid: _fwdUid,
        fetchCiphertext: (k) async => store[k]!,
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
    });

    test('两次上传：先 thumb 后主体（Slice 7 顺序）', () {
      expect(cap.objectKeys.length, 2);
      expect(cap.confirmBodies.length, 2);
      // putBytes[0]=thumb（48B 明文 → 48+16 密文），putBytes[1]=主体
      expect(
        cap.putBytes[0].length,
        srcThumb.plaintext.length + 16,
        reason: '第一笔是 thumb 密文（明文 48B + 单块 tag 16B）',
      );
    });

    test('新主 descriptor.thumb == 新 thumb descriptor；四元 key/nonce 互异', () {
      final newThumb = out.descriptor.thumb!;
      expect(newThumb, isNotNull);
      expect(out.thumbObjectKey, isNotNull);
      // 与源互异
      expect(
        newThumb.contentKey,
        isNot(equals(srcThumb.descriptor.contentKey)),
      );
      expect(newThumb.baseNonce, isNot(equals(srcThumb.descriptor.baseNonce)));
      expect(
        out.descriptor.contentKey,
        isNot(equals(srcMain.descriptor.contentKey)),
      );
      // thumb 与主体互异（构造层强制 + 实证）
      expect(newThumb.contentKey, isNot(equals(out.descriptor.contentKey)));
      expect(newThumb.baseNonce, isNot(equals(out.descriptor.baseNonce)));
    });

    test('接收方可打开主体与缩略图，内容与原件一致', () {
      final dstBinding = _dstBinding(_targetC2C);
      final mainOpened = AttachmentEncryptor.open(
        ciphertext: cap.putBytes[1],
        descriptor: out.descriptor,
        bindingHash: dstBinding,
      );
      expect(mainOpened, equals(srcMain.plaintext));
      final thumbOpened = AttachmentEncryptor.open(
        ciphertext: cap.putBytes[0],
        descriptor: out.descriptor.thumb!,
        bindingHash: dstBinding,
      );
      expect(thumbOpened, equals(srcThumb.plaintext));
    });

    test('两次 confirm 都带 anchor=新消息 id 与 cipher 判别位', () {
      for (final body in cap.confirmBodies) {
        expect(body['anchor_msg_id'], _newMsgId);
        expect(body['cipher'], AttachmentDescriptor.supportedCipher);
      }
    });
  });

  group('5. 失败路径（无半转发状态）', () {
    late ({
      AttachmentDescriptor descriptor,
      Uint8List ciphertext,
      Uint8List plaintext,
    })
    src;

    setUp(() {
      src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'image',
        objectKey: 'u-src/5/pic.jpg',
      );
    });

    Map<String, dynamic> payload() => {
      AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
    };

    test('原件下载失败 → fetch_failed，抛出即无消息落库素材', () async {
      await expectLater(
        AttachmentForward.reSeal(
          sourcePayload: payload(),
          sourceMessageId: 'msg-src',
          sourceChatType: 'C2C',
          sourceFromUid: '1001',
          sourceToUid: '2002',
          newMessageId: _newMsgId,
          targetScope: 'c2c',
          targetConversationId: _targetC2C,
          forwarderUid: _fwdUid,
          fetchCiphertext: (_) async => throw Exception('network down'),
        ),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_fetch_failed',
          ),
        ),
      );
    });

    test('原件认证解密失败（密文被腐蚀 / 缺钥）→ open_failed', () async {
      final corrupted = Uint8List.fromList(src.ciphertext);
      corrupted[corrupted.length - 1] ^= 0x01;
      await expectLater(
        AttachmentForward.reSeal(
          sourcePayload: payload(),
          sourceMessageId: 'msg-src',
          sourceChatType: 'C2C',
          sourceFromUid: '1001',
          sourceToUid: '2002',
          newMessageId: _newMsgId,
          targetScope: 'c2c',
          targetConversationId: _targetC2C,
          forwarderUid: _fwdUid,
          fetchCiphertext: (_) async => corrupted,
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

    test('源绑定推不出（C2S 等非标源）→ undecryptable', () async {
      await expectLater(
        AttachmentForward.reSeal(
          sourcePayload: payload(),
          sourceMessageId: 'msg-src',
          sourceChatType: 'C2S',
          sourceFromUid: '1001',
          sourceToUid: '2002',
          newMessageId: _newMsgId,
          targetScope: 'private',
          targetConversationId: '',
          forwarderUid: _fwdUid,
          fetchCiphertext: (_) async => src.ciphertext,
        ),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_undecryptable',
          ),
        ),
      );
    });

    test('目标会话推不出 scope_ref（矛盾态防御）→ undecryptable 而非裸异常穿透', () async {
      await expectLater(
        AttachmentForward.reSeal(
          sourcePayload: payload(),
          sourceMessageId: 'msg-src',
          sourceChatType: 'C2C', // 源绑定可算
          sourceFromUid: '1001',
          sourceToUid: '2002',
          newMessageId: _newMsgId,
          targetScope: 'private',
          targetConversationId: '', // 目标绑定算不出
          forwarderUid: _fwdUid,
          fetchCiphertext: (_) async => src.ciphertext,
        ),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_undecryptable',
          ),
        ),
      );
    });

    test('重上传失败（confirm 拒绝）→ upload_failed，不再产出消息引用', () async {
      final cap = _UploadCapture();
      await expectLater(
        AttachmentForward.reSeal(
          sourcePayload: payload(),
          sourceMessageId: 'msg-src',
          sourceChatType: 'C2C',
          sourceFromUid: '1001',
          sourceToUid: '2002',
          newMessageId: _newMsgId,
          targetScope: 'c2c',
          targetConversationId: _targetC2C,
          forwarderUid: _fwdUid,
          fetchCiphertext: (_) async => src.ciphertext,
          presignFn: cap.presignFn,
          putFn: cap.putFn,
          confirmFn: (_) async =>
              IMBoyHttpResponse.failure(errMsg: 'boom', errCode: 500),
        ),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_upload_failed',
          ),
        ),
      );
    });

    test('thumb 下载失败同样整体失败（半封装状态不可接受）', () async {
      final b = _srcBinding();
      final srcThumb = _sealSource(
        bindingHash: b,
        attachmentId: 'video_thumb',
        objectKey: 'u-src/6/thumb.jpg',
        plaintext: _plain(48, 13),
      );
      final srcMain = _sealSource(
        bindingHash: b,
        attachmentId: 'video',
        objectKey: 'u-src/6/v.mp4',
        thumb: srcThumb.descriptor,
      );
      final cap = _UploadCapture();
      await expectLater(
        AttachmentForward.reSeal(
          sourcePayload: {
            AttachmentSealPolicy.descriptorPayloadKey: srcMain.descriptor
                .toMap(),
          },
          sourceMessageId: 'msg-src',
          sourceChatType: 'C2C',
          sourceFromUid: '1001',
          sourceToUid: '2002',
          newMessageId: _newMsgId,
          targetScope: 'c2c',
          targetConversationId: _targetC2C,
          forwarderUid: _fwdUid,
          // 主体密文在、thumb 密文拿不到
          fetchCiphertext: (k) async => k == srcMain.descriptor.objectKey
              ? srcMain.ciphertext
              : throw Exception('404'),
          presignFn: cap.presignFn,
          putFn: cap.putFn,
          confirmFn: cap.confirmFn,
        ),
        throwsA(
          isA<AttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_fetch_failed',
          ),
        ),
      );
    });
  });

  group('6. 明文目标域：三域一致性（拒绝 + 既有双闸门原样保留）', () {
    test('decide 拒绝明文目标域（转发动作处显式失败，不落库）', () {
      final src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'image',
        objectKey: 'u-src/7/pic.jpg',
      );
      final d = AttachmentForward.decide(
        sourceMetadata: {
          AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
        },
        targetPayloadWillBeEncrypted: false,
        sourceMessageId: 'msg-src',
        sourceChatType: 'C2C',
        sourceFromUid: '1001',
        sourceToUid: '2002',
      ) as ForwardRejected;
      expect(d.reason, 'attachment_forward_plaintext_target');
    });

    test('纵深防御：若旧客户端仍把 descriptor 复制进明文 payload，双闸门仍拦（C04/C06 语义不变）', () {
      final legacyCopied = <String, dynamic>{
        AttachmentSealPolicy.descriptorPayloadKey: {'v': 'as-if-copied'},
        'text': '',
      };
      expect(AttachmentSealPolicy.carriesContentKey(legacyCopied), isTrue);
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: false,
          e2ee: null,
          carriesContentKey: true,
        ),
        isTrue,
        reason: '重发闸门与出网闸门语义原样保留，优先级高于域策略',
      );
    });

    test('无 descriptor 的源转发到明文域：不拦（明文附件照旧）', () {
      final plainAttachment = <String, dynamic>{
        'uri': 'objkey/legacy/file.jpg',
        'text': '',
      };
      expect(AttachmentSealPolicy.carriesContentKey(plainAttachment), isFalse);
    });
  });

  group('7. 幂等：重试 = 全新密钥，绝不复用', () {
    test('同一源两次重封装（不同新消息 id）：key/nonce/object 两两互异且各自可打开', () async {
      final src = _sealSource(
        bindingHash: _srcBinding(),
        attachmentId: 'image',
        objectKey: 'u-src/8/pic.jpg',
      );
      Future<ForwardedAttachment> run(String msgId, _UploadCapture cap) =>
          AttachmentForward.reSeal(
            sourcePayload: {
              AttachmentSealPolicy.descriptorPayloadKey: src.descriptor.toMap(),
            },
            sourceMessageId: 'msg-src',
            sourceChatType: 'C2C',
            sourceFromUid: '1001',
            sourceToUid: '2002',
            newMessageId: msgId,
            targetScope: 'c2c',
            targetConversationId: _targetC2C,
            forwarderUid: _fwdUid,
            fetchCiphertext: (_) async => src.ciphertext,
            presignFn: cap.presignFn,
            putFn: cap.putFn,
            confirmFn: cap.confirmFn,
          );

      final capA = _UploadCapture('a');
      final capB = _UploadCapture('b');
      final a = await run('msg-fwd-A', capA);
      final b = await run('msg-fwd-B', capB);

      expect(a.descriptor.contentKey, isNot(equals(b.descriptor.contentKey)));
      expect(a.descriptor.baseNonce, isNot(equals(b.descriptor.baseNonce)));
      expect(a.objectKey, isNot(equals(b.objectKey)));

      // 各自在自己的新消息 id 下可打开（解耦：绑定输入不同）
      for (final e in [(a, capA, 'msg-fwd-A'), (b, capB, 'msg-fwd-B')]) {
        final binding = AttachmentBinding.compute(
          messageId: e.$3,
          conversationId: _targetC2C,
          senderUid: _fwdUid,
        );
        expect(
          AttachmentEncryptor.open(
            ciphertext: e.$2.putBytes.single,
            descriptor: e.$1.descriptor,
            bindingHash: binding,
          ),
          equals(src.plaintext),
        );
      }
    });
  });

  group('8. applyForwardedAttachment：payload 覆盖纯函数', () {
    final fakeDescriptor = AttachmentDescriptor(
      attachmentId: 'image',
      objectKey: 'new-key/pic.jpg',
      contentKey: Uint8List.fromList(List.filled(32, 1)),
      cipher: AttachmentDescriptor.supportedCipher,
      chunkSize: 64,
      chunkCount: 1,
      baseNonce: Uint8List.fromList(List.filled(12, 2)),
      plainSize: 10,
      plainSha256: Uint8List.fromList(List.filled(32, 3)),
      mime: 'image/jpeg',
      name: 'pic.jpg',
    );
    final fwd = ForwardedAttachment(
      descriptor: fakeDescriptor,
      objectKey: 'new-key/pic.jpg',
      fileHash256: 'new-cipher-hash',
      plainSize: 10,
    );

    test('uri / descriptor / file_hash256 / size 全部替换为目标会话新值', () {
      final out = SendToNotifier.applyForwardedAttachment({
        'uri': 'old-key/pic.jpg',
        'file_hash256': 'old-hash',
        'size': 999,
        'peer_id': 4004,
      }, fwd);
      expect(out['uri'], 'new-key/pic.jpg');
      expect(out['file_hash256'], 'new-cipher-hash');
      expect(out['size'], 10);
      expect(
        out[AttachmentSealPolicy.descriptorPayloadKey],
        equals(fakeDescriptor.toMap()),
      );
      expect(out['peer_id'], 4004, reason: '非附件字段原样保留');
    });

    test('thumb 为 map（视频 EntityImage）→ uri/file_hash256 更新', () {
      final out = SendToNotifier.applyForwardedAttachment(
        {
          'thumb': {
            'file_hash256': 'old-thumb-hash',
            'name': 'thumb.jpg',
            'uri': 'old-key/thumb.jpg',
          },
        },
        ForwardedAttachment(
          descriptor: fakeDescriptor,
          objectKey: 'new-key/v.mp4',
          fileHash256: 'new-hash',
          plainSize: 10,
          thumbObjectKey: 'new-key/thumb.jpg',
          thumbFileHash256: 'new-thumb-hash',
        ),
      );
      final thumb = out['thumb'] as Map<String, dynamic>;
      expect(thumb['uri'], 'new-key/thumb.jpg');
      expect(thumb['file_hash256'], 'new-thumb-hash');
      expect(thumb['name'], 'thumb.jpg', reason: '其余字段保留');
    });

    test('thumb 为字符串（位置消息）→ 整体替换为新 object_key', () {
      final out = SendToNotifier.applyForwardedAttachment(
        {'thumb': 'old-key/loc.jpg'},
        ForwardedAttachment(
          descriptor: fakeDescriptor,
          objectKey: 'new-key/loc-main',
          fileHash256: 'h',
          plainSize: 1,
          thumbObjectKey: 'new-key/loc.jpg',
          thumbFileHash256: 'th',
        ),
      );
      expect(out['thumb'], 'new-key/loc.jpg');
    });
  });
}
