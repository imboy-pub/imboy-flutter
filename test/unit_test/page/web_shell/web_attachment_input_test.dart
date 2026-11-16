@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/upload/upload_mime.dart';
import 'package:imboy/component/helper/func.dart' show formatBytes;
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/web_shell/web_attachment_input.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Only OS picker I/O is substituted. These cases do not upload or prove direct-v1.
final class _File extends PlatformFile {
  _File(
    this.name, {
    this.readGate,
    this.declaredLength,
    this.unknownLength = false,
    Uint8List? content,
  }) : bytes = content ?? Uint8List.fromList([1, 2, 3]);
  @override
  final String name;
  final Future<void>? readGate;
  final int? declaredLength;
  final bool unknownLength;
  final Uint8List bytes;
  int reads = 0;
  @override
  Uri get uri => Uri.file('/synthetic/$name');
  @override
  int? lengthSync() => unknownLength ? null : declaredLength ?? bytes.length;
  @override
  Future<int?> length() async {
    if (unknownLength) {
      throw StateError('unbounded length fallback must not run');
    }
    return lengthSync();
  }

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return bytes;
  }

  @override
  Stream<Uint8List> readAsByteStream() async* {
    reads++;
    if (readGate != null) {
      await readGate;
    }
    yield bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

// Reject-only tripwire: a bad preview must never start product HTTP.
class _NoNetwork implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw StateError('Bad preview must not upload');
  }

  @override
  void close({bool force = false}) {}
}

class _Picker extends FilePickerPlatform {
  Future<List<PlatformFile>> result = Future.value([]);
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) => result;
}

void main() {
  late FilePickerPlatform original;
  late _Picker picker;
  late FocusNode focus;
  late GlobalKey region;
  var current = true;
  final pick = find.byKey(const ValueKey('web-attachment-file'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '900001'});
    await StorageService.init();
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    focus = FocusNode();
    region = GlobalKey();
    current = true;
  });
  tearDown(() {
    FilePickerPlatform.instance = original;
    focus.dispose();
  });

  Future<void> pump(WidgetTester tester, {String peer = '990001'}) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: AppLoading.init(),
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Scaffold(
            body: Container(
              key: region,
              child: WebAttachmentInput(
                key: const ValueKey('attachment-composer'),
                selection: ChatSelection(peerId: peer, chatType: 'C2C'),
                currentUserId: '900001',
                isCurrent: () => current,
                inputFocus: focus,
                regionKey: region,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpUntilPreviewReady(WidgetTester tester) async {
    // Decode runs on the engine; advance real I/O instead of fake animation time.
    final decoded = find.descendant(
      of: find.byType(Image),
      matching: find.byWidgetPredicate(
        (widget) => widget is RawImage && widget.image != null,
      ),
    );
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (decoded.evaluate().length == 1 &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        return;
      }
    }
    expect(find.byType(Image), findsOneWidget);
    expect(decoded, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }

  testWidgets('selection and remove stay local until explicit send', (
    tester,
  ) async {
    final file = _File('local.bin');
    picker.result = Future.value([file]);
    await pump(tester);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    expect(find.textContaining('local.bin'), findsOneWidget);
    expect(file.reads, 1);
    await tester.tap(find.byTooltip(t.common.buttonRemove));
    await tester.pump();
    expect(find.textContaining('local.bin'), findsNothing);
  });

  testWidgets(
    'late picker cannot enter next peer and reset permits new selection',
    (tester) async {
      final pending = Completer<List<PlatformFile>>();
      picker.result = pending.future;
      await pump(tester);
      await tester.tap(pick);
      await tester.pump();
      await pump(tester, peer: '990002');
      final old = _File('old.bin');
      pending.complete([old]);
      await tester.pumpAndSettle();
      expect(find.textContaining('old.bin'), findsNothing);
      expect(old.reads, 0);
      picker.result = Future.value([_File('current.bin')]);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      expect(find.textContaining('current.bin'), findsOneWidget);
    },
  );

  testWidgets('late byte stream cannot enter new peer', (tester) async {
    final read = Completer<void>();
    final old = _File('old-length.bin', readGate: read.future);
    picker.result = Future.value([old]);
    await pump(tester);
    await tester.tap(pick);
    await tester.pump();
    await pump(tester, peer: '990002');
    read.complete();
    await tester.pumpAndSettle();
    expect(old.reads, 1);
    expect(find.textContaining('old-length.bin'), findsNothing);
    current = false;
    await pump(tester, peer: '990002');
    expect(tester.widget<IconButton>(pick).onPressed, isNull);
  });

  testWidgets('retained budget rejects next declared 100MiB before reading', (
    tester,
  ) async {
    picker.result = Future.value([_File('retained.bin')]);
    await pump(tester);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    final next = _File(
      'would-overflow.bin',
      declaredLength: AttachmentApi.maxUploadBytes,
    );
    picker.result = Future.value([next]);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    expect(next.reads, 0);
    expect(find.textContaining('retained.bin'), findsOneWidget);
    expect(find.textContaining('would-overflow.bin'), findsNothing);
    expect(find.textContaining(t.main.cache), findsWidgets);
    await tester.tap(find.byTooltip(t.common.buttonRemove));
    await tester.pumpAndSettle();
    picker.result = Future.value([_File('replacement.bin')]);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    expect(find.textContaining('replacement.bin'), findsOneWidget);
  });

  testWidgets(
    'unknown picker length uses bounded stream without length fallback',
    (tester) async {
      final file = _File('unknown-length.bin', unknownLength: true);
      picker.result = Future.value([file]);
      await pump(tester);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      expect(file.reads, 1);
      expect(find.textContaining('unknown-length.bin'), findsOneWidget);
    },
  );

  test('extreme preview ratios remain nonzero and bounded on both sides', () {
    expect(webAttachmentPreviewSize(48, 1000000), (width: 1, height: 48));
    expect(webAttachmentPreviewSize(1000000, 48), (width: 48, height: 1));
    expect(webAttachmentPreviewSize(400, 200), (width: 48, height: 24));
    expect(() => webAttachmentPreviewSize(0, 3), throwsFormatException);
  });

  testWidgets('SVG stays an ordinary file without inline preview or network', (
    tester,
  ) async {
    final network = _NoNetwork();
    final oldAdapter = app_http.HttpClient.adapterForTest;
    app_http.HttpClient.adapterForTest = network;
    addTearDown(() => app_http.HttpClient.adapterForTest = oldAdapter);
    final bytes = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="2" height="1"><path d="M0 0h2v1H0z"/></svg>',
      ),
    );
    final file = _File('ordinary.svg', content: bytes);
    expect(resolveUploadMime(file.name, bytes), 'image/svg+xml');
    picker.result = Future.value([file]);
    await pump(tester);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    expect(file.reads, 1);
    expect(
      find.text('ordinary.svg · ${formatBytes(bytes.length)}'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const ValueKey('web-attachment-unpreviewable')),
      findsNothing,
    );
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, t.common.buttonSend),
          )
          .onPressed,
      isNotNull,
    );
    expect(network.calls, 0);
  });

  testWidgets('preview budget keeps valid metadata selectable for upload', (
    tester,
  ) async {
    final network = _NoNetwork();
    final oldAdapter = app_http.HttpClient.adapterForTest;
    app_http.HttpClient.adapterForTest = network;
    addTearDown(() => app_http.HttpClient.adapterForTest = oldAdapter);
    // Valid 8193x1 PNG header and IEND only: this path must not decode pixels.
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAIAEAAAABCAIAAAAW69wJAAAAAElFTkSuQmCC',
    );
    picker.result = Future.value([_File('large-preview.png', content: bytes)]);
    await pump(tester);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    expect(
      find.text('large-preview.png · ${formatBytes(bytes.length)}'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const ValueKey('web-attachment-unpreviewable')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, t.common.buttonSend),
          )
          .onPressed,
      isNotNull,
    );
    expect(AttachmentApi.validateUpload(bytes.length, 'image/png'), isNull);
    expect(network.calls, 0); // No backend success or upload is claimed.
    await tester.tap(find.byTooltip(t.common.buttonRemove));
    await tester.pump();
    expect(find.textContaining('large-preview.png'), findsNothing);
  });

  testWidgets('full-decoder pixel default is not an image upload limit', (
    tester,
  ) async {
    final network = _NoNetwork();
    final oldAdapter = app_http.HttpClient.adapterForTest;
    app_http.HttpClient.adapterForTest = network;
    addTearDown(() => app_http.HttpClient.adapterForTest = oldAdapter);
    // 20000x20000 metadata exceeds the library default; no pixels are decoded.
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAATiAAAE4gCAIAAABsEtFuAAAAAElFTkSuQmCC',
    );
    picker.result = Future.value([_File('huge-metadata.png', content: bytes)]);
    await pump(tester);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    expect(
      find.text('huge-metadata.png · ${formatBytes(bytes.length)}'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const ValueKey('web-attachment-unpreviewable')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, t.common.buttonSend),
          )
          .onPressed,
      isNotNull,
    );
    expect(AttachmentApi.validateUpload(bytes.length, 'image/png'), isNull);
    expect(network.calls, 0);
    await tester.tap(find.byTooltip(t.common.buttonRemove));
    await tester.pump();
    expect(find.textContaining('huge-metadata.png'), findsNothing);
  });

  testWidgets('preview and eviction share the bounded provider key', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4zwAE/wEHAAH/4iOeWQAAAABJRU5ErkJggg==',
    );
    picker.result = Future.value([_File('bounded.png', content: bytes)]);
    await pump(tester);
    await tester.runAsync(() => tester.tap(pick));
    await pumpUntilPreviewReady(tester);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, 2);
    expect(provider.height, 1);
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 2);
    final key = await provider.obtainKey(ImageConfiguration.empty);
    await tester.tap(find.byTooltip(t.common.buttonRemove));
    await tester.pump();
    expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
  });

  testWidgets(
    'bad PNG retains metadata and placeholder until remove and reselect',
    (tester) async {
      final network = _NoNetwork();
      final oldAdapter = app_http.HttpClient.adapterForTest;
      app_http.HttpClient.adapterForTest = network;
      addTearDown(() => app_http.HttpClient.adapterForTest = oldAdapter);
      final broken = Uint8List.fromList([137, 80, 78, 71]);
      picker.result = Future.value([_File('broken.png', content: broken)]);
      await pump(tester);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      expect(
        find.text('broken.png · ${formatBytes(broken.length)}'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('web-attachment-unpreviewable')),
        findsOneWidget,
      );
      expect(
        find.text(
          '${t.chat.groupFileImagePreview}: ${t.common.groupFileImageLoadFailed}',
        ),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      final send = find.widgetWithText(TextButton, t.common.buttonSend);
      expect(tester.widget<TextButton>(send).onPressed, isNull);
      await tester.tap(send, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(network.calls, 0);
      expect(find.text(t.customerService.attachUnknown), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('broken.png'), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.buttonRemove));
      await tester.pumpAndSettle();
      expect(find.textContaining('broken.png'), findsNothing);
      expect(
        find.byKey(const ValueKey('web-attachment-unpreviewable')),
        findsNothing,
      );
      picker.result = Future.value([
        _File(
          'reselected.png',
          content: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4zwAE/wEHAAH/4iOeWQAAAABJRU5ErkJggg==',
          ),
        ),
      ]);
      await tester.runAsync(() => tester.tap(pick));
      await pumpUntilPreviewReady(tester);
      expect(find.textContaining('reselected.png'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.widget<TextButton>(send).onPressed, isNotNull);
      expect(network.calls, 0);
    },
  );

  testWidgets('send button remains at least 44pt in compact desktop theme', (
    tester,
  ) async {
    picker.result = Future.value([_File('button.bin')]);
    await pump(tester);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    final button = find.widgetWithText(TextButton, t.common.buttonSend);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    final style = tester.widget<TextButton>(button).style!;
    expect(style.visualDensity, VisualDensity.standard);
  });
}
