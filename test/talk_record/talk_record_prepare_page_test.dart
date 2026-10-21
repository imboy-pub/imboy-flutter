/// T10 面聊记录准备页 widget 测试：能力降级矩阵（未配置/配额/已配置）、
/// 企业协作折叠区（个人不显示、参与者注入勾选）、已告知确认触达区与
/// 门控、麦克风权限拒绝态（注入网关，不请求真权限）、启动器占位、
/// 以及「跳保存位置回来标题还在」的导航不丢稿（真实 GoRouter + 共享
/// ProviderContainer）。
///
/// 纪律：全部能力/目录/权限/启动器经 Provider override 注入——widget
/// 测试零麦克风副作用、零网络；不是与真实端点的联调验收（T11+/T22）。
library;

import 'package:imboy/modules/talk_record/presentation/talk_record_notification_permission.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_prepare_page.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_save_location_page.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

// ---------------------------------------------------------------------------
// fixtures
// ---------------------------------------------------------------------------

class FakeNotificationGateway
    implements TalkRecordNotificationPermissionGateway {
  FakeNotificationGateway({
    this.required = true,
    this.status = TalkRecordNotificationPermissionStatus.denied,
  });
  @override
  final bool required;
  TalkRecordNotificationPermissionStatus status;
  int requests = 0, settings = 0;
  Completer<TalkRecordNotificationPermissionStatus>? pending;
  @override
  Future<TalkRecordNotificationPermissionStatus> request() async {
    requests++;
    return pending == null ? status : await pending!.future;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }
}

class FakeMicGateway implements TalkRecordMicPermissionGateway {
  FakeMicGateway([this.status = TalkRecordMicPermissionStatus.denied]);

  TalkRecordMicPermissionStatus status;
  int requestCount = 0;
  int settingsCount = 0;

  @override
  Future<TalkRecordMicPermissionStatus> request() async {
    requestCount++;
    return status;
  }

  @override
  Future<void> openSettings() async {
    settingsCount++;
  }
}

class PendingMicGateway extends FakeMicGateway {
  final pending = Completer<TalkRecordMicPermissionStatus>();
  @override
  Future<TalkRecordMicPermissionStatus> request() => pending.future;
}

class FakeLauncher implements TalkRecordRecordingLauncher {
  TalkRecordRecordingDraftRequest? lastRequest;
  bool startSucceeds;
  bool notificationFailure = false;

  FakeLauncher({this.startSucceeds = false});

  @override
  Future<TalkRecordRecordingLaunchResult> launch(
    TalkRecordRecordingDraftRequest request,
  ) async {
    lastRequest = request;
    if (notificationFailure) {
      return const TalkRecordRecordingLaunchResult.notificationsRequired();
    }
    return startSucceeds
        ? const TalkRecordRecordingLaunchResult.started()
        : const TalkRecordRecordingLaunchResult.unavailable();
  }
}

class FakeDirectory implements TalkRecordParticipantDirectory {
  FakeDirectory(this.options);

  final List<TalkRecordParticipantOption> options;

  @override
  bool get isAvailable => true;

  @override
  Future<List<TalkRecordParticipantOption>> search(
    String organizationId,
    String q,
  ) async {
    return options;
  }
}

class FakeDataService implements TalkRecordListService {
  FakeDataService({this.caps, this.contexts = const [], this.capError});

  /// capabilities fixture（命名与 capabilities() 方法区分）。
  final TalkRecordCapabilitiesModel? caps;
  final List<TalkRecordCreationContextModel> contexts;
  final Object? capError;

  /// 置 true 后 creationContexts 抛错（失败态用例）。
  bool forceContextsError = false;

  @override
  Future<TalkRecordCapabilitiesModel> capabilities() async {
    if (capError != null) throw capError!;
    return caps ?? TalkRecordCapabilitiesModel.fromJson(const {});
  }

  @override
  Future<List<TalkRecordCreationContextModel>> creationContexts({
    String cursor = '',
    int? limit,
  }) async {
    if (forceContextsError) throw StateError('contexts down');
    return contexts;
  }

  @override
  Future<Never> page({
    TalkRecordScope? scope,
    String? organizationId,
    String? workspaceId,
    TalkRecordListFilter? filter,
    String? q,
    String cursor = '',
    int? limit,
  }) {
    throw UnimplementedError('列表页不在本测试范围');
  }
}

const List<TalkRecordCreationContextModel> kContexts = [
  TalkRecordCreationContextModel(scope: TalkRecordScope.personal),
  TalkRecordCreationContextModel(
    scope: TalkRecordScope.organization,
    organizationId: '7001',
    displayName: '甲企业',
    retentionPolicy: '企业策略 180 天',
  ),
  TalkRecordCreationContextModel(
    scope: TalkRecordScope.organization,
    organizationId: '7001',
    workspaceId: '8001',
    displayName: '主工作区',
  ),
];

const TalkRecordEntryContext kOrgEntry = TalkRecordEntryContext(
  scope: TalkRecordScope.organization,
  organizationId: '7001',
  organizationName: '甲企业',
);

const String kOrgPreparePath =
    '$kTalkRecordPreparePath?scope=organization&organization_id=7001'
    '&organization_name=%E7%94%B2%E4%BC%81%E4%B8%9A';

TalkRecordCapabilitiesModel _caps(Map<String, dynamic> json) {
  return TalkRecordCapabilitiesModel.fromJson(json);
}

/// 统一 pump：显式容器（供断言草稿）+ 可选 router（导航用例）。
Future<void> pumpPrepare(
  WidgetTester tester,
  ProviderContainer container, {
  TalkRecordEntryContext entryContext = kOrgEntry,
  GoRouter? router,
}) {
  final child = router == null
      ? TalkRecordPreparePage(entryContext: entryContext)
      : null;
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ),
  );
}

void main() {
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });

  /// 统一容器（服务/网关注入；无显式 Override 类型——经字面量推断）。
  ProviderContainer newContainer({
    TalkRecordListService? service,
    FakeMicGateway? mic,
    FakeLauncher? launcher,
    FakeNotificationGateway? notifications,
    FakeDirectory? directory,
    TalkRecordAuthSubscribe? authSubscribe,
  }) {
    final container = ProviderContainer(
      overrides: [
        if (authSubscribe != null)
          talkRecordAuthSubscribeProvider.overrideWithValue(authSubscribe),
        if (service != null)
          talkRecordListServiceProvider.overrideWithValue(service),
        if (mic != null)
          talkRecordMicPermissionGatewayProvider.overrideWithValue(mic),
        if (launcher != null)
          talkRecordRecordingLauncherProvider.overrideWithValue(launcher),
        if (notifications != null)
          talkRecordNotificationPermissionGatewayProvider.overrideWithValue(
            notifications,
          ),
        talkRecordParticipantDirectoryProvider.overrideWithValue(
          directory ?? const EmptyParticipantDirectory(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets(
    'auth transition during microphone permission never launches for the next account',
    (tester) async {
      final mic = PendingMicGateway();
      final launcher = FakeLauncher();
      final listeners = <void Function()>[];
      final container = newContainer(
        service: FakeDataService(),
        mic: mic,
        launcher: launcher,
        authSubscribe: (changed) {
          listeners.add(changed);
          return () => listeners.remove(changed);
        },
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();
      container
          .read(talkRecordDraftProvider.notifier)
          .setNoticeAcknowledged(true);
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_start_button')),
      );
      await tester.tap(find.byKey(const ValueKey('talk_record_start_button')));
      await tester.pump();
      for (final listener in List.of(listeners)) {
        listener();
      }
      mic.pending.complete(TalkRecordMicPermissionStatus.granted);
      await tester.pumpAndSettle();
      expect(
        container.read(talkRecordDraftProvider).noticeAcknowledged,
        isFalse,
      );
      expect(launcher.lastRequest, isNull);
    },
  );

  group('处理方式能力降级', () {
    testWidgets('未配置转写 → 单档「仅录音」+ 原因，无虚假 AI 选项', (tester) async {
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.processingRecordOnly), findsOneWidget);
      expect(find.text(t.talkRecord.processingTranscribe), findsNothing);
      expect(find.text(t.talkRecord.processingSummarize), findsNothing);
      expect(
        find.text(t.talkRecord.processingReasonUnavailable),
        findsOneWidget,
      );
    });

    testWidgets('配额不足 → 仅录音 + 「录音不受影响」说明', (tester) async {
      final container = newContainer(
        service: FakeDataService(
          caps: _caps(const {
            'processing_available': true,
            'asr_enabled': true,
            'processor_config_version': 'approved-bundle-v1',
            'queue_limit': 0,
          }),
        ),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.processingReasonQuota), findsOneWidget);
      expect(find.text(t.talkRecord.processingTranscribe), findsNothing);
    });

    testWidgets('能力加载失败 → 按仅录音处理并说明', (tester) async {
      final container = newContainer(
        service: FakeDataService(capError: StateError('caps down')),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.processingRecordOnly), findsOneWidget);
      expect(
        find.text(t.talkRecord.processingReasonLoadFailed),
        findsOneWidget,
      );
    });

    testWidgets('已配置 → 多档可选，切换写入草稿', (tester) async {
      final container = newContainer(
        service: FakeDataService(
          caps: _caps(const {
            'processing_available': true,
            'asr_enabled': true,
            'processor_config_version': 'approved-bundle-v1',
            'summary_enabled': true,
            'queue_limit': 5,
          }),
        ),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.processingTranscribe), findsOneWidget);
      expect(find.text(t.talkRecord.processingSummarize), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_processing_reason')),
        findsNothing,
      );

      await tester.tap(find.text(t.talkRecord.processingSummarize));
      await tester.pumpAndSettle();
      expect(
        container.read(talkRecordDraftProvider).processingMode,
        TalkRecordProcessingMode.summarize,
      );
    });

    testWidgets('真实时长上限如实展示（不硬编码时长）', (tester) async {
      final container = newContainer(
        service: FakeDataService(
          caps: _caps(const {
            'asr_enabled': false,
            'max_duration_ms': 7_200_000,
          }),
        ),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();
      expect(
        find.text(t.talkRecord.maxDurationHint(minutes: 120)),
        findsOneWidget,
      );
    });
  });

  group('企业协作信息折叠区', () {
    testWidgets('个人上下文不显示协作区', (tester) async {
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
      );
      await pumpPrepare(
        tester,
        container,
        entryContext: const TalkRecordEntryContext.personal(),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.talkRecord.collabSectionTitle), findsNothing);
    });

    testWidgets('企业上下文折叠→展开：默认目录不可用如实提示，不猜候选', (tester) async {
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.collabSectionTitle), findsOneWidget);
      expect(find.text(t.talkRecord.collabParticipantsLabel), findsNothing);

      await tester.tap(find.text(t.talkRecord.collabSectionTitle));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('talk_record_participants_unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('注入目录后可勾选参与者并写入草稿', (tester) async {
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
        directory: FakeDirectory(const [
          TalkRecordParticipantOption(userId: '9001', displayName: '张三'),
        ]),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.talkRecord.collabSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('talk_record_participants_choose')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('张三'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonAccomplish));
      await tester.pumpAndSettle();

      expect(
        container.read(talkRecordDraftProvider).participants,
        hasLength(1),
      );
      expect(
        find.text(t.talkRecord.collabParticipantsCount(count: 1)),
        findsWidgets,
      );
    });
  });

  group('已告知确认与开始门控', () {
    testWidgets('确认行触达区 ≥67pt；未确认时开始不触权限', (tester) async {
      final mic = FakeMicGateway();
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
        mic: mic,
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      final noticeRow = find.byKey(const ValueKey('talk_record_notice_row'));
      expect(tester.getSize(noticeRow).height, greaterThanOrEqualTo(67));

      await tester.tap(
        find.byKey(const ValueKey('talk_record_start_button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(mic.requestCount, 0);
      expect(find.text(t.talkRecord.noticeHint), findsOneWidget);

      await tester.tap(noticeRow);
      await tester.pumpAndSettle();
      expect(find.text(t.talkRecord.noticeHint), findsNothing);
    });

    testWidgets('点击文字标签同样切换确认（整行触达）', (tester) async {
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.talkRecord.noticeCheckbox));
      await tester.pumpAndSettle();
      expect(container.read(talkRecordDraftProvider).noticeAcknowledged, true);
    });
  });

  group('麦克风权限拒绝态（注入状态，不请求权限）', () {
    testWidgets('拒绝 → 说明 + 重试/去设置；重试与去设置走网关', (tester) async {
      final mic = FakeMicGateway();
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
        mic: mic,
        launcher: FakeLauncher(),
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('talk_record_notice_row')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_start_button')),
      );
      await tester.tap(find.byKey(const ValueKey('talk_record_start_button')));
      await tester.pumpAndSettle();

      expect(mic.requestCount, 1);
      expect(
        find.byKey(const ValueKey('talk_record_mic_denied_panel')),
        findsOneWidget,
      );
      expect(find.text(t.talkRecord.micDeniedMessage), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_mic_settings')),
      );
      await tester.tap(find.byKey(const ValueKey('talk_record_mic_settings')));
      await tester.pumpAndSettle();
      expect(mic.settingsCount, 1);

      mic.status = TalkRecordMicPermissionStatus.granted;
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_mic_retry')),
      );
      await tester.tap(find.byKey(const ValueKey('talk_record_mic_retry')));
      await tester.pumpAndSettle();
      expect(mic.requestCount, 2);
      expect(
        find.byKey(const ValueKey('talk_record_mic_denied_panel')),
        findsNothing,
      );
    });

    testWidgets('授权后调用启动器并携带草稿；占位启动如实提示未开始', (tester) async {
      final mic = FakeMicGateway(TalkRecordMicPermissionStatus.granted);
      final launcher = FakeLauncher();
      final container = newContainer(
        service: FakeDataService(caps: _caps(const {'asr_enabled': false})),
        mic: mic,
        launcher: launcher,
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('talk_record_title_field')),
        '需求评审',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('talk_record_notice_row')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_start_button')),
      );
      await tester.tap(find.byKey(const ValueKey('talk_record_start_button')));
      await tester.pumpAndSettle();

      expect(launcher.lastRequest, isNotNull);
      expect(launcher.lastRequest!.title, '需求评审');
      expect(launcher.lastRequest!.saveTo.organizationId, '7001');
      expect(
        launcher.lastRequest!.processingMode,
        TalkRecordProcessingMode.recordOnly,
      );
      expect(
        find.byKey(const ValueKey('talk_record_recording_unavailable_panel')),
        findsOneWidget,
      );
    });
  });

  group('导航不丢稿（准备 ↔ 保存位置，真实 GoRouter + 共享容器）', () {
    testWidgets('跳保存位置→确认更改→回来：标题保留、跨归属参与者清空', (tester) async {
      final container = newContainer(
        service: FakeDataService(
          caps: _caps(const {'asr_enabled': false}),
          contexts: kContexts,
        ),
        directory: FakeDirectory(const [
          TalkRecordParticipantOption(userId: '9001', displayName: '张三'),
        ]),
      );
      final router = GoRouter(
        initialLocation: kOrgPreparePath,
        routes: talkRecordRoutes(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 1) 准备页（企业入口）：填标题、勾参与者。
      await tester.enterText(
        find.byKey(const ValueKey('talk_record_title_field')),
        '客户访谈',
      );
      await tester.pump();
      await tester.tap(find.text(t.talkRecord.collabSectionTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_participants_choose')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('张三'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonAccomplish));
      await tester.pumpAndSettle();
      expect(
        container.read(talkRecordDraftProvider).participants,
        hasLength(1),
      );

      // 2) 进保存位置。
      await tester.tap(find.text(t.talkRecord.saveToChangeAction));
      await tester.pumpAndSettle();
      expect(router.state.path, kTalkRecordSaveLocationPath);

      // 个人/企业分组与工作区子行渲染；工作区仅出现在企业分组下。
      // （覆盖路由仍在树上：用 descendant 限定保存位置页内匹配。）
      final locationPage = find.byType(TalkRecordSaveLocationPage);
      expect(
        find.descendant(
          of: locationPage,
          matching: find.text(t.talkRecord.saveLocationPersonalSection),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: locationPage, matching: find.text('甲企业')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: locationPage, matching: find.text('主工作区')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: locationPage,
          matching: find.text(t.talkRecord.contextPersonal),
        ),
        findsOneWidget,
      );

      // 3) 变更确认：目标/保留/清空/重校验说明齐全。
      await tester.tap(
        find.descendant(
          of: locationPage,
          matching: find.text(t.talkRecord.contextPersonal),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.talkRecord.changeConfirmTitle), findsOneWidget);
      expect(find.text(t.talkRecord.changeConfirmKeepTitle), findsOneWidget);
      expect(
        find.text(t.talkRecord.changeConfirmClearParticipants),
        findsOneWidget,
      );
      expect(find.text(t.talkRecord.changeConfirmRecheck), findsOneWidget);

      // 4) 确认更改：回准备页，标题保留、保存到变个人、参与者清空。
      await tester.tap(
        find.byKey(const ValueKey('talk_record_change_confirm')),
      );
      await tester.pumpAndSettle();
      expect(router.state.path, kTalkRecordPreparePath);

      final draft = container.read(talkRecordDraftProvider);
      expect(draft.title, '客户访谈');
      expect(draft.saveTo?.isOrganization, false);
      expect(draft.participants, isEmpty);
      expect(find.text(t.talkRecord.collabSectionTitle), findsNothing);
    });

    testWidgets('点当前选择不弹确认直接返回', (tester) async {
      final container = newContainer(
        service: FakeDataService(
          caps: _caps(const {'asr_enabled': false}),
          contexts: kContexts,
        ),
      );
      final router = GoRouter(
        initialLocation: kOrgPreparePath,
        routes: talkRecordRoutes(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.talkRecord.saveToChangeAction));
      await tester.pumpAndSettle();

      // 当前选择 = 企业根行（甲企业，仅保存位置页内命中）。
      await tester.tap(
        find.descendant(
          of: find.byType(TalkRecordSaveLocationPage),
          matching: find.text('甲企业'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.talkRecord.changeConfirmTitle), findsNothing);
      expect(router.state.path, kTalkRecordPreparePath);
    });

    testWidgets('保存位置加载失败 → 失败态 + 重试（不吞成空列表）', (tester) async {
      final container = newContainer(
        service: FakeDataService(
          caps: _caps(const {'asr_enabled': false}),
          contexts: kContexts,
        )..forceContextsError = true,
      );
      final router = GoRouter(
        initialLocation: kTalkRecordSaveLocationPath,
        routes: talkRecordRoutes(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(t.talkRecord.loadFailedTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_locations_retry')),
        findsOneWidget,
      );
    });
  });
  Future<void> pressStart(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container
        .read(talkRecordDraftProvider.notifier)
        .setNoticeAcknowledged(true);
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('talk_record_start_button')),
    );
    await tester.tap(find.byKey(const ValueKey('talk_record_start_button')));
    await tester.pumpAndSettle();
  }

  for (final status in [
    TalkRecordNotificationPermissionStatus.denied,
    TalkRecordNotificationPermissionStatus.restricted,
  ]) {
    testWidgets(
      'notification $status is explicit and settings return never auto starts',
      (tester) async {
        final notifications = FakeNotificationGateway(status: status);
        final launcher = FakeLauncher(startSucceeds: true);
        final container = newContainer(
          service: FakeDataService(),
          mic: FakeMicGateway(TalkRecordMicPermissionStatus.granted),
          notifications: notifications,
          launcher: launcher,
        );
        await pumpPrepare(tester, container);
        await tester.pumpAndSettle();
        expect(notifications.requests, 0);
        await pressStart(tester, container);
        expect(notifications.requests, 1);
        expect(notifications.settings, 0);
        expect(launcher.lastRequest, isNull);
        expect(
          find.text(t.talkRecord.notificationRequiredTitle),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('talk_record_notification_settings')),
        );
        await tester.tap(
          find.byKey(const ValueKey('talk_record_notification_settings')),
        );
        await tester.pumpAndSettle();
        expect(notifications.settings, 1);
        expect(notifications.requests, 1);
        expect(launcher.lastRequest, isNull);
        notifications.status = TalkRecordNotificationPermissionStatus.granted;
        await tester.ensureVisible(
          find.byKey(const ValueKey('talk_record_notification_retry')),
        );
        await tester.tap(
          find.byKey(const ValueKey('talk_record_notification_retry')),
        );
        await tester.pumpAndSettle();
        expect(notifications.requests, 2);
        expect(launcher.lastRequest, isNotNull);
        expect(
          find.byKey(const ValueKey('talk_record_notification_denied_panel')),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'native notifications disabled shows dedicated recovery, not generic failure',
    (tester) async {
      final notifications = FakeNotificationGateway(
        status: TalkRecordNotificationPermissionStatus.granted,
      );
      final launcher = FakeLauncher()..notificationFailure = true;
      final container = newContainer(
        service: FakeDataService(),
        mic: FakeMicGateway(TalkRecordMicPermissionStatus.granted),
        notifications: notifications,
        launcher: launcher,
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();
      await pressStart(tester, container);
      expect(
        find.byKey(const ValueKey('talk_record_notification_denied_panel')),
        findsOneWidget,
      );
      expect(find.text(t.talkRecord.recordingUnavailableTitle), findsNothing);
      expect(container.read(talkRecordDraftProvider).noticeAcknowledged, true);
    },
  );

  testWidgets('non Android skips notification permission entirely', (
    tester,
  ) async {
    final notifications = FakeNotificationGateway(required: false);
    final launcher = FakeLauncher(startSucceeds: true);
    final container = newContainer(
      service: FakeDataService(),
      mic: FakeMicGateway(TalkRecordMicPermissionStatus.granted),
      notifications: notifications,
      launcher: launcher,
    );
    await pumpPrepare(tester, container);
    await tester.pumpAndSettle();
    await pressStart(tester, container);
    expect(notifications.requests, 0);
    expect(launcher.lastRequest, isNotNull);
  });

  testWidgets(
    'same uid auth transition while notification request waits never launches',
    (tester) async {
      final notifications = FakeNotificationGateway()
        ..pending = Completer<TalkRecordNotificationPermissionStatus>();
      final launcher = FakeLauncher(startSucceeds: true);
      final listeners = <void Function()>[];
      final container = newContainer(
        service: FakeDataService(),
        mic: FakeMicGateway(TalkRecordMicPermissionStatus.granted),
        notifications: notifications,
        launcher: launcher,
        authSubscribe: (changed) {
          listeners.add(changed);
          return () => listeners.remove(changed);
        },
      );
      await pumpPrepare(tester, container);
      await tester.pumpAndSettle();
      container
          .read(talkRecordDraftProvider.notifier)
          .setNoticeAcknowledged(true);
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_start_button')),
      );
      await tester.tap(find.byKey(const ValueKey('talk_record_start_button')));
      await tester.pump();
      for (final listener in List.of(listeners)) {
        listener();
      }
      notifications.pending!.complete(
        TalkRecordNotificationPermissionStatus.granted,
      );
      await tester.pumpAndSettle();
      expect(launcher.lastRequest, isNull);
    },
  );
}
