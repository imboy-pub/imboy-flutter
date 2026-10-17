import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_message_item.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/channel/widgets/channel_role_badge.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';

ChannelModel _channel({bool managed = false}) => ChannelModel(
  id: 1001,
  name: '工程效率与产品发布特别特别长的频道名称',
  description: '频道介绍与使用说明。' * 12,
  tags: const ['效率', '工程', '发布', '公告', '讨论', '资料', '第七个标签'],
  subscriberCount: 12,
  visibility: 0,
  accessType: 0,
  joinPolicy: 0,
  isVerified: true,
  userRole: managed ? ChannelUserRole.admin : ChannelUserRole.none,
  creatorId: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

class _DetailFixture extends ChannelDetailNotifier {
  _DetailFixture(
    this.channel, {
    this.empty = false,
    this.messageType = ChannelMessageType.text,
  });
  final ChannelModel channel;
  final bool empty;
  final String messageType;

  @override
  Future<void> loadChannel(String channelId) async {
    state = ChannelDetailState(
      channel: channel,
      messages: empty
          ? const []
          : [
              ChannelMessageModel(
                id: 1,
                channelId: 1001,
                content: '首条置顶内容：工程实践与产品更新。',
                msgType: messageType,
                payload: const {
                  'uri': 'def_avatar.png',
                  'thumb': 'def_avatar.png',
                  'name': 'fixture.pdf',
                  'size': 1024,
                  'duration_ms': 12000,
                },
                isPinned: true,
                createdAt: DateTime(2024, 1, 1),
              ),
            ],
      hasMore: false,
    );
  }

  @override
  Future<void> loadMoreMessages() async {}

  @override
  Future<void> markAsRead(String messageId) async {}
}

class _SilentPlayback extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool empty = false,
  String messageType = ChannelMessageType.text,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final channel = _channel(managed: empty);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const ChannelDetailPage(channelId: '1001', autoLoadStats: false),
      ),
      for (final path in [
        '/channel/:id/edit',
        '/channel/:id/admins',
        AppRoutes.momentCreate,
      ])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('${state.uri.path}\n${state.extra}'),
          ),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          channelDetailProvider.overrideWith(
            () =>
                _DetailFixture(channel, empty: empty, messageType: messageType),
          ),
          voicePlaybackServiceProvider.overrideWith(_SilentPlayback.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final type in [
    ChannelMessageType.image,
    ChannelMessageType.video,
    ChannelMessageType.file,
    ChannelMessageType.audio,
  ]) {
    testWidgets('现有 $type 内容与互动入口仍可展示', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, messageType: type);
      final item = find.byType(ChannelMessageItem);
      expect(item, findsOneWidget);
      for (final label in [
        t.channel.like,
        t.channel.comment,
        t.channel.share,
      ]) {
        expect(
          find.descendant(
            of: item,
            // 点赞在有反应计数时 semantics 为「点赞: N」（计数对读屏更
            // 完整），按前缀匹配；comment/share 恒为固定文案。
            matching: find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}')),
          ),
          findsOneWidget,
        );
      }
      if (type == ChannelMessageType.file) {
        expect(find.text('fixture.pdf'), findsOneWidget);
      }
      if (type == ChannelMessageType.audio) {
        expect(find.text("12''"), findsOneWidget);
      }
      if (type == ChannelMessageType.image) {
        expect(
          find.descendant(of: item, matching: find.byType(Image)),
          findsOneWidget,
        );
      }
      if (type == ChannelMessageType.video) {
        expect(find.byIcon(CupertinoIcons.play_arrow), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      // 框架在 teardown 前校验 SemanticsHandle，须在 body 末尾显式释放
      // （项目惯例：channel_article_page_test.dart:200 同法）。
      semantics.dispose();
    });
  }

  testWidgets('首屏内容优先，说明与全部标签通过原频道信息入口可达', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(ChannelHeaderBar)).height, lessThan(220));
    expect(tester.getTopLeft(find.text('首条置顶内容：工程实践与产品更新。')).dy, lessThan(400));
    expect(find.textContaining('#第七个标签'), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.channel.info));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text(_channel().description!), findsOneWidget);
    expect(find.textContaining('#第七个标签'), findsOneWidget);
    expect(
      find.text('${t.channel.privacyTitle} · ${t.channel.privacyDesc}'),
      findsOneWidget,
    );
    expect(find.text('${t.channel.subscribers}: 12'), findsOneWidget);
    await tester.tap(find.text(t.common.ok));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情只保留头部一份角色徽标', (tester) async {
    await _pump(tester, empty: true);
    expect(find.byType(ChannelRoleBadge), findsOneWidget);
    expect(find.text(channelRoleLabel(ChannelUserRole.admin)), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  for (final action in ['edit', 'admins', 'moment']) {
    testWidgets('空态 $action 保留原路由与载荷', (tester) async {
      await _pump(tester, empty: true);
      final label = switch (action) {
        'edit' => t.channel.settings,
        'admins' => t.channel.inviteAdmins,
        _ => t.channel.shareToMyStatus,
      };
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      final path = action == 'moment'
          ? AppRoutes.momentCreate
          : '/channel/1001/$action';
      expect(find.textContaining(path), findsOneWidget);
      if (action == 'edit') {
        expect(find.textContaining('ChannelModel(id: 1001'), findsOneWidget);
      }
      if (action == 'moment') {
        expect(find.textContaining('channel/1001'), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ChannelDetailPage), findsOneWidget);
    });
  }

  for (final profile in [
    (width: 390.0, scale: 1.0, brightness: Brightness.light),
    (width: 360.0, scale: 1.0, brightness: Brightness.light),
    (width: 360.0, scale: 2.0, brightness: Brightness.dark),
    (width: 1280.0, scale: 1.0, brightness: Brightness.dark),
    (width: 1280.0, scale: 2.0, brightness: Brightness.light),
  ]) {
    for (final empty in [false, true]) {
      final name =
          '${empty ? 'empty' : 'content'}_${profile.width.toInt()}_'
          '${profile.scale.toInt()}_${profile.brightness.name}';
      testWidgets('golden: t09_$name', (tester) async {
        await _pump(
          tester,
          width: profile.width,
          scale: profile.scale,
          brightness: profile.brightness,
          empty: empty,
        );
        await expectLater(
          find.byType(Scaffold).first,
          matchesGoldenFile('goldens/t09_$name.png'),
        );
      });
    }
  }
}
