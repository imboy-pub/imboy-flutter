import 'dart:async';
import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/image_gallery/photo_view_loading.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_view/photo_view.dart';

class _ChunkedImageStream extends OneFrameImageStreamCompleter {
  _ChunkedImageStream(super.image);

  void progress(int loaded, int expected) => reportImageChunkEvent(
    ImageChunkEvent(
      cumulativeBytesLoaded: loaded,
      expectedTotalBytes: expected,
    ),
  );
}

class _DelayedImage extends ImageProvider<_DelayedImage> {
  final _loading = Completer<ImageInfo>();
  late final _stream = _ChunkedImageStream(_loading.future);

  @override
  Future<_DelayedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _DelayedImage key,
    ImageDecoderCallback decode,
  ) => _stream;

  void progress(int loaded, int expected) => _stream.progress(loaded, expected);

  void complete() {
    if (_loading.isCompleted) return;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF218754), ui.BlendMode.src);
    final picture = recorder.endRecording();
    try {
      _loading.complete(ImageInfo(image: picture.toImageSync(2, 2)));
    } finally {
      picture.dispose();
    }
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('PhotoView loading follows the new UI theme: $brightness', (
      tester,
    ) async {
      final image = _DelayedImage();
      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: PhotoView(
                  imageProvider: image,
                  loadingBuilder: buildPhotoViewLoading,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(PhotoView), findsOneWidget);
        final indicator = find.byType(CircularProgressIndicator);
        expect(indicator, findsOneWidget);
        final context = tester.element(indicator);
        expect(Theme.of(context).brightness, brightness);
        expect(CupertinoTheme.brightnessOf(context), brightness);
        expect(
          tester.widget<CircularProgressIndicator>(indicator).value,
          isNull,
        );
        expect(tester.getSize(indicator), const Size(20, 20));
        expect(find.byType(RawImage), findsNothing);
        expect(tester.takeException(), isNull);

        for (final loaded in [25, 75]) {
          image.progress(loaded, 100);
          await tester.pump();
          expect(
            tester.widget<CircularProgressIndicator>(indicator).value,
            loaded / 100,
          );
          expect(tester.getSize(indicator), const Size(20, 20));
        }

        image.complete();
        await tester.pumpAndSettle();

        expect(indicator, findsNothing);
        final rendered = find.descendant(
          of: find.byType(PhotoView),
          matching: find.byType(RawImage),
        );
        expect(rendered, findsOneWidget);
        expect(tester.widget<RawImage>(rendered).image?.width, 2);
        expect(tester.widget<RawImage>(rendered).image?.height, 2);
        expect(tester.takeException(), isNull);
      } finally {
        image.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await image.evict();
      }
    });
  }
}
