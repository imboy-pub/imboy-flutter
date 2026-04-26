import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_quick_action_menu.dart';
import 'package:imboy/service/storage.dart';

/// MessageQuickActionMenu 静态 BottomSheet 菜单契约测试
///
/// 通过 Builder 注入 BuildContext + GestureDetector 触发，验证 BottomSheet 渲染。
///
/// 覆盖：
///   - showRetryMenu：重试 + 删除 ListTile + icon 颜色
///   - showRetryMenu：tap 触发 onRetry/onDelete 回调
///   - showQuickActionMenu：TextMessage → "复制" 渲染；通用项（转发/收藏/回复/删除）
///   - showQuickActionMenu：撤回项条件渲染（authorId == currentUid + 2 分钟内）
const _currentUid = 'tsid_uid_001';

Future<void> _pumpHostAndShow(
  WidgetTester tester,
  void Function(BuildContext) showFn,
) async {
  // showQuickActionMenu 渲染 7+ ListTile，需要充足的画布高度避免 RenderFlex overflow
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  late BuildContext captured;
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              captured = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  showFn(captured);
  await tester.pumpAndSettle();
}

TextMessage _textMsg({
  String authorId = _currentUid,
  DateTime? createdAt,
}) {
  return TextMessage(
    id: 'msg_1',
    authorId: authorId,
    text: 'hello',
    createdAt: createdAt ?? DateTime.now(),
  );
}

void main() {
  setUpAll(() async {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    await StorageService.to.setString(Keys.currentUid, _currentUid);
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
  });

  group('MessageQuickActionMenu.showRetryMenu', () {
    testWidgets('renders 重试 (refresh icon) + 删除 (delete icon)',
        (tester) async {
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showRetryMenu(
          context: ctx,
          message: _textMsg(),
          onRetry: () {},
          onDelete: () {},
        );
      });

      // i18n: chatResend = "重新发送", chatDeleteMessage = "删除消息"
      expect(find.text('重新发送'), findsOneWidget);
      expect(find.text('删除消息'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('tap 重新发送 → 触发 onRetry + 关闭 BottomSheet',
        (tester) async {
      var retryCount = 0;
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showRetryMenu(
          context: ctx,
          message: _textMsg(),
          onRetry: () => retryCount++,
          onDelete: () {},
        );
      });

      await tester.tap(find.text('重新发送'));
      await tester.pumpAndSettle();

      expect(retryCount, 1);
      // BottomSheet 关闭后文字消失
      expect(find.text('重新发送'), findsNothing);
    });

    testWidgets('tap 删除消息 → 触发 onDelete + 关闭', (tester) async {
      var deleteCount = 0;
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showRetryMenu(
          context: ctx,
          message: _textMsg(),
          onRetry: () {},
          onDelete: () => deleteCount++,
        );
      });

      await tester.tap(find.text('删除消息'));
      await tester.pumpAndSettle();

      expect(deleteCount, 1);
      expect(find.text('删除消息'), findsNothing);
    });
  });

  group('MessageQuickActionMenu.showQuickActionMenu', () {
    testWidgets('TextMessage → 渲染 复制 / 转发 / 收藏 / 回复 / 删除',
        (tester) async {
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showQuickActionMenu(
          context: ctx,
          message: _textMsg(),
          onReply: () {},
          onSaveFile: (_, _) async {},
          onCopy: () {},
          onForward: () {},
          onCollect: () {},
          onRevoke: () {},
          onDelete: () {},
        );
      });

      // i18n: buttonCopy="复制" / forward="转发" / favorites="收藏" / reply="回复" / buttonDelete="删除"
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('转发'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('回复'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('authorId == currentUid + 刚发送 → 显示 "撤回"', (tester) async {
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showQuickActionMenu(
          context: ctx,
          message: _textMsg(authorId: _currentUid, createdAt: DateTime.now()),
          onReply: () {},
          onSaveFile: (_, _) async {},
          onCopy: () {},
          onForward: () {},
          onCollect: () {},
          onRevoke: () {},
          onDelete: () {},
        );
      });

      // 撤回（i18n: revoke="撤回"）
      expect(find.text('撤回'), findsOneWidget);
    });

    testWidgets('authorId != currentUid → 不显示 "撤回"', (tester) async {
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showQuickActionMenu(
          context: ctx,
          message: _textMsg(authorId: 'other_uid'),
          onReply: () {},
          onSaveFile: (_, _) async {},
          onCopy: () {},
          onForward: () {},
          onCollect: () {},
          onRevoke: () {},
          onDelete: () {},
        );
      });

      expect(find.text('撤回'), findsNothing);
    });

    testWidgets('authorId == currentUid 但超过 2 分钟 → 不显示 "撤回"',
        (tester) async {
      // 3 分钟前发送
      final oldTime = DateTime.now().subtract(const Duration(minutes: 3));
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showQuickActionMenu(
          context: ctx,
          message: _textMsg(authorId: _currentUid, createdAt: oldTime),
          onReply: () {},
          onSaveFile: (_, _) async {},
          onCopy: () {},
          onForward: () {},
          onCollect: () {},
          onRevoke: () {},
          onDelete: () {},
        );
      });

      expect(find.text('撤回'), findsNothing);
    });

    testWidgets('tap 复制 → 触发 onCopy + 关闭 BottomSheet', (tester) async {
      var copyCount = 0;
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showQuickActionMenu(
          context: ctx,
          message: _textMsg(),
          onReply: () {},
          onSaveFile: (_, _) async {},
          onCopy: () => copyCount++,
          onForward: () {},
          onCollect: () {},
          onRevoke: () {},
          onDelete: () {},
        );
      });

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();

      expect(copyCount, 1);
      // 关闭后复制文字消失
      expect(find.text('复制'), findsNothing);
    });

    testWidgets('tap 撤回 → 触发 onRevoke', (tester) async {
      var revokeCount = 0;
      await _pumpHostAndShow(tester, (ctx) {
        MessageQuickActionMenu.showQuickActionMenu(
          context: ctx,
          message: _textMsg(authorId: _currentUid, createdAt: DateTime.now()),
          onReply: () {},
          onSaveFile: (_, _) async {},
          onCopy: () {},
          onForward: () {},
          onCollect: () {},
          onRevoke: () => revokeCount++,
          onDelete: () {},
        );
      });

      await tester.tap(find.text('撤回'));
      await tester.pumpAndSettle();

      expect(revokeCount, 1);
    });
  });
}
