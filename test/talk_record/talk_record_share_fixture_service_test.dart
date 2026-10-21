/// T18 分享域 fixture 服务语义测试（内存端点形状：门控/PUT/DELETE/
/// 候选/卡片/发送）。fixture 只证明组件契约，不是真实授权/撤销验收。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_service.dart';

import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_fixture_service.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';

void main() {
  group('grants 门控（§4：完整名单仅 owner；其他人只看自己）', () {
    test('owner 返回全量名单与 acl ETag', () async {
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      final fetched = await service.grants('1001');
      expect(fetched.data.length, 3);
      expect(fetched.etag, 'acl:1');
    });

    test('非 owner（editor）只返回自己的授权', () async {
      final service = TalkRecordShareFixtureScenarios.editorWithOwnGrant();
      final fetched = await service.grants('1001');
      expect(fetched.data.length, 1);
      expect(fetched.data.first.granteeUserId, '9102');
      expect(fetched.data.first.role, TalkRecordGrantRole.editor);
    });

    test('无访问主体 record()/shareCard() 统一 404（§11.3）', () async {
      final service = TalkRecordShareFixtureScenarios.viewerNoAccess();
      await expectLater(
        service.record('1001'),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.isNoAccess,
            'isNoAccess',
            true,
          ),
        ),
      );
      await expectLater(
        service.shareCard('1001'),
        throwsA(isA<TalkRecordApiException>()),
      );
    });
  });

  group('PUT grants（§4 全量提交 + §11.2 acl_revision）', () {
    test('非 owner 提交 403', () async {
      final service = TalkRecordShareFixtureScenarios.editorWithOwnGrant();
      await expectLater(
        service.putGrants('1001', grants: const [], ifMatch: 'acl:1'),
        throwsA(
          isA<TalkRecordApiException>().having((e) => e.code, 'code', 403),
        ),
      );
    });

    test('If-Match 错配 412', () async {
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      await expectLater(
        service.putGrants('1001', grants: const [], ifMatch: 'acl:stale'),
        throwsA(
          isA<TalkRecordApiException>().having(
            (e) => e.isRevisionStale,
            'isRevisionStale',
            true,
          ),
        ),
      );
    });

    test('成功替换名单并推进 acl_revision，新 ETag 可继续写', () async {
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      final before = (await service.grants('1001')).data;
      final next = <TalkRecordGrantInput>[
        for (final g in before)
          TalkRecordGrantInput(
            granteeUserId: g.granteeUserId,
            role: g.role,
            allowExport: g.allowExport,
            expiresAt: g.expiresAt,
          ),
        const TalkRecordGrantInput(
          granteeUserId: '9104',
          role: TalkRecordGrantRole.editor,
          allowExport: true,
        ),
      ];
      final saved = await service.putGrants(
        '1001',
        grants: next,
        ifMatch: 'acl:1',
      );
      expect(saved.data.length, 4);
      expect(saved.etag, 'acl:2');
      expect(service.entries.first.record.aclRevision, 2);
      // 同名重提交以最后为准（活跃 UNIQUE 语义）。
      final again = await service.putGrants(
        '1001',
        grants: [
          const TalkRecordGrantInput(
            granteeUserId: '9104',
            role: TalkRecordGrantRole.viewer,
          ),
          const TalkRecordGrantInput(
            granteeUserId: '9104',
            role: TalkRecordGrantRole.editor,
          ),
        ],
        ifMatch: 'acl:2',
      );
      expect(again.data.length, 1);
      expect(again.data.first.role, TalkRecordGrantRole.editor);
    });
  });

  group('DELETE grant（撤销立即生效，名单即时更新）', () {
    test('owner 撤销成功：名单移除 + acl_revision 推进', () async {
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      final result = await service.revokeGrant(
        '1001',
        '6001',
        ifMatch: 'acl:1',
      );
      expect(result.data.where((g) => g.id == '6001'), isEmpty);
      expect(result.etag, 'acl:2');
      final activeIds = (await service.grants('1001')).data
          .where((g) => g.isActive)
          .map((g) => g.id);
      expect(activeIds, isNot(contains('6001')));
    });

    test('撤销不存在/已撤销的 grant 404；非 owner 403', () async {
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      await expectLater(
        service.revokeGrant('1001', '9999', ifMatch: 'acl:1'),
        throwsA(isA<TalkRecordApiException>()),
      );
      final editorService =
          TalkRecordShareFixtureScenarios.editorWithOwnGrant();
      await expectLater(
        editorService.revokeGrant('1001', '6002', ifMatch: 'acl:1'),
        throwsA(isA<TalkRecordApiException>()),
      );
    });
  });

  group('share-candidates（候选≠授权凭证，§8）', () {
    test('排除创建者与已授权用户；q 过滤姓名/账号', () async {
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      final page = await service.shareCandidates('1001');
      expect(page.list.map((c) => c.userId), ['9104']);
      final zero = TalkRecordShareFixtureScenarios.ownerZeroGrants();
      final full = await zero.shareCandidates('1001');
      expect(full.list.length, 4);
      final hit = await zero.shareCandidates('1001', q: 'member2');
      expect(hit.list.single.displayName, '林早');
    });
  });

  group('share-card（标题最小化，§4）与发送 fixture', () {
    test('owner 生成受控卡片：类型/定位/最小化标题 + 计数', () async {
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      final card = await service.shareCard('1001');
      expect(card.cardType, 'talk_record_card');
      expect(card.recordId, '1001');
      expect(card.title, '面聊记录');
      expect(service.entries.first.shareCardCount, 1);
    });

    test('FixtureShareCardSender 成功记录卡片；失败不记录', () async {
      final ok = FixtureShareCardSender();
      final card = await TalkRecordShareFixtureScenarios.ownerZeroGrants()
          .shareCard('1001');
      expect(await ok.send(card), TalkRecordCardSendResult.sent);
      expect(ok.sentCards.single.raw['fixture'], isTrue);
      final failing = FixtureShareCardSender(shouldSucceed: false);
      expect(await failing.send(card), TalkRecordCardSendResult.failed);
      expect(failing.sentCards, isEmpty);
    });
  });

  group('场景构造器', () {
    test('ownerZeroGrants 默认 owner_only；editorWithOwnGrant 只读语义', () {
      final zero = TalkRecordShareFixtureScenarios.ownerZeroGrants();
      expect(zero.entries.first.record.visibility, 'owner_only');
      expect(zero.entries.first.isOwner, isTrue);
      final editor = TalkRecordShareFixtureScenarios.editorWithOwnGrant();
      expect(editor.entries.first.isOwner, isFalse);
    });
  });
}
