// AI 预览夹具（过程性产物，不入 git）：企业模式消息页「有数据」视觉预览。
//
// RUN: flutter test integration_test/preview/workspace_messages_preview_macos_test.dart -d macos \
//   2>&1 | python3 /tmp/decode_preview_png.py
// OUT: /tmp/imboy_preview/{workspace_messages_light,dark}.png
//（macOS integration_test 无 takeScreenshot 平台通道且沙盒禁写任意路径；
//  PNG 以 [AI_PNG] 分块 base64 走 stdout，由外层脚本重组落盘）
//
// 不依赖后端/账号：ProviderScope 注入 mock WorkspaceApi（复用单测
// workspace_conversations_page_test 的接线），macOS 真渲染拿真实字体
// 与组件管线。
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _NeverReadGlobal extends ConversationNotifier {
  @override
  ConversationState build() =>
      throw StateError('Workspace read global conversation cache');
}

class _Api extends WorkspaceApi {
  final List<WorkspaceConversationModel> rows;
  _Api(this.rows);

  @override
  Future<List<WorkspaceConversationModel>> conversations(
    EntityId workspaceId,
  ) async => rows;
}

String _iso(Duration ago) =>
    DateTime.now().toUtc().subtract(ago).toIso8601String();

Map<String, dynamic> _row({
  required int id,
  required String title,
  required String text,
  required String serverTs,
  int unread = 0,
  int memberCount = 20,
  String msgType = 'text',
}) => {
  'id': id,
  'scope': 'workspace',
  'workspace_id': 100,
  'status': 1,
  'title': title,
  'avatar': '',
  'member_count': memberCount,
  'unread_count': unread,
  'member_start_seq': 3,
  'latest_message': {
    'msg_id': 'msg$id',
    'conv_seq': 4,
    'msg_type': msgType,
    'payload': <String, dynamic>{
      'payload': <String, dynamic>{'text': text},
    },
    'e2ee': null,
    'server_ts': serverTs,
    'expire_at': null,
  },
};

List<Map<String, dynamic>> _mockRows() => [
  _row(
    id: 101,
    title: '产品研发群',
    text: '刚才那版设计稿我更新到共享目录了，重点看第 3 页的交互细节',
    serverTs: _iso(const Duration(minutes: 3)),
    unread: 12,
    memberCount: 23,
  ),
  _row(
    id: 102,
    title: '华南渠道对接群',
    text:
        '本周渠道对账单已经同步到财务侧，周三之前请各区域负责人确认返利口径，'
        '逾期未反馈的按上一季度默认规则执行，有问题群里 @我',
    serverTs: _iso(const Duration(minutes: 42)),
    unread: 128,
    memberCount: 156,
  ),
  _row(
    id: 103,
    title: '每周产品例会',
    text: '明早十点例会改到会议室 B，agenda 不变，请提前看上周纪要',
    serverTs: _iso(const Duration(hours: 2, minutes: 15)),
    unread: 3,
    memberCount: 9,
  ),
  _row(
    id: 104,
    title: '设计资源同步',
    msgType: 'image',
    text: '',
    serverTs: _iso(const Duration(hours: 5)),
    unread: 2,
    memberCount: 31,
  ),
  _row(
    id: 105,
    title: '客户成功 1 群',
    text: '客户侧灰度报告已回传，续约方案下周一对齐',
    serverTs: _iso(const Duration(hours: 20)),
    memberCount: 45,
  ),
  _row(
    id: 106,
    title: '招聘协同',
    text: '高级前端候选人已约到周四下午三点，面试官请提前看简历',
    serverTs: _iso(const Duration(days: 3)),
    memberCount: 12,
  ),
];

ProviderContainer _container(_Api api) => ProviderContainer(
  overrides: [
    workspaceApiProvider.overrideWithValue(api),
    currentUserProvider.overrideWithValue(UserModel.fromJson({'uid': '1'})),
    conversationProvider.overrideWith(_NeverReadGlobal.new),
  ],
);

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const WorkspaceConversationsPage()),
  ],
);

final _shotKey = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: _shotKey,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: dark ? ThemeData(brightness: Brightness.dark) : null,
            routerConfig: _router(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// macOS 沙盒禁写任意宿主路径：PNG 分块 base64 走 stdout，外层
/// /tmp/decode_preview_png.py 监听 [AI_PNG] 标记重组落盘。
Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  final image = await boundary.toImage(pixelRatio: 2.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final b64 = base64Encode(data!.buffer.asUint8List());
  debugPrint('[AI_PNG_BEGIN:$name:${b64.length}]');
  const chunkSize = 800;
  for (var i = 0; i < b64.length; i += chunkSize) {
    // ignore: avoid_print
    print(b64.substring(i, math.min(i + chunkSize, b64.length)));
  }
  debugPrint('[AI_PNG_END:$name:${b64.length}]');
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workspace messages with data — light & dark', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _Api(
      _mockRows().map(WorkspaceConversationModel.fromJson).toList(),
    );
    final container = _container(api);
    addTearDown(container.dispose);
    // 与单测同款：选中工作区 100（applyCreated 驱动 currentWorkspaceProvider）。
    container
        .read(workspaceShellProvider.notifier)
        .applyCreated(
          WorkspaceCreateResult(
            workspace: WorkspaceModel(
              id: '100',
              name: 'Preview Workspace',
              ownerId: '1',
            ),
            channelId: '',
            groupId: '',
            status: 'created',
          ),
        );

    await _pump(tester, container);
    await tester.pump(const Duration(milliseconds: 300));
    await _shoot(tester, 'workspace_messages_light');

    await _pump(tester, container, dark: true);
    await tester.pump(const Duration(milliseconds: 300));
    await _shoot(tester, 'workspace_messages_dark');
  });
}
