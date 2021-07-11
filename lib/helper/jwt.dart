import 'package:flutter/cupertino.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:jose/jose.dart';

/// 验证token是否过期
bool token_expired(String token) {
  try {
    var jwt = JsonWebToken.unverified(token);
    int ts = DateTimeHelper.currentTimeMillis();
    debugPrint(
        ">>>>>>>> on jwt claims ${jwt.claims} ${jwt.claims['exp']}, ${ts}, ${ts > jwt.claims['exp']}");
    return ts > jwt.claims['exp'] ? true : false;
  } on Exception catch (e) {
    // 任意一个异常
    print('Unknown exception: $e');
  } catch (e) {
    // 非具体类型
    print('Something really unknown: $e');
  }
  return true;
}
