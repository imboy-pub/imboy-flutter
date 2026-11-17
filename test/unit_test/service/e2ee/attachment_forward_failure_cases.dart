part of 'attachment_forward_test.dart';

void _registerAttachmentForwardFailures() {
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
}
