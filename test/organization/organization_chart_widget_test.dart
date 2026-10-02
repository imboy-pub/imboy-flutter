import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/infrastructure/human_directory_api.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_chart.dart';

class ChartSource implements HumanDirectoryDataSource {
  bool deny = false;
  Completer<HumanDirectoryPage<HumanDirectoryDepartment>>? pending;
  final calls = <String>[];
  @override
  Future<HumanDirectoryPage<HumanDirectoryDepartment>> directoryDepartments({
    required EntityId organizationId,
    EntityId? parentId,
    String? cursor,
    int? limit,
  }) async {
    calls.add('$organizationId/${parentId ?? "root"}/${cursor ?? "first"}');
    if (pending != null) return pending!.future;
    if (deny) throw const OrganizationApiException(403, 'synthetic denied');
    final rows = parentId == null
        ? cursor == null
              ? const [
                  HumanDirectoryDepartment(
                    id: '1',
                    name: '销售部',
                    memberCount: 12,
                  ),
                ]
              : const [
                  HumanDirectoryDepartment(
                    id: '2',
                    name: '技术部',
                    memberCount: 8,
                  ),
                ]
        : parentId == '1'
        ? const [
            HumanDirectoryDepartment(
              id: '3',
              parentId: '1',
              name: '广州销售组',
              memberCount: 6,
            ),
          ]
        : <HumanDirectoryDepartment>[];
    return HumanDirectoryPage(
      list: rows,
      cursor: parentId == null && cursor == null ? 'next' : null,
      hasMore: parentId == null && cursor == null,
    );
  }

  @override
  Future<HumanDirectoryPage<HumanDirectoryMember>> directoryMembers({
    required EntityId organizationId,
    EntityId? departmentId,
    String? cursor,
    int? limit,
  }) async => const HumanDirectoryPage(list: [], cursor: null, hasMore: false);
  @override
  Future<HumanDirectoryMe> directoryMe({
    required EntityId organizationId,
  }) async => HumanDirectoryMe(organizationId: organizationId, list: const []);
  @override
  Future<HumanDirectoryPage<HumanDirectorySearchItem>> directorySearch({
    required EntityId organizationId,
    required String q,
    String? cursor,
    int? limit,
  }) async => const HumanDirectoryPage(list: [], cursor: null, hasMore: false);
}

Widget chartHost(
  ChartSource source, {
  String account = 'synthetic-account',
  String org = '100',
  double textScale = 1,
  ValueChanged<List<HumanDirectoryDepartment>>? onOpen,
  ValueChanged<OrganizationApiException>? onDenied,
}) => TranslationProvider(
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: OrganizationChart(
          accountKey: account,
          organizationId: org,
          organizationName: '广州示例公司',
          source: source,
          onAccessDenied: onDenied,
          onOpenDepartment: onOpen ?? (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  test('图形节点和子树不重叠，折叠移除后代，损坏的环不会无限递归', () {
    const a = HumanDirectoryDepartment(id: '1', name: '销售部');
    const b = HumanDirectoryDepartment(id: '2', name: '技术部');
    const c = HumanDirectoryDepartment(id: '3', parentId: '1', name: '销售组');
    final tree = {
      '': [a, b],
      '1': [c],
    };
    final graph = organizationChartLayout(tree, {'', '1'});
    expect(graph.nodes.keys, containsAll(['', '1', '2', '3']));
    expect(graph.nodes['1']!.rect.overlaps(graph.nodes['2']!.rect), isFalse);
    expect(
      graph.nodes['3']!.rect.top,
      greaterThan(graph.nodes['1']!.rect.bottom),
    );
    expect(organizationChartLayout(tree, {''}).nodes.containsKey('3'), isFalse);
    expect(
      organizationChartLayout(
        {
          '': [a],
          '1': [a],
        },
        {'', '1'},
      ).nodes.length,
      2,
    );
  });

  testWidgets('授权分页图形支持拖动、缩放、适应、展开和节点成员跳转', (tester) async {
    final source = ChartSource();
    List<HumanDirectoryDepartment>? selected;
    await tester.pumpWidget(
      chartHost(source, onOpen: (path) => selected = path),
    );
    await tester.pumpAndSettle();
    expect(source.calls, ['100/root/first', '100/root/next']);
    expect(find.text('销售部'), findsOneWidget);
    expect(find.text('技术部'), findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final initial = viewer.transformationController!.value.clone();
    await tester.tap(find.byKey(const ValueKey('org-chart-zoom-in')));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(initial.getMaxScaleOnAxis()),
    );
    await tester.tap(find.byKey(const ValueKey('org-chart-zoom-out')));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(initial.getMaxScaleOnAxis(), .001),
    );
    final beforeDrag = viewer.transformationController!.value.clone();
    await tester.drag(find.byType(InteractiveViewer), const Offset(70, 50));
    await tester.pumpAndSettle();
    expect(
      viewer.transformationController!.value.storage[12],
      isNot(beforeDrag.storage[12]),
    );
    await tester.tap(find.byKey(const ValueKey('org-chart-fit')));
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final beforePinch = viewer.transformationController!.value
        .getMaxScaleOnAxis();
    final finger1 = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final finger2 = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await finger1.moveBy(const Offset(-45, 0));
    await finger2.moveBy(const Offset(45, 0));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(beforePinch),
    );
    await finger1.up();
    await finger2.up();
    await tester.tap(find.byKey(const ValueKey('org-chart-fit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('org-chart-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('广州销售组'), findsOneWidget);
    await tester.tap(find.text('广州销售组'));
    expect(selected!.map((row) => row.id), ['1', '3']);
    await tester.tap(find.byKey(const ValueKey('org-chart-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('广州销售组'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分支撤权立即清空整图并通知成员列表', (tester) async {
    final source = ChartSource();
    var denied = false;
    await tester.pumpWidget(chartHost(source, onDenied: (_) => denied = true));
    await tester.pumpAndSettle();
    source.deny = true;
    await tester.tap(find.byKey(const ValueKey('org-chart-expand-1')));
    await tester.pumpAndSettle();
    expect(find.text('销售部'), findsNothing);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(denied, isTrue);
  });

  testWidgets('换账号和企业后旧响应不得回填图形', (tester) async {
    final old = ChartSource()..pending = Completer();
    await tester.pumpWidget(chartHost(old));
    final next = ChartSource();
    await tester.pumpWidget(
      chartHost(next, account: 'next-account', org: '200'),
    );
    await tester.pumpAndSettle();
    old.pending!.complete(
      const HumanDirectoryPage(
        list: [HumanDirectoryDepartment(id: '99', name: '旧企业秘密部门')],
        cursor: null,
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧企业秘密部门'), findsNothing);
    expect(find.text('销售部'), findsOneWidget);
    expect(next.calls.every((call) => call.startsWith('200/')), isTrue);
  });

  testWidgets('窄屏双倍字号无布局溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(chartHost(ChartSource(), textScale: 2));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
