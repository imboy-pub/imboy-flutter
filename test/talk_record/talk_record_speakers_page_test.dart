/// T16 发言人校对页 widget 测试：说话人列表（匿名/人工标记来源 pill）、
/// 试听片段（播放器定位）、设置显示名、认领自己（409 冲突提示）、
/// editor 标记同事（目录可用/不可用两态）、viewer 只读。
///
/// 纪律：fixture 注入 + 真实 GoRouter；零网络零声纹——人工标记 ≠ 本人
/// 认证（UI-SPEC §2），本文件不是与真实目录/认领 API 的联调验收。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';

import 'talk_record_detail_test_helpers.dart';

void main() {
  setUpAll(() async {
    await useZhCn();
  });

  /// 打开详情 → 发言人入口进入发言人页。
  Future<void> openSpeakersPage(WidgetTester tester, T16Harness harness) async {
    await pumpDetailRouter(tester, harness);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('talk_record_speakers_entry')));
    await tester.pumpAndSettle();
    expect(find.text(t.talkRecord.speakersTitle), findsOneWidget);
  }

  testWidgets('说话人列表：匿名标签 pill + 范围说明（不建立声纹）', (tester) async {
    final harness = T16Harness();
    await openSpeakersPage(tester, harness);

    expect(find.text('说话人 1'), findsOneWidget);
    expect(find.text('说话人 2'), findsOneWidget);
    // 匿名来源 pill ×2。
    expect(find.text(t.talkRecord.speakerAnonymousPill), findsNWidgets(2));
    expect(find.text(t.talkRecord.speakersScopeHint), findsOneWidget);
    // 本页同样挂播放器条（试听定位后可播放/暂停）。
    expect(
      find.byKey(const ValueKey('talk_record_player_bar')),
      findsOneWidget,
    );
  });

  testWidgets('试听片段：定位播放器到该说话人首个片段并播放', (tester) async {
    final harness = T16Harness();
    await openSpeakersPage(tester, harness);

    // 说话人 2（id 202）首个片段 seq1 起点 60s → 定位 60s 并播放。
    await tester.ensureVisible(
      find.byKey(const ValueKey('talk_record_speaker_row_202')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('talk_record_speaker_audition_202')),
    );
    await tester.pumpAndSettle();

    expect(harness.backend.seeks, contains(60_000));
    expect(harness.backend.plays, isNotEmpty);
  });

  testWidgets('设置显示名（editor）：对话框输入并保存生效', (tester) async {
    final harness = T16Harness(
      service: TalkRecordFixtureScenarios.transcribedWithSummary(
        caps: kEditorCaps,
      ),
    );
    await openSpeakersPage(tester, harness);

    await tester.tap(
      find.byKey(const ValueKey('talk_record_speaker_rename_201')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('talk_record_speaker_name_field')),
      '李工',
    );
    await tester.tap(find.text(t.talkRecord.speakerSetNameConfirm));
    await tester.pumpAndSettle();

    expect(find.text('李工'), findsOneWidget);
    // 显示名不改变身份来源（仍匿名来源）。
    expect(find.text(t.talkRecord.speakerAnonymousPill), findsNWidgets(2));
  });

  testWidgets('认领自己：来源 pill 变为本人认领', (tester) async {
    final harness = T16Harness();
    await openSpeakersPage(tester, harness);

    await tester.tap(
      find.byKey(const ValueKey('talk_record_speaker_claim_201')),
    );
    await tester.pumpAndSettle();

    expect(find.text(t.talkRecord.speakerSelfClaimPill), findsOneWidget);
    expect(find.text(t.talkRecord.speakerSourceHint), findsOneWidget);
  });

  testWidgets('认领冲突（409）：显示人工纠正提示', (tester) async {
    final harness = T16Harness();
    // 预置：说话人已被他人认领。
    final entry = harness.service.entries.single;
    await harness.service.claimSpeaker('1001', entry.speakers.first.id);
    entry.currentUserId = '9600';
    await openSpeakersPage(tester, harness);

    await tester.tap(
      find.byKey(const ValueKey('talk_record_speaker_claim_201')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('talk_record_claim_conflict_banner')),
      findsOneWidget,
    );
    expect(find.text(t.talkRecord.speakerClaimConflict), findsOneWidget);
  });

  testWidgets('editor 标记同事（目录可用）：人工标记 pill 出现', (tester) async {
    final harness = T16Harness(
      service: TalkRecordFixtureScenarios.transcribedWithSummary(
        caps: kEditorCaps,
      ),
      directory: FakeDirectory(const [
        TalkRecordParticipantOption(userId: '9500', displayName: '张三'),
      ]),
    );
    await openSpeakersPage(tester, harness);

    await tester.tap(
      find.byKey(const ValueKey('talk_record_speaker_mark_201')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();

    expect(find.text(t.talkRecord.speakerManualPill), findsOneWidget);
    expect(find.text(t.talkRecord.speakerSourceHint), findsOneWidget);
    // 服务端置 manual 且绑定标记人。
    final speaker = harness.service.entries.single.speakers.first;
    expect(speaker.identitySource.wireName, 'manual');
    expect(speaker.matchedUserId, '9500');
  });

  testWidgets('目录待接入：标记同事如实提示，不猜候选人', (tester) async {
    final harness = T16Harness(
      service: TalkRecordFixtureScenarios.transcribedWithSummary(
        caps: kEditorCaps,
      ),
      directory: const EmptyParticipantDirectory(),
    );
    await openSpeakersPage(tester, harness);

    await tester.tap(
      find.byKey(const ValueKey('talk_record_speaker_mark_201')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('talk_record_mark_colleague_unavailable')),
      findsOneWidget,
    );
    expect(find.text(t.talkRecord.speakerDirectoryUnavailable), findsOneWidget);
  });

  testWidgets('viewer：无设置名/标记入口；试听与认领保留', (tester) async {
    final harness = T16Harness(
      service: TalkRecordFixtureScenarios.transcribedWithSummary(
        caps: kViewerCaps,
      ),
    );
    await openSpeakersPage(tester, harness);

    expect(
      find.byKey(const ValueKey('talk_record_speaker_rename_201')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('talk_record_speaker_mark_201')),
      findsNothing,
    );
    expect(find.text(t.talkRecord.speakerAudition), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('talk_record_speaker_claim_201')),
      findsOneWidget,
    );
    // 行触达 ≥44（C-F4 抽查）。
    expect(
      tester
          .getSize(find.byKey(const ValueKey('talk_record_speaker_row_201')))
          .height,
      greaterThanOrEqualTo(44),
    );
  });
}
