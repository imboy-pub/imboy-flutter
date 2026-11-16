/// Central Wiring 合并转发编排与按钮动作策略测试（chat_history_bundle_v1）。
///
/// 覆盖：
/// 1. `bundleActionAllowedFor` / `exportActionAllowedFor`：flag 门控 +
///    类型矩阵 + 状态/焚毁/E2EE 失败 + 条数上限（计划 §12.5）。
/// 2. `BundleForwardDispatcher.sendToTargets`：目标串行、每目标独立构建、
///    禁止字段不入 payload、源行缺失整体放弃、准入预检失败零落库、
///    192KiB 客户端软边（W3-L F-4）、附件任务绑定（新 message id /
///    目标 scope / 转发者 uid，W2-G 调用契约）。
///
/// 全部经注入 fake（fetcher/inserter/forwarder）脱离 SQLite 与网络。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/modules/messaging/application/history_bundle/bundle_attachment_forwarder.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart'
    as domain_msg;
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/page/chat/chat/bundle_forward_dispatcher.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

part 'bundle_forward_dispatcher_fixtures.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _uid);
    await StorageService.to.setString(
      Keys.currentUser,
      '{"uid":"$_uid","nickname":"Fixture sender","account":"",'
      '"email":"","mobile":"","avatar":"","role":null,"gender":0,'
      '"region":"","sign":"","setting":{}}',
    );
  });

  for (final throwsError in [false, true]) {
    test(
      'dispatch ${throwsError ? "throw" : "false"} retains one local echo and reports failure',
      () async {
        final inserted = <MessageModel>[];
        final echoes = <core.Message>[];
        final order = <String>[];
        final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
          (event) {
            if (event.dataType == 'Message') {
              echoes.add(event.data as core.Message);
              order.add('echo');
            }
          },
        );
        addTearDown(subscription.cancel);
        final dispatcher = BundleForwardDispatcher(
          messageFetcher: (id, _) async => _sourceRow(id, 1000),
          messageInserter: (model, _) async => inserted.add(model),
          forwarderUidResolver: () => _uid,
          wsDispatcher: (model) async {
            await Future<void>.delayed(Duration.zero);
            order.add('dispatch');
            if (throwsError) throw StateError('dispatch failed');
            return false;
          },
        );
        final report = await dispatcher.sendToTargets(
          [_target(1, '1000000056')],
          [_uiMessage('m1')],
          sourceChatType: 'C2C',
        );
        expect(report.successCount, 0);
        expect(report.allSuccess, isFalse);
        expect(
          report.failures.single.errorCode,
          HistoryBundleBuildErrorCode.sendFailed,
        );
        expect(inserted, hasLength(1));
        expect(inserted.single.status, IMBoyMessageStatus.sending);
        expect(echoes, hasLength(1));
        expect(echoes.single.id, inserted.single.id);
        expect(echoes.single.status, core.MessageStatus.sending);
        expect(order, ['echo', 'dispatch']);
      },
    );
  }

  setUp(() {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
      'chat_multi_select_v1': true,
      'chat_history_bundle_v1': true,
      'chat_export_share_v1': true,
    });
  });

  tearDown(() {
    AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
  });

  group('bundleActionAllowedFor（§12.5 合并转发按钮策略）', () {
    test('flag 关闭 → 恒 false', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
      expect(
        bundleActionAllowedFor([_traits('text')]),
        isFalse,
        reason: 'rollout flag 默认关闭，关闭时按钮禁用（零 UI 变化语义）',
      );
    });

    test('text/image/voice/quote 可合并 → true；空集 → false', () {
      expect(bundleActionAllowedFor([_traits('text')]), isTrue);
      expect(bundleActionAllowedFor([_traits('image')]), isTrue);
      expect(bundleActionAllowedFor([_traits('voice')]), isTrue);
      expect(bundleActionAllowedFor([_traits('quote')]), isTrue);
      expect(bundleActionAllowedFor(<MessageSelectionTraits>[]), isFalse);
    });

    test('状态维度：sending/error/revoked → false', () {
      expect(
        bundleActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.sending),
        ]),
        isFalse,
      );
      expect(
        bundleActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.error),
        ]),
        isFalse,
      );
      expect(
        bundleActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.revoked),
        ]),
        isFalse,
      );
    });

    test('E2EE 失败占位 / 阅后即焚 → false（冻结合同 §4.4）', () {
      expect(
        bundleActionAllowedFor([_traits('text', e2eeFailed: true)]),
        isFalse,
      );
      expect(
        bundleActionAllowedFor([_traits('text', burnReadAt: 123)]),
        isFalse,
      );
    });

    test('不可合并类型 → false（WebRTC/红包/转账/系统/未知 fail-closed）', () {
      expect(bundleActionAllowedFor([_traits('webrtcAudio')]), isFalse);
      expect(bundleActionAllowedFor([_traits('redPacket')]), isFalse);
      expect(bundleActionAllowedFor([_traits('transfer')]), isFalse);
      expect(bundleActionAllowedFor([_traits('groupNotice')]), isFalse);
      expect(bundleActionAllowedFor([_traits(null)]), isFalse);
      expect(bundleActionAllowedFor([_traits('some_unknown_type')]), isFalse);
    });

    test('51 条 → false（1..50 上限）；50 条 → true', () {
      expect(
        bundleActionAllowedFor(List.generate(51, (_) => _traits('text'))),
        isFalse,
      );
      expect(
        bundleActionAllowedFor(List.generate(50, (_) => _traits('text'))),
        isTrue,
      );
    });
  });

  group('exportActionAllowedFor（§12.5 导出按钮策略）', () {
    test('flag 关闭 → 恒 false', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{});
      expect(exportActionAllowedFor([_traits('text')]), isFalse);
    });

    test('text 与 image（描述导出）→ true；红包/发送中/E2EE 失败 → false', () {
      expect(exportActionAllowedFor([_traits('text')]), isTrue);
      expect(exportActionAllowedFor([_traits('image')]), isTrue);
      expect(exportActionAllowedFor([_traits('redPacket')]), isFalse);
      expect(
        exportActionAllowedFor([
          _traits('text', status: domain_msg.MessageStatus.sending),
        ]),
        isFalse,
      );
      expect(
        exportActionAllowedFor([_traits('text', e2eeFailed: true)]),
        isFalse,
      );
    });
  });

  group('BundleForwardDispatcher.sendToTargets', () {
    test(
      'sealed local location keeps trusted DB projection instead of UI text',
      () async {
        final row = _sourceRow('sealed', 1000, msgType: 'location')
          ..fromId = _uid
          ..isAuthor = 1
          ..payload = ''
          ..e2ee = {'meta_version': 3};
        final inserted = <MessageModel>[];
        final dispatcher = BundleForwardDispatcher(
          messageFetcher: (_, _) async => row,
          localPayloadLoader: (model) async {
            expect(identical(model, row), isTrue);
            return {
              'title': 'trusted location',
              'latitude': '39.123456789012',
              'longitude': '116.123456789012',
            };
          },
          messageInserter: (model, _) async => inserted.add(model),
          wsDispatcher: (_) async => true,
          forwarderUidResolver: () => _uid,
        );
        final report = await dispatcher.sendToTargets(
          [_target(1, '1000000056')],
          [_uiMessage('sealed')],
          sourceChatType: 'C2C',
        );
        expect(report.allSuccess, isTrue);
        final entries = inserted.single.payloadMap['entries'] as List;
        expect((entries.single as Map)['payload'], {
          'title': 'trusted location',
          'latitude': '39.123456789012',
          'longitude': '116.123456789012',
        });
        expect(inserted.single.id, isNot('sealed'));
      },
    );

    for (final scenario in ['missing', 'burned', 'failed', 'account-switch']) {
      test(
        'sealed local source $scenario fails closed before inserting',
        () async {
          final row = _sourceRow('sealed', 1000, msgType: 'location')
            ..fromId = _uid
            ..isAuthor = 1
            ..payload = ''
            ..e2ee = {'meta_version': 3};
          if (scenario == 'failed') row.status = IMBoyMessageStatus.error;
          final inserted = <MessageModel>[];
          addTearDown(() => StorageService.to.setString(Keys.currentUid, _uid));
          final dispatcher = BundleForwardDispatcher(
            messageFetcher: (_, _) async => row,
            localPayloadLoader: (_) async {
              if (scenario == 'missing') return null;
              if (scenario == 'account-switch') {
                await StorageService.to.setString(
                  Keys.currentUid,
                  'other-account',
                );
              }
              return {
                'title': 'trusted location',
                if (scenario == 'burned') 'burn_read_at': '1731000000000',
              };
            },
            messageInserter: (model, _) async => inserted.add(model),
            wsDispatcher: (_) async => true,
            forwarderUidResolver: () => _uid,
          );
          final report = await dispatcher.sendToTargets(
            [_target(1, '1000000056')],
            [_uiMessage('sealed')],
            sourceChatType: 'C2C',
          );
          expect(report.successCount, 0);
          expect(inserted, isEmpty);
          if (scenario == 'missing') {
            expect(
              report.failures.single.errorCode,
              HistoryBundleBuildErrorCode.rejectedE2eeFailed,
            );
          }
          if (scenario == 'burned') {
            expect(
              report.failures.single.errorCode,
              HistoryBundleBuildErrorCode.rejectedBurnAfterRead,
            );
          }
        },
      );
    }

    for (final stage in ['resolver', 'forwarder', 'insert']) {
      test(
        'sealed projection scope change during $stage stops later effects',
        () async {
          final row = _sourceRow('sealed', 1000, msgType: 'file')
            ..fromId = _uid
            ..isAuthor = 1
            ..payload = ''
            ..e2ee = {'meta_version': 3};
          Future<void> switchAccount() =>
              StorageService.to.setString(Keys.currentUid, 'other-account');
          addTearDown(() => StorageService.to.setString(Keys.currentUid, _uid));
          final inserted = <MessageModel>[];
          final echoes = <core.Message>[];
          var dispatches = 0;
          final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>()
              .listen((event) {
                if (event.dataType == 'Message') {
                  echoes.add(event.data as core.Message);
                }
              });
          addTearDown(subscription.cancel);
          final forwarder = _RecordingForwarder(
            beforeReturn: stage == 'forwarder' ? switchAccount : null,
          );
          final dispatcher = BundleForwardDispatcher(
            messageFetcher: (_, _) async => row,
            localPayloadLoader: (_) async => {
              'uri': 'obj/trusted-source',
              'attachment_descriptor': {'synthetic': true},
            },
            targetEncryptedResolver: (_, _) async {
              if (stage == 'resolver') await switchAccount();
              return true;
            },
            attachmentForwarder: forwarder,
            messageInserter: (model, _) async {
              inserted.add(model);
              if (stage == 'insert') await switchAccount();
            },
            wsDispatcher: (_) async {
              dispatches++;
              return true;
            },
            forwarderUidResolver: () => _uid,
          );
          final report = await dispatcher.sendToTargets(
            [_target(1, '1000000056')],
            [_uiMessage('sealed')],
            sourceChatType: 'C2C',
          );
          await Future<void>.delayed(Duration.zero);
          expect(report.successCount, 0);
          expect(
            report.failures.single.errorCode,
            HistoryBundleBuildErrorCode.sendFailed,
          );
          expect(inserted.length, stage == 'insert' ? 1 : 0);
          expect(forwarder.requests.length, stage == 'resolver' ? 0 : 1);
          expect(echoes, isEmpty);
          expect(dispatches, 0);
        },
      );
    }

    test('2 源 × 2 目标：目标串行、每目标独立构建、payload 干净、目标字段正确', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow('m1', 1000),
        'm2': _sourceRow('m2', 2000),
      };
      final inserted = <MessageModel>[];
      final targets = [_target(1, '1000000056'), _target(2, '1000000057')];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(targets, [
        _uiMessage('m1'),
        _uiMessage('m2'),
      ], sourceChatType: 'C2C');

      expect(report.allSuccess, isTrue);
      expect(report.successCount, 2);
      expect(inserted.length, 2);
      // 目标串行：插入顺序 = 目标传入顺序（§4.3 v1 目标间也串行）
      expect(inserted[0].toId, '1000000056');
      expect(inserted[1].toId, '1000000057');
      // 每目标独立新 message id
      expect(inserted[0].id, isNot(inserted[1].id));
      for (final row in inserted) {
        expect(row.msgType, 'chat_history_bundle');
        expect(row.status, IMBoyMessageStatus.sending);
        expect(row.isAuthor, 1);
        expect(row.fromId, _uid);
        final payload = row.payloadMap;
        expect(payload['bundle_version'], 1);
        final entries = payload['entries'] as List;
        expect(entries.length, 2);
        // 稳定排序：createdAt 从旧到新
        expect((entries[0] as Map)['payload']['text'], 'hello m1');
        expect((entries[1] as Map)['payload']['text'], 'hello m2');
        // 禁止字段（合同 §4.5）不入 payload 顶层
        expect(payload.containsKey('peer_id'), isFalse);
        expect(payload.containsKey('conversation_uk3'), isFalse);
        expect(payload.containsKey('sender_did'), isFalse);
        expect(payload.containsKey('burn_read_at'), isFalse);
      }
    });

    test('准入预检失败（sending 源）→ 零落库零转发，整体放弃', () async {
      final rows = <String, MessageModel>{
        'm1': _sourceRow('m1', 1000),
        'm2': _sourceRow('m2', 2000, status: IMBoyMessageStatus.sending),
      };
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1'), _uiMessage('m2')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.rejectedStatusSending,
      );
      expect(inserted, isEmpty);
    });

    test('源行缺失 → 整体放弃（sourceMissing），无部分 bundle', () async {
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => null,
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.sourceMissing,
        reason: 'W5 G4-7：源行缺失与目标标识缺失语义分离，专用稳定码',
      );
      expect(inserted, isEmpty);
    });

    test(
      'W5 G4-1：burn_read_at 为字符串形态 → rejectedBurnAfterRead（焚毁闸 §4.4）',
      () async {
        final rows = <String, MessageModel>{
          'm1': _sourceRow(
            'm1',
            1000,
            payload: <String, dynamic>{
              'text': 'burn-me',
              // 字符串形态的已读时刻：仅按 int 解析会落 0 绕过焚毁闸。
              'burn_read_at': '1731000000000',
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
        );

        final report = await dispatcher.sendToTargets(
          [_target(1, '1000000056')],
          [_uiMessage('m1')],
          sourceChatType: 'C2C',
        );

        expect(report.successCount, 0);
        expect(
          report.failures.single.errorCode,
          HistoryBundleBuildErrorCode.rejectedBurnAfterRead,
          reason: '字符串 burn_read_at 必须经 ChatBurnService 宽松解析命中焚毁闸',
        );
        expect(inserted, isEmpty, reason: '无半转发状态');
      },
    );

    test('W5 G4-2：空 targets → invalidTarget 稳定码返回（不抛 StateError）', () async {
      var fetcherCalls = 0;
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async {
          fetcherCalls++;
          return null;
        },
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(<ConversationModel>[], [
        _uiMessage('m1'),
      ], sourceChatType: 'C2C');

      expect(report.successCount, 0);
      expect(report.allSuccess, isFalse);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.invalidTarget,
        reason: '与 validateBatch 空目标同语义的稳定码',
      );
      expect(fetcherCalls, 0, reason: '入口防御在阶段 1 之前短路');
      expect(inserted, isEmpty);
    });

    test('S1-L3：>9 目标 → invalidTarget 整体拒绝（9 目标闸纵深防御）', () async {
      var fetcherCalls = 0;
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async {
          fetcherCalls++;
          return _sourceRow('m1', 1000);
        },
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );
      final tenTargets = [
        for (var i = 0; i < 10; i++) _target(i + 1, '20000$i'),
      ];

      final report = await dispatcher.sendToTargets(tenTargets, [
        _uiMessage('m1'),
      ], sourceChatType: 'C2C');

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.invalidTarget,
        reason: '与 G4-2 空 targets 同风格的入口稳定码拒绝',
      );
      expect(fetcherCalls, 0, reason: '目标数闸在源行快照之前短路');
      expect(inserted, isEmpty, reason: '零构建零重传（资源不放大）');
    });

    test('S1-L3：9 目标（上限内）→ 全部逐目标成功', () async {
      final rows = <String, MessageModel>{'m1': _sourceRow('m1', 1000)};
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );
      final nineTargets = [
        for (var i = 0; i < 9; i++) _target(i + 1, '20000$i'),
      ];

      final report = await dispatcher.sendToTargets(nineTargets, [
        _uiMessage('m1'),
      ], sourceChatType: 'C2C');

      expect(report.allSuccess, isTrue);
      expect(report.successCount, 9);
      expect(inserted, hasLength(9), reason: '上限内逐目标独立构建不受影响');
    });

    test('S1-L5：forwarderName 进顶层 sender_name（详情页来源行数据源）', () async {
      final rows = <String, MessageModel>{'m1': _sourceRow('m1', 1000)};
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
        forwarderName: '李四',
      );

      expect(report.allSuccess, isTrue);
      expect(
        inserted.single.payloadMap['sender_name'],
        '李四',
        reason: '合同顶层预留键：转发者展示名仅供详情页来源行展示',
      );
    });

    test('S1-M1 写回兜底：附件写回产物深度超限 → sendFailed 整目标失败零落库', () async {
      // 理论不可达（构建期深度闸已拒深树源行），防御写回通路自身：
      // forwarder 产物若为深树（>maxDepth），sanitizeAttachmentWriteback
      // 不得让 depthExceeded 产物静默进入 bundle JSON。
      Map<String, dynamic> deep = <String, dynamic>{'leaf': true};
      for (var i = 0; i < 20; i++) {
        deep = <String, dynamic>{'nested': deep};
      }
      final rows = <String, MessageModel>{
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
        attachmentForwarder: _RecordingForwarder(script: [deep]),
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
        reason: '深度超限写回按稳定码整目标失败（不静默不落库）',
      );
      expect(inserted, isEmpty);
    });

    test(
      'W5 G4-3：阶段 1 fetcher 抛 Exception → sendFailed 归一，不产生未处理异步错误',
      () async {
        final inserted = <MessageModel>[];
        final dispatcher = BundleForwardDispatcher(
          wsDispatcher: (_) async => true,
          messageFetcher: (id, chatType) async => throw Exception('db locked'),
          messageInserter: (model, chatType) async => inserted.add(model),
          forwarderUidResolver: () => _uid,
          attachmentForwarder: _RecordingForwarder(),
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
          reason: 'DB 异常与 F4 附件基础设施失败同口径归一',
        );
        expect(inserted, isEmpty);
      },
    );

    test('W5 G4-3：阶段 2 probe 构建抛 Exception → sendFailed 归一，零落库', () async {
      final rows = <String, MessageModel>{'m1': _sourceRow('m1', 1000)};
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
        bundleBuilder: (uk3, sources, {title, senderName}) =>
            throw Exception('probe exploded'),
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
        reason: 'probe 构建异常不得穿透 sendToTargets（未处理异步错误）',
      );
      expect(inserted, isEmpty);
    });

    test('192KiB 客户端软边（W3-L F-4）：介于软边与 256KiB 之间先行失败', () async {
      final big = 'x' * (200 * 1024);
      final rows = <String, MessageModel>{
        'm1': _sourceRow('m1', 1000, payload: <String, dynamic>{'text': big}),
      };
      final inserted = <MessageModel>[];
      final dispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => rows[id],
        messageInserter: (model, chatType) async => inserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );

      final report = await dispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );

      expect(report.successCount, 0);
      expect(
        report.failures.single.errorCode,
        HistoryBundleBuildErrorCode.payloadTooLarge,
      );
      expect(inserted, isEmpty);

      // 边界下量级仍可正常发送
      final smallRows = <String, MessageModel>{
        'm1': _sourceRow(
          'm1',
          1000,
          payload: <String, dynamic>{'text': 'x' * 1024},
        ),
      };
      final okInserted = <MessageModel>[];
      final okDispatcher = BundleForwardDispatcher(
        wsDispatcher: (_) async => true,
        messageFetcher: (id, chatType) async => smallRows[id],
        messageInserter: (model, chatType) async => okInserted.add(model),
        forwarderUidResolver: () => _uid,
        attachmentForwarder: _RecordingForwarder(),
      );
      final ok = await okDispatcher.sendToTargets(
        [_target(1, '1000000056')],
        [_uiMessage('m1')],
        sourceChatType: 'C2C',
      );
      expect(ok.allSuccess, isTrue);
    });

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

    test(
      'A4 CRITICAL：sealed 源 + 明文目标 → rejected_plaintext_target，零落库',
      () async {
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
      },
    );

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

    test(
      'A4 HIGH：imageMulti 写回逐图净化，每图 descriptor 保留',
      _verifyMultiImageDescriptors,
    );

    test(
      'W5 G4-5：images[] 非 Map 元素取净化后版本（不透传原引用/未净化内容）',
      _verifySanitizedImageElements,
    );

    test(
      'F2：C2C 源 → C2G 目标：scope/resolver/落库按目标 C2G，fetch 仍走源表',
      _verifyGroupTargetBinding,
    );

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
  });
}
