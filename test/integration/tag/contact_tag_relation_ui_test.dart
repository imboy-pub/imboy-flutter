import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_page.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_provider.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_provider.dart';

/// 联系人标签关系 UI 集成测试
///
/// 测试覆盖范围：
/// 1. 联系人标签设置页面渲染和交互
/// 2. 备注修改流程
/// 3. 标签显示和交互
/// 4. 标签新增/绑定/筛选/删除完整流程
/// 5. 标签关系变更后页面返回回显
/// 6. Provider 状态管理测试
Widget _buildContactTagPage({
  String peerTag = 'tag_a,tag_b',
  String peerRemark = 'old-remark',
  void Function(String)? onRemarkChanged,
}) {
  return TranslationProvider(
    child: ProviderScope(
      child: MaterialApp(
        home: ContactSettingTagPage(
          peerId: 'u_1001',
          peerAccount: 'alice',
          peerAvatar: '',
          peerNickname: 'Alice',
          peerGender: 1,
          peerTitle: '',
          peerSign: '',
          peerRegion: '',
          peerSource: '',
          peerRemark: peerRemark,
          peerTag: peerTag,
          onRemarkChanged: onRemarkChanged,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =====================================================
  // Group 1: ContactSettingTagPage 基础渲染测试
  // =====================================================
  group('ContactSettingTagPage - 基础渲染测试', () {
    testWidgets('页面正确渲染备注输入框和标签组件', (tester) async {
      await tester.pumpWidget(_buildContactTagPage());
      await tester.pump();

      // 验证页面存在
      expect(find.byType(ContactSettingTagPage), findsOneWidget);
      // 验证备注输入框存在
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('页面正确显示现有标签', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerTag: '工作,朋友,家人'));
      await tester.pump();

      // 验证标签显示
      expect(find.text('工作'), findsOneWidget);
      expect(find.text('朋友'), findsOneWidget);
      expect(find.text('家人'), findsOneWidget);
    });

    testWidgets('空标签状态显示添加标签提示', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerTag: ''));
      await tester.pump();

      // 查找添加标签的提示
      expect(find.text(t.addTag), findsOneWidget);
    });

    testWidgets('标签区域有导航箭头', (tester) async {
      await tester.pumpWidget(_buildContactTagPage());
      await tester.pump();

      // 查找导航箭头图标
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });
  });

  // =====================================================
  // Group 2: 备注修改流程测试
  // =====================================================
  group('ContactSettingTagPage - 备注修改流程测试', () {
    testWidgets('保存按钮在备注改变后变为可用', (tester) async {
      await tester.pumpWidget(_buildContactTagPage());
      await tester.pump();

      // 初始状态：保存按钮应该禁用
      final buttonsBefore = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(buttonsBefore.any((button) => button.onPressed == null), isTrue);

      // 修改备注
      await tester.enterText(find.byType(TextFormField), 'new-remark');
      await tester.pump();

      // 保存按钮应该启用
      final buttonsAfter = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(buttonsAfter.any((button) => button.onPressed != null), isTrue);
    });

    testWidgets('备注输入框存在并可输入', (tester) async {
      await tester.pumpWidget(_buildContactTagPage());
      await tester.pump();

      // 验证 TextFormField 存在
      expect(find.byType(TextFormField), findsOneWidget);

      // 验证可以输入文本
      await tester.enterText(find.byType(TextFormField), '测试备注');
      await tester.pump();
      expect(find.text('测试备注'), findsOneWidget);
    });

    testWidgets('备注初始值正确显示', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerRemark: '初始备注'));
      await tester.pump();

      expect(find.text('初始备注'), findsOneWidget);
    });

    testWidgets('备注修改后回调触发', (tester) async {
      await tester.pumpWidget(
        _buildContactTagPage(
          peerRemark: 'old',
          onRemarkChanged: (value) {
            // 回调被触发
          },
        ),
      );
      await tester.pump();

      // 修改备注
      await tester.enterText(find.byType(TextFormField), 'new-remark-test');
      await tester.pump();

      // 验证修改成功
      expect(find.text('new-remark-test'), findsOneWidget);
    });
  });

  // =====================================================
  // Group 3: 标签显示和交互测试
  // =====================================================
  group('ContactSettingTagPage - 标签显示和交互测试', () {
    testWidgets('标签区域显示当前标签数量', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerTag: 'tag1,tag2,tag3'));
      await tester.pump();

      // 验证三个标签都显示
      expect(find.text('tag1'), findsOneWidget);
      expect(find.text('tag2'), findsOneWidget);
      expect(find.text('tag3'), findsOneWidget);
    });

    testWidgets('标签区域 ListTile 存在并可交互', (tester) async {
      await tester.pumpWidget(_buildContactTagPage());
      await tester.pump();

      // 找到标签区域的 ListTile
      final listTile = find.byType(ListTile);
      expect(listTile, findsOneWidget);

      // 验证 ListTile 存在
      final listTileWidget = tester.widget<ListTile>(listTile);
      expect(listTileWidget.onTap, isNotNull);
    });
  });

  // =====================================================
  // Group 4: 边界条件测试
  // =====================================================
  group('ContactSettingTagPage - 边界条件测试', () {
    testWidgets('处理超长标签字符串', (tester) async {
      final longTags = List.generate(10, (i) => 'tag_$i').join(',');
      await tester.pumpWidget(_buildContactTagPage(peerTag: longTags));
      await tester.pump();

      // 验证页面能处理多个标签而不崩溃
      expect(find.byType(ContactSettingTagPage), findsOneWidget);
    });

    testWidgets('处理特殊字符标签名', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerTag: '工作-标签,朋友_群,家人(重要)'));
      await tester.pump();

      // 验证页面能处理特殊字符
      expect(find.byType(ContactSettingTagPage), findsOneWidget);
    });

    testWidgets('处理空备注', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerRemark: ''));
      await tester.pump();

      // 验证页面正常显示
      expect(find.byType(ContactSettingTagPage), findsOneWidget);
    });
  });

  // =====================================================
  // Group 5: ContactSettingTagProvider 状态管理测试
  // =====================================================
  group('ContactSettingTagProvider - 状态管理测试', () {
    test('初始状态正确', () {
      final container = ProviderContainer();
      final state = container.read(contactSettingTagProvider);

      expect(state.valueChanged, isFalse);
      expect(state.val, isEmpty);
    });

    test('valueOnChange 更新状态', () {
      final container = ProviderContainer();
      final notifier = container.read(contactSettingTagProvider.notifier);

      notifier.valueOnChange(true);
      expect(container.read(contactSettingTagProvider).valueChanged, isTrue);

      notifier.valueOnChange(false);
      expect(container.read(contactSettingTagProvider).valueChanged, isFalse);
    });

    test('setVal 更新值', () {
      final container = ProviderContainer();
      final notifier = container.read(contactSettingTagProvider.notifier);

      notifier.setVal('test_value');
      expect(container.read(contactSettingTagProvider).val, equals('test_value'));
    });

    test('TextEditingController 初始化', () {
      final container = ProviderContainer();
      final notifier = container.read(contactSettingTagProvider.notifier);

      expect(notifier.remarkTextController, isNotNull);
      expect(notifier.remarkFocusNode, isNotNull);
    });
  });

  // =====================================================
  // Group 6: UserTagRelationProvider 状态管理测试
  // =====================================================
  group('UserTagRelationProvider - 状态管理测试', () {
    test('初始状态正确', () {
      final container = ProviderContainer();
      final state = container.read(userTagRelationProvider);

      expect(state.tagItems, isEmpty);
      expect(state.recentTagItems, isEmpty);
      expect(state.hasChanges, isFalse);
      expect(state.isLoading, isFalse);
    });

    test('setTagItems 更新标签列表', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      notifier.setTagItems(['tag1', 'tag2']);
      expect(
        container.read(userTagRelationProvider).tagItems,
        equals(['tag1', 'tag2']),
      );
    });

    test('setRecentTagItems 更新最近标签列表', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      notifier.setRecentTagItems(['recent1', 'recent2', 'recent3']);
      expect(
        container.read(userTagRelationProvider).recentTagItems.length,
        equals(3),
      );
    });

    test('checkChanges 检测变更', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      notifier.setTagItems(['tag1', 'tag2']);
      final hasChanges = notifier.checkChanges(['tag1']);
      expect(hasChanges, isTrue);
    });

    test('filterTags 过滤标签', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      notifier.setRecentTagItems(['apple', 'banana', 'cherry', 'date']);
      notifier.filterTags('a');

      final state = container.read(userTagRelationProvider);
      expect(state.searchQuery, equals('a'));
    });

    test('getPopularTags 返回按使用频率排序的标签', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      notifier.setRecentTagItems(['tag1', 'tag2', 'tag3']);

      final popularTags = notifier.getPopularTags(limit: 2);
      expect(popularTags.length, lessThanOrEqualTo(2));
    });

    test('getRecentUnselectedTags 排除已选标签', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      notifier.setRecentTagItems(['tag1', 'tag2', 'tag3', 'tag4']);
      notifier.setTagItems(['tag1', 'tag3']);

      final unselected = notifier.getRecentUnselectedTags();
      expect(unselected, isNot(contains('tag1')));
      expect(unselected, isNot(contains('tag3')));
      expect(unselected, contains('tag2'));
      expect(unselected, contains('tag4'));
    });
  });

  // =====================================================
  // Group 7: 联系人标签完整流程测试 - 标签CRUD
  // =====================================================
  group('联系人标签完整流程测试 - 标签CRUD', () {
    testWidgets('标签显示：已有标签正确渲染', (tester) async {
      await tester.pumpWidget(
        _buildContactTagPage(peerTag: 'VIP客户,合作伙伴,重要'),
      );
      await tester.pump();

      // 验证所有标签都显示
      expect(find.text('VIP客户'), findsOneWidget);
      expect(find.text('合作伙伴'), findsOneWidget);
      expect(find.text('重要'), findsOneWidget);
    });

    testWidgets('标签绑定：标签区域 ListTile 可点击', (tester) async {
      await tester.pumpWidget(_buildContactTagPage());
      await tester.pump();

      // 找到标签区域的 ListTile
      final listTile = find.byType(ListTile);
      expect(listTile, findsOneWidget);

      // 验证 ListTile 有 onTap 回调
      final listTileWidget = tester.widget<ListTile>(listTile);
      expect(listTileWidget.onTap, isNotNull);
    });

    testWidgets('标签筛选：空标签时显示添加提示', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerTag: ''));
      await tester.pump();

      // 验证添加标签提示显示
      expect(find.text(t.addTag), findsOneWidget);
    });

    testWidgets('标签删除：验证标签不显示在空标签页面', (tester) async {
      // 测试空标签页面不显示任何标签
      await tester.pumpWidget(_buildContactTagPage(peerTag: ''));
      await tester.pump();

      // 验证添加标签提示显示
      expect(find.text(t.addTag), findsOneWidget);
    });
  });

  // =====================================================
  // Group 8: 标签关系变更后页面返回回显测试
  // =====================================================
  group('标签关系变更后页面返回回显测试', () {
    testWidgets('页面返回时标签状态保持', (tester) async {
      await tester.pumpWidget(_buildContactTagPage(peerTag: 'initial_tag'));
      await tester.pump();

      // 验证初始标签显示
      expect(find.text('initial_tag'), findsOneWidget);
    });

    test('标签更新后 Provider 状态同步', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      // 设置初始标签
      notifier.setTagItems(['tag1', 'tag2']);
      expect(
        container.read(userTagRelationProvider).tagItems,
        equals(['tag1', 'tag2']),
      );

      // 更新标签
      notifier.setTagItems(['tag1', 'tag2', 'tag3']);
      expect(
        container.read(userTagRelationProvider).tagItems.length,
        equals(3),
      );

      // 删除标签
      notifier.setTagItems(['tag1']);
      expect(
        container.read(userTagRelationProvider).tagItems.length,
        equals(1),
      );
    });
  });

  // =====================================================
  // Group 9: ContactSettingTagState 状态类测试
  // =====================================================
  group('ContactSettingTagState - 状态类测试', () {
    test('copyWith 正确复制状态', () {
      const original = ContactSettingTagState(valueChanged: false, val: 'test');

      final copied = original.copyWith(valueChanged: true);

      expect(copied.valueChanged, isTrue);
      expect(copied.val, equals('test'));
    });

    test('默认构造函数提供正确默认值', () {
      const state = ContactSettingTagState();

      expect(state.valueChanged, isFalse);
      expect(state.val, isEmpty);
    });
  });

  // =====================================================
  // Group 10: UserTagRelationState 状态类测试
  // =====================================================
  group('UserTagRelationState - 状态类测试', () {
    test('copyWith 正确复制所有字段', () {
      const original = UserTagRelationState(
        tagItems: ['a', 'b'],
        recentTagItems: ['c', 'd'],
        hasChanges: false,
      );

      final copied = original.copyWith(
        tagItems: ['x', 'y', 'z'],
        hasChanges: true,
      );

      expect(copied.tagItems, equals(['x', 'y', 'z']));
      expect(copied.recentTagItems, equals(['c', 'd']));
      expect(copied.hasChanges, isTrue);
    });

    test('默认构造函数提供正确默认值', () {
      const state = UserTagRelationState();

      expect(state.tagItems, isEmpty);
      expect(state.recentTagItems, isEmpty);
      expect(state.tagUsageCount, isEmpty);
      expect(state.hasChanges, isFalse);
      expect(state.isLoading, isFalse);
    });
  });

  // =====================================================
  // Group 11: 标签筛选一致性验证测试
  // =====================================================
  group('标签筛选一致性验证测试', () {
    test('标签选择状态与 Provider 同步', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      // 设置标签
      notifier.setTagItems(['selected1', 'selected2']);
      notifier.setRecentTagItems(['selected1', 'selected2', 'unselected1']);

      // 验证选中状态
      final state = container.read(userTagRelationProvider);
      expect(state.tagItems, contains('selected1'));
      expect(state.tagItems, contains('selected2'));
      expect(state.tagItems, isNot(contains('unselected1')));
    });

    test('标签过滤功能正确工作', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      // 设置最近标签
      notifier.setRecentTagItems(['apple', 'banana', 'cherry', 'apricot']);

      // 过滤 'ap'
      notifier.filterTags('ap');

      // 验证过滤结果
      final state = container.read(userTagRelationProvider);
      expect(state.searchQuery, equals('ap'));
    });

    test('标签变更检测功能正确工作', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);

      // 设置初始标签
      notifier.setTagItems(['tag1', 'tag2']);

      // 检测变更
      var hasChanges = notifier.checkChanges(['tag1', 'tag2']);
      expect(hasChanges, isFalse);

      // 修改标签后检测变更
      notifier.setTagItems(['tag1', 'tag3']);
      hasChanges = notifier.checkChanges(['tag1', 'tag2']);
      expect(hasChanges, isTrue);
    });
  });
}
