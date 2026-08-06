import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/routes.dart';

void main() {
  group('Moment routes', () {
    test('AppRoutes 应包含朋友圈路由常量', () {
      expect(AppRoutes.momentFeed, '/moment/feed');
      expect(AppRoutes.momentCreate, '/moment/create');
      expect(AppRoutes.momentRoot, '/moment');
    });
  });
}
