/// W1-B BatchForwardCoordinator 验收测试（chat_multi_select_v1）。
///
/// 覆盖冻结合同（PLAN chat-multi-20261111 §4.2/§4.3）：
/// - 2 消息 × 2 目标调用顺序精确匹配（目标外层 × createdAt 升序内层）；
/// - 相同 createdAt 按传入列表稳定顺序；
/// - 部分失败：失败单元标记 failed，后续单元继续执行；
/// - cancel()：不再调用 forwardOne，未开始单元 skipped，已成功不回滚；
/// - dispose()：停止排入新单元，之后 run 抛稳定码；
/// - retryFailed()：只重调失败单元、顺序稳定、成功单元零重复、attempt 递增；
/// - 50/51 消息、9/10 目标边界；
/// - forwardOne 抛异常按单元失败隔离；
/// - onProgress 进度序列。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/send_to/batch_forward_coordinator.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    // 钉住当前用户，uk3 才是确定值：C2C_10001_<peerId>。
    await StorageService.to.setString(Keys.currentUid, '10001');
  });

  // 目标会话：peerId 唯一 → uk3 唯一。
  ConversationModel conv(String peerId) => ConversationModel(
    id: peerId.hashCode,
    peerId: peerId,
    avatar: '',
    title: 'peer-$peerId',
    subtitle: '',
    type: 'C2C',
    msgType: 'text',
    unreadNum: 0,
  );

  MessageModel msg(String id, int createdAt) => MessageModel(
    id,
    autoId: 0,
    type: 'C2C',
    status: 21,
    fromId: '10001',
    toId: '10002',
    payload: <String, dynamic>{'text': id},
    isAuthor: 0,
    conversationUk3: 'C2C_10001_10002',
    createdAt: createdAt,
    msgType: 'text',
  );

  // 标准夹具：2 目标 × 2 消息（故意按新到旧传入，验证排序）。
  final t1 = conv('10002'); // uk3 = C2C_10001_10002
  final t2 = conv('10003'); // uk3 = C2C_10001_10003
  final m1 = msg('m1', 1000); // 旧
  final m2 = msg('m2', 2000); // 新

  BatchForwardCoordinator coordinatorWith(
    Future<bool> Function(
      ConversationModel target,
      MessageModel message,
      bool isCurrent,
    )
    forwardOne, {
    BatchForwardProgressFn? onProgress,
  }) => BatchForwardCoordinator(forwardOne: forwardOne, onProgress: onProgress);

  group('validateBatch 边界（§4.2）', () {
    test('9 目标 × 50 消息合法', () {
      final targets = List.generate(9, (i) => conv('${20000 + i}'));
      final messages = List.generate(50, (i) => msg('m$i', 1000 + i));
      expect(validateBatch(targets, messages), isNull);
    });

    test('10 目标 → batch_limit_targets', () {
      final targets = List.generate(10, (i) => conv('${30000 + i}'));
      expect(validateBatch(targets, [m1]), BatchForwardErrorCode.limitTargets);
    });

    test('51 消息 → batch_limit_messages', () {
      final messages = List.generate(51, (i) => msg('m$i', 1000 + i));
      expect(
        validateBatch([t1], messages),
        BatchForwardErrorCode.limitMessages,
      );
    });

    test('空目标 / 空消息', () {
      expect(
        validateBatch(<ConversationModel>[], [m1]),
        BatchForwardErrorCode.emptyTargets,
      );
      expect(
        validateBatch([t1], <MessageModel>[]),
        BatchForwardErrorCode.emptyMessages,
      );
    });

    test('重复目标 uk3 / 重复消息 id → 防御性拒绝', () {
      expect(
        validateBatch([conv('10002'), conv('10002')], [m1]),
        BatchForwardErrorCode.duplicateTargets,
      );
      expect(
        validateBatch([t1], [msg('dup', 1), msg('dup', 2)]),
        BatchForwardErrorCode.duplicateMessages,
      );
    });
  });

  group('run 执行顺序（§4.3 全串行）', () {
    test('2 消息 × 2 目标：调用顺序精确匹配（目标外层 × 消息时间升序内层）', () async {
      final calls = <String>[];
      final c = coordinatorWith((target, message, isCurrent) async {
        expect(isCurrent, isTrue, reason: '正常运行时 isCurrent 应为 true');
        calls.add('${target.peerId}/${message.id}');
        return true;
      });
      // 消息按新到旧传入，协调器必须重排为旧到新。
      final report = await c.run([t1, t2], [m2, m1]);

      expect(calls, ['10002/m1', '10002/m2', '10003/m1', '10003/m2']);
      expect(report.totalCount, 4);
      expect(report.successCount, 4);
      expect(report.failedCount, 0);
      expect(report.cancelled, isFalse);
      expect(report.allSucceeded, isTrue);
      expect(report.retryableUnitKeys, isEmpty);
      // 报告结果顺序 = 执行顺序。
      expect(
        report.results
            .map((r) => '${r.targetConversationUk3}/${r.sourceMessageId}')
            .toList(),
        [
          'C2C_10001_10002/m1',
          'C2C_10001_10002/m2',
          'C2C_10001_10003/m1',
          'C2C_10001_10003/m2',
        ],
      );
      expect(report.results.first.attempt, 1);
    });

    test('相同 createdAt 按传入列表稳定顺序', () async {
      final calls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        return true;
      });
      final b = msg('b-tie', 5000);
      final a = msg('a-tie', 5000);
      await c.run([t1], [b, a]);
      expect(calls, ['10002/b-tie', '10002/a-tie']);
    });
  });

  group('部分失败', () {
    test('第 3 单元失败：前 2 单元 success、后续继续执行、失败单元可重试', () async {
      final calls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        return calls.length != 3; // 第 3 次（t2×m1）失败
      });
      final report = await c.run([t1, t2], [m1, m2]);

      expect(calls, hasLength(4), reason: '失败不中断整批');
      expect(report.results.map((r) => r.status).toList(), [
        ForwardUnitStatus.success,
        ForwardUnitStatus.success,
        ForwardUnitStatus.failed,
        ForwardUnitStatus.success,
      ]);
      final failed = report.results[2];
      expect(failed.targetConversationUk3, 'C2C_10001_10003');
      expect(failed.sourceMessageId, 'm1');
      expect(failed.errorCode, BatchForwardErrorCode.forwardFailed);
      expect(failed.attempt, 1);
      expect(report.retryableUnitKeys, {failed.key});
      expect(report.allSucceeded, isFalse);
    });

    test('forwardOne 抛 Exception：按单元失败隔离，后续单元继续', () async {
      final calls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        if (calls.length == 2) throw Exception('boom');
        return true;
      });
      final report = await c.run([t1, t2], [m1, m2]);

      expect(calls, hasLength(4));
      expect(report.results[1].status, ForwardUnitStatus.failed);
      expect(report.results[1].errorCode, BatchForwardErrorCode.forwardFailed);
      expect(report.successCount, 3);
      expect(report.failedCount, 1);
    });
  });

  group('cancel', () {
    test('执行中 cancel：已成功不回滚、未开始 skipped、不再调用 forwardOne', () async {
      final calls = <String>[];
      late final BatchForwardCoordinator c;
      c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        if (calls.length == 3) c.cancel();
        return true; // 第 3 单元已真实完成，保持 success
      });
      final report = await c.run([t1, t2], [m1, m2]);

      expect(calls, ['10002/m1', '10002/m2', '10003/m1']);
      expect(report.cancelled, isTrue);
      expect(
        report.results[2].status,
        ForwardUnitStatus.success,
        reason: '已成功单元不回滚',
      );
      final skipped = report.results[3];
      expect(skipped.status, ForwardUnitStatus.skipped);
      expect(skipped.errorCode, BatchForwardErrorCode.batchCancelled);
      expect(skipped.attempt, 0, reason: '从未排入执行');
      expect(report.successCount, 3);
      expect(report.skippedCount, 1);
    });

    test('cancel 后 in-flight 返回 false：该单元标记 cancelled', () async {
      final calls = <String>[];
      late final BatchForwardCoordinator c;
      c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        if (calls.length == 3) {
          c.cancel();
          return false; // 适配层因会话切换提前退出
        }
        return true;
      });
      final report = await c.run([t1, t2], [m1, m2]);

      expect(calls, hasLength(3));
      expect(report.results[2].status, ForwardUnitStatus.cancelled);
      expect(
        report.results[2].errorCode,
        BatchForwardErrorCode.forwardCancelled,
      );
      expect(report.results[3].status, ForwardUnitStatus.skipped);
      // cancelled/skipped 均不可重试（重试只包含 failed 单元）。
      expect(report.retryableUnitKeys, isEmpty);
    });
  });

  group('dispose（页面销毁/会话切换防护）', () {
    test('执行中 dispose：停止排入新单元，剩余单元 skipped/coordinator_disposed', () async {
      final calls = <String>[];
      late final BatchForwardCoordinator c;
      c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        if (calls.length == 2) c.dispose();
        return true;
      });
      final report = await c.run([t1, t2], [m1, m2]);

      expect(calls, ['10002/m1', '10002/m2']);
      expect(report.results[1].status, ForwardUnitStatus.success);
      expect(report.results[2].status, ForwardUnitStatus.skipped);
      expect(
        report.results[2].errorCode,
        BatchForwardErrorCode.coordinatorDisposed,
      );
      expect(report.results[3].status, ForwardUnitStatus.skipped);
      expect(report.cancelled, isFalse, reason: 'dispose 中止不置 cancelled 标志');
    });

    test('dispose 后 run：抛稳定码且不调用 forwardOne', () async {
      final calls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        return true;
      });
      c.dispose();
      await expectLater(
        c.run([t1], [m1]),
        throwsA(
          isA<BatchForwardException>().having(
            (e) => e.code,
            'code',
            BatchForwardErrorCode.coordinatorDisposed,
          ),
        ),
      );
      expect(calls, isEmpty);
    });
  });

  group('retryFailed（重试只包含失败单元）', () {
    test('只重调失败单元：顺序稳定、attempt 递增、成功单元零重复', () async {
      final firstCalls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        firstCalls.add('${target.peerId}/${message.id}');
        return firstCalls.length != 3; // t2×m1 失败
      });
      final report = await c.run([t1, t2], [m1, m2]);
      expect(report.failedCount, 1);

      // 换一个记录器观察重试阶段。
      final retryCalls = <String>[];
      final c2 = coordinatorWith((target, message, _) async {
        retryCalls.add('${target.peerId}/${message.id}');
        return true;
      });
      final retryReport = await c2.retryFailed(
        report,
        targets: [t1, t2],
        messages: [m1, m2],
      );

      expect(retryCalls, ['10003/m1'], reason: '只重调失败单元，成功单元零重复');
      expect(retryReport.totalCount, 1);
      expect(retryReport.results.first.status, ForwardUnitStatus.success);
      expect(retryReport.results.first.attempt, 2, reason: '第二次尝试');
      expect(retryReport.retryableUnitKeys, isEmpty);
    });

    test('多个失败单元：保持原排序规则（目标外层 × 消息升序内层）', () async {
      final firstCalls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        firstCalls.add('${target.peerId}/${message.id}');
        // u2=(t1,m2) 与 u3=(t2,m1) 失败。
        return firstCalls.length != 2 && firstCalls.length != 3;
      });
      final report = await c.run([t1, t2], [m1, m2]);
      expect(report.failedCount, 2);

      final retryCalls = <String>[];
      final c2 = coordinatorWith((target, message, _) async {
        retryCalls.add('${target.peerId}/${message.id}');
        return true;
      });
      final retryReport = await c2.retryFailed(
        report,
        targets: [t1, t2],
        messages: [m1, m2],
      );

      expect(retryCalls, ['10002/m2', '10003/m1']);
      expect(retryReport.totalCount, 2);
      expect(retryReport.results.every((r) => r.attempt == 2), isTrue);
    });

    test('W5 G4-8：retryableUnitKeys 不可变（外部不得原地增删重试集合）', () async {
      final c = coordinatorWith((target, message, _) async => false);
      final report = await c.run([t1], [m1]);
      expect(report.failedCount, 1);
      expect(
        () => report.retryableUnitKeys.add('tampered-key'),
        throwsUnsupportedError,
        reason: 'report 是跨回调的结果快照，集合加不可变壳与 results 同口径',
      );
      expect(report.retryableUnitKeys, {
        unitKey(t1.uk3, 'm1'),
      }, reason: '原有内容不受篡改尝试影响');
    });

    test('无可重试单元：零调用、空报告', () async {
      final c = coordinatorWith((target, message, _) async => true);
      final report = await c.run([t1, t2], [m1, m2]);
      expect(report.retryableUnitKeys, isEmpty);

      final retryCalls = <String>[];
      final c2 = coordinatorWith((target, message, _) async {
        retryCalls.add('${target.peerId}/${message.id}');
        return true;
      });
      final retryReport = await c2.retryFailed(
        report,
        targets: [t1, t2],
        messages: [m1, m2],
      );
      expect(retryCalls, isEmpty);
      expect(retryReport.totalCount, 0);
    });

    test('传入列表覆盖不了失败单元 → batch_retry_units_mismatch', () async {
      final firstCalls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        firstCalls.add('${target.peerId}/${message.id}');
        return false; // 全部失败
      });
      final report = await c.run([t1], [m1]);

      final otherMessage = msg('other', 9000);
      final c2 = coordinatorWith((target, message, _) async => true);
      await expectLater(
        c2.retryFailed(report, targets: [t1], messages: [otherMessage]),
        throwsA(
          isA<BatchForwardException>().having(
            (e) => e.code,
            'code',
            BatchForwardErrorCode.retryUnitsMismatch,
          ),
        ),
      );
    });
  });

  group('run 入口校验与并发防护', () {
    test('51 条消息 run 抛 batch_limit_messages 且不调用 forwardOne', () async {
      final calls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        return true;
      });
      final messages = List.generate(51, (i) => msg('m$i', 1000 + i));
      await expectLater(
        c.run([t1], messages),
        throwsA(
          isA<BatchForwardException>().having(
            (e) => e.code,
            'code',
            BatchForwardErrorCode.limitMessages,
          ),
        ),
      );
      expect(calls, isEmpty);
    });

    test('10 个目标 run 抛 batch_limit_targets', () async {
      final calls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        return true;
      });
      final targets = List.generate(10, (i) => conv('${40000 + i}'));
      await expectLater(
        c.run(targets, [m1]),
        throwsA(
          isA<BatchForwardException>().having(
            (e) => e.code,
            'code',
            BatchForwardErrorCode.limitTargets,
          ),
        ),
      );
      expect(calls, isEmpty);
    });

    test('上一轮未结束时再次 run → batch_already_running', () async {
      final gate = Completer<void>();
      final calls = <String>[];
      final c = coordinatorWith((target, message, _) async {
        calls.add('${target.peerId}/${message.id}');
        if (calls.length == 1) await gate.future;
        return true;
      });
      final first = c.run([t1, t2], [m1, m2]);
      await Future<void>.delayed(Duration.zero); // 让首个单元挂起
      await expectLater(
        c.run([t1], [m1]),
        throwsA(
          isA<BatchForwardException>().having(
            (e) => e.code,
            'code',
            BatchForwardErrorCode.alreadyRunning,
          ),
        ),
      );
      gate.complete();
      final report = await first;
      expect(report.successCount, 4);
    });

    test('run 结束后可复用；残留 cancel 标志被新一轮清零', () async {
      var calls = 0;
      final c = coordinatorWith((target, message, _) async {
        calls++;
        return true;
      });
      await c.run([t1], [m1]);
      c.cancel(); // 迟到的取消不应影响下一轮
      final report2 = await c.run([t1], [m1]);
      expect(calls, 2);
      expect(report2.cancelled, isFalse);
      expect(report2.successCount, 1);
    });
  });

  group('onProgress', () {
    test('每个单元（含 skipped）触发一次，completed/total 单调', () async {
      final progress = <(int, int, ForwardUnitStatus)>[];
      late final BatchForwardCoordinator c;
      c = coordinatorWith(
        (target, message, _) async {
          if (target.peerId == '10003' && message.id == 'm1') {
            c.cancel();
            return true;
          }
          return true;
        },
        onProgress: (completed, total, lastResult) =>
            progress.add((completed, total, lastResult.status)),
      );
      final report = await c.run([t1, t2], [m1, m2]);

      expect(progress, [
        (1, 4, ForwardUnitStatus.success),
        (2, 4, ForwardUnitStatus.success),
        (3, 4, ForwardUnitStatus.success),
        (4, 4, ForwardUnitStatus.skipped),
      ]);
      expect(report.cancelled, isTrue);
    });
  });
}
