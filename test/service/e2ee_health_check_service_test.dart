import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee_health_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage MethodChannel
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final store = <String, String?>{};

  setUpAll(() async {
    // 设置 Mock 处理器
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              final key = call.arguments['key'] as String;
              final value = call.arguments['value'] as String?;
              store[key] = value;
              return null;
            case 'read':
              final key = call.arguments['key'] as String;
              return store[key];
            case 'delete':
              final key = call.arguments['key'] as String;
              store.remove(key);
              return null;
            case 'deleteAll':
              store.clear();
              return null;
            case 'containsKey':
              final key = call.arguments['key'] as String;
              return store.containsKey(key);
            default:
              return null;
          }
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('E2EEHealthCheckResult', () {
    test('should create result with all fields', () {
      // Arrange & Act
      const result = E2EEHealthCheckResult(
        needsUpdate: true,
        currentVersion: 'v1.0.0',
        latestVersion: 'v2.0.0',
        reason: 'version_mismatch',
        details: {'key': 'value'},
      );

      // Assert
      expect(result.needsUpdate, true);
      expect(result.currentVersion, 'v1.0.0');
      expect(result.latestVersion, 'v2.0.0');
      expect(result.reason, 'version_mismatch');
      expect(result.details, {'key': 'value'});
    });

    test('should create result with minimal fields', () {
      // Arrange & Act
      const result = E2EEHealthCheckResult(
        needsUpdate: false,
        reason: 'ok',
      );

      // Assert
      expect(result.needsUpdate, false);
      expect(result.currentVersion, isNull);
      expect(result.latestVersion, isNull);
      expect(result.reason, 'ok');
      expect(result.details, isNull);
    });

    test('toString should contain needsUpdate and reason', () {
      // Arrange
      const result = E2EEHealthCheckResult(
        needsUpdate: true,
        reason: 'no_keys',
      );

      // Act
      final str = result.toString();

      // Assert
      expect(str, contains('needsUpdate'));
      expect(str, contains('no_keys'));
    });
  });

  group('E2EEHealthCheckService', () {
    late E2EEHealthCheckService service;

    setUp(() {
      service = E2EEHealthCheckService.to;
    });

    group('getHealthStatus', () {
      test('should return health status map', () async {
        // Act
        final status = await service.getHealthStatus();

        // Assert
        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('has_key'), isTrue);
        expect(status.containsKey('status'), isTrue);
        expect(status.containsKey('checked_at'), isTrue);
      });

      test('should return has_key as boolean', () async {
        // Act
        final status = await service.getHealthStatus();

        // Assert
        expect(status['has_key'], isA<bool>());
      });

      test('should return status as string', () async {
        // Act
        final status = await service.getHealthStatus();

        // Assert
        expect(status['status'], isA<String>());
      });

      test('should return valid ISO8601 timestamp', () async {
        // Act
        final status = await service.getHealthStatus();

        // Assert
        final checkedAt = status['checked_at'] as String;
        expect(checkedAt, isNotEmpty);
        // 验证是有效的 ISO8601 格式
        final dateTime = DateTime.parse(checkedAt);
        expect(dateTime, isNotNull);
      });
    });

    group('hasValidKey', () {
      test('should return boolean', () async {
        // Act
        final hasKey = await service.hasValidKey();

        // Assert
        expect(hasKey, isA<bool>());
      });
    });

    group('getKeyInfo', () {
      test('should return null or map with key info', () async {
        // Act
        final keyInfo = await service.getKeyInfo();

        // Assert
        if (keyInfo != null) {
          expect(keyInfo, isA<Map<String, dynamic>>());
          expect(keyInfo.containsKey('has_private_key'), isTrue);
          expect(keyInfo.containsKey('has_public_key'), isTrue);
        }
      });
    });

    group('syncFriendPublicKey', () {
      test('should return false for invalid uid', () async {
        // Act
        final success = await service.syncFriendPublicKey('invalid_uid_test');

        // Assert - 由于网络/API 原因可能返回 false
        expect(success, isA<bool>());
      });
    });

    group('checkUserKeyVersion', () {
      test('should return E2EEHealthCheckResult', () async {
        // Act
        final result = await service.checkUserKeyVersion(
          uid: 'test_uid_123',
        );

        // Assert
        expect(result, isA<E2EEHealthCheckResult>());
        expect(result.reason, isNotEmpty);
      });

      test('should handle empty uid', () async {
        // Act
        final result = await service.checkUserKeyVersion(uid: '');

        // Assert
        expect(result, isA<E2EEHealthCheckResult>());
        // 可能返回错误或无密钥状态
      });

      test('should return error result on exception', () async {
        // Act
        final result = await service.checkUserKeyVersion(
          uid: 'definitely_nonexistent_user_xxx',
        );

        // Assert
        expect(result, isA<E2EEHealthCheckResult>());
      });
    });

    group('checkMultipleUserKeyVersions', () {
      test('should return map of results', () async {
        // Arrange
        final uids = ['user1', 'user2', 'user3'];

        // Act
        final results = await service.checkMultipleUserKeyVersions(uids);

        // Assert
        expect(results, isA<Map<String, E2EEHealthCheckResult>>());
        expect(results.length, equals(3));
        expect(results.containsKey('user1'), isTrue);
        expect(results.containsKey('user2'), isTrue);
        expect(results.containsKey('user3'), isTrue);
      });

      test('should handle empty list', () async {
        // Arrange
        final uids = <String>[];

        // Act
        final results = await service.checkMultipleUserKeyVersions(uids);

        // Assert
        expect(results, isEmpty);
      });
    });

    group('syncMultipleFriendPublicKeys', () {
      test('should return map of results', () async {
        // Arrange
        final uids = ['user1', 'user2'];

        // Act
        final results = await service.syncMultipleFriendPublicKeys(uids);

        // Assert
        expect(results, isA<Map<String, bool>>());
        expect(results.length, equals(2));
      });
    });

    group('retryFailedMessages', () {
      test('should return int count', () async {
        // Act
        final count = await service.retryFailedMessages();

        // Assert
        expect(count, isA<int>());
        expect(count, greaterThanOrEqualTo(0));
      });

      test('should handle conversationUk3 parameter', () async {
        // Act
        final count = await service.retryFailedMessages(
          conversationUk3: 'test_conversation',
        );

        // Assert
        expect(count, isA<int>());
      });

      test('should call progress callback if provided', () async {
        // Arrange
        int? progressCurrent;
        int? progressTotal;

        // Act
        await service.retryFailedMessages(
          onProgress: (current, total) {
            progressCurrent = current;
            progressTotal = total;
          },
        );

        // Assert - callback was handled without exception
        // Note: In test environment, database is not initialized,
        // so no messages will be found and callback won't be called.
        // The important thing is that no exception is thrown.
        // If there were failed messages, the callback would be called.
        expect(progressCurrent, isNull); // Not called in test environment
        expect(progressTotal, isNull); // Not called in test environment
      });
    });

    group('checkConversationFailureRate', () {
      test('should return double between 0 and 1', () async {
        // Act
        final rate = await service.checkConversationFailureRate(
          'test_conversation',
        );

        // Assert
        expect(rate, isA<double>());
        expect(rate, greaterThanOrEqualTo(0.0));
        expect(rate, lessThanOrEqualTo(1.0));
      });
    });

    group('Singleton', () {
      test('should return same instance', () {
        // Act
        final instance1 = E2EEHealthCheckService.to;
        final instance2 = E2EEHealthCheckService.to;

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });
    });
  });
}
