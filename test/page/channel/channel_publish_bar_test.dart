import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_publish_bar.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class _FakeChannelDetailNotifier extends ChannelDetailNotifier {
  final ChannelModel channel;

  _FakeChannelDetailNotifier(this.channel);

  @override
  ChannelDetailState build() {
    super.build();
    return ChannelDetailState(
      channel: channel,
      messages: const [],
      isLoading: false,
      hasMore: false,
    );
  }

  @override
  Future<void> loadChannel(String channelId) async {}
}

ChannelModel _channel() => ChannelModel(
  id: 1001,
  name: '测试频道',
  description: '频道简介',
  userRole: ChannelUserRole.creator,
  isSubscribed: true,
  creatorId: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Widget _app(
  ChannelModel channel,
  FocusNode focusNode, {
  required double bottomPadding,
  required double viewInsetsBottom,
}) => TranslationProvider(
  child: ProviderScope(
    overrides: [
      channelDetailProvider.overrideWith(
        () => _FakeChannelDetailNotifier(channel),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        bottomNavigationBar: MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: bottomPadding),
            viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
          ),
          child: ChannelPublishBar(focusNode: focusNode),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'ChannelPublishBar bottom padding behavior with and without keyboard',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      // 1. 无键盘状态，模拟 iOS 底部 Safe Area 34
      await tester.pumpWidget(
        _app(_channel(), focusNode, bottomPadding: 34, viewInsetsBottom: 0),
      );
      await tester.pumpAndSettle();

      final barFinder = find.byType(ChannelPublishBar);
      expect(barFinder, findsOneWidget);

      // 获取 Row 的底部位置和屏幕底部位置
      final rowFinder = find
          .descendant(of: barFinder, matching: find.byType(Row))
          .first;

      final rowBottom = tester.getBottomLeft(rowFinder).dy;
      final screenHeight = tester.getBottomLeft(find.byType(MaterialApp)).dy;

      // 此时 Row 的底部到屏幕底部的距离应为 Safe Area (34) + AppSpacing.small (12)
      expect(screenHeight - rowBottom, 34 + AppSpacing.small);

      // 2. 键盘弹出状态，模拟 keyboardHeight = 300
      await tester.pumpWidget(
        _app(_channel(), focusNode, bottomPadding: 0, viewInsetsBottom: 300),
      );
      await tester.pumpAndSettle();

      final newRowBottom = tester.getBottomLeft(rowFinder).dy;
      final newScreenHeight = tester.getBottomLeft(find.byType(MaterialApp)).dy;

      // 此时 Row 的底部到屏幕底部的距离应只有 AppSpacing.small (12)
      expect(newScreenHeight - newRowBottom, AppSpacing.small);
    },
  );
}
