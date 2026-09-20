/// CSM-01（§12.5.1）+ APP-M01-A01 — 客服工作台入口可见性判定单测
///
/// 四态覆盖（csWorkspaceEntryVisible 纯函数与集）：
/// 1. 合格坐席（active member + active customer_service assignment +
///    enabled seat）→ 可见；
/// 2. 普通用户（无 customer_service 职能 assignment）→ 不可见；
/// 3. disabled seat（席位停用）→ 不可见；
/// 4. 错 function（active assignment 但职能是 sales）→ 不可见。
///
/// APP-M01-A01：入口判定数据源切换为 seat-contexts 权威聚合——
/// `csEntryVisibleFromContexts`（任一「active assignment + enabled seat」
/// 上下文即可见；空/全 disabled/全缺 assignment → fail-closed 不可见），
/// 替代旧「首个 Org 的 enterprise 身份列表近似推断」组装
///（csSeatGateFromUserData 已随入口改造移除）。
///
/// 判定为纯 Dart（cs_seat_gate.dart），另覆盖掩码名纯函数。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/public.dart';

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

  group('APP-M01-A01 seat-contexts 组装（csEntryVisibleFromContexts）', () {
    test('合格坐席：active assignment + enabled seat → 可见', () {
      expect(
        csEntryVisibleFromContexts([_FakeContext(eligible: true)]),
        isTrue,
      );
    });

    test('普通用户：无 assignment（identity 缺失）→ 不可见', () {
      expect(
        csEntryVisibleFromContexts([_FakeContext(identityId: '')]),
        isFalse,
      );
    });

    test('disabled seat：seatEnabled=false → 不可见', () {
      expect(
        csEntryVisibleFromContexts([_FakeContext(seatEnabled: false)]),
        isFalse,
      );
    });

    test('多 Org：任一上下文合格即可见（不固定首个 Org）', () {
      expect(
        csEntryVisibleFromContexts([
          _FakeContext(eligible: false),
          _FakeContext(eligible: true),
        ]),
        isTrue,
      );
      expect(
        csEntryVisibleFromContexts([
          _FakeContext(eligible: true),
          _FakeContext(eligible: false),
        ]),
        isTrue,
      );
    });

    test('空上下文列表（无 active member Org / 请求失败兜底）→ 不可见', () {
      expect(csEntryVisibleFromContexts(const []), isFalse);
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

/// csEntryVisibleFromContexts 的最小结构桩（CsSeatContextLike）。
class _FakeContext implements CsSeatContextLike {
  @override
  final bool isEligible;

  _FakeContext({
    bool eligible = true,
    String identityId = 'identity',
    bool seatEnabled = true,
  }) : isEligible = eligible && identityId.isNotEmpty && seatEnabled;
}
