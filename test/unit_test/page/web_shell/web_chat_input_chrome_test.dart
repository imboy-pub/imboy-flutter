/// Run the production composer component cases in the real browser runtime.
///
/// FL-06 增补：编辑/引用/删除/多选接既有模型的行为断言（LOCAL:01..:04）。
/// 原有 composer 全量用例经 `composer.main()` 在同一 chrome 运行时回归。
@TestOn('chrome')
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintSynchronously;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/page/chat/chat/bundle_forward_dispatcher.dart'
    show bundleActionAllowedFor;
import 'package:imboy/page/chat/chat/chat_multi_select_wiring.dart'
    show canDispatchSelectedMessages;
import 'package:imboy/page/chat/chat/services/message_selection_traits.dart'
    show messageSelectionTraitsOf;
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/web_shell/web_chat_input.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart'
    show ReEditMessageEvent;
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/chat_input_io_fence.dart';
import 'fixtures/text_send_fixture.dart';
import 'web_chat_input_test.dart' as composer;

const _uid = '900001';
const _peer = '990001';
final String _uk3 = 'C2G_${_uid}_$_peer';

/// 接受任意 Message（CustomMessage 引用行）的发送 fake（TextSendChat 的
/// addMessage 断言 `message as TextMessage`，引用路径需要宽容载荷）。
class _AnyMessageChat extends TextSendChat {
  _AnyMessageChat(super.messages);

  @override
  Future<bool> addMessage(
    String fromId,
    String toId,
    String? avatar,
    String title,
    String type,
    Message message, {
    bool sendToServer = true,
  }) async {
    submitted.add(message);
    if (failure != null) throw failure!;
    final result = gate == null ? succeeds : await gate!.future;
    final text = message is TextMessage
        ? message.text
        : (message.metadata?['quote_text']?.toString() ?? '');
    messages.rows[message.id] = MessageModel(
      message.id,
      autoId: messages.rows.length + 1,
      type: type,
      status: result ? IMBoyMessageStatus.sent : IMBoyMessageStatus.error,
      fromId: fromId,
      toId: toId,
      payload: {'text': text},
      isAuthor: 1,
      conversationUk3: '${type}_${fromId}_$toId',
    );
    return result;
  }
}

TextMessage _text(String id, String body, {String? authorId}) => TextMessage(
  id: id,
  authorId: authorId ?? _uid,
  createdAt: DateTime.now(),
  text: body,
  status: MessageStatus.sent,
);

CustomMessage _custom(String id, String msgType, {String? authorId}) =>
    CustomMessage(
      authorId: authorId ?? _peer,
      id: id,
      metadata: {'msg_type': msgType},
    );

void main() {
  debugPrint = debugPrintSynchronously;
  composer.main();
  fl06ComposerIntentAssertions();
}

void fl06ComposerIntentAssertions() {
  late TextSendChat chat;
  late TextSendMessages messages;
  late ProviderContainer container;
  late ChatInputIoFence ioFence;
  final field = find.descendant(
    of: find.byKey(const ValueKey('web-chat-input-field')),
    matching: find.byType(TextField),
  );
  final send = find.byKey(const ValueKey('web-chat-input-send-btn'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: _uid,
      Keys.currentUser:
          '{"uid":"$_uid","nickname":"Fixture sender","account":"",'
          '"email":"","mobile":"","avatar":"","role":null,"gender":0,'
          '"region":"","sign":"","setting":{}}',
    });
    await StorageService.init();
    ioFence = ChatInputIoFence()..install();
    messages = TextSendMessages();
    NtpHelper.debugReset();
    chat = _AnyMessageChat(messages);
    container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => chat)],
    );
    container.listen(chatProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    ioFence.verifyAndRestore();
  });

  Future<void> pump(
    WidgetTester tester, {
    required WebComposerIntentController controller,
    String type = 'C2G',
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: WebComposerIntentScope(
                controller: controller,
                child: WebChatInput(
                  key: const ValueKey('$_uid:$_peer'),
                  selection: ChatSelection(peerId: _peer, chatType: type),
                  currentUserId: _uid,
                  messageRepository: messages,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// FL-06:LOCAL:01 —— 编辑提交走权威编辑模型（ MessagingFacade.sendEditMessage
  /// 的注入面），成功后仅当代次与文本均未漂移才收敛编辑态。
  isolatedChatInputTestWidgets(
    'LOCAL:01 edit submit dispatches the authoritative edit model',
    (tester) async {
      final calls = <(String, String, String)>[];
      final controller = WebComposerIntentController(
        editDispatcher: (messageId, chatType, content) async {
          calls.add((messageId, chatType, content));
          return true;
        },
      );
      await pump(tester, controller: controller);
      // 编辑快照语境（LOCAL:02 的编辑半边）：进入编辑 → composer 填充快照。
      expect(controller.beginEdit(_text('m1', 'original text'), _uid), isTrue);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('web-composer-edit-bar')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, 'original text');
      await tester.enterText(field, 'edited body');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single, ('m1', 'C2G', 'edited body'));
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.byKey(const ValueKey('web-composer-edit-bar')), findsNothing);
    },
  );

  isolatedChatInputTestWidgets(
    'LOCAL:01 reverse-order edit supersedes an in-flight edit without silent overwrite',
    (tester) async {
      final calls = <(String, String, String)>[];
      final firstAck = Completer<bool>();
      final secondAck = Completer<bool>();
      final gateQueue = <Completer<bool>>[firstAck, secondAck];
      final controller = WebComposerIntentController(
        editDispatcher: (messageId, chatType, content) {
          calls.add((messageId, chatType, content));
          return gateQueue.removeAt(0).future;
        },
      );
      await pump(tester, controller: controller);
      expect(controller.beginEdit(_text('m1', 'first snapshot'), _uid), isTrue);
      await tester.pump();
      await tester.enterText(field, 'edit one');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      expect(calls, hasLength(1));
      // 反序：第一条 ACK 未回时用户对另一条消息发起第二次编辑。
      expect(
        controller.beginEdit(_text('m2', 'second snapshot'), _uid),
        isTrue,
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'second snapshot',
      );
      firstAck.complete(true);
      await tester.pumpAndSettle();
      // 迟到的第一条 ACK 不得清空第二条编辑（无静默覆盖）。
      expect(
        tester.widget<TextField>(field).controller!.text,
        'second snapshot',
      );
      expect(
        find.byKey(const ValueKey('web-composer-edit-bar')),
        findsOneWidget,
      );
      // 第二条编辑照常提交并收敛。
      await tester.tap(send);
      await tester.pump();
      expect(calls, hasLength(2));
      expect(calls.last.$1, 'm2');
      expect(calls.last.$3, 'second snapshot');
      secondAck.complete(true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.byKey(const ValueKey('web-composer-edit-bar')), findsNothing);
    },
  );

  isolatedChatInputTestWidgets(
    'LOCAL:01 late edit success preserves newer typed text (conflict stays explicit)',
    (tester) async {
      final gate = Completer<bool>();
      final controller = WebComposerIntentController(
        editDispatcher: (_, _, _) => gate.future,
      );
      await pump(tester, controller: controller);
      controller.beginEdit(_text('m1', 'snapshot'), _uid);
      await tester.pump();
      await tester.enterText(field, 'snapshot');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      // ACK 期间用户继续输入新文本。
      await tester.enterText(field, 'newer typed text');
      await tester.pump();
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'newer typed text',
      );
      expect(
        find.byKey(const ValueKey('web-composer-edit-bar')),
        findsOneWidget,
      );
    },
  );

  isolatedChatInputTestWidgets(
    'LOCAL:01 failed edit keeps text and surfaces send failure feedback',
    (tester) async {
      final controller = WebComposerIntentController(
        editDispatcher: (_, _, _) async => false,
      );
      await pump(tester, controller: controller);
      controller.beginEdit(_text('m1', 'snapshot'), _uid);
      await tester.pump();
      await tester.enterText(field, 'rejected edit');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'rejected edit');
      expect(find.text(t.common.sendFailed), findsOneWidget);
      expect(
        find.byKey(const ValueKey('web-composer-edit-bar')),
        findsOneWidget,
      );
    },
  );

  /// FL-06:LOCAL:02 —— 撤回/失权隐藏摘要：撤回终态行令编辑意图失效，
  /// 无权限旁路（不能再以编辑身份派发）。
  isolatedChatInputTestWidgets(
    'LOCAL:02 revoke invalidates edit intent without permission bypass',
    (tester) async {
      final calls = <(String, String, String)>[];
      final controller = WebComposerIntentController(
        editDispatcher: (messageId, chatType, content) async {
          calls.add((messageId, chatType, content));
          return true;
        },
      );
      await pump(tester, controller: controller);
      controller.beginEdit(_text('m1', 'soon revoked'), _uid);
      await tester.pump();
      final original = _text('m1', 'soon revoked');
      final revoked = original.copyWith(
        metadata: {
          ...?original.metadata,
          IMBoyMessageStatus.localStatusMetadataKey:
              IMBoyMessageStatus.myRevoked,
        },
      );
      expect(webEditIntentInvalidated(controller.intent, [revoked]), isTrue);
      controller.invalidateEditing();
      await tester.pump();
      expect(find.byKey(const ValueKey('web-composer-edit-bar')), findsNothing);
      expect(controller.intent.isEditing, isFalse);
      // 未撤回的权威行 → 不失权（可判定才收敛，不猜）。
      controller.beginEdit(_text('m2', 'still live'), _uid);
      expect(
        webEditIntentInvalidated(controller.intent, [
          _text('m2', 'still live'),
        ]),
        isFalse,
      );
      controller.cancelIntent();
      expect(calls, isEmpty);
    },
  );

  isolatedChatInputTestWidgets(
    'LOCAL:02 shared re-edit event fills composer snapshot (real setter path)',
    (tester) async {
      final controller = WebComposerIntentController();
      final subscription = webBindReEditEvents(controller: controller);
      addTearDown(subscription.cancel);
      await pump(tester, controller: controller);
      await tester.runAsync(() async {
        AppEventBus.fire(
          const ReEditMessageEvent(text: 're-edited body', messageId: 'm9'),
        );
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(controller.intent.isEditing, isTrue);
      expect(controller.intent.editingMessageId, 'm9');
      expect(controller.intent.editSnapshotText, 're-edited body');
      expect(
        tester.widget<TextField>(field).controller!.text,
        're-edited body',
      );
      // 取消编辑（不带恢复：撤回重编辑无前置草稿可恢复）。
      controller.cancelIntent();
      await tester.pump();
      expect(find.byKey(const ValueKey('web-composer-edit-bar')), findsNothing);
    },
  );

  /// FL-06:LOCAL:02 —— 引用发送保留快照语境（mobile `_sendQuoteMessage`
  /// 同 metadata 合同；quote_msg 是发送时刻的序列化快照）。
  isolatedChatInputTestWidgets(
    'LOCAL:02 quote send preserves snapshot context with shared metadata contract',
    (tester) async {
      final controller = WebComposerIntentController();
      await pump(tester, controller: controller);
      final quoted = _text('origin-1', 'quoted original', authorId: _peer);
      controller.beginQuote(quoted);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('web-composer-quote-bar')),
        findsOneWidget,
      );
      expect(find.text('quoted original'), findsOneWidget);
      await tester.enterText(field, 'reply text');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(chat.submitted, hasLength(1));
      final sent = chat.submitted.single;
      expect(sent, isA<CustomMessage>());
      final metadata = sent.metadata!;
      expect(metadata['msg_type'], 'quote');
      expect(metadata['quote_msg'], quoted.toJson());
      expect(metadata['quote_text'], 'reply text');
      expect(metadata['quote_msg_author_name'], isNotEmpty);
      expect((metadata['quote_msg'] as Map)['text'], 'quoted original');
      expect(
        find.byKey(const ValueKey('web-composer-quote-bar')),
        findsNothing,
      );
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    },
  );

  isolatedChatInputTestWidgets(
    'LOCAL:02 cancel edit restores the pre-edit draft',
    (tester) async {
      final controller = WebComposerIntentController(
        editDispatcher: (_, _, _) async => true,
      );
      await pump(tester, controller: controller);
      await tester.enterText(field, 'pre-edit draft');
      await tester.pump();
      controller.beginEdit(_text('m1', 'snapshot body'), _uid);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'snapshot body');
      await tester.tap(find.byKey(const ValueKey('web-composer-edit-cancel')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'pre-edit draft',
      );
    },
  );

  /// FL-06:LOCAL:03 —— 多选进入/勾选/退出接 messageSelectionProvider 既有模型。
  isolatedChatInputTestWidgets(
    'LOCAL:03 multi-select enter/toggle/exit wire into the shared selection model',
    (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        'chat_multi_select_v1': true,
        'chat_history_bundle_v1': true,
        'chat_export_share_v1': true,
      });
      addTearDown(
        () => AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{}),
      );
      chat.initChatService('C2G');
      final service = chat.chatService!;
      String? enterReason;
      String? toggleReason;
      bool? activeAfterEnter;
      bool? activeAfterExit;
      Set<String>? selectedAfterToggle;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    // watch 保活 autoDispose family（镜像 mobile 页面契约）。
                    final active = webMultiSelectActiveOf(ref, _uk3);
                    return Column(
                      children: [
                        Text('active=$active'),
                        TextButton(
                          onPressed: () {
                            enterReason = webEnterMultiSelect(
                              ref,
                              _uk3,
                              _text('m1', 'first'),
                            );
                            activeAfterEnter = ref
                                .read(messageSelectionProvider(_uk3))
                                .active;
                          },
                          child: const Text('enter'),
                        ),
                        TextButton(
                          onPressed: () {
                            toggleReason = webToggleMessageSelection(
                              ref,
                              _uk3,
                              _text('m2', 'second'),
                            );
                            selectedAfterToggle = container
                                .read(messageSelectionProvider(_uk3))
                                .selectedIds;
                          },
                          child: const Text('toggle'),
                        ),
                        TextButton(
                          onPressed: () {
                            webExitMultiSelect(ref, _uk3);
                            activeAfterExit = ref
                                .read(messageSelectionProvider(_uk3))
                                .active;
                          },
                          child: const Text('exit'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await service.setMessages([
          _text('m1', 'first'),
          _text('m2', 'second'),
        ]);
      });
      await tester.tap(find.text('enter'));
      await tester.pump();
      expect(enterReason, isNull);
      expect(activeAfterEnter, isTrue);
      await tester.tap(find.text('toggle'));
      await tester.pump();
      expect(toggleReason, isNull);
      expect(selectedAfterToggle, {'m1', 'm2'});
      // WebRTC 信令行不可入选（既有白名单模型，fail-closed）。
      expect(
        evaluateMessageSelectability(
          messageSelectionTraitsOf(_custom('m3', 'webrtcAudio')),
        ).selectable,
        isFalse,
      );
      await tester.tap(find.text('exit'));
      await tester.pump();
      expect(activeAfterExit, isFalse);
      expect(container.read(messageSelectionProvider(_uk3)).active, isFalse);
      await tester.runAsync(() async {
        service.dispose();
      });
    },
  );

  isolatedChatInputTestWidgets(
    'LOCAL:03 forward re-check keeps non-mergeable sources from dispatching',
    (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        'chat_multi_select_v1': true,
        'chat_history_bundle_v1': true,
        'chat_export_share_v1': true,
      });
      addTearDown(
        () => AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{}),
      );
      chat.initChatService('C2G');
      final service = chat.chatService!;
      await tester.runAsync(() async {
        await service.setMessages([
          _text('m1', 'a'),
          _custom('m2', 'webrtcAudio'),
        ]);
      });
      // 与 native bundle_forward_dispatcher_test 同源的策略函数：混入
      // WebRTC 信令 → 合并转发准入拒绝；纯 text 组合 → 允许。
      final mixed = [_custom('m2', 'webrtcAudio'), _text('m1', 'a')];
      final traits = mixed
          .map(messageSelectionTraitsOf)
          .toList(growable: false);
      expect(
        traits.any((t) => !evaluateMessageSelectability(t).selectable),
        isTrue,
      );
      expect(bundleActionAllowedFor(traits), isFalse);
      expect(
        canDispatchSelectedMessages(
          active: true,
          current: mixed,
          initial: mixed,
          allowed: bundleActionAllowedFor,
        ),
        isFalse,
      );
      final pure = [_text('m1', 'a')]
          .map(messageSelectionTraitsOf)
          .toList(growable: false);
      expect(bundleActionAllowedFor(pure), isTrue);
      expect(
        canDispatchSelectedMessages(
          active: true,
          current: [_text('m1', 'a')],
          initial: [_text('m1', 'a')],
          allowed: bundleActionAllowedFor,
        ),
        isTrue,
      );
      await tester.runAsync(() async {
        service.dispose();
      });
    },
  );

  /// FL-06:LOCAL:04 —— 长按菜单可见性矩阵（最低 UX 合同决策点）。
  isolatedChatInputTestWidgets(
    'LOCAL:04 long-press menu plan maps the minimum UX contract matrix',
    (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ownRecent = resolveWebLongPressMenuPlan(
        message: _text('m1', 'own recent'),
        currentUserId: _uid,
        nowMs: now,
        multiSelectFlagEnabled: true,
        conversationAvailable: true,
      );
      expect(ownRecent.canCopy, isTrue);
      expect(ownRecent.canQuote, isTrue);
      expect(ownRecent.canEdit, isTrue);
      expect(ownRecent.canRecall, isTrue);
      expect(ownRecent.canDelete, isTrue);
      expect(ownRecent.canMultiSelect, isTrue);

      // 对端消息：无编辑/撤回；复制/引用/删除/多选可达。
      final peerText = resolveWebLongPressMenuPlan(
        message: _text('m2', 'peer text', authorId: _peer),
        currentUserId: _uid,
        nowMs: now,
        multiSelectFlagEnabled: true,
        conversationAvailable: true,
      );
      expect(peerText.canEdit, isFalse);
      expect(peerText.canRecall, isFalse);
      expect(peerText.canCopy, isTrue);
      expect(peerText.canQuote, isTrue);
      expect(peerText.canDelete, isTrue);
      expect(peerText.canMultiSelect, isTrue);

      // E2EE 解密失败占位：仅删除（防占位串被复制/引用/编辑为真实文本）。
      final e2ee = resolveWebLongPressMenuPlan(
        message: _custom('m3', 'text', authorId: _uid).copyWith(
          metadata: {
            ..._custom('m3', 'text', authorId: _uid).metadata!,
            '_e2ee_failed': true,
          },
        ),
        currentUserId: _uid,
        nowMs: now,
        multiSelectFlagEnabled: true,
        conversationAvailable: true,
      );
      expect(e2ee.canCopy, isFalse);
      expect(e2ee.canQuote, isFalse);
      expect(e2ee.canEdit, isFalse);
      expect(e2ee.canRecall, isFalse);
      expect(e2ee.canMultiSelect, isFalse);
      expect(e2ee.canDelete, isTrue);

      // flag 关闭 → 无多选入口（零 UI 变化语义）。
      final flagOff = resolveWebLongPressMenuPlan(
        message: _text('m1', 'own recent'),
        currentUserId: _uid,
        nowMs: now,
        multiSelectFlagEnabled: false,
        conversationAvailable: true,
      );
      expect(flagOff.canMultiSelect, isFalse);
      expect(flagOff.canEdit, isTrue);

      // 超过 15 分钟的旧文本 → 编辑入口失权（权限不旁路）。
      final stale = resolveWebLongPressMenuPlan(
        message: TextMessage(
          id: 'm4',
          authorId: _uid,
          createdAt: DateTime.fromMillisecondsSinceEpoch(now - 16 * 60 * 1000),
          text: 'stale own text',
          status: MessageStatus.sent,
        ),
        currentUserId: _uid,
        nowMs: now,
        multiSelectFlagEnabled: true,
        conversationAvailable: true,
      );
      expect(stale.canEdit, isFalse);
      expect(stale.canCopy, isTrue);
    },
  );

  isolatedChatInputTestWidgets(
    'LOCAL:04 multi-select row wrapper reflects the shared selection state',
    (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        'chat_multi_select_v1': true,
      });
      addTearDown(
        () => AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{}),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => Column(
                    children: [
                      TextButton(
                        onPressed: () =>
                            webEnterMultiSelect(ref, _uk3, _text('m1', 'a')),
                        child: const Text('enter'),
                      ),
                      // enter 已预选长按消息 m1（W1-A enter 契约）；
                      // m3 行用于验证勾选框的加选/取消。
                      webMultiSelectRowWrapper(
                        context,
                        ref: ref,
                        conversationUk3: _uk3,
                        message: _text('m1', 'a'),
                        child: const SizedBox(height: 20, width: 50),
                      ),
                      // WebRTC 行：勾选框禁用 + 整行置灰。
                      webMultiSelectRowWrapper(
                        context,
                        ref: ref,
                        conversationUk3: _uk3,
                        message: _custom('m2', 'webrtcAudio'),
                        child: const SizedBox(height: 20, width: 50),
                      ),
                      webMultiSelectRowWrapper(
                        context,
                        ref: ref,
                        conversationUk3: _uk3,
                        message: _text('m3', 'c'),
                        child: const SizedBox(height: 20, width: 50),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // 未激活 → 无勾选框（零 UI 变化）。
      expect(find.byType(IconButton), findsNothing);
      await tester.tap(find.text('enter'));
      await tester.pump();
      final preselected = find.byKey(
        const ValueKey('web-msg-select-checkbox-m1'),
      );
      final disabled = find.byKey(const ValueKey('web-msg-select-checkbox-m2'));
      final toggleTarget = find.byKey(
        const ValueKey('web-msg-select-checkbox-m3'),
      );
      expect(preselected, findsOneWidget);
      expect(disabled, findsOneWidget);
      expect(toggleTarget, findsOneWidget);
      expect(tester.widget<IconButton>(preselected).onPressed, isNotNull);
      expect(tester.widget<IconButton>(disabled).onPressed, isNull);
      // enter 已预选 m1（共享 provider 状态可见）。
      expect(
        container.read(messageSelectionProvider(_uk3)).contains('m1'),
        isTrue,
      );
      // 点 m3 勾选框 → 既有 toggle 模型加入；再点 → 取消（取消恒成功）。
      await tester.tap(toggleTarget);
      await tester.pump();
      expect(
        container.read(messageSelectionProvider(_uk3)).contains('m3'),
        isTrue,
      );
      await tester.tap(toggleTarget);
      await tester.pump();
      expect(
        container.read(messageSelectionProvider(_uk3)).contains('m3'),
        isFalse,
      );
      // 点已预选的 m1 → 取消勾选（取消不受可选性限制）。
      await tester.tap(preselected);
      await tester.pump();
      expect(
        container.read(messageSelectionProvider(_uk3)).contains('m1'),
        isFalse,
      );
    },
  );
}
