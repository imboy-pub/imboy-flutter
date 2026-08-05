import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_input.dart';

/// 真机实测：收藏 → 编辑标签，一输入就
/// `BOTTOM OVERFLOWED BY 24 PIXELS`，黄黑条纹盖住输入的文字。
/// 调用方把 TagInput 放在 Expanded 里（tight 高度），键盘弹起后高度骤减，
/// 而"已选标签 + 输入框 + 建议列表"是会长高的。
void main() {
  testWidgets('高度被压缩时可滚动，不溢出', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // 键盘弹起后 Expanded 只剩这么点高度（tight 约束，和真机同构）
          body: SizedBox(
            height: 100,
            child: TagInput(
              initialTags: const ['tag-a', 'tag-b', 'tag-c'],
              suggestedTags: const ['s1', 's2', 's3'],
              onTagsChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
