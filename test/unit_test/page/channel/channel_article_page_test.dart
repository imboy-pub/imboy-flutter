// ChannelArticlePage Widget 测试
//
// 验证频道沉浸式全屏阅读页：
// - 用假 message 构造并 pump，长正文完整渲染（不折叠 / 无省略号）
// - 无评论时展示空态占位 + 评论计数为 0
//
// 依赖注入：channelServiceProvider override 注入 mock，getComments 返回空，
// 不触发真实网络。channelDetailProvider 用默认 build()（channel=null，标题回退）。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_article_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/component/chat/composer_emoji_panel.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/cupertino_modal_surface.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_article_page.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/channel_message_model.dart';

class _MockChannelService extends Mock implements ChannelService {}

// 超过 280 字符的正文——feed 卡片会折叠为 280 + 省略号，阅读页必须完整展示。
final _longContent = '沉浸式全屏阅读正文段落。' * 40;

ChannelMessageModel _fakeMessage({String? content}) => ChannelMessageModel(
  id: 9001,
  channelId: 1001,
  authorId: 2002,
  authorName: '频道作者',
  content: content ?? _longContent,
  msgType: ChannelMessageType.text,
  createdAt: DateTime(2024, 1, 1),
  viewCount: 123,
);

Widget _buildTestApp(ChannelService service, ChannelMessageModel? message) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: ChannelArticlePage(channelId: '1001', message: message),
      ),
    ),
  );
}

Widget _buildAccessibleTestApp(
  ChannelService service,
  ChannelMessageModel message,
) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
    child: TranslationProvider(
      child: ProviderScope(
        overrides: [channelServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ChannelArticlePage(channelId: '1001', message: message),
        ),
      ),
    ),
  );
}

/// 上一页占位文案（用于断言「确实退回去了」）。
const String _previousPageText = '上一页占位';

/// 把阅读页 push 到一条已有路由之上 —— 复刻真实入口
/// （channel_message_item 单击卡片 → `context.push('/channel/:id/article/:mid')`）。
///
/// 为什么不能直接 `home: ChannelArticlePage(...)`：`GlassAppBar` 只在
/// `automaticallyImplyLeading && Navigator.canPop(context)` 时生成返回键，
/// 而 home 是栈底、canPop 恒 false ⇒ 无论开关怎么配都测不到返回键（假绿）。
Widget _buildRootApp(ChannelService service, GlobalKey<NavigatorState> navKey) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Center(child: Text(_previousPageText))),
      ),
    ),
  );
}

void main() {
  late _MockChannelService service;
  setUp(() {
    service = _MockChannelService();
    when(
      () => service.getComments(
        channelId: any(named: 'channelId'),
        messageId: any(named: 'messageId'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);
  });

  testWidgets('外部链接无需 route extra 即可读取文章', (tester) async {
    when(() => service.getMessage('1001', '9001'))
        .thenAnswer((_) async => _fakeMessage(content: '外部文章正文'));
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: ChannelArticlePage(channelId: '1001', messageId: '9001'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('外部文章正文'), findsWidgets);
    verify(() => service.getMessage('1001', '9001')).called(1);
  });

  testWidgets('文章不可访问时可重试，不显示旧正文', (tester) async {
    when(() => service.getMessage('1001', '9001'))
        .thenAnswer((_) async => null);
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: ChannelArticlePage(channelId: '1001', messageId: '9001'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.common.loadError), findsOneWidget);
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    verify(() => service.getMessage('1001', '9001')).called(2);
  });

  testWidgets('长正文完整渲染且不折叠 / renders full body without truncation', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(service, _fakeMessage()));
    await tester.pumpAndSettle();

    // 正文改用 markdown 渲染（channelMarkdownBody）：拆成多 widget，
    // 用 textContaining 校验完整正文落地（未被截断为 280 + 省略号）。
    // 纯文本是合法 markdown，单段渲染故整段可匹配。
    expect(find.textContaining(_longContent), findsWidgets);

    // 未出现折叠省略号截断的正文
    final truncated = '${_longContent.substring(0, 280).trim()}…';
    expect(find.text(truncated), findsNothing);
  });

  testWidgets('imageText：payload.title 作顶部标题、content 作正文', (tester) async {
    final msg = ChannelMessageModel(
      id: 9001,
      channelId: 1001,
      authorId: 2002,
      authorName: '频道作者',
      content: '完整正文内容段落',
      msgType: ChannelMessageType.imageText,
      payload: const {'title': '文章大标题', 'images': <dynamic>[]},
      createdAt: DateTime(2024, 1, 1),
      viewCount: 1,
    );
    await tester.pumpWidget(_buildTestApp(service, msg));
    await tester.pumpAndSettle();

    // 顶部标题取 payload.title（仍是普通 Text heading，非 markdown）
    expect(find.text('文章大标题'), findsOneWidget);
    // content 完整作正文（markdown 渲染），不被切首行
    expect(find.textContaining('完整正文内容段落'), findsWidgets);
  });

  testWidgets('无评论时展示空态占位 / shows empty placeholder when no comments', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(service, _fakeMessage(content: '短正文')),
    );
    await tester.pumpAndSettle();

    verify(
      () => service.getComments(
        channelId: '1001',
        messageId: '9001',
        cursor: 0,
        limit: 20,
      ),
    ).called(1);
    expect(find.text(t.channel.noComments), findsOneWidget);
  });

  testWidgets('message 为空时降级空态 / degrades to empty view when message is null', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(service, null));
    await tester.pumpAndSettle();

    // 未加载评论（message 为空直接返回）
    verifyNever(
      () => service.getComments(
        channelId: any(named: 'channelId'),
        messageId: any(named: 'messageId'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    );
    expect(find.text(t.common.loadError), findsOneWidget);
  });

  testWidgets('暗色大字号下阅读页操作与 feed 使用统一读屏语义', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      _buildAccessibleTestApp(service, _fakeMessage(content: '正文内容')),
    );
    await tester.pumpAndSettle();

    bool hasExplicitLabel(String label) => find
        .byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        )
        .evaluate()
        .isNotEmpty;

    expect(hasExplicitLabel(t.channel.like), isTrue);
    expect(hasExplicitLabel(t.channel.comment), isTrue);
    expect(hasExplicitLabel(t.channel.share), isTrue);
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
  });

  testWidgets('表情面板使用底栏全宽且无布局异常', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(service, _fakeMessage(content: '正文内容')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('composer_emoji_button')));
    await tester.pumpAndSettle();

    final panel = find.byType(ComposerEmojiPanel);
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, greaterThan(350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('发送按钮仅在输入评论后出现', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(service, _fakeMessage(content: '正文内容')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(t.common.buttonSend), findsNothing);
    await tester.enterText(
      find.byKey(const Key('composer_text_field')),
      '一条评论',
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(t.common.buttonSend), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('拖拽阅读列表会收起系统键盘', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(service, _fakeMessage(content: '正文内容')),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(
      scrollView.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('分享弹窗使用不透明主题表面', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(service, _fakeMessage(content: '正文内容')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.channel.share).last);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoModalSurface), findsOneWidget);
  });

  // 背景：阅读页此前写作 `GlassAppBar(title: title)`，而 GlassAppBar 的
  // automaticallyImplyLeading **默认 false** ⇒ 左上角没有返回键。沉浸阅读页是
  // 被 push 进来的全屏页，用户在左上角找不到退路（只能靠系统返回手势）。
  group('左上角返回上一页', () {
    /// push 阅读页并等动画结束；返回 navKey 供断言栈状态。
    Future<void> pushArticle(
      WidgetTester tester,
      GlobalKey<NavigatorState> navKey,
      ChannelMessageModel? message,
    ) async {
      await tester.pumpWidget(_buildRootApp(service, navKey));
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChannelArticlePage(channelId: '1001', message: message),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('有上一页时展示返回键，点击即回到上一页', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await pushArticle(tester, navKey, _fakeMessage(content: '正文内容'));

      expect(find.byType(ChannelArticlePage), findsOneWidget);
      expect(
        find.byType(GlassBackButton),
        findsOneWidget,
        reason: '阅读页左上角必须有返回上一页按钮',
      );

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelArticlePage), findsNothing);
      expect(find.text(_previousPageText), findsOneWidget);
    });

    testWidgets('message 丢失的降级态同样可返回', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await pushArticle(tester, navKey, null);

      // 降级分支（无 message）也要有退路，否则深链落到空态就卡死。
      expect(find.text(t.common.loadError), findsOneWidget);
      expect(find.byType(GlassBackButton), findsOneWidget);
    });

    testWidgets('栈底（无上一页）不显示返回键，避免死键', (tester) async {
      // 对照组：深链直开时 canPop=false，返回键必须缺席，
      // 否则点了没反应，比没有更糟。
      await tester.pumpWidget(_buildTestApp(service, _fakeMessage()));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelArticlePage), findsOneWidget);
      expect(find.byType(GlassBackButton), findsNothing);
    });
  });
}
