import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_input.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 真机实测（BUG#39 第二层）：修好 TagInput 内部滚动后，
/// 加到第二个标签时页面底部又 `BOTTOM OVERFLOWED BY 16 PIXELS` ——
/// 统计卡 + 快捷操作栏 + 底部保存按钮都是固定高度，键盘弹起后
/// Expanded 收缩到 0 也补不上差额。
///
/// 这里复刻 tag_relation_page 的骨架，锁住"上半部分必须可滚"这个结构约束。
void main() {
  testWidgets('固定高度块 + 键盘挤压时整体不溢出', (tester) async {
    Widget fixedBlock(double h) => SizedBox(height: h, width: double.infinity);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // 键盘弹起后 body 只剩这么高
          body: SizedBox(
            height: 300,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        fixedBlock(150), // 统计卡
                        fixedBlock(90), // 快捷操作栏
                        AppSpacing.verticalRegular,
                        TagInput(
                          initialTags: const ['a', 'b'],
                          suggestedTags: const ['s1'],
                          onTagsChanged: (_) {},
                        ),
                        AppSpacing.verticalRegular,
                      ],
                    ),
                  ),
                ),
                fixedBlock(80), // 底部保存按钮
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
