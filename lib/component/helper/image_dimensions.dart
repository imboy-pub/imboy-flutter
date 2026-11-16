import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Read pinned image-library metadata without decoding a pixel frame.
/// Unsupported formats remain downloadable files, not unsafe preview fallbacks.
({int width, int height}) readImageDimensions(Uint8List bytes) {
  if (bytes.length < 8) {
    throw const FormatException('Invalid image metadata');
  }
  for (final decoder in <img.Decoder>[
    img.JpegDecoder(),
    img.PngDecoder(maxPixels: 0),
    img.GifDecoder()..maxPixels = 0,
    img.WebPDecoder()..maxPixels = 0,
    img.BmpDecoder(),
  ]) {
    if (!decoder.isValidFile(bytes)) {
      continue;
    }
    if (decoder is img.BmpDecoder) {
      _requireBmpPaletteAdmission(bytes);
    }
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw const FormatException('Invalid image metadata');
    }
    final orientation = decoder is img.JpegDecoder
        ? img.decodeJpgExif(bytes)?.imageIfd.orientation ?? 1
        : 1;
    return {5, 6, 7, 8}.contains(orientation)
        ? (width: info.height, height: info.width)
        : (width: info.width, height: info.height);
  }
  throw const FormatException('Unsupported image metadata');
}

/// Preview memory budget; the authorized original remains downloadable.
bool isWebImagePreviewSizeAllowed(int width, int height) =>
    width > 0 &&
    height > 0 &&
    width <= 8192 &&
    height <= 8192 &&
    width * height <= 16 * 1024 * 1024;

/// Bound the pinned BMP decoder's palette allocation before it is called.
bool isBmpPaletteAdmissionAllowed({
  required int bitsPerPixel,
  required int totalColors,
  required int paletteBytesAvailable,
}) {
  if (!{1, 2, 4, 8, 16, 24, 32}.contains(bitsPerPixel) ||
      totalColors < 0 ||
      paletteBytesAvailable < 0) {
    return false;
  }
  if (bitsPerPixel > 8) {
    return true;
  }
  final capacity = 1 << bitsPerPixel;
  final count = totalColors == 0 ? capacity : totalColors;
  return count <= capacity && count <= paletteBytesAvailable ~/ 4;
}

void _requireBmpPaletteAdmission(Uint8List bytes) {
  if (bytes.length < 54) {
    throw const FormatException('Truncated BMP metadata');
  }
  final header = ByteData.sublistView(bytes);
  final dibSize = header.getUint32(14, Endian.little);
  final paletteStart = 14 + dibSize;
  final pixelsAt = header.getUint32(10, Endian.little);
  final paletteEnd = pixelsAt < bytes.length ? pixelsAt : bytes.length;
  if (dibSize < 40 ||
      dibSize > 124 ||
      paletteStart > bytes.length ||
      !isBmpPaletteAdmissionAllowed(
        bitsPerPixel: header.getUint16(28, Endian.little),
        totalColors: header.getUint32(46, Endian.little),
        paletteBytesAvailable: paletteEnd - paletteStart,
      )) {
    throw const FormatException('Invalid BMP palette declaration');
  }
}
