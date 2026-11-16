part of 'bundle_forward_dispatcher_test.dart';

const String _uid = '1000000051';

ConversationModel _target(int id, String peerId) => ConversationModel(
  id: id,
  peerId: peerId,
  avatar: '',
  title: 't$id',
  subtitle: '',
  type: 'C2C',
  msgType: 'text',
  unreadNum: 0,
);

MessageModel _sourceRow(
  String id,
  int createdAt, {
  Map<String, dynamic>? payload,
  int status = IMBoyMessageStatus.sent,
  String msgType = 'text',
}) => MessageModel(
  id,
  autoId: 0,
  type: 'C2C',
  status: status,
  fromId: '1000000056',
  toId: _uid,
  payload: payload ?? <String, dynamic>{'text': 'hello $id'},
  createdAt: createdAt,
  isAuthor: 0,
  conversationUk3: 'C2C_${_uid}_1000000056',
  msgType: msgType,
);

core.Message _uiMessage(String id) => core.TextMessage(
  id: id,
  authorId: '1000000056',
  text: 'hello $id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
);

MessageSelectionTraits _traits(
  String? msgType, {
  domain_msg.MessageStatus status = domain_msg.MessageStatus.sent,
  bool e2eeFailed = false,
  int burnReadAt = 0,
}) => MessageSelectionTraits(
  msgType: msgType,
  status: status,
  e2eeFailed: e2eeFailed,
  burnReadAt: burnReadAt,
);

/// 记录型附件转发 fake（按脚本顺序返回 payload，缺省新 uri payload）。
class _RecordingForwarder implements BundleAttachmentForwarder {
  // ignore: prefer_initializing_formals
  _RecordingForwarder({
    List<Map<String, dynamic>> script = const [],
    this.beforeReturn,
  }) : _script = List<Map<String, dynamic>>.of(script);

  final List<Map<String, dynamic>> _script;
  final Future<void> Function()? beforeReturn;
  var _calls = 0;
  final List<BundleAttachmentForwardRequest> requests =
      <BundleAttachmentForwardRequest>[];

  @override
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  ) async {
    requests.add(request);
    await beforeReturn?.call();
    final index = _calls++;
    if (index < _script.length) return _script[index];
    return <String, dynamic>{
      'uri': 'obj/new-key',
      'file_hash256': 'cafebabe',
      'size': 3,
    };
  }
}

/// 抛普通 Exception 的转发 fake（附件下载/上传等基础设施失败形态）。
class _ThrowingForwarder implements BundleAttachmentForwarder {
  const _ThrowingForwarder();

  @override
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  ) async {
    throw Exception('attachment upload failed');
  }
}

Future<void> _verifyMultiImageDescriptors() async {
  final rows = <String, MessageModel>{
    'm1': _sourceRow(
      'm1',
      1000,
      msgType: 'imageMulti',
      payload: <String, dynamic>{
        'images': [
          <String, dynamic>{
            'uri': 'obj/old-1',
            'attachment_descriptor': <String, dynamic>{'k': 1},
          },
          <String, dynamic>{'uri': 'obj/old-2', 'peer_id': 'leak'},
        ],
      },
    ),
  };
  final forwarder = _RecordingForwarder(
    script: <Map<String, dynamic>>[
      <String, dynamic>{
        'images': [
          <String, dynamic>{
            'uri': 'obj/new-1',
            'attachment_descriptor': <String, dynamic>{'new': 1},
            'from_id': 'junk',
          },
          <String, dynamic>{
            'uri': 'obj/new-2',
            'attachment_descriptor': <String, dynamic>{'new': 2},
          },
        ],
        'total': 2,
      },
    ],
  );
  final inserted = <MessageModel>[];
  final dispatcher = BundleForwardDispatcher(
    wsDispatcher: (_) async => true,
    messageFetcher: (id, chatType) async => rows[id],
    messageInserter: (model, chatType) async => inserted.add(model),
    forwarderUidResolver: () => _uid,
    attachmentForwarder: forwarder,
    targetEncryptedResolver: (chatType, peerId) async => true,
  );

  final report = await dispatcher.sendToTargets(
    [_target(1, '1000000056')],
    [_uiMessage('m1')],
    sourceChatType: 'C2C',
  );

  expect(report.allSuccess, isTrue);
  final wp =
      ((inserted.single.payloadMap['entries'] as List).first as Map)['payload']
          as Map;
  final images = wp['images'] as List;
  expect((images[0] as Map)['attachment_descriptor'], {'new': 1});
  expect((images[0] as Map).containsKey('from_id'), isFalse);
  expect((images[1] as Map)['attachment_descriptor'], {'new': 2});
  expect((images[1] as Map)['uri'], 'obj/new-2');
}

Future<void> _verifySanitizedImageElements() async {
  final rows = <String, MessageModel>{
    'm1': _sourceRow(
      'm1',
      1000,
      msgType: 'imageMulti',
      payload: <String, dynamic>{
        'images': [
          <String, dynamic>{'uri': 'obj/old-1'},
        ],
      },
    ),
  };
  // adapter 产物：images 混入非 Map 元素（嵌套 list 夹带禁止键 + 标量）。
  final adapterPayload = <String, dynamic>{
    'images': [
      <String, dynamic>{'uri': 'obj/new-1'},
      <dynamic>[
        <String, dynamic>{'peer_id': 'leak', 'text': 'x'},
      ],
      'plain-scalar',
    ],
    'total': 3,
  };
  final forwarder = _RecordingForwarder(script: [adapterPayload]);
  final inserted = <MessageModel>[];
  final dispatcher = BundleForwardDispatcher(
    wsDispatcher: (_) async => true,
    messageFetcher: (id, chatType) async => rows[id],
    messageInserter: (model, chatType) async => inserted.add(model),
    forwarderUidResolver: () => _uid,
    attachmentForwarder: forwarder,
    targetEncryptedResolver: (chatType, peerId) async => true,
  );

  final report = await dispatcher.sendToTargets(
    [_target(1, '1000000056')],
    [_uiMessage('m1')],
    sourceChatType: 'C2C',
  );

  expect(report.allSuccess, isTrue);
  final wp =
      ((inserted.single.payloadMap['entries'] as List).first as Map)['payload']
          as Map;
  final images = wp['images'] as List;
  expect(images, hasLength(3));
  // Map 元素照常净化 + descriptor 回填路径。
  expect((images[0] as Map)['uri'], 'obj/new-1');
  // 非 Map 的嵌套 list 元素：必须走 sanitizer 净化（禁止键被清），
  // 不得原引用透传。
  final nested = (images[1] as List).single as Map;
  expect(nested.containsKey('peer_id'), isFalse, reason: '禁止键被清理');
  expect(nested['text'], 'x');
  expect(
    identical(images[1], (adapterPayload['images'] as List)[1]),
    isFalse,
    reason: '非 Map 元素也不得与 adapter 产物共享可变引用',
  );
  // 标量元素保留。
  expect(images[2], 'plain-scalar');
}

Future<void> _verifyGroupTargetBinding() async {
  final fetchChatTypes = <String>[];
  final rows = <String, MessageModel>{
    'm1': _sourceRow(
      'm1',
      1000,
      msgType: 'file',
      payload: <String, dynamic>{
        'uri': 'obj/old-key',
        'attachment_descriptor': <String, dynamic>{'k': 'v'},
      },
    ),
  };
  final resolverCalls = <({String chatType, String peerId})>[];
  final forwarder = _RecordingForwarder();
  final insertChatTypes = <String>[];
  final inserted = <MessageModel>[];
  const gid = '2000000071';
  final groupTarget = ConversationModel(
    id: 9,
    peerId: gid,
    avatar: '',
    title: 'g',
    subtitle: '',
    type: 'C2G',
    msgType: 'text',
    unreadNum: 0,
  );
  final dispatcher = BundleForwardDispatcher(
    wsDispatcher: (_) async => true,
    messageFetcher: (id, chatType) async {
      fetchChatTypes.add(chatType);
      return rows[id];
    },
    messageInserter: (model, chatType) async {
      insertChatTypes.add(chatType);
      inserted.add(model);
    },
    forwarderUidResolver: () => _uid,
    attachmentForwarder: forwarder,
    targetEncryptedResolver: (chatType, peerId) async {
      resolverCalls.add((chatType: chatType, peerId: peerId));
      return true;
    },
  );

  final report = await dispatcher.sendToTargets(
    [groupTarget],
    [_uiMessage('m1')],
    sourceChatType: 'C2C',
  );

  expect(report.allSuccess, isTrue);
  // 源消息 DB 行 fetch 仍按**源** chatType（fetch 表按源）
  expect(fetchChatTypes, everyElement('C2C'));
  // resolver 收到**目标**派生 chatType + 目标 peerId（与单条转发同口径）
  expect(resolverCalls, hasLength(1));
  expect(resolverCalls.single.chatType, 'C2G');
  expect(resolverCalls.single.peerId, gid);
  expect(
    resolverCalls.map((r) => r.chatType),
    isNot(contains('C2C')),
    reason: '跨类型目标不得把源 chatType 灌进加密判定',
  );
  // 上传 scope 按目标 C2G：scope=group、绑定=gid（deriveUploadScope）
  expect(forwarder.requests, hasLength(1));
  expect(forwarder.requests.single.targetScope, 'group');
  expect(forwarder.requests.single.targetConversationUk3, gid);
  // 落库：model.type=C2G 且插表走 msg_c2g（chatType=C2G）
  expect(inserted.single.type, 'C2G');
  expect(insertChatTypes, everyElement('C2G'));
}
