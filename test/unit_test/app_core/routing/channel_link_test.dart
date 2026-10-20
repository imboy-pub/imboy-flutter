import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/routing/channel_link.dart';

void main() {
  const base = 'https://imboy.pub';
  test('channel and article references round trip without credentials', () {
    for (final message in <String?>[null, '923456789012345678']) {
      final link = channelLink('123', messageId: message, baseUrl: base);
      expect(
        channelLinkLocation(link, baseUrl: base),
        message == null ? '/channel/123' : '/channel/123/article/$message',
      );
    }
  });
  test('reject configured origins with credentials or hidden query', () {
    for (final base in [
      'http://imboy.pub',
      'https://user@imboy.pub',
      'https://imboy.pub?token=x',
      'https://imboy.pub/subpath',
    ]) {
      expect(() => channelLink('1', baseUrl: base), throwsStateError);
    }
  });
  test('reject foreign origins, malformed IDs and lookalike paths', () {
    for (final value in [
      'https://evil.test/channel/1',
      'https://imboy.pub.evil.test/channel/1',
      'https://imboy.pub:444/channel/1',
      'http://imboy.pub/channel/1',
      'https://user@imboy.pub/channel/1',
      'https://imboy.pub/channel/0',
      'https://imboy.pub/channel/1/edit',
      'https://imboy.pub/channel/1#x',
      'imboy://evil.test/channel/1',
      'https://imboy.pub/channel/9223372036854775808',
      'https://imboy.pub/channel/1?redirect=/settings',
      'imboy://imboy.pub:443/channel/1',
    ]) {
      expect(channelLinkLocation(value, baseUrl: base), isNull, reason: value);
    }
    expect(
      channelLinkLocation('imboy://imboy.pub/channel/1', baseUrl: base),
      '/channel/1',
    );
  });
}
