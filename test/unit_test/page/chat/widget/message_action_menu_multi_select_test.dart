import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';

/// 长按菜单「多选」入口 + chat_multi_select_v1 灰度开关契约（W2-E）：
/// - onMultiSelect=null（flag 关闭 / 消息不可选）：菜单零变化，无「多选」按钮
/// - 提供 callback：按钮渲染；点击顺序 = 先 onClose() 再 onMultiSelect()
/// - e2eeFailed 占位行：不出现「多选」
/// - 开关语义：默认 false；replaceSnapshotForTest 可开；isEnabled 走编译清单恒 false
const _testMsg = TextMessage(id: 'msg_1', authorId: 'u_1', text: 'hi');

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onMultiSelect,
  bool e2eeFailed = false,
  List<String> calls = const [],
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageActionMenu(
              message: _testMsg,
              isSentByMe: false,
              e2eeFailed: e2eeFailed,
              onReply: () {},
              onCopy: () {},
              onEdit: () {},
              onDelete: () {},
              onForward: () {},
              onReaction: (_) {},
              onMultiSelect: onMultiSelect == null
                  ? null
                  : () => calls.add('multi_select'),
              onClose: () => calls.add('onClose'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('onMultiSelect=null：不渲染「多选」按钮（flag 关闭零 UI 变化）', (tester) async {
    await _pump(tester);
    expect(find.text(t.chat.multiSelect), findsNothing);
  });

  testWidgets('e2eeFailed 占位行：不渲染「多选」', (tester) async {
    await _pump(tester, e2eeFailed: true, onMultiSelect: () {});
    expect(find.text(t.chat.multiSelect), findsNothing);
  });

  testWidgets('onMultiSelect 提供且非 e2eeFailed：渲染「多选」并按序回调', (tester) async {
    final calls = <String>[];
    await _pump(tester, onMultiSelect: () {}, calls: calls);
    expect(find.text(t.chat.multiSelect), findsOneWidget);

    await tester.tap(find.text(t.chat.multiSelect));
    await tester.pump();
    // 现有菜单约定：先 onClose()（关菜单）再动作（顺序反了会 pop 掉
    // 动作刚 push 的路由，见 message_action_menu.dart 注释）。
    expect(calls, ['onClose', 'multi_select']);
  });

  group('chat_multi_select_v1 灰度开关语义（rollout flag）', () {
    tearDown(() => AppFeatureRegistry.replaceSnapshotForTest({}));

    test('默认 false（fail-closed）', () {
      AppFeatureRegistry.replaceSnapshotForTest({});
      expect(
        AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatMultiSelectV1),
        isFalse,
      );
    });

    test('replaceSnapshotForTest({chat_multi_select_v1: true}) 可开启', () {
      AppFeatureRegistry.replaceSnapshotForTest({
        FeatureKeys.chatMultiSelectV1: true,
      });
      expect(
        AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatMultiSelectV1),
        isTrue,
      );
    });

    test('isEnabled（编译清单路径）对该键恒 false —— 两种判定不可混用', () {
      AppFeatureRegistry.replaceSnapshotForTest({
        FeatureKeys.chatMultiSelectV1: true,
      });
      // chat_multi_select_v1 不在 compiledProductFeatures（产品组合清单由
      // 后端 manifest 生成，不应为 UI 灰度键改跨仓合同）。
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.chatMultiSelectV1),
        isFalse,
      );
    });

    test('空键 fail-closed', () {
      expect(AppFeatureRegistry.isRolloutFlagEnabled(''), isFalse);
    });
  });
}
