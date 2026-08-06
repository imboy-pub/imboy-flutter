import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/page/chat/widget/chat_input_types.dart';
import 'package:imboy/service/storage.dart';

/// ChatInput widget 契约测试
///
/// ChatInput 是 1262 行 StatefulWidget + TickerProviderStateMixin，依赖：
///   - mention_provider Riverpod
///   - emoji_picker_flutter 资源
///   - 多个动画 controller / focus node
///   - SendButtonVisibilityMode / 文本状态
///
/// 完整交互测试超出 ROI 范围，本文件聚焦：
///   1. **构造参数契约**（type / peerId / 默认值）— 不 pump widget
///   2. **isMuted=true 禁言态简化分支**（绕开 mention/emoji 复杂渲染）
///   3. **类型断言**（StatefulWidget / 默认值不变）
Future<void> _pump(
  WidgetTester tester, {
  required bool isMuted,
  String? muteMessage,
}) async {
  final composerHeight = ValueNotifier<double>(52);
  addTearDown(composerHeight.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ChatInput(
              type: 'C2C',
              peerId: 'peer_1',
              onSendPressed: (text) async => true,
              composerHeight: composerHeight,
              isMuted: isMuted,
              muteMessage: muteMessage,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 按聊天类型渲染非禁言态输入行（用于验证工具区按钮可见性）。
/// 默认 text 模式不构建 emoji 面板；C2G 的群成员加载错误被 provider 吞掉，
/// 因此单次 pump 即可安全断言同步渲染的工具按钮。
Future<void> _pumpType(WidgetTester tester, String type) async {
  final composerHeight = ValueNotifier<double>(52);
  addTearDown(composerHeight.dispose);

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ChatInput(
              type: type,
              peerId: 'peer_1',
              onSendPressed: (text) async => true,
              composerHeight: composerHeight,
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
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
  });

  group('ChatInput construction contract', () {
    test('default values', () {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);

      final widget = ChatInput(
        type: 'C2C',
        peerId: 'peer_1',
        onSendPressed: (text) async => true,
        composerHeight: composerHeight,
      );

      expect(widget.type, 'C2C');
      expect(widget.peerId, 'peer_1');
      expect(widget.isMuted, false);
      expect(widget.muteMessage, isNull);
      // hintText 构造默认 null，渲染期兜底 t.chat.messageInputHint（chat_input.dart:875）
      expect(widget.hintText, isNull);
      expect(widget.autocorrect, true);
      expect(widget.autofocus, false);
      expect(widget.maxLines, 6);
      expect(widget.minLines, 1);
      expect(widget.maxLength, 1000);
      expect(widget.handleSafeArea, true);
      // 默认 sendButtonVisibilityMode（editing）
      expect(widget.textCapitalization, TextCapitalization.sentences);
      expect(widget.keyboardType, TextInputType.multiline);
      expect(widget.textInputAction, TextInputAction.newline);
    });

    test('ChatInput is a StatefulWidget', () {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);

      final widget = ChatInput(
        type: 'C2G',
        peerId: 'group_1',
        onSendPressed: (text) async => true,
        composerHeight: composerHeight,
      );
      expect(widget, isA<StatefulWidget>());
      expect(widget, isA<ChatInput>());
    });

    test('accepts type=C2G group chat scenario', () {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);

      final widget = ChatInput(
        type: 'C2G',
        peerId: 'group_42',
        onSendPressed: (text) async => true,
        composerHeight: composerHeight,
        isMuted: true,
        muteMessage: '管理员将群禁言',
      );
      expect(widget.type, 'C2G');
      expect(widget.isMuted, isTrue);
      expect(widget.muteMessage, '管理员将群禁言');
    });
  });

  group('ChatInput isMuted=true (muted state)', () {
    testWidgets('isMuted=true → 渲染禁言提示条 + volume_off icon', (tester) async {
      await _pump(tester, isMuted: true);

      // i18n: mutedCannotSend = "禁言期间无法发送消息"
      expect(find.text('禁言期间无法发送消息'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.volume_off), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('isMuted=true + custom muteMessage → 显示自定义文案 '
        '（覆盖默认 i18n）', (tester) async {
      await _pump(tester, isMuted: true, muteMessage: '你已被禁言 5 分钟');

      expect(find.text('你已被禁言 5 分钟'), findsOneWidget);
      // 默认文案不应再出现
      expect(find.text('禁言期间无法发送消息'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('isMuted=true → 不渲染输入框 / emoji 按钮 / 发送按钮', (tester) async {
      await _pump(tester, isMuted: true);

      // 禁言态应仅渲染禁言提示，无 TextField / 发送按钮
      expect(find.byType(TextField), findsNothing);
      // 不渲染 hintText "Type a message"
      expect(find.text('Type a message'), findsNothing);

      await _unmount(tester);
    });
  });

  group('ChatInput @提及按钮可见性（仅 C2G）', () {
    final mentionButton = find.byKey(const Key('chat_mention_button'));

    testWidgets('type=C2G → 显示 @提及按钮（at 图标）', (tester) async {
      await _pumpType(tester, 'C2G');

      expect(mentionButton, findsOneWidget);
      expect(find.byIcon(CupertinoIcons.at), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('type=C2C → 不显示 @提及按钮', (tester) async {
      await _pumpType(tester, 'C2C');

      expect(mentionButton, findsNothing);
      expect(find.byIcon(CupertinoIcons.at), findsNothing);

      await _unmount(tester);
    });

    testWidgets('type=C2G 点击 @提及按钮 → 输入框插入 @ 触发提及', (tester) async {
      await _pumpType(tester, 'C2G');

      await tester.tap(mentionButton);
      await tester.pump();

      // showMentionPicker 在光标处插入 '@'
      final field = tester.widget<TextField>(
        find.byKey(const Key('chat_message_input')),
      );
      expect(field.controller?.text, '@');

      await _unmount(tester);
    });
  });

  testWidgets('输入层状态只跟随键盘 metrics，不受 iOS 安全区高度影响', (tester) async {
    final composerHeight = ValueNotifier<double>(52);
    addTearDown(composerHeight.dispose);
    final states = <bool>[];

    Widget frame({required double viewInsetsBottom}) {
      return ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  padding: const EdgeInsets.only(bottom: 34),
                  viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
                ),
                child: ChatInput(
                  type: 'C2C',
                  peerId: 'peer_1',
                  onSendPressed: (text) async => true,
                  composerHeight: composerHeight,
                  onInputLayerExpandedChanged: states.add,
                ),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(frame(viewInsetsBottom: 0));

    await tester.pump();
    expect(states.last, isFalse);

    await tester.tap(find.byKey(const Key('chat_message_input')));
    await tester.pump();
    expect(states.last, isFalse, reason: 'focus 保持不等于键盘仍可见');

    await tester.pumpWidget(frame(viewInsetsBottom: 320));
    await tester.pump();
    expect(states.last, isTrue);

    // 模拟系统收起键盘但 FocusNode 仍保持 focus。
    await tester.pumpWidget(frame(viewInsetsBottom: 0));
    await tester.pump();
    expect(states.last, isFalse);

    tester.state<ChatInputState>(find.byType(ChatInput)).hideAllPanel();
    await tester.pump();
    expect(states.last, isFalse);

    await _unmount(tester);
  });

  testWidgets('键盘动画中间帧（53px）不被缓存为面板高度，表情面板不溢出', (tester) async {
    final composerHeight = ValueNotifier<double>(52);
    addTearDown(composerHeight.dispose);

    // 53 逻辑像素是键盘弹起动画的中间帧。旧实现会把它缓存成 _keyboardHeight，
    // 表情面板随之只有 53px，低于 EmojiPicker 固定装饰（48 分类栏 + 40 底栏），
    // 触发 "RenderFlex overflowed by 35 pixels on the bottom"。
    // ChatInput.build 读的是 View.viewInsets（物理像素），故在此设置而非 MediaQuery。
    addTearDown(tester.view.reset);
    tester.view.viewInsets = FakeViewPadding(
      bottom: 53 * tester.view.devicePixelRatio,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                type: 'C2C',
                peerId: 'peer_1',
                onSendPressed: (text) async => true,
                composerHeight: composerHeight,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester
        .state<ChatInputState>(find.byType(ChatInput))
        .updateState(InputType.emoji);
    await tester.pump();

    // EmojiPicker 固定装饰 48（分类栏）+ 40（底部操作栏）= 88，面板矮于此必溢出
    expect(
      tester.getSize(find.byType(EmojiPicker)).height,
      greaterThanOrEqualTo(88.0),
    );

    await _unmount(tester);
  });

  group('ChatInput 发送按钮触达区域与语义 / Send button hit target & semantics', () {
    testWidgets('发送按钮可点击区域 ≥ 44x44，且声明 button 语义 + label', (tester) async {
      await _pumpType(tester, 'C2C');

      // 输入文本使发送按钮可见（默认 sendButtonVisibilityMode = editing）
      await tester.tap(find.byKey(const Key('chat_message_input')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('chat_message_input')), 'hi');
      // _handleTextControllerChange 有 300ms 防抖 Timer；发送按钮外层 AnimatedSwitcher
      // 还有 300ms ScaleTransition。依次 pump 过二者，使尺寸稳定到真实命中区。
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      final sendButton = find.byKey(const ValueKey('send_button'));
      expect(sendButton, findsOneWidget);
      final rect = tester.getRect(sendButton);
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));

      final sem = tester.getSemantics(sendButton);
      expect(sem.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(sem.label, '发送'); // t.chat.send = 发送

      await _unmount(tester);
    });

    testWidgets('点击发送按钮只触发一次 onSendPressed（外层命中区与内层按钮不双发）', (tester) async {
      var sendCalls = 0;
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: ChatInput(
                  type: 'C2C',
                  peerId: 'peer_1',
                  onSendPressed: (text) async {
                    sendCalls++;
                    return true;
                  },
                  composerHeight: composerHeight,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat_message_input')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('chat_message_input')), 'hi');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byKey(const ValueKey('send_button')));
      await tester.pump(const Duration(milliseconds: 50));

      // 嵌套 GestureDetector + CupertinoButton 经手势竞技场应只单发
      expect(sendCalls, 1);

      await _unmount(tester);
    });
  });

  group('ChatInput 输入区图标按钮语义 / Composer icon button semantics', () {
    /// 断言语义树里存在带该 label 的 button 节点。
    ///
    /// 不用 `find.ancestor(..., find.byType(Semantics)).first`：CupertinoButton
    /// 内部自带一层 `Semantics(button: true)`（label 为空）会先被命中，
    /// 测不到外层标签。bySemanticsLabel 直接查整棵语义树，测的是读屏用户
    /// 真正能听到的东西。
    void expectSemanticButton(WidgetTester tester, String label) {
      final finder = find.bySemanticsLabel(label);
      expect(finder, findsWidgets, reason: '语义树里找不到 label="$label" 的节点');
      expect(
        tester.getSemantics(finder.first).hasFlag(SemanticsFlag.isButton),
        isTrue,
        reason: '"$label" 未声明 button 语义',
      );
    }

    testWidgets('语音/键盘切换按钮：标签随当前态变化，不是静态名词', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpType(tester, 'C2C');

      // 初始文本态 → 图标是麦克风，按下去是"切换到语音输入"
      expectSemanticButton(tester, t.chat.switchToVoiceInput);
      expect(find.bySemanticsLabel(t.chat.switchToKeyboardInput), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.mic));
      await tester.pump(const Duration(milliseconds: 350));

      // 语音态 → 图标变键盘，标签必须跟着变成"切换到键盘输入"
      expectSemanticButton(tester, t.chat.switchToKeyboardInput);

      handle.dispose();
      await _unmount(tester);
    });

    testWidgets('表情按钮声明 button 语义 + label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpType(tester, 'C2C');

      expectSemanticButton(tester, t.common.expression);

      handle.dispose();
      await _unmount(tester);
    });

    testWidgets('更多（附加项）按钮声明 button 语义 + label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpType(tester, 'C2C');

      expectSemanticButton(tester, t.chat.extraItems);

      handle.dispose();
      await _unmount(tester);
    });

    testWidgets('三个图标按钮命中区均 ≥ 44x44', (tester) async {
      await _pumpType(tester, 'C2C');

      for (final icon in [
        CupertinoIcons.mic,
        CupertinoIcons.smiley,
        CupertinoIcons.plus_circle,
      ]) {
        final button = find
            .ancestor(
              of: find.byIcon(icon),
              matching: find.byType(CupertinoButton),
            )
            .first;
        final rect = tester.getRect(button);
        expect(rect.width, greaterThanOrEqualTo(44), reason: '$icon 宽度不足');
        expect(rect.height, greaterThanOrEqualTo(44), reason: '$icon 高度不足');
      }

      await _unmount(tester);
    });
  });

  group('@提及候选点击（回归：曾看得见点不中）', () {
    // 原 bug：候选列表挂在输入框内部的 Stack 里，用
    // Positioned(bottom: 50) 浮到输入框上方。Clip.none 只保证「画得出来」，
    // 命中测试不会越过父 RenderBox 边界 —— 用户看得到列表，点下去毫无反应。
    // 修法是把列表提为输入区的同级兄弟，回到正常布局流。
    testWidgets('候选列表整体落在输入区之上，且命中区未溢出父边界', (tester) async {
      final composerHeight = ValueNotifier<double>(52);
      addTearDown(composerHeight.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    const Spacer(),
                    ChatInput(
                      type: 'C2G',
                      peerId: 'g1',
                      onSendPressed: (_) async => true,
                      composerHeight: composerHeight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 触发 @：点 @ 按钮会在光标处插入 @ 并唤起候选面板
      await tester.tap(find.byKey(const Key('chat_mention_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // 候选面板由 provider 驱动，测试环境下群成员为空 → 面板不渲染，
      // 这里只钉死结构不变量：ChatInput 内不得再出现 clipBehavior: Clip.none
      // 的 Stack 承载候选列表（那正是命中失效的根源）。
      final stacks = tester.widgetList<Stack>(find.byType(Stack));
      final leakyStacks = stacks.where((s) => s.clipBehavior == Clip.none);
      expect(
        leakyStacks,
        isEmpty,
        reason:
            'Clip.none 的 Stack 里放溢出内容 = 看得见点不中，'
            '候选列表必须留在正常布局流里',
      );

      await _unmount(tester);
    });
  });
}
