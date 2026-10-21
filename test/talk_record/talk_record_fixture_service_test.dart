/// T16 fixture 服务与受控回放网关单测：ETag/412 语义、content_revision
/// 推进与摘要 stale、认领 409、人工标记 manual、票据开票/续签/到期。
///
/// 声明：fixture 只证明组件行为契约，不代表真实转写/摘要质量。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/config/error_code.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart'
    show talkRecordSegmentEtagOf, talkRecordSpeakerEtagOf;
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';

void main() {
  group('patchSegment（§11.2 内容修订语义）', () {
    test(
      '正确 If-Match：revision+1、origin=human、content_revision 推进、摘要 stale',
      () async {
        final service = TalkRecordFixtureScenarios.transcribedWithSummary();
        final entry = service.entries.single;
        final before = entry.record.contentRevision;
        final etag = talkRecordSegmentEtagOf(entry.segments.first);

        final fetched = await service.patchSegment(
          '1001',
          entry.segments.first.id,
          text: '（校对后）先过一下发布进展',
          ifMatch: etag,
        );

        expect(fetched.data.revision, 2);
        expect(fetched.data.origin.wireName, 'human');
        expect(fetched.data.text, '（校对后）先过一下发布进展');
        expect(fetched.etag, 'segment:${entry.segments.first.id}:2');
        expect(entry.record.contentRevision, before + 1);
        expect(entry.summary.status.wireName, 'stale');
        // 原稿快照保留（供对照）。
        expect(entry.originalTexts[entry.segments.first.id], isNotEmpty);
      },
    );

    test('过期 If-Match：抛 412（revisionStale 分型），不改状态', () async {
      final service = TalkRecordFixtureScenarios.transcribedWithSummary();
      final entry = service.entries.single;
      const staleEtag = 'segment:300:0';

      await expectLater(
        service.patchSegment(
          '1001',
          entry.segments.first.id,
          text: 'x',
          ifMatch: staleEtag,
        ),
        throwsA(
          isA<TalkRecordApiException>()
              .having((e) => e.code, 'code', ErrorCode.PRECONDITION_FAILED)
              .having((e) => e.isRevisionStale, 'isRevisionStale', true),
        ),
      );
      expect(entry.record.contentRevision, 3);
      expect(entry.summary.status.wireName, 'draft');
    });
  });

  group('notes（PATCH /:id notes）', () {
    test('正确 If-Match 保存并推进 revision etag', () async {
      final service = TalkRecordFixtureScenarios.transcribedWithSummary();
      final entry = service.entries.single;
      final fetched = await service.patchNotes(
        '1001',
        '补充：会后补材料',
        ifMatch: entry.recordEtag,
      );
      expect(fetched.data.notes, '补充：会后补材料');
      expect(fetched.etag, 'record:${entry.record.revision}');
      expect(entry.recordEtag, isNot('record:2'));
    });

    test('过期 If-Match 抛 412', () async {
      final service = TalkRecordFixtureScenarios.transcribedWithSummary();
      await expectLater(
        service.patchNotes('1001', 'x', ifMatch: 'record:0'),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.isRevisionStale,
            'isRevisionStale',
            true,
          ),
        ),
      );
    });
  });

  group('发言人（§4 speakers）', () {
    test('matched_user_id 由服务端置 manual（客户端不能指定 self_claim）', () async {
      final service = TalkRecordFixtureScenarios.transcribedWithSummary();
      final speaker = service.entries.single.speakers.first;
      final updated = await service.patchSpeaker(
        '1001',
        speaker.id,
        matchedUserId: '9500',
        ifMatch: talkRecordSpeakerEtagOf(speaker),
      );
      expect(updated.identitySource.wireName, 'manual');
      expect(updated.matchedUserId, '9500');
      expect(updated.confirmedBy, '9001');
    });

    test('认领：置 self_claim 并绑当前主体；他人再认领 409', () async {
      final service = TalkRecordFixtureScenarios.transcribedWithSummary();
      final entry = service.entries.single;
      final speaker = entry.speakers.first;

      final claimed = await service.claimSpeaker('1001', speaker.id);
      expect(claimed.identitySource.wireName, 'self_claim');
      expect(claimed.matchedUserId, '9001');

      // 换一个主体再认领 → 409 conflict。
      entry.currentUserId = '9600';
      await expectLater(
        service.claimSpeaker('1001', speaker.id),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.isConflict,
            'isConflict',
            true,
          ),
        ),
      );
    });
  });

  group('转写重试（jobs retry 子集）', () {
    test('失败态可受理并置 queued；非失败态 409', () async {
      final failed = TalkRecordFixtureScenarios.transcribeFailed();
      final ok = await failed.retryTranscribe('1001');
      expect(ok, true);
      expect(failed.entries.single.record.transcriptStatus.wireName, 'queued');

      final ready = TalkRecordFixtureScenarios.transcribedWithSummary();
      await expectLater(
        ready.retryTranscribe('1001'),
        throwsA(isA<TalkRecordApiException>()),
      );
    });
  });

  group('segments 查询（§4 q/speaker 过滤）', () {
    test('q 过滤与 speaker 过滤', () async {
      final service = TalkRecordFixtureScenarios.transcribedWithSummary();
      final hit = await service.segments('1001', q: '预算');
      expect(hit.list, isNotEmpty);
      final none = await service.segments('1001', q: '不存在的词');
      expect(none.list, isEmpty);
      final bySpeaker = await service.segments('1001', speakerId: '202');
      expect(bySpeaker.list, isNotEmpty);
      for (final s in bySpeaker.list) {
        expect(s.speakerId, '202');
      }
    });
  });

  group('FixtureTalkRecordPlaybackGateway（受控票据）', () {
    test('开票：短时 URL + 到期时间；续签产生新会话', () async {
      final gateway = FixtureTalkRecordPlaybackGateway();
      final t1 = await gateway.openTicket('1001');
      expect(t1.url, startsWith('fixture-playback://talk-records/1001'));
      expect(t1.expiresAt.isAfter(DateTime.now()), isTrue);
      final t2 = await gateway.renewTicket('1001', t1);
      expect(t2.sessionId, isNot(t1.sessionId));
      expect(gateway.openCount, 1);
      expect(gateway.renewCount, 1);
    });

    test('needsRenew/isExpired 到期判定', () {
      final now = DateTime.now();
      final ticket = TalkRecordPlaybackTicket(
        recordId: '1001',
        sessionId: 's',
        url: 'u',
        expiresAt: now.add(const Duration(seconds: 30)),
      );
      expect(ticket.needsRenew(now, const Duration(seconds: 60)), isTrue);
      expect(ticket.needsRenew(now, const Duration(seconds: 10)), isFalse);
      expect(ticket.isExpired(now), isFalse);
      expect(ticket.isExpired(now.add(const Duration(seconds: 31))), isTrue);
    });

    test('错误注入传播（撤权语义：开票失败如实抛出）', () async {
      final gateway = FixtureTalkRecordPlaybackGateway()
        ..errorToThrow = const TalkRecordApiException(
          ErrorCode.NOT_FOUND,
          'revoked',
        );
      await expectLater(gateway.openTicket('1001'), throwsException);
    });
  });
}
