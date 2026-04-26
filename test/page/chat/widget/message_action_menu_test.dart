import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';

/// MessageActionMenu 长按操作菜单 widget 契约测试
///
/// 覆盖：
///   - 6 个 reaction emoji 渲染（👍 ❤️ 😂 😮 😢 🙏）+ tap 触发 onReaction
///   - 通用操作（引用/复制/转发）始终可见
///   - 收藏（onCollect 非 null 才显示）
///   - 保存（onSave 非 null 才显示）
///   - 发送者可见操作：撤回 / 重试 / 编辑（canEdit）/ 删除（destructive）
///   - 接收者可见操作：仅"删除我的消息"
///   - tap 触发对应回调（且自动 onClose）
const _testMsg = TextMessage(
  id: 'msg_1',
  authorId: 'u_1',
  text: 'hi',
);

Future<void> _pump(
  WidgetTester tester, {
  required bool isSentByMe,
  bool canEdit = false,
  VoidCallback? onReply,
  VoidCallback? onCopy,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onForward,
  void Function(String)? onReaction,
  VoidCallback? onRevoke,
  VoidCallback? onSave,
  VoidCallback? onCollect,
  VoidCallback? onDeleteForEveryone,
  VoidCallback? onRetry,
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageActionMenu(
              message: _testMsg,
              isSentByMe: isSentByMe,
              canEdit: canEdit,
              onReply: onReply ?? () {},
              onCopy: onCopy ?? () {},
              onEdit: onEdit ?? () {},
              onDelete: onDelete ?? () {},
              onForward: onForward ?? () {},
              onReaction: onReaction ?? (_) {},
              onRevoke: onRevoke,
              onSave: onSave,
              onCollect: onCollect,
              onDeleteForEveryone: onDeleteForEveryone,
              onRetry: onRetry,
              onClose: onClose,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  group('MessageActionMenu reaction section', () {
    testWidgets('渲染 6 个 reaction emoji（👍 ❤️ 😂 😮 😢 🙏）', (tester) async {
      await _pump(tester, isSentByMe: false);
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);
      expect(find.text('😮'), findsOneWidget);
      expect(find.text('😢'), findsOneWidget);
      expect(find.text('🙏'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('tap reaction → 触发 onReaction(emoji) + onClose', (
      tester,
    ) async {
      String? lastEmoji;
      var closeCount = 0;
      await _pump(
        tester,
        isSentByMe: false,
        onReaction: (e) => lastEmoji = e,
        onClose: () => closeCount++,
      );

      await tester.tap(find.byKey(const ValueKey('reaction_❤️')));
      await tester.pump();

      expect(lastEmoji, '❤️');
      expect(closeCount, 1);
      await _unmount(tester);
    });
  });

  group('MessageActionMenu common actions (always visible)', () {
    testWidgets('引用/复制/转发 文字始终渲染', (tester) async {
      await _pump(tester, isSentByMe: false);
      expect(find.text('引用'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('转发'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('tap 引用 → onReply + onClose', (tester) async {
      var replyCount = 0;
      var closeCount = 0;
      await _pump(
        tester,
        isSentByMe: false,
        onReply: () => replyCount++,
        onClose: () => closeCount++,
      );

      await tester.tap(find.text('引用'));
      await tester.pump();

      expect(replyCount, 1);
      expect(closeCount, 1);
      await _unmount(tester);
    });

    testWidgets('tap 复制 → onCopy + onClose', (tester) async {
      var copyCount = 0;
      await _pump(
        tester,
        isSentByMe: false,
        onCopy: () => copyCount++,
      );

      await tester.tap(find.text('复制'));
      await tester.pump();
      expect(copyCount, 1);
      await _unmount(tester);
    });

    testWidgets('tap 转发 → onForward + onClose', (tester) async {
      var forwardCount = 0;
      await _pump(
        tester,
        isSentByMe: false,
        onForward: () => forwardCount++,
      );

      await tester.tap(find.text('转发'));
      await tester.pump();
      expect(forwardCount, 1);
      await _unmount(tester);
    });
  });

  group('MessageActionMenu optional actions', () {
    testWidgets('onCollect=null → "收藏" 不渲染', (tester) async {
      await _pump(tester, isSentByMe: false);
      expect(find.text('收藏'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('onCollect 非 null → "收藏" 渲染 + tap 触发回调', (tester) async {
      var collectCount = 0;
      await _pump(
        tester,
        isSentByMe: false,
        onCollect: () => collectCount++,
      );

      expect(find.text('收藏'), findsOneWidget);
      await tester.tap(find.text('收藏'));
      await tester.pump();
      expect(collectCount, 1);
      await _unmount(tester);
    });

    testWidgets('onSave=null → "保存" 不渲染', (tester) async {
      await _pump(tester, isSentByMe: false);
      expect(find.text('保存'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('onSave 非 null → "保存" 渲染 + tap 触发回调', (tester) async {
      var saveCount = 0;
      await _pump(
        tester,
        isSentByMe: false,
        onSave: () => saveCount++,
      );

      expect(find.text('保存'), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(saveCount, 1);
      await _unmount(tester);
    });
  });

  group('MessageActionMenu sender (isSentByMe=true)', () {
    testWidgets('isSentByMe=true → 显示"删除"按钮（destructive）', (tester) async {
      await _pump(tester, isSentByMe: true);
      // i18n: buttonDelete = "删除"
      expect(find.text('删除'), findsOneWidget);
      // 不显示 "删除我的消息"（接收者专属）
      expect(find.text('删除我的消息'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('onRevoke 非 null → "撤回" 渲染 + tap 触发回调', (tester) async {
      var revokeCount = 0;
      await _pump(
        tester,
        isSentByMe: true,
        onRevoke: () => revokeCount++,
      );

      expect(find.text('撤回'), findsOneWidget);
      await tester.tap(find.text('撤回'));
      await tester.pump();
      expect(revokeCount, 1);
      await _unmount(tester);
    });

    testWidgets('onRetry 非 null → "重试" 渲染 + tap 触发回调', (tester) async {
      var retryCount = 0;
      await _pump(
        tester,
        isSentByMe: true,
        onRetry: () => retryCount++,
      );

      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(retryCount, 1);
      await _unmount(tester);
    });

    testWidgets('canEdit=true → "编辑" 渲染 + tap 触发回调', (tester) async {
      var editCount = 0;
      await _pump(
        tester,
        isSentByMe: true,
        canEdit: true,
        onEdit: () => editCount++,
      );

      expect(find.text('编辑'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pump();
      expect(editCount, 1);
      await _unmount(tester);
    });

    testWidgets('canEdit=false → "编辑" 不渲染', (tester) async {
      await _pump(tester, isSentByMe: true);
      expect(find.text('编辑'), findsNothing);
      await _unmount(tester);
    });
  });

  group('MessageActionMenu receiver (isSentByMe=false)', () {
    testWidgets('isSentByMe=false → 显示"删除我的消息"（接收者专属）',
        (tester) async {
      await _pump(tester, isSentByMe: false);
      // i18n: deleteForMe = "删除我的消息"
      expect(find.text('删除我的消息'), findsOneWidget);
      // 接收者不应看到撤回/重试/编辑/删除
      expect(find.text('撤回'), findsNothing);
      expect(find.text('重试'), findsNothing);
      expect(find.text('编辑'), findsNothing);
      // 注意：buttonDelete = "删除"，受发送者独占
      expect(find.text('删除'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('tap "删除我的消息" → onDelete + onClose', (tester) async {
      var deleteCount = 0;
      var closeCount = 0;
      await _pump(
        tester,
        isSentByMe: false,
        onDelete: () => deleteCount++,
        onClose: () => closeCount++,
      );

      await tester.tap(find.text('删除我的消息'));
      await tester.pump();

      expect(deleteCount, 1);
      expect(closeCount, 1);
      await _unmount(tester);
    });

    testWidgets('isSentByMe=false 时 onRevoke 即使非 null 也不显示',
        (tester) async {
      await _pump(
        tester,
        isSentByMe: false,
        onRevoke: () {},
      );
      // 撤回是发送者专属，接收者绝不显示（即使 onRevoke 非 null）
      expect(find.text('撤回'), findsNothing);
      await _unmount(tester);
    });
  });
}
