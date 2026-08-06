import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 用户仓库测试
/// 测试 Token 管理和登录流程的关键场景
void main() {
  group('tokenExpired - Token 验证测试', () {
    test('应该拒绝 null token', () {
      // Arrange
      final String? nullToken = null;

      // Act
      final result = tokenExpired(nullToken);

      // Assert
      expect(result, isTrue, reason: 'null token 应该被判定为已过期');
    });

    test('应该拒绝空字符串 token', () {
      // Arrange
      final String emptyToken = '';

      // Act
      final result = tokenExpired(emptyToken);

      // Assert
      expect(result, isTrue, reason: '空字符串 token 应该被判定为已过期');
    });

    test('应该拒绝无效格式的 token', () {
      // Arrange
      final invalidToken = 'not-a-valid-jwt-token';

      // Act
      final result = tokenExpired(invalidToken);

      // Assert
      expect(result, isTrue, reason: '无效格式的 token 应该被判定为已过期');
    });
  });

  group('UserRepoLocal.loginAfter - 登录后处理测试', () {
    test('应该在服务端返回空 token 时抛出异常', () {
      // Arrange
      final repo = UserRepoLocal.to;
      final payloadWithEmptyToken = {
        'uid': 'user123',
        'token': '', // 空字符串 token
        'refreshtoken': 'valid_refresh_token',
        'nickname': 'Test User',
      };

      // Act & Assert
      expect(
        () => repo.validateLoginPayload(payloadWithEmptyToken),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('token'),
          ),
        ),
        reason: '服务端返回空 token 时应该抛出 ArgumentError',
      );
    });

    test('应该在服务端返回 null token 时抛出异常', () {
      // Arrange
      final repo = UserRepoLocal.to;
      final payloadWithNullToken = {
        'uid': 'user123',
        'token': null, // null token
        'refreshtoken': 'valid_refresh_token',
        'nickname': 'Test User',
      };

      // Act & Assert
      expect(
        () => repo.validateLoginPayload(payloadWithNullToken),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('token'),
          ),
        ),
        reason: '服务端返回 null token 时应该抛出 ArgumentError',
      );
    });

    test('应该在服务端返回空 refreshToken 时抛出异常', () {
      // Arrange
      final repo = UserRepoLocal.to;
      final payloadWithEmptyRefreshToken = {
        'uid': 'user123',
        'token': 'valid_access_token_that_is_long_enough',
        'refreshtoken': '', // 空字符串 refresh token
        'nickname': 'Test User',
      };

      // Act & Assert
      expect(
        () => repo.validateLoginPayload(payloadWithEmptyRefreshToken),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('refreshtoken'),
          ),
        ),
        reason: '服务端返回空 refresh token 时应该抛出 ArgumentError',
      );
    });

    test('应该在缺少 uid 时抛出异常', () {
      // Arrange
      final repo = UserRepoLocal.to;
      final payloadWithoutUid = {
        'token': 'valid_access_token_that_is_long_enough',
        'refreshtoken': 'valid_refresh_token',
        'nickname': 'Test User',
        // uid 缺失
      };

      // Act & Assert
      expect(
        () => repo.validateLoginPayload(payloadWithoutUid),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('uid'),
          ),
        ),
        reason: '服务端返回缺少 uid 时应该抛出 ArgumentError',
      );
    });

    test('应该在 token 长度小于 10 时抛出异常', () {
      // Arrange
      final repo = UserRepoLocal.to;
      final payloadWithShortToken = {
        'uid': 'user123',
        'token': 'short', // 长度小于 10
        'refreshtoken': 'valid_refresh_token',
        'nickname': 'Test User',
      };

      // Act & Assert
      expect(
        () => repo.validateLoginPayload(payloadWithShortToken),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('token'),
          ),
        ),
        reason: 'token 长度小于 10 时应该抛出 ArgumentError',
      );
    });

    test('应该在所有字段都有效时验证通过', () {
      // Arrange
      final repo = UserRepoLocal.to;
      final validPayload = {
        'uid': 'user123',
        'token': 'valid_access_token_that_is_long_enough',
        'refreshtoken': 'valid_refresh_token',
        'nickname': 'Test User',
        'avatar': 'https://example.com/avatar.jpg',
      };

      // Act & Assert
      expect(
        () => repo.validateLoginPayload(validPayload),
        returnsNormally,
        reason: '所有字段都有效时应该验证通过',
      );
    });
  });
}
