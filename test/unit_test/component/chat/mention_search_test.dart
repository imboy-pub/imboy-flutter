/// mentionMatches 契约测试。
///
/// 改动前 @ 面板只做 `displayName.contains(keyword)`：群成员多为中文昵称，
/// 用户打 `@zhangsan` 或 `@zs` 一个都搜不出来。项目本就依赖 lpinyin
/// （联系人索引栏在用），这里复用同一套转换补上全拼与首字母。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/chat/mention_search.dart';

void main() {
  group('原文子串匹配', () {
    test('中文昵称按原文命中', () {
      expect(mentionMatches('张三', '张'), isTrue);
      expect(mentionMatches('张三', '三'), isTrue);
      expect(mentionMatches('张三', '张三'), isTrue);
    });

    test('英文昵称大小写不敏感', () {
      expect(mentionMatches('Alice', 'ali'), isTrue);
      expect(mentionMatches('Alice', 'ALI'), isTrue);
      expect(mentionMatches('alice', 'Ali'), isTrue);
    });

    test('不相干关键词不命中', () {
      expect(mentionMatches('张三', '李'), isFalse);
      expect(mentionMatches('Alice', 'bob'), isFalse);
    });
  });

  group('拼音匹配（本次新增能力）', () {
    test('全拼命中', () {
      expect(mentionMatches('张三', 'zhangsan'), isTrue);
      expect(mentionMatches('张三', 'zhang'), isTrue);
      expect(mentionMatches('张三', 'san'), isTrue);
    });

    test('首字母命中', () {
      expect(mentionMatches('张三', 'zs'), isTrue);
      expect(mentionMatches('王小明', 'wxm'), isTrue);
      expect(mentionMatches('王小明', 'wx'), isTrue);
    });

    test('拼音大小写不敏感', () {
      expect(mentionMatches('张三', 'ZhangSan'), isTrue);
      expect(mentionMatches('张三', 'ZS'), isTrue);
    });

    test('拼音不匹配时仍返回 false（不能变成万能命中）', () {
      expect(mentionMatches('张三', 'lisi'), isFalse);
      expect(mentionMatches('张三', 'ls'), isFalse);
    });
  });

  group('边界', () {
    test('空关键词全部命中（刚敲下 @ 时展示全部候选）', () {
      expect(mentionMatches('张三', ''), isTrue);
      expect(mentionMatches('Alice', ''), isTrue);
      expect(mentionMatches('', ''), isTrue);
    });

    test('关键词只有空白等同于空', () {
      expect(mentionMatches('张三', '   '), isTrue);
    });

    test('空昵称配非空关键词不命中', () {
      expect(mentionMatches('', 'a'), isFalse);
      expect(mentionMatches('   ', 'a'), isFalse);
    });

    test('中英混合昵称两条路都能命中', () {
      expect(mentionMatches('张三Alice', 'zhang'), isTrue);
      expect(mentionMatches('张三Alice', 'ali'), isTrue);
      expect(mentionMatches('张三Alice', 'zs'), isTrue);
    });

    test('emoji 前缀昵称不影响匹配（lpinyin 原样透传 emoji）', () {
      // 「小鱼儿」首字母是 xye（儿 = er → e），不是 xyr
      expect(mentionMatches('🐟小鱼儿', '小鱼'), isTrue);
      expect(mentionMatches('🐟小鱼儿', 'xye'), isTrue);
      expect(mentionMatches('🐟小鱼儿', 'xiaoyuer'), isTrue);
      // emoji 本身留在拼音串里，不会把无关关键词也匹配上
      expect(mentionMatches('🐟小鱼儿', 'abc'), isFalse);
    });

    test('纯 emoji 昵称不崩溃', () {
      expect(() => mentionMatches('🎉🎉', 'a'), returnsNormally);
      expect(mentionMatches('🎉🎉', '🎉'), isTrue);
    });
  });

  group('英文昵称跳过拼音转换（性能）', () {
    test('纯 ASCII 昵称不会因拼音路径产生误命中', () {
      // "bob" 不含 CJK，直接走原文匹配后返回，不做拼音转换
      expect(mentionMatches('bob', 'bob'), isTrue);
      expect(mentionMatches('bob', 'b'), isTrue);
      expect(mentionMatches('bob', 'x'), isFalse);
    });
  });
}
