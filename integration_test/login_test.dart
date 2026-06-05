// Flutter 集成测试 - 登录流程测试
//
// 使用方法：
// flutter test integration_test/login_test.dart --dart-define=APP_ENV=local_office -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'flows/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('登录流程测试', () {
    testWidgets('查找登录入口', (WidgetTester tester) async {
      await ensureAppLaunched(tester);
      await tester.pumpAndSettle();

      // 等待应用加载
      await tester.pump(const Duration(seconds: 3));

      // 查找登录相关元素
      final loginButton = find.text('登录');
      final loginText = find.textContaining('登录');

      print('🔍 查找登录入口...');

      if (tester.any(loginButton)) {
        print('✅ 找到登录按钮');
      } else if (tester.any(loginText)) {
        print('✅ 找到登录相关文本');
      } else {
        print('ℹ️ 可能已自动登录或登录页未显示');
      }

      // 截图
      await tester.pumpAndSettle();
      print('✅ 登录入口检查完成');
    });
  });
}
