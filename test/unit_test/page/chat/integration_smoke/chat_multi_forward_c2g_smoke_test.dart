// test/unit_test/page/chat/integration_smoke/chat_multi_forward_c2g_smoke_test.dart
//
// W3-K 本地冒烟锚（RUN_ID=chat-multi-20261111）——
// integration_test/chat_multi_forward_c2g_test.dart 的本地版：
// W1-B BatchForwardCoordinator 真调度（C2C + C2G 双目标、串行保序、
// 入口校验）+ W2-F 精确单元 key；fixtures 与真机版共享。

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/send_to/batch_forward_coordinator.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    // 钉住当前用户，uk3 才是确定值（与 W1-B 既有测试同口径）。
    await StorageService.to.setString(Keys.currentUid, '1000000051');
  });

  ConversationModel conv(String peerId, {String type = 'C2C', String? title}) =>
      ConversationModel(
        id: '$type$peerId'.hashCode,
        peerId: peerId,
        avatar: '',
        title: title ?? 'peer-$peerId',
        subtitle: '',
        type: type,
        msgType: 'text',
        unreadNum: 0,
      );

  /// fixtures standardSet（5 条：text/image/file/voice/text）→ 真实
  /// MessageModel（coordinator 输入契约）。
  List<MessageModel> models({required String uk3, required int baseMs}) {
    final msgs = ChatMultiMessageFixtures.standardSet(
      authorId: '1000000056',
      textMarker: 'w3k',
      baseTime: DateTime.fromMillisecondsSinceEpoch(baseMs),
    );
    return [
      for (final m in msgs)
        chatMultiMessageModel(
          m,
          chatType: 'C2C',
          fromUid: '1000000056',
          toUid: '1000000051',
          conversationUk3: uk3,
        ),
    ];
  }

  group('W3-K 冒烟 | BatchForwardCoordinator（设备旅程④的本地锚）', () {
    test('C2C + C2G 双目标：目标外层序 × 消息 createdAt 升序，全串行保序', () async {
      final c2c = conv('1000000056');
      final c2g = conv('110073884384167936', type: 'C2G', title: 'W3K-C2G');
      final msgs = models(uk3: c2c.uk3, baseMs: 1700000000000);

      final callLog = <String>[];
      final coordinator = BatchForwardCoordinator(
        forwardOne: (target, message, isCurrent) async {
          callLog.add('${target.uk3}:${message.id}');
          return true;
        },
      );
      addTearDown(coordinator.dispose);

      final report = await coordinator.run([c2c, c2g], msgs);
      expect(report.allSucceeded, isTrue, reason: '全成功路径');
      expect(report.totalCount, 10, reason: '2 目标 × 5 消息');

      // 目标外层序：C2C 的 5 个单元先于 C2G 的 5 个单元。
      expect(callLog.take(5).every((e) => e.startsWith(c2c.uk3)), isTrue);
      expect(callLog.skip(5).every((e) => e.startsWith(c2g.uk3)), isTrue);

      // 消息内层序：createdAt 旧→新（fixtures 构造即升序；输入侧已是升序
      // 时 coordinator 保持稳定序）。
      final c2cIds = callLog.take(5).map((e) => e.split(':')[1]).toList();
      expect(
        c2cIds,
        msgs.map((m) => m.id).toList(),
        reason: '同目标内消息顺序应与源选择一致（冻结合同 §4.3）',
      );

      // 单元 key = uk3 × sourceMessageId（仅失败重试的精确依据）。
      expect(
        report.results.every(
          (r) => r.key == unitKey(r.targetConversationUk3, r.sourceMessageId),
        ),
        isTrue,
      );
    });

    test('部分失败：失败单元精确入 retryableUnitKeys，成功单元不重复', () async {
      final target = conv('1000000056');
      final msgs = models(uk3: target.uk3, baseMs: 1700000001000);
      final attempted = <String>[]; // 调用流水（含重试），用 List 计次
      final attempts = <String, int>{};
      final coordinator = BatchForwardCoordinator(
        forwardOne: (target, message, isCurrent) async {
          attempted.add(message.id);
          // 文本单元首次模拟失败、重试成功（验证仅失败单元重试语义）。
          final n = (attempts[message.id] ?? 0) + 1;
          attempts[message.id] = n;
          return !(message.msgType == 'text' && n == 1);
        },
      );
      addTearDown(coordinator.dispose);

      final report = await coordinator.run([target], msgs);
      expect(report.failedCount, 2, reason: '2 条文本单元失败');
      expect(report.successCount, 3, reason: '附件类 3 条成功');
      expect(report.retryableUnitKeys.length, 2);

      // 精确重试：只重跑失败单元（冻结合同 §4.3）。
      final report2 = await coordinator.retryFailed(
        report,
        targets: [target],
        messages: msgs,
      );
      expect(
        report2.results.every((r) => r.status == ForwardUnitStatus.success),
        isTrue,
      );
      expect(report2.totalCount, 2, reason: '重试报告只覆盖失败单元');
      expect(report2.retryableUnitKeys, isEmpty, reason: '重试全成功后无可再试单元');
      expect(attempted.length, 7, reason: '首跑 5 + 重试 2，成功单元零重复');
    });

    test('入口校验：空消息/空目标/超 50 条/超 9 目标/重复目标（稳定错误码）', () {
      final target = conv('1000000056');
      final msgs = models(uk3: target.uk3, baseMs: 1700000002000);
      final msg0 = msgs.first;

      expect(validateBatch([], [msg0]), BatchForwardErrorCode.emptyTargets);
      expect(
        validateBatch([target], <MessageModel>[]),
        BatchForwardErrorCode.emptyMessages,
      );

      final tooManyMsgs = List.generate(
        51,
        (i) => MessageModel(
          'w3k-lim-$i',
          autoId: 0,
          type: 'C2C',
          status: 11,
          fromId: '1000000056',
          toId: '1000000051',
          payload: {'text': 'x'},
          isAuthor: 1,
          conversationUk3: target.uk3,
          msgType: 'text',
        ),
      );
      expect(
        validateBatch([target], tooManyMsgs),
        BatchForwardErrorCode.limitMessages,
        reason: '逐条转发上限 50（冻结合同 §4.2）',
      );

      // peerId 必须数字串（channelDecimalId 归一，非数字落 '0' 会撞 uk3）。
      final nineTargets = List.generate(9, (i) => conv('20000000$i'));
      expect(validateBatch(nineTargets, [msg0]), isNull, reason: '9 目标合法');
      final tenTargets = List.generate(10, (i) => conv('20000000$i'));
      expect(
        validateBatch(tenTargets, [msg0]),
        BatchForwardErrorCode.limitTargets,
        reason: '逐条转发目标上限 9（冻结合同 §4.2）',
      );

      expect(
        validateBatch([target, target], [msg0]),
        BatchForwardErrorCode.duplicateTargets,
      );
    });

    test('取消：未开始单元 skipped，已成功单元不回滚', () async {
      final target = conv('1000000056');
      final msgs = models(uk3: target.uk3, baseMs: 1700000003000);
      BatchForwardCoordinator? coordinatorRef;
      var cancelRequested = false;
      final coordinator = BatchForwardCoordinator(
        forwardOne: (target, message, isCurrent) async {
          // 第 1 条成功后立即请求取消：后续单元不得排入。
          if (!cancelRequested) {
            cancelRequested = true;
            coordinatorRef?.cancel();
          }
          return true;
        },
      );
      coordinatorRef = coordinator;
      addTearDown(coordinator.dispose);

      final report = await coordinator.run([target], msgs);
      expect(report.cancelled, isTrue);
      expect(report.successCount, 1, reason: '第 1 条已成功不回滚');
      expect(report.skippedCount, 4, reason: '未开始单元 skipped');
    });
  });
}
