import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 15: `_MomentMediaCell` passes the raw video MP4 URL to
/// `OctoImage` as a fallback "cover" when the `VideoPlayerController` hasn't
/// initialized yet. OctoImage can't decode MP4 → silent broken image. The
/// publish page already uploads `cover_url` on video media items; this helper
/// picks the right URL per media kind.
void main() {
  group('pickMediaPreviewUrl', () {
    test('image: returns url', () {
      final media = {'type': 'image', 'url': 'https://cdn/pic.jpg'};
      expect(pickMediaPreviewUrl(media), 'https://cdn/pic.jpg');
    });

    test('video with cover_url: returns cover_url (preferred)', () {
      final media = {
        'type': 'video',
        'url': 'https://cdn/clip.mp4',
        'cover_url': 'https://cdn/clip-cover.jpg',
      };
      expect(pickMediaPreviewUrl(media), 'https://cdn/clip-cover.jpg');
    });

    test('video without cover_url: falls back to url (defensive)', () {
      // Historical moments or third-party payloads might not carry cover_url.
      // Fallback is better than a blank cell.
      final media = {'type': 'video', 'url': 'https://cdn/clip.mp4'};
      expect(pickMediaPreviewUrl(media), 'https://cdn/clip.mp4');
    });

    test('video with empty cover_url: falls back to url', () {
      final media = {
        'type': 'video',
        'url': 'https://cdn/clip.mp4',
        'cover_url': '',
      };
      expect(pickMediaPreviewUrl(media), 'https://cdn/clip.mp4');
    });

    test('video with whitespace cover_url: falls back to url', () {
      final media = {
        'type': 'video',
        'url': 'https://cdn/clip.mp4',
        'cover_url': '   ',
      };
      expect(pickMediaPreviewUrl(media), 'https://cdn/clip.mp4');
    });

    test('unknown type: returns url', () {
      final media = {'type': 'other', 'url': 'https://cdn/x'};
      expect(pickMediaPreviewUrl(media), 'https://cdn/x');
    });

    test('missing type: returns url as-is', () {
      final media = {'url': 'https://cdn/x'};
      expect(pickMediaPreviewUrl(media), 'https://cdn/x');
    });

    test('empty map: returns empty string', () {
      expect(pickMediaPreviewUrl(const {}), '');
    });
  });
}
