import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:jose/jose.dart';

/// 验证token是否过期
bool tokenExpired(String? token) {
  try {
    var jwt = JsonWebToken.unverified(token ?? '');
    // 极端情况下扣除2秒
    return (jwt.claims['exp'] ?? 0) - 2 > (DateTimeHelper.second())
        ? true
        : false;
  } on Exception catch (e) {
    // 任意一个异常
    debugPrint('Unknown exception: $e');
  } catch (e) {
    // 非具体类型
    debugPrint('Something really unknown: $e');
  }
  return true;
}
