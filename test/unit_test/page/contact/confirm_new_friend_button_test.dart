import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/confirm_new_friend/confirm_new_friend_page.dart';
import 'package:imboy/theme/default/app_colors.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ConfirmNewFriendPage(
            from: '1',
            to: '2',
            msg: 'hello',
            nickname: 'friend',
            payload: '{}',
          ),
        ),
      ),
    );
  }

  void expectLabelInsideButton(WidgetTester tester) {
    final buttonFinder = find.widgetWithText(
      CupertinoButton,
      t.common.buttonAccomplish,
    );
    final labelFinder = find.text(t.common.buttonAccomplish);
    final buttonRect = tester.getRect(buttonFinder);
    final labelRect = tester.getRect(labelFinder);
    expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
    expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
    expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
    expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
  }

  testWidgets('确认好友提交按钮显示高对比度文案', (tester) async {
    await pumpPage(tester);

    final buttonFinder = find.widgetWithText(
      CupertinoButton,
      t.common.buttonAccomplish,
    );
    expect(buttonFinder, findsOneWidget);
    final button = tester.widget<CupertinoButton>(buttonFinder);
    expect(button.color, AppColors.primary);
    expect(button.padding, EdgeInsets.zero);

    final labelFinder = find.text(t.common.buttonAccomplish);
    final label = tester.widget<Text>(labelFinder);
    expect(label.style?.color, AppColors.onPrimary);

    expectLabelInsideButton(tester);
  });

  testWidgets('确认好友提交按钮在辅助功能大字体下不裁切文案', (tester) async {
    await pumpPage(tester, textScale: 3);
    expectLabelInsideButton(tester);

    final buttonRect = tester.getRect(
      find.widgetWithText(CupertinoButton, t.common.buttonAccomplish),
    );
    expect(buttonRect.height, greaterThan(50));
  });
}
