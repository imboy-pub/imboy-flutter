/// ENT-UX-02 — 目标尺寸 widget test 无溢出（CS/企业域本 run 新增页面）。
///
/// 验收口径：Android/iOS 最小目标尺寸（kUxSmallViewport 320×568 档）渲染
/// 本 run 新增的治理页，无 RenderFlex overflow（tester.takeException 为
/// null）；输入触达 >=44 逻辑像素（CupertinoTextField 合同）。真机视觉
/// 结果由 DEVICE-01/02 代证（本卡不冒充）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/presentation/cs_governance_page.dart';

import '../ux_matrix/ux_harness.dart';

const String kOrgId = '7266418340025468951';

/// C05 默认工作区指针桩（治理面 workspace 门的客户端取数来源；缺失即
/// 页面诚实终态，渲染不出治理数据）。
const String kWsId = '7266418340025468952';

void main() {
  setUp(() async {
    await initUxHarness();
  });

  tearDown(teardownUxHarness);

  testWidgets('治理页：320×568 目标尺寸渲染无溢出', (tester) async {
    uxInstallStub(
      RouteStubAdapter([
        (
          '/default-workspace',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'organization_id': kOrgId,
                  'default_workspace_id': kWsId,
                },
              ),
            ),
          ],
        ),
        (
          '/seat-limit',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'organization_id': kOrgId,
                  'seat_limit': 5,
                  'used': 3,
                },
              ),
            ),
          ],
        ),
        (
          '/seats',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'seats': <Map<String, dynamic>>[],
                  'next_after_id': null,
                },
              ),
            ),
          ],
        ),
      ]),
    );
    await tester.pumpWidget(
      uxHost(
        const CsGovernancePage(orgId: kOrgId),
        const UxCombo(kUxSmallViewport),
      ),
    );
    await tester.pump();
    await settleUx(tester);
    expect(tester.takeException(), isNull, reason: '目标尺寸无 RenderFlex 溢出');
  });

  testWidgets('治理页：44pt 触达（输入控件高度合同）', (tester) async {
    uxInstallStub(
      RouteStubAdapter([
        (
          '/default-workspace',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'organization_id': kOrgId,
                  'default_workspace_id': kWsId,
                },
              ),
            ),
          ],
        ),
        (
          '/seat-limit',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'organization_id': kOrgId,
                  'seat_limit': 5,
                  'used': 3,
                },
              ),
            ),
          ],
        ),
        (
          '/seats',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'seats': <Map<String, dynamic>>[],
                  'next_after_id': null,
                },
              ),
            ),
          ],
        ),
      ]),
    );
    await tester.pumpWidget(
      uxHost(
        const CsGovernancePage(orgId: kOrgId),
        const UxCombo(kUxSmallViewport),
      ),
    );
    await pumpUntilUxFound(tester, find.text('调整额度'));
    // 调整额度对话框入口（AlertDialog 内 TextField）：打开对话框后量渲染高度。
    await tester.tap(find.text('调整额度'));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextField);
    expect(inputs, findsOneWidget, reason: '额度输入存在');
    for (final box in tester.renderObjectList<RenderBox>(inputs)) {
      expect(
        box.size.height >= 44,
        isTrue,
        reason: '输入触达 >=44（渲染高度 ${box.size.height}）',
      );
    }
  });
}
