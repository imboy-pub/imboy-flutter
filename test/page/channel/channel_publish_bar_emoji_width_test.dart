import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_publish_bar.dart';
import 'package:imboy/store/model/channel_model.dart';

class _Fake extends ChannelDetailNotifier {
  @override
  ChannelDetailState build() {
    super.build();
    return ChannelDetailState(
      channel: ChannelModel(
        id: 1001,
        name: 'c',
        userRole: ChannelUserRole.creator,
        isSubscribed: true,
        creatorId: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
      messages: const [],
      isLoading: false,
      hasMore: false,
    );
  }

  @override
  Future<void> loadChannel(String id) async {}
}

void main() {
  testWidgets('表情面板铺满屏宽，不被输入框那一列夹住 / emoji panel spans full width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final fn = FocusNode();
    addTearDown(fn.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelDetailProvider.overrideWith(_Fake.new)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: SizedBox()),
                  ChannelPublishBar(focusNode: fn),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('composer_emoji_button')));
    await tester.pumpAndSettle();
    final panel = tester.getSize(find.byType(EmojiPicker)).width;
    final screen = tester.getSize(find.byType(MaterialApp)).width;
    // 回归护栏：面板曾画在 ComposerField 内部，被左侧 3 个图标列 + 右侧发送位
    // 夹到 256/390pt（真机 iOS 反馈「宽度不够」）。必须等于整屏宽。
    expect(panel, screen);
  });
}
