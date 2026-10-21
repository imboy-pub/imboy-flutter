/// T09 录音条 widget 测试：状态机呈现（录制/暂停/中断/空间不足）、
/// 重点标记、结束确认、收起不自动结束、无麦克风权限视图无副作用。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/talk_record_recorder/talk_record_recorder_bar.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';

import 'fake_talk_record_engine.dart';

void main() {
  late Directory baseDir;
  late FakeTalkRecordEngine engine;
  late FakeDiskSpaceProbe diskProbe;
  late FakeInterruptionSource interruptionSource;

  setUp(() {
    baseDir = Directory.systemTemp.createTempSync('t09_widget');
    engine = FakeTalkRecordEngine();
    diskProbe = FakeDiskSpaceProbe();
    interruptionSource = FakeInterruptionSource();
    TalkRecordCaptureLease.resetForTest();
  });

  tearDown(() {
    TalkRecordCaptureLease.resetForTest();
    if (baseDir.existsSync()) baseDir.deleteSync(recursive: true);
  });

  TalkRecordRecorderService newService() {
    return TalkRecordRecorderService(
      baseDirectory: baseDir,
      engine: engine,
      keyStore: MemoryTalkRecordKeyStore(),
      diskProbe: diskProbe,
      interruptionSource: interruptionSource,
      config: const TalkRecordRecorderConfig(
        segmentTargetMs: 1000,
        maxDurationMs: 10000,
        minFreeDiskBytesPerSegment: 1,
      ),
    );
  }

  /// 真实文件 IO（manifest/密文落盘）在 FakeAsync 下不会自行完成，
  /// 会话侧操作统一经 [tester.runAsync] 驱动（真实事件循环），UI 断言
  /// 回到 fake 侧 pump。
  Future<void> drive(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    var completed = false;
    Object? failure;
    StackTrace? failureStack;
    await tester.runAsync(() async {
      unawaited(
        Future<void>.sync(action).then<void>(
          (_) => completed = true,
          onError: (Object error, StackTrace stack) {
            failure = error;
            failureStack = stack;
            completed = true;
          },
        ),
      );
    });
    // UI callbacks may have enqueued controls in FakeAsync. Do not await a
    // real-I/O control while preventing those queued microtasks from running.
    for (var round = 0; !completed && round < 250; round++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(completed, isTrue, reason: 'Recorder control did not complete');
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }

  /// tap 全链路：手势竞技场与每个 IO 阶段的续体都在 fake zone 微任务里，
  /// 而文件 IO 完成回调在真实事件循环——两者必须交替冲刷：
  /// pump（fake 微任务→onTap/续体启动 IO）↔ runAsync（真实循环完成 IO
  /// →fake 微任务排队）×若干轮，最后统一 settle。
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
    }
    await tester.pumpAndSettle();
  }

  /// pump 先行的交替冲刷，直到条件满足（服务内部状态/快照收敛）。
  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    var rounds = 0;
    while (!done() && rounds++ < 80) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
    }
    expect(done(), isTrue, reason: 'Recorder state did not converge');
    await tester.pumpAndSettle();
  }

  Future<TalkRecordRecorderService> pumpRecording(
    WidgetTester tester, {
    bool initiallyCollapsed = false,
    ValueChanged<TalkRecordSessionResult>? onEnded,
  }) async {
    // The service's control queue is created in the same real async zone as
    // start. Constructing it in FakeAsync then awaiting its initial Future from
    // runAsync would wait forever for an unpumped fake-zone microtask.
    final svc = (await tester.runAsync(() async {
      final service = newService();
      await service.start(recordLocalId: 'rec-1', clientRecordingId: 'crid-1');
      return service;
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TalkRecordRecorderBar(
              controller: svc,
              initiallyCollapsed: initiallyCollapsed,
              onEnded: onEnded,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return svc;
  }

  testWidgets('录制态：计时/状态/电平，暂停不计时，继续恢复', (tester) async {
    final svc = await pumpRecording(tester);
    expect(find.text('正在录音 · 本机分段保存'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    await drive(tester, () async => engine.tick(1100, decibels: -10));
    // Segment sealing uses real file I/O; wait for the observable duration
    // rather than assuming 30ms suffices under concurrent module tests.
    await settleUntil(tester, () => svc.snapshot.effectiveDurationMs >= 1100);
    expect(find.text('00:01'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const ValueKey('trr_btn_pause')));
    await settleUntil(
      tester,
      () => find.text('已暂停，不计入录音时长').evaluate().length == 1,
    );
    expect(svc.phase, TalkRecordRecorderPhase.paused);
    expect(find.text('已暂停，不计入录音时长'), findsOneWidget);
    expect(find.text('00:01'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const ValueKey('trr_btn_resume')));
    expect(svc.phase, TalkRecordRecorderPhase.recording);
    await drive(tester, () async => engine.tick(500));
    await tester.pump();
    expect(find.text('00:01'), findsOneWidget); // 1600ms → 00:01
    expect(find.text('本机分段 1'), findsOneWidget);
    await drive(tester, svc.end);
  });

  testWidgets('中断态：持久原因横幅，用户点击继续', (tester) async {
    final svc = await pumpRecording(tester);
    await drive(tester, () async {
      engine.tick(300);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      interruptionSource.interrupt('audio_interruption');
    });
    await settleUntil(
      tester,
      () => find.textContaining('录音已中断：来电或系统占用麦克风').evaluate().isNotEmpty,
    );

    expect(svc.phase, TalkRecordRecorderPhase.interrupted);
    expect(find.textContaining('录音已中断：来电或系统占用麦克风'), findsWidgets);
    // 中断横幅的继续按钮。
    await tapAndSettle(tester, find.text('点击继续'));
    expect(svc.phase, TalkRecordRecorderPhase.recording);
    await drive(tester, svc.end);
  });

  testWidgets('重点标记：点击写本地并计数', (tester) async {
    final svc = await pumpRecording(tester);
    await drive(tester, () async => engine.tick(1500));
    await tester.pump();

    await tapAndSettle(tester, find.byKey(const ValueKey('trr_btn_mark')));
    await settleUntil(tester, () => find.text('1 个重点').evaluate().length == 1);
    expect(find.text('1 个重点'), findsOneWidget);
    expect(svc.snapshot.markCount, 1);
    expect(svc.snapshot.effectiveDurationMs, 1500);
    await drive(tester, svc.end);
  });

  testWidgets('结束确认弹窗：取消继续录，确认后结束', (tester) async {
    final svc = await pumpRecording(tester);

    await drive(tester, () async => engine.tick(700));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('trr_btn_end')));
    await tester.pumpAndSettle();
    expect(find.text('结束并保存'), findsWidgets); // 弹窗标题/按钮

    await tapAndSettle(tester, find.text('继续录制'));
    expect(svc.phase, TalkRecordRecorderPhase.recording); // 取消不动会话

    await tester.tap(find.byKey(const ValueKey('trr_btn_end')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束并保存').last);
    // 轮询最终快照（end() 全链含封段/清单/teardown 多段真实 IO，
    // fake-zone 续体靠 pump↔runAsync 交替推进）。
    await settleUntil(
      tester,
      () => svc.snapshot.phase == TalkRecordRecorderPhase.ended,
    );
    expect(svc.phase, TalkRecordRecorderPhase.ended);
    // 弹窗已随确认关闭（dialog 流程完成）；结果干净保存。
    expect(find.text('结束并保存'), findsNothing);
    expect(find.text('录音已保存'), findsOneWidget);
    // end() 幂等：结束后再次调用返回首次结果。
    TalkRecordSessionResult? result;
    await drive(tester, () async => result = await svc.end());
    expect(result, isNotNull);
    final ended = result!;
    expect(ended.savedCleanly, isTrue);
    expect(ended.effectiveDurationMs, 700);
  });

  testWidgets('空间不足：自动结束展示空间不足横幅（不显示保存成功）', (tester) async {
    final svc = await pumpRecording(tester);
    await drive(tester, () async => engine.tick(1200));
    await settleUntil(tester, () => svc.snapshot.segmentCount == 1);
    expect(svc.snapshot.segmentCount, 1);

    diskProbe.failingDirs.add(svc.sessionDir!.path);
    await drive(tester, () async => engine.tick(1000));
    await settleUntil(
      tester,
      () => find.text('空间不足，已停止写入；已录内容保留在本机').evaluate().isNotEmpty,
    );

    expect(svc.phase, TalkRecordRecorderPhase.ended);
    expect(find.text('空间不足，已停止写入；已录内容保留在本机'), findsOneWidget);
    expect(find.text('录音已保存'), findsNothing);
  });

  testWidgets('收起：持久录音条不自动结束，点击恢复面板', (tester) async {
    final svc = await pumpRecording(tester);
    await drive(tester, () async => engine.tick(1100));
    await settleUntil(tester, () => find.text('00:01').evaluate().length == 1);

    await tester.tap(find.byKey(const ValueKey('trr_btn_collapse')));
    await tester.pump();
    // 收起条：仍显示计时与状态，会话仍在录。
    expect(find.text('正在录音 · 本机分段保存'), findsOneWidget);
    expect(find.text('00:01'), findsOneWidget);
    expect(find.byKey(const ValueKey('trr_collapsed_bar')), findsOneWidget);
    expect(svc.phase, TalkRecordRecorderPhase.recording);

    // 收起后继续计时（无自动结束）。
    await drive(tester, () async => engine.tick(200));
    await tester.pump();
    expect(svc.phase, TalkRecordRecorderPhase.recording);
    expect(find.text('00:01'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trr_collapsed_bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trr_btn_pause')), findsOneWidget);
    await drive(tester, svc.end);
  });

  testWidgets('初始收起：退出录音页场景仍持续呈现', (tester) async {
    final svc = await pumpRecording(tester, initiallyCollapsed: true);
    expect(find.byKey(const ValueKey('trr_collapsed_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('trr_btn_pause')), findsNothing);
    expect(svc.phase, TalkRecordRecorderPhase.recording);
    await drive(tester, svc.end);
  });

  testWidgets('无麦克风权限：仅引导视图，无引擎/文件副作用', (tester) async {
    final svc = newService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TalkRecordRecorderBar(
            controller: svc,
            micPermission: TalkRecordMicPermission.denied,
          ),
        ),
      ),
    );
    expect(find.text('未获得麦克风权限，请在系统设置中开启后重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('trr_btn_pause')), findsNothing);
    expect(engine.opened, isFalse);
    expect(engine.events, isEmpty);
    expect(baseDir.listSync(), isEmpty); // 无会话目录/密钥/清单
  });

  testWidgets('主按钮触达区 ≥48pt，次按钮 ≥44pt（UI-SPEC §1）', (tester) async {
    await pumpRecording(tester);

    final pause = tester.getSize(find.byKey(const ValueKey('trr_btn_pause')));
    expect(pause.width, greaterThanOrEqualTo(48.0));
    expect(pause.height, greaterThanOrEqualTo(48.0));

    final mark = tester.getSize(find.byKey(const ValueKey('trr_btn_mark')));
    expect(mark.width, greaterThanOrEqualTo(44.0));
    expect(mark.height, greaterThanOrEqualTo(44.0));
  });
}
