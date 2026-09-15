/// APP-A09 — 真机企业+客服 E2E（具名用例骨架）
///
/// **BLOCKED_DEVICE**：本用例属真机门（amendment §3），本 run 本地未执行
/// ——工作区规则禁止模拟器做功能验证，A4 环境无真机挂载；由 A0 在真机
/// 门解锁后以如下命令执行（多设备环境必须显式 `-d`）：
///
/// ```
/// flutter test integration_test/enterprise/enterprise_cs_e2e_test.dart \
///   -d <真机设备ID> \
///   --dart-define=IMBOY_API_BASE=http://<lan-ip>:<隔离端口>
/// ```
///
/// 未注入 `--dart-define=IMBOY_API_BASE` 时本用例自动 skip（不产生红）。
///
/// 最小场景序列（amendment §3 APP-A09，13 步）：
///  1. 登录（个人域既有链路，拿 JWT）
///  2. 企业上下文（GET organizations → memberStatus=active）
///  3. 联系人（GET contacts，断言仅企业联系人、非个人好友）
///  4. 会话（GET conversations）
///  5. 发送消息（POST messages → accepted）
///  6. after_id 增量拉取（GET messages?after_id= → 只含增量）
///  7. delivery ACK（POST ack → 本地缓存真源仍在，delivery-only）
///  8. 附件上传（presign → PUT → confirm 重新鉴权）
///  9. 附件查看（GET assets/:id/content 鉴权代理，无 presigned 泄露）
/// 10. 客服 queue（GET /api/v1/cs/sessions/queue）
/// 11. 客服 claim（POST claim → active）
/// 12. 客服 transfer/close（POST transfer → accepted → close）
/// 13. 客服 rating + suspend 降级（POST rating；suspend 后企业入口只读、
///     新企业 API 请求 403）
///
/// 后端：本 run 隔离实例（经 IMBOY_API_BASE 注入，与共享 9700/9800/9801
/// 实例隔离）；A08/A09 证据须附 `adb devices` / `flutter devices` 输出。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/modules/customer_service/public.dart';
import 'package:imboy/modules/enterprise/public.dart';

/// 隔离后端地址（A0 真机执行时经 --dart-define 注入）。
const String kImboyApiBase = String.fromEnvironment('IMBOY_API_BASE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final bool backendConfigured = kImboyApiBase.isNotEmpty;

  testWidgets(
    'APP-A09 enterprise+cs e2e (BLOCKED_DEVICE skeleton)',
    (tester) async {
      // 未配置隔离后端时本用例已被 skip 参数整体跳过（不产生红）。

      // 步骤 1（登录）：复用个人域既有登录链路产出 JWT；本骨架只占位断言
      // TODO(A0/device-gate): 执行个人域登录并断言 accessToken 非空

      final enterpriseApi = EnterpriseApi();
      final csApi = CsApi();

      // 步骤 2（企业上下文）
      // TODO(A0/device-gate): GET organizations → 断言 memberStatus == active
      final orgs = await enterpriseApi.myOrganizations();
      expect(orgs, isNotEmpty);

      // 步骤 3（联系人）：仅企业联系人（EB-D04：不写个人好友）
      // TODO(A0/device-gate): 断言 contacts 列表非空且不落 user_friend
      final contacts = await enterpriseApi.contacts(orgs.first.id);
      expect(contacts, isNotEmpty);

      // 步骤 4（会话）
      final conversations = await enterpriseApi.conversations(orgs.first.id);
      expect(conversations, isNotEmpty);

      // 步骤 5（发送消息）
      // TODO(A0/device-gate): sendMessage → 断言 accepted 与服务端 accepted
      // 晚于 canonical 提交的服务端语义（客户端仅验形状）
      final sent = await enterpriseApi.sendMessage(
        orgs.first.id,
        conversations.first.id,
        content: 'e2e-ping',
      );
      expect(sent.id, isNotEmpty);

      // 步骤 6（after_id 增量）
      final incremental = await enterpriseApi.messages(
        orgs.first.id,
        conversations.first.id,
        afterId: sent.id,
      );
      expect(incremental.every((m) => m.id.compareTo(sent.id) > 0), isTrue);

      // 步骤 7（delivery ACK，delivery-only）
      // TODO(A0/device-gate): ack 后重拉全量，断言消息真源仍在
      await enterpriseApi.ackDelivered(
        orgs.first.id,
        conversations.first.id,
        sent.id,
      );

      // 步骤 8/9（附件 presign → PUT → confirm；content 鉴权代理查看）
      // TODO(A0/device-gate): PUT uploadUrl 上传字节并断言 confirm 后 status
      final presign = await enterpriseApi.presignAsset(
        orgs.first.id,
        fileName: 'e2e.txt',
        mime: 'text/plain',
        size: 9,
      );
      expect(presign.assetId, isNotEmpty);
      final asset = await enterpriseApi.confirmAsset(
        orgs.first.id,
        presign.assetId,
      );
      expect(asset.isPending, isFalse);

      // 步骤 10~12（客服 queue → claim → transfer/close）
      // TODO(A0/device-gate): 用 CsSessionMachine 镜像驱动并断言服务端状态
      final queue = await csApi.queue();
      expect(queue, isA<List<CsQueueItem>>());

      // 步骤 13（rating + suspend 降级）
      // TODO(A0/device-gate): close→rating 后由后端触发 suspend，断言：
      //  a) 企业 API 新请求 403（EnterpriseApiException.isForbidden）
      //  b) 企业入口页 isReadOnly 降级提示可见
      final machine = CsSessionMachine(sessionId: 'e2e-skeleton');
      expect(machine.status, CsSessionStatus.queued);
    },
    // BLOCKED_DEVICE：未注入隔离后端地址时整体 skip（真机门由 A0 解锁）
    skip: !backendConfigured,
  );
}
