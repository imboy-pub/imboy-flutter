import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_page.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_provider.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/theme/theme_manager.dart';

/// 真机复现：标签详情页「更多」菜单弹层为固定高度 172 的 Column。
/// 键盘弹出（或弹层可用高度收缩）后，固定高度超出可用空间，
/// `RenderFlex overflowed by 58 pixels on the bottom`。
/// 修复：Column 外包 SingleChildScrollView，收缩时可滚动而非溢出，
/// 静止时高度不变、视觉不变。
void main() {
  testWidgets('键盘挤压（bottom sheet 场景）下弹层不溢出', (tester) async {
    // 页面 build 里 searchBar 会读 ThemeManager，须注入容器（与 run.dart 对齐）
    ThemeManager.instance.setProviderContainer(ProviderContainer());

    // 模拟键盘弹出：先压出 viewInsets，再打开弹层，复刻「弹层收缩」路径
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.reset);

    final tag = UserTagModel(
      userId: 1,
      tagId: 1,
      scene: 1,
      name: 'test',
      subtitle: '',
      refererTime: 0,
      updatedAt: 0,
      createdAt: 0,
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            contactTagDetailProvider.overrideWith(
              _FakeContactTagDetailNotifier.new,
            ),
          ],
          child: MaterialApp(home: ContactTagDetailPage(tag: tag)),
        ),
      ),
    );
    await tester.pump();

    // 打开「更多」弹层
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}

/// 空实现：不触发真实网络请求（loadTagData 内部会调 UserTagApi）。
class _FakeContactTagDetailNotifier extends ContactTagDetailNotifier {
  @override
  ContactTagDetailState build() => const ContactTagDetailState();

  @override
  Future<void> loadTagData({
    required String tagName,
    required int refererTime,
    required int tagId,
  }) async {}
}
