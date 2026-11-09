/// M04 内容完整性 App 腿补测（IMBOY_AUTOTEST_V2.1 / AT04）— 断言 1 & 2
///
/// 与后端 M04（无权操作拒绝 / 时间窗校验）61 项 PASS 对账的 App 侧 UI 面：
///
///   断言 1（无权操作 UI 拒绝反馈）：
///     - C13 禁言用户点「编辑」→ 立即 toast「你已被禁言」，
///       不进编辑态（editing id 不变）、不回填输入框、不抢焦点；
///     - 接收者视角长按菜单永不出现「编辑 / 撤回」（作者专属，
///       即使误传 canEdit=true / onRevoke 也被 UI 门禁拦下）。
///
///   断言 2（时间窗过期 UI 禁止编辑）：
///     - 编辑窗（15 分钟）过期 → canEdit=false → 菜单不渲染「编辑」；
///     - 撤回窗（2 分钟）过期 → revokeMessage 前端短路（S1），
///       toast「超过 2 分钟，无法撤回」，路由不被弹掉、不发网络请求。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/message_action_handler.dart';
import 'package:imboy/page/chat/chat/utils/chat_page_utils.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/service/storage.dart';

const _meUid = '100';

ConversationModel _conversation() => ConversationModel(
  id: 1,
  peerId: '200',
  avatar: '',
  title: '',
  subtitle: '',
  type: 'C2C',
  msgType: 'text',
  unreadNum: 0,
);

Future<void> _pumpMenu(
  WidgetTester tester, {
  required TextMessage message,
  required bool canEdit,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageActionMenu(
              message: message,
              isSentByMe: true,
              canEdit: canEdit,
              onRevoke: () {},
              onReply: () {},
              onCopy: () {},
              onEdit: () {},
              onDelete: () {},
              onForward: () {},
              onReaction: (_) {},
              onClose: () {},
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({Keys.currentUid: _meUid});
    await StorageService.init();
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  // ================= 断言 1：无权操作 UI 拒绝反馈 =================
  group('M04-1 禁言用户操作被 UI 拒绝（C13）', () {
    testWidgets('禁言点「编辑」→ toast「你已被禁言」，不进编辑态、不回填输入框', (tester) async {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);
      final chatInputKey = GlobalKey<ChatInputState>();
      String? editingMessageId;
      final message = TextMessage(
        id: 'msg-mute-edit',
        authorId: _meUid,
        text: 'my own text',
        // 时间窗内（编辑窗 15 分钟以内），排除时间窗干扰：
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              builder: AppLoading.init(),
              home: Consumer(
                builder: (context, ref, _) {
                  final handler = MessageActionHandler(
                    type: 'C2C',
                    peerId: '200',
                    conversation: _conversation(),
                    ref: ref,
                    chatInputKey: chatInputKey,
                    onEditingMessageIdChanged: (id) => editingMessageId = id,
                    // C13 禁言：chat_page._isMuted 注入的检查回调
                    isMutedCheck: () => true,
                  );
                  return Scaffold(
                    body: Column(
                      children: [
                        Expanded(
                          child: ChatInput(
                            key: chatInputKey,
                            type: 'C2C',
                            peerId: '200',
                            onSendPressed: (text) async => true,
                            composerHeight: composerHeight,
                          ),
                        ),
                        TextButton(
                          onPressed: () => handler.editMessage(message),
                          child: const Text('edit while muted'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 前置：输入框存在且为空（本次用非禁言态输入框，单独隔离 handler 层守卫）
      final fieldBefore = tester.widget<CupertinoTextField>(
        find.byKey(const Key('chat_message_input')),
      );
      expect(fieldBefore.controller?.text, '');
      expect(editingMessageId, isNull);

      await tester.tap(find.text('edit while muted'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 拒绝反馈：禁言 toast
      expect(find.text(t.chat.youAreMuted), findsOneWidget);
      // 不进编辑态：editing id 未被置位
      expect(editingMessageId, isNull);
      // 不回填原文到输入框
      final fieldAfter = tester.widget<CupertinoTextField>(
        find.byKey(const Key('chat_message_input')),
      );
      expect(fieldAfter.controller?.text, '');

      // 推进假时钟，让 EasyLoading toast 自动消失，避免遗留 Timer
      await tester.pump(const Duration(seconds: 4));
      await _unmount(tester);
    });
  });

  group('M04-1 接收者视角菜单门禁（作者专属操作不可见）', () {
    testWidgets('接收者即使误传 canEdit=true / onRevoke，也不渲染「编辑」「撤回」', (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MessageActionMenu(
                  // 对端作者的消息（isSentByMe=false）
                  message: TextMessage(
                    id: 'msg-peer',
                    authorId: '200',
                    text: 'from peer',
                  ),
                  isSentByMe: false,
                  // 误配置：把作者专属开关传进来，UI 也必须拦下
                  canEdit: true,
                  onRevoke: () {},
                  onReply: () {},
                  onCopy: () {},
                  onEdit: () {},
                  onDelete: () {},
                  onForward: () {},
                  onReaction: (_) {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(t.common.edit), findsNothing);
      expect(find.text(t.chat.revoke), findsNothing);
      await _unmount(tester);
    });
  });

  // ================= 断言 2：时间窗过期 UI 禁止编辑 =================
  group('M04-2 编辑窗（15 分钟）过期 → 菜单不渲染「编辑」', () {
    testWidgets('过期消息无「编辑」，窗口内消息有「编辑」（对照组）', (tester) async {
      final expired = TextMessage(
        id: 'msg-edit-expired',
        authorId: _meUid,
        text: 'expired draft',
        createdAt: DateTime.now().subtract(const Duration(minutes: 16)),
      );
      final fresh = TextMessage(
        id: 'msg-edit-fresh',
        authorId: _meUid,
        text: 'fresh message',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      // chat_page 同款计算：canEdit 由 ChatPageUtils.canEditMessage 推导
      expect(ChatPageUtils.canEditMessage(expired, _meUid), isFalse);
      expect(ChatPageUtils.canEditMessage(fresh, _meUid), isTrue);

      // 过期消息：菜单无「编辑」，撤回入口仍在（撤回有自己的 2 分钟窗）
      await _pumpMenu(
        tester,
        message: expired,
        canEdit: ChatPageUtils.canEditMessage(expired, _meUid),
      );
      expect(find.text(t.common.edit), findsNothing);
      expect(find.text(t.chat.revoke), findsOneWidget);
      await _unmount(tester);

      // 对照组：窗口内消息仍渲染「编辑」
      await _pumpMenu(
        tester,
        message: fresh,
        canEdit: ChatPageUtils.canEditMessage(fresh, _meUid),
      );
      expect(find.text(t.common.edit), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('M04-2 撤回窗（2 分钟）过期 → 前端短路（S1）', () {
    testWidgets('点撤回 → toast「超过 2 分钟，无法撤回」，路由不被弹掉', (tester) async {
      final conversation = _conversation();
      final expired = TextMessage(
        id: 'msg-revoke-expired',
        authorId: _meUid,
        text: 'too old to revoke',
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              builder: AppLoading.init(),
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Consumer(
                        builder: (context, ref, _) {
                          final handler = MessageActionHandler(
                            type: 'C2C',
                            peerId: '200',
                            conversation: conversation,
                            ref: ref,
                            chatInputKey: GlobalKey<ChatInputState>(),
                            onEditingMessageIdChanged: (_) {},
                          );
                          return Scaffold(
                            body: TextButton(
                              onPressed: () => handler.revokeMessage(expired),
                              child: const Text('revoke expired'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  child: const Text('open chat'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('revoke expired'));
      await tester.pumpAndSettle();

      // S1 短路：立即给出过期反馈（不发网络请求）
      expect(find.text(t.common.revokeExpired), findsOneWidget);
      // 聊天路由未被弹掉
      expect(find.text('revoke expired'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await _unmount(tester);
    });
  });
}
