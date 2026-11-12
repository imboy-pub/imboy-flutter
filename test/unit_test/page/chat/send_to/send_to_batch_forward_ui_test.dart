/// W2-F 批量逐条转发 UI 接线验收测试（chat_multi_select_v1）。
///
/// 覆盖冻结合同（PLAN chat-multi-20261111 §4.2/§4.3 + W1-B handoff）：
/// - 协调器输入转换（toCoordinatorMessageModels）：id/createdAt 映射；
/// - sendMsg 适配（forwardOneForBatch）：原 Message 同一性、isCurrent
///   闭包透传、查不到 id 按单元失败不崩溃；
/// - 协调器 × 适配层全链路：2 消息 × 2 目标顺序（fake sendMsg 注入）、
///   部分失败不回滚、仅失败重试精确（成功单元零重复）；
/// - SendToPage.batch 页面接线：全成功关页、进度卡、取消按钮、
///   部分失败汇总卡 + 仅重试失败、9/10 目标、51 条兜底拦截；
/// - 单条模式零回归（页面级）：默认构造 sendToSelected 路径与
///   onConfirmedSend 兼容路径行为不变。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show Message, TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/send_to/batch_forward_coordinator.dart';
import 'package:imboy/page/chat/send_to/send_to_page.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    // uk3 = C2C_<currentUid>_<peerId>，钉住当前用户才有确定值。
    await StorageService.to.setString(Keys.currentUid, '10001');
  });

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

  TextMessage chatMsg(String id, int createdAtMs) => TextMessage(
    id: id,
    authorId: '10001',
    text: 'text-$id',
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    metadata: const {'msg_type': 'text', 'conversation_uk3': 'C2C_10001_10002'},
  );

  group('toCoordinatorMessageModels（协调器输入转换）', () {
    test('id / createdAt 正确映射，保持传入顺序（旧→新重排是协调器职责）', () {
      final messages = [chatMsg('m2', 2000), chatMsg('m1', 1000)];
      final models = SendToNotifier.toCoordinatorMessageModels(messages);
      expect(models.map((m) => m.id).toList(), ['m2', 'm1']);
      expect(models.map((m) => m.createdAt).toList(), [2000, 1000]);
      expect(models.map((m) => m.msgType).toList(), ['text', 'text']);
    });

    test('createdAt 为 null → 0（不崩溃，排序退化为稳定传入序）', () {
      final m = TextMessage(id: 'n1', authorId: '10001', text: 'x');
      final models = SendToNotifier.toCoordinatorMessageModels([m]);
      expect(models.single.createdAt, 0);
    });

    test('metadata 缺 msg_type → 兜底 text（与单条转发同口径）', () {
      final m = TextMessage(
        id: 'n2',
        authorId: '10001',
        text: 'x',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      );
      final models = SendToNotifier.toCoordinatorMessageModels([m]);
      expect(models.single.msgType, 'text');
    });
  });

  group('forwardOneForBatch（sendMsg 适配）', () {
    test('按 id 取回原 Message（同一性）并透传 isCurrent 闭包语义', () async {
      final fake = _RecordingSendToNotifier();
      final m = chatMsg('m1', 1000);
      final model = SendToNotifier.toCoordinatorMessageModels([m]).single;

      final ok = await fake.forwardOneForBatch(
        conv('10002'),
        model,
        true,
        messagesById: {m.id: m},
      );

      expect(ok, isTrue);
      expect(fake.calls, hasLength(1));
      expect(fake.calls.single.$1, '10002');
      expect(
        identical(fake.calls.single.$2, m),
        isTrue,
        reason: 'sendMsg 必须收到原 flutter_chat Message 对象',
      );
      expect(fake.calls.single.$3, isTrue, reason: 'isCurrent() 即排入时的 bool');
    });

    test('查不到 id（接线错误防御）→ 本单元失败 false，不抛异常', () async {
      final fake = _RecordingSendToNotifier();
      final m = chatMsg('m1', 1000);
      final model = SendToNotifier.toCoordinatorMessageModels([m]).single;
      final ok = await fake.forwardOneForBatch(
        conv('10002'),
        model,
        true,
        messagesById: const {},
      );
      expect(ok, isFalse);
      expect(fake.calls, isEmpty);
    });
  });

  group('协调器 × 适配层全链路（fake sendMsg 注入）', () {
    BatchForwardCoordinator wired(
      _RecordingSendToNotifier fake,
      Map<String, Message> byId,
    ) => BatchForwardCoordinator(
      forwardOne: (target, message, isCurrent) => fake.forwardOneForBatch(
        target,
        message,
        isCurrent,
        messagesById: byId,
      ),
    );

    test('2 消息 × 2 目标：目标外层 × 消息 createdAt 升序（传入新→旧也要重排）', () async {
      final fake = _RecordingSendToNotifier();
      final messages = [chatMsg('m2', 2000), chatMsg('m1', 1000)];
      final byId = {for (final m in messages) m.id: m};
      final report = await wired(fake, byId).run([
        conv('10002'),
        conv('10003'),
      ], SendToNotifier.toCoordinatorMessageModels(messages));

      expect(fake.calls.map((c) => '${c.$1}/${c.$2.id}').toList(), [
        '10002/m1',
        '10002/m2',
        '10003/m1',
        '10003/m2',
      ]);
      expect(report.successCount, 4);
      expect(fake.calls.every((c) => c.$3), isTrue);
      // W5 G4-9：批量路径（forwardOneForBatch → sendMsg）必须全部静默。
      expect(fake.silentCalls, fake.calls.length);
    });

    test('部分失败不回滚：失败单元标记、后续继续；仅重试失败单元，成功单元零重复', () async {
      final fake = _RecordingSendToNotifier()..failUnits.add('10003/m1');
      final messages = [chatMsg('m1', 1000), chatMsg('m2', 2000)];
      final byId = {for (final m in messages) m.id: m};
      final coordinator = wired(fake, byId);
      final report = await coordinator.run([
        conv('10002'),
        conv('10003'),
      ], SendToNotifier.toCoordinatorMessageModels(messages));

      expect(fake.calls, hasLength(4), reason: '失败不中断整批');
      expect(report.successCount, 3);
      expect(report.failedCount, 1);

      fake.failUnits.clear(); // 重试时故障恢复
      final callsBeforeRetry = fake.calls.length;
      final retryReport = await coordinator.retryFailed(
        report,
        targets: [conv('10002'), conv('10003')],
        messages: SendToNotifier.toCoordinatorMessageModels(messages),
      );

      expect(fake.calls.length, callsBeforeRetry + 1, reason: '只重调失败单元');
      expect(fake.calls.last.$1, '10003');
      expect(fake.calls.last.$2.id, 'm1');
      expect(retryReport.successCount, 1);
      expect(retryReport.totalCount, 1);
    });
  });

  group('SendToPage.batch 页面接线', () {
    testWidgets('全成功：2 消息 × 2 目标顺序正确，复用 forwardedToChats 文案并关页', (
      tester,
    ) async {
      final fake = _RecordingSendToNotifier()
        ..conversations = [conv('10002'), conv('10003')];
      final messages = [chatMsg('m2', 2000), chatMsg('m1', 1000)];
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage.batch(messages: messages),
      );

      await tester.tap(find.text('peer-10002'));
      await tester.tap(find.text('peer-10003'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();

      expect(fake.calls.map((c) => '${c.$1}/${c.$2.id}').toList(), [
        '10002/m1',
        '10002/m2',
        '10003/m1',
        '10003/m2',
      ]);
      expect(
        find.text(t.chat.forwardedToChats(count: fake.calls.length ~/ 2)),
        findsOneWidget,
        reason: '全成功沿用既有 forwardedToChats 文案',
      );
      expect(find.text('home-marker'), findsOneWidget, reason: '全成功自动关页');
    });

    testWidgets('部分失败：留页展示汇总卡；「仅重试失败」精确，成功单元零重复', (tester) async {
      final fake = _RecordingSendToNotifier()
        ..conversations = [conv('10002'), conv('10003')]
        ..failUnits.add('10003/m1');
      final messages = [chatMsg('m1', 1000), chatMsg('m2', 2000)];
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage.batch(messages: messages),
      );

      await tester.tap(find.text('peer-10002'));
      await tester.tap(find.text('peer-10003'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(4));
      expect(find.text('peer-10002'), findsOneWidget, reason: '有失败不关页');
      expect(
        find.text(t.chat.batchForwardDone(success: 3, failed: 1)),
        findsWidgets,
        reason: '汇总卡按整批口径合并展示（toast 同文案并存的元素 ≥1 即可）',
      );
      expect(find.text(t.chat.batchForwardRetryFailed), findsOneWidget);

      fake.failUnits.clear(); // 重试时故障恢复
      await tester.tap(find.text(t.chat.batchForwardRetryFailed));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(5), reason: '只重调 10003/m1 一个单元');
      expect(fake.calls.last.$1, '10003');
      expect(fake.calls.last.$2.id, 'm1');
      expect(find.text('home-marker'), findsOneWidget, reason: '重试全成后关页');
    });

    testWidgets('执行中展示进度卡（已完成/总数）；取消停排新单元，已成功不回滚', (tester) async {
      final gate = Completer<void>();
      final fake = _RecordingSendToNotifier()
        ..conversations = [conv('10002')]
        ..holdGate = gate;
      final messages = [chatMsg('m1', 1000), chatMsg('m2', 2000)];
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage.batch(messages: messages),
      );

      await tester.tap(find.text('peer-10002'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pump();

      expect(
        find.text(t.chat.batchForwardProgress(completed: 0, total: 2)),
        findsOneWidget,
        reason: '首单元在途时进度卡按 0/2 展示',
      );
      expect(find.text(t.common.cancel), findsOneWidget, reason: '执行中按钮变取消');

      await tester.tap(find.text(t.common.cancel));
      gate.complete(); // 在途单元继续完成（返回 true = 已成功不回滚）
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1), reason: '取消后不再排入第 2 个单元');
      expect(find.text('peer-10002'), findsOneWidget, reason: '有未完成单元不关页');
      expect(
        find.text(t.chat.batchForwardRetryFailed),
        findsNothing,
        reason: 'skipped 单元不可重试，无重试按钮',
      );
    });

    testWidgets('9/10 目标边界：第 10 个拒绝选择，发送只覆盖 9 个目标', (tester) async {
      final fake = _RecordingSendToNotifier()
        ..conversations = [for (var i = 1; i <= 10; i++) conv('${20000 + i}')];
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage.batch(messages: [chatMsg('m1', 1000)]),
      );

      for (var i = 1; i <= 10; i++) {
        // 测试视口一次放不下 10 行，先滚动到位再点。
        final row = find.text('peer-${20000 + i}');
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pump();
      }
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(9), reason: '第 10 个目标被拒绝，未进整批');
      expect(fake.calls.map((c) => c.$1).toSet().contains('20010'), isFalse);
      expect(find.text('home-marker'), findsOneWidget);
    });

    testWidgets('51 条消息：确认时按 batch_limit_messages 兜底拦截，零发送', (tester) async {
      final fake = _RecordingSendToNotifier()..conversations = [conv('10002')];
      final messages = [for (var i = 0; i < 51; i++) chatMsg('m$i', 1000 + i)];
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage.batch(messages: messages),
      );

      await tester.tap(find.text('peer-10002'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty, reason: '超限在确认时被兜底拦截，sendMsg 零调用');
      expect(find.text('peer-10002'), findsOneWidget, reason: '页面保留');
      expect(
        find.text(t.chat.batchForwardRetryFailed),
        findsNothing,
        reason: '未产生任何单元结果，无重试入口',
      );
    });

    testWidgets('W5 G4-4：send 路径抛 StateError（协调器透传 Error）→ 按钮状态恢复，不卡「取消」', (
      tester,
    ) async {
      final fake = _RecordingSendToNotifier()
        ..conversations = [conv('10002')]
        ..errorUnits.add('10002/m1');
      final messages = [chatMsg('m1', 1000), chatMsg('m2', 2000)];
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage.batch(messages: messages),
      );

      await tester.tap(find.text('peer-10002'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      // StateError 在纯 microtask 链内即传播完毕（无真实计时器），
      // 首帧 pump 后即处于「已捕获 + 已复位」的终态。
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1), reason: '首个单元已进入 send 路径并抛 StateError');
      // 关键断言：_runBatchSafely 的 finally 复位 _batchRunning，
      // Error 逃逸不再让按钮永久卡在「取消」态。
      expect(find.text(t.common.cancel), findsNothing, reason: '按钮已离开取消态');
      expect(find.text(t.common.buttonSend), findsOneWidget, reason: '按钮回到发送态');
      expect(find.text('peer-10002'), findsOneWidget, reason: '页面保留');
      expect(
        find.text(t.chat.batchForwardRetryFailed),
        findsNothing,
        reason: 'crash 路径无单元报告，不出现重试入口',
      );
    });
  });

  group('单条模式零回归（页面级）', () {
    testWidgets('默认构造 msg：sendToSelected 单条 × 多目标，全成提示并关页', (tester) async {
      final fake = _RecordingSendToNotifier()
        ..conversations = [conv('10002'), conv('10003')];
      final msg = chatMsg('only', 1000);
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage(msg: msg),
      );

      await tester.tap(find.text('peer-10002'));
      await tester.tap(find.text('peer-10003'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();

      expect(fake.calls.map((c) => c.$1).toList(), ['10002', '10003']);
      expect(fake.calls.every((c) => identical(c.$2, msg)), isTrue);
      // W5 G4-9 回归锚：单条路径保持默认非静默（失败 toast 行为零变化）。
      expect(fake.silentCalls, 0);
      expect(
        find.text(t.chat.forwardedToChats(count: 2)),
        findsOneWidget,
        reason: '单条多目标沿用既有文案',
      );
      expect(find.text('home-marker'), findsOneWidget);
    });

    testWidgets('onConfirmedSend 兼容：回调收到目标列表，页面以结果关页', (tester) async {
      final fake = _RecordingSendToNotifier()..conversations = [conv('10002')];
      List<ConversationModel>? captured;
      await _pumpSendTo(
        tester,
        notifier: fake,
        page: SendToPage(
          msg: chatMsg('only', 1000),
          onConfirmedSend: (targets) async {
            captured = targets;
            return true;
          },
        ),
      );

      await tester.tap(find.text('peer-10002'));
      await tester.pump();
      await tester.tap(find.text(t.common.buttonSend));
      await tester.pumpAndSettle();

      expect(captured, hasLength(1));
      expect(captured!.single.peerId, '10002');
      expect(fake.calls, isEmpty, reason: 'onConfirmedSend 路径不调 sendMsg');
      expect(find.text('home-marker'), findsOneWidget);
    });

    testWidgets(
      'S1-L3：bundle 模式（onConfirmedSend）9/10 目标闸生效：第 10 个拒绝选择，仅 9 目标进入合并转发',
      (tester) async {
        final fake = _RecordingSendToNotifier()
          ..conversations = [
            for (var i = 1; i <= 10; i++) conv('${20000 + i}'),
          ];
        List<ConversationModel>? captured;
        await _pumpSendTo(
          tester,
          notifier: fake,
          page: SendToPage(
            msg: chatMsg('only', 1000),
            enforceTargetLimit: true,
            onConfirmedSend: (targets) async {
              captured = targets;
              return true;
            },
          ),
        );

        for (var i = 1; i <= 10; i++) {
          // 测试视口一次放不下 10 行，先滚动到位再点。
          final row = find.text('peer-${20000 + i}');
          await tester.ensureVisible(row);
          await tester.tap(row);
          await tester.pump();
        }
        await tester.tap(find.text(t.common.buttonSend));
        await tester.pumpAndSettle();

        expect(captured, hasLength(9), reason: '第 10 个目标被拒绝选择，未进合并转发');
        expect(
          captured!.map((c) => c.peerId).toSet().contains('20010'),
          isFalse,
          reason: '被拒的第 10 个会话不出现在目标列表',
        );
        expect(find.text('home-marker'), findsOneWidget);
      },
    );
  });
}

/// 真实 SendToNotifier 的可注入替身：只覆写 sendMsg / conversationsList，
/// 其余（含 W2-F 的 forwardOneForBatch）全部走生产实现。
class _RecordingSendToNotifier extends SendToNotifier {
  List<ConversationModel> conversations = const [];

  /// `peerId/messageId` 集合：命中的单元 sendMsg 返回 false。
  final Set<String> failUnits = {};

  /// `peerId/messageId` 集合：命中的单元 sendMsg 抛 StateError
  /// （W5 G4-4：Error 不被协调器的 on Exception 捕获，会透传到页面层）。
  final Set<String> errorUnits = {};

  /// 非空时，下一次 sendMsg 调用先等待该 gate（用于观察执行中 UI）。
  Completer<void>? holdGate;

  /// sendMsg 收到 silent=true 的调用次数（W5 G4-9：批量路径必须静默）。
  int silentCalls = 0;

  /// 每次真实 sendMsg 调用：(目标 peerId, 原消息对象, 调用时 isCurrent())。
  final List<(String, Message, bool)> calls = [];

  @override
  Future<void> conversationsList() async {
    state = state.copyWith(
      conversations: conversations,
      searchResults: List<ConversationModel>.from(conversations),
    );
  }

  @override
  Future<bool> sendMsg(
    ConversationModel conversation,
    Message msg, {
    void Function(MessageModel)? onQueued,
    bool Function()? isCurrent,
    bool silent = false,
  }) async {
    calls.add((conversation.peerId, msg, isCurrent?.call() ?? true));
    if (silent) silentCalls++;
    if (errorUnits.contains('${conversation.peerId}/${msg.id}')) {
      throw StateError('injected state error');
    }
    final gate = holdGate;
    if (gate != null) {
      holdGate = null;
      await gate.future;
    }
    return !failUnits.contains('${conversation.peerId}/${msg.id}');
  }
}

/// 以 /send_to 路由挂载页面（context.pop 需要 GoRouter 且栈下要有一个
/// 可返回的路由），并注入替身 provider。
Future<void> _pumpSendTo(
  WidgetTester tester, {
  required SendToPage page,
  required SendToNotifier notifier,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('home-marker'))),
      ),
      GoRoute(path: '/send_to', builder: (_, _) => page),
    ],
  );
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [sendToProvider.overrideWith(() => notifier)],
        child: MaterialApp.router(
          routerConfig: router,
          builder: AppLoading.init(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/send_to');
  await tester.pumpAndSettle();
}
