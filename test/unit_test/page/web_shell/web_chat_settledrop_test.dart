import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/mixin/chat_event_subscription_manager.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/config/const.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OBS-SYN03-SETTLEDROP 回归（daemon 面 web_shell 分页到顶 settle 渲染丢块）。
///
/// 取证口径（runs/syn03-topreach-20261117）：63/63 模型完好、console「没有更多
/// 消息，返回现有 63 条消息」，但静止态（绝对顶、hasMore=false、settle 后）
/// 渲染列表整块丢弃 conv_seq 13-22（seq12→seq23 布局零间隙，4 次复现）。
///
/// 机制：会话存在未读积压（46 条未读）时，WS 补投的旧消息经
/// ChatEventSubscriptionManager 以 newestFirst 语义 `insertMessage(index: 0)`
/// 落到列表 HEAD（最新端），与时间序无关；用户远离底部阅读历史时，这些
/// 头部整块新增又被 ChatMessageList 的 _deferredIds 阅读防跳窗口整块隐藏，
/// 且只有回底/自发消息才释放——settle 后渲染列表缺一整块真实历史，
/// 模型计数不变（dedup 保证 63 条唯一 id）。
///
/// 本测试走真实链路：WebChatPanel → ChatEventSubscriptionManager（真实
/// AppEventBus 投递）→ SqliteChatService → ChatMessageList(_deferredIds)。

class _Sessions extends ChangeNotifier implements AuthSessionReader {
  @override
  bool get transitionFailed => false;
  @override
  AuthSessionScope current = (uid: '1', generation: 1, transitioning: false);
  @override
  bool isCurrent(AuthSessionScope captured) =>
      captured == current && current.uid.isNotEmpty && !current.transitioning;
}

class _Conversation extends ConversationModel {
  _Conversation(String peer)
    : super(
        id: 1,
        peerId: peer,
        avatar: '',
        title: '',
        subtitle: '',
        type: 'C2C',
        msgType: 'text',
        unreadNum: 0,
      );
  @override
  String get uk3 => ConversationUk3Generator.generateSmart(
    type: type,
    currentUserId: '1',
    peerId: peerId,
  );
}

class _SilentVoice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

/// 40 行 newest-first 历史（index 0 = 最新），加上分页语义兼容的空页返回。
class _SettleDropChat extends ChatNotifier {
  late SqliteChatService service;

  @override
  ChatState build() {
    service = SqliteChatService(ref);
    ref.onDispose(service.dispose);
    return const ChatState();
  }

  @override
  SqliteChatService get chatService => service;
  @override
  bool get ownsCurrentSession => true;
  @override
  void initChatService(String chatType) {}
  @override
  void syncMessagesToState() =>
      state = state.copyWith(messages: service.messages);
  @override
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds, {
    bool syncToServer = true,
  }) async => true;
  @override
  Future<void> syncHistoryBackfill(
    ConversationModel conversation, {
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {}
  @override
  Future<List<Message>> loadMoreMessages(
    ConversationModel obj, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {
    if (!isInitial) return const [];
    final base = DateTime(2026, 11, 17, 12);
    final page = List<Message>.generate(
      40,
      (i) => TextMessage(
        id: 'hist-${39 - i}',
        authorId: obj.peerId,
        text: 'hist row ${39 - i}',
        createdAt: base.add(Duration(minutes: 39 - i)),
        metadata: {'conversation_uk3': obj.uk3, 'auto_id': 100 + i},
      ),
    );
    // newest-first：index 0 = hist-39（最新）。
    await service.setMessages(page, animated: false);
    state = state.copyWith(
      messages: page,
      currentConversationId: obj.uk3,
      hasMoreMessage: false,
    );
    return page;
  }
}

void main() {
  late _Sessions sessions;
  late _SettleDropChat chat;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '1',
      Keys.currentUser: jsonEncode({
        'uid': '1',
        'setting': <String, dynamic>{},
      }),
    });
    await StorageService.init();
    sessions = _Sessions();
    chat = _SettleDropChat();
    container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(() => chat),
        voicePlaybackServiceProvider.overrideWith(_SilentVoice.new),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    sessions.dispose();
    MessageRepo.setCurrentActiveConversationUk3(null);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            home: Material(
              child: SizedBox(
                width: 600,
                height: 1400,
                child: WebChatPanel(
                  key: const ValueKey('chat-panel-under-test'),
                  selection: const ChatSelection(peerId: '2', chatType: 'C2C'),
                  currentUserId: '1',
                  closeTooltip: 'Close',
                  onClose: () {},
                  inputArea: const SizedBox(),
                  sessionReader: sessions,
                  conversationLoader: (_, _) async => _Conversation('2'),
                  contactLoader: (_) async => null,
                  groupLoader: (_) async => null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollPosition readingPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ChatMessageList),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  int renderedCount(WidgetTester tester) {
    final list = tester.widget<ListView>(find.byType(ListView));
    final delegate = list.childrenDelegate;
    return delegate is SliverChildBuilderDelegate
        ? (delegate.childCount ?? 0)
        : 0;
  }

  /// 模拟 WS 补投一条「比全部在场历史都旧」的未读积压消息（真实事件链路）。
  void redeliver(int seq) {
    AppEventBus.fireData(
      TextMessage(
        id: 'seq-$seq',
        authorId: '2',
        text: 'redelivered old seq $seq',
        createdAt: DateTime(2026, 11, 17, 11, 59 - (23 - seq)),
        metadata: {'conversation_uk3': _Conversation('2').uk3},
      ),
      'TextMessage',
    );
  }

  test('deliveryInsertionIndex：时间序落位契约（newest-first / oldest-first）', () {
    DateTime t(int m) => DateTime(2026, 11, 17, 12, m);
    final newestFirst = [
      TextMessage(id: 'a', authorId: '2', text: 'a', createdAt: t(30)),
      TextMessage(id: 'b', authorId: '2', text: 'b', createdAt: t(20)),
      TextMessage(id: 'c', authorId: '2', text: 'c', createdAt: t(10)),
    ];
    int idx(int minute) => ChatEventSubscriptionManager.deliveryInsertionIndex(
      newestFirst,
      TextMessage(id: 'x', authorId: '2', text: 'x', createdAt: t(minute)),
      newestFirst: true,
    );
    // 真新消息保持原 head 语义；旧消息按时间序落位，不再一律 head。
    expect(idx(40), 0);
    expect(idx(25), 1);
    expect(idx(15), 2);
    expect(idx(5), 3);
    final oldestFirst = [
      TextMessage(id: 'a', authorId: '2', text: 'a', createdAt: t(10)),
      TextMessage(id: 'b', authorId: '2', text: 'b', createdAt: t(20)),
      TextMessage(id: 'c', authorId: '2', text: 'c', createdAt: t(30)),
    ];
    int idxOld(int minute) =>
        ChatEventSubscriptionManager.deliveryInsertionIndex(
          oldestFirst,
          TextMessage(id: 'x', authorId: '2', text: 'x', createdAt: t(minute)),
          newestFirst: false,
        );
    expect(idxOld(40), 3);
    expect(idxOld(25), 2);
    expect(idxOld(15), 1);
    expect(idxOld(5), 0);
    // 无时间戳合成消息（交付行或在场行）无法建立时间序，保持原「视为最新」
    // 落位语义（如上传确认 canonical 消息须落 head，见
    // attachment_upload_task_recovery_test）。
    expect(
      ChatEventSubscriptionManager.deliveryInsertionIndex(
        newestFirst,
        TextMessage(id: 'x', authorId: '2', text: 'x'),
        newestFirst: true,
      ),
      0,
    );
    expect(
      ChatEventSubscriptionManager.deliveryInsertionIndex(
        oldestFirst,
        TextMessage(id: 'x', authorId: '2', text: 'x'),
        newestFirst: false,
      ),
      3,
    );
    final withNullRow = [
      TextMessage(id: 'n', authorId: '2', text: 'n'),
      TextMessage(id: 'a', authorId: '2', text: 'a', createdAt: t(30)),
    ];
    expect(
      ChatEventSubscriptionManager.deliveryInsertionIndex(
        withNullRow,
        TextMessage(
          id: 'x',
          authorId: '2',
          text: 'x',
          createdAt: DateTime(2020),
        ),
        newestFirst: true,
      ),
      0,
      reason: '在场行缺时间戳 → 时间序不可建，保持原最新端落位',
    );
  });

  testWidgets('settle 后渲染 items 覆盖模型全量：WS 补投的旧消息不得整块消失（SETTLEDROP）', (
    tester,
  ) async {
    try {
      await mount(tester);
      expect(chat.service.messages, hasLength(40));

      // 分页到顶：远离底部（nearBottom=false），对应取证「自底递增上升」。
      final position = readingPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      // 顶部 settle 期间 WS 补投 10 条旧消息（seq13-22，取证口径）。
      for (var seq = 13; seq <= 22; seq++) {
        redeliver(seq);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // 模型层完好：50/50 唯一行。
      final modelIds = chat.service.messages.map((m) => m.id).toSet();
      expect(modelIds, hasLength(50));
      for (var seq = 13; seq <= 22; seq++) {
        expect(modelIds, contains('seq-$seq'));
      }

      // 渲染 items 覆盖模型全量（RED：现状 40，缺 seq13-22 整块）。
      expect(
        renderedCount(tester),
        50,
        reason: 'settle 后渲染 items 必须覆盖模型全量 50 行（OBS-SYN03-SETTLEDROP）',
      );

      // 绝对顶可达：补投块是更旧消息，应出现在顶部窗口（web 正文经
      // GptMarkdown 渲染，需 findRichText 匹配）；块尾行下探后可达可读。
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('redelivered old seq 13', findRichText: true),
        findsOneWidget,
      );
      var reachable = false;
      for (var i = 0; i < 30 && !reachable; i++) {
        reachable = find
            .textContaining('redelivered old seq 22', findRichText: true)
            .evaluate()
            .isNotEmpty;
        if (!reachable) {
          await tester.drag(
            find.byType(ChatMessageList),
            const Offset(0, -200),
          );
          await tester.pumpAndSettle();
        }
      }
      expect(reachable, isTrue, reason: '补投块尾行必须静止可停靠阅读');

      // 时间序：补投块落在最旧端（tail），不落在最新端（head）。
      final ids = chat.service.messages.map((m) => m.id).toList();
      expect(ids.first, 'hist-39', reason: '最新端不变');
      expect(
        ids.sublist(ids.length - 10),
        List.generate(10, (i) => 'seq-${22 - i}'),
        reason: '补投旧消息按时间序落在最旧端（newest-first 列表 tail）',
      );
    } finally {
      // 消息监听器内有 5s msgIds 回收 Timer，测试收尾统一冲掉。
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });
}
