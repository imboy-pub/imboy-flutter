import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_list_previews.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _List extends ChannelListNotifier {
  _List(this.channels);
  final List<ChannelModel> channels;
  @override
  ChannelListState build() => ChannelListState(channels: channels);
}

class _Cache extends Fake implements ChannelService {
  List<String> requested = [];
  @override
  Future<Map<int, ChannelMessageModel>> getCachedPreviews(
    List<String> ids,
  ) async {
    requested = ids;
    return {};
  }
}

ChannelModel channel(
  int id, {
  bool purchased = false,
  bool paid = false,
  bool subscribed = true,
}) => ChannelModel(
  id: id,
  name: 'synthetic',
  creatorId: 1,
  visibility: 0,
  accessType: paid ? 1 : 0,
  joinPolicy: paid ? 3 : 0,
  isSubscribed: subscribed,
  hasPurchased: purchased,
  userRole: subscribed ? ChannelUserRole.subscriber : ChannelUserRole.none,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
void main() {
  test(
    'cached previews never query paid-locked or unsubscribed content',
    () async {
      final cache = _Cache();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          channelServiceProvider.overrideWithValue(cache),
          channelListProvider.overrideWith(
            () => _List([
              channel(1),
              channel(2, paid: true),
              channel(3, paid: true, purchased: true),
              channel(4, subscribed: false),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        channelListPreviewsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(channelListPreviewsProvider.future);
      expect(cache.requested, ['1', '3']);
    },
  );
}
