/// 个人壳消息页左上角头像按钮（空间切换抽屉入口）。
///
/// 整页挂载不在测试 ROI 内（见 bottom_navigation_page_test 文件头），这里
/// 只验按钮本体：触控盒尺寸、点击回调、无头像/未登录两态、首字母居中
/// （回归钉：AvatarFallbackContent 是裸 Text，容器曾缺 alignment 导致字母
/// 偏到左上角）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_sizes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required UserModel? user,
  required VoidCallback onTap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(user)],
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: PersonalShellDrawerAvatarButton(onTap: onTap)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const key = ValueKey('personal-shell-drawer-avatar');

  testWidgets('无头像：首字母回退且在 32pt 盒内居中，触控盒 ≥ 40pt，点击回调', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      user: UserModel(uid: '1', account: 'synthetic', nickname: '合成用户'),
      onTap: () => taps++,
    );

    final button = tester.getRect(find.byKey(key));
    expect(button.width, greaterThanOrEqualTo(AppSizes.touchTargetCompact));
    expect(button.height, greaterThanOrEqualTo(AppSizes.touchTargetCompact));

    final fallback = find.byType(AvatarFallbackContent);
    expect(fallback, findsOneWidget);
    expect(find.text('合'), findsOneWidget);
    final box = tester.getRect(
      find.ancestor(of: fallback, matching: find.byType(Container)).first,
    );
    expect(box.width, AppSizes.avatarSizeSmall);
    expect(box.height, AppSizes.avatarSizeSmall);
    final letter = tester.getRect(find.text('合'));
    expect(letter.center.dx, moreOrLessEquals(box.center.dx, epsilon: 1.0));
    expect(letter.center.dy, moreOrLessEquals(box.center.dy, epsilon: 1.0));

    await tester.tap(find.byKey(key));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  // 有头像态走远端图加载（测试环境无网络会留下重试 Timer），不在此覆盖；
  // 该分支与 MineProfile 头像同一 avatarImageProvider 链路，真机验收。

  testWidgets('未登录（user 为 null）仍可渲染，不抛异常', (tester) async {
    await _pump(tester, user: null, onTap: () {});
    expect(find.byKey(key), findsOneWidget);
    expect(find.byType(AvatarFallbackContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
