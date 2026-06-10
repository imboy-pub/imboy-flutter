import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:jose/jose.dart';

bool tokenExpired(String? token) {
  // 空值快速失败
  if (token == null || token.isEmpty) {
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
      if (kDebugMode) {}
      return true;
    }

    final current = DateTimeHelper.second();
    const buffer = 3; // 建议 3-5 秒（考虑网络波动）
    // 修正后的核心逻辑
    final expired = current >= (exp - buffer);

    if (kDebugMode && expired) {}

    return expired;
  } on JoseException catch (e) {
    if (kDebugMode) {}
    return true;
  } catch (e) {
    if (kDebugMode) {}
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
