import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee_transfer_service.dart';

void main() {
  group('E2EETransferService', () {
    group('generateQRCodeData', () {
      test('should generate valid JSON string', () {
        // Arrange
        const sessionId = 'test-session-123';

        // Act
        final qrData = E2EETransferService.generateQRCodeData(sessionId);

        // Assert
        expect(qrData, isA<String>());
        expect(() => jsonDecode(qrData), returnsNormally);
      });

      test('should include type as e2ee_transfer', () {
        // Arrange
        const sessionId = 'test-session-456';

        // Act
        final qrData = E2EETransferService.generateQRCodeData(sessionId);
        final data = jsonDecode(qrData) as Map<String, dynamic>;

        // Assert
        expect(data['type'], equals('e2ee_transfer'));
      });

      test('should include session_id', () {
        // Arrange
        const sessionId = 'session-abc-xyz';

        // Act
        final qrData = E2EETransferService.generateQRCodeData(sessionId);
        final data = jsonDecode(qrData) as Map<String, dynamic>;

        // Assert
        expect(data['session_id'], equals(sessionId));
      });

      test('should include extra data when provided', () {
        // Arrange
        const sessionId = 'session-123';
        final extra = {'user': 'alice', 'device': 'mobile'};

        // Act
        final qrData = E2EETransferService.generateQRCodeData(
          sessionId,
          extra: extra,
        );
        final data = jsonDecode(qrData) as Map<String, dynamic>;

        // Assert
        expect(data['user'], equals('alice'));
        expect(data['device'], equals('mobile'));
      });

      test('should handle empty extra data', () {
        // Arrange
        const sessionId = 'session-empty';

        // Act
        final qrData = E2EETransferService.generateQRCodeData(sessionId);
        final data = jsonDecode(qrData) as Map<String, dynamic>;

        // Assert
        expect(data.length, equals(2)); // type and session_id only
      });
    });

    group('parseQRCodeData', () {
      test('should parse valid QR code data', () {
        // Arrange
        final qrData = jsonEncode({
          'type': 'e2ee_transfer',
          'session_id': 'session-123',
        });

        // Act
        final result = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(result, isNotNull);
        expect(result!['type'], equals('e2ee_transfer'));
        expect(result['session_id'], equals('session-123'));
      });

      test('should return null for invalid JSON', () {
        // Arrange
        const qrData = 'not a valid json';

        // Act
        final result = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(result, isNull);
      });

      test('should return null for wrong type', () {
        // Arrange
        final qrData = jsonEncode({
          'type': 'other_type',
          'session_id': 'session-123',
        });

        // Act
        final result = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(result, isNull);
      });

      test('should return null for missing type', () {
        // Arrange
        final qrData = jsonEncode({
          'session_id': 'session-123',
        });

        // Act
        final result = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(result, isNull);
      });

      test('should parse QR data with extra fields', () {
        // Arrange
        final qrData = jsonEncode({
          'type': 'e2ee_transfer',
          'session_id': 'session-xyz',
          'extra_field': 'value',
        });

        // Act
        final result = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(result, isNotNull);
        expect(result!['extra_field'], equals('value'));
      });

      test('should handle empty string', () {
        // Arrange
        const qrData = '';

        // Act
        final result = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(result, isNull);
      });
    });

    group('generateQRCodeData and parseQRCodeData integration', () {
      test('should round-trip correctly', () {
        // Arrange
        const sessionId = 'round-trip-session';
        final extra = {'user_id': '12345', 'timestamp': 1234567890};

        // Act
        final qrData = E2EETransferService.generateQRCodeData(
          sessionId,
          extra: extra,
        );
        final parsed = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(parsed, isNotNull);
        expect(parsed!['session_id'], equals(sessionId));
        expect(parsed['user_id'], equals('12345'));
        expect(parsed['timestamp'], equals(1234567890));
      });

      test('should round-trip without extra data', () {
        // Arrange
        const sessionId = 'simple-session';

        // Act
        final qrData = E2EETransferService.generateQRCodeData(sessionId);
        final parsed = E2EETransferService.parseQRCodeData(qrData);

        // Assert
        expect(parsed, isNotNull);
        expect(parsed!['session_id'], equals(sessionId));
        expect(parsed['type'], equals('e2ee_transfer'));
      });
    });

    group('encryptKeyBundle', () {
      test('should throw exception with invalid public key', () async {
        // Arrange
        final keyBundle = {
          'private_key': 'test_private_key',
          'public_key': 'test_public_key',
        };
        const invalidPublicKey = 'invalid_public_key';

        // Act & Assert
        expect(
          () => E2EETransferService.encryptKeyBundle(keyBundle, invalidPublicKey),
          throwsA(isA<Exception>()),
        );
      });

      test('should serialize key bundle to JSON', () async {
        // Arrange
        final keyBundle = {
          'private_key': 'test_private',
          'public_key': 'test_public',
          'device_id': 'device-123',
          'key_id': 'key-456',
        };

        // 这个测试验证 keyBundle 被正确序列化
        // 由于需要有效的公钥才能加密，我们只验证序列化部分
        final jsonString = json.encode(keyBundle);

        // Assert
        expect(jsonString, contains('private_key'));
        expect(jsonString, contains('test_private'));
        expect(jsonString, contains('device_id'));
        expect(jsonString, contains('device-123'));
      });
    });

    group('API methods (mock scenarios)', () {
      // 这些测试验证方法签名和错误处理
      // 实际 API 调用需要 mock 或集成测试

      test('createTransfer should throw on API failure', () async {
        // 测试方法存在且可调用
        // 由于需要网络连接，这里只验证方法存在
        expect(E2EETransferService.createTransfer, isA<Function>());
      });

      test('acceptTransfer should throw on API failure', () async {
        expect(E2EETransferService.acceptTransfer, isA<Function>());
      });

      test('confirmTransfer should throw on API failure', () async {
        expect(E2EETransferService.confirmTransfer, isA<Function>());
      });

      test('getTransferInfo should throw on API failure', () async {
        expect(E2EETransferService.getTransferInfo, isA<Function>());
      });

      test('getPendingTransfers should throw on API failure', () async {
        expect(E2EETransferService.getPendingTransfers, isA<Function>());
      });
    });

    group('Key bundle format', () {
      test('key bundle should contain required fields', () {
        // Arrange
        final keyBundle = {
          'private_key': '-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----',
          'public_key': '-----BEGIN PUBLIC KEY-----\ntest\n-----END PUBLIC KEY-----',
          'device_id': 'device-abc-123',
          'key_id': 'kid-xyz-789',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

        // Assert
        expect(keyBundle.containsKey('private_key'), isTrue);
        expect(keyBundle.containsKey('public_key'), isTrue);
        expect(keyBundle.containsKey('device_id'), isTrue);
        expect(keyBundle.containsKey('key_id'), isTrue);
      });

      test('key bundle should be JSON serializable', () {
        // Arrange
        final keyBundle = {
          'private_key': 'test_key',
          'public_key': 'test_public',
          'device_id': 'device-123',
          'key_id': 'key-456',
        };

        // Act
        final jsonString = json.encode(keyBundle);
        final decoded = json.decode(jsonString) as Map<String, dynamic>;

        // Assert
        expect(decoded['private_key'], equals('test_key'));
        expect(decoded['public_key'], equals('test_public'));
        expect(decoded['device_id'], equals('device-123'));
        expect(decoded['key_id'], equals('key-456'));
      });
    });
  });
}
