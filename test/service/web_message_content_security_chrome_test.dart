@TestOn('chrome')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
// ignore: depend_on_referenced_packages
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_message_content.dart';
import 'package:web/web.dart' as web;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_web/url_launcher_web.dart';

const _origin = String.fromEnvironment('WEB_CONTROL_TEST_ORIGIN');

Future<List<Object?>> _stats(String name) async {
  final response = await web.window
      .fetch('$_origin/stats?case=$name'.toJS)
      .toDart;
  expect(response.status, 200);
  return jsonDecode((await response.text().toDart).toDart) as List<Object?>;
}

Future<T> _realAsync<T>(WidgetTester tester, Future<T> Function() body) async {
  final result = await tester.runAsync(
    () => body().timeout(const Duration(seconds: 6)),
  );
  final error = tester.takeException();
  if (error != null) {
    throw StateError('real async failed: ${error.runtimeType}');
  }
  if (result == null) throw StateError('real async operation returned null');
  return result;
}

Widget _content(String text) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => webMessageContent(
        context: context,
        message: TextMessage(id: 'm', authorId: 'sender', text: text),
        index: 0,
        currentUserId: 'recipient',
        theme: ChatTheme.light(),
      )!,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final uri = Uri.parse(_origin);
    expect(uri.scheme, 'http');
    expect({'localhost', '127.0.0.1'}, contains(uri.host));
    expect(uri.userInfo, isEmpty);
  });

  testWidgets('markdown images do not contact remote servers', (tester) async {
    // The control must hit the server, or a zero-request assertion means nothing.
    debugPrint('stage control fetch');
    final status = await _realAsync(tester, () async {
      final response = await web.window
          .fetch('$_origin/resource/data?case=md-control'.toJS)
          .toDart;
      return response.status;
    });
    expect(status, 200);
    final control = await _realAsync(tester, () => _stats('md-control'));
    expect(control, hasLength(1));
    final imageCases = <String, String>{
      'md-inline':
          'Text before ![normal]($_origin/resource/data?case=md-inline)',
      'md-ref':
          'Text before ![ref][r]\n\n[r]: $_origin/resource/data?case=md-ref',
      'md-html': 'Text before <img src="$_origin/resource/data?case=md-html">',
    };
    for (final entry in imageCases.entries) {
      debugPrint('stage render ${entry.key}');
      await tester.pumpWidget(_content(entry.value));
      await tester.pump();
      await _realAsync(tester, () async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return true;
      });
      await tester.pump();
      expect(
        find.textContaining('Text before', findRichText: true),
        findsWidgets,
      );
      // Proves this exact syntax reached the defensive image builder.
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      debugPrint('stage image request verification ${entry.key}');
      expect(await _realAsync(tester, () => _stats(entry.key)), isEmpty);
    }
  });

  testWidgets('a normal web link uses isolated browser opening', (
    tester,
  ) async {
    var stage = 'window setup';
    JSObject? window;
    JSAny? original;
    final key = 'open'.toJS;
    var installed = false;
    final opened = <List<String>>[];
    final priorLauncher = UrlLauncherPlatform.instance;
    try {
      // flutter test does not register the web plugin; exercise the real plugin.
      UrlLauncherPlatform.instance = UrlLauncherPlugin();
      window = web.window as JSObject;
      original = window.getProperty<JSAny?>(key);
      window.setProperty(
        key,
        ((JSString url, JSString target, JSString features) {
          opened.add([url.toDart, target.toDart, features.toDart]);
        }).toJS,
      );
      installed = true;
      debugPrint(
        'link stage: $stage installed launcher=${UrlLauncherPlatform.instance.runtimeType}',
      );
      stage = 'render link';
      await tester.pumpWidget(
        _content('[open link]($_origin/resource/data?case=md-link)'),
      );
      await tester.pump();
      final renderError = tester.takeException();
      if (renderError != null) {
        throw StateError('render exception: $renderError');
      }
      final link = find.text('open link', findRichText: true);
      debugPrint('link stage: rendered, matches=${link.evaluate().length}');
      expect(link, findsOneWidget);
      stage = 'locate link text';
      final paragraph = tester.renderObject<RenderParagraph>(link);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      debugPrint('link stage: text boxes=${boxes.length}');
      expect(boxes, isNotEmpty);
      stage = 'tap link';
      await tester.tapAt(paragraph.localToGlobal(boxes.first.toRect().center));
      await tester.pump(const Duration(milliseconds: 500));
      final tapError = tester.takeException();
      if (tapError != null) throw StateError('tap exception: $tapError');
      final tapOpenCount = opened.length;
      debugPrint(
        'link stage: tapped, open count=$tapOpenCount; failure toast=${find.text(t.common.cannotOpenWebpage).evaluate().length}',
      );
      if (tapOpenCount == 0) {
        stage = 'diagnostic direct callback';
        tester
            .widget<GptMarkdown>(find.byType(GptMarkdown))
            .onLinkTap
            ?.call('$_origin/resource/data?case=md-link', 'open link');
        await tester.pump(const Duration(milliseconds: 500));
        debugPrint(
          'link diagnostic: direct callback open count=${opened.length}; failure toast=${find.text(t.common.cannotOpenWebpage).evaluate().length}',
        );
        stage = 'diagnostic real event loop';
        await _realAsync(tester, () async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return true;
        });
        await tester.pump();
        debugPrint(
          'link diagnostic: after real async open count=${opened.length}; failure toast=${find.text(t.common.cannotOpenWebpage).evaluate().length}',
        );
        if (opened.isEmpty) {
          stage = 'diagnostic platform call';
          try {
            final result = await _realAsync(
              tester,
              () => launchUrl(
                Uri.parse('$_origin/resource/data?case=md-link'),
                webOnlyWindowName: '_blank',
              ),
            );
            debugPrint(
              'link diagnostic: direct platform result=$result open count=${opened.length}',
            );
          } on Object catch (error) {
            debugPrint(
              'link diagnostic: direct platform exception=${error.runtimeType} error=$error',
            );
          }
        }
      }
      stage = 'check browser open';
      expect(tapOpenCount, 1);
      expect(opened.single[0], '$_origin/resource/data?case=md-link');
      expect(opened.single[1], '_blank');
      expect(opened.single[2], contains('noopener'));
      expect(opened.single[2], contains('noreferrer'));
      stage = 'check no request from stub';
      expect(await _realAsync(tester, () => _stats('md-link')), isEmpty);
      debugPrint('link stage: verified');
    } on Object catch (error) {
      debugPrint(
        'link diagnostic: stage=$stage type=${error.runtimeType} error=$error',
      );
      rethrow;
    } finally {
      if (installed) window!.setProperty(key, original);
      UrlLauncherPlatform.instance = priorLauncher;
    }
  });
}
