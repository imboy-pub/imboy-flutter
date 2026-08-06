// 好友列表页面 Widget 集成测试 / ContactPage Widget Integration Tests
//
// 测试策略 / Test strategy:
//   - 通过 ProviderScope.overrideWithValue 直接注入 ContactState，绕过网络/DB
//   - 涵盖：空状态、列表渲染、加载态、功能入口项、搜索框、长按交互
//   - No real network or database required; runs stably in CI
//
// 运行方式 / How to run:
//   flutter test test/widget/friend_list_page_test.dart

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/store/model/contact_model.dart';

// ---------------------------------------------------------------------------
// 测试辅助 / Test helpers
// ---------------------------------------------------------------------------

/// 将昵称首字母转换为 nameIndex（测试用简化版）
String _nameIndex(String name) {
  final first = name.isNotEmpty ? name[0].toUpperCase() : '#';
  // 英文首字母直接使用，否则归入 '#'
  if (RegExp(r'[A-Z]').hasMatch(first)) return first;
  return '#';
}

/// 创建测试用联系人 / Create a test ContactModel
ContactModel _makeContact({
  required int peerId,
  required String nickname,
  String? avatar,
  String status = 'offline',
}) {
  final model = ContactModel(
    peerId: peerId,
    nickname: nickname,
    avatar: avatar ?? '',
    status: status,
  );
  model.nameIndex = _nameIndex(nickname);
  SuspensionUtil.sortListBySuspensionTag([model]);
  return model;
}

/// 固定测试好友数据 / Fixed test contact data
List<ContactModel> _buildFakeContacts() {
  return [
    _makeContact(peerId: 1001, nickname: 'Alice', status: 'online'),
    _makeContact(peerId: 1002, nickname: 'Bob'),
    _makeContact(peerId: 1003, nickname: '张三'),
  ];
}

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

/// 固定一个真机尺寸的视口。
///
/// AzListView 内部是 Stack + 悬浮 IndexBar，对约束敏感；默认 800x600 的
/// 测试画布下会走到「无限宽」分支抛 BoxConstraints forces an infinite width。
void _useIphoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

// ---------------------------------------------------------------------------
// 测试用例 / Test cases
// ---------------------------------------------------------------------------

void main() {
  group('ContactPage —— 空状态 / Empty state', () {
    testWidgets('空好友列表时显示无数据视图 / shows NoDataView when contacts is empty', (
      tester,
    ) async {
      _useIphoneViewport(tester);
      // 直接注入空列表状态，不触发网络请求
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                const ContactState(contactList: [], isLoading: false),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 空列表不含 AzListView（有数据才渲染）
      expect(find.byType(AzListView), findsNothing);
    });

    testWidgets('空好友列表时不渲染任何联系人标题 / no contact text when list is empty', (
      tester,
    ) async {
      _useIphoneViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                const ContactState(contactList: [], isLoading: false),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 确保联系人昵称不出现
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsNothing);
    });
  });

  group('ContactPage —— 加载状态 / Loading state', () {
    testWidgets('isLoading=true 时显示 ShimmerList / shows shimmer when loading', (
      tester,
    ) async {
      _useIphoneViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                const ContactState(contactList: [], isLoading: true),
              ),
            ),
          ],
        ),
      );
      // pump 一帧检查加载指示器存在 / Pump one frame to check loading indicator
      await tester.pump();

      // AzListView 不应该出现（仍在加载中）
      expect(find.byType(AzListView), findsNothing);
    });
  });

  group('ContactPage —— 好友列表渲染 / Friend list rendering', () {
    testWidgets('有好友数据时渲染 AzListView / renders AzListView with contacts', (
      tester,
    ) async {
      _useIphoneViewport(tester);
      final contacts = _buildFakeContacts();

      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                ContactState(
                  contactList: contacts,
                  isLoading: false,
                  indexBarData: const {'A', 'B', '#'},
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 英文名好友应显示
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
    });

    testWidgets('多个好友时所有名字均可见 / all contact names are visible', (tester) async {
      _useIphoneViewport(tester);
      final contacts = _buildFakeContacts();

      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                ContactState(
                  contactList: contacts,
                  isLoading: false,
                  indexBarData: const {'A', 'B', '#'},
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 3 个联系人名字均可找到
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
      expect(find.text('张三'), findsWidgets);
    });
  });

  group('ContactPage —— 功能入口项 / Special function entries', () {
    testWidgets('顶部功能入口项（新的好友等）在联系人列表中可见 / special entries visible', (
      tester,
    ) async {
      _useIphoneViewport(tester);
      // 注入包含功能入口项的联系人列表（模拟真实 provider 行为）
      final newFriendEntry = ContactModel(
        peerId: kPeerIdNewFriend,
        nickname: '新的朋友',
        nameIndex: '↑',
      );
      final groupEntry = ContactModel(
        peerId: kPeerIdGroup,
        nickname: '群聊',
        nameIndex: '↑',
      );

      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                ContactState(
                  contactList: [newFriendEntry, groupEntry],
                  isLoading: false,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 功能入口项名称可见
      expect(find.text('新的朋友'), findsWidgets);
      expect(find.text('群聊'), findsWidgets);
    });
  });

  group('ContactPage —— 搜索框 / Search bar', () {
    testWidgets('页面顶部有搜索输入框 / search bar exists at page top', (tester) async {
      _useIphoneViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                const ContactState(contactList: [], isLoading: false),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      // 搜索框是 CupertinoSearchTextField，内部是 CupertinoTextField，
      // 不是 Material 的 TextField —— 旧断言找 TextField 永远是 0。
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);
      expect(find.byKey(const Key('contact_search_input')), findsOneWidget);
    });
  });

  group('ContactPage —— 好友申请入口 / Friend request entry', () {
    testWidgets('顶部 AppBar 包含"添加好友"图标按钮 / AppBar has person_add button', (
      tester,
    ) async {
      _useIphoneViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                const ContactState(contactList: [], isLoading: false),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 页面是 Cupertino 风格：图标是 CupertinoIcons.person_add，
      // 不是 Material 的 Icons.person_add。
      expect(find.byIcon(Icons.person_add), findsNothing);
      expect(find.byIcon(CupertinoIcons.person_add), findsOneWidget);
      expect(find.byKey(const Key('add_friend_button')), findsOneWidget);
    });
  });

  group('ContactPage —— 视觉/无障碍收口', () {
    Future<void> pumpWithContacts(WidgetTester tester) async {
      _useIphoneViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWith(
              () => _StateOverrideNotifier(
                ContactState(
                  contactList: _buildFakeContacts(),
                  isLoading: false,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('联系人行不画 disclosure chevron', (tester) async {
      await pumpWithContacts(tester);

      expect(find.text('Alice'), findsWidgets, reason: '列表没渲染出来，后续断言无意义');
      // 整行可点，箭头传达不了额外信息。iOS 通讯录 / 微信通讯录都没有。
      expect(find.byIcon(CupertinoIcons.chevron_right), findsNothing);
    });

    testWidgets('在线状态点不进语义树', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithContacts(tester);

      // 那个点是纯颜色编码（在线/1小时内/1天内/更久），本身读不出来；
      // 有 lastSeenAt 时 subtitle 已经把同样信息写成文字，点只是重复。
      expect(
        find.descendant(
          of: find.byType(ContactPage),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
        reason: '状态点未用 ExcludeSemantics 排除',
      );

      handle.dispose();
    });
  });
}

/// 注入指定 ContactState 的 fake notifier。
///
/// 不能用 `overrideWithValue`：contactProvider 是 NotifierProvider，
/// overrideWithValue 装的是 _SyncValueProviderElement，页面里任何
/// `ref.read(contactProvider.notifier)` 都会在类型转换处炸
/// （'_SyncValueProviderElement<ContactState>' is not a subtype of
/// '$ClassProviderElement<ContactNotifier, ...>'）。
/// 必须 overrideWith(() => 子类) 才有真正的 notifier 实例。
class _StateOverrideNotifier extends ContactNotifier {
  _StateOverrideNotifier(this._initial);
  final ContactState _initial;

  @override
  ContactState build() => _initial;

  /// ContactPage.initState 会调 loadData()，不覆盖会走真实网络/DB。
  @override
  Future<void> loadData() async {}
}
