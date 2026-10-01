import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/presentation/department_parent_picker.dart';

const moving = OrganizationDepartment(
  id: '10',
  organizationId: '1',
  parentId: '20',
  name: '合成待移动部门',
);
const candidates = [
  moving,
  OrganizationDepartment(id: '20', organizationId: '1', name: '合成原部门'),
  OrganizationDepartment(
    id: '9007199254740993',
    organizationId: '1',
    name: '名称很长的合成目标部门用于验证移动布局不会溢出',
  ),
];

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('移动选择器 $brightness 双倍字号、长名称和 ID 无损', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      String? selected;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await showDepartmentParentPicker(
                      context,
                      moving: moving,
                      departments: candidates,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final choice = find.byKey(
        const Key('department-parent-9007199254740993'),
      );
      await tester.ensureVisible(choice);
      expect(tester.getSize(choice).height, greaterThanOrEqualTo(44));
      expect(
        tester
            .widget<CupertinoListTile>(
              find.byKey(const Key('department-parent-20')),
            )
            .onTap,
        isNull,
      );
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(selected, '9007199254740993');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('取消返回 null，选择企业根返回空 ID，两者不会混淆', (tester) async {
    String? selected = 'pending';
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showDepartmentParentPicker(
                    context,
                    moving: moving,
                    departments: candidates,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const Key('department-parent-root'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('department-parent-root')));
    await tester.pumpAndSettle();
    expect(selected, '');
  });
}
