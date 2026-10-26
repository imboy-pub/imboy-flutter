/// T10 面聊记录列表页 widget 测试：个人/企业空间矩阵、筛选切换、
/// 空态（从未创建 ≠ 无结果）、记录行内容、录音条占位（跨空间标注）、
/// 入口行导航。
///
/// 纪律：fixture 服务注入（零网络）；录音条状态由 stub Notifier 注入
/// （零录音副作用）；本文件是 widget fixture 测试，不是与真实
/// capabilities/creation-contexts 的联调验收（T11+/T22）。
library;

import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_pending_uploads.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_tiles.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_list_page.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';

/// 记录服务调用与响应的 fixture。
class FakeListService implements TalkRecordListService {
  FakeListService({
    this.records = const [],
    TalkRecordCapabilitiesModel? capabilities,
    this.contexts = const [],
    this.error,
  }) : capsValue = capabilities;

  List<TalkRecordModel> records;
  final TalkRecordCapabilitiesModel? capsValue;
  List<TalkRecordCreationContextModel> contexts;
  Object? error;

  final List<Map<String, Object?>> pageCalls = [];

  @override
  Future<TalkRecordCursorPage<TalkRecordModel>> page({
    TalkRecordScope? scope,
    String? organizationId,
    String? workspaceId,
    TalkRecordListFilter? filter,
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    pageCalls.add({
      'scope': scope?.wireName,
      'organization_id': organizationId,
      'workspace_id': workspaceId,
      'filter': filter?.wireName,
      'q': q,
      'cursor': cursor,
    });
    if (error != null) throw error!;
    return TalkRecordCursorPage<TalkRecordModel>(
      list: records,
      nextCursor: '',
      hasMore: false,
    );
  }

  @override
  Future<TalkRecordCapabilitiesModel> capabilities() async {
    return capsValue ??
        TalkRecordCapabilitiesModel.fromJson(const <String, dynamic>{});
  }

  @override
  Future<List<TalkRecordCreationContextModel>> creationContexts({
    String cursor = '',
    int? limit,
  }) async {
    return contexts;
  }
}

/// 录音条状态 stub（页面侧只读展示）。
class StubCaptureNotifier extends TalkRecordActiveCaptureNotifier {
  StubCaptureNotifier(this.initial);

  final TalkRecordActiveCaptureState initial;

  @override
  TalkRecordActiveCaptureState build() => initial;
}

/// 已配置转写能力的 capabilities fixture（准备页联动用）。
final TalkRecordCapabilitiesModel kConfiguredCaps =
    TalkRecordCapabilitiesModel.fromJson(const {
      'processing_available': true,
      'asr_enabled': true,
      'processor_config_version': 'approved-bundle-v1',
      'summary_enabled': true,
      'queue_limit': 5,
      'max_duration_ms': 7_200_000,
    });

TalkRecordModel _record({
  Object id = 101,
  String title = '客户访谈',
  int durationMs = 655_000,
  String media = 'available',
  String transcript = 'ready',
  String processing = 'transcribe',
  String visibility = 'owner_only',
}) {
  return TalkRecordModel.fromJson({
    'id': id,
    'title': title,
    'media_status': media,
    'transcript_status': transcript,
    'processing_mode': processing,
    'capture_status': 'ended',
    'duration_ms': durationMs,
    'visibility': visibility,
  });
}

/// 统一 pump：服务注入 + 可选录音条状态注入（无显式 Override 类型——
/// flutter_riverpod 3.x 未导出该类型，字面量经 use-site 推断）。
Future<void> pumpList(
  WidgetTester tester, {
  required TalkRecordEntryContext entryContext,
  required FakeListService service,
  TalkRecordActiveCaptureState? capture,
  TalkRecordCapabilitiesModel? capabilities,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        talkRecordPendingAccountProvider.overrideWithValue(
          const TalkRecordAccount('http://127.0.0.1', ''),
        ),
        talkRecordListServiceProvider.overrideWithValue(service),
        if (capture != null)
          talkRecordActiveCaptureProvider.overrideWith(
            () => StubCaptureNotifier(capture),
          ),
        if (capabilities != null)
          talkRecordCapabilitiesProvider.overrideWith(
            (ref) async => capabilities,
          ),
      ],
      child: MaterialApp(home: TalkRecordListPage(entryContext: entryContext)),
    ),
  );
}

void main() {
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });

  group('空间上下文矩阵', () {
    testWidgets('个人入口：默认空间不重复展示，不显示工作区行', (tester) async {
      final service = FakeListService(records: [_record()]);
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();

      // DESIGN.md §8.14: personal is the default context, with no caption.
      expect(find.text(t.talkRecord.contextPersonal), findsNothing);
      expect(find.textContaining('·'), findsNothing);
      // 服务按 personal scope 拉取，不带 org/ws。
      expect(service.pageCalls.single['scope'], 'personal');
      expect(service.pageCalls.single['organization_id'], null);
      expect(service.pageCalls.single['workspace_id'], null);
    });

    testWidgets('企业入口：显示企业名；携带工作区时追加展示', (tester) async {
      final service = FakeListService(records: [_record()]);
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext(
          scope: TalkRecordScope.organization,
          organizationId: '7001',
          organizationName: '甲企业',
          workspaceId: '8001',
          workspaceName: '主工作区',
        ),
        service: service,
      );
      await tester.pumpAndSettle();

      expect(find.text('甲企业 · 主工作区'), findsOneWidget);
      expect(service.pageCalls.single['scope'], 'organization');
      expect(service.pageCalls.single['organization_id'], '7001');
      expect(service.pageCalls.single['workspace_id'], '8001');
    });

    testWidgets('企业入口未带工作区：不展示未知工作区，服务不传 ws', (tester) async {
      final service = FakeListService(records: [_record()]);
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext(
          scope: TalkRecordScope.organization,
          organizationId: '7001',
          organizationName: '甲企业',
        ),
        service: service,
      );
      await tester.pumpAndSettle();

      expect(find.text('甲企业'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
      expect(service.pageCalls.single['workspace_id'], null);
    });
  });

  group('筛选切换', () {
    testWidgets('全部/我创建/共享给我传递 filter 参数', (tester) async {
      final service = FakeListService(records: [_record()]);
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();
      expect(service.pageCalls.last['filter'], 'all');

      await tester.tap(find.text(t.talkRecord.filterOwned));
      await tester.pumpAndSettle();
      expect(service.pageCalls.last['filter'], 'owned');

      await tester.tap(find.text(t.talkRecord.filterShared));
      await tester.pumpAndSettle();
      expect(service.pageCalls.last['filter'], 'shared');
    });
  });

  group('空态', () {
    testWidgets('默认筛选无数据 → 「还没有」+ 空态保留筛选/搜索/新建入口', (tester) async {
      final service = FakeListService();
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.emptyNeverCreatedTitle), findsOneWidget);
      expect(find.text(t.talkRecord.filterAll), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_search_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_create_button')),
        findsOneWidget,
      );
    });

    testWidgets('筛选无结果 → 「没有匹配」，不把无结果误报从未创建', (tester) async {
      final service = FakeListService();
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.talkRecord.filterOwned));
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.emptyNoMatchTitle), findsOneWidget);
      expect(find.text(t.talkRecord.emptyNeverCreatedTitle), findsNothing);
    });

    testWidgets('加载失败 → 失败态 + 重试（不吞成空列表）', (tester) async {
      final service = FakeListService(error: StateError('down'));
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.loadFailedTitle), findsOneWidget);
      expect(find.text(t.talkRecord.emptyNeverCreatedTitle), findsNothing);

      service.error = null;
      service.records = [_record()];
      await tester.tap(find.byKey(const ValueKey('talk_record_load_retry')));
      await tester.pumpAndSettle();
      expect(find.text('客户访谈'), findsOneWidget);
    });
  });

  group('记录行', () {
    testWidgets('标题/时长/状态/可见范围/本机草稿标记', (tester) async {
      final service = FakeListService(
        records: [
          _record(),
          _record(
            id: 102,
            title: '',
            durationMs: 0,
            media: 'local_only',
            transcript: 'not_requested',
            processing: 'record_only',
            visibility: 'shared_with_grants',
          ),
        ],
      );
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();

      expect(find.text('客户访谈'), findsOneWidget);
      expect(find.text('10:55'), findsOneWidget);
      expect(find.text(t.talkRecord.statusTranscribeReady), findsOneWidget);
      expect(find.text(t.talkRecord.visibilityOwnerOnly), findsOneWidget);
      // 未命名 + 仅录音 + 本机草稿（仅本机标记）。
      expect(find.text(t.talkRecord.untitledRecord), findsOneWidget);
      expect(find.text(t.talkRecord.statusRecordOnly), findsOneWidget);
      expect(find.text(t.talkRecord.localDraftBadge), findsOneWidget);
    });

    testWidgets('已共享可见范围 pill', (tester) async {
      final service = FakeListService(
        records: [_record(visibility: 'shared_with_grants')],
      );
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();
      expect(find.text(t.talkRecord.visibilityShared), findsOneWidget);
    });
  });

  group('录音条占位（状态注入，零录音副作用）', () {
    testWidgets('录音中状态 + 跨空间标注原归属', (tester) async {
      final service = FakeListService(records: [_record()]);
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
        capture: const TalkRecordActiveCaptureState(
          visible: true,
          phase: TalkRecordCaptureBarPhase.recording,
          title: '项目例会',
          positionMs: 125_000,
          originContext: TalkRecordEntryContext(
            scope: TalkRecordScope.organization,
            organizationId: '7001',
            organizationName: '甲企业',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('talk_record_recording_bar')),
        findsOneWidget,
      );
      expect(find.text(t.talkRecord.barRecording), findsOneWidget);
      expect(find.text('来自 甲企业'), findsOneWidget);
      expect(find.text('02:05'), findsOneWidget);
    });

    testWidgets('暂停文案区分；同空间不标注归属', (tester) async {
      final service = FakeListService();
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
        capture: const TalkRecordActiveCaptureState(
          visible: true,
          phase: TalkRecordCaptureBarPhase.paused,
          originContext: TalkRecordEntryContext.personal(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.barPaused), findsOneWidget);
      expect(find.textContaining(t.talkRecord.barOriginPrefix), findsNothing);
    });

    testWidgets('不可见时零占位', (tester) async {
      final service = FakeListService();
      await pumpList(
        tester,
        entryContext: const TalkRecordEntryContext.personal(),
        service: service,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_recording_bar')),
        findsNothing,
      );
    });
  });

  group('入口行导航（router 挂载 talkRecordRoutes）', () {
    testWidgets('个人/企业入口行 push 列表并携带上下文 query', (tester) async {
      final service = FakeListService();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(
              body: Column(
                children: [
                  TalkRecordPersonalToolEntry(),
                  TalkRecordOrgToolEntry(
                    organizationId: '7001',
                    organizationName: '甲企业',
                  ),
                ],
              ),
            ),
          ),
          ...talkRecordRoutes(),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordPendingAccountProvider.overrideWithValue(
              const TalkRecordAccount('http://127.0.0.1', ''),
            ),
            talkRecordListServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('talk_record_personal_entry')),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/talk_record?scope=personal');
      // DESIGN.md §8.14: personal is the default context, with no caption.
      expect(find.text(t.talkRecord.contextPersonal), findsNothing);

      router.push('/home');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('talk_record_org_entry')));
      await tester.pumpAndSettle();
      expect(
        router.state.uri.toString(),
        '/talk_record?scope=organization&organization_id=7001'
        '&organization_name=${Uri.encodeComponent('甲企业')}',
      );
    });

    testWidgets('列表新建按钮 push 准备页并携带上下文', (tester) async {
      final service = FakeListService();
      final router = GoRouter(
        initialLocation: '/talk_record',
        routes: talkRecordRoutes(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordPendingAccountProvider.overrideWithValue(
              const TalkRecordAccount('http://127.0.0.1', ''),
            ),
            talkRecordListServiceProvider.overrideWithValue(service),
            talkRecordCapabilitiesProvider.overrideWith(
              (ref) async => kConfiguredCaps,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('talk_record_create_button')));
      await tester.pumpAndSettle();
      expect(router.state.path, kTalkRecordPreparePath);
      expect(find.text(t.talkRecord.prepareTitle), findsOneWidget);
    });
  });
}
