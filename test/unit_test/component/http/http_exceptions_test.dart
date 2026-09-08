import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_exceptions.dart';

void main() {
  group('HttpException.toString', () {
    test('带 message 时 toString 返回 message 而非 Instance of', () {
      final e = BadRequestException(message: '请求语法错误', code: 400);

      expect(e.toString(), '请求语法错误');
    });

    test('无 message 时 toString 回退到类型名', () {
      final e = BadRequestException();

      expect(e.toString(), 'BadRequestException');
    });

    test('子类继承 toString：UnauthorisedException 显示人话文案', () {
      final e = UnauthorisedException(message: '没有权限');

      expect(e.toString(), '没有权限');
    });
  });
}
