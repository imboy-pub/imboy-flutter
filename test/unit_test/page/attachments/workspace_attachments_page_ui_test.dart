/// 企业附件页 UI 契约（视觉/状态分层回归钉）。
///
/// 覆盖（生产嵌入形态：入口外壳 Scaffold +「附件」标题栏）：
/// - ready 态：结果计数（keyset 终点才展示）、类型化图标（pdf/photo）、
///   人性化大小（100 B / 2 MB）、跨年日期带年份、单 AppBar（双层标题
///   回归钉）；
/// - 空态：图标 + 主文案 + 行动建议（emptyHint），不出计数行；
/// - 首屏失败：居中错误态（ws-attachments-error）+ 可重试文案；
/// - 筛选控件族：下拉 hint 形态（全部群组/全部频道）+ 人名搜索占位；
///   选中群组后出现「清除筛选」，点击后回收。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/workspace_attachments_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Shell extends WorkspaceShellNotifier {
  @override
  Future<void> initialize() async {}
  @override
  WorkspaceShellState build() => const WorkspaceShellState(
    organizationId: '10',
    currentWorkspaceId: '100',
    workspaces: [
      WorkspaceModel(
        id: '100',
        name: '合成企业',
        ownerId: '1',
        organizationId: '10',
      ),
    ],
  );
}

class _Api extends WorkspaceApi {
  _Api({
    List<Map<String, dynamic>> attachmentItems = const [],
    List<GroupModel> groupList = const [],
    List<ChannelModel> channelList = const [],
    bool shouldFail = false,
  }) : _items = attachmentItems,
       _groups = groupList,
       _channels = channelList,
       failAttachments = shouldFail;

  final List<Map<String, dynamic>> _items;
  final List<GroupModel> _groups;
  final List<ChannelModel> _channels;

  @override
  Future<List<GroupModel>> memberGroups(EntityId workspaceId) async => _groups;

  @override
  Future<List<ChannelModel>> channels(
    EntityId workspaceId, {
    String? status,
  }) async => _channels;

  bool failAttachments;

  @override
  Future<Map<String, dynamic>> attachments(
    EntityId workspaceId,
    Map<String, dynamic> filters,
  ) async {
    if (failAttachments) {
      failAttachments = false;
      throw Exception('synthetic attachment failure');
    }
    return {'workspace_id': workspaceId, 'next_cursor': null, 'items': _items};
  }
}

Map<String, dynamic> _item(
  String name, {
  int size = 100,
  String createdAt = '2026-10-08T03:00:00Z',
  String source = '研发资料群',
  String? creator = '张三',
}) => {
  'id': name.hashCode,
  'name': name,
  'size': size,
  'scope': 'group',
  'scope_ref': '200',
  'source_name': source,
  'creator_name': ?creator,
  'created_at': createdAt,
};

Future<void> _pump(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        UserModel(uid: '1', account: 'synthetic-account', nickname: '合成员工'),
      ),
      workspaceShellProvider.overrideWith(_Shell.new),
      workspaceApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        // 生产嵌入形态：入口外壳提供 Scaffold +「附件」标题栏（页面本体
        // 不再自带 AppBar，见 _resourceEntry 契约）。
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('附件')),
            body: const WorkspaceAttachmentsPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
  });

  testWidgets('ready：计数行 + 类型化图标 + 人性化大小 + 跨年年份 + 单 AppBar', (tester) async {
    final api = _Api(
      attachmentItems: [
        _item('enterprise-report.pdf', size: 100),
        _item(
          'cover.png',
          size: 2097152,
          createdAt: '2024-03-01T12:00:00Z',
          creator: null,
        ),
      ],
      groupList: [
        GroupModel.fromJson({'id': 301, 'title': '研发群'}),
      ],
    );
    await _pump(tester, api);

    expect(find.byType(AppBar), findsOneWidget, reason: '入口外壳标题栏唯一');
    expect(find.text('共 2 个附件'), findsOneWidget, reason: 'keyset 终点回显计数');
    expect(find.text('enterprise-report.pdf'), findsOneWidget);
    expect(
      find.byIcon(CupertinoIcons.doc_richtext),
      findsOneWidget,
      reason: 'pdf → 文档富文本图标（类型化视觉）',
    );
    expect(
      find.byIcon(CupertinoIcons.photo),
      findsOneWidget,
      reason: 'png → 图片图标（类型化视觉）',
    );
    expect(find.textContaining('研发资料群 · 张三 · 100 B'), findsOneWidget);
    expect(find.textContaining('2 MB'), findsOneWidget, reason: '2 MiB 人性化');
    expect(
      find.textContaining('2024/'),
      findsOneWidget,
      reason: '跨年日期带年份（不依赖本地时区断言到日）',
    );
    expect(find.text('全部群组'), findsOneWidget, reason: '下拉 hint 形态');
    expect(find.text('全部频道'), findsOneWidget);
    expect(find.text('上传人姓名、账号或编号'), findsOneWidget);
  });

  testWidgets('空态：图标 + 主文案 + 行动建议，不出计数行', (tester) async {
    await _pump(tester, _Api());
    expect(find.byKey(const ValueKey('ws-attachments-empty')), findsOneWidget);
    expect(find.text('未找到匹配附件'), findsOneWidget);
    expect(find.text('试试调整关键词或筛选条件'), findsOneWidget);
    expect(find.textContaining('共 '), findsNothing);
  });

  testWidgets('首屏失败：居中错误态 + 重试按钮点击恢复', (tester) async {
    final api = _Api(
      attachmentItems: [_item('enterprise-report.pdf')],
      shouldFail: true,
    );
    await _pump(tester, api);
    expect(find.byKey(const ValueKey('ws-attachments-error')), findsOneWidget);
    expect(find.text('附件加载失败，请重试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ws-attachments-retry')),
      findsOneWidget,
      reason: '重试必须是显式可供件（pull-to-refresh 是隐藏路径）',
    );

    await tester.tap(find.byKey(const ValueKey('ws-attachments-retry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('ws-attachments-error')),
      findsNothing,
      reason: 'api 恢复后重试即回到数据态',
    );
    expect(find.text('enterprise-report.pdf'), findsOneWidget);
  });

  testWidgets('选中群组出现「清除筛选」，点击后回收', (tester) async {
    final api = _Api(
      groupList: [
        GroupModel.fromJson({'id': 301, 'title': '研发群'}),
      ],
    );
    await _pump(tester, api);
    expect(find.text('清除筛选'), findsNothing);

    // Material 下拉覆盖层与字段错位、无勾选态——已改为底部弹层选择器。
    await tester.tap(find.text('全部群组'));
    await tester.pumpAndSettle();
    expect(find.text('选择群组'), findsOneWidget, reason: '弹层带居中标题');
    await tester.tap(find.text('研发群'));
    await tester.pumpAndSettle();
    expect(find.text('清除筛选'), findsOneWidget, reason: '激活筛选给出显式撤销入口');
    expect(find.text('研发群'), findsOneWidget, reason: '字段回显选中项');

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    expect(find.text('清除筛选'), findsNothing);
    expect(find.text('全部群组'), findsOneWidget, reason: '清除后字段回显复位 hint');
  });
}
