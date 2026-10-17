/// 阳性对照：确认矩阵断言机制真能捕获 overflow（防止假绿）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ux_matrix/ux_harness.dart';

void main() {
  testWidgets('sanity：Row 溢出被 takeException 捕获', (tester) async {
    await initUxHarness();
    addTearDown(teardownUxHarness);
    await pumpUxCombo(
      tester,
      Scaffold(body: Row(children: [Text('A' * 200)])),
      const UxCombo(Size(360, 800)),
    );
    expect(tester.takeException(), isNotNull, reason: '阳性对照：必须能捕获溢出');
  });

  testWidgets('sanity：正常页面不误报', (tester) async {
    await initUxHarness();
    addTearDown(teardownUxHarness);
    await pumpUxCombo(
      tester,
      Scaffold(body: ListView(children: const [Text('ok')])),
      const UxCombo(Size(360, 800)),
    );
    expect(tester.takeException(), isNull);
  });
}
