/// Tests for `lib/component/helper/jwt.dart` `tokenExpired`.
///
/// 行为契约：
///   - null / 空字符串 → true（无 token = 已过期，安全默认）
///   - 非法格式 → true（catch 兜底，不抛异常）
///   - exp 缺失 / null / <= 0 → true
///   - exp 在未来 > buffer(3s) → false
///   - exp 在过去 / 当前 → true
///   - exp 在 (now, now+buffer) 区间内 → true（保守判定，提前 3s 视为过期）
///   - exp 是字符串数字 → 也能解析
///
/// 测试通过手工构造 unsigned JWT (`header.payload.`) 来注入 claims，
/// 不需要私钥（JsonWebToken.unverified 不验签）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/jwt.dart';

/// 构造一个无签名的 JWT：`<base64url(header)>.<base64url(payload)>.`
/// `JsonWebToken.unverified` 接受这种最小结构。
String _makeJwt(Map<String, dynamic> claims) {
  String b64(Map<String, dynamic> m) {
    return base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  }

  final header = b64({'alg': 'none', 'typ': 'JWT'});
  final payload = b64(claims);
  // 第三段为空签名段
  return '$header.$payload.';
}

int _nowSec() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

void main() {
  group('tokenExpired null/empty input', () {
    test('null → true（视为已过期，最安全默认）', () {
      expect(tokenExpired(null), isTrue);
    });

    test('空字符串 → true', () {
      expect(tokenExpired(''), isTrue);
    });
  });

  group('tokenExpired malformed input', () {
    test('完全非 JWT 格式 → true（catch 兜底）', () {
      expect(tokenExpired('not_a_jwt'), isTrue);
    });

    test('结构不完整（只有一段）→ true', () {
      expect(tokenExpired('onlyonepart'), isTrue);
    });

    test('payload 段为非法 base64 → true', () {
      expect(tokenExpired('aaa.@@@.ccc'), isTrue);
    });
  });

  group('tokenExpired exp claim missing/invalid', () {
    test('payload 无 exp 字段 → true', () {
      final t = _makeJwt({'sub': 'user_1'});
      expect(tokenExpired(t), isTrue);
    });

    test('exp = null → true', () {
      final t = _makeJwt({'exp': null});
      expect(tokenExpired(t), isTrue);
    });

    test('exp = 0 → true', () {
      final t = _makeJwt({'exp': 0});
      expect(tokenExpired(t), isTrue);
    });

    test('exp = -1 (负数) → true', () {
      final t = _makeJwt({'exp': -1});
      expect(tokenExpired(t), isTrue);
    });

    test('exp 是非数字字符串 → true（_parseExp 失败 → null）', () {
      final t = _makeJwt({'exp': 'not_a_number'});
      expect(tokenExpired(t), isTrue);
    });
  });

  group('tokenExpired valid exp', () {
    test('exp 远未来（+3600s） → false（仍有效）', () {
      final t = _makeJwt({'exp': _nowSec() + 3600});
      expect(tokenExpired(t), isFalse);
    });

    test('exp 已过去（-1s）→ true', () {
      final t = _makeJwt({'exp': _nowSec() - 1});
      expect(tokenExpired(t), isTrue);
    });

    test('exp == 当前秒 → true（current >= exp - buffer 即过期）', () {
      final t = _makeJwt({'exp': _nowSec()});
      expect(tokenExpired(t), isTrue);
    });

    test('exp 在 buffer 区间内（now+1s）→ true（提前判定过期）', () {
      // buffer=3 的语义：current >= exp - 3 即过期
      // exp = now+1 → now >= -2 → now >= now-2 → 永远 true
      final t = _makeJwt({'exp': _nowSec() + 1});
      expect(tokenExpired(t), isTrue,
          reason: 'buffer=3s，exp 在 3s 内已被认为过期（保守策略）');
    });

    test('exp 刚好超出 buffer（now+10s）→ false', () {
      final t = _makeJwt({'exp': _nowSec() + 10});
      expect(tokenExpired(t), isFalse);
    });
  });

  group('tokenExpired exp type variations', () {
    test('exp 是字符串数字 → 也能解析', () {
      final t = _makeJwt({'exp': (_nowSec() + 3600).toString()});
      expect(tokenExpired(t), isFalse,
          reason: '_parseExp 用 int.parse(value.toString()) 兜底');
    });

    test('exp 是 double（1234.0）→ toInt() 转换', () {
      final t = _makeJwt({'exp': (_nowSec() + 3600).toDouble()});
      expect(tokenExpired(t), isFalse);
    });
  });
}
