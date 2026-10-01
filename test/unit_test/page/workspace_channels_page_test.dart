import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel(uid: '1', account: 'synthetic');
  void select(String uid) => state = UserModel(uid: uid, account: 'synthetic');
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _Shell extends WorkspaceShellNotifier {
  @override
  WorkspaceShellState build() => const WorkspaceShellState(
    currentWorkspaceId: '100',
    workspaces: [WorkspaceModel(id: '100', name: 'Synthetic', ownerId: '1')],
  );
  void selectSpace() => state = const WorkspaceShellState(
    currentWorkspaceId: '200',
    workspaces: [WorkspaceModel(id: '200', name: 'Other', ownerId: '1')],
  );
}

class _Api extends WorkspaceApi {
  int calls = 0;
  bool fail = false;
  Completer<List<ChannelModel>>? pending;
  List<ChannelModel> rows = [
    _channel(1, '公告', 'announcements'),
    _channel(2, '项目动态', 'updates'),
  ];
  @override
  Future<List<ChannelModel>> channels(
    EntityId workspaceId, {
    String? status,
  }) async {
    calls++;
    if (fail) throw const WorkspaceApiException(403, 'denied');
    if (pending != null) return pending!.future;
    return workspaceId == '100' ? rows : [_channel(4, '另一空间', 'other')];
  }
}

ChannelModel _channel(int id, String name, String customId) =>
    ChannelModel.fromJson({
      'id': id,
      'name': name,
      'custom_id': customId,
      'visibility': 1,
      'access_type': 0,
      'join_policy': 1,
    });

Future<_Api> _mount(WidgetTester tester) async {
  final api = _Api();
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => ref.watch(_account)),
          workspaceShellProvider.overrideWith(_Shell.new),
          workspaceApiProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(home: Scaffold(body: WorkspaceChannelsPage())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('按名称、ID及自定义ID搜索，清空恢复列表，空结果可刷新', (tester) async {
    final api = await _mount(tester);
    final field = find.byKey(const ValueKey('workspace-channel-search'));
    await tester.enterText(field, ' 项目 ');
    await tester.pump();
    expect(find.text('公告'), findsNothing);
    expect(find.text('项目动态'), findsOneWidget);
    await tester.enterText(field, '1');
    await tester.pump();
    expect(find.text('公告'), findsOneWidget);
    await tester.enterText(field, 'UPDATES');
    await tester.pump();
    expect(find.text('项目动态'), findsOneWidget);
    await tester.enterText(field, 'missing');
    await tester.pump();
    expect(find.text(t.channel.noResults), findsOneWidget);
    await tester.enterText(field, '');
    await tester.pump();
    expect(find.text('公告'), findsOneWidget);
    api.rows = [_channel(3, '新公告', 'new')];
    await tester.tap(find.byKey(const ValueKey('workspace-channel-refresh')));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('新公告'), findsOneWidget);
    expect(find.text('公告'), findsNothing);
  });
  testWidgets('刷新失败显示错误与重试，不能静默显示旧列表', (tester) async {
    final api = await _mount(tester);
    api.fail = true;
    await tester.tap(find.byKey(const ValueKey('workspace-channel-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('denied'), findsOneWidget);
    expect(find.text('公告'), findsNothing);
    api.fail = false;
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    expect(find.text('公告'), findsOneWidget);
    expect(api.calls, 3);
  });
  testWidgets('同一工作区换账号清空旧搜索，重新获取列表', (tester) async {
    final api = await _mount(tester);
    final field = find.byKey(const ValueKey('workspace-channel-search'));
    await tester.enterText(field, 'missing');
    await tester.pump();
    expect(find.text(t.channel.noResults), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceChannelsPage)),
    );
    container.read(_account.notifier).select('2');
    await tester.pumpAndSettle();
    expect(find.text('公告'), findsOneWidget);
    expect(find.text(t.channel.noResults), findsNothing);
    expect(api.calls, 2);
  });
  testWidgets('切换工作区清空搜索并撤下旧频道', (tester) async {
    await _mount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('workspace-channel-search')),
      'missing',
    );
    await tester.pump();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceChannelsPage)),
    );
    (c.read(workspaceShellProvider.notifier) as _Shell).selectSpace();
    await tester.pumpAndSettle();
    expect(find.text('另一空间'), findsOneWidget);
    expect(find.text('公告'), findsNothing);
    expect(find.text(t.channel.noResults), findsNothing);
  });
  testWidgets('刷新显示忙碌反馈并保留搜索条件', (tester) async {
    final api = await _mount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('workspace-channel-search')),
      '公告',
    );
    await tester.pump();
    api.pending = Completer<List<ChannelModel>>();
    await tester.tap(find.byKey(const ValueKey('workspace-channel-refresh')));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('workspace-channel-refresh')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    api.pending!.complete([
      _channel(3, '新公告', 'new'),
      _channel(4, '其他', 'other'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('新公告'), findsOneWidget);
    expect(find.text('其他'), findsNothing);
  });
  testWidgets('空频道目录仍可手动刷新恢复', (tester) async {
    final api = await _mount(tester);
    api.rows = [];
    await tester.tap(find.byKey(const ValueKey('workspace-channel-refresh')));
    await tester.pumpAndSettle();
    expect(find.text(t.workspace.channelsEmptyTitle), findsOneWidget);
    api.rows = [_channel(3, '新公告', 'new')];
    await tester.tap(find.byKey(const ValueKey('workspace-channel-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('新公告'), findsOneWidget);
  });
}
