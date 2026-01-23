import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:jose/jose.dart';

bool tokenExpired(String? token) {
  // 空值快速失败
  if (token == null || token.isEmpty) {
    // 这是预期的情况（用户未登录或正在登录），降低日志级别
    debugPrint('Token validation: token is empty (user may not be logged in)');
    return true;
  }

  try {
    // 使用标准解析方法
    final jwt = JsonWebToken.unverified(token);

    // 获取claims时处理可能的null值
    final claims = jwt.claims;
    // 类型安全的exp解析
    final exp = _parseExp(claims['exp']);

    // 边界值处理
    if (exp == null || exp <= 0) {
      debugPrint(
        '❌ Token validation failed: invalid exp value: ${claims['exp']}',
      );
      return true;
    }

    final current = DateTimeHelper.second();
    const buffer = 3; // 建议 3-5 秒（考虑网络波动）
    // 修正后的核心逻辑
    final expired = current >= (exp - buffer);

    if (expired) {
      debugPrint(
        '❌ Token validation failed: token expired (exp=$exp, current=$current)',
      );
    } else {
      // Token 有效，输出调试信息（可以后续移除）
      debugPrint(
        '✅ Token validation: token is valid (exp=$exp, current=$current)',
      );
    }

    return expired;
  } on JoseException catch (e) {
    debugPrint('❌ JWT processing error (${e.runtimeType}): ${e.message}');
    return true;
  } catch (e) {
    debugPrint('❌ Unexpected token validation error: ${e.runtimeType}');
    return true;
  }
}

// 支持多种exp类型处理
int? _parseExp(dynamic value) {
  try {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.parse(value.toString());
  } catch (_) {
    return null;
  }
}
