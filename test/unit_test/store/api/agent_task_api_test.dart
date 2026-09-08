import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/agent_task_api.dart';

/// APP-01-A03：审批 API 客户端契约——空 task_id 不发请求（短路返回 false），
/// 防止 widget 重建/重复点击产生的无效请求。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('空 task_id 短路：approve/reject 不抛异常且返回 false', () async {
    final api = AgentTaskApi();
    expect(await api.approve(''), isFalse);
    expect(await api.reject(''), isFalse);
    expect(await api.approve('   '), isFalse);
  });
}
