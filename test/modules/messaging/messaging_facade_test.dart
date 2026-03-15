import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/public.dart';

void main() {
  test('messaging public entry exposes facade shell', () {
    expect(MessagingFacade.instance, isA<MessagingFacade>());
    expect(MessageServiceAdapter.instance, isA<MessageServiceAdapter>());
    expect(ChatEntry.new, isA<Function>());
  });
}
