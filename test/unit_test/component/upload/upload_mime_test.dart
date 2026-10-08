import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/upload/upload_mime.dart';

void main() {
  const png = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  const jpeg = <int>[0xff, 0xd8, 0xff, 0xe0];

  test('native PNG gallery export with jpg extension retains PNG MIME', () {
    expect(resolveUploadMime('gallery-export.jpg', png), 'image/png');
  });
  test('JPEG signature overrides an incorrect PNG extension', () {
    expect(resolveUploadMime('capture.png', jpeg), 'image/jpeg');
  });
  test('recognized image without an extension is not octet-stream', () {
    expect(resolveUploadMime('gallery-export', png), 'image/png');
  });
  test('text without a recognized signature retains extension fallback', () {
    expect(resolveUploadMime('notes.txt', <int>[65, 66]), 'text/plain');
  });
  test('unknown bytes and extension retain binary fallback', () {
    expect(
      resolveUploadMime('payload.unknown', <int>[0, 1]),
      'application/octet-stream',
    );
  });
}
