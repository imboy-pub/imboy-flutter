import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('UserRepoLocal.quitLogin - 游标清理测试', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    // BUG#119 附带发现：聊天历史回填游标（msg_history_seq_<uk3>）只写不
    // 清理，登出后残留，换号/重装后无新消息的会话持续「暂无数据」。
    test('应该清理全部 msg_history_seq_* 前缀键', () async {
      // Arrange
      await StorageService.to.setString(Keys.currentUid, '1817128709888507904');
      await StorageService.to.setInt('msg_history_seq_c2c_1_2', 42);
      await StorageService.to.setInt('msg_history_seq_C2G_1_3', 7);

      // Act
      await UserRepoLocal.to.quitLogin();

      // Assert
      expect(
        StorageService.to.containsKey('msg_history_seq_c2c_1_2'),
        isFalse,
        reason: 'quitLogin 必须清理 C2C 会话回填游标',
      );
      expect(
        StorageService.to.containsKey('msg_history_seq_C2G_1_3'),
        isFalse,
        reason: 'quitLogin 必须清理 C2G 会话回填游标',
      );
    });

    test('应该只清理游标键，不动其他键', () async {
      // Arrange
      await StorageService.to.setString(Keys.currentUid, '1817128709888507904');
      await StorageService.to.setString(
        Keys.lastLoginAccount,
        'demo@imboy.pub',
      );
      await StorageService.to.setInt('msg_history_seq_c2c_1_2', 42);

      // Act
      await UserRepoLocal.to.quitLogin();

      // Assert
      expect(
        StorageService.to.getString(Keys.lastLoginAccount),
        'demo@imboy.pub',
        reason: '登录历史账号不属于游标，不应被清理',
      );
      expect(StorageService.to.containsKey('msg_history_seq_c2c_1_2'), isFalse);
    });
  });
}
