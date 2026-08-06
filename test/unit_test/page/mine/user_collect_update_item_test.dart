import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/user_collect/user_collect_state.dart';
import 'package:imboy/store/model/user_collect_model.dart';

/// 真机实测：收藏详情设完备注返回，备注卡片压根不出现。
/// 根因之一是 `updateItem` 用 `state.items.setRange(...)` 就地改同一个 List，
/// state 引用没变 → Riverpod 判定"无变化" → 没有任何监听者收到通知。
/// 这里锁住"必须换新 List 实例"这个契约。
UserCollectModel _m(String kindId, {String remark = ''}) => UserCollectModel(
  userId: 1,
  kind: 1,
  kindId: kindId,
  source: 's',
  remark: remark,
  tag: '',
  updatedAt: 0,
  createdAt: 0,
  info: const {},
);

void main() {
  test('copyWith 换 items 后是新的 State 与新的 List 实例', () {
    final original = [_m("1"), _m("2")];
    final state = UserCollectState()..items = original;

    final next = List<UserCollectModel>.from(state.items);
    next[0] = _m("1", remark: 'note');
    final updated = state.copyWith(items: next);

    // State 换了实例，Riverpod 才会通知
    expect(identical(updated, state), isFalse);
    // List 也换了实例，否则 == 比较仍会判定相等
    expect(identical(updated.items, original), isFalse);
    expect(updated.items[0].remark, 'note');
    // 原 List 不被污染
    expect(original[0].remark, '');
  });
}
