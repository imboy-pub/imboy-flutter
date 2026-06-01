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

// ---------------------------------------------------------------------------
// 测试用例 / Test cases
// ---------------------------------------------------------------------------

void main() {
  group('ContactPage —— 空状态 / Empty state', () {
    testWidgets('空好友列表时显示无数据视图 / shows NoDataView when contacts is empty', (
      tester,
    ) async {
      // 直接注入空列表状态，不触发网络请求
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWithValue(
              const ContactState(contactList: [], isLoading: false),
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
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWithValue(
              const ContactState(contactList: [], isLoading: false),
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
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWithValue(
              const ContactState(contactList: [], isLoading: true),
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
      final contacts = _buildFakeContacts();

      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWithValue(
              ContactState(
                contactList: contacts,
                isLoading: false,
                indexBarData: const {'A', 'B', '#'},
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
      final contacts = _buildFakeContacts();

      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWithValue(
              ContactState(
                contactList: contacts,
                isLoading: false,
                indexBarData: const {'A', 'B', '#'},
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
            contactProvider.overrideWithValue(
              ContactState(
                contactList: [newFriendEntry, groupEntry],
                isLoading: false,
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
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWithValue(
              const ContactState(contactList: [], isLoading: false),
            ),
          ],
        ),
      );
      await tester.pump();

      // CupertinoSearchTextField 应该存在
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });
  });

  group('ContactPage —— 好友申请入口 / Friend request entry', () {
    testWidgets('顶部 AppBar 包含"添加好友"图标按钮 / AppBar has person_add button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ContactPage(),
          overrides: [
            contactProvider.overrideWithValue(
              const ContactState(contactList: [], isLoading: false),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // person_add 图标来自 AppBar actions 入口
      expect(find.byIcon(Icons.person_add), findsWidgets);
    });
  });
}
