import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
// ignore: depend_on_referenced_packages
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/web_shell/web_message_content.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('窄屏待确认提示位于消息下方且不压缩正文', (tester) async {
    const message = TextMessage(
      id: 'held-narrow',
      authorId: '1',
      text: '一条需要完整显示的消息正文',
      status: MessageStatus.error,
      metadata: {'_imboy_local_status': 42},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 300,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: ChatMessageList(
                messages: const [message],
                currentUserId: '1',
                onMessageLongPress: (_) {},
                onMessageDoubleTap: (_) {},
                messageContentBuilder: (_, _, _) => const Text('一条需要完整显示的消息正文'),
                messageStatusBuilder: (_, m) => webMessageStatus(
                  m,
                  themeColor: (_) => Colors.red,
                  chatColor: (_) => Colors.blue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final body = tester.getRect(find.text('一条需要完整显示的消息正文'));
    final status = tester.getRect(find.text(t.chat.chatStatusOutcomeUnknown));
    expect(status.top, greaterThanOrEqualTo(body.bottom));
    expect(body.width, greaterThan(180));
  });

  testWidgets('结果待确认显示明确文案而不是普通失败', (tester) async {
    const message = TextMessage(
      id: 'held',
      authorId: '1',
      text: '原文',
      status: MessageStatus.error,
      metadata: {'_imboy_local_status': 42},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: webMessageStatus(
            message,
            themeColor: (_) => Colors.red,
            chatColor: (_) => Colors.blue,
          ),
        ),
      ),
    );
    expect(find.text(t.chat.chatStatusOutcomeUnknown), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.exclamationmark_circle), findsNothing);
  });

  group('Web restricted and historical message bodies', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '1',
        Keys.currentUser: jsonEncode({
          'uid': '1',
          'nickname': 'Synthetic reader',
          'avatar': '',
          'setting': <String, dynamic>{},
        }),
      });
      await StorageService.init();
    });

    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final audio in [true, false]) {
        testWidgets(
          'typed media has a visible limitation: $audio $brightness',
          (tester) async {
            final message = audio
                ? const AudioMessage(
                    id: 'restricted-audio',
                    authorId: 'other',
                    source: 'private/audio',
                    duration: Duration(seconds: 1),
                  )
                : const VideoMessage(
                    id: 'restricted-video',
                    authorId: 'other',
                    source: 'private/video',
                  );
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Scaffold(
                  body: ChatMessageList(
                    messages: [message],
                    currentUserId: 'me',
                    onMessageLongPress: (_) {},
                    onMessageDoubleTap: (_) {},
                    messageContentBuilder: (context, value, index) =>
                        webMessageContent(
                          context: context,
                          message: value,
                          index: index,
                          currentUserId: 'me',
                          theme: brightness == Brightness.dark
                              ? ChatTheme.dark()
                              : ChatTheme.light(),
                        ),
                  ),
                ),
              ),
            );
            expect(
              find.text(audio ? t.chat.voiceMessage : t.chat.videoMessage),
              findsOneWidget,
            );
            expect(
              find.text(
                audio
                    ? t.common.webAudioNotSupported
                    : t.chat.unsupportedMessageType,
              ),
              findsOneWidget,
            );
            expect(find.text('private/audio'), findsNothing);
            expect(find.text('private/video'), findsNothing);
            expect(find.byType(Image), findsNothing);
          },
        );
      }
    }

    testWidgets(
      'unknown and revoked retain their existing safe custom bodies',
      (tester) async {
        const secret = 'original revoked secret must not be visible';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatMessageList(
                messages: const [
                  CustomMessage(
                    id: 'unknown',
                    authorId: 'other',
                    metadata: {'msg_type': 'future-unknown'},
                  ),
                  CustomMessage(
                    id: 'revoked',
                    authorId: 'other',
                    metadata: {
                      'status': 30,
                      'msg_type': 'text',
                      'text': secret,
                      'peer_name': 'Synthetic peer',
                    },
                  ),
                ],
                currentUserId: 'me',
                onMessageLongPress: (_) {},
                onMessageDoubleTap: (_) {},
                messageContentBuilder: (context, value, index) =>
                    webMessageContent(
                      context: context,
                      message: value,
                      index: index,
                      currentUserId: 'me',
                      theme: ChatTheme.light(),
                    ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(t.chat.unsupportedMessageType), findsOneWidget);
        expect(find.textContaining('Synthetic peer'), findsOneWidget);
        expect(find.text(secret), findsNothing);
      },
    );
  });

  testWidgets('own pending image waits for server confirmation', (
    tester,
  ) async {
    Widget? content;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            content = webMessageContent(
              context: context,
              message: const ImageMessage(
                id: 'pending-image',
                authorId: 'me',
                source: 'group/image.png',
                status: MessageStatus.sending,
              ),
              index: 0,
              currentUserId: 'me',
              theme: ChatTheme.light(),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    final imageArea =
        (((content! as Semantics).child! as ConstrainedBox).child! as ClipRRect)
            .child;
    expect(imageArea, isNot(isA<Image>()));
    expect(imageArea, isA<SizedBox>());
    expect((imageArea! as SizedBox).child, isA<Center>());
  });

  testWidgets('confirmed and received images retain authorized loading', (
    tester,
  ) async {
    for (final message in [
      const ImageMessage(
        id: 'own',
        authorId: 'me',
        source: 'group/image.png',
        status: MessageStatus.sent,
      ),
      const ImageMessage(
        id: 'other',
        authorId: 'other',
        source: 'group/image.png',
        status: MessageStatus.sending,
      ),
    ]) {
      Widget? content;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              content = webMessageContent(
                context: context,
                message: message,
                index: 0,
                currentUserId: 'me',
                theme: ChatTheme.light(),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      final child =
          (((content! as Semantics).child! as ConstrainedBox).child!
                  as ClipRRect)
              .child;
      expect(child, isA<Image>());
      expect((child! as Image).image, isA<IMBoyCachedImageProvider>());
    }
  });

  testWidgets(
    'image uses owner-scoped authorized provider with bounded preview and failure semantics',
    (tester) async {
      Widget? content;
      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildContext = context;
              content = webMessageContent(
                context: context,
                message: const ImageMessage(
                  id: 'image',
                  authorId: 'other',
                  source: 'web-mvp-native/u123/c2c/20261113/file_123_ABCD/photo.png',
                  width: 10000,
                  height: 10000,
                ),
                index: 0,
                currentUserId: 'me',
                theme: ChatTheme.light(),
              );
              // Inspect the widget without resolving an image or touching any cache/IO.
              return const SizedBox();
            },
          ),
        ),
      );
      expect(content, isNotNull);
      final semantics = content! as Semantics;
      expect(semantics.properties.label, contains(t.chat.image));
      final bounds = semantics.child! as ConstrainedBox;
      expect(bounds.constraints.maxWidth.isFinite, isTrue);
      expect(bounds.constraints.maxHeight.isFinite, isTrue);
      expect(bounds.constraints.maxWidth, lessThanOrEqualTo(800));
      expect(bounds.constraints.maxHeight, lessThanOrEqualTo(600));
      final clip = bounds.child! as ClipRRect;
      final image = clip.child! as Image;
      final provider = image.image as IMBoyCachedImageProvider;
      expect(
        provider.url,
        'web-mvp-native/u123/c2c/20261113/file_123_ABCD/photo.png',
      );
      expect(provider.publicDirect, isFalse);
      expect(image.gaplessPlayback, isFalse);
      final loading = image.frameBuilder!(
        buildContext,
        const SizedBox(),
        null,
        false,
      ) as SizedBox;
      expect(loading.width, image.width);
      expect(loading.height, image.height);
      final failure = image.errorBuilder!(
        buildContext,
        StateError('synthetic unauthorized'),
        null,
      );
      final failureBox = failure as SizedBox;
      expect(failureBox.width, image.width);
      expect(failureBox.height, image.height);
      await tester.pumpWidget(MaterialApp(home: failure));
      expect(find.text(t.common.imageLoadFailed), findsOneWidget);
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'web text and file are visible and file tap reaches owner ($brightness)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        const text = TextMessage(
          id: 'text',
          authorId: 'other',
          text: 'hello synthetic',
        );
        const file = FileMessage(
          id: 'file',
          authorId: 'other',
          name: 'sample.txt',
          size: 36,
          source: 'private/object',
        );
        Message? tapped;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: ChatMessageList(
                messages: const [file, text],
                currentUserId: 'me',
                onMessageLongPress: (_) {},
                onMessageDoubleTap: (_) {},
                onMessageTap: (message) => tapped = message,
                messageContentBuilder: (context, message, index) =>
                    webMessageContent(
                      context: context,
                      message: message,
                      index: index,
                      currentUserId: 'me',
                      theme: brightness == Brightness.dark
                          ? ChatTheme.dark()
                          : ChatTheme.light(),
                    ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('hello synthetic', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('sample.txt'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp('${t.chat.myReceivedTab}${t.chat.file}'),
          ),
          findsOneWidget,
        );
        expect(find.text('private/object'), findsNothing);
        await tester.tap(find.text('sample.txt'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(tapped, same(file));
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'empty or failed-encryption images expose failure without creating a provider',
    (tester) async {
      for (final message in [
        const ImageMessage(id: 'empty', authorId: 'other', source: ''),
        const ImageMessage(
          id: 'failed',
          authorId: 'other',
          source: 'web-mvp-native/u123/c2c/20261113/file_123_ABCD/photo.png',
          metadata: {'_e2ee_failed': true},
        ),
      ]) {
        Widget? content;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                content = webMessageContent(
                  context: context,
                  message: message,
                  index: 0,
                  currentUserId: 'me',
                  theme: ChatTheme.light(),
                );
                return const SizedBox();
              },
            ),
          ),
        );
        final semantics = content! as Semantics;
        final clip = (semantics.child! as ConstrainedBox).child! as ClipRRect;
        expect(clip.child, isNot(isA<Image>()));
        await tester.pumpWidget(MaterialApp(home: content));
        expect(find.text(t.common.imageLoadFailed), findsOneWidget);
      }
    },
  );

  testWidgets('file timestamp is shown only when known and positive', (
    tester,
  ) async {
    final time = DateTime.utc(2024, 1, 2, 3, 4);
    final messages = [
      FileMessage(
        id: 'known',
        authorId: 'me',
        name: 'known.txt',
        source: 'private/known',
        createdAt: time,
      ),
      FileMessage(
        id: 'zero',
        authorId: 'me',
        name: 'zero.txt',
        source: 'private/zero',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      const FileMessage(
        id: 'missing',
        authorId: 'me',
        name: 'missing.txt',
        source: 'private/missing',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            messages: messages,
            currentUserId: 'me',
            onMessageLongPress: (_) {},
            onMessageDoubleTap: (_) {},
            messageContentBuilder: (context, message, index) =>
                webMessageContent(
                  context: context,
                  message: message,
                  index: index,
                  currentUserId: 'me',
                  theme: ChatTheme.light(),
                ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('1970'), findsNothing);
    expect(find.textContaining('2024'), findsWidgets);
    final cards = tester
        .widgetList<FlyerChatFileMessage>(find.byType(FlyerChatFileMessage))
        .toList();
    expect(cards.singleWhere((x) => x.message.id == 'known').showTime, isTrue);
    expect(cards.singleWhere((x) => x.message.id == 'zero').showTime, isFalse);
    expect(
      cards.singleWhere((x) => x.message.id == 'missing').showTime,
      isFalse,
    );
    expect(
      find.bySemanticsLabel(RegExp('${t.main.sentByMe}${t.chat.file}')),
      findsNWidgets(3),
    );
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final sent in [true, false]) {
      testWidgets(
        'link color and hover contrast match bubble ($brightness sent=$sent)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: Builder(
                  builder: (context) => webMessageContent(
                    context: context,
                    message: TextMessage(
                      id: 'link',
                      authorId: sent ? 'me' : 'other',
                      text: '[open](https://example.invalid)',
                    ),
                    index: 0,
                    currentUserId: 'me',
                    theme: brightness == Brightness.dark
                        ? ChatTheme.dark()
                        : ChatTheme.light(),
                  )!,
                ),
              ),
            ),
          );
          await tester.pump();
          final renderer = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
          final link = renderer.styleSheet!.link!;
          final background = sent
              ? (brightness == Brightness.dark
                    ? AppColors.darkSentMessageBackground
                    : AppColors.lightSentMessageBackground)
              : (brightness == Brightness.dark
                    ? AppColors.darkReceivedMessageBackground
                    : AppColors.lightReceivedMessageBackground);
          double contrast(Color a, Color b) {
            final x = a.computeLuminance(), y = b.computeLuminance();
            return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
          }

          expect(link.color, isNotNull);
          expect(link.hoverColor, link.color);
          expect(link.decoration, TextDecoration.underline);
          expect(contrast(link.color!, background), greaterThanOrEqualTo(4.5));
        },
      );
    }
  }

  testWidgets('own status changes with actual status and hides unknown', (
    tester,
  ) async {
    const statuses = [
      MessageStatus.sending,
      MessageStatus.sent,
      MessageStatus.delivered,
      MessageStatus.seen,
      MessageStatus.error,
    ];
    final labels = [
      t.chat.chatStatusSending,
      t.chat.chatStatusSent,
      t.chat.chatStatusDelivered,
      t.chat.chatStatusSeen,
      t.common.chatStatusFailed,
    ];
    var statusBuilderCalls = 0;
    Widget view(
      MessageStatus? status, {
      bool sent = true,
      bool useWebStatus = true,
    }) => MaterialApp(
      home: Scaffold(
        body: ChatMessageList(
          messages: [
            TextMessage(
              id: 'id',
              authorId: sent ? 'me' : 'other',
              text: 'body',
              status: status,
            ),
          ],
          currentUserId: 'me',
          onMessageLongPress: (_) {},
          onMessageDoubleTap: (_) {},
          messageStatusBuilder: useWebStatus
              ? (context, message) {
                  statusBuilderCalls++;
                  return webMessageStatus(
                    message,
                    themeColor: (_) => Colors.blue,
                    chatColor: (_) => Colors.green,
                  );
                }
              : null,
        ),
      ),
    );
    for (var i = 0; i < statuses.length; i++) {
      await tester.pumpWidget(view(statuses[i]));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.semanticLabel == labels[i],
        ),
        findsOneWidget,
      );
      for (var j = 0; j < labels.length; j++) {
        if (i != j) {
          expect(
            find.byWidgetPredicate(
              (w) => w is Icon && w.semanticLabel == labels[j],
            ),
            findsNothing,
          );
        }
      }
    }
    await tester.pumpWidget(view(null));
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);
    expect(find.byIcon(CupertinoIcons.clock), findsNothing);
    expect(find.byIcon(CupertinoIcons.exclamationmark_circle), findsNothing);
    final previousCalls = statusBuilderCalls;
    await tester.pumpWidget(view(MessageStatus.sent, sent: false));
    expect(statusBuilderCalls, previousCalls);
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);
    // The shared list's existing default remains unchanged for native callers.
    await tester.pumpWidget(view(null, useWebStatus: false));
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
  });

  final imageCases = <String, String>{
    'inline': 'before ![normal](https://example.invalid/inline.png)',
    'reference': 'before ![ref][r]\n\n[r]: https://example.invalid/ref.png',
    'html': 'before <img src="https://example.invalid/html.png">',
  };
  for (final entry in imageCases.entries) {
    testWidgets(
      'untrusted ${entry.key} image reaches non-network placeholder',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => webMessageContent(
                  context: context,
                  message: TextMessage(
                    id: entry.key,
                    authorId: 'other',
                    text: entry.value,
                  ),
                  index: 0,
                  currentUserId: 'me',
                  theme: ChatTheme.light(),
                )!,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.textContaining('before', findRichText: true), findsWidgets);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      },
    );
  }
}
