/// 钉住 GroupModel.displayTitle 的兜底契约。
///
/// 背景：无名群（后端 `title` 为空）在客户端曾出现 4 种不同显示 ——
///   群列表 `IMBoy`（取成员昵称）/ 聊天页 `群聊(2)` / 群设置 `未命名` /
///   群二维码 `群聊: `（空白）/ 共同群聊（整行没有任何文字）。
/// 根因是各页面各写各的 `title.isEmpty ? computeTitle : title`，
/// 而 `computeTitle` 本身也可能是空串，三元表达式兜不住底。
///
/// 关键边界（两条都必须守住）：
///   1. title 与 computeTitle 同时为空时，必须回退到「未命名」而不是空串；
///   2. **任何情况下都不得回退到 groupId** —— TSID 属内部标识，不进 UI。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/group_model.dart';

GroupModel buildGroup({String title = '', String computeTitle = ''}) {
  final g = GroupModel(
    groupId: 104603643803863040,
    type: 1,
    joinLimit: 1,
    contentLimit: 1,
    userIdSum: 0,
    ownerUid: 50,
    creatorUid: 50,
    memberMax: 200,
    memberCount: 2,
    title: title,
    createdAt: 0,
  );
  g.computeTitle = computeTitle;
  return g;
}

void main() {
  group('GroupModel.displayTitle', () {
    test('title 非空时优先用 title', () {
      expect(buildGroup(title: '产品组', computeTitle: 'X').displayTitle, '产品组');
    });

    test('title 为空时回退到 computeTitle', () {
      expect(buildGroup(computeTitle: 'IMBoy, 117').displayTitle, 'IMBoy, 117');
    });

    test('title 仅空白字符时视为空，回退到 computeTitle', () {
      expect(
        buildGroup(title: '   ', computeTitle: 'IMBoy').displayTitle,
        'IMBoy',
      );
    });

    test('两者都为空时回退到「未命名」，而不是空串', () {
      final name = buildGroup().displayTitle;
      expect(name.isNotEmpty, isTrue);
      expect(name, '未命名');
    });

    test('两者都为空时也绝不能回退到 groupId（TSID 不进 UI）', () {
      final g = buildGroup();
      expect(g.displayTitle.contains(g.groupId.toString()), isFalse);
    });

    test('两者都仅空白字符时同样回退到「未命名」', () {
      expect(buildGroup(title: ' ', computeTitle: '  ').displayTitle, '未命名');
    });
  });
}
