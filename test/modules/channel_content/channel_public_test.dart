import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/channel_content/public.dart';

void main() {
  test('channel_content public entry exposes current route surfaces', () {
    expect(ChannelService.to, isA<ChannelService>());
    expect(ChannelListPage.new, isA<Function>());
    expect(ChannelDetailPage.new, isA<Function>());
    expect(ChannelDiscoverPage.new, isA<Function>());
    expect(ChannelInvitationPage.new, isA<Function>());
    expect(ChannelCreatePage.new, isA<Function>());
    expect(ChannelEditPage.new, isA<Function>());
    expect(ChannelAdminPage.new, isA<Function>());
    expect(ChannelSubscriberPage.new, isA<Function>());
  });
}
