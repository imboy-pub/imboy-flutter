/// `ImBoyListTile` 的 leading 后间距是全仓多个列表页分隔线缩进的推导基数。
///
/// 这个数字改了会同时错开 5 个页面，且错位只有 2pt——肉眼扫一眼看不出来，
/// 但分隔线和文字左缘不齐在真机上是能看见的。历史上它就是 14，导致
/// contact(72) / group_list(76) / people_nearby(84) 三组页面的文字全都比
/// 自己的分隔线右移 2pt。
///
/// 所以这里既断言间距本身，也把「页面 padding + 头像 + 间距 == 分隔线缩进」
/// 这条推导对每个实际取值验一遍——哪天有人改了间距，这里会直接指出是哪几个
/// 页面会跟着错。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/theme/default/app_spacing.dart';

void main() {
  testWidgets('leading 与标题之间是 AppSpacing.medium', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImBoyListTile(
            leading: const SizedBox(
              key: Key('probe_leading'),
              width: 44,
              height: 44,
            ),
            title: const Text('张三'),
          ),
        ),
      ),
    );
    await tester.pump();

    final leadingRight = tester
        .getBottomRight(find.byKey(const Key('probe_leading')))
        .dx;
    final titleLeft = tester.getTopLeft(find.text('张三')).dx;

    expect(
      titleLeft - leadingRight,
      moreOrLessEquals(AppSpacing.medium, epsilon: 0.5),
      reason: 'leading 后间距偏离规范，用到本组件的列表页分隔线会与文字对不齐',
    );
  });

  test('各页分隔线缩进都能由「16 + 头像 + 间距」推导出来', () {
    // (页面, 头像尺寸, 该页 Divider 的左缩进)
    const cases = <(String, double, double)>[
      ('contact_page', 44, 72),
      ('group_list_page / group_select_page', 48, 76),
      ('mention_list_page', 48, 76),
      ('people_nearby_page / recently_registered_user_page', 56, 84),
      ('conversation_page', 56, 84),
    ];

    for (final (page, avatar, indent) in cases) {
      expect(
        AppSpacing.regular + avatar + AppSpacing.medium,
        indent,
        reason: '$page 的分隔线缩进 $indent 与实际文字左缘对不上',
      );
    }
  });
}
