/// T09 段加密单测：加密往返、篡改检测、nonce 单射、绑定失效。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('t09_crypto');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Uint8List plain(int size) =>
      Uint8List.fromList(List<int>.generate(size, (i) => i & 0xFF));

  test('加密往返：写→读→解密与原文逐字节一致', () async {
    final key = TalkRecordSegmentCrypto.generateRecordKey();
    final plainFile = File('${tmpDir.path}/p0.aac');
    await plainFile.writeAsBytes(plain(1024 * 3 + 17));
    final cipherFile = File('${tmpDir.path}/s0.aes');

    final info = await TalkRecordSegmentCrypto.sealSegment(
      plainFile: plainFile,
      cipherFile: cipherFile,
      recordKey: key,
      sessionId: 'sess-1',
      seq: 3,
      mime: 'audio/aac',
    );
    expect(cipherFile.existsSync(), isTrue);
    expect(info.cipherSize, cipherFile.lengthSync());
    expect(info.plainSize, 1024 * 3 + 17);

    final outFile = File('${tmpDir.path}/out.aac');
    await TalkRecordSegmentCrypto.openSegment(
      cipherFile: cipherFile,
      plainOutFile: outFile,
      recordKey: key,
      sessionId: 'sess-1',
      seq: 3,
      info: info,
      mime: 'audio/aac',
    );
    final roundtrip = await outFile.readAsBytes();
    expect(roundtrip, equals(plain(1024 * 3 + 17)));
  });

  test('篡改密文一字节 → 解封失败（完整性门）', () async {
    final key = TalkRecordSegmentCrypto.generateRecordKey();
    final plainFile = File('${tmpDir.path}/p1.aac');
    await plainFile.writeAsBytes(plain(999));
    final cipherFile = File('${tmpDir.path}/s1.aes');
    final info = await TalkRecordSegmentCrypto.sealSegment(
      plainFile: plainFile,
      cipherFile: cipherFile,
      recordKey: key,
      sessionId: 'sess-1',
      seq: 0,
      mime: 'audio/aac',
    );

    final cipher = await cipherFile.readAsBytes();
    cipher[10] ^= 0x01;
    await cipherFile.writeAsBytes(cipher);

    final outFile = File('${tmpDir.path}/out1.aac');
    expect(
      () => TalkRecordSegmentCrypto.openSegment(
        cipherFile: cipherFile,
        plainOutFile: outFile,
        recordKey: key,
        sessionId: 'sess-1',
        seq: 0,
        info: info,
        mime: 'audio/aac',
      ),
      throwsA(isA<TalkRecordSegmentCryptoException>()),
    );
    // 失败不得产出部分明文。
    expect(outFile.existsSync(), isFalse);
  });

  test('段被搬到其他会话（sessionId 不符）→ 绑定失效', () async {
    final key = TalkRecordSegmentCrypto.generateRecordKey();
    final plainFile = File('${tmpDir.path}/p2.aac');
    await plainFile.writeAsBytes(plain(500));
    final cipherFile = File('${tmpDir.path}/s2.aes');
    final info = await TalkRecordSegmentCrypto.sealSegment(
      plainFile: plainFile,
      cipherFile: cipherFile,
      recordKey: key,
      sessionId: 'sess-a',
      seq: 0,
      mime: 'audio/aac',
    );
    final outFile = File('${tmpDir.path}/out2.aac');
    expect(
      () => TalkRecordSegmentCrypto.openSegment(
        cipherFile: cipherFile,
        plainOutFile: outFile,
        recordKey: key,
        sessionId: 'sess-b',
        seq: 0,
        info: info,
        mime: 'audio/aac',
      ),
      throwsA(isA<TalkRecordSegmentCryptoException>()),
    );
  });

  test('同 key 跨段 baseNonce 单射（无 GCM nonce 复用）', () {
    final key = TalkRecordSegmentCrypto.generateRecordKey();
    final seen = <String>{};
    for (var seq = 0; seq < 500; seq++) {
      final nonce = TalkRecordSegmentCrypto.segmentBaseNonce(
        key,
        'sess-n',
        seq,
      );
      expect(nonce.length, 12);
      expect(
        seen.add(String.fromCharCodes(nonce)),
        isTrue,
        reason: 'seq=$seq nonce 复用',
      );
    }
    // 不同 key 派生不同 nonce。
    final key2 = TalkRecordSegmentCrypto.generateRecordKey();
    expect(
      TalkRecordSegmentCrypto.segmentBaseNonce(key, 's', 1),
      isNot(equals(TalkRecordSegmentCrypto.segmentBaseNonce(key2, 's', 1))),
    );
  });

  test('recordKey 随机性（两条密钥不等）', () {
    expect(
      TalkRecordSegmentCrypto.generateRecordKey(),
      isNot(equals(TalkRecordSegmentCrypto.generateRecordKey())),
    );
  });

  test('verifySegment：大小/哈希校验', () async {
    final key = TalkRecordSegmentCrypto.generateRecordKey();
    final plainFile = File('${tmpDir.path}/p3.aac');
    await plainFile.writeAsBytes(plain(300));
    final cipherFile = File('${tmpDir.path}/s3.aes');
    final info = await TalkRecordSegmentCrypto.sealSegment(
      plainFile: plainFile,
      cipherFile: cipherFile,
      recordKey: key,
      sessionId: 'sess-v',
      seq: 0,
      mime: 'audio/aac',
    );
    expect(
      await TalkRecordSegmentCrypto.verifySegment(
        cipherFile: cipherFile,
        info: info,
      ),
      isTrue,
    );
    await cipherFile.writeAsBytes(plain(300));
    expect(
      await TalkRecordSegmentCrypto.verifySegment(
        cipherFile: cipherFile,
        info: info,
      ),
      isFalse,
    );
  });
}
