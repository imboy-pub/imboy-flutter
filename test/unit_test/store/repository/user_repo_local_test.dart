import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show serviceContainer;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
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

  group('UserRepoLocal.loginAfter - 身份绑定落盘（A01-NC-5）', () {
    final secure = <String, String>{};
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    PathProviderPlatform? previousPathProvider;

    setUp(() async {
      // 先钉好平台桩，再初始化存储，最后清理跨用例残留标记——顺序敏感：
      // 文件内更早的 quitLogin 组会让 E2EE purge 失败留下 e2eePurgePending，
      // 本组 loginAfter 一进来就会走补救 purge（失败即抛 E2eeSecretPurgeException）
      secure.clear();
      previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _OwnedCachePaths();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secure[key];
              case 'write':
                secure[key!] = args['value'] as String;
                return null;
              case 'delete':
                secure.remove(key);
                return null;
              case 'readAll':
                return secure;
              case 'deleteAll':
                secure.clear();
                return null;
            }
            return null;
          });
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
      SqliteService.setDbUnavailableForTest();
      // 清掉前序用例可能留下的失败标记，阻断后台 quitLogin 触发链
      UserRepoLocal.to.clearTokenDecryptionFailureFlag();
      UserRepoLocal.to.clearAuthTransitionFailureForTest();
      // loginAfter 成功腿的后台任务（feature refresh/push/uploader 恢复）
      // 会经 HttpClient.client 发请求，挂通用 200 响应适配器
      HttpClient.adapterForTest = _GenericOkAdapter();
      serviceContainer.put(
        HttpClient(options: BaseOptions(baseUrl: Env().apiBaseUrl)),
      );
    });

    tearDown(() async {
      HttpClient.adapterForTest = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
      if (previousPathProvider != null) {
        PathProviderPlatform.instance = previousPathProvider!;
      }
    });

    test(
      '提交 alice：lastLoginAccount/currentUid/currentUser/token 历史绑定一致',
      () async {
        final payload = Map<String, dynamic>.from({
          'uid': '2002',
          'token': 'synthetic-access-token-2002',
          'refreshtoken': 'synthetic-refresh-2002',
          'nickname': 'Alice',
          'account': 'alice@imboy.pub',
        });

        final ok = await UserRepoLocal.to.loginAfter(
          'alice@imboy.pub',
          payload,
        );
        expect(ok, isTrue);
        // loginHistory 为 unawaited 写入，微任务级即完成，稍作沉淀
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // 提交 account ↔ lastLoginAccount 绑定（A01 行④核心断言）
        expect(UserRepoLocal.to.lastLoginAccount, 'alice@imboy.pub');
        // 会话身份：currentUid == payload uid
        expect(UserRepoLocal.to.currentUid, '2002');
        expect(UserRepoLocal.to.isLoggedIn, isTrue);
        // token 只进安全存储，不进明文 currentUser
        expect(secure['secure_token'], 'synthetic-access-token-2002');
        expect(secure['secure_refresh_token'], 'synthetic-refresh-2002');
        final current = StorageService.getMap(Keys.currentUser);
        expect(current['nickname'], 'Alice');
        expect(current['account'], 'alice@imboy.pub');
        expect(
          current.containsKey('token'),
          isFalse,
          reason: 'token 必须从 currentUser 明文 Map 剥离',
        );
        expect(current.containsKey('refreshtoken'), isFalse);
        // 登录历史首元素 == 提交 account
        expect(
          StorageService.to.getStringList(Keys.loginHistory)?.first,
          'alice@imboy.pub',
        );
      },
    );

    test('换账号登录：历史去重置顶，currentUid 跟随最新会话', () async {
      await UserRepoLocal.to.loginAfter('alice@imboy.pub', {
        'uid': '2002',
        'token': 'synthetic-access-token-2002',
        'refreshtoken': 'synthetic-refresh-2002',
        'nickname': 'Alice',
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await UserRepoLocal.to.loginAfter('bob@imboy.pub', {
        'uid': '2003',
        'token': 'synthetic-access-token-2003',
        'refreshtoken': 'synthetic-refresh-2003',
        'nickname': 'Bob',
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(StorageService.to.getStringList(Keys.loginHistory), [
        'bob@imboy.pub',
        'alice@imboy.pub',
      ], reason: '新账号置顶、旧账号保留（去重）');
      expect(UserRepoLocal.to.currentUid, '2003');
      expect(UserRepoLocal.to.lastLoginAccount, 'bob@imboy.pub');

      // 旧账号重登：去重后再次置顶
      await UserRepoLocal.to.loginAfter('alice@imboy.pub', {
        'uid': '2002',
        'token': 'synthetic-access-token-2002b',
        'refreshtoken': 'synthetic-refresh-2002b',
        'nickname': 'Alice',
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(StorageService.to.getStringList(Keys.loginHistory), [
        'alice@imboy.pub',
        'bob@imboy.pub',
      ]);
      expect(UserRepoLocal.to.currentUid, '2002');
      expect(secure['secure_token'], 'synthetic-access-token-2002b');
    });
  });
}

/// 通用 200 空响应适配器：喂给登录后台任务（feature/push/uploader 恢复）
class _GenericOkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"code":0,"payload":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// E2EE purge 依赖的缓存目录桩（含 getApplicationCachePath，
/// unit_test 全局 config 的 fake 未实现该方法，purge 会抛
/// E2eeSecretPurgeException 并留下 e2eePurgePending 标记）
class _OwnedCachePaths extends PathProviderPlatform {
  String get _tmp => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationCachePath() async => _tmp;

  @override
  Future<String?> getTemporaryPath() async => _tmp;

  @override
  Future<String?> getApplicationSupportPath() async => _tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tmp;

  @override
  Future<String?> getLibraryPath() async => _tmp;
}
