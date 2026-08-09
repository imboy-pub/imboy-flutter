import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_page.dart';

/// 真机复现：contact_tag_detail 更多菜单 →「修改标签」→ showModalBottomSheet
/// 打开 UserTagSavePage，输入框 autofocus 弹键盘 → 可用高度骤减，
/// 旧代码 body 是固定 Column（mainAxisSize.min），直接
/// `RenderFlex overflowed by 58 pixels on the bottom`。
/// 修复：Column 外包 SingleChildScrollView，高度不足时可滚动而非溢出。
void main() {
  testWidgets('键盘挤压（bottom sheet 场景）下不溢出，可滚动', (tester) async {
    // 模拟键盘弹出：resizeToAvoidBottomInset 的 Scaffold 会把 body 压到很小
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  height: 300,
                  child: UserTagSavePage(scene: 'friend'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
