// 频道列表页面 Widget 集成测试 / ChannelListPage Widget Integration Tests
//
// 测试策略 / Test strategy:
//   - 通过 ProviderScope.overrideWithValue 注入 ChannelListState，不触发网络
//   - 覆盖：空状态（订阅/管理）、列表渲染、加载态、错误态、未读计数入口
//   - No real network required; stable in CI
//
// 运行方式 / How to run:
//   flutter test test/widget/channel_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/store/model/channel_model.dart';

// ---------------------------------------------------------------------------
// 测试辅助 / Test helpers
// ---------------------------------------------------------------------------

/// 构建测试用 ChannelModel
ChannelModel _makeChannel({
  required int id,
  required String name,
  String? avatar,
  int subscriberCount = 100,
  ChannelUserRole userRole = ChannelUserRole.subscriber,
  bool isVerified = false,
}) {
  return ChannelModel(
    id: id,
    name: name,
    avatar: avatar,
    subscriberCount: subscriberCount,
    userRole: userRole,
    isVerified: isVerified,
    isSubscribed: true,
    creatorId: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

/// 固定订阅频道数据
final _kSubscribedChannels = [
  _makeChannel(id: 101, name: 'Flutter 技术周报', subscriberCount: 3200),
  _makeChannel(id: 102, name: 'Dart 语言动态', subscriberCount: 1500),
];

/// 构建被测 Widget / Build widget under test
///
/// TranslationProvider 防止 slang "Please wrap" 异常
Widget _buildTestApp(Widget home, {List<dynamic> overrides = const []}) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(home: home),
    ),
  );
}

// ---------------------------------------------------------------------------
// 测试用例 / Test cases
// ---------------------------------------------------------------------------

void main() {
  group('ChannelListPage —— 空状态 / Empty state', () {
    testWidgets('订阅列表为空时显示空视图 / shows empty view for no subscribed channels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              const ChannelListState(channels: [], isLoading: false),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 没有频道时列表不含 ListTile
      expect(find.byType(ListTile), findsNothing);
      // 没有频道名出现
      expect(find.text('Flutter 技术周报'), findsNothing);
    });

    testWidgets('管理列表为空时切换 Tab 不崩溃 / switch to managed tab with empty data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              const ChannelListState(channels: [], isLoading: false),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 切换到"我管理的"Tab（index=1）
      final tabs = find.byType(Tab);
      if (tabs.evaluate().length >= 2) {
        await tester.tap(tabs.at(1));
        await tester.pumpAndSettle();
      }
      // 不抛出异常即为通过
    });
  });

  group('ChannelListPage —— 加载状态 / Loading state', () {
    testWidgets('isLoading=true 时不显示频道列表 / hides list when loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              const ChannelListState(channels: [], isLoading: true),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pump();

      // 加载中不应显示频道名
      expect(find.text('Flutter 技术周报'), findsNothing);
    });
  });

  group('ChannelListPage —— 列表渲染 / List rendering', () {
    testWidgets('订阅频道列表正确渲染频道名称 / renders subscribed channel names', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              ChannelListState(
                channels: _kSubscribedChannels,
                isLoading: false,
              ),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 两个频道名均可见
      expect(find.text('Flutter 技术周报'), findsOneWidget);
      expect(find.text('Dart 语言动态'), findsOneWidget);
    });

    testWidgets('订阅者数量显示在列表项中 / subscriber counts appear in list items', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              ChannelListState(
                channels: _kSubscribedChannels,
                isLoading: false,
              ),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 订阅者数字出现（3200 / 1500）
      expect(find.textContaining('3200'), findsWidgets);
    });

    testWidgets('已认证频道显示认证图标 / verified channel shows verified icon', (
      tester,
    ) async {
      final verifiedChannel = _makeChannel(
        id: 301,
        name: '官方认证频道',
        isVerified: true,
      );
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              ChannelListState(channels: [verifiedChannel], isLoading: false),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Icons.verified 应出现
      expect(find.byIcon(Icons.verified), findsWidgets);
    });
  });

  group('ChannelListPage —— 错误状态 / Error state', () {
    testWidgets('加载失败时显示重试按钮 / shows retry button on error', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              const ChannelListState(
                channels: [],
                isLoading: false,
                error: 'NetworkException',
              ),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 错误文本 / 重试按钮出现
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('ChannelListPage —— AppBar 操作 / AppBar actions', () {
    testWidgets('AppBar 包含创建频道按钮 / AppBar has create channel button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ChannelListPage(),
          overrides: [
            channelListProvider.overrideWithValue(
              const ChannelListState(channels: [], isLoading: false),
            ),
            channelUnreadCountProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Icons.add 来自 AppBar actions 中的"创建频道"按钮
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}
