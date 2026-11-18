@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/page/error/init_error_page.dart';
import 'package:imboy/service/web_writer_gate.dart';

void main() {
  for (final kind in WebWriterFailureKind.values) {
    testWidgets('$kind requests document reload rather than bootstrap retry', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        InitErrorPage(
          error: WebWriterGateFailure(kind),
          onRetry: () async {
            retries++;
          },
        ),
      );
      expect(find.text('Web 暂时无法打开'), findsOneWidget);
      expect(find.textContaining('不要清除浏览器数据'), findsOneWidget);
      expect(find.textContaining('重新安装'), findsNothing);
      await tester.tap(find.text('刷新页面'));
      await tester.pumpAndSettle();
      // The VM facade cannot reload a browser; it still must not retry startup.
      expect(retries, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('native/general failure retains its original retry callback', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      InitErrorPage(
        error: StateError('synthetic initialization failure'),
        onRetry: () async {
          retries++;
        },
      ),
    );
    expect(find.text('应用初始化失败'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
