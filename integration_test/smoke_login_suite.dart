// integration_test/smoke_login_suite.dart — 冒烟 + 登录合并入口
// 共享一次 App 启动，避免每个文件重复等待 VM 连接
import 'smoke/smoke_test.dart' as smoke;
import 'login_test.dart' as login;

void main() {
  smoke.main();
  login.main();
}
