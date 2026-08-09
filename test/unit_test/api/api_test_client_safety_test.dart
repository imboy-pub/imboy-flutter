import 'package:test/test.dart';

import 'api_test_client.dart';

void main() {
  test('业务 POST 按 client 实际目标地址判断，不能被环境变量误导', () async {
    final client = ApiTestClient(baseUrl: 'https://pro.imboy.pub');
    addTearDown(client.close);

    await expectLater(
      client.post('/api/v1/group/task/create'),
      throwsA(isA<StateError>()),
    );
  });
}
