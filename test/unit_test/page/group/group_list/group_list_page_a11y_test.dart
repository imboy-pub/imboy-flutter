/// 群列表页顶部刷新按钮的读屏契约。
///
/// 这是页内唯一的纯图标控件：没有文字，不补 semanticLabel 的话读屏用户
/// 在那个位置只听到"按钮"，不知道按下去会发生什么（DESIGN.md 11.4）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_list/group_list_page.dart';
import 'package:imboy/page/group/group_list/group_list_provider.dart';

/// 注入空列表 State，让页面 initData 走空数据分支。
///
/// initData 已收编到页面 State（group_list_page.dart），不在 Notifier 上；
/// 覆盖 build() 返回空列表即可让页面数据装载短路为空态。
class _FakeGroupListNotifier extends GroupListNotifier {
  @override
  GroupListState build() =>
      const GroupListState(groupList: [], isLoading: false);
}

void main() {
  testWidgets('顶部刷新按钮读得出「刷新」', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupListProvider.overrideWith(_FakeGroupListNotifier.new)],
        child: TranslationProvider(
          child: const MaterialApp(home: GroupListPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(CupertinoIcons.refresh), findsOneWidget);
    expect(
      find.bySemanticsLabel(t.groupList.refresh),
      findsWidgets,
      reason: '刷新按钮没有读屏标签，读屏用户只会听到一个「按钮」',
    );

    handle.dispose();
  });
}
