part of 'enterprise_shell_page_test.dart';

// Shared synthetic fixtures for enterprise shell navigation and role tests.

class _Shell extends WorkspaceShellNotifier {
  @override
  Future<void> initialize() async {}
  void empty(String mode) => state = WorkspaceShellState(
    organizationId: '10',
    isLoading: mode == 'loading',
    error: mode == 'error' ? 'synthetic workspace failure' : null,
  );
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
  void organization(String id, {String? workspaceId}) => state = state.copyWith(
    organizationId: id,
    currentWorkspaceId: workspaceId ?? '${id}0',
    workspaces: [
      WorkspaceModel(
        id: workspaceId ?? '${id}0',
        name: '合成企业 $id',
        ownerId: '1',
        organizationId: id,
      ),
    ],
  );

  void useNonOwnerWorkspace() => state = state.copyWith(
    workspaces: const [
      WorkspaceModel(
        id: '100',
        name: '合成企业',
        ownerId: '2',
        organizationId: '10',
      ),
    ],
  );
}

class _Api extends WorkspaceApi {
  @override
  Future<List<GroupModel>> memberGroups(EntityId workspaceId) async => [];
  @override
  Future<Map<String, dynamic>> attachments(
    EntityId workspaceId,
    Map<String, dynamic> filters,
  ) async => {
    'workspace_id': workspaceId,
    'next_cursor': null,
    'items': [
      {
        'id': 991,
        'name': 'enterprise-report.pdf',
        'size': 100,
        'scope': 'group',
        'scope_ref': '200',
        'source_name': 'test group',
        'creator_name': 'test uploader',
        'created_at': '2026-10-08T03:00:00Z',
      },
    ],
  };
  @override
  Future<List<WorkspaceConversationModel>> conversations(
    EntityId workspaceId,
  ) async => [];
  @override
  Future<List<ChannelModel>> channels(
    EntityId workspaceId, {
    String? status,
  }) async => [];
}

class _OrgApi extends OrganizationApi {
  _OrgApi(this.role);
  final String role;
  @override
  Future<Organization> detail(EntityId orgId) async {
    if (role == 'error') throw StateError('synthetic role failure');
    return Organization(id: orgId, name: '合成企业资料', memberRole: role);
  }

  /// 壳级抽屉的空间区从 membership 真源渲染企业行。
  @override
  Future<List<Organization>> allMine() async => [
    Organization(id: '10', name: '合成企业', memberRole: role),
  ];
}

class _DirectoryTransport implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final path = options.uri.path;
    final departments = path.endsWith('/directory/departments');
    final payload = <String, dynamic>{
      'organization_id': 10,
      'list': departments
          ? [
              {'id': 21, 'name': '合成研发部', 'member_count': 0},
            ]
          : <Map<String, dynamic>>[],
      'cursor': null,
      'has_more': false,
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'msg': 'success', 'payload': payload}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _OaApi extends OaWorkbenchApi {
  final calls = <String>[];
  // initState watch + postFrame invalidate 会双触发请求：按队列缓存
  // completer，completeFirst 消费最早一个（键控单 completer 会被二次
  // complete 打爆）。
  final pending = <String, List<Completer<List<EnterpriseOaRuntimeConfig>>>>{};
  @override
  Future<List<EnterpriseOaRuntimeConfig>> entries() {
    calls.add('entries');
    final c = Completer<List<EnterpriseOaRuntimeConfig>>();
    pending.putIfAbsent('entries', () => []).add(c);
    return c.future;
  }

  void completeFirst(List<EnterpriseOaRuntimeConfig> value) {
    pending['entries']!.removeAt(0).complete(value);
  }

  void failFirst(Object error) {
    pending['entries']!.removeAt(0).completeError(error);
  }

  void resetPending() {
    pending['entries'] = [];
  }
}

List<EnterpriseOaRuntimeConfig> _entries(String org) =>
    parseOaWorkbenchEntries({
      'entries': [
        {
          'kind': 'oa',
          'organization_id': int.parse(org),
          'application_key': 'synthetic-oa-key',
          'label': '合成办公 $org',
          'redirect_uri': 'https://oa.example.com/$org',
        },
      ],
    });

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _OaApi api, {
  Size size = const Size(430, 900),
  String? emptyMode,
  List<GroupModel> groups = const [],
  String orgRole = 'member',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        UserModel(uid: '1', account: 'synthetic-account', nickname: '合成员工'),
      ),
      workspaceShellProvider.overrideWith(_Shell.new),
      workspaceApiProvider.overrideWithValue(_Api()),
      organizationApiProvider.overrideWithValue(_OrgApi(orgRole)),
      workspaceGroupsProvider('100').overrideWith((ref) async => groups),
      oaWorkbenchApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  if (emptyMode != null) {
    (container.read(workspaceShellProvider.notifier) as _Shell).empty(
      emptyMode,
    );
  }
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: emptyMode == null
              ? const WorkspaceShellPage()
              : const WorkspaceShellBootstrap(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}
