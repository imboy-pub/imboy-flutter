import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_preview_scope.dart';

void main() {
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
          asset: CsMessageAsset(id: '1', fileName: 'owned.txt'),
          loadBytes: () async =>
              Uint8List.fromList('owned plaintext'.codeUnits),
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
    final bytes = Completer<Uint8List?>();
    var allowed = true;
    final pending = previews.show(
      context: pageContext,
      asset: CsMessageAsset(id: '1'),
      loadBytes: () => bytes.future,
      isCurrent: () => allowed,
    );
    allowed = false;
    previews.invalidate();
    bytes.complete(Uint8List.fromList('late plaintext'.codeUnits));
    await pending;
    await tester.pumpAndSettle();
    expect(find.text('late plaintext'), findsNothing);
    previews.dispose();
  });
}
