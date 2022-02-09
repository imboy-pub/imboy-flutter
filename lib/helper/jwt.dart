import 'package:imboy/helper/datetime.dart';
import 'package:jose/jose.dart';

/// 验证token是否过期
bool token_expired(String token) {
  try {
    var jwt = JsonWebToken.unverified(token);
    // 极端情况下扣除2秒
    int ts = DateTimeHelper.currentTimeMillis() - 2000;
    // debugPrint(">>> on jwt claims ${jwt.claims}, ${ts > jwt.claims['exp']}");
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
