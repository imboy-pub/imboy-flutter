// 标准 integration_test driver：配合 flutter drive --use-application-binary
// 使用（设备存储不足无法走 flutter test 的整包安装路径时的替代通道）。
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
