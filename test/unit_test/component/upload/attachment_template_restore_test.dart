/// restoreAttachmentGroupTemplate 契约测试
///
/// 生产路径下附件消息正是由它从「模板 + journal 行」重建后出网，故这里直接
/// 用构造的 [AttachmentUploadTask] 行驱动（不依赖 SQLite / 密钥库）：
/// - imageMulti：按每行 intent 的 object_index 排序逐行回填 images[]；
///   uri / size / file_hash256 / descriptor 以 journal 与材料加载器为准，
///   尺寸文件名来自 object_meta；材料缺失 fail-closed；
/// - 分组不完整（行数 / 未 confirmed）→ StateError；
/// - 既有单图 / 视频 / 位置路径逐字节保留（从 uploader 提取后的回归锚点）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/upload/attachment_template_restore.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart'
    show LostCipherMaterialError;
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';

const _uid = 'u1';
const _anchor = 'anchor-1';

Map<String, dynamic> _intent(
  String kind, {
  required int expected,
  Map<String, dynamic> metadata = const {'peer_id': 'p9'},
}) => {
  'message_id': _anchor,
  'author_id': _uid,
  'state': 'uploading',
  'attachment_kind': kind,
  'expected_objects': expected,
  'message_template': {'id': _anchor, 'authorId': _uid, 'metadata': metadata},
};

AttachmentUploadTask _row(
  String id, {
  int? index,
  String? cipher,
  String mime = 'image/jpeg',
  AttachmentUploadStage stage = AttachmentUploadStage.confirmed,
  String? objectKey,
  int createdAt = 0,
  Map<String, dynamic>? intentOverride,
}) {
  final intent =
      intentOverride ??
      {
        ..._intent('imageMulti', expected: 3),
        'object_index': ?index,
        if (index != null)
          'object_meta': {'name': 'p$index.jpg', 'width': 640, 'height': 480},
      };
  final n = index ?? 0;
  return AttachmentUploadTask(
    id: id,
    userId: _uid,
    scope: 'private',
    scopeRef: null,
    fileName: '$id.jpg',
    mime: mime,
    plainSize: 100 + n,
    plainSha256: 'plain-$id',
    objectKey: objectKey ?? 'u1/obj/$id',
    businessIntent: jsonEncode(intent),
    stage: stage,
    cipher: cipher,
    bindingHash: null,
    keyRef: null,
    ciphertextSha256: cipher == null ? null : 'cipher-$id',
    anchorMsgId: _anchor,
    lastError: null,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<Map<String, String>?> _noMaterials(AttachmentUploadTask _) async => null;

void main() {
  group('imageMulti', () {
    test('按 object_index 排序回填 images[]，字段来自 journal + object_meta', () async {
      final sessions = <String>[];
      final restored = await restoreAttachmentGroupTemplate(
        intent: _intent('imageMulti', expected: 3),
        rows: [
          _row('c', index: 2, createdAt: 1),
          _row('a', index: 0, createdAt: 3),
          _row('b', index: 1, createdAt: 2),
        ],
        userId: _uid,
        loadMaterials: _noMaterials,
        requireSession: sessions.add,
      );
      final metadata = restored['metadata'] as Map<String, dynamic>;
      final images = metadata['images'] as List;
      expect(images, hasLength(3));
      expect(metadata['total'], 3);
      expect(metadata['peer_id'], 'p9', reason: '模板既有 metadata 保留');
      expect(
        [for (final e in images) e['uri']],
        ['u1/obj/a', 'u1/obj/b', 'u1/obj/c'],
      );
      expect(images[1], {
        'name': 'p1.jpg',
        'width': 640,
        'height': 480,
        'uri': 'u1/obj/b',
        'size': 101,
        'file_hash256': 'plain-b',
      });
      expect(restored.containsKey('source'), isFalse, reason: '多图无顶层 source');
      expect(sessions, isEmpty, reason: '明文行不读材料，不触发会话复核');
    });

    test('密文行：descriptor 来自材料加载器，file_hash256 取密文哈希', () async {
      final sessions = <String>[];
      final restored = await restoreAttachmentGroupTemplate(
        intent: _intent('imageMulti', expected: 2),
        rows: [
          _row('a', index: 0, cipher: 'AES-256-GCM'),
          _row('b', index: 1, cipher: 'AES-256-GCM'),
        ],
        userId: _uid,
        loadMaterials: (t) async => {
          'descriptor': jsonEncode({'attachment_id': 'image_${t.id}'}),
        },
        requireSession: sessions.add,
      );
      final images = (restored['metadata'] as Map)['images'] as List;
      expect(images[0]['attachment_descriptor'], {'attachment_id': 'image_a'});
      expect(images[1]['attachment_descriptor'], {'attachment_id': 'image_b'});
      expect(images[0]['file_hash256'], 'cipher-a');
      expect(sessions, [_uid, _uid], reason: '每次读材料后复核会话');
    });

    test('密文行材料缺失 → LostCipherMaterialError（fail-closed）', () async {
      await expectLater(
        restoreAttachmentGroupTemplate(
          intent: _intent('imageMulti', expected: 1),
          rows: [_row('a', index: 0, cipher: 'AES-256-GCM')],
          userId: _uid,
          loadMaterials: _noMaterials,
          requireSession: (_) {},
        ),
        throwsA(isA<LostCipherMaterialError>()),
      );
    });

    test('object_index 缺失 → 退回 createdAt 顺序', () async {
      final bare = {..._intent('imageMulti', expected: 2)};
      final restored = await restoreAttachmentGroupTemplate(
        intent: _intent('imageMulti', expected: 2),
        rows: [
          _row('late', createdAt: 20, intentOverride: bare),
          _row('early', createdAt: 10, intentOverride: bare),
        ],
        userId: _uid,
        loadMaterials: _noMaterials,
        requireSession: (_) {},
      );
      final images = (restored['metadata'] as Map)['images'] as List;
      expect(
        [for (final e in images) e['uri']],
        ['u1/obj/early', 'u1/obj/late'],
      );
    });

    test('行数不足 / 任一行未 confirmed → StateError（分组不完整）', () async {
      await expectLater(
        restoreAttachmentGroupTemplate(
          intent: _intent('imageMulti', expected: 3),
          rows: [_row('a', index: 0), _row('b', index: 1)],
          userId: _uid,
          loadMaterials: _noMaterials,
          requireSession: (_) {},
        ),
        throwsStateError,
      );
      await expectLater(
        restoreAttachmentGroupTemplate(
          intent: _intent('imageMulti', expected: 2),
          rows: [
            _row('a', index: 0),
            _row('b', index: 1, stage: AttachmentUploadStage.putDone),
          ],
          userId: _uid,
          loadMaterials: _noMaterials,
          requireSession: (_) {},
        ),
        throwsStateError,
      );
    });

    test('confirmed 行缺 objectKey → StateError', () async {
      await expectLater(
        restoreAttachmentGroupTemplate(
          intent: _intent('imageMulti', expected: 1),
          rows: [_row('a', index: 0, objectKey: '')],
          userId: _uid,
          loadMaterials: _noMaterials,
          requireSession: (_) {},
        ),
        throwsStateError,
      );
    });
  });

  group('既有单附件路径回归（从 uploader 提取后逐字节保留）', () {
    test(
      'image：source/size 进模板顶层，file_hash256 与 descriptor 进 metadata',
      () async {
        final restored = await restoreAttachmentGroupTemplate(
          intent: _intent('image', expected: 1),
          rows: [
            _row(
              'a',
              cipher: 'AES-256-GCM',
              intentOverride: _intent('image', expected: 1),
            ),
          ],
          userId: _uid,
          loadMaterials: (_) async => {
            'descriptor': jsonEncode({'attachment_id': 'image'}),
          },
          requireSession: (_) {},
        );
        expect(restored['source'], 'u1/obj/a');
        expect(restored['size'], 100);
        final metadata = restored['metadata'] as Map;
        expect(metadata['file_hash256'], 'cipher-a');
        expect(metadata['attachment_descriptor'], {'attachment_id': 'image'});
      },
    );

    test('video：主体为 video/* 行，缩略图回填 metadata.thumb', () async {
      final intent = _intent('video', expected: 2);
      final restored = await restoreAttachmentGroupTemplate(
        intent: intent,
        rows: [
          _row('thumb', mime: 'image/jpeg', intentOverride: intent),
          _row('main', mime: 'video/mp4', intentOverride: intent),
        ],
        userId: _uid,
        loadMaterials: _noMaterials,
        requireSession: (_) {},
      );
      expect(restored['source'], 'u1/obj/main');
      expect((restored['metadata'] as Map)['thumb'], {'uri': 'u1/obj/thumb'});
    });

    test('location：缩略图 object_key 与 size 进 metadata，不设顶层 source', () async {
      final intent = _intent('location', expected: 1);
      final restored = await restoreAttachmentGroupTemplate(
        intent: intent,
        rows: [_row('snap', intentOverride: intent)],
        userId: _uid,
        loadMaterials: _noMaterials,
        requireSession: (_) {},
      );
      final metadata = restored['metadata'] as Map;
      expect(metadata['thumb'], 'u1/obj/snap');
      expect(metadata['size'], 100);
      expect(restored.containsKey('source'), isFalse);
    });
  });
}
