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
      'e2ee', 'e2ee_v3', 'e2ee_room_key', 'devices', 'protected_header',
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
    // 修改输出不影响输入
    (r.cleaned['body'] as Map<String, dynamic>)['text'] = 'changed';
    expect(nested['text'], 'x');
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
