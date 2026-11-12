/// BundleSanitizer 验收测试：冻结禁止字段清单 + 任意嵌套层递归清理 +
/// 计数 + 深拷贝独立性（BND-03 客户端递归禁止字段扫描）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_sanitizer.dart';

void main() {
  test('冻结清单：精确键全部命中（isForbiddenKey 全表）', () {
    const exactKeys = <String>{
      // 原消息 id 快照
      'msg_id', 'message_id', 'original_message_id',
      // 源会话上下文 / 设备身份
      'peer_id', 'conversation_uk3', 'sender_did', 'sender_dtype',
      // 原 E2EE 外层信封（e2ee 前缀族 + 信封嵌套键）
      'e2ee', 'e2ee_v3', 'e2ee_room_key', 'e2eeRoomKey', 'e2eeEnvelope',
      'devices', 'protected_header',
      // 原 content key / descriptor
      'attachment_descriptor', 'content_key',
      // 阅后即焚
      'burn_read_at',
      // 服务端内部主键（源会话侧 *_id）
      'auto_id', 'topic_id', 'from_id', 'to_id',
      // 原会话成员列表
      'member_list', 'members', 'receivers',
    };
    for (final key in exactKeys) {
      expect(BundleSanitizer.isForbiddenKey(key), isTrue, reason: key);
    }
  });

  test('合法业务键不误伤', () {
    const okKeys = <String>{
      'text', 'quote_text', 'name', 'filename', 'size', 'width', 'height',
      'duration_ms', 'total', 'images', 'title', 'address', 'latitude',
      'longitude', 'sender_name', 'sent_at', 'msg_type', 'url', 'uri',
      'file_hash256', 'sender_uid', 'target_scope', // 非冻结清单键不清理
    };
    for (final key in okKeys) {
      expect(BundleSanitizer.isForbiddenKey(key), isFalse, reason: key);
    }
  });

  test('顶层禁止字段清理 + 计数', () {
    final input = <String, dynamic>{
      'text': 'hello',
      'peer_id': '42',
      'conversation_uk3': 'C2C_1_2',
      'burn_read_at': 1760000000000,
    };
    final r = BundleSanitizer.sanitize(input);
    expect(r.cleaned, <String, dynamic>{'text': 'hello'});
    expect(r.removedFieldCount, 3);
  });

  test('任意嵌套层埋雷：map 套 map 套 list 全部清理并计数', () {
    final input = <String, dynamic>{
      'text': '正文',
      // 干净分支下逐层埋雷：每处独立计数
      'meta': <String, dynamic>{
        'msg_id': 'M1', // 第二层 map
        'info': <String, dynamic>{
          'sender_did': 'did-9', // 第三层 map
          'deep': <dynamic>[
            <String, dynamic>{
              'member_list': <dynamic>['a', 'b'], // list → map 第四层
              'conversation_uk3': 'C2C_1_2',
            },
          ],
        },
      },
      // 禁止键子树整棵丢弃（计 1 次，子树内不再访问/重复计数）
      'e2ee': <String, dynamic>{
        'v': 3,
        'protected_header': <String, dynamic>{'alg': 'AES'},
        'devices': <dynamic>[
          <String, dynamic>{
            'payload': <String, dynamic>{'msg_id': 'M2'},
          },
        ],
      },
      'keep': <String, dynamic>{
        'ok': <dynamic>[
          1,
          2,
          <String, dynamic>{'fine': true},
        ],
      },
    };
    final r = BundleSanitizer.sanitize(input);
    // msg_id + sender_did + member_list + conversation_uk3 + e2ee = 5
    expect(r.removedFieldCount, 5);
    expect(r.cleaned.containsKey('e2ee'), isFalse);
    final meta = r.cleaned['meta'] as Map<String, dynamic>;
    expect(meta.containsKey('msg_id'), isFalse);
    final info = meta['info'] as Map<String, dynamic>;
    expect(info.containsKey('sender_did'), isFalse);
    final deep = info['deep'] as List<dynamic>;
    expect(deep.single, <String, dynamic>{});
    expect(r.cleaned['keep'], isNotNull);
    final keep = r.cleaned['keep'] as Map<String, dynamic>;
    expect(keep['ok'], isNotNull);
  });

  test('list 内嵌套 map 的独立元素逐个清理（兄弟元素保留）', () {
    final input = <String, dynamic>{
      'images': <dynamic>[
        <String, dynamic>{'uri': 'u1', 'size': 10},
        <String, dynamic>{'uri': 'u2', 'size': 20, 'conversation_uk3': 'X'},
        <String, dynamic>{
          'uri': 'u3',
          'meta': <String, dynamic>{'message_id': 'M9', 'tag': 't'},
        },
      ],
    };
    final r = BundleSanitizer.sanitize(input);
    expect(r.removedFieldCount, 2);
    final images = r.cleaned['images'] as List<dynamic>;
    expect(images, hasLength(3));
    expect(images[0], <String, dynamic>{'uri': 'u1', 'size': 10});
    expect(images[1], <String, dynamic>{'uri': 'u2', 'size': 20});
    expect(images[2], <String, dynamic>{
      'uri': 'u3',
      'meta': <String, dynamic>{'tag': 't'},
    });
  });

  test('输出是与输入不共享引用的全新深拷贝；输入不被修改', () {
    final nested = <String, dynamic>{'text': 'x', 'peer_id': '1'};
    final input = <String, dynamic>{
      'body': nested,
      'keep': <dynamic>[nested],
    };
    final snapshotBefore = Map.of(nested);
    final r = BundleSanitizer.sanitize(input);
    expect(identical(r.cleaned['body'], nested), isFalse);
    expect(nested, snapshotBefore); // 输入原样（含违规键，未被动）
    // 修改输出不影响输入：嵌套层不可变，修改直接拒绝（见下条契约测试）
    expect(
      () => (r.cleaned['body'] as Map<String, dynamic>)['text'] = 'changed',
      throwsUnsupportedError,
    );
    expect(nested['text'], 'x');
  });

  test('不可变契约：顶层可变、嵌套层（map/list 全深度）不可变', () {
    final r = BundleSanitizer.sanitize(<String, dynamic>{
      'nested': <String, dynamic>{'a': 1},
      'list': <dynamic>[
        <String, dynamic>{'b': 2},
      ],
    });
    // 顶层普通可变：DTO 层加 Map.unmodifiable 壳与 dispatcher 写回需要
    r.cleaned['top'] = 'ok';
    expect(r.cleaned['top'], 'ok');
    // 嵌套 map 修改抛异常
    expect(
      () => (r.cleaned['nested'] as Map<String, dynamic>)['a'] = 99,
      throwsUnsupportedError,
    );
    // 嵌套 list 修改抛异常（既有行为）
    expect(
      () => (r.cleaned['list'] as List<dynamic>).clear(),
      throwsUnsupportedError,
    );
    // list 内 map 同样不可变
    expect(
      () => ((r.cleaned['list'] as List<dynamic>).single as Map)['b'] = 99,
      throwsUnsupportedError,
    );
  });

  test('S1-M1 深度上限：顶层下 16 层容器合法，17 层起置位 depthExceeded', () {
    // 顶层 map 不计层：leaf 为第 1 层，每包一层 +1
    Object nest(int levels) {
      Object node = <String, dynamic>{'text': 'leaf'};
      for (var i = 1; i < levels; i++) {
        node = <String, dynamic>{'nested': node};
      }
      return node;
    }

    final ok = BundleSanitizer.sanitize(<String, dynamic>{'deep': nest(16)});
    expect(ok.depthExceeded, isFalse, reason: '16 层容器（顶层不计）合法');
    expect(ok.cleaned['deep'], isNotNull);

    final over = BundleSanitizer.sanitize(<String, dynamic>{'deep': nest(17)});
    expect(over.depthExceeded, isTrue, reason: '第 17 层容器 fail-closed');
    // 超限子树被丢弃（置 null），但浅层输出仍是结构完好的 map
    expect(over.cleaned['deep'], isA<Map<dynamic, dynamic>>());

    // 既有两参构造兼容：默认 depthExceeded = false
    expect(
      const BundleSanitizeResult(<String, dynamic>{}, 0).depthExceeded,
      isFalse,
    );
  });

  test('S1-M1 病态深嵌套（5000 层）不栈溢出：有界递归 + 稳定置位', () {
    Object deep = <dynamic>[1];
    for (var i = 0; i < 5000; i++) {
      deep = <dynamic>[deep];
    }
    final r = BundleSanitizer.sanitize(<String, dynamic>{'deep': deep});
    expect(r.depthExceeded, isTrue);
  });

  test('S1-M1 depthOverLimit 共用前置闸：与 sanitize 同口径', () {
    Object nest(int levels) {
      Object node = <String, dynamic>{'text': 'leaf'};
      for (var i = 1; i < levels; i++) {
        node = <String, dynamic>{'nested': node};
      }
      return node;
    }

    expect(
      BundleSanitizer.depthOverLimit(<String, dynamic>{'a': nest(16)}),
      isFalse,
    );
    expect(
      BundleSanitizer.depthOverLimit(<String, dynamic>{'a': nest(17)}),
      isTrue,
    );
    // 标量不消耗深度预算（jsonEncode 对标量不递归）
    expect(BundleSanitizer.depthOverLimit('scalar'), isFalse);

    Object deep = <dynamic>[1];
    for (var i = 0; i < 5000; i++) {
      deep = <dynamic>[deep];
    }
    // 递归帧数有界（≤ maxDepth+2），永不栈溢出
    expect(
      BundleSanitizer.depthOverLimit(<String, dynamic>{'deep': deep}),
      isTrue,
    );
  });

  test('干净 payload：零移除、内容等价', () {
    final input = <String, dynamic>{
      'text': 'ok',
      'extra': <String, dynamic>{
        'a': <dynamic>[1, 2, 3],
      },
    };
    final r = BundleSanitizer.sanitize(input);
    expect(r.removedFieldCount, 0);
    expect(r.cleaned, equals(input));
  });
}
