import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/shamir_secret_sharing.dart';

void main() {
  group('ShamirSecretSharing', () {
    test('should split secret into shares', () {
      // Arrange
      final secret = 'This is a test secret for Shamir Secret Sharing';
      final secretBytes = Uint8List.fromList(secret.codeUnits);
      const n = 5; // 总分片数
      const k = 3; // 恢复阈值

      // Act
      final shares = ShamirSecretSharing.splitSecret(secretBytes, n, k);

      // Assert
      expect(shares.length, equals(n));

      // 验证每个分片都有必要的字段
      for (final share in shares) {
        expect(share.containsKey('index'), isTrue);
        expect(share.containsKey('x'), isTrue);
        expect(share.containsKey('y'), isTrue);
        expect(share['x'], isPositive);
        expect(share['y'], isA<BigInt>());
      }
    });

    test('should combine shares to recover secret', () {
      // Arrange
      final secret = 'This is a test secret for Shamir Secret Sharing';
      final secretBytes = Uint8List.fromList(secret.codeUnits);
      const n = 5;
      const k = 3;

      // Act
      final shares = ShamirSecretSharing.splitSecret(secretBytes, n, k);

      // 只使用 k 个分片来重建
      final sharesToCombine = shares.take(k).toList();
      final recoveredBytes = ShamirSecretSharing.combineShares(sharesToCombine);
      final recoveredSecret = String.fromCharCodes(recoveredBytes);

      // Assert
      expect(recoveredSecret, equals(secret));
    });

    test('should throw error when N <= K', () {
      // Arrange
      final secret = 'Test secret';
      final secretBytes = Uint8List.fromList(secret.codeUnits);
      const n = 3;
      const k = 3;

      // Act & Assert
      expect(
        () => ShamirSecretSharing.splitSecret(secretBytes, n, k),
        throwsArgumentError,
      );
    });

    test('should throw error when K < 2', () {
      // Arrange
      final secret = 'Test secret';
      final secretBytes = Uint8List.fromList(secret.codeUnits);
      const n = 5;
      const k = 1;

      // Act & Assert
      expect(
        () => ShamirSecretSharing.splitSecret(secretBytes, n, k),
        throwsArgumentError,
      );
    });

    test('should throw error when shares count is less than 2', () {
      // Arrange
      final shares = <Map<String, dynamic>>[];

      // Act & Assert
      expect(
        () => ShamirSecretSharing.combineShares(shares),
        throwsArgumentError,
      );
    });

    test('should recover secret with different share combinations', () {
      // Arrange
      final secret = 'Test secret for combination verification';
      final secretBytes = Uint8List.fromList(secret.codeUnits);
      const n = 5;
      const k = 2;

      // Act
      final shares = ShamirSecretSharing.splitSecret(secretBytes, n, k);

      // 测试不同的分片组合
      final combinations = [
        [0, 1], // 前两个
        [1, 2], // 中间两个
        [3, 4], // 最后两个
        [0, 4], // 首尾两个
      ];

      for (final combo in combinations) {
        final selectedShares = combo.map((i) => shares[i]).toList();
        final recoveredBytes = ShamirSecretSharing.combineShares(
          selectedShares,
        );
        final recoveredSecret = String.fromCharCodes(recoveredBytes);

        expect(
          recoveredSecret,
          equals(secret),
          reason: 'Failed for combination $combo',
        );
      }
    });

    test('should handle empty secret', () {
      // Arrange
      final secret = '';
      final secretBytes = Uint8List.fromList([]);
      const n = 3;
      const k = 2;

      // Act
      final shares = ShamirSecretSharing.splitSecret(secretBytes, n, k);
      final recoveredBytes = ShamirSecretSharing.combineShares(
        shares.take(k).toList(),
      );
      final recoveredSecret = String.fromCharCodes(recoveredBytes);

      // Assert
      expect(recoveredSecret, equals(secret));
    });

    test('should handle large secret', () {
      // Arrange
      final largeSecret = 'A' * 1000;
      final secretBytes = Uint8List.fromList(largeSecret.codeUnits);
      const n = 5;
      const k = 3;

      // Act
      final shares = ShamirSecretSharing.splitSecret(secretBytes, n, k);
      final recoveredBytes = ShamirSecretSharing.combineShares(
        shares.take(k).toList(),
      );
      final recoveredSecret = String.fromCharCodes(recoveredBytes);

      // Assert
      expect(recoveredSecret, equals(largeSecret));
    });
  });
}
