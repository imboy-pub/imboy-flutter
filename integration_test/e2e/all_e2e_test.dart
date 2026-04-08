// Flutter E2E 联调测试 - 全套件入口
//
// 统一运行所有 E2E 联调测试。
//
// 使用方法：
// flutter test integration_test/e2e/all_e2e_test.dart \
//   --dart-define=APP_ENV=local_office \
//   --dart-define=API_BASE_URL=http://192.168.2.19:9800 \
//   --dart-define=WS_URL=ws://192.168.2.19:9800/ws \
//   --dart-define=TEST_PHONE=13800138000 \
//   --dart-define=TEST_PASSWORD=test123456

// 导入所有 E2E 测试文件
// ignore: unused_import
import 'api_e2e_test.dart' as api_e2e;
// ignore: unused_import
import 'ws_e2e_test.dart' as ws_e2e;

// Flutter integration_test 框架会自动发现并运行所有导入文件中的 main()
// 但如果需要显式控制执行顺序，可以使用以下方式：
void main() {
  api_e2e.main();
  ws_e2e.main();
}
