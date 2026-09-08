import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/passport_notifier.dart';

void main() {
  test('JVerify failure keeps the diagnostic code', () {
    expect(formatJverifyLoginError(6001, '错误'), '一键登录失败（错误码 6001）：错误');
    expect(formatJverifyLoginError(-997, null), '一键登录失败（错误码 -997）');
  });
}
