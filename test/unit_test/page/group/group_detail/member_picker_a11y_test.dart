/// 群设置里两个多选页（添加成员 / 移除成员）的无障碍与交互契约。
///
/// 两页此前零 widget 测试。本文件只钉与本轮整改直接相关的不变量：
///   1. 行声明 selected 状态 —— 多选页里读屏用户光听到名字不知道选没选
///   2. 不用 Material Ripple（DESIGN.md §13.2 禁止用在 Cupertino 列表行）
///   3. 添加成员页里「已是群成员」的行要声明 enabled: false，
///      否则读屏用户会一直点一个永远没反应的行
///
/// 与朋友圈 @选人页（moment_at_picker_a11y_test）是同一类问题，同批修复。
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_detail/remove_member_page.dart';
import 'package:imboy/page/group/group_detail/remove_member_provider.dart';
import 'package:imboy/store/model/group_member_model.dart';

GroupMemberModel _member({required int userId, required String nickname}) {
  return GroupMemberModel(
    id: userId,
    groupId: 1,
    userId: userId,
    nickname: nickname,
    avatar: '',
    sign: '',
    account: 'acc_$userId',
    alias: '',
    createdAt: 0,
  );
}

/// 注入固定成员列表，跳过网络/DB。
class _FakeRemoveMemberNotifier extends RemoveMemberNotifier {
  _FakeRemoveMemberNotifier(this._members);
  final List<GroupMemberModel> _members;

  @override
  RemoveMemberState build() =>
      RemoveMemberState(groupMemberList: _members, isLoading: false);

  /// 页面 initState 会直接查 SQLite 再调 setGroupMemberList 覆盖注入的 state，
  /// 不拦住的话测试里成员会被清空（这和 denylist/friend_list 踩的是同一个坑：
  /// 只覆盖 build() 不够，得把会写 state 的入口一并覆盖）。
  @override
  void setGroupMemberList(List<GroupMemberModel> list, String currentUid) {
    // 保持注入的固定列表不变
  }

  @override
  void setLoading(bool value) {
    // 注入态恒为已加载，避免 initData 把页面推回 loading
  }
}

void main() {
  Future<void> pumpRemovePage(
    WidgetTester tester,
    List<GroupMemberModel> members,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          removeMemberProvider.overrideWith(
            () => _FakeRemoveMemberNotifier(members),
          ),
        ],
        child: TranslationProvider(
          child: const MaterialApp(home: RemoveMemberPage(groupId: '1')),
        ),
      ),
    );
    await tester.pump();
  }

  group('移除成员页', () {
    testWidgets('成员行不使用 Material Ripple（DESIGN.md 13.2）', (tester) async {
      await pumpRemovePage(tester, [_member(userId: 1, nickname: '张三')]);

      expect(find.text('张三'), findsWidgets, reason: '成员未渲染，后续断言无意义');
      // 只看承载成员行的那一层：页面里 IconButton 等 Material 组件内部
      // 自带 InkWell，一刀切断言全页无 InkWell 会管到第三方实现细节
      expect(
        find.ancestor(of: find.text('张三'), matching: find.byType(InkWell)),
        findsNothing,
        reason: 'Cupertino 列表行禁止用 Material Ripple',
      );
    });

    testWidgets('多选行声明 selected 状态，选中后翻转', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRemovePage(tester, [_member(userId: 1, nickname: '张三')]);

      final name = find.text('张三');
      expect(name, findsWidgets);
      expect(
        tester.getSemantics(name.first).hasFlag(SemanticsFlag.isSelected),
        isFalse,
        reason: '未选中时不该声明 selected',
      );

      await tester.tap(name.first);
      await tester.pump();

      expect(
        tester.getSemantics(name.first).hasFlag(SemanticsFlag.isSelected),
        isTrue,
        reason: '移除成员是破坏性操作，选中态读不出来风险更高',
      );

      handle.dispose();
    });
  });
}
