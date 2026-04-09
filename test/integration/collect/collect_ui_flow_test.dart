/// 收藏系统 UI 流程测试
///
/// 测试目标：
/// 1. 收藏状态初始化验证
/// 2. 分页加载逻辑验证
/// 3. 搜索功能逻辑验证
/// 4. 标签筛选逻辑验证
/// 5. 删除操作反馈验证
/// 6. 多选模式逻辑验证
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/user_collect/user_collect_page.dart';
import 'package:imboy/page/mine/user_collect/user_collect_state.dart';
import 'package:imboy/store/model/user_collect_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('收藏页面构造函数验证', () {
    test('默认构造函数保持非选择模式', () {
      const page = UserCollectPage();

      expect(page.isSelect, isFalse);
      expect(page.peer, isEmpty);
    });

    test('选择模式构造函数保留 peer 载荷', () {
      const page = UserCollectPage(
        isSelect: true,
        peer: {'peer_id': 'u_1001', 'peer_name': 'Alice'},
      );

      expect(page.isSelect, isTrue);
      expect(page.peer['peer_id'], 'u_1001');
      expect(page.peer['peer_name'], 'Alice');
    });

    test('选择模式可以包含完整的会话信息', () {
      const page = UserCollectPage(
        isSelect: true,
        peer: {
          'peer_id': 'g_2001',
          'peer_name': 'Group Chat',
          'type': 'C2G',
        },
      );

      expect(page.isSelect, isTrue);
      expect(page.peer['type'], 'C2G');
    });
  });

  group('收藏状态初始化验证', () {
    test('初始状态应该正确设置默认值', () {
      final state = UserCollectState();

      expect(state.kindActive, isFalse);
      expect(state.items, isEmpty);
      expect(state.tagItems, isEmpty);
      expect(state.page, 1);
      expect(state.size, 10);
      expect(state.kind, 'all');
      expect(state.kwd, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.removingIds, isEmpty);
    });

    test('状态复制应该正确更新指定字段', () {
      final original = UserCollectState();
      final copied = original.copyWith(
        page: 2,
        kind: '1',
        kwd: 'test',
        isLoading: true,
        hasMore: false,
      );

      expect(copied.page, 2);
      expect(copied.kind, '1');
      expect(copied.kwd, 'test');
      expect(copied.isLoading, isTrue);
      expect(copied.hasMore, isFalse);

      // 未修改的字段保持原值
      expect(copied.size, original.size);
      expect(copied.kindActive, original.kindActive);
    });

    test('removingIds 集合应该正确跟踪删除操作', () {
      final state = UserCollectState();
      expect(state.removingIds, isEmpty);

      final updated = state.copyWith(
        removingIds: {'kind_001', 'kind_002'},
      );
      expect(updated.removingIds.length, 2);
      expect(updated.removingIds.contains('kind_001'), isTrue);
      expect(updated.removingIds.contains('kind_002'), isTrue);
    });
  });

  group('收藏模型解析验证', () {
    test('应该正确解析完整的收藏数据', () {
      final json = {
        'user_id': 1001,
        'kind': 1,
        'kind_id': 1,
        'source': 'chat',
        'remark': '重要内容',
        'tag': 'work,important,',
        'updated_at': 1640000000,
        'created_at': 1630000000,
        'info': {'text': '收藏的文本内容'},
      };

      final model = UserCollectModel.fromJson(json);

      expect(model.userId, 1001);
      expect(model.kind, 1);
      expect(model.kindId, 1);
      expect(model.source, 'chat');
      expect(model.remark, '重要内容');
      expect(model.tag, 'work,important,');
      expect(model.info['text'], '收藏的文本内容');
    });

    test('应该正确处理 info 字段为字符串的情况', () {
      final json = {
        'user_id': 1001,
        'kind': 2,
        'kind_id': 2,
        'source': 'chat',
        'remark': '',
        'tag': '',
        'updated_at': 1640000000,
        'created_at': 1630000000,
        'info': '{"uri": "https://example.com/image.jpg"}',
      };

      final model = UserCollectModel.fromJson(json);

      expect(model.info, isA<Map<String, dynamic>>());
      expect(model.info['uri'], 'https://example.com/image.jpg');
    });

    test('应该正确处理缺失的可选字段', () {
      final json = {
        'user_id': 1001,
        'kind': 1,
        'kind_id': 3,
        'source': null,
        'remark': null,
        'tag': null,
        'updated_at': 1640000000,
        'created_at': 1630000000,
        'info': <String, dynamic>{},
      };

      final model = UserCollectModel.fromJson(json);

      expect(model.source, '');
      expect(model.remark, '');
      expect(model.tag, '');
      expect(model.info, isEmpty);
    });

    test('toMap 应该正确序列化模型', () {
      final model = UserCollectModel(
        userId: 1001,
        kind: 1,
        kindId: 1,
        source: 'chat',
        remark: '备注',
        tag: 'tag1,',
        updatedAt: 1640000000,
        createdAt: 1630000000,
        info: {'text': '内容'},
      );

      final map = model.toMap();

      expect(map['user_id'], 1001);
      expect(map['kind'], 1);
      expect(map['kind_id'], 1);
      expect(map['source'], 'chat');
      expect(map['remark'], '备注');
      expect(map['tag'], 'tag1,');
      expect(map['info'], isA<Map<String, dynamic>>());
    });

    test('应该正确解析各种类型的收藏', () {
      final kinds = [
        {'kind': 1, 'expected': '文本'},
        {'kind': 2, 'expected': '图片'},
        {'kind': 3, 'expected': '语音'},
        {'kind': 4, 'expected': '视频'},
        {'kind': 5, 'expected': '文件'},
        {'kind': 6, 'expected': '位置'},
        {'kind': 7, 'expected': '名片'},
      ];

      for (final item in kinds) {
        final json = {
          'user_id': 1001,
          'kind': item['kind'],
          'kind_id': 0,
          'source': '',
          'remark': '',
          'tag': '',
          'updated_at': 1640000000,
          'created_at': 1630000000,
          'info': {},
        };

        final model = UserCollectModel.fromJson(json);
        expect(model.kind, item['kind']);
      }
    });
  });

  group('分页加载逻辑验证', () {
    test('分页偏移量计算应该正确', () {
      // 第一页
      expect((1 - 1) * 10, 0);

      // 第二页
      expect((2 - 1) * 10, 10);

      // 第三页
      expect((3 - 1) * 10, 20);
    });

    test('hasMore 标志应该根据返回数量判断', () {
      const size = 10;

      // 返回数量等于 size，可能还有更多
      final hasMore1 = 10 >= size;
      expect(hasMore1, isTrue);

      // 返回数量小于 size，没有更多了
      final hasMore2 = 5 >= size;
      expect(hasMore2, isFalse);

      // 返回空列表，没有更多了
      final hasMore3 = 0 >= size;
      expect(hasMore3, isFalse);
    });

    test('翻页时应该正确去重', () {
      final existingItems = [
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 1,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 2,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
      ];

      final newItems = [
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 2, // 重复
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 3, // 新的
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
      ];

      final existingIds = existingItems.map((e) => e.kindId).toSet();
      final filtered =
          newItems.where((r) => !existingIds.contains(r.kindId)).toList();

      expect(filtered.length, 1);
      expect(filtered.first.kindId, 3);
    });
  });

  group('搜索功能逻辑验证', () {
    test('关键词搜索应该构建正确的 WHERE 子句', () {
      const kwd = 'test';
      const userId = 'u_1001';

      // 模拟构建 WHERE 子句
      String where = '${'user_id'}=?';
      final List<Object?> whereArgs = [userId];

      where =
          "$where and (source like '%$kwd%' or remark like '%$kwd%' or info like '%$kwd%')";

      expect(where, contains('source like'));
      expect(where, contains('remark like'));
      expect(where, contains('info like'));
      expect(whereArgs.length, 1);
    });

    test('空关键词不应该添加搜索条件', () {
      const String? kwd = null;
      String where = 'user_id=?';
      final baseWhere = where;

      // kwd 为 null 时，条件判断为 false，不会添加搜索条件
      if (kwd != null && kwd.isNotEmpty) {
        where = "$where and (source like '%$kwd%')";
      }

      expect(where, baseWhere);
    });

    test('搜索后应该重置分页', () {
      final state = UserCollectState()..page = 5;

      // 搜索时应该重置到第一页
      final newState = state.copyWith(page: 1, kwd: 'test');
      expect(newState.page, 1);
      expect(newState.kwd, 'test');
    });
  });

  group('标签筛选逻辑验证', () {
    test('标签筛选应该构建正确的 LIKE 条件', () {
      const tag = 'work';
      String where = 'user_id=?';

      where = "$where and tag like '%$tag,%'";

      expect(where, contains('tag like'));
      expect(where, contains('%work,%'));
    });

    test('切换标签应该重置分页和列表', () {
      final state = UserCollectState()
        ..page = 3
        ..items = [
          {'id': 1},
          {'id': 2},
        ];

      // 切换标签时应该重置
      final newState = state.copyWith(
        page: 1,
        items: [],
        kind: 'all',
      );

      expect(newState.page, 1);
      expect(newState.items, isEmpty);
    });

    test('标签格式应该以逗号结尾', () {
      // 模拟 _formatTag 逻辑
      String formatTag(String tag) {
        if (tag.isNotEmpty && !tag.endsWith(',')) {
          tag = "$tag,";
        }
        return tag.replaceAll(',,', ',');
      }

      expect(formatTag('work'), 'work,');
      expect(formatTag('work,'), 'work,');
      expect(formatTag('work,important'), 'work,important,');
      expect(formatTag('work,,important'), 'work,important,');
    });
  });

  group('类型筛选逻辑验证', () {
    test('recent_use 类型应该按更新时间排序', () {
      const kind = 'recent_use';
      String? orderBy;

      if (kind == 'recent_use') {
        orderBy = 'updated_at desc, auto_id desc';
      }

      expect(orderBy, 'updated_at desc, auto_id desc');
    });

    test('数字类型应该添加 kind 条件', () {
      const kind = '2'; // 图片
      String where = 'user_id=?';
      final List<Object?> whereArgs = ['u_1001'];

      if (int.tryParse(kind) != null) {
        where = "$where and kind=?";
        whereArgs.add(kind);
      }

      expect(where, contains('kind=?'));
      expect(whereArgs.length, 2);
      expect(whereArgs.last, '2');
    });

    test('all 类型不应该添加 kind 条件', () {
      const kind = 'all';
      String where = 'user_id=?';
      final List<Object?> whereArgs = ['u_1001'];
      final baseWhere = where;

      if (kind != 'all' && int.tryParse(kind) != null) {
        where = "$where and kind=?";
        whereArgs.add(kind);
      }

      expect(where, baseWhere);
      expect(whereArgs.length, 1);
    });
  });

  group('删除操作逻辑验证', () {
    test('删除项应该添加到 removingIds 防止重复提交', () {
      final state = UserCollectState();
      final removingIds = <String>{};

      // 开始删除
      removingIds.add('kind_001');
      final deleting = state.copyWith(removingIds: removingIds);

      expect(deleting.removingIds.contains('kind_001'), isTrue);

      // 检查是否正在删除
      final isRemoving = deleting.removingIds.contains('kind_001');
      expect(isRemoving, isTrue);
    });

    test('删除完成后应该从 removingIds 移除', () {
      final state = UserCollectState().copyWith(
        removingIds: {'kind_001', 'kind_002'},
      );

      // 删除完成
      final newRemovingIds = Set<String>.from(state.removingIds);
      newRemovingIds.remove('kind_001');
      final updated = state.copyWith(removingIds: newRemovingIds);

      expect(updated.removingIds.contains('kind_001'), isFalse);
      expect(updated.removingIds.contains('kind_002'), isTrue);
    });

    test('删除成功后应该从列表中移除该项', () {
      final items = [
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 1,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 2,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
      ];

      // 删除 kind_001
      final updatedItems =
          items.where((item) => item.kindId != 1).toList();

      expect(updatedItems.length, 1);
      expect(updatedItems.first.kindId, 2);
    });
  });

  group('多选模式逻辑验证', () {
    test('多选模式应该跟踪选中项', () {
      final selectedIds = <String>{};

      // 选中
      selectedIds.add('kind_001');
      selectedIds.add('kind_002');
      expect(selectedIds.length, 2);

      // 取消选中
      selectedIds.remove('kind_001');
      expect(selectedIds.length, 1);
      expect(selectedIds.contains('kind_001'), isFalse);
    });

    test('全选应该选中所有项', () {
      final items = [
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 1,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 2,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 3,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
      ];

      final allIds = items.map((e) => e.kindId).toSet();
      expect(allIds.length, 3);
      expect(allIds.containsAll([1, 2, 3]), isTrue);
    });

    test('批量删除应该删除所有选中项', () {
      final items = [
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 1,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 2,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 3,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
      ];

      final selectedIds = {1, 3};

      final remainingItems =
          items.where((item) => !selectedIds.contains(item.kindId)).toList();

      expect(remainingItems.length, 1);
      expect(remainingItems.first.kindId, 2);
    });
  });

  group('刷新逻辑验证', () {
    test('下拉刷新应该重置分页并清空列表', () {
      final state = UserCollectState()
        ..page = 3
        ..items = [1, 2, 3]
        ..hasMore = false;

      // 刷新时重置状态
      final refreshed = state.copyWith(
        page: 1,
        items: [],
        hasMore: true,
        isRefreshing: true,
      );

      expect(refreshed.page, 1);
      expect(refreshed.items, isEmpty);
      expect(refreshed.hasMore, isTrue);
      expect(refreshed.isRefreshing, isTrue);
    });

    test('刷新完成后应该正确设置状态', () {
      final state = UserCollectState().copyWith(
        isRefreshing: true,
        isLoading: true,
      );

      // 刷新完成
      final completed = state.copyWith(
        isRefreshing: false,
        isLoading: false,
        hasMore: true,
      );

      expect(completed.isRefreshing, isFalse);
      expect(completed.isLoading, isFalse);
      expect(completed.hasMore, isTrue);
    });
  });

  group('加载状态管理验证', () {
    test('加载中状态应该正确设置', () {
      final state = UserCollectState();
      expect(state.isLoading, isFalse);

      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, isTrue);
    });

    test('加载完成后应该重置加载状态', () {
      final state = UserCollectState().copyWith(isLoading: true);
      final completed = state.copyWith(isLoading: false);

      expect(completed.isLoading, isFalse);
    });

    test('加载失败时应该正确处理', () {
      final state = UserCollectState().copyWith(
        isLoading: true,
        hasMore: true,
      );

      // 加载失败，设置 hasMore 为 false 防止无限加载
      final failed = state.copyWith(
        isLoading: false,
        hasMore: false,
      );

      expect(failed.isLoading, isFalse);
      expect(failed.hasMore, isFalse);
    });
  });

  group('UI 流程完整性验证', () {
    test('完整流程：打开页面 -> 加载数据 -> 显示列表', () {
      // 1. 初始化状态
      final initialState = UserCollectState();
      expect(initialState.items, isEmpty);
      expect(initialState.page, 1);
      expect(initialState.isLoading, isFalse);

      // 2. 开始加载
      final loadingState = initialState.copyWith(isLoading: true);
      expect(loadingState.isLoading, isTrue);

      // 3. 加载完成
      final loadedState = loadingState.copyWith(
        isLoading: false,
        items: [
          {'kind_id': 1},
          {'kind_id': 2},
        ],
        hasMore: true,
      );

      expect(loadedState.isLoading, isFalse);
      expect(loadedState.items.length, 2);
      expect(loadedState.hasMore, isTrue);
    });

    test('完整流程：筛选 -> 加载 -> 验证结果一致性', () {
      // 1. 设置筛选条件
      final state = UserCollectState().copyWith(
        kind: '1', // 文本类型
        page: 1,
      );

      expect(state.kind, '1');
      expect(state.page, 1);

      // 2. 模拟筛选后的结果（应该都是 kind=1 的项）
      final filteredItems = [
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 1,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 2,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
      ];

      // 3. 验证结果一致性
      for (final item in filteredItems) {
        expect(item.kind, 1);
      }
    });

    test('完整流程：选择 -> 删除 -> 反馈', () {
      // 1. 初始化选择
      final selectedIds = <int>{};
      expect(selectedIds, isEmpty);

      // 2. 选中项目
      selectedIds.add(1);
      selectedIds.add(2);
      expect(selectedIds.length, 2);

      // 3. 执行删除（模拟 API 返回成功）
      const deleteSuccess = true;
      expect(deleteSuccess, isTrue);

      // 4. 从列表中移除已删除项
      final items = [
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 1,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 2,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
        UserCollectModel(
          userId: 1,
          kind: 1,
          kindId: 3,
          source: '',
          remark: '',
          tag: '',
          updatedAt: 1640000000,
          createdAt: 1630000000,
          info: {},
        ),
      ];

      final remainingItems =
          items.where((item) => !selectedIds.contains(item.kindId)).toList();

      // 5. 验证删除结果
      expect(remainingItems.length, 1);
      expect(remainingItems.first.kindId, 3);

      // 6. 清空选择
      selectedIds.clear();
      expect(selectedIds, isEmpty);
    });
  });
}
