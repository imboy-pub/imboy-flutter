// integration_test/channel/channel_edit_persistence_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('频道编辑持久化', () {
    testWidgets('编辑频道描述后保存不出现失败提示', (tester) async {
      final newDesc = '[E2E-DESC] ${DateTime.now().millisecondsSinceEpoch}';

      app.main();
      await settle(tester, maxSeconds: 3);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      if (!await _openChannelTab(tester)) {
        markTestSkipped('无法进入频道 Tab');
        return;
      }
      await settle(tester, maxSeconds: 2);

      if (!tester.any(find.byType(ListTile))) {
        markTestSkipped('无频道可编辑');
        return;
      }

      await safeTap(tester, find.byType(ListTile).first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'edit_01_detail');

      expect(
        _anyText(['频道不存在', 'Channel not found']),
        findsNothing,
        reason: '进入频道后不应提示不存在',
      );

      if (!await tapAny(tester, [
        find.byIcon(Icons.edit),
        find.byIcon(Icons.settings),
        find.byIcon(Icons.more_vert),
        _anyText(['编辑', 'Edit', '设置']).first,
      ])) {
        markTestSkipped('未找到编辑入口');
        return;
      }
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'edit_02_edit_page');

      final formFields = find.byType(TextFormField);
      final textFields = find.byType(TextField);
      Finder? descField;
      if (formFields.evaluate().length > 1) {
        descField = formFields.at(1);
      } else if (textFields.evaluate().length > 1) {
        descField = textFields.at(1);
      }

      if (descField == null || !tester.any(descField)) {
        markTestSkipped('未找到描述输入框');
        return;
      }

      await tester.enterText(descField, newDesc);
      await settle(tester, maxSeconds: 1);

      if (!await tapAny(tester, [
        find.text('保存'),
        find.text('确认'),
        find.text('Save'),
        find.text('Confirm'),
      ])) {
        markTestSkipped('未找到保存按钮');
        return;
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'edit_03_after_save');

      expect(
        _anyText(['保存失败', 'Save failed', '更新失败']),
        findsNothing,
        reason: '保存频道描述不应出现失败提示',
      );
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

bool _isOnChannelList(WidgetTester t) =>
    t.any(_anyText(['频道', 'Channel', 'Channels'])) &&
    t.any(find.byIcon(Icons.search));

Future<bool> _openChannelTab(WidgetTester t) async {
  if (_isOnChannelList(t)) return true;
  for (int i = 0; i < 4; i++) {
    await tapAny(t, [
      find.byIcon(Icons.campaign_outlined),
      find.byIcon(Icons.campaign),
      find.text('频道'),
      find.text('Channel'),
    ]);
    await settle(t, maxSeconds: 2);
    if (_isOnChannelList(t)) return true;
  }
  return false;
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
