part of 'bundle_forward_dispatcher_test.dart';

void _registerAttachmentForwardingCases() {
  test('附件任务绑定：新 message id / 目标 scope / 转发者 uid（W2-G 契约）', () async {
    final rows = <String, MessageModel>{
      'm1': _sourceRow(
        'm1',
        1000,
        msgType: 'file',
        payload: <String, dynamic>{
          'uri': 'obj/old-key',
          'attachment_descriptor': <String, dynamic>{'k': 'v'},
          'file_hash256': 'deadbeef',
        },
      ),
    };
    final forwarder = _RecordingForwarder();
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
    expect(forwarder.requests, hasLength(1));
    final req = forwarder.requests.single;
    expect(req.task.sourceMsgType, 'file');
    expect(req.task.sourceMessageId, 'm1');
    expect(
      req.newMessageId,
      inserted.single.id,
      reason: '附件锚点与落库消息同 id（与单条转发同序）',
    );
    expect(req.targetScope, 'c2c');
    expect(
      req.targetConversationUk3,
      startsWith('c2c:'),
      reason: '重封装 targetConversationId 绑定与单条转发同真值（scopeRef）',
    );
    expect(req.forwarderUid, _uid);
    // withEntryPayload 写回：落库 payload 的 entry 使用适配器产物
    final entries = inserted.single.payloadMap['entries'] as List;
    expect((entries[0] as Map)['payload']['uri'], 'obj/new-key');
    expect((entries[0] as Map)['payload']['file_hash256'], 'cafebabe');
  });

  test('A4 CRITICAL：sealed 源 + 明文目标 → rejected_plaintext_target，零落库', () async {
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
    var resolverCalls = 0;
    final forwarder = _RecordingForwarder();
    final inserted = <MessageModel>[];
    final dispatcher = BundleForwardDispatcher(
      wsDispatcher: (_) async => true,
      messageFetcher: (id, chatType) async => rows[id],
      messageInserter: (model, chatType) async => inserted.add(model),
      forwarderUidResolver: () => _uid,
      attachmentForwarder: forwarder,
      targetEncryptedResolver: (chatType, peerId) async {
        resolverCalls++;
        return false;
      },
    );

    final report = await dispatcher.sendToTargets(
      [_target(1, '1000000056')],
      [_uiMessage('m1')],
      sourceChatType: 'C2C',
    );

    expect(report.successCount, 0);
    expect(
      report.failures.single.errorCode,
      HistoryBundleBuildErrorCode.rejectedPlaintextTarget,
    );
    expect(resolverCalls, 1);
    expect(forwarder.requests, isEmpty, reason: '重封装不得开始');
    expect(inserted, isEmpty, reason: '无半转发状态');
  });

  test('A4 CRITICAL：plain 源 + 明文目标不受闸影响（回归锚）', () async {
    final rows = <String, MessageModel>{
      'm1': _sourceRow(
        'm1',
        1000,
        msgType: 'file',
        payload: <String, dynamic>{'uri': 'obj/old-key'},
      ),
    };
    final forwarder = _RecordingForwarder();
    final inserted = <MessageModel>[];
    final dispatcher = BundleForwardDispatcher(
      wsDispatcher: (_) async => true,
      messageFetcher: (id, chatType) async => rows[id],
      messageInserter: (model, chatType) async => inserted.add(model),
      forwarderUidResolver: () => _uid,
      attachmentForwarder: forwarder,
      targetEncryptedResolver: (chatType, peerId) async => false,
    );

    final report = await dispatcher.sendToTargets(
      [_target(1, '1000000056')],
      [_uiMessage('m1')],
      sourceChatType: 'C2C',
    );

    expect(report.allSuccess, isTrue);
    expect(forwarder.requests, hasLength(1));
    expect(inserted, hasLength(1));
  });

  test('A4 HIGH：写回产物经 sanitizer（junk 清理）且目标绑定 descriptor 保留', () async {
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
    final forwarder = _RecordingForwarder(
      script: <Map<String, dynamic>>[
        // adapter 产物：新 descriptor（目标绑定）+ 源残留 junk 键
        <String, dynamic>{
          'uri': 'obj/new-key',
          'file_hash256': 'cafebabe',
          'attachment_descriptor': <String, dynamic>{'new': 'key'},
          'from_id': '1000000056',
          'burn_read_at': 999,
          'e2ee_stale': <String, dynamic>{},
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
    final entryPayload =
        (inserted.single.payloadMap['entries'] as List).first as Map;
    final wp = entryPayload['payload'] as Map;
    expect(wp['uri'], 'obj/new-key');
    expect(wp['attachment_descriptor'], <String, dynamic>{
      'new': 'key',
    }, reason: '目标绑定新 descriptor 是接收侧开封合法机制（§4.5 禁止源密钥）');
    expect(wp.containsKey('from_id'), isFalse);
    expect(wp.containsKey('burn_read_at'), isFalse);
    expect(wp.containsKey('e2ee_stale'), isFalse);
  });

  test('A4 HIGH：imageMulti 写回逐图净化，每图 descriptor 保留', () async {
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
        ((inserted.single.payloadMap['entries'] as List).first
                as Map)['payload']
            as Map;
    final images = wp['images'] as List;
    expect((images[0] as Map)['attachment_descriptor'], {'new': 1});
    expect((images[0] as Map).containsKey('from_id'), isFalse);
    expect((images[1] as Map)['attachment_descriptor'], {'new': 2});
    expect((images[1] as Map)['uri'], 'obj/new-2');
  });

  test('W5 G4-5：images[] 非 Map 元素取净化后版本（不透传原引用/未净化内容）', () async {
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
        ((inserted.single.payloadMap['entries'] as List).first
                as Map)['payload']
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
  });

  test('F2：C2C 源 → C2G 目标：scope/resolver/落库按目标 C2G，fetch 仍走源表', () async {
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
  });

  test(
    'F4：非 Bundle 异常（附件上传失败）→ bundle_send_failed，不误标 payloadTooLarge',
    () async {
      final rows = <String, MessageModel>{
        // 明文附件源（无 descriptor）：不触发加密判定，异常来自转发适配器
        'm1': _sourceRow(
          'm1',
          1000,
          msgType: 'file',
          payload: <String, dynamic>{'uri': 'obj/old-key'},
        ),
      };
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: const _ThrowingForwarder(),
        targetEncryptedResolver: (chatType, peerId) async => true,
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.sendFailed,
        reason:
            '基础设施失败须归一专用稳定码（含 resolver 的 '
            'policy_not_initialized 等非 bundle 异常）',
      );
      expect(
        report.failures.single.errorCode,
        isNot(HistoryBundleBuildErrorCode.payloadTooLarge),
        reason: '尺寸语义不得被借用为泛化失败码（F4 误标本体）',
      );
      expect(inserted, isEmpty, reason: '失败目标零落库（无半转发状态）');
    },
  );

  test('F4 负向：BundleForwardException 保留原码（不被归一覆盖）', () async {
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
    final inserted = <MessageModel>[];
    final dispatcher = BundleForwardDispatcher(
      wsDispatcher: (_) async => true,
      messageFetcher: (id, chatType) async => rows[id],
      messageInserter: (model, chatType) async => inserted.add(model),
      forwarderUidResolver: () => _uid,
      attachmentForwarder: _RecordingForwarder(),
      targetEncryptedResolver: (chatType, peerId) async => false,
    );

    final report = await dispatcher.sendToTargets(
      [_target(1, '1000000056')],
      [_uiMessage('m1')],
      sourceChatType: 'C2C',
    );

    expect(report.successCount, 0);
    expect(
      report.failures.single.errorCode,
      HistoryBundleBuildErrorCode.rejectedPlaintextTarget,
      reason: '策略性拒绝的原码语义优先于基础设施归一码',
    );
    expect(
      report.failures.single.errorCode,
      isNot(HistoryBundleBuildErrorCode.sendFailed),
    );
    expect(inserted, isEmpty);
  });
}
