import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/schedule/group_schedule_create_dialog.dart';

void main() {
  testWidgets('日程回显日期和 24 小时时间，空标题不能创建', (tester) async {
    final start = DateTime.now().add(const Duration(days: 2));
    final initial = DateTime(start.year, start.month, start.day, 10, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              GroupScheduleCreateDialog(initialStart: initial),
        ),
      ),
    );
    expect(find.text('10:30'), findsOneWidget);
    final confirm = tester
        .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
        .last;
    expect(confirm.onPressed, isNull);
    await tester.enterText(find.byType(CupertinoTextField), '团队例会');
    await tester.pump();
    expect(
      tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .last
          .onPressed,
      isNotNull,
    );
    await tester.tap(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.calendar),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:30'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    final context = tester.element(find.byType(TimePickerDialog));
    expect(MediaQuery.of(context).alwaysUse24HourFormat, isTrue);
  });
}
