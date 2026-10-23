part of 'attachment_handler.dart';

/// 附件消息意图（journal businessIntent）构造 + 多图（imageMulti）打包发送。
///
/// attachment_handler.dart 受文件行数 ratchet 门约束；本 part 与它同属一个
/// library，顶层函数可直接访问 handler 的私有成员（封装判定、发送回调、
/// 阅后即焚元数据），不必为拆分把这些安全敏感成员改成公开 API。
///
/// ## 多图为什么必须走上传日志 / 业务出站箱
///
/// 单图在生产路径下并不是用内存里构造的 `ImageMessage` 出网的：
/// `_sendMessage` 查到该消息 id 的 journal 行后，交给
/// `ResumableAttachmentUploader.recoverBusinessOutbox` 从 **模板 + 日志**
/// 重建消息（descriptor 来自密钥库），再经业务出站箱 / 重试队列发送。
/// 多图沿用同一条管线：N 张图 = N 条 journal 行，同一 `anchor_msg_id`、
/// `expected_objects = N`、每行自带 `object_index` 保序；消息由
/// `restoreAttachmentGroupTemplate` 的 imageMulti 分支回填 `images[]`。

/// 构造附件上传日志的 businessIntent + 消息模板
/// （[ChatAttachmentHandler.pendingMessageIntent] 的实现体）。
///
/// `expected_objects` 默认按 kind 推导（视频双对象，其余单对象）；多图由
/// 调用方显式传 N。[intentExtra] 直接并入 intent 顶层——多图用它携带每行的
/// `object_index` / `object_meta`，恢复时据此排序与回填尺寸。
Map<String, dynamic> attachmentIntentFor(
  ChatAttachmentHandler handler, {
  required String id,
  required String kind,
  String name = '',
  int size = 0,
  double width = 0,
  double height = 0,
  Duration duration = Duration.zero,
  List<double>? waveform,
  Map<String, dynamic> extra = const {},
  int? expectedObjects,
  Map<String, dynamic> intentExtra = const {},
}) {
  final created = DateTime.now().toUtc();
  final metadata = handler._withBurnMetadata({
    'peer_id': handler.peerId,
    ...extra,
  });
  final Message template = switch (kind) {
    'file' => FileMessage(
      id: id,
      authorId: handler._currentUser.id,
      createdAt: created,
      source: '',
      mimeType: extra['mime_type'] as String?,
      name: name,
      size: size,
      metadata: metadata,
    ),
    'image' => ImageMessage(
      id: id,
      authorId: handler._currentUser.id,
      createdAt: created,
      source: '',
      text: name,
      size: size,
      width: width,
      height: height,
      metadata: metadata,
    ),
    'video' => VideoMessage(
      id: id,
      authorId: handler._currentUser.id,
      createdAt: created,
      source: '',
      text: name,
      name: name,
      size: size,
      width: width,
      height: height,
      metadata: {...metadata, 'duration_ms': duration.inMilliseconds},
    ),
    'voice' => AudioMessage(
      id: id,
      authorId: handler._currentUser.id,
      createdAt: created,
      source: '',
      text: '',
      size: size,
      duration: duration,
      waveform: waveform,
      metadata: metadata,
    ),
    'location' => CustomMessage(
      id: id,
      authorId: handler._currentUser.id,
      createdAt: created,
      metadata: {...metadata, 'msg_type': 'location'},
    ),
    // 多图：images[] 在恢复时由各 journal 行回填（uri/size/file_hash256/
    // descriptor 都以日志为准），模板只承载 msg_type 与会话/阅后即焚元数据。
    MessageType.imageMulti => CustomMessage(
      id: id,
      authorId: handler._currentUser.id,
      createdAt: created,
      metadata: {...metadata, 'msg_type': MessageType.imageMulti},
    ),
    _ => throw StateError('unsupported attachment template'),
  };
  return {
    ...handler._businessIntent(id),
    'message_template': handler._safeMessageJson(template),
    'attachment_kind': kind,
    'expected_objects': expectedObjects ?? (kind == 'video' ? 2 : 1),
    ...intentExtra,
  };
}

/// 相册多选结果的发送规划：≥2 张图片聚合为**单条** imageMulti（一条消息多张图，
/// 与 Telegram/iMessage 及本项目频道的 imageText 口径一致），单图保持既有
/// `uploadSelectedAsset` 路径不变。
Future<void> uploadPickedImages(
  ChatAttachmentHandler handler,
  BuildContext context,
  List<AssetEntity> result,
) async {
  final images = result.where((e) => e.type == AssetType.image).toList();
  if (images.length < 2) {
    for (final entity in result) {
      await handler.uploadSelectedAsset(context, entity);
    }
    return;
  }
  await uploadImagesAsMulti(handler, context, images);
  if (!context.mounted) return;
  // 选择器当前只出图片（RequestType.image）；防御性地让非图片项仍逐条走旧路径
  for (final entity in result) {
    if (entity.type != AssetType.image) {
      await handler.uploadSelectedAsset(context, entity);
    }
  }
}

/// N 张图片 → 单条 imageMulti：全部封装决策（fail-closed）→ 逐张上传
/// （同一 anchor）→ 发一条。
///
/// - 封装决策在**任何上传之前**一次做完：加密会话缺绑定输入时直接中止，
///   不留下"传了一半密文"的中间态（与 [ChatAttachmentHandler._sealFor] 同一
///   fail-closed 语义）；
/// - N 张图共用同一 `anchor_msg_id`：服务端把群附件绑到 conv_seq 是按 anchor
///   的多行 UPDATE（`msg_store_repo:bind_group_attachment_anchors`），无唯一约束；
/// - 任一张上传失败 → 整条失败并提示（单条消息不能引用未上传对象）；已上传
///   对象留给服务端孤儿清理，journal 行留给既有恢复流程。
Future<void> uploadImagesAsMulti(
  ChatAttachmentHandler handler,
  BuildContext context,
  List<AssetEntity> images,
) async {
  try {
    final s = handler._uploadScope;
    final String messageId = Xid().toString();
    final seals = await _sealsForMulti(handler, messageId, images.length);
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < images.length; i++) {
      final entity = images[i];
      final name = await entity.titleAsync;
      final meta = await AttachmentApi.uploadImageEntityViaPresign(
        entity,
        scope: s.scope,
        scopeRef: s.scopeRef,
        anchorMsgId: messageId,
        messageIntent: handler.pendingMessageIntent(
          messageId,
          MessageType.imageMulti,
          name: name,
          width: entity.width.toDouble(),
          height: entity.height.toDouble(),
          expectedObjects: images.length,
          intentExtra: {
            'object_index': i,
            'object_meta': {
              'name': name,
              'width': entity.width,
              'height': entity.height,
            },
          },
        ),
        seal: seals[i],
      );
      items.add(
        handler._withDescriptor({
          'uri': meta['object_key'],
          'name': name,
          'size': meta['size'],
          'width': entity.width,
          'height': entity.height,
          'file_hash256': meta['file_hash256'].toString(),
        }, seals[i]),
      );
    }
    final message = CustomMessage(
      authorId: handler._currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: messageId,
      // images[i] 的 descriptor 嵌套在 payload 内随 PFv3 整体加密；明文出网由
      // AttachmentSealPolicy.carriesContentKey 的嵌套检测兜底拦截。
      metadata: handler._withBurnMetadata({
        'msg_type': MessageType.imageMulti,
        'peer_id': handler.peerId,
        'images': items,
        'total': items.length,
      }),
    );
    await handler._sendMessage(message);
  } on Object catch (e) {
    final p = ChatAttachmentHandler._attachmentFailurePresentation(e);
    debugPrint('[attachment_handler] uploadImagesAsMulti failed, ${p.log}');
    AppLoading.showError(p.toast);
  }
}

/// 一次加密判定派生 N 份 seal。attachmentId 逐图区分（`image_0`…）：它进
/// AAD，同一条消息内多个附件不可互换（见 [AttachmentSealRequest]）。
///
/// 加密会话下任一份算不出绑定值 → 在任何上传前抛出，与 `_sealFor` 同一
/// fail-closed 口径。
Future<List<AttachmentSealRequest?>> _sealsForMulti(
  ChatAttachmentHandler handler,
  String messageId,
  int count,
) async {
  final bool encrypted = await handler._payloadWillBeEncrypted();
  final seals = <AttachmentSealRequest?>[];
  for (var i = 0; i < count; i++) {
    final attachmentId = 'image_$i';
    final seal = ChatAttachmentHandler.buildSealRequest(
      rolloutEnabled: handler.sealRollout,
      payloadWillBeEncrypted: encrypted,
      messageId: messageId,
      conversationId: handler.sealConversationId,
      senderUid: handler._currentUser.id,
      attachmentId: attachmentId,
    );
    if (seal == null && encrypted && handler.sealRollout) {
      throw E2eeSecurityException('attachment_binding_missing:$attachmentId');
    }
    seals.add(seal);
  }
  return seals;
}
