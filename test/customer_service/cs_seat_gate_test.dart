/// CSM-01（§12.5.1）— 客服工作台入口可见性判定单测
///
/// 四态覆盖：
/// 1. 合格坐席（active member + active customer_service assignment +
///    enabled seat）→ 可见；
/// 2. 普通用户（无 customer_service 职能 assignment）→ 不可见；
/// 3. disabled seat（席位停用）→ 不可见；
/// 4. 错 function（active assignment 但职能是 sales）→ 不可见。
///
/// 判定为纯 Dart（cs_seat_gate.dart），另覆盖掩码名纯函数与
/// csSeatGateFromUserData 组装（含 suspend/removed 组织降级）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/public.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

CsSeatGateInput _input({
  String memberStatus = 'active',
  String functionKey = kCsFunctionKey,
  String identityStatus = 'active',
  bool seatEnabled = true,
}) {
  return CsSeatGateInput(
    memberStatus: memberStatus,
    functionKey: functionKey,
    identityStatus: identityStatus,
    seatEnabled: seatEnabled,
  );
}

void main() {
  group('CSM-01 入口判定四态（csWorkspaceEntryVisible）', () {
    test('1 合格坐席：active member + active cs assignment + enabled seat → 可见', () {
      expect(csWorkspaceEntryVisible(_input()), isTrue);
    });

    test('2 普通用户：无 customer_service 职能 assignment → 不可见', () {
      // functionKey 为空（无任何 assignment）
      expect(csWorkspaceEntryVisible(_input(functionKey: '')), isFalse);
      // functionKey 为 null-ish 字符串同样不可见
      expect(
        csWorkspaceEntryVisible(_input(functionKey: 'unknown_function')),
        isFalse,
      );
    });

    test('3 disabled seat：席位停用 → 不可见（其余全合格）', () {
      expect(csWorkspaceEntryVisible(_input(seatEnabled: false)), isFalse);
    });

    test('4 错 function：active assignment 但职能不是 customer_service → 不可见', () {
      expect(csWorkspaceEntryVisible(_input(functionKey: 'sales')), isFalse);
      // 职能精确匹配：前缀/包含变体一律拒绝（fail-closed 与集）
      expect(
        csWorkspaceEntryVisible(_input(functionKey: 'customer_service_v2')),
        isFalse,
      );
    });

    test('fail-closed 补充：非 active member / 非 active assignment → 不可见', () {
      for (final status in ['suspended', 'removed', '']) {
        expect(
          csWorkspaceEntryVisible(_input(memberStatus: status)),
          isFalse,
          reason: 'memberStatus=$status 应不可见',
        );
        expect(
          csWorkspaceEntryVisible(_input(identityStatus: status)),
          isFalse,
          reason: 'identityStatus=$status 应不可见',
        );
      }
    });
  });

  group('CSM-01 会话内用户域数据组装（csSeatGateFromUserData）', () {
    EnterpriseOrg orgWith(String status) => EnterpriseOrg(
      id: '7266418340025468901',
      name: 'Acme',
      memberStatus: EnterpriseMemberStatus.parse(status),
    );

    BusinessIdentity identity(String fn, String status) => BusinessIdentity(
      id: '7266418340025468902',
      organizationId: '7266418340025468901',
      functionKey: fn,
      status: status,
    );

    test('合格坐席：可见', () {
      expect(
        csSeatGateFromUserData(
          org: orgWith('active'),
          identities: [identity(kCsFunctionKey, 'active')],
        ),
        isTrue,
      );
    });

    test('普通用户：无组织 / 无 cs assignment → 不可见', () {
      expect(csSeatGateFromUserData(org: null, identities: const []), isFalse);
      expect(
        csSeatGateFromUserData(
          org: orgWith('active'),
          identities: [identity('sales', 'active')],
        ),
        isFalse,
      );
    });

    test('disabled seat：seatEnabled=false → 不可见', () {
      expect(
        csSeatGateFromUserData(
          org: orgWith('active'),
          identities: [identity(kCsFunctionKey, 'active')],
          seatEnabled: false,
        ),
        isFalse,
      );
    });

    test('组织 suspend/removed：member 非 active → 不可见（降级）', () {
      for (final status in ['suspended', 'removed']) {
        expect(
          csSeatGateFromUserData(
            org: orgWith(status),
            identities: [identity(kCsFunctionKey, 'active')],
          ),
          isFalse,
          reason: 'memberStatus=$status 应不可见',
        );
      }
    });

    test('assignment 停用（status != active）→ 不可见', () {
      expect(
        csSeatGateFromUserData(
          org: orgWith('active'),
          identities: [identity(kCsFunctionKey, 'disabled')],
        ),
        isFalse,
      );
    });
  });

  group('CSM-01 客户掩码名（csMaskContactName）', () {
    test('常规名：保留首字符 + ** 掩码', () {
      expect(csMaskContactName('张三丰'), '张**');
      expect(csMaskContactName('Alice'), 'A**');
    });

    test('空名 / 单字符：不泄露额外信息', () {
      expect(csMaskContactName(''), '**');
      expect(csMaskContactName('   '), '**');
      expect(csMaskContactName('张'), '张*');
    });
  });
}
