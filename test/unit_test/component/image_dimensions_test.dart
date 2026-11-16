import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:imboy/component/helper/image_dimensions.dart';

void main() {
  test(
    'metadata reads fixed valid PNG without a Flutter engine descriptor',
    () {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4zwAE/wEHAAH/4iOeWQAAAABJRU5ErkJggg==',
      );
      expect(readImageDimensions(bytes), (width: 2, height: 1));
    },
  );

  test('installed common format metadata preserves known dimensions', () {
    final image = img.Image(width: 2, height: 1);
    for (final bytes in [
      img.encodeJpg(image),
      img.encodePng(image),
      img.encodeGif(image),
      img.encodeWebP(image),
      img.encodeBmp(image),
    ]) {
      expect(readImageDimensions(bytes), (width: 2, height: 1));
    }
  });

  test('JPEG orientation swaps the dimensions used for preview', () {
    final image = img.Image(width: 2, height: 1);
    image.exif.imageIfd.orientation = 6;
    expect(readImageDimensions(img.encodeJpg(image)), (width: 1, height: 2));
  });

  test('valid extreme-ratio metadata is refused before pixel preview', () {
    final bytes = img.encodePng(img.Image(width: 8193, height: 1));
    final size = readImageDimensions(bytes);
    expect(size, (width: 8193, height: 1));
    expect(isWebImagePreviewSizeAllowed(size.width, size.height), isFalse);
    expect(isWebImagePreviewSizeAllowed(4096, 4096), isTrue);
    expect(isWebImagePreviewSizeAllowed(4097, 4096), isFalse);
  });

  test('unrecognized and truncated metadata cannot start an image preview', () {
    expect(
      () => readImageDimensions(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => readImageDimensions(Uint8List.fromList([137, 80, 78, 71])),
      throwsFormatException,
    );
  });
  test('metadata above full-decode default retains positive dimensions', () {
    final defaultLimit = img.Decoder.defaultMaxPixels;
    // Header-only fixture; no image pixels or full-frame decoder is constructed.
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAATiAAAE4gCAIAAABsEtFuAAAAAElFTkSuQmCC',
    );
    final size = readImageDimensions(bytes);
    expect(size, (width: 20000, height: 20000));
    expect(size.width * size.height, greaterThan(defaultLimit));
    expect(isWebImagePreviewSizeAllowed(size.width, size.height), isFalse);
    expect(img.Decoder.defaultMaxPixels, defaultLimit);
  });

  test('BMP palette admission rejects unsafe counts and truncated tables', () {
    expect(
      isBmpPaletteAdmissionAllowed(
        bitsPerPixel: 8,
        totalColors: 0,
        paletteBytesAvailable: 1024,
      ),
      isTrue,
    );
    expect(
      isBmpPaletteAdmissionAllowed(
        bitsPerPixel: 8,
        totalColors: 256,
        paletteBytesAvailable: 1024,
      ),
      isTrue,
    );
    expect(
      isBmpPaletteAdmissionAllowed(
        bitsPerPixel: 8,
        totalColors: 257,
        paletteBytesAvailable: 1028,
      ),
      isFalse,
    );
    expect(
      isBmpPaletteAdmissionAllowed(
        bitsPerPixel: 4,
        totalColors: 16,
        paletteBytesAvailable: 63,
      ),
      isFalse,
    );
    expect(
      isBmpPaletteAdmissionAllowed(
        bitsPerPixel: 24,
        totalColors: 0,
        paletteBytesAvailable: 0,
      ),
      isTrue,
    );
  });

  test('benign indexed BMP still passes the shared metadata path', () {
    final image = img.Image(
      width: 2,
      height: 1,
      numChannels: 3,
      withPalette: true,
    );
    expect(readImageDimensions(img.encodeBmp(image)), (width: 2, height: 1));
  });
}
