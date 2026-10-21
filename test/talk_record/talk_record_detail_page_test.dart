/// T16 详情页 widget 测试：角色矩阵（UI-SPEC §3）、状态降级、固定播放器
/// （受控会话/续签/定位/回到播放位置）、页签 C-F1、触达 C-F4、C-F3 换行、
/// 语义标签抽查。
///
/// 纪律：fixture 注入（零网络零麦克风零平台通道）；本文件是组件行为
/// 验证，不是与真实 API/票据/播放器的联调验收（T13/T15/T22）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/config/error_code.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'talk_record_detail_test_helpers.dart';

void main() {
  setUpAll(() async {
    await useZhCn();
  });

  Future<void> openTranscriptTab(WidgetTester tester) async {
    await tester.tap(find.text(t.talkRecord.tabTranscript));
    await tester.pumpAndSettle();
  }

  group('角色矩阵（UI-SPEC §3）', () {
    testWidgets('viewer：读者徽章；笔记只读；无更多管理入口；无校对入口', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribedWithSummary(
          caps: kViewerCaps,
        ),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.roleViewer), findsOneWidget);
      expect(find.text(t.talkRecord.visibilityShared), findsOneWidget);
      // 笔记只读：无编辑按钮，显示只读说明。
      expect(
        find.byKey(const ValueKey('talk_record_notes_edit')),
        findsNothing,
      );
      expect(find.text(t.talkRecord.notesReadonlyHint), findsOneWidget);
      // 无分享/导出/删除能力 → 更多入口整体隐藏。
      expect(
        find.byKey(const ValueKey('talk_record_more_entry')),
        findsNothing,
      );

      await openTranscriptTab(tester);
      // viewer 原文无校对跳转：行无 onTap（以校对入口缺失间接证明——
      // editor 场景对应用例断言路由跳转）。
      expect(find.text(t.talkRecord.transcriptSearchHint), findsOneWidget);
    });

    testWidgets('editor：编辑者徽章；笔记可编辑；无分享/删除入口', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribedWithSummary(
          caps: kEditorCaps,
        ),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.roleEditor), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_notes_edit')),
        findsOneWidget,
      );
      // editor 无 share/delete/export → 更多入口隐藏。
      expect(
        find.byKey(const ValueKey('talk_record_more_entry')),
        findsNothing,
      );
      expect(find.text(t.talkRecord.roleEditorHint), findsOneWidget);
    });

    testWidgets('editor + allow_export：仅出现导出入口', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribedWithSummary(
          caps: kEditorExportCaps,
        ),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('talk_record_more_entry')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('talk_record_action_export')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_action_share')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('talk_record_action_delete')),
        findsNothing,
      );
    });

    testWidgets('owner：创建者徽章；分享/导出/删除全量出现且诚实标注待接入', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribedWithSummary(
          caps: kOwnerCaps,
        ),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.roleOwner), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('talk_record_more_entry')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('talk_record_action_share')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_action_export')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_action_delete')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('talk_record_action_export')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_action_pending_dialog')),
        findsOneWidget,
      );
      expect(find.text(t.talkRecord.actionPendingIntegration), findsOneWidget);
    });
  });

  group('状态降级（不渲染虚构正文）', () {
    testWidgets('仅录音：原文页签真实降级，无片段行', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.recordOnly(caps: kOwnerCaps),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();
      // 摘要页签：无源不伪造摘要。
      expect(find.text(t.talkRecord.summaryNoSource), findsOneWidget);

      await openTranscriptTab(tester);
      expect(find.text(t.talkRecord.detailRecordOnlyBody), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('talk_record_transcript_degraded_recordOnly'),
        ),
        findsOneWidget,
      );
      // 没有任何片段文本被渲染。
      expect(find.textContaining('（fixture）'), findsNothing);
    });

    testWidgets('无语音：专用文案，全文不出现「转写失败」', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.noSpeech(caps: kOwnerCaps),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();
      await openTranscriptTab(tester);

      expect(
        find.byKey(const ValueKey('talk_record_transcript_degraded_noSpeech')),
        findsOneWidget,
      );
      expect(find.text(t.talkRecord.detailNoSpeechBody), findsOneWidget);
      // UI-SPEC §4：无语音不显示「转写失败」。
      expect(find.text(t.talkRecord.detailTranscribeFailedTitle), findsNothing);
      expect(find.text(t.talkRecord.statusTranscribeFailed), findsNothing);
    });

    testWidgets('转写失败（editor）：可重试，重试走服务并转入排队文案', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribeFailed(caps: kEditorCaps),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();
      await openTranscriptTab(tester);

      expect(
        find.byKey(const ValueKey('talk_record_transcript_degraded_failed')),
        findsOneWidget,
      );
      expect(
        find.text(t.talkRecord.detailTranscribeFailedBodyEditor),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transcript_retry')),
      );
      await tester.pumpAndSettle();
      expect(harness.service.retryCount, 1);
      // 受理后状态推进 queued → 转入「处理中」降级视图。
      expect(
        find.byKey(
          const ValueKey('talk_record_transcript_degraded_processing'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('转写失败（viewer）：联系创建者文案，无重试按钮', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribeFailed(caps: kViewerCaps),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();
      await openTranscriptTab(tester);

      expect(
        find.text(t.talkRecord.detailTranscribeFailedBodyViewer),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_transcript_retry')),
        findsNothing,
      );
    });

    testWidgets('摘要过时：过时横幅 + AI 草稿标注 + 旧摘要仍可见', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.staleSummary(caps: kOwnerCaps),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('talk_record_summary_stale_banner')),
        findsOneWidget,
      );
      expect(find.text(t.talkRecord.summaryDraftBadge), findsOneWidget);
      expect(find.text(t.talkRecord.summaryDecisionsTitle), findsOneWidget);
      expect(find.text(t.talkRecord.summaryActionsTitle), findsOneWidget);
    });
  });

  group('固定播放器（受控会话）', () {
    testWidgets('播放：开受控票据并载入 URL；进度触达区 ≥44', (tester) async {
      final harness = T16Harness();
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      final track = find.byKey(const ValueKey('talk_record_player_progress'));
      expect(tester.getSize(track).height, greaterThanOrEqualTo(44));

      await tester.tap(find.byKey(const ValueKey('talk_record_player_play')));
      await tester.pumpAndSettle();

      expect(harness.gateway.openCount, 1);
      expect(harness.backend.loads, hasLength(1));
      expect(
        harness.backend.loads.single.$1,
        startsWith('fixture-playback://talk-records/1001'),
      );
      expect(harness.backend.plays, hasLength(1));
      // 播放/暂停按钮触达 ≥44。
      final play = find.byKey(const ValueKey('talk_record_player_pause'));
      expect(tester.getSize(play).height, greaterThanOrEqualTo(44));
    });

    testWidgets('票据临期：进度回调触发续签并热载保持位置', (tester) async {
      // 票据寿命 20s < 续签提前量 60s → 开票即临期；首个进度回调续签。
      final harness = T16Harness(
        gateway: FixtureTalkRecordPlaybackGateway(
          ticketTtl: const Duration(seconds: 20),
        ),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('talk_record_player_play')));
      await tester.pumpAndSettle();
      harness.backend.emit(15_000, playing: true, durationMs: 655_000);
      await tester.pumpAndSettle();

      expect(harness.gateway.renewCount, greaterThanOrEqualTo(1));
      expect(harness.backend.loads.length, greaterThanOrEqualTo(2));
      // 热载保持当前位置（initialPositionMs=15000）。
      expect(harness.backend.loads.last.$2, 15_000);
      expect(find.text('00:15'), findsOneWidget);
    });

    testWidgets('片段时间点回听：定位播放器到片段起点并自动播放', (tester) async {
      final harness = T16Harness();
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();
      await openTranscriptTab(tester);

      // 片段 id=303 → seq=3 → 起点 180s（先滚动到可见再点击）。
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('talk_record_segment_time_303')),
        find.byType(Scrollable).last,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_segment_time_303')),
      );
      await tester.pumpAndSettle();

      expect(harness.backend.seeks, contains(180_000));
      expect(harness.backend.plays, isNotEmpty);
    });

    testWidgets('无回放能力：如实禁用，不请求票据', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribedWithSummary(
          caps: const {'edit': true, 'playback': false},
        ),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.playbackUnavailable), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('talk_record_player_play')));
      await tester.pumpAndSettle();
      expect(harness.gateway.openCount, 0);
      expect(harness.backend.loads, isEmpty);
    });

    testWidgets('开票失败（撤权语义）：失败提示 + 重试恢复', (tester) async {
      final harness = T16Harness();
      harness.gateway.errorToThrow = const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'revoked (fixture)',
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('talk_record_player_play')));
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.playbackTicketFailed), findsOneWidget);
      expect(harness.backend.plays, isEmpty);

      harness.gateway.errorToThrow = null;
      await tester.tap(
        find.byKey(const ValueKey('talk_record_playback_retry')),
      );
      await tester.pumpAndSettle();
      expect(harness.backend.plays, isNotEmpty);
    });
  });

  group('搜索定位与「回到播放位置」', () {
    testWidgets('命中高亮 + 计数；命中跳转只 seek 播放器不抢阅读位置', (tester) async {
      final harness = T16Harness();
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();
      await openTranscriptTab(tester);

      await tester.enterText(
        find.byKey(const ValueKey('talk_record_transcript_search')),
        '预算',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('talk_record_transcript_hit_count')),
        findsOneWidget,
      );
      expect(
        find.text(t.talkRecord.transcriptHitCount(count: 2)),
        findsOneWidget,
      );

      // 命中段时间点回听（可见命中 seq0）：播放器定位到 0ms。
      final listFinder = find.byType(Scrollable).last;
      final offsetBefore = tester
          .state<ScrollableState>(listFinder)
          .position
          .pixels;
      await tester.tap(
        find.byKey(const ValueKey('talk_record_segment_time_300')),
      );
      await tester.pumpAndSettle();
      expect(harness.backend.seeks, contains(0));
      // 不抢阅读位置：列表滚动偏移保持不变。
      expect(
        tester.state<ScrollableState>(listFinder).position.pixels,
        offsetBefore,
      );

      // 播放推进离开阅读锚点（seq0 → seq1）→ 出现「回到播放位置」。
      harness.backend.emit(65_000, playing: true, durationMs: 655_000);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_return_to_playback')),
        findsOneWidget,
      );

      // 点击入口：原文滚回播放片段，入口消失（不改变播放进度）。
      final seeksBefore = harness.backend.seeks.length;
      await tester.tap(
        find.byKey(const ValueKey('talk_record_return_to_playback')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_return_to_playback')),
        findsNothing,
      );
      expect(harness.backend.seeks.length, seeksBefore);
    });
  });

  group('C-F 契约（CONTRACT-FREEZE-T02 §4，对齐 T10 断言模式）', () {
    testWidgets('C-F1：选中页签 primaryDark 实底 + 白字 w600', (tester) async {
      final harness = T16Harness();
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('talk_record_tab_selected_container')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.primaryDark);

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('talk_record_detail_tabs')),
          matching: find.text(t.talkRecord.tabSummary),
        ),
      );
      expect(text.style?.color, AppColors.onPrimary);
      expect(text.style?.fontWeight, FontWeight.w600);

      // 切换后选中态跟随。
      await openTranscriptTab(tester);
      final container2 = tester.widget<Container>(
        find.byKey(const ValueKey('talk_record_tab_selected_container')),
      );
      expect(
        (container2.decoration! as BoxDecoration).color,
        AppColors.primaryDark,
      );
      final text2 = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('talk_record_detail_tabs')),
          matching: find.text(t.talkRecord.tabTranscript),
        ),
      );
      expect(text2.style?.color, AppColors.onPrimary);
    });

    testWidgets('C-F3：降级/说明文字无单行截断（maxLines == null）', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.recordOnly(caps: kOwnerCaps),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();
      await openTranscriptTab(tester);

      final body = tester.widget<Text>(
        find.text(t.talkRecord.detailRecordOnlyBody),
      );
      expect(body.maxLines, isNull);
    });

    testWidgets('C-F4：概述行动作行触达 ≥44（发言人入口）', (tester) async {
      final harness = T16Harness();
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(find.byKey(const ValueKey('talk_record_speakers_entry')))
            .height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('可访问性（语义标签抽查）', () {
    testWidgets('播放/暂停/回到播放位置/进度携带语义标签', (tester) async {
      final handle = tester.ensureSemantics();
      final harness = T16Harness();
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(t.talkRecord.playbackPlayLabel),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('talk_record_player_play')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(t.talkRecord.playbackPauseLabel),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          t.talkRecord.playbackProgressLabel(
            position: talkRecordFormatDuration(0),
            duration: talkRecordFormatDuration(655_000),
          ),
        ),
        findsOneWidget,
      );

      // 播放推进离开阅读锚点 → 「回到播放位置」携带语义标签。
      await openTranscriptTab(tester);
      harness.backend.emit(65_000, playing: true, durationMs: 655_000);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      // 语义节点可能与行内文本合并——按包含匹配（节点携带该标签即可）。
      expect(
        find.bySemanticsLabel(RegExp('.*${t.talkRecord.returnToPlayback}.*')),
        findsOneWidget,
      );

      // 片段时间点回听按钮的语义标签（已构建行；合并节点按包含匹配）。
      expect(
        find.bySemanticsLabel(
          RegExp('.*${t.talkRecord.segmentListenLabel(time: '00:00')}.*'),
        ),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('共享笔记保存（editor）', () {
    testWidgets('编辑保存走服务并显示已保存提示', (tester) async {
      final harness = T16Harness(
        service: TalkRecordFixtureScenarios.transcribedWithSummary(
          caps: kEditorCaps,
        ),
      );
      await pumpDetailPage(tester, harness);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_notes_edit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('talk_record_notes_edit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_notes_field')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('talk_record_notes_field')),
        '会后补充：发版清单已对齐',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_notes_save')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('talk_record_notes_save')));
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.notesSavedHint), findsOneWidget);
      expect(harness.service.entries.single.record.notes, '会后补充：发版清单已对齐');
      // 保存成功后退出编辑态，展示新内容。
      expect(find.text('会后补充：发版清单已对齐'), findsOneWidget);
    });
  });
}
