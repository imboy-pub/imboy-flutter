/// Tests for `lib/component/helper/list.dart` `listDiff`.
///
/// 行为契约（与源码注释对齐）：
///   - 任一输入为 null → 返回 true（任何 null 都视为"不同"，特殊语义）
///   - 元素相同但顺序不同 → 视为相同 → 返回 false
///   - 长度不同 → 不同 → true
///   - 同元素重复次数不同（{a,a,b} vs {a,b,b}）→ 当前实现按"对方包含"计数判定相同，
///     不区分多重集；锁定该现实行为以防误改语义。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/list.dart';

void main() {
  group('listDiff null inputs', () {
    test('a=null → true（按约定 null 永远算不同）', () {
      expect(listDiff(null, [1, 2]), isTrue);
    });

    test('b=null → true', () {
      expect(listDiff([1], null), isTrue);
    });

    test('两边都为 null → true（特殊：源码注释明确说"两个 null 也是不相同的"）', () {
      expect(listDiff(null, null), isTrue);
    });
  });

  group('listDiff content equality', () {
    test('完全相同（同序）→ false', () {
      expect(listDiff([1, 2, 3], [1, 2, 3]), isFalse);
    });

    test('元素相同但顺序不同 → false（顺序无关）', () {
      expect(listDiff([1, 2, 3], [3, 1, 2]), isFalse);
    });

    test('长度不同 → true', () {
      expect(listDiff([1, 2], [1, 2, 3]), isTrue);
      expect(listDiff([1, 2, 3], [1, 2]), isTrue);
    });

    test('元素不同 → true', () {
      expect(listDiff([1, 2, 3], [4, 5, 6]), isTrue);
    });

    test('部分重叠 → true', () {
      expect(listDiff([1, 2, 3], [1, 2, 4]), isTrue);
    });

    test('两个空 list → false（同长 + 同内容）', () {
      expect(listDiff([], []), isFalse);
    });

    test('一空一非空 → true', () {
      expect(listDiff([], [1]), isTrue);
    });
  });

  group('listDiff with strings', () {
    test('字符串顺序不同 → false', () {
      expect(listDiff(['a', 'b'], ['b', 'a']), isFalse);
    });

    test('字符串内容不同 → true', () {
      expect(listDiff(['a', 'b'], ['a', 'c']), isTrue);
    });
  });

  group('listDiff multiset edge cases (lock-in current behavior)', () {
    test('{a,a,b} vs {a,b,b}：长度=3、count=3 → false（按实现视为相同）', () {
      // 当前实现：a 中每个元素只看 b 是否包含，不管出现次数；
      // a=[a,a,b]，遍历每项 b.contains 都 true → count=3，长度匹配 → false
      // 这与多重集语义不一致，但锁定真实行为防误改。
      expect(listDiff(['a', 'a', 'b'], ['a', 'b', 'b']), isFalse);
    });
  });
}
