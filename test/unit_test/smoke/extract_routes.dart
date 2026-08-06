// 路由清单提取脚本 / Route inventory extraction script
//
// 用途 / Purpose:
//   遍历 goRouterProvider 的全部 GoRoute，打印 name + path + 是否含动态段，
//   用于人工核对 route_registry.dart 的完整性（防漏登记）。
//   Walks every GoRoute in goRouterProvider and prints name + path, so we can
//   cross-check route_registry.dart for completeness.
//
// 运行方式 / How to run:
//   flutter test test/smoke/extract_routes.dart
//
// 注意 / Note:
//   这是一次性辅助脚本，非 CI 断言；只负责打印清单。
//   This is a one-off helper, NOT a CI assertion — it only prints.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/service/storage.dart';

import '../helper/sqflite_test_helper.dart';

void main() {
  setUp(() async {
    // goRouterProvider 内部读取 UserRepoLocal.to → 触碰 SQLite / secure storage，
    // 必须先 mock 原生 channel；StorageService 已由 flutter_test_config 初始化。
    mockSqfliteSqlcipher();
    await StorageService.to.setString(Keys.currentUid, 'smoke_test_uid');
  });

  test('打印全部路由清单 / dump all routes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(goRouterProvider);

    var count = 0;
    var dynamicCount = 0;
    final lines = <String>[];

    // 匹配 path 中的 :param 动态段 / match `:param` segments
    final paramRe = RegExp(r':(\w+)');

    // 为动态段生成 fake 值 / fake values for dynamic segments
    String fakeFor(String param) {
      switch (param) {
        case 'peerId':
          return '1001';
        case 'id':
          return '1001';
        case 'groupId':
          return '2001';
        case 'channelId':
          return '5001';
        case 'momentId':
          return '3001';
        case 'albumId':
          return '4001';
        case 'photoId':
          return '4101';
        case 'voteId':
          return '6001';
        case 'scheduleId':
          return '7001';
        case 'taskId':
          return '8001';
        case 'feedbackId':
          return '9001';
        default:
          return '1';
      }
    }

    // 递归时累积祖先链上的全部参数名（嵌套子路由的完整参数集）
    // accumulate all ancestor param names for nested routes
    void walk(List<RouteBase> routes, int depth, Set<String> inheritedParams) {
      for (final r in routes) {
        final ownParams = r is GoRoute
            ? paramRe.allMatches(r.path).map((m) => m.group(1)!).toSet()
            : <String>{};
        final allParams = {...inheritedParams, ...ownParams};

        if (r is GoRoute) {
          count++;
          final isDynamic = allParams.isNotEmpty;
          if (isDynamic) dynamicCount++;

          // 用 namedLocation 解析嵌套 + 填 fake 参数，得到真实可导航 location
          String resolved;
          try {
            final pathParams = <String, String>{
              for (final p in allParams) p: fakeFor(p),
            };
            resolved = r.name != null
                ? router.namedLocation(r.name!, pathParameters: pathParams)
                : '(no-name, raw=${r.path})';
          } on Object catch (e) {
            resolved = '(namedLocation FAILED: $e)';
          }

          final indent = '  ' * depth;
          lines.add(
            '$indent${r.name ?? "(no-name)"}\t'
            'rawPath=${r.path}\t'
            'location=$resolved'
            '${isDynamic ? "\t[DYNAMIC params=$allParams]" : ""}',
          );
        }
        walk(r.routes, depth + 1, allParams);
      }
    }

    walk(router.configuration.routes, 0, <String>{});

    // ignore: avoid_print
    print(
      '\n===== ROUTE INVENTORY (total=$count, dynamic=$dynamicCount) =====',
    );
    for (final l in lines) {
      // ignore: avoid_print
      print(l);
    }
    // ignore: avoid_print
    print('===== END (total=$count) =====\n');

    // 仅做存在性兜底断言：至少应有 100+ 条路由
    expect(
      count,
      greaterThan(100),
      reason: '提取到的路由数 ($count) 异常偏低，检查 goRouterProvider 是否正常构造',
    );
  });
}
