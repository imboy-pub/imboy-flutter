import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';
import 'package:imboy/store/api/report_api.dart';

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
const _testMsg = TextMessage(id: 'msg_1', authorId: 'u_1', text: 'hi');

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

/// R-01 消息一等举报 + E2EE 同意门测试。
///
/// 举报按钮（接收者可见）→ 原因选择 →（E2EE 消息）明文披露同意对话框
/// → 提交 message 类举报（target_type='message'，不再伪装 user+description）。
class _FakeReportApi extends ReportApi {
  _FakeReportApi() : super.base();

  final List<Map<String, dynamic>> messageCalls = [];

  @override
  Future<(bool, String)> createMessage({
    required String chatType,
    required String targetId,
    required String scopeId,
    required String reason,
    String excerpt = '',
    bool consent = false,
    String clientMsgId = '',
    String msgType = '',
    int sentAt = 0,
  }) async {
    messageCalls.add({
      'chat_type': chatType,
      'target_id': targetId,
      'scope_id': scopeId,
      'reason': reason,
      'excerpt': excerpt,
      'consent': consent,
      'client_msg_id': clientMsgId,
    });
    return (true, 'success');
  }
}

Future<void> _pumpReport(
  WidgetTester tester, {
  required bool isSentByMe,
  Map<String, dynamic>? metadata,
  String reportChatType = 'c2c',
  String reportScopeId = '3001',
}) async {
  final message = TextMessage(
    id: 'msg_r1',
    authorId: '2001',
    text: '垃圾广告内容',
    metadata: metadata,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1770000000000),
  );
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        // AppLoading 需要 EasyLoading init 的 overlay
        builder: AppLoading.init(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageActionMenu(
              message: message,
              isSentByMe: isSentByMe,
              reportChatType: reportChatType,
              reportScopeId: reportScopeId,
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

void _registerReportGroups() {
  group('R-01 消息一等举报', () {
    // 基础语言 zh-CN：与既有用例一致用字面文案断言
    testWidgets('非 E2EE：选原因后直接提交 message 举报（含摘录，无 consent）', (tester) async {
      final fake = _FakeReportApi();
      ReportApi.debugInstanceForTest = fake;
      try {
        await _pumpReport(tester, isSentByMe: false);

        // 打开举报原因 action sheet
        await tester.tap(find.text('投诉'));
        await tester.pumpAndSettle();

        // 非 E2EE 不出现同意对话框
        expect(find.text('提交加密消息证据'), findsNothing);

        await tester.tap(find.text('垃圾信息'));
        await tester.pumpAndSettle();

        expect(fake.messageCalls, hasLength(1));
        final call = fake.messageCalls.first;
        expect(call['chat_type'], 'c2c');
        expect(call['target_id'], 'msg_r1');
        expect(call['scope_id'], '3001');
        expect(call['reason'], 'spam');
        expect(call['excerpt'], '垃圾广告内容');
        expect(call['consent'], false);
        expect(call['client_msg_id'], 'msg_r1');
        await _unmount(tester);
      } finally {
        ReportApi.debugInstanceForTest = null;
      }
    });

    testWidgets('E2EE：选原因后先弹明文披露同意对话框', (tester) async {
      final fake = _FakeReportApi();
      ReportApi.debugInstanceForTest = fake;
      try {
        await _pumpReport(
          tester,
          isSentByMe: false,
          metadata: {
            'e2ee': {'v': 'OLM.V1'},
          },
        );

        await tester.tap(find.text('投诉'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('骚扰'));
        await tester.pumpAndSettle();

        // 同意对话框出现；尚未提交
        expect(find.text('提交加密消息证据'), findsOneWidget);
        expect(fake.messageCalls, isEmpty);

        // 取消：不提交
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(fake.messageCalls, isEmpty);
        await _unmount(tester);
      } finally {
        ReportApi.debugInstanceForTest = null;
      }
    });

    testWidgets('E2EE：明确同意 → 摘录 + consent=true', (tester) async {
      final fake = _FakeReportApi();
      ReportApi.debugInstanceForTest = fake;
      try {
        await _pumpReport(
          tester,
          isSentByMe: false,
          metadata: {
            'e2ee': {'v': 'OLM.V1'},
          },
        );

        await tester.tap(find.text('投诉'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('垃圾信息'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('同意并提交证据'));
        await tester.pumpAndSettle();

        expect(fake.messageCalls, hasLength(1));
        final call = fake.messageCalls.first;
        expect(call['excerpt'], '垃圾广告内容');
        expect(call['consent'], true);
        await _unmount(tester);
      } finally {
        ReportApi.debugInstanceForTest = null;
      }
    });

    testWidgets('E2EE：拒绝披露 → 无摘录、无 consent，仍成举报', (tester) async {
      final fake = _FakeReportApi();
      ReportApi.debugInstanceForTest = fake;
      try {
        await _pumpReport(
          tester,
          isSentByMe: false,
          metadata: {
            'e2ee': {'v': 'OLM.V1'},
          },
        );

        await tester.tap(find.text('投诉'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('其他'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('仅举报（不提交内容）'));
        await tester.pumpAndSettle();

        expect(fake.messageCalls, hasLength(1));
        final call = fake.messageCalls.first;
        expect(call['excerpt'], '');
        expect(call['consent'], false);
        expect(call['reason'], 'other');
        await _unmount(tester);
      } finally {
        ReportApi.debugInstanceForTest = null;
      }
    });

    testWidgets('群聊上下文透传：chat_type=c2g + scope=群 ID', (tester) async {
      final fake = _FakeReportApi();
      ReportApi.debugInstanceForTest = fake;
      try {
        await _pumpReport(
          tester,
          isSentByMe: false,
          reportChatType: 'C2G',
          reportScopeId: '7001',
        );

        await tester.tap(find.text('投诉'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('垃圾信息'));
        await tester.pumpAndSettle();

        expect(fake.messageCalls, hasLength(1));
        expect(fake.messageCalls.first['chat_type'], 'C2G');
        expect(fake.messageCalls.first['scope_id'], '7001');
        await _unmount(tester);
      } finally {
        ReportApi.debugInstanceForTest = null;
      }
    });
  });
}

void main() {
  _registerReportGroups();

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
      await _pump(tester, isSentByMe: false, onCopy: () => copyCount++);

      await tester.tap(find.text('复制'));
      await tester.pump();
      expect(copyCount, 1);
      await _unmount(tester);
    });

    testWidgets('tap 转发 → onForward + onClose', (tester) async {
      var forwardCount = 0;
      await _pump(tester, isSentByMe: false, onForward: () => forwardCount++);

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
      await _pump(tester, isSentByMe: false, onCollect: () => collectCount++);

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
      await _pump(tester, isSentByMe: false, onSave: () => saveCount++);

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
      await _pump(tester, isSentByMe: true, onRevoke: () => revokeCount++);

      expect(find.text('撤回'), findsOneWidget);
      await tester.tap(find.text('撤回'));
      await tester.pump();
      expect(revokeCount, 1);
      await _unmount(tester);
    });

    testWidgets('onRetry 非 null → "重试" 渲染 + tap 触发回调', (tester) async {
      var retryCount = 0;
      await _pump(tester, isSentByMe: true, onRetry: () => retryCount++);

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
    testWidgets('isSentByMe=false → 显示"删除我的消息"（接收者专属）', (tester) async {
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

    testWidgets('isSentByMe=false 时 onRevoke 即使非 null 也不显示', (tester) async {
      await _pump(tester, isSentByMe: false, onRevoke: () {});
      // 撤回是发送者专属，接收者绝不显示（即使 onRevoke 非 null）
      expect(find.text('撤回'), findsNothing);
      await _unmount(tester);
    });
  });

  // 顺序契约：onClose 必须先于动作执行。
  // 反过来时，onClose 里的 Navigator.pop() 会弹掉动作刚 push 的路由 ——
  // 真机实测：点「转发」，SendToPage 被自己的 onClose 关掉，菜单反而留在原地，
  // 用户看到的是"转发按钮完全没反应"。
  group('回调顺序（onClose 先于动作）', () {
    testWidgets('转发：onClose 在 onForward 之前触发', (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        isSentByMe: true,
        onForward: () => calls.add('forward'),
        onClose: () => calls.add('close'),
      );

      await tester.tap(find.text('转发'));
      await tester.pump();

      expect(calls, ['close', 'forward']);
      await _unmount(tester);
    });

    testWidgets('复制：同样遵循 close-first', (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        isSentByMe: true,
        onCopy: () => calls.add('copy'),
        onClose: () => calls.add('close'),
      );

      await tester.tap(find.text('复制'));
      await tester.pump();

      expect(calls, ['close', 'copy']);
      await _unmount(tester);
    });
  });

  // 换行契约（与 conversation/right_button 同一准则，2026-08-27 用户拍板：
  // "打3个点的模式，还不如换行"）：德语等长文案或「超大字号」下，
  // 操作按钮标签应换行承接而非打点截断。
  // 本菜单里唯一设置 maxLines 的就是操作按钮标签（reaction emoji 无约束），
  // 因此断言「所有带 maxLines 的文本 == 2」即可锁定整个按钮区。
  group('长文案换行契约（换行优先于省略号）', () {
    testWidgets('所有操作按钮标签 maxLines==2', (tester) async {
      await _pump(
        tester,
        isSentByMe: true,
        onRevoke: () {},
        onSave: () {},
        onCollect: () {},
      );

      final labeledTexts = tester
          .widgetList<Text>(
            find.byWidgetPredicate((w) => w is Text && w.maxLines != null),
          )
          .toList();
      expect(labeledTexts, isNotEmpty);
      for (final text in labeledTexts) {
        expect(text.maxLines, 2, reason: '「${text.data}」应允许两行换行承接');
      }
      await _unmount(tester);
    });
  });
}
