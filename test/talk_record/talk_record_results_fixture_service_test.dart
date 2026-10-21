/// T21 结果域 fixture 服务语义测试（零网络；仅证明组件契约形状）。
///
/// 覆盖：导出门控（403/策略）、排队→就绪、下载短时 URL 与 410、移交
/// owner 换人/保留查看分支/403/412、删除 202 语义与删除后 owner 白名单/
/// 非 owner 404、清理五态推进与失败重试。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/config/error_code.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_fixture_service.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

void main() {
  group('导出', () {
    test('无导出能力（viewer）→ 403；策略禁用 → 403', () async {
      final viewer = TalkRecordResultsFixtureScenarios.viewerNoExport();
      await expectLater(
        () => viewer.createExport(
          '1001',
          format: TalkRecordExportFormat.txt,
          idempotencyKey: 'k1',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.FORBIDDEN,
          ),
        ),
      );
      final blocked =
          TalkRecordResultsFixtureScenarios.ownerExportBlockedByOrg();
      await expectLater(
        () => blocked.createExport(
          '1001',
          format: TalkRecordExportFormat.md,
          idempotencyKey: 'k2',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.FORBIDDEN,
          ),
        ),
      );
    });

    test('创建即就绪（pollsToReady=0）→ ready + 短时到期', () async {
      final service = TalkRecordResultsFixtureScenarios.ownerExportAllowed();
      final artifact = await service.createExport(
        '1001',
        format: TalkRecordExportFormat.md,
        idempotencyKey: 'k3',
      );
      expect(artifact.isReady, isTrue);
      expect(artifact.format, TalkRecordExportFormat.md);
      expect(artifact.expiresAt, isNotNull);
    });

    test('排队 → 轮询一次后就绪；排队不伪造完成', () async {
      final service = TalkRecordResultsFixtureScenarios.ownerExportAllowed(
        exportPollsToReady: 1,
      );
      final queued = await service.createExport(
        '1001',
        format: TalkRecordExportFormat.txt,
        idempotencyKey: 'k4',
      );
      expect(queued.isQueued, isTrue);
      final stillQueued = await service.exportState('1001', queued.exportId);
      expect(stillQueued.isReady, isTrue);
    });

    test('下载返回短时示例 URL；到期/过期 → 410 GONE', () async {
      final service = TalkRecordResultsFixtureScenarios.ownerExportAllowed();
      final artifact = await service.createExport(
        '1001',
        format: TalkRecordExportFormat.txt,
        idempotencyKey: 'k5',
      );
      final url = await service.exportDownloadUrl('1001', artifact.exportId);
      expect(url, contains('ticket=synthetic-ticket'));
      service.expireExport('1001', artifact.exportId);
      await expectLater(
        () => service.exportDownloadUrl('1001', artifact.exportId),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.GONE,
          ),
        ),
      );
    });

    test('exportShouldFail → 503 如实失败', () async {
      final service = FixtureTalkRecordResultsService([
        TalkRecordResultsFixtureScenarios.entry(
          recordId: '1001',
          transferCandidates:
              TalkRecordResultsFixtureScenarios.defaultTransferCandidates(),
          exportShouldFail: true,
        ),
      ]);
      await expectLater(
        () => service.createExport(
          '1001',
          format: TalkRecordExportFormat.txt,
          idempotencyKey: 'k6',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.SERVICE_UNAVAILABLE,
          ),
        ),
      );
    });
  });

  group('责任移交（§9）', () {
    test('候选排除当前 owner；q 过滤', () async {
      final service = FixtureTalkRecordResultsService([
        TalkRecordResultsFixtureScenarios.entry(
          recordId: '1001',
          transferCandidates: [
            TalkRecordShareCandidateModel.fromJson(const {
              'user_id': '9001',
              'display_name': '我本人',
              'account': 'me@fixture.example',
            }),
            ...TalkRecordResultsFixtureScenarios.defaultTransferCandidates(),
          ],
        ),
      ]);
      final page = await service.transferCandidates('1001');
      expect(page.list.any((c) => c.userId == '9001'), isFalse);
      expect(page.list.length, 3);
      final filtered = await service.transferCandidates('1001', q: '沈例');
      expect(filtered.list.single.displayName, '沈例');
    });

    test('移交成功：换 owner、推进 revision/acl、keepViewer=false 失访问', () async {
      final service = TalkRecordResultsFixtureScenarios.ownerExportAllowed();
      final outcome = await service.transferOwnership(
        '1001',
        targetUserId: '9201',
        keepViewerForOriginalOwner: false,
        ifMatch: 'record:2',
        idempotencyKey: 't1',
      );
      expect(outcome.newOwnerUserId, '9201');
      expect(outcome.originalOwnerKeptViewer, isFalse);
      final entry = service.entries.single;
      expect(entry.record.ownerUserId, '9201');
      expect(entry.record.createdBy, '9001'); // created_by 不变（§9）
      expect(entry.record.revision, 3); // 2 → 3
      expect(entry.record.aclRevision, 2); // 1 → 2
      // 不保留 → 原 owner 立即失去访问（统一 404，§11.3 不泄露原因）。
      await expectLater(
        () => service.record('1001'),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.NOT_FOUND,
          ),
        ),
      );
    });

    test('keepViewer=true → 原 owner 仍可读（保留查看）', () async {
      final service = TalkRecordResultsFixtureScenarios.ownerExportAllowed();
      await service.transferOwnership(
        '1001',
        targetUserId: '9202',
        keepViewerForOriginalOwner: true,
        ifMatch: 'record:2',
        idempotencyKey: 't2',
      );
      final kept = await service.record('1001');
      expect(kept.data.id, '1001');
      expect(
        service.entries.single.lastTransfer!.originalOwnerKeptViewer,
        isTrue,
      );
    });

    test('非 owner / 非法目标 / If-Match 错配 → 403 / 403 / 412', () async {
      final viewer = TalkRecordResultsFixtureScenarios.viewerNoExport();
      await expectLater(
        () => viewer.transferOwnership(
          '1001',
          targetUserId: '9201',
          keepViewerForOriginalOwner: false,
          ifMatch: 'record:2',
          idempotencyKey: 't3',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.FORBIDDEN,
          ),
        ),
      );
      final owner = TalkRecordResultsFixtureScenarios.ownerExportAllowed();
      await expectLater(
        () => owner.transferOwnership(
          '1001',
          targetUserId: '9999', // 不在候选集 → 目标仍须合法（§3）
          keepViewerForOriginalOwner: false,
          ifMatch: 'record:2',
          idempotencyKey: 't4',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.FORBIDDEN,
          ),
        ),
      );
      await expectLater(
        () => owner.transferOwnership(
          '1001',
          targetUserId: '9201',
          keepViewerForOriginalOwner: false,
          ifMatch: 'record:1', // 过期版本
          idempotencyKey: 't5',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.PRECONDITION_FAILED,
          ),
        ),
      );
    });
  });

  group('删除与清理（§4/§10.4/§11.3）', () {
    test('删除成功：202 语义 logical_deleted + pending；revision 推进', () async {
      final service = TalkRecordResultsFixtureScenarios.ownerExportAllowed();
      final result = await service.deleteRecord('1001', ifMatch: 'record:2');
      expect(result.logicalDeleted, isTrue);
      expect(result.cleanupStatus, TalkRecordCleanupStatus.pending);
      final entry = service.entries.single;
      expect(entry.record.revision, 3);
    });

    test('删除后：owner 读白名单（无正文/标题）；非 owner 404', () async {
      final service = TalkRecordResultsFixtureScenarios.ownerExportAllowed();
      await service.deleteRecord('1001', ifMatch: 'record:2');
      final whitelist = await service.record('1001');
      expect(whitelist.data.title, isEmpty); // 正文/标题不再返回
      expect(
        whitelist.data.cleanupStatus,
        TalkRecordCleanupStatus.pending, // 仅清理状态白名单（§11.3）
      );
      service.entries.single.currentUserId = '9203'; // 换非 owner 主体
      await expectLater(
        () => service.record('1001'),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.NOT_FOUND,
          ),
        ),
      );
    });

    test('无删除能力 → 403；冲突 → 412', () async {
      final viewer = TalkRecordResultsFixtureScenarios.viewerNoExport();
      await expectLater(
        () => viewer.deleteRecord('1001', ifMatch: 'record:2'),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.FORBIDDEN,
          ),
        ),
      );
      final conflicted = FixtureTalkRecordResultsService([
        TalkRecordResultsFixtureScenarios.entry(
          recordId: '1001',
          transferCandidates:
              TalkRecordResultsFixtureScenarios.defaultTransferCandidates(),
          deleteShouldConflict: true,
        ),
      ]);
      await expectLater(
        () => conflicted.deleteRecord('1001', ifMatch: 'record:2'),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.PRECONDITION_FAILED,
          ),
        ),
      );
    });

    test('清理失败重试：failed → pending；非 failed 409；重试失败 503', () async {
      final service = TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
        TalkRecordCleanupStatus.failed,
      );
      await service.retryCleanup(
        '1001',
        ifMatch: 'record:2',
        idempotencyKey: 'r1',
      );
      expect(
        service.entries.single.record.cleanupStatus,
        TalkRecordCleanupStatus.pending,
      );
      // pending 非 failed → 不可重试（409）。
      await expectLater(
        () => service.retryCleanup(
          '1001',
          ifMatch: 'record:2',
          idempotencyKey: 'r2',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.CONFLICT,
          ),
        ),
      );
      final failing = TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
        TalkRecordCleanupStatus.failed,
        cleanupRetryShouldFail: true,
      );
      await expectLater(
        () => failing.retryCleanup(
          '1001',
          ifMatch: 'record:2',
          idempotencyKey: 'r3',
        ),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.code,
            'code',
            ErrorCode.SERVICE_UNAVAILABLE,
          ),
        ),
      );
    });
  });
}
