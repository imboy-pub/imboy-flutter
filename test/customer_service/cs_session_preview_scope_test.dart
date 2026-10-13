import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:imboy/modules/customer_service/presentation/cs_attachment_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_preview_scope.dart';

CsVerifiedAssetContent content(String id, Uint8List bytes, String mime) =>
    CsVerifiedAssetContent.fromResponse(
      Response(
        requestOptions: RequestOptions(path: '/synthetic'),
        data: bytes,
        statusCode: 200,
        headers: Headers.fromMap({
          'x-asset-id': [id],
          'x-asset-sha256': [sha256.convert(bytes).toString()],
          'content-length': ['${bytes.length}'],
          'content-type': [mime],
        }),
      ),
      id,
    );

void main() {
  testWidgets('ordinary binary is never rendered as UTF8 plaintext', (
    tester,
  ) async {
    final previews = CsSessionPreviewScope();
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => TranslationProvider(child: child!),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    unawaited(
      previews.show(
        context: pageContext,
        asset: CsMessageAsset(
          id: '1',
          mime: 'application/pdf',
          fileName: 'sample.pdf',
        ),
        loadContent: () async => content(
          '1',
          Uint8List.fromList('binary-marker'.codeUnits),
          'application/pdf',
        ),
        isCurrent: () => true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('binary-marker'), findsNothing);
    expect(
      find.text(pageContext.t.customerService.attachBinaryNoPreview),
      findsOneWidget,
    );
    previews.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'invalidating preview removes only owned route, preserving external dialog',
    (tester) async {
      final previews = CsSessionPreviewScope();
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TranslationProvider(child: child!),
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      unawaited(
        previews.show(
          context: pageContext,
          asset: CsMessageAsset(
            id: '1',
            mime: 'text/plain',
            fileName: 'owned.txt',
          ),
          loadContent: () async => content(
            '1',
            Uint8List.fromList('owned plaintext'.codeUnits),
            'text/plain',
          ),
          isCurrent: () => true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('owned plaintext'), findsOneWidget);
      unawaited(
        showDialog<void>(
          context: pageContext,
          builder: (_) => const AlertDialog(content: Text('external dialog')),
        ),
      );
      await tester.pumpAndSettle();
      previews.invalidate();
      await tester.pumpAndSettle();
      expect(find.text('owned plaintext', skipOffstage: false), findsNothing);
      expect(find.text('external dialog'), findsOneWidget);
      previews.dispose();
    },
  );

  testWidgets('revoked scope never opens a preview after late bytes', (
    tester,
  ) async {
    final previews = CsSessionPreviewScope();
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => TranslationProvider(child: child!),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final bytes = Completer<CsVerifiedAssetContent?>();
    var allowed = true;
    final pending = previews.show(
      context: pageContext,
      asset: CsMessageAsset(id: '1'),
      loadContent: () => bytes.future,
      isCurrent: () => allowed,
    );
    allowed = false;
    previews.invalidate();
    bytes.complete(
      content(
        '1',
        Uint8List.fromList('late plaintext'.codeUnits),
        'text/plain',
      ),
    );
    await pending;
    await tester.pumpAndSettle();
    expect(find.text('late plaintext'), findsNothing);
    previews.dispose();
  });
  testWidgets(
    'large text preview is bounded while save keeps full verified bytes',
    (tester) async {
      final source = Uint8List.fromList(List.filled(40000, 65));
      Uint8List? saved;
      final previews = CsSessionPreviewScope(
        save: CsAttachmentSave(
          saveFile:
              ({required fileName, required bytes, required mimeType}) async {
                saved = bytes;
                return Uri.file('/synthetic/large.txt');
              },
        ),
      );
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TranslationProvider(child: child!),
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      unawaited(
        previews.show(
          context: pageContext,
          asset: CsMessageAsset(
            id: '1',
            mime: 'text/plain',
            fileName: 'large.txt',
          ),
          loadContent: () async => content('1', source, 'text/plain'),
          isCurrent: () => true,
        ),
      );
      await tester.pumpAndSettle();
      final strings = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '');
      expect(strings.every((s) => s.length <= 10000), isTrue);
      expect(
        find.text(pageContext.t.customerService.attachPreviewTruncated),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('cs-save-attachment')));
      await tester.pumpAndSettle();
      expect(saved, source);
      previews.dispose();
      await tester.pumpAndSettle();
    },
  );
}
