import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  group('ChannelMessageType.imageText', () {
    test('constant carries channel_ prefix', () {
      expect(ChannelMessageType.imageText, 'channel_imageText');
    });

    test('is registered in allTypes and passes isValid', () {
      expect(
        ChannelMessageType.allTypes,
        contains(ChannelMessageType.imageText),
      );
      expect(ChannelMessageType.isValid(ChannelMessageType.imageText), isTrue);
    });

    test('fromMessageType normalizes unprefixed imageText', () {
      expect(
        ChannelMessageType.fromMessageType('imageText'),
        ChannelMessageType.imageText,
      );
    });

    test('fromMessageType is idempotent on already-prefixed value', () {
      expect(
        ChannelMessageType.fromMessageType(ChannelMessageType.imageText),
        ChannelMessageType.imageText,
      );
    });

    test('toMessageType strips the channel_ prefix', () {
      expect(
        ChannelMessageType.toMessageType(ChannelMessageType.imageText),
        'imageText',
      );
    });
  });
}
