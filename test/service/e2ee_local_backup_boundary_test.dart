import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';

/// E2EE-016 — legacy backup parser 边界与资源安全单测。
///
/// 覆盖：
/// - notes 确定性 writer/reader 布局（长度 0/1/上限、往返、尾部边界）。
/// - 大分配/KDF 前的上限拒绝（超大文件、极端迭代数）。
/// - 短文件、垃圾字节、错误 UTF-8 的确定性处理（ArgumentError，非 RangeError/崩溃）。
/// - 固定 seed fuzz：随机字节 blob 永不 crash/hang/OOM，只抛 ArgumentError。
void main() {
  const password = 'Test-Passw0rd!';
  const privateKey =
      '-----BEGIN RSA PRIVATE KEY-----\nMIIfake-private\n-----END RSA PRIVATE KEY-----'; // gitleaks:allow
  const publicKey =
      '-----BEGIN PUBLIC KEY-----\nMIIfake-public\n-----END PUBLIC KEY-----';
  const deviceId = 'device-016-test';
  const keyId = 'key-016-test';

  Future<Uint8List> pack({String? userNotes}) {
    return E2EELocalBackupService.packBackupBytes(
      password: password,
      privateKey: privateKey,
      publicKey: publicKey,
      deviceId: deviceId,
      keyId: keyId,
      userNotes: userNotes,
    );
  }

  Future<Map<String, dynamic>> unpack(Uint8List bytes) {
    return E2EELocalBackupService.unpackBackupBytes(
      bytes: bytes,
      password: password,
    );
  }

  group('notes 确定性 writer/reader 布局', () {
    test('无备注往返成功', () async {
      final result = await unpack(await pack());
      expect(result['private_key'], privateKey);
      expect(result['device_id'], deviceId);
    });

    test('备注长度 0（空串等价无备注）往返成功', () async {
      final result = await unpack(await pack(userNotes: ''));
      expect(result['private_key'], privateKey);
    });

    test('备注长度 1 往返成功且不吃进密文', () async {
      final result = await unpack(await pack(userNotes: 'x'));
      expect(result['private_key'], privateKey);
      expect(result['key_id'], keyId);
    });

    test('多字节 UTF-8 备注（中文）往返成功', () async {
      final result = await unpack(await pack(userNotes: '主手机备份🔐'));
      expect(result['public_key'], publicKey);
    });

    test('备注长度上限（maxNotesBytes）往返成功', () async {
      final notes = 'a' * E2EELocalBackupService.maxNotesBytes;
      final result = await unpack(await pack(userNotes: notes));
      expect(result['private_key'], privateKey);
    });

    test('导出备注超上限抛 ArgumentError', () async {
      final tooLong = 'a' * (E2EELocalBackupService.maxNotesBytes + 1);
      await expectLater(pack(userNotes: tooLong), throwsArgumentError);
    });

    test('尾部追加垃圾字节（篡改 notes 边界）→ 确定性拒绝，非崩溃', () async {
      final bytes = await pack();
      final tampered = Uint8List.fromList([...bytes, 1, 2, 3, 4]);
      // 头部 notes_length=0，但实际多了 4 字节 → GCM 认证必败（ArgumentError）
      await expectLater(unpack(tampered), throwsArgumentError);
    });
  });

  group('大分配 / KDF 上限（派生前拒绝）', () {
    test('超过 maxBackupBytes 的字节直接拒绝，不进入解密', () async {
      final huge = Uint8List(E2EELocalBackupService.maxBackupBytes + 1);
      // 前 8 字节填 magic，确保不是 magic 先失败而是 size 先失败
      huge.setRange(0, 8, utf8.encode('IMBOYBKP'));
      await expectLater(unpack(huge), throwsArgumentError);
    });

    test('极端迭代数（头部 iterations 越界）在 KDF 前拒绝', () async {
      final bytes = await pack();
      final mutated = Uint8List.fromList(bytes);
      // offset 12..16 是 iterations(uint32 大端)，写入 0xFFFFFFFF
      ByteData.sublistView(mutated).setUint32(12, 0xFFFFFFFF);
      await expectLater(unpack(mutated), throwsArgumentError);
    });
  });

  group('短文件 / 畸形输入确定性处理（ArgumentError，非 RangeError）', () {
    test('空字节', () async {
      await expectLater(unpack(Uint8List(0)), throwsArgumentError);
    });

    test('仅 32 字节头、无 salt/iv/tag/密文（小于 minBackupBytes）', () async {
      final justHeader = Uint8List(32);
      justHeader.setRange(0, 8, utf8.encode('IMBOYBKP'));
      await expectLater(unpack(justHeader), throwsArgumentError);
    });

    test('minBackupBytes-1 边界（切片前须拒绝，不 RangeError）', () async {
      final b = Uint8List(E2EELocalBackupService.minBackupBytes - 1);
      b.setRange(0, 8, utf8.encode('IMBOYBKP'));
      await expectLater(unpack(b), throwsArgumentError);
    });

    test('错误 magic number', () async {
      final b = Uint8List(E2EELocalBackupService.minBackupBytes);
      b.setRange(0, 8, utf8.encode('NOTIMBOY'));
      await expectLater(unpack(b), throwsArgumentError);
    });
  });

  group('固定 seed fuzz：随机字节永不 crash/hang，只抛 ArgumentError', () {
    test('10000 个固定 seed 随机 blob', () async {
      // 线性同余 PRNG（固定 seed，确定性可复现，无外部依赖）
      var seed = 0x1234abcd;
      int nextInt(int mod) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed % mod;
      }

      for (var i = 0; i < 10000; i++) {
        // 长度覆盖 0..160，跨越 minBackupBytes(77) 边界
        final len = nextInt(161);
        final blob = Uint8List(len);
        for (var j = 0; j < len; j++) {
          blob[j] = nextInt(256);
        }
        // 半数样本填入合法 magic，逼近「头合法但内容垃圾」的路径
        if (i.isEven && len >= 8) {
          blob.setRange(0, 8, utf8.encode('IMBOYBKP'));
        }

        try {
          await unpack(blob);
          // 极小概率随机合法：允许，但绝不能是其它异常类型
        } on ArgumentError {
          // 期望路径：确定性拒绝
        }
      }
    });
  });
}
