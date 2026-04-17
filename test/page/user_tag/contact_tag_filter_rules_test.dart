import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/contact_tag_filter_rules.dart';

void main() {
  group('filterContactsByTagUids', () {
    final contacts = [
      {'peer_id': 1001, 'name': 'Alice'},
      {'peer_id': 1002, 'name': 'Bob'},
      {'peer_id': 1003, 'name': 'Cindy'},
      {'peer_id': 1004, 'name': 'David'},
    ];

    test('空 contacts → 返回空列表', () {
      expect(
        filterContactsByTagUids(const [], tagUids: const ['1001']),
        isEmpty,
      );
    });

    test('空 tagUids → 返回空列表（语义：标签无成员即无人命中）', () {
      expect(
        filterContactsByTagUids(contacts, tagUids: const []),
        isEmpty,
      );
    });

    test('命中单个 UID → 返回对应联系人', () {
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['1002'],
      );
      expect(result.length, 1);
      expect(result.first['peer_id'], 1002);
    });

    test('命中多个 UID → 返回所有匹配的联系人，保持原顺序', () {
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['1003', '1001'],
      );
      // 原列表中 1001 在前、1003 在后，结果必须保序
      expect(result.map((c) => c['peer_id']).toList(), [1001, 1003]);
    });

    test('UID 类型互通：int peer_id vs String tagUids', () {
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['1004'],
      );
      expect(result.first['peer_id'], 1004);
    });

    test('tagUids 包含不存在的 UID → 忽略不报错', () {
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['9999', '1001', '8888'],
      );
      expect(result.length, 1);
      expect(result.first['peer_id'], 1001);
    });

    test('tagUids 含空白/空字符串 → 归一化过滤后不匹配', () {
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['', '  ', '1002'],
      );
      expect(result.length, 1);
      expect(result.first['peer_id'], 1002);
    });

    test('tagUids 全为空白 → 归一化后为空集 → 返回空列表', () {
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['', '   ', '\t'],
      );
      expect(result, isEmpty);
    });

    test('tagUids 重复 → 仍正确去重匹配', () {
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['1001', '1001', '1001'],
      );
      expect(result.length, 1);
      expect(result.first['peer_id'], 1001);
    });

    test('不可变性：返回新列表，修改结果不影响原 contacts', () {
      final original = List<Map<String, dynamic>>.from(contacts);
      final result = filterContactsByTagUids(
        contacts,
        tagUids: const ['1001', '1002'],
      );
      result.clear();
      // 原列表应保持 4 条
      expect(contacts.length, 4);
      expect(contacts, equals(original));
    });

    test('contacts 中 peer_id 缺失 → 跳过不报错', () {
      final dirty = [
        {'peer_id': 1001},
        {'name': 'Ghost'}, // 无 peer_id
        {'peer_id': 1002},
      ];
      final result = filterContactsByTagUids(
        dirty,
        tagUids: const ['1001', '1002'],
      );
      expect(result.length, 2);
    });

    test('contacts 中 peer_id 为 String 类型 → 仍能匹配（字段类型宽容）', () {
      final mixed = [
        {'peer_id': '1001', 'name': 'A'},
        {'peer_id': 1002, 'name': 'B'},
      ];
      final result = filterContactsByTagUids(
        mixed,
        tagUids: const ['1001', '1002'],
      );
      expect(result.length, 2);
    });
  });

  group('unionTagUids', () {
    test('空列表 → 返回空', () {
      expect(unionTagUids(const []), isEmpty);
    });

    test('单标签 → 去空 + 去重 + 保序', () {
      expect(
        unionTagUids(const [
          ['1001', '', '1002', '1001', '  '],
        ]),
        ['1001', '1002'],
      );
    });

    test('多标签并集 → 按首次出现顺序保序', () {
      final result = unionTagUids(const [
        ['1001', '1002'],
        ['1003', '1001', '1004'],
      ]);
      expect(result, ['1001', '1002', '1003', '1004']);
    });

    test('全空 → 返回空', () {
      expect(unionTagUids(const [[], []]), isEmpty);
    });

    test('全部重复 → 返回一个', () {
      final result = unionTagUids(const [
        ['1001'],
        ['1001'],
        ['1001'],
      ]);
      expect(result, ['1001']);
    });

    test('包含空白字符的 UID → trim 后去重', () {
      final result = unionTagUids(const [
        ['  1001  '],
        ['1001'],
      ]);
      expect(result, ['1001']);
    });
  });
}
