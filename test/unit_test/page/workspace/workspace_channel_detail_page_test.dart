/// WP5 (T9) — Workspace Channel 详情视图结构契约测试（I6 + W06/F12）
///
/// 计划锚点：Workspace 的 Channel 视图**不提供聊天式输入框**（无
/// ChatInput / 聊天 Composer），只有发帖/评论入口。
///
/// W06/F12 收敛（J12）：「去 General 群聊聊」常驻引导横幅与进个人会话
/// 列表的「私聊/全部消息」按钮已移除——讨论的唯一合法目的地是内容区内
/// 的真实绑定讨论入口（ChannelDiscussionEntry，经 embedded
/// ChannelDetailPage 提供）；不造 General、不自动加入。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/page/workspace/widget/workspace_access_guard.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';

class _ChannelApi extends ChannelApi {
  @override
  Future<ChannelModel> getChannelChecked(String channelId) async {
    expect(channelId, '9002');
    return ChannelModel(
      id: 9002,
      scope: 'workspace',
      workspaceId: '100',
      name: 'Workspace channel',
      creatorId: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      visibility: 1,
      accessType: 0,
      joinPolicy: 1,
    );
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/channel/9002/messages');
    expect(queryParameters, {'limit': 1});
    return IMBoyHttpResponse.success({'list': <Map<String, dynamic>>[]});
  }
}

void main() {
  Future<void> pumpPage(WidgetTester tester, {Widget? detailEntry}) async {
    // WorkspaceChannelDetailPage 为 ConsumerWidget（外层顶栏 watch 频道
    // provider），必须置于 ProviderScope 内。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelApiProvider.overrideWithValue(_ChannelApi()),
          workspaceAccessNetworkProvider.overrideWith(
            (ref) => Stream.value(true),
          ),
          workspaceAccessContextReaderProvider.overrideWithValue(
            () => (
              origin: 'https://workspace.invalid',
              uid: '1',
              session: 1,
              featureScope: 'workspace:1',
              featureEpoch: 1,
              featureRevision: 1,
              channelEnabled: true,
            ),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            home: WorkspaceChannelDetailPage(
              channelId: '9002',
              workspaceId: '100',
              detailEntry: detailEntry ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-access-shield')), findsNothing);
  }

  testWidgets('频道详情视图无聊天式输入框（I6：不出现 ChatInput）', (tester) async {
    await pumpPage(tester);
    expect(find.byType(ChatInput), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('W06/J12：常驻讨论引导横幅已移除，页面无 General 文案', (tester) async {
    await pumpPage(tester);
    expect(
      find.byKey(const ValueKey('workspace-channel-discuss-guide')),
      findsNothing,
      reason: '跳群列表的常驻引导与真实绑定讨论入口并存属 F12 反模式',
    );
    expect(find.textContaining('General'), findsNothing);
  });

  testWidgets('W06/F12：无「全部消息/私聊」按钮（个人会话列表不是频道讨论目的地）', (tester) async {
    await pumpPage(tester);
    expect(
      find.byKey(const ValueKey('workspace-channel-detail-dm-entry')),
      findsNothing,
    );
  });

  testWidgets('内容区默认复用现有频道内容页（发帖/评论模型，非聊天页）', (tester) async {
    final entry = defaultWorkspaceChannelDetailEntry('9002');
    expect(entry, isA<ChannelDetailPage>());
    expect((entry as ChannelDetailPage).channelId, '9002');
  });

  testWidgets('注入内容区直接成为页面主体（无横幅占位）', (tester) async {
    await pumpPage(
      tester,
      detailEntry: const SizedBox(key: ValueKey('detail-entry-probe')),
    );
    expect(find.byKey(const ValueKey('detail-entry-probe')), findsOneWidget);
    // body 即内容区本身（W06 收敛后无 Column+横幅结构）。
    final bodyDy = tester
        .getTopLeft(find.byKey(const ValueKey('detail-entry-probe')))
        .dy;
    final appBarBottom = tester.getBottomRight(find.byType(AppBar)).dy;
    expect(bodyDy, greaterThanOrEqualTo(appBarBottom));
  });
}
