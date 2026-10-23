/// 从上传日志（attachment upload journal）恢复附件消息模板
///
/// 从 `ResumableAttachmentUploader.restoreMessageTemplate` 提取的纯编排：
/// 输入 = 同一 anchor 的全部 journal 行 + 每行的加密材料加载器，输出 = 可直接
/// `Message.fromJson` 的模板 JSON。生产路径下**消息正是由这里重建后出网**
/// （业务出站箱），内存里先构造的 Message 只是无 journal 时的兜底。
///
/// 单文件 / 图片 / 语音 / 视频 / 位置的既有逻辑逐字节保留；新增 imageMulti
/// 分支：多图 = N 行同 anchor，按每行 intent 的 `object_index` 排序后逐行
/// 回填 `metadata.images[]`（uri / size / file_hash256 / 尺寸 / descriptor）。
library;

import 'dart:convert';

import 'package:imboy/component/upload/resumable_attachment_uploader.dart'
    show LostCipherMaterialError;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';

/// journal 行 → 加密材料（含 `descriptor` JSON 串）；明文行返回 null。
typedef UploadMaterialsLoader = Future<Map<String, String>?> Function(
  AttachmentUploadTask task,
);

/// 恢复同一 anchor 分组的消息模板。
///
/// [requireSession] 在每次异步读取密钥材料后复核会话未切换（与上传器内
/// `_requireSession` 同一语义）。分组不完整（行数 ≠ `expected_objects` 或
/// 任一行未 confirmed）→ `StateError`，由调用方按"恢复未完成"处理。
Future<Map<String, dynamic>> restoreAttachmentGroupTemplate({
  required Map<String, dynamic> intent,
  required List<AttachmentUploadTask> rows,
  required String userId,
  required UploadMaterialsLoader loadMaterials,
  required void Function(String userId) requireSession,
}) async {
  final count = intent['expected_objects'] as int;
  if (rows.length != count ||
      rows.any((r) => r.stage != AttachmentUploadStage.confirmed)) {
    throw StateError('attachment group incomplete');
  }
  final kind = intent['attachment_kind'];
  final template = Map<String, dynamic>.from(intent['message_template'] as Map);
  final metadata = Map<String, dynamic>.from(
    template['metadata'] as Map? ?? {},
  );
  if (kind == MessageType.imageMulti) {
    metadata['images'] = await _restoreImageItems(
      rows,
      userId: userId,
      loadMaterials: loadMaterials,
      requireSession: requireSession,
    );
    metadata['total'] = (metadata['images'] as List).length;
    template['metadata'] = metadata;
    return template;
  }
  final main = kind == 'video'
      ? rows.singleWhere((r) => r.mime.startsWith('video/'))
      : rows.single;
  if (main.objectKey == null || main.objectKey!.isEmpty) {
    throw StateError('confirmed attachment identity missing');
  }
  if (main.cipher != null) {
    final materials = await loadMaterials(main);
    requireSession(userId);
    final descriptor = materials?['descriptor'];
    if (descriptor == null) throw LostCipherMaterialError(main.id);
    metadata['attachment_descriptor'] = jsonDecode(descriptor);
  }
  metadata['file_hash256'] = main.ciphertextSha256 ?? main.plainSha256;
  if (kind == 'location') {
    metadata['thumb'] = main.objectKey;
    metadata['size'] = main.plainSize;
  } else {
    template['source'] = main.objectKey;
    template['size'] = main.plainSize;
  }
  if (kind == 'video') {
    final thumb = rows.singleWhere((r) => r.id != main.id);
    metadata['thumb'] = {'uri': thumb.objectKey};
  }
  template['metadata'] = metadata;
  return template;
}

/// 多图：逐行回填 images[] 元素，顺序 = 每行 intent 的 `object_index`。
///
/// 尺寸/文件名来自该行 intent 的 `object_meta`（上传时随行写入，anchor 整组
/// 覆写 intent 的 `saveBusinessIntent` 只发生在出站之后，不影响这里读取）；
/// uri / size / file_hash256 / descriptor 一律以 journal 行与密钥库为准。
Future<List<Map<String, dynamic>>> _restoreImageItems(
  List<AttachmentUploadTask> rows, {
  required String userId,
  required UploadMaterialsLoader loadMaterials,
  required void Function(String userId) requireSession,
}) async {
  final ordered = [...rows]
    ..sort((a, b) => _objectIndex(a).compareTo(_objectIndex(b)));
  final images = <Map<String, dynamic>>[];
  for (final r in ordered) {
    if (r.objectKey == null || r.objectKey!.isEmpty) {
      throw StateError('confirmed attachment identity missing');
    }
    final item = <String, dynamic>{
      ..._objectMeta(r),
      'uri': r.objectKey,
      'size': r.plainSize,
      'file_hash256': r.ciphertextSha256 ?? r.plainSha256,
    };
    if (r.cipher != null) {
      final materials = await loadMaterials(r);
      requireSession(userId);
      final descriptor = materials?['descriptor'];
      if (descriptor == null) throw LostCipherMaterialError(r.id);
      item['attachment_descriptor'] = jsonDecode(descriptor);
    }
    images.add(item);
  }
  return images;
}

Map<String, dynamic> _rowIntent(AttachmentUploadTask r) {
  final raw = r.businessIntent;
  if (raw == null) return const {};
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  } on FormatException {
    return const {};
  }
}

/// 排序键：`object_index` 缺失/损坏时退回 createdAt（上传按序插入），
/// 只影响显示顺序，不影响 uri 与密钥的正确性。
int _objectIndex(AttachmentUploadTask r) {
  final v = _rowIntent(r)['object_index'];
  return v is int ? v : r.createdAt;
}

Map<String, dynamic> _objectMeta(AttachmentUploadTask r) {
  final meta = _rowIntent(r)['object_meta'];
  return meta is Map ? Map<String, dynamic>.from(meta) : const {};
}
