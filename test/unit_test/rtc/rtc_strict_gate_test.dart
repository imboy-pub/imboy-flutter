import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/rtc/rtc_e2e_helpers.dart';

void main() {
  test('正式验收条件缺失必须抛出失败，不能返回 skip', () {
    expect(
      () => rtcSetupUnavailable('missing peer', strict: true),
      throwsA(isA<TestFailure>()),
    );
  });
  if (lkRtcStrict) {
    testWidgets('编译开关 strict 进入单机与双机前置门，缺 RUN 均失败', (tester) async {
      expect(lkRtcRunEnabled, isFalse);
      expect(
        () => requireOneDeviceSetup(tester, 'one'),
        throwsA(isA<TestFailure>()),
      );
      expect(
        () => requireTwoDeviceSetup(tester, 'two'),
        throwsA(isA<TestFailure>()),
      );
    });
  }
}
