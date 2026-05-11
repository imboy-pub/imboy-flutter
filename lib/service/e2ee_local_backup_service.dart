import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'e2ee_crypto_service.dart';

/// E2EE 本地备份服务
///
/// 提供备份导出/导入功能：
/// - 导出备份：加密私钥并生成 .enc 文件
/// - 导入备份：解密备份文件并恢复私钥
/// - 文件验证：验证备份文件格式和完整性
/// - 分享备份：通过邮件/云盘分享备份文件
///
/// 安全特性：
/// - 使用 PBKDF2-HMAC-SHA256 派生密钥（310,000 次迭代）
/// - 使用 AES-256-GCM 加密私钥
/// - SHA-256 校验和验证文件完整性
/// - 备份文件完全由用户控制，服务器不存储
///
/// @author Imboy Team
/// @since 2026-01-31
class E2EELocalBackupService {
  // ================================================================
  // 导出备份
  // ================================================================

  /// 导出 E2EE 密钥备份
  ///
  /// @param password 备份密码（必须 ≥ 8 位）
  /// @param privateKey PEM 格式的私钥
  /// @param publicKey PEM 格式的公钥
  /// @param deviceId 设备 ID
  /// @param keyId 密钥 ID
  /// @param userNotes 用户备注（可选）
  /// @returns 备份文件路径
  ///
  /// @throws ArgumentError 如果密码强度不足
  /// @throws Exception 如果加密失败
  ///
  /// @example
  /// ```dart
  /// try {
  ///   final filePath = await E2EELocalBackupService.exportBackup(
  ///     password: 'MyPass123',
  ///     privateKey: privateKeyPem,
  ///     publicKey: publicKeyPem,
  ///     deviceId: 'device-001',
  ///     keyId: 'key-abc123',
  ///     userNotes: '主手机备份',
  ///   );
  ///   print('备份已保存到: $filePath');
  /// } catch (e) {
  ///   print('备份失败: $e');
  /// }
  /// ```
  static Future<String> exportBackup({
    required String password,
    required String privateKey,
    required String publicKey,
    required String deviceId,
    required String keyId,
    String? userNotes,
  }) async {
    // 1. 验证密码强度
    _validatePassword(password);

    // 2. 构建备份数据（JSON）
    final backupData = {
      'version': E2EECryptoService.formatVersion,
      'device_id': deviceId,
      'private_key': privateKey,
      'public_key': publicKey,
      'key_id': keyId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // 3. 计算校验和
    final jsonString = json.encode(backupData);
    final plaintext = Uint8List.fromList(utf8.encode(jsonString));
    final checksum = E2EECryptoService.calculateChecksum(plaintext);
    backupData['checksum'] = 'sha256:$checksum';

    // 4. 生成随机参数
    final salt = E2EECryptoService.generateSalt();
    final iv = E2EECryptoService.generateIV();

    // 5. 派生密钥
    final derivedKey = await E2EECryptoService.deriveKey(password, salt);

    // 6. 加密数据（重新编码带校验和的 JSON）
    final jsonWithChecksum = json.encode(backupData);
    final plaintextWithChecksum = Uint8List.fromList(
      utf8.encode(jsonWithChecksum),
    );

    final encryptedResult = await E2EECryptoService.encryptAesGcm(
      plaintextWithChecksum,
      derivedKey,
      iv,
    );

    // 7. 构建备份文件
    final backupFile = await _buildBackupFile(
      salt: salt,
      iv: iv,
      authTag: encryptedResult['authTag']!,
      ciphertext: encryptedResult['ciphertext']!,
      userNotes: userNotes,
    );

    // 8. 保存到临时目录
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'imboy_e2ee_backup_$timestamp.enc';
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(backupFile);

    return filePath;
  }

  // ================================================================
  // 导入备份
  // ================================================================

  /// 测试密码是否正确（不完全解密，只测试密钥派生）
  ///
  /// @param filePath 备份文件路径
  /// @param password 待测试的密码
  /// @returns true 如果密码可能正确
  static Future<bool> testPassword({
    required String filePath,
    required String password,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final fileBytes = await file.readAsBytes();
      final header = _parseFileHeader(fileBytes);

      // 提取 salt
      int offset = 32;
      final salt = fileBytes.sublist(
        offset,
        offset + E2EECryptoService.saltLength,
      );

      // 尝试派生密钥（如果密码错误，派生的密钥也会不同）
      await E2EECryptoService.deriveKey(
        password,
        salt,
        iterations: header['iterations']!,
      );

      // 如果派生成功（没有抛出异常），说明密码格式正确
      // 但不能保证是正确的密码
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 导入 E2EE 密钥备份
  ///
  /// @param filePath 备份文件路径
  /// @param password 备份密码
  /// @returns 解密后的密钥数据 Map
  ///
  /// @throws ArgumentError 如果文件格式无效
  /// @throws ArgumentError 如果密码错误
  /// @throws ArgumentError 如果文件已损坏
  ///
  /// @example
  /// ```dart
  /// try {
  ///   final result = await E2EELocalBackupService.importBackup(
  ///     filePath: '/path/to/backup.enc',
  ///     password: 'MyStrongPassword123!',
  ///   );
  ///   print('密钥已恢复:');
  ///   print('设备 ID: ${result['device_id']}');
  ///   print('密钥 ID: ${result['key_id']}');
  /// } catch (e) {
  ///   print('导入失败: $e');
  /// }
  /// ```
  static Future<Map<String, dynamic>> importBackup({
    required String filePath,
    required String password,
  }) async {
    // 1. 读取备份文件
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('备份文件不存在: $filePath');
    }

    final fileBytes = await file.readAsBytes();

    // 2. 解析文件头
    final header = _parseFileHeader(fileBytes);

    // 3. 验证算法版本
    if (header['algorithm'] != E2EECryptoService.algorithmId) {
      throw ArgumentError('不支持的备份算法版本: ${header['algorithm']}');
    }

    // 4. 提取加密组件
    int offset = 32; // 文件头长度
    final salt = fileBytes.sublist(
      offset,
      offset + E2EECryptoService.saltLength,
    );
    offset += E2EECryptoService.saltLength;

    final iv = fileBytes.sublist(offset, offset + E2EECryptoService.ivLength);
    offset += E2EECryptoService.ivLength;

    final authTag = fileBytes.sublist(
      offset,
      offset + E2EECryptoService.authTagLength,
    );
    offset += E2EECryptoService.authTagLength;

    // 计算加密数据长度
    // 文件格式: [头 32] + [salt 16] + [iv 12] + [authTag 16] + [密文] + [备注长度 4]? + [备注内容]?
    // 如果有备注，文件最后 4 字节是备注长度，然后是备注内容
    // 如果没有备注，所有剩余字节都是密文
    final ciphertext = _extractCiphertext(fileBytes, offset);

    // 5. 派生密钥
    final derivedKey = await E2EECryptoService.deriveKey(
      password,
      salt,
      iterations: header['iterations']!,
    );

    // 6. 解密数据
    final plaintext = await E2EECryptoService.decryptAesGcm(
      ciphertext,
      authTag,
      derivedKey,
      iv,
    );

    // 7. 解析备份数据
    final backupData = json.decode(utf8.decode(plaintext));

    // 8. 验证版本
    if (backupData['version'] != E2EECryptoService.formatVersion) {
      throw ArgumentError('不支持的备份版本: ${backupData['version']}');
    }

    // 9. 验证校验和
    final storedChecksum = backupData['checksum'];
    if (!(storedChecksum as String).startsWith('sha256:')) {
      throw ArgumentError('无效的校验和格式');
    }
    final expectedChecksum = storedChecksum.substring(7); // 去掉 'sha256:' 前缀

    // 移除 checksum 字段后重新计算
    final dataWithoutChecksum = Map<String, dynamic>.from(backupData as Map<dynamic, dynamic>);
    dataWithoutChecksum.remove('checksum');

    final jsonWithoutChecksum = json.encode(dataWithoutChecksum);
    final actualChecksum = E2EECryptoService.calculateChecksum(
      Uint8List.fromList(utf8.encode(jsonWithoutChecksum)),
    );

    if (actualChecksum != expectedChecksum) {
      throw ArgumentError('备份文件已损坏（校验和不匹配）');
    }

    // 10. 返回密钥数据
    return {
      'device_id': backupData['device_id'],
      'key_id': backupData['key_id'],
      'private_key': backupData['private_key'],
      'public_key': backupData['public_key'],
      'created_at': backupData['created_at'],
      'file_size': fileBytes.length,
    };
  }

  // ================================================================
  // 文件验证
  // ================================================================

  /// 验证备份文件格式（不解密）
  ///
  /// @param filePath 备份文件路径
  /// @returns 文件信息 Map
  ///
  /// @throws ArgumentError 如果文件格式无效
  ///
  /// @example
  /// ```dart
  /// try {
  ///   final info = await E2EELocalBackupService.verifyBackupFile(filePath);
  ///   print('版本: ${info['version']}');
  ///   print('算法: ${info['algorithm']}');
  ///   print('文件大小: ${info['file_size']} bytes');
  /// } catch (e) {
  ///   print('文件验证失败: $e');
  /// }
  /// ```
  static Future<Map<String, dynamic>> verifyBackupFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('备份文件不存在: $filePath');
    }

    final fileBytes = await file.readAsBytes();
    final header = _parseFileHeader(fileBytes);

    return {
      'version': header['version'],
      'algorithm': header['algorithm'],
      'iterations': header['iterations'],
      'salt_length': header['salt_length'],
      'iv_length': header['iv_length'],
      'tag_length': header['tag_length'],
      'file_size': fileBytes.length,
      'is_valid': true,
    };
  }

  // ================================================================
  // 分享备份
  // ================================================================

  /// 分享备份文件（通过邮件/云盘等）
  ///
  /// @param filePath 备份文件路径
  /// @param shareText 分享时的附加文本（可选）
  ///
  /// @example
  /// ```dart
  /// await E2EELocalBackupService.shareBackup(
  ///   filePath,
  ///   shareText: '这是我的 E2EE 密钥备份文件，请妥善保管',
  /// );
  /// ```
  static Future<void> shareBackup(String filePath, {String? shareText}) async {
    final file = XFile(filePath);
    final text = shareText ?? 'Imboy E2EE 密钥备份文件';

    // ignore: deprecated_member_use
    await Share.shareXFiles([file], text: text);
  }

  // ================================================================
  // 密码强度验证
  // ================================================================

  /// 验证密码强度
  ///
  /// 要求：
  /// - 长度 ≥ 8 位
  ///
  /// @param password 待验证的密码
  /// @returns true 如果密码强度足够，否则 false
  ///
  /// @throws ArgumentError 如果密码不符合要求
  static void _validatePassword(String password) {
    if (password.length < 8) {
      throw ArgumentError('密码长度至少需要 8 位');
    }

    // 密码长度要求已满足，无需额外复杂度检查
  }

  /// 计算密码强度（0-1，1 为最强）
  ///
  /// @param password 密码
  /// @returns 强度分数（0.0 - 1.0）
  static double calculatePasswordStrength(String password) {
    double strength = 0.0;

    // 长度（最多 100%）
    if (password.length >= 8) strength += 0.50;
    if (password.length >= 12) strength += 0.30;
    if (password.length >= 16) strength += 0.20;

    return strength.clamp(0.0, 1.0);
  }

  // ================================================================
  // 内部函数 - 构建备份文件
  // ================================================================

  /// 构建备份文件
  static Future<Uint8List> _buildBackupFile({
    required Uint8List salt,
    required Uint8List iv,
    required Uint8List authTag,
    required Uint8List ciphertext,
    String? userNotes,
  }) async {
    final output = BytesBuilder();

    // 1. 写入文件头（32 bytes）
    output.add(_buildFileHeader());

    // 2. 写入 Salt
    output.add(salt);

    // 3. 写入 IV
    output.add(iv);

    // 4. 写入 Auth Tag
    output.add(authTag);

    // 5. 写入密文
    output.add(ciphertext);

    // 6. 写入用户备注（可选）
    if (userNotes != null && userNotes.isNotEmpty) {
      final notesBytes = utf8.encode(userNotes);
      final notesLength = ByteData(4)..setUint32(0, notesBytes.length);
      output.add(notesLength.buffer.asUint8List());
      output.add(notesBytes);
    }

    return output.toBytes();
  }

  /// 构建文件头（32 bytes）
  static Uint8List _buildFileHeader() {
    final header = BytesBuilder();

    // Magic Number (8 bytes): "IMBOYBKP"
    header.add(utf8.encode(E2EECryptoService.magicNumber.padRight(8, '\x00')));

    // Version (2 bytes)
    final versionData = ByteData(2)
      ..setUint16(0, E2EECryptoService.formatVersion);
    header.add(versionData.buffer.asUint8List());

    // Algorithm ID (2 bytes)
    final algoData = ByteData(2)..setUint16(0, E2EECryptoService.algorithmId);
    header.add(algoData.buffer.asUint8List());

    // Iterations (4 bytes)
    final iterData = ByteData(4)
      ..setUint32(0, E2EECryptoService.pbkdf2Iterations);
    header.add(iterData.buffer.asUint8List());

    // Salt Length (2 bytes)
    final saltLenData = ByteData(2)..setUint16(0, E2EECryptoService.saltLength);
    header.add(saltLenData.buffer.asUint8List());

    // IV Length (2 bytes)
    final ivLenData = ByteData(2)..setUint16(0, E2EECryptoService.ivLength);
    header.add(ivLenData.buffer.asUint8List());

    // Tag Length (2 bytes)
    final tagLenData = ByteData(2)
      ..setUint16(0, E2EECryptoService.authTagLength);
    header.add(tagLenData.buffer.asUint8List());

    // Reserved (6 bytes)
    final reserved = Uint8List(6);
    header.add(reserved);

    return header.toBytes();
  }

  /// 解析文件头
  static Map<String, int?> _parseFileHeader(Uint8List fileBytes) {
    if (fileBytes.length < 32) {
      throw ArgumentError('文件格式无效：文件过小');
    }

    final byteData = ByteData.sublistView(fileBytes);

    // 验证 Magic Number
    final magicBytes = fileBytes.sublist(0, 8);
    final magic = String.fromCharCodes(magicBytes).trim();
    if (!magic.startsWith(E2EECryptoService.magicNumber)) {
      throw ArgumentError('不是有效的 Imboy 备份文件（Magic Number 错误）');
    }

    return {
      'version': byteData.getUint16(8),
      'algorithm': byteData.getUint16(10),
      'iterations': byteData.getUint32(12),
      'salt_length': byteData.getUint16(16),
      'iv_length': byteData.getUint16(18),
      'tag_length': byteData.getUint16(20),
    };
  }

  /// 提取密文数据（正确处理可选的用户备注）
  static Uint8List _extractCiphertext(
    Uint8List fileBytes,
    int dataStartOffset,
  ) {
    // 文件格式: [头 32] + [salt 16] + [iv 12] + [authTag 16] + [密文] + ([备注长度 4] + [备注内容])?
    // dataStartOffset 是密文的起始位置 (32 + 16 + 12 + 16 = 76)

    final remainingBytes = fileBytes.length - dataStartOffset;

    // 尝试检测是否有用户备注
    // 备注格式: [4 bytes 长度] + [内容]
    // 但我们不能直接判断最后 4 字节是否是长度，因为密文可能有任何值

    // 策略：先假设没有备注，尝试解密
    // 如果解密失败，可能是因为最后 4 字节被误当作密文了
    // 但这里我们无法尝试解密，所以需要另一个方法

    // 更好的策略：检查文件是否明显包含备注
    // 如果文件末尾有一个合理的长度值，尝试读取备注
    if (remainingBytes > 8) {
      // 至少需要 4 字节长度 + 一些内容
      try {
        // 检查最后 4 字节作为长度是否合理
        final potentialLengthBytes = fileBytes.sublist(fileBytes.length - 4);
        final lengthData = ByteData.sublistView(potentialLengthBytes);
        final potentialNotesLength = lengthData.getUint32(0);

        // 长度必须 > 0 且 < 剩余字节数（至少留 4 字节给长度字段本身）
        final minHeaderSize = 32 + 16 + 12 + 16; // 76
        final maxNotesLength = fileBytes.length - minHeaderSize - 4;

        if (potentialNotesLength > 0 &&
            potentialNotesLength <= maxNotesLength) {
          // 可能的备注位置
          final notesStart = fileBytes.length - 4 - potentialNotesLength;

          // 备注必须从合理的偏移开始（至少在所有固定字段之后）
          if (notesStart >= dataStartOffset) {
            // 尝试验证备注内容：应该是可打印的 UTF-8 字符串
            final potentialNotes = fileBytes.sublist(
              notesStart,
              fileBytes.length - 4,
            );
            try {
              final notesString = utf8.decode(potentialNotes);
              // 如果是有效的 UTF-8 且包含可打印字符，认为确实是备注
              if (notesString.isNotEmpty &&
                  notesString.runes.every(
                    (r) => r >= 32 && r < 127 || r >= 0x4E00 && r <= 0x9FFF,
                  )) {
                // 有备注，返回密文（去掉备注和长度字段）
                return fileBytes.sublist(dataStartOffset, notesStart);
              }
            } catch (e) {
              // 不是有效的 UTF-8，所以不是备注
            }
          }
        }
      } catch (e) {
        // 解析失败，当作没有备注处理
      }
    }

    // 没有备注或无法确定，返回所有剩余字节作为密文
    return fileBytes.sublist(dataStartOffset);
  }
}
