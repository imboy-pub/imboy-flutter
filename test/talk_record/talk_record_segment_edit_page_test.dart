/// T16 片段校对页 widget 测试：原稿对照、保存成功（content_revision 推进
/// + 摘要 stale 生效回详情）、412 冲突保留本地输入（对比/采用服务器稿/
/// 重新提交）。
///
/// 纪律：fixture 注入 + 真实 GoRouter 导航（editor 点片段行进入校对页）；
/// 零网络，不是与真实编辑 API 的联调验收（T15/T22）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_fixture_service.dart';

import 'talk_record_detail_test_helpers.dart';

void main() {
  setUpAll(() async {
    await useZhCn();
  });

  /// 打开详情并进入片段 300 的校对页（editor 点行）。
  Future<GoRouter> openSegmentEdit(
    WidgetTester tester,
    T16Harness harness,
  ) async {
    final router = await pumpDetailRouter(tester, harness);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.talkRecord.tabTranscript));
    await tester.pumpAndSettle();
    await tester.tap(find.text('（fixture）先过一下上周的发布进展。预算'));
    await tester.pumpAndSettle();
    expect(find.text(t.talkRecord.segmentEditTitle), findsOneWidget);
    return router;
  }

  testWidgets('进入校对页：原稿对照 + 可编辑文字预填', (tester) async {
    final harness = T16Harness();
    await openSegmentEdit(tester, harness);

    expect(
      find.byKey(const ValueKey('talk_record_segment_original')),
      findsOneWidget,
    );
    final field = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('talk_record_segment_field')),
    );
    expect(field.controller?.text, '（fixture）先过一下上周的发布进展。预算');
    // C-F2/C-F4：保存主按钮 ≥48pt。
    expect(
      tester
          .getSize(find.byKey(const ValueKey('talk_record_segment_save')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('保存成功：返回详情，content_revision 推进且摘要过时横幅出现', (tester) async {
    final harness = T16Harness(
      service: TalkRecordFixtureScenarios.transcribedWithSummary(
        caps: kEditorCaps,
      ),
    );
    final router = await openSegmentEdit(tester, harness);
    final entry = harness.service.entries.single;
    final beforeRevision = entry.record.contentRevision;

    await tester.enterText(
      find.byKey(const ValueKey('talk_record_segment_field')),
      '（校对后）先过一下上周的发布与预算进展',
    );
    await tester.tap(find.byKey(const ValueKey('talk_record_segment_save')));
    await tester.pumpAndSettle();

    // 返回详情（pop；state.uri 是实际地址，state.path 是路由模板）。
    expect(router.state.uri.path, '$kTalkRecordDetailPath/1001');
    expect(entry.record.contentRevision, beforeRevision + 1);
    expect(entry.summary.status.wireName, 'stale');
    // 返回后仍在原文页签；切回摘要页签看到过时横幅（fixture 语义端到端）。
    await tester.tap(find.text(t.talkRecord.tabSummary));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('talk_record_summary_stale_banner')),
      findsOneWidget,
    );
  });

  testWidgets('412 冲突：本地输入保留；服务器稿对照；采用服务器稿；重新提交成功', (tester) async {
    final harness = T16Harness(
      service: TalkRecordFixtureScenarios.transcribedWithSummary(
        caps: kEditorCaps,
      ),
    );
    await openSegmentEdit(tester, harness);
    final entry = harness.service.entries.single;
    final segmentId = entry.segments.first.id;

    // 模拟他人在本页打开后先行保存（revision 1 → 2）。
    await harness.service.patchSegment(
      '1001',
      segmentId,
      text: '（他人改过）先过一下上周的发布进展',
      ifMatch: 'segment:$segmentId:1',
    );

    // 本地输入新文字后保存 → 412。
    await tester.enterText(
      find.byKey(const ValueKey('talk_record_segment_field')),
      '（我的校对）预算口径先确认',
    );
    await tester.tap(find.byKey(const ValueKey('talk_record_segment_save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('talk_record_segment_conflict_banner')),
      findsOneWidget,
    );
    // 服务器最新稿出现在原稿对照区。
    expect(find.textContaining('（他人改过）'), findsOneWidget);
    // 本地输入保留（不清空、不静默覆盖）。
    final field = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('talk_record_segment_field')),
    );
    expect(field.controller?.text, '（我的校对）预算口径先确认');
    // 按钮切换为「重新提交」。
    expect(find.text(t.talkRecord.segmentResubmit), findsOneWidget);

    // 采用服务器稿：编辑框载入服务器文本。
    await tester.tap(
      find.byKey(const ValueKey('talk_record_segment_adopt_server')),
    );
    await tester.pumpAndSettle();
    final fieldAfterAdopt = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('talk_record_segment_field')),
    );
    expect(fieldAfterAdopt.controller?.text, '（他人改过）先过一下上周的发布进展');
    expect(
      find.byKey(const ValueKey('talk_record_segment_conflict_banner')),
      findsNothing,
    );

    // 改一版再重新提交（用刷新后的服务器 revision 作 If-Match）→ 成功。
    await tester.enterText(
      find.byKey(const ValueKey('talk_record_segment_field')),
      '（合并后）先过发布进展，预算口径待确认',
    );
    await tester.tap(find.byKey(const ValueKey('talk_record_segment_save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('talk_record_segment_conflict_banner')),
      findsNothing,
    );
    expect(entry.summary.status.wireName, 'stale');
    final saved = entry.segments.first;
    expect(saved.text, '（合并后）先过发布进展，预算口径待确认');
    expect(saved.revision, 3);
  });
}
