// 联系人页搜索过滤逻辑测试 / ContactPage search filtering logic tests
//
// 注：ContactPage 全量 widget 渲染依赖 AzListView，其 sticky header 在当前
// Flutter/azlistview 组合的 widget 测试环境里会触发 "BoxConstraints forces an
// infinite width"（见既有 test/widget/friend_list_page_test.dart 同根因失败）。
// 故本文件对抽取出的纯函数 filteredContacts / filteredIndexBar 做确定性单测，
// 覆盖搜索过滤契约：匹配、清空恢复、无结果、索引栏一致性。
//
// 运行 / How to run:
//   flutter test test/page/contact/contact_page_search_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/contact/contact/contact_page.dart';
import 'package:imboy/store/model/contact_model.dart';

ContactModel _c(int peerId, String nickname, String nameIndex) {
  final m = ContactModel(peerId: peerId, nickname: nickname);
  m.nameIndex = nameIndex;
  return m;
}

void main() {
  final all = [
    _c(101, 'Alice', 'A'),
    _c(102, 'Bob', 'B'),
    _c(103, 'Alice Smith', 'A'),
  ];
  const stateBar = {'A', 'B'};

  group('filteredContacts', () {
    test('query 空返回全量（同一引用）', () {
      expect(filteredContacts(all, ''), same(all));
    });

    test('输入 alice 仅保留标题匹配项', () {
      final r = filteredContacts(all, 'alice');
      expect(r.length, 2);
      expect(r.map((m) => m.nickname), containsAll(['Alice', 'Alice Smith']));
      expect(r.any((m) => m.nickname == 'Bob'), isFalse);
    });

    test('大小写不敏感', () {
      expect(filteredContacts(all, 'ALICE').length, 2);
      expect(filteredContacts(all, 'bOb').length, 1);
    });

    test('无匹配返回空列表', () {
      expect(filteredContacts(all, 'zzz'), isEmpty);
    });
  });

  group('filteredIndexBar', () {
    test('query 空沿用原始 indexBar（带 ↑ 前缀）', () {
      final bar = filteredIndexBar(all, stateBar, '');
      expect(bar.first, '↑');
      expect(bar.toSet().containsAll(stateBar), isTrue);
    });

    test('过滤后索引栏只含匹配项的标签，保持一致', () {
      final filtered = filteredContacts(all, 'alice'); // 仅 A
      final bar = filteredIndexBar(filtered, stateBar, 'alice');
      expect(bar, isNot(contains('B')));
      expect(bar, contains('A'));
      // 无 '↑' 顶部项匹配 'alice'，故不带 '↑'
      expect(bar.first, isNot('↑'));
    });

    test('无匹配项 → 索引栏仅由结果派生（空标签集）', () {
      final filtered = filteredContacts(all, 'zzz');
      final bar = filteredIndexBar(filtered, stateBar, 'zzz');
      expect(bar.where((t) => t != '↑'), isEmpty);
    });
  });
}
