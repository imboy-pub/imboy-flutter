import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/storage_secure.dart';

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
  // 边界常量（E2EE-016：文件/KDF/字段上限，防 OOM / DoS / 崩溃）
  // ================================================================

  /// 备份文件字节上限（64 MiB）。在 readAsBytes / 解密 / 大分配前拒绝，防 OOM。
  static const int maxBackupBytes = 64 * 1024 * 1024;

  /// 最小合法字节数：头 32 + salt 16 + iv 12 + tag 16 + 至少 1 字节密文 = 77。
  /// 小于此值时固定字段切片会 RangeError 崩溃，须在切片前确定性拒绝。
  static const int minBackupBytes = 32 + 16 + 12 + 16 + 1;

  /// PBKDF2 迭代数合法区间。头部迭代数来自文件（攻击者可控），
  /// 越界值（如 2^32-1）会让 KDF 挂死 → 在派生前拒绝。
  static const int minKdfIterations = 1;
  static const int maxKdfIterations = 1000000;

  /// 用户备注字节上限（64 KiB）。
  static const int maxNotesBytes = 64 * 1024;

  /// notes_length 在 32 字节文件头内的偏移（uint32，大端，位于原 reserved 区起始）。
  static const int _notesLengthHeaderOffset = 22;

  /// 文件字节数边界校验：过大防 OOM，过小防固定字段切片 RangeError 崩溃。
  static void _ensureSizeBounds(int length) {
    if (length > maxBackupBytes) {
      throw ArgumentError('备份文件过大（上限 $maxBackupBytes 字节）');
    }
    if (length < minBackupBytes) {
      throw ArgumentError('文件格式无效：文件过小');
    }
  }

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
    final backupFile = await packBackupBytes(
      password: password,
      privateKey: privateKey,
      publicKey: publicKey,
      deviceId: deviceId,
      keyId: keyId,
      userNotes: userNotes,
    );

    // 保存到临时目录
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'imboy_e2ee_backup_$timestamp.enc';
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(backupFile);

    return filePath;
  }

  /// 打包加密备份为字节（不落盘）
  ///
  /// 本地文件备份与服务端云备份（E2EEServerBackupService）共用的
  /// 加密核与二进制格式：[头 32] + [salt 16] + [iv 12] + [authTag 16] + [密文]。
  static Future<Uint8List> packBackupBytes({
    required String password,
    required String privateKey,
    required String publicKey,
    required String deviceId,
    required String keyId,
    String? userNotes,
    @visibleForTesting Map<String, String>? secureEntriesForTest,
  }) async {
    // 1. 验证密码强度
    _validatePassword(password);

    // P3-1：Megolm inbound session 段——换设备后群聊历史可恢复的唯一材料。
    // 收集失败不阻断备份（RSA 私钥仍值得备份），但留日志不静默。
    Map<String, String> megolmSection = const {};
    try {
      final all =
          secureEntriesForTest ?? await StorageSecureService.to.readAll();
      megolmSection = collectMegolmSection(all);
    } on Object catch (e) {
      iPrint('⚠️ [BACKUP] Megolm 段收集失败，仅备份 RSA 私钥: $e');
    }

    // 2. 构建备份数据（JSON）
    final backupData = {
      'version': E2EECryptoService.formatVersion,
      'device_id': deviceId,
      'private_key': privateKey,
      'public_key': publicKey,
      'key_id': keyId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      // 空段也写入：让「新格式但确实没有群会话」与「旧格式备份」可区分
      kMegolmSectionKey: megolmSection,
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

    // 7. 构建备份文件字节
    return _buildBackupFile(
      salt: salt,
      iv: iv,
      authTag: encryptedResult['authTag']!,
      ciphertext: encryptedResult['ciphertext']!,
      userNotes: userNotes,
    );
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

      _ensureSizeBounds(await file.length());
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

    _ensureSizeBounds(await file.length()); // 在 readAsBytes 前拒绝超大文件，防 OOM
    final fileBytes = await file.readAsBytes();
    return unpackBackupBytes(bytes: fileBytes, password: password);
  }

  /// 解包加密备份字节（importBackup 与云备份恢复共用）
  ///
  /// @throws ArgumentError 密码错误（GCM 认证失败）/ 格式无效 / 校验和不匹配
  static Future<Map<String, dynamic>> unpackBackupBytes({
    required Uint8List bytes,
    required String password,
  }) async {
    final fileBytes = bytes;

    // 1. 边界校验（防 OOM / 短文件切片 RangeError 崩溃）：先于任何派生/大分配
    _ensureSizeBounds(fileBytes.length);

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
    final ciphertext = _extractCiphertext(
      fileBytes,
      offset,
      header['notes_length']!,
    );

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
    final dataWithoutChecksum = Map<String, dynamic>.from(
      backupData as Map<dynamic, dynamic>,
    );
    dataWithoutChecksum.remove('checksum');

    final jsonWithoutChecksum = json.encode(dataWithoutChecksum);
    final actualChecksum = E2EECryptoService.calculateChecksum(
      Uint8List.fromList(utf8.encode(jsonWithoutChecksum)),
    );

    if (actualChecksum != expectedChecksum) {
      throw ArgumentError('备份文件已损坏（校验和不匹配）');
    }

    // 10. 返回密钥数据
    //
    // P3-1：`megolm_inbound` 为可选段——v1 旧备份无此字段时解析为空 map，
    // 不影响 RSA 私钥恢复（fail-closed 取舍见 megolm_backup_section.dart）。
    return {
      'device_id': backupData['device_id'],
      'key_id': backupData['key_id'],
      'private_key': backupData['private_key'],
      'public_key': backupData['public_key'],
      'created_at': backupData['created_at'],
      'file_size': fileBytes.length,
      kMegolmSectionKey: parseMegolmSection(backupData[kMegolmSectionKey]),
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

    _ensureSizeBounds(await file.length());
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
    // 备注字节：长度写入固定文件头（reserved 区），内容附于文件末尾。
    // 不再用「尾部 4 字节长度 + 启发式猜测」——那对某些密文会误判密文/备注边界。
    final notesBytes = (userNotes != null && userNotes.isNotEmpty)
        ? Uint8List.fromList(utf8.encode(userNotes))
        : Uint8List(0);
    if (notesBytes.length > maxNotesBytes) {
      throw ArgumentError('备注过长（上限 $maxNotesBytes 字节）');
    }

    final output = BytesBuilder();
    output.add(_buildFileHeader(notesBytes.length)); // 头（32 bytes，含 notes 长度）
    output.add(salt);
    output.add(iv);
    output.add(authTag);
    output.add(ciphertext);
    output.add(notesBytes); // 末尾即备注，长度由头部权威给出（确定性边界）
    return output.toBytes();
  }

  /// 构建文件头（32 bytes）。[notesLength] 写入 reserved 区，
  /// 使 reader 能确定性定位密文/备注边界（取代旧的尾部长度启发式猜测）。
  static Uint8List _buildFileHeader(int notesLength) {
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

    // Notes Length (4 bytes, offset 22)：备注字节长度，reader 据此确定性
    // 定位密文/备注边界。头部固定 32 字节的约定见下方 reserved。
    final notesLenData = ByteData(4)..setUint32(0, notesLength);
    header.add(notesLenData.buffer.asUint8List());

    // Reserved (6 bytes)
    //
    // 头部固定 32 字节：magic8 + ver2 + algo2 + iter4 + saltLen2 + ivLen2
    // + tagLen2 (=22) + notesLen4 (=26) + reserved6 (=32)。importBackup/
    // _extractCiphertext/testPassword 均按 offset=32 读取后续字段，须凑齐 32。
    header.add(Uint8List(6));

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

    // 迭代数来自文件（攻击者可控）：越界值会让 PBKDF2 挂死 → 派生前拒绝
    final iterations = byteData.getUint32(12);
    if (iterations < minKdfIterations || iterations > maxKdfIterations) {
      throw ArgumentError('非法的 KDF 迭代数: $iterations');
    }

    return {
      'version': byteData.getUint16(8),
      'algorithm': byteData.getUint16(10),
      'iterations': iterations,
      'salt_length': byteData.getUint16(16),
      'iv_length': byteData.getUint16(18),
      'tag_length': byteData.getUint16(20),
      'notes_length': byteData.getUint32(_notesLengthHeaderOffset),
    };
  }

  /// 提取密文数据。备注长度由文件头 notes_length 权威给出，
  /// 确定性定位密文/备注边界（取代旧的尾部长度启发式猜测）。
  static Uint8List _extractCiphertext(
    Uint8List fileBytes,
    int dataStartOffset,
    int notesLength,
  ) {
    // 布局: [头 32] + [salt 16] + [iv 12] + [authTag 16] + [密文] + [备注 notesLength]
    // dataStartOffset = 密文起始 (32 + 16 + 12 + 16 = 76)
    if (notesLength < 0 || notesLength > maxNotesBytes) {
      throw ArgumentError('非法的备注长度: $notesLength');
    }
    final ciphertextEnd = fileBytes.length - notesLength;
    // 密文至少 1 字节；备注不能越界吃进固定字段区
    if (ciphertextEnd <= dataStartOffset) {
      throw ArgumentError('文件格式无效：密文/备注边界越界');
    }
    return fileBytes.sublist(dataStartOffset, ciphertextEnd);
  }
}
