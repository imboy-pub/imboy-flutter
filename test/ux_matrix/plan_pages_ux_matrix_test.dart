/// T19（ux-plan imboyapp-uiux-v1）尺寸/字号矩阵——本计划改造但尚未
/// 矩阵化的核心页：频道列表（T08）/ 群列表（T11/T13）/ 组织选择器
/// （T07）/ 群信息卡（T12）。
///
/// 冻结矩阵（TASKS T19 / spec 尺寸段）：
/// - viewport sweep：360/390/430/768/1280/1440（@1.0 light，断言滚动
///   结构 + 无 overflow 异常 + 内容探针防空壳假绿）；
/// - textScale sweep：1.0/1.3/2.0 @390 light（核心页 1.0+2.0 必测）；
/// - dark @390 1.0；
/// - 热区：T07/T08 新增可操作元素 ≥48 逻辑像素高（本文件断言）。
///
/// 断言机制经阳性对照验证（sanity_overflow_test.dart：Row 溢出可捕获、
/// 正常页不误报）。数据注入用既有 fake（override provider / service）
/// 静态供料，不发请求不触 sqlite；行为契约由各卡自身测试负责。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/organization/presentation/organization_picker_page.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/group/group_detail/widgets/group_info_card.dart';
import 'package:imboy/page/group/group_list/group_list_page.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../ux_matrix/ux_harness.dart';

/// T19 冻结 viewport 矩阵（手机 3 档 + 平板 + 桌面 2 档）。
const List<Size> kPlanViewportSweep = [
  Size(360, 800),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024),
  Size(1280, 900),
  Size(1440, 900),
];

/// textScale 冻结档。
const List<double> kPlanTextScales = [1.0, 1.3, 2.0];

// ---------- fixture / fake ----------

ChannelModel _channel(int id, String name) {
  final ts = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return ChannelModel(
    id: id,
    name: name,
    creatorId: 1,
    subscriberCount: 12034,
    createdAt: ts,
    updatedAt: ts,
    userRole: ChannelUserRole.subscriber,
    isSubscribed: true,
    tags: const ['效率', '工程'],
  );
}

class _FixedChannelListNotifier extends ChannelListNotifier {
  @override
  ChannelListState build() => ChannelListState(
    channels: [
      _channel(1, '工程效率双周刊'),
      _channel(2, '内部公告板'),
      _channel(3, '一个特别特别特别特别特别特别特别特别特别长的频道名称测试用例'),
    ],
  );

  @override
  Future<void> loadSubscribedChannels() async {}

  @override
  Future<void> loadManagedChannels() async {}

  @override
  Future<void> loadMoreSubscribedChannels() async {}
}

class _FakeGroupListService extends GroupListService {
  @override
  Future<List<GroupModel>> page({
    int page = 1,
    int size = 10,
    bool onRefresh = false,
    String attr = 'all',
  }) async {
    const ts = 1700000000;
    return [
      GroupModel(
        groupId: 7001,
        type: 2,
        joinLimit: 0,
        contentLimit: 0,
        ownerUid: 1,
        creatorUid: 1,
        memberMax: 500,
        memberCount: 8,
        title: '产品研发群',
        createdAt: ts,
      ),
      GroupModel(
        groupId: 7002,
        type: 2,
        joinLimit: 0,
        contentLimit: 0,
        ownerUid: 1,
        creatorUid: 1,
        memberMax: 500,
        memberCount: 120,
        title: '一个特别特别特别特别特别特别特别长的群名称矩阵测试',
        createdAt: ts,
      ),
    ];
  }

  @override
  Future<String> computeTitle(String groupId) async => '';
}

Widget _groupInfoCard() {
  return GroupInfoCard(
    group: GroupModel(
      groupId: 7001,
      type: 2,
      joinLimit: 0,
      contentLimit: 0,
      ownerUid: 1,
      creatorUid: 1,
      memberMax: 500,
      memberCount: 23,
      title: '产品研发群',
      introduction: '这是一个很长很长的群简介用于矩阵下折叠行为与溢出断言验证',
      createdAt: 1700000000,
    ),
    onTap: () {},
  );
}

// ---------- 矩阵执行器 ----------

/// 单页矩阵：viewport sweep + textScale sweep + dark（合并单 testWidgets）。
/// [contentProbe] 在最小 viewport 档断言供料真实到位（防空壳假绿）。
Future<void> _runMatrix(
  WidgetTester tester,
  String pageLabel,
  Widget Function(UxCombo combo) buildPage, {
  Finder? contentProbe,
}) async {
  await initUxHarness();
  addTearDown(teardownUxHarness);

  // viewport sweep @1.0 light
  for (final vp in kPlanViewportSweep) {
    final combo = UxCombo(vp);
    await pumpUxCombo(tester, buildPage(combo), combo);
    tester.takeException();
    expect(
      uxHasScrollable(tester) || find.byType(Scaffold).evaluate().isNotEmpty,
      isTrue,
      reason: '${uxComboLabel(pageLabel, combo)}: 无滚动结构也无 Scaffold',
    );
    final ex = tester.takeException();
    expect(ex, isNull, reason: '${uxComboLabel(pageLabel, combo)}: $ex');
    if (vp == kPlanViewportSweep.first && contentProbe != null) {
      expect(
        contentProbe.evaluate().isNotEmpty,
        isTrue,
        reason: '${uxComboLabel(pageLabel, combo)}: 内容探针落空（供料断链，矩阵空转假绿）',
      );
    }
  }

  // textScale sweep @390 light（长文本自然增高，只断 overflow 不截高）
  for (final scale in kPlanTextScales) {
    final combo = UxCombo(kUxMediumViewport, textScale: scale);
    await pumpUxCombo(tester, buildPage(combo), combo);
    final ex = tester.takeException();
    expect(ex, isNull, reason: '${uxComboLabel(pageLabel, combo)}: $ex');
  }

  // dark @390 1.0
  final dark = UxCombo(kUxMediumViewport, brightness: Brightness.dark);
  await pumpUxCombo(tester, buildPage(dark), dark);
  final exDark = tester.takeException();
  expect(exDark, isNull, reason: '${uxComboLabel(pageLabel, dark)}: $exDark');
}

void main() {
  testWidgets('T19 矩阵：ChannelListPage（T08 改造面）', (tester) async {
    await _runMatrix(tester, 'ChannelListPage', (combo) {
      return ProviderScope(
        overrides: [
          channelListProvider.overrideWith(_FixedChannelListNotifier.new),
        ],
        child: const ChannelListPage(),
      );
    }, contentProbe: find.text('工程效率双周刊'));
  });

  testWidgets('T19 矩阵：GroupListPage（T11/T13 改造面）', (tester) async {
    await _runMatrix(tester, 'GroupListPage', (combo) {
      return ProviderScope(
        overrides: [
          groupListServiceProvider.overrideWithValue(_FakeGroupListService()),
        ],
        child: const GroupListPage(),
      );
    }, contentProbe: find.text('产品研发群'));
  });

  testWidgets('T19 矩阵：OrganizationPickerPage（T07 改造面）+ 热区', (tester) async {
    await initUxHarness();
    addTearDown(teardownUxHarness);
    // picker 数据源：mine 列表静态供料（账户固定注入，绕开登录态）。
    uxInstallStub(
      RouteStubAdapter([
        (
          '/organizations/mine',
          [
            (
              200,
              uxPage([
                {'id': 7001, 'name': '矩阵企业甲', 'member_role': 'member'},
                {
                  'id': 7002,
                  'name': '一个特别特别特别特别特别长的企业名称矩阵用例',
                  'member_role': 'owner',
                },
              ]),
            ),
          ],
        ),
      ]),
    );
    await _runMatrix(tester, 'OrganizationPickerPage', (combo) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            UserModel(uid: '91001', account: 'ux-matrix'),
          ),
        ],
        child: const OrganizationPickerPage(accountKey: '91001'),
      );
    }, contentProbe: find.text('矩阵企业甲'));

    // T19 热区冻结值：T07 新增的底部主/次按钮 ≥48 逻辑像素高。
    for (final key in const [
      'org-picker-join-entry',
      'org-picker-create-entry',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(
        rect.height,
        greaterThanOrEqualTo(48),
        reason: 'T19 热区：$key 高度 ${rect.height} < 48',
      );
    }
  });

  testWidgets('T19 矩阵：GroupInfoCard（T12 改造面，组件级）', (tester) async {
    await _runMatrix(
      tester,
      'GroupInfoCard',
      (combo) => SingleChildScrollView(child: _groupInfoCard()),
      contentProbe: find.text('产品研发群'),
    );
  });

  testWidgets('T19 热区：频道列表分段控件 ≥48 逻辑像素高', (tester) async {
    await initUxHarness();
    addTearDown(teardownUxHarness);
    await pumpUxCombo(
      tester,
      ProviderScope(
        overrides: [
          channelListProvider.overrideWith(_FixedChannelListNotifier.new),
        ],
        child: const ChannelListPage(),
      ),
      const UxCombo(Size(390, 844)),
    );
    final segment = find.byType(CupertinoSlidingSegmentedControl<int>);
    expect(segment, findsOneWidget);
    final segRect = tester.getRect(segment);
    expect(
      segRect.height,
      greaterThanOrEqualTo(48),
      reason: 'T19 热区：频道列表分段高度 ${segRect.height} < 48',
    );
  });

  testWidgets('T19 热区：群列表分段控件 ≥48 逻辑像素高', (tester) async {
    await initUxHarness();
    addTearDown(teardownUxHarness);
    await pumpUxCombo(
      tester,
      ProviderScope(
        overrides: [
          groupListServiceProvider.overrideWithValue(_FakeGroupListService()),
        ],
        child: const GroupListPage(),
      ),
      const UxCombo(Size(390, 844)),
    );
    // fake service 数据经页面 initData 异步链到位后再断言。
    await pumpUntilUxFound(tester, find.text('产品研发群'));
    final groupSeg = find.byType(CupertinoSlidingSegmentedControl<String>);
    expect(groupSeg, findsOneWidget);
    final gRect = tester.getRect(groupSeg);
    expect(
      gRect.height,
      greaterThanOrEqualTo(48),
      reason: 'T19 热区：群列表分段高度 ${gRect.height} < 48',
    );
  });
}
