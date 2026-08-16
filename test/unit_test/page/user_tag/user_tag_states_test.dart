import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_provider.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_provider.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_provider.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_provider.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/select_tag_friend_page.dart';
import 'package:imboy/store/model/contact_model.dart';

/// user_tag 各 provider 的不可变 State copyWith 纯逻辑单测。
///
/// Notifier 网络/SQLite 方法依赖 UserTagRepo()/ContactRepo() 直接 new SQLite
/// + UserRepoLocal.to GetX 单例，不可 ProviderScope override，故仅覆盖纯内存 State。
void main() {
  group('UserTagSaveState', () {
    test('SV-1 默认值', () {
      const s = UserTagSaveState();
      expect(s.text, '');
      expect(s.valueChanged, false);
      expect(s.isLoading, false);
    });

    test('SV-2 copyWith 选择性覆盖且不可变', () {
      const s = UserTagSaveState();
      final s2 = s.copyWith(text: 'vip', valueChanged: true);
      expect(s2.text, 'vip');
      expect(s2.valueChanged, true);
      expect(s2.isLoading, false);
      // 原对象不变
      expect(s.text, '');
      expect(s.valueChanged, false);
    });

    test('SV-3 copyWith 不传参保留原值', () {
      const s = UserTagSaveState(
        text: 'a',
        valueChanged: true,
        isLoading: true,
      );
      final s2 = s.copyWith();
      expect(s2.text, 'a');
      expect(s2.valueChanged, true);
      expect(s2.isLoading, true);
    });
  });

  group('SelectFriendPage.isRowSelected', () {
    test('SF-1 未勾选任何好友返回 false', () {
      final model = ContactModel(peerId: 1, nickname: 'Alice');
      expect(SelectFriendPage.isRowSelected(model, []), false);
    });

    test('SF-2 进页已在标签内默认选中', () {
      final model = ContactModel(peerId: 1, nickname: 'Alice');
      // 进页时 selectedContact 初始化自标签成员（_loadData L51）
      expect(SelectFriendPage.isRowSelected(model, [model]), true);
    });

    test('SF-3 本次会话勾选后返回 true（BUG#132 回归）', () {
      final model = ContactModel(peerId: 1, nickname: 'Alice');
      final other = ContactModel(peerId: 2, nickname: 'Bob');
      expect(SelectFriendPage.isRowSelected(model, [other, model]), true);
    });

    test('SF-4 取消勾选后返回 false（BUG#132 回归：进页已选被取消）', () {
      final model = ContactModel(peerId: 1, nickname: 'Alice');
      // 进页已选（初始在 selectedContact），会话内被 removeWhere 移除
      expect(SelectFriendPage.isRowSelected(model, []), false);
    });
  });

  group('ContactTagDetailNotifier.handleList 空 title', () {
    test('CD-H1 空 title 归入 # 组不崩溃', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(contactTagDetailProvider.notifier);
      final list = [
        ContactModel(peerId: 1, nickname: 'Alice'),
        ContactModel(peerId: 2, nickname: ''),
      ];
      // 回归：getPinyinE('') 返回空串，修复前 substring(0,1) 抛 RangeError
      // 导致整页渲染空列表（真机实测 select_tag_friend_page.dart）。
      notifier.handleList(list);
      expect(list[0].nameIndex, 'A');
      expect(list[1].nameIndex, '#');
      expect(
        container.read(contactTagDetailProvider).currIndexBarData,
        contains('#'),
      );
    });
  });

  group('ContactTagDetailState', () {
    test('CD-1 默认值', () {
      const s = ContactTagDetailState();
      expect(s.tagName, '');
      expect(s.refererTime, 0);
      expect(s.contactList, isEmpty);
      expect(s.currIndexBarData, isEmpty);
      expect(s.page, 1);
      expect(s.size, 10);
      expect(s.kwd, '');
      expect(s.isLoading, false);
    });

    test('CD-2 copyWith 覆盖分页/关键词且不可变', () {
      const s = ContactTagDetailState();
      final s2 = s.copyWith(page: 3, kwd: 'tom', tagName: '同学');
      expect(s2.page, 3);
      expect(s2.kwd, 'tom');
      expect(s2.tagName, '同学');
      expect(s2.size, 10);
      // 原对象不变
      expect(s.page, 1);
      expect(s.kwd, '');
    });

    test('CD-3 copyWith 不传参保留原值', () {
      const s = ContactTagDetailState(
        tagName: '家人',
        refererTime: 100,
        page: 2,
        isLoading: true,
      );
      final s2 = s.copyWith();
      expect(s2.tagName, '家人');
      expect(s2.refererTime, 100);
      expect(s2.page, 2);
      expect(s2.isLoading, true);
    });
  });

  group('ContactTagListState', () {
    test('CL-1 默认值', () {
      const s = ContactTagListState();
      expect(s.items, isEmpty);
      expect(s.page, 1);
      expect(s.size, 10);
      expect(s.kwd, '');
      expect(s.isLoading, false);
    });

    test('CL-2 copyWith 覆盖分页且不可变', () {
      const s = ContactTagListState();
      final s2 = s.copyWith(page: 5, kwd: 'k', isLoading: true);
      expect(s2.page, 5);
      expect(s2.kwd, 'k');
      expect(s2.isLoading, true);
      expect(s.page, 1);
      expect(s.isLoading, false);
    });

    test('CL-3 copyWith 不传参保留原值', () {
      const s = ContactTagListState(page: 4, size: 20, kwd: 'x');
      final s2 = s.copyWith();
      expect(s2.page, 4);
      expect(s2.size, 20);
      expect(s2.kwd, 'x');
    });
  });

  group('UserTagRelationState', () {
    test('UR-1 默认值', () {
      const s = UserTagRelationState();
      expect(s.tagItems, isEmpty);
      expect(s.recentTagItems, isEmpty);
      expect(s.tagUsageCount, isEmpty);
      expect(s.useAdvancedMode, true);
      expect(s.searchQuery, '');
      expect(s.isEditMode, false);
      expect(s.hasChanges, false);
      expect(s.isLoading, false);
      expect(s.inputTimer, isNull);
      expect(s.lastInputTag, '');
    });

    test('UR-2 copyWith 覆盖标签列表/编辑态且不可变', () {
      const s = UserTagRelationState();
      final s2 = s.copyWith(
        tagItems: ['a', 'b'],
        hasChanges: true,
        searchQuery: 'q',
      );
      expect(s2.tagItems, ['a', 'b']);
      expect(s2.hasChanges, true);
      expect(s2.searchQuery, 'q');
      expect(s2.useAdvancedMode, true);
      // 原对象不变
      expect(s.tagItems, isEmpty);
      expect(s.hasChanges, false);
    });

    test('UR-3 copyWith 不传参保留原值', () {
      const s = UserTagRelationState(
        tagItems: ['x'],
        isEditMode: true,
        useAdvancedMode: false,
        lastInputTag: 'last',
      );
      final s2 = s.copyWith();
      expect(s2.tagItems, ['x']);
      expect(s2.isEditMode, true);
      expect(s2.useAdvancedMode, false);
      expect(s2.lastInputTag, 'last');
    });
  });
}
