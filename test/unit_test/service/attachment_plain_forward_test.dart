/// 明文附件转发重上传（PlainAttachmentForward）验收
///
/// 钉住的行为：转发明文附件时，源 `uri` 是**原会话 scope** 下的 object_key，
/// 读取授权按 scope 判成员资格（`attach_logic:authorize/3`）。原样复制会得到
/// 「消息正常显示、点开 403」。正确做法 = 下载原字节 → 按目标会话 scope 重上传
/// → 改写 uri/size/file_hash256。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/service/attachment_plain_forward.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/store/api/attachment_api.dart';

/// 捕获上传链三个 seam。
class _UploadCapture {
  _UploadCapture([this.label = 'dest']);

  final String label;
  final List<String> objectKeys = [];
  final List<Uint8List> putBytes = [];
  final List<String> fileNames = [];
  final List<Map<String, dynamic>> confirmBodies = [];
  Map<String, dynamic>? lastPresignExtra;

  PresignFn get presignFn => (filename, mime) async {
    fileNames.add(filename);
    final k = 'u-${label}/${objectKeys.length}/$filename';
    objectKeys.add(k);
    return IMBoyHttpResponse.success(<String, dynamic>{
      'put_url': 'https://example.invalid/put/${objectKeys.length}',
      'object_key': k,
    });
  };

  PutFn get putFn =>
      (url, bytes, mime, process) async => putBytes.add(bytes);

  ConfirmFn get confirmFn => (body) async {
    confirmBodies.add(body);
    return IMBoyHttpResponse.success(<String, dynamic>{});
  };
}

Uint8List _bytes(int n, [int seed = 3]) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 17 + seed) & 0xFF));

Future<Uint8List> Function(String) _fetcher(Uint8List data) =>
    (objectKey) async => data;

void main() {
  group('needsReupload 判定', () {
    test('纯文本 / 卡片无对象引用 → 不需要重上传', () {
      expect(PlainAttachmentForward.needsReupload({'text': 'hi'}), isFalse);
      expect(PlainAttachmentForward.needsReupload(null), isFalse);
      expect(PlainAttachmentForward.needsReupload('not-a-map'), isFalse);
    });

    test('uri 是 object_key → 需要重上传', () {
      expect(
        PlainAttachmentForward.needsReupload({
          'uri': 'u4/c2c/20261008/a/b.png',
        }),
        isTrue,
      );
    });

    test('绝对外链不算（换会话照样能打开，不该搬进自家桶）', () {
      expect(
        PlainAttachmentForward.needsReupload({
          'uri': 'https://example.com/a.png',
        }),
        isFalse,
      );
      expect(
        PlainAttachmentForward.needsReupload({
          'url': 'http://example.com/s.png',
        }),
        isFalse,
      );
    });

    test('thumb（字符串/嵌套 uri）与 images[] 都能识别', () {
      expect(
        PlainAttachmentForward.needsReupload({'thumb': 'u4/c2c/1/2/t.jpg'}),
        isTrue,
      );
      expect(
        PlainAttachmentForward.needsReupload({
          'thumb': {'uri': 'u4/c2c/1/2/t.jpg', 'width': 10},
        }),
        isTrue,
      );
      expect(
        PlainAttachmentForward.needsReupload({
          'images': [
            {'uri': 'u4/c2c/1/2/a.jpg'},
            {'uri': 'https://example.com/b.jpg'},
          ],
        }),
        isTrue,
      );
      expect(
        PlainAttachmentForward.needsReupload({
          'images': [
            {'uri': 'https://example.com/b.jpg'},
          ],
        }),
        isFalse,
      );
    });
  });

  group('reupload 单附件', () {
    test('下载原字节按目标 scope 重上传，并改写 uri/size/file_hash256', () async {
      final cap = _UploadCapture();
      final bytes = _bytes(64);
      final payload = {
        'uri': 'u4/c2c/1/2/pic.png',
        'name': 'pic.png',
        'size': 999, // 源值故意写错：必须以新对象实际字节数为准
        'file_hash256': 'old-hash',
        'msg_type': 'image',
      };

      final out = await PlainAttachmentForward.reupload(
        payload: payload,
        newMessageId: 'msg-fwd-1',
        targetScope: 'c2c',
        targetConversationId: 'c2c:7:9',
        fetchObject: _fetcher(bytes),
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );

      expect(cap.objectKeys, hasLength(1), reason: '单个 uri 只上传一次');
      expect(cap.putBytes.single, bytes, reason: '上传的必须是下载到的原字节');
      expect(out['uri'], cap.objectKeys.single);
      expect(out['size'], bytes.length);
      expect(out['file_hash256'], isNot('old-hash'));
      // 展示信息必须原样保留
      expect(out['name'], 'pic.png');
      expect(out['msg_type'], 'image');
      // 入参不被就地改写
      expect(payload['uri'], 'u4/c2c/1/2/pic.png');
    });

    test('文件名沿用原扩展名（服务端按扩展名 + 魔数双校验）', () async {
      final cap = _UploadCapture();
      await PlainAttachmentForward.reupload(
        payload: {'uri': 'u4/c2c/1/2/IMG_0001.HEIC'},
        newMessageId: 'm',
        targetScope: 'c2c',
        targetConversationId: 'c2c:7:9',
        fetchObject: _fetcher(_bytes(32)),
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
      expect(cap.fileNames.single.toLowerCase(), endsWith('.heic'));
    });

    test('外链 uri 原样保留，且一次网络都不发', () async {
      final cap = _UploadCapture();
      final out = await PlainAttachmentForward.reupload(
        payload: {'uri': 'https://example.com/a.png', 'text': 'x'},
        newMessageId: 'm',
        targetScope: 'c2c',
        targetConversationId: 'c2c:7:9',
        fetchObject: _fetcher(_bytes(8)),
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
      expect(out['uri'], 'https://example.com/a.png');
      expect(cap.objectKeys, isEmpty);
    });
  });

  group('reupload 多图 / 视频 / 位置', () {
    test('多图逐项重上传，顺序与张数不变，total 同步', () async {
      final cap = _UploadCapture();
      final out = await PlainAttachmentForward.reupload(
        payload: {
          'images': [
            {'uri': 'u4/c2c/1/2/a.jpg', 'width': 10},
            {'uri': 'u4/c2c/1/2/b.jpg', 'width': 20},
          ],
          'total': 9,
        },
        newMessageId: 'm',
        targetScope: 'group',
        targetConversationId: '50',
        fetchObject: _fetcher(_bytes(16)),
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
      final images = out[AttachmentSealPolicy.imagesPayloadKey] as List;
      expect(cap.objectKeys, hasLength(2));
      expect(images, hasLength(2));
      expect(images[0]['uri'], cap.objectKeys[0]);
      expect(images[1]['uri'], cap.objectKeys[1]);
      expect(images[0]['width'], 10, reason: '宽高等展示字段必须保留');
      expect(out['total'], 2, reason: 'total 必须与 images 实际张数一致');
    });

    test('视频：主体 + 缩略图（map）各自重上传，且不新增不认识的键', () async {
      final cap = _UploadCapture();
      final out = await PlainAttachmentForward.reupload(
        payload: {
          'uri': 'u4/c2c/1/2/v.mp4',
          'thumb': {'uri': 'u4/c2c/1/2/v.jpg', 'width': 120, 'height': 90},
        },
        newMessageId: 'm',
        targetScope: 'c2c',
        targetConversationId: 'c2c:7:9',
        fetchObject: _fetcher(_bytes(24)),
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
      final thumb = out['thumb'] as Map;
      expect(cap.objectKeys, hasLength(2), reason: '主体与缩略图是两个对象');
      expect(out['uri'], cap.objectKeys[0]);
      expect(thumb['uri'], cap.objectKeys[1]);
      expect(thumb['file_hash256'], isNotNull);
      expect(
        thumb.containsKey('size'),
        isFalse,
        reason: '原本没有 size 就不要凭空空造一个键',
      );
    });

    test('位置：thumb 是 object_key 字符串，整体替换', () async {
      final cap = _UploadCapture();
      final out = await PlainAttachmentForward.reupload(
        payload: {'thumb': 'u4/c2c/1/2/loc.jpg', 'lat': '31.2', 'lng': '121.4'},
        newMessageId: 'm',
        targetScope: 'c2c',
        targetConversationId: 'c2c:7:9',
        fetchObject: _fetcher(_bytes(12)),
        presignFn: cap.presignFn,
        putFn: cap.putFn,
        confirmFn: cap.confirmFn,
      );
      expect(out['thumb'], cap.objectKeys.single);
      expect(out['lat'], '31.2');
    });
  });

  group('失败路径：落库前显式失败', () {
    test('源对象下载失败 → attachment_forward_fetch_failed', () async {
      final cap = _UploadCapture();
      await expectLater(
        PlainAttachmentForward.reupload(
          payload: {'uri': 'u4/c2c/1/2/a.png'},
          newMessageId: 'm',
          targetScope: 'c2c',
          targetConversationId: 'c2c:7:9',
          fetchObject: (k) async => throw StateError('403'),
          presignFn: cap.presignFn,
          putFn: cap.putFn,
          confirmFn: cap.confirmFn,
        ),
        throwsA(
          isA<PlainAttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_fetch_failed',
          ),
        ),
      );
      expect(cap.objectKeys, isEmpty);
    });

    test('空字节视为下载失败（不拿空文件覆盖目标）', () async {
      await expectLater(
        PlainAttachmentForward.reupload(
          payload: {'uri': 'u4/c2c/1/2/a.png'},
          newMessageId: 'm',
          targetScope: 'c2c',
          targetConversationId: 'c2c:7:9',
          fetchObject: (k) async => Uint8List(0),
          presignFn: _UploadCapture().presignFn,
          putFn: _UploadCapture().putFn,
          confirmFn: _UploadCapture().confirmFn,
        ),
        throwsA(isA<PlainAttachmentForwardException>()),
      );
    });

    test('private scope 显式拒绝（读授权只给上传者，收件人永远打不开）', () async {
      await expectLater(
        PlainAttachmentForward.reupload(
          payload: {'uri': 'u4/c2c/1/2/a.png'},
          newMessageId: 'm',
          targetScope: 'private',
          targetConversationId: null,
          fetchObject: _fetcher(_bytes(8)),
          presignFn: _UploadCapture().presignFn,
          putFn: _UploadCapture().putFn,
          confirmFn: _UploadCapture().confirmFn,
        ),
        throwsA(
          isA<PlainAttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_private_scope',
          ),
        ),
      );
    });

    test('上传失败 → attachment_forward_upload_failed', () async {
      final cap = _UploadCapture();
      await expectLater(
        PlainAttachmentForward.reupload(
          payload: {'uri': 'u4/c2c/1/2/a.png'},
          newMessageId: 'm',
          targetScope: 'c2c',
          targetConversationId: 'c2c:7:9',
          fetchObject: _fetcher(_bytes(16)),
          presignFn: cap.presignFn,
          putFn: (url, b, m, p) async => throw StateError('put failed'),
          confirmFn: cap.confirmFn,
        ),
        throwsA(
          isA<PlainAttachmentForwardException>().having(
            (e) => e.reason,
            'reason',
            'attachment_forward_upload_failed',
          ),
        ),
      );
    });
  });
}
