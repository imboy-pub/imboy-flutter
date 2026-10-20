import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/file/group_attachment_tile.dart';
import 'package:imboy/page/group/task/group_task_form.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('resource content remains readable at $width $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opens = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ResourcePageLayout(
                child: ListView(
                  children: [
                    GroupAttachmentTile(
                      name: 'Project planning document with a long name.pdf',
                      category: 'Document',
                      size: '2 MB',
                      createdAt: '2026-10-20T12:00:00Z',
                      onOpen: () => opens++,
                      deleteLabel: 'Delete',
                    ),
                    const ListTile(
                      title: Text('Members and permissions'),
                      subtitle: Text('Only authorized resources are listed'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byType(GroupAttachmentTile);
        final rect = tester.getRect(row);
        expect(rect.width, lessThanOrEqualTo(680));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        await tester.tap(row);
        expect(opens, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'task sheet keeps confirm visible above keyboard and trims input',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      GroupTaskFormResult? result;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await showGroupTaskFormDialog(
                    context,
                    dialogTitle: 'Create task',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        '  Design review  ',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('create_task_confirm'));
      expect(tester.getRect(confirm).bottom, lessThan(844 - 300));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result?.title, 'Design review');
      expect(tester.takeException(), isNull);
    },
  );
}
