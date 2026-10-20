import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee/attachment_chunk_codec.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';

/// step-9（E2EE 文件化 seal/open）定向测试：
///   * sealToFile 与内存 seal 同 key/nonce/input **逐字节等价**（T24）；
///   * openToFile round-trip 恢复原明文；
///   * 末块/中块 tag 破坏、descriptor hash 破坏：抛错且**无部分明文暴露**
///     （隔离临时文件语义，协议 5.2）；
///   * 大文件（多块+尾块）流式，不整读。
void main() {
  late Directory tmp;
  late Uint8List bindingHash;
  late Uint8List contentKey;
  late Uint8List baseNonce;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dv1-e2ee-test');
    bindingHash = Uint8List.fromList(List<int>.generate(32, (int i) => i));
    contentKey = Uint8List.fromList(
      List<int>.generate(
        AttachmentChunkCodec.keyLength,
        (int i) => (i * 7) % 256,
      ),
    );
    baseNonce = Uint8List.fromList(
      List<int>.generate(
        AttachmentChunkCodec.nonceLength,
        (int i) => (i * 3) % 256,
      ),
    );
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  File writePlain(String name, int size, {int seed = 1}) {
    final File f = File('${tmp.path}/$name');
    final Uint8List bytes = Uint8List(size);
    for (int i = 0; i < size; i++) {
      bytes[i] = (i * seed + i ~/ 1024) % 256;
    }
    f.writeAsBytesSync(bytes);
    return f;
  }

  Map<String, dynamic> sealArgs(File plain) => <String, dynamic>{
    'bindingHash': bindingHash,
    'attachmentId': 'att-1',
    'objectKey': 'u1/file/e2ee-x',
    'mime': 'image/png',
    'name': 'x.png',
    'contentKey': contentKey,
    'baseNonce': baseNonce,
  };

  test('sealToFile 与内存 seal 逐字节等价（多块+尾块，T24）', () async {
    final File plain = writePlain(
      'p1.bin',
      AttachmentEncryptor.defaultChunkSize * 3 + 777,
    );
    final args = sealArgs(plain);

    final SealedAttachment mem = AttachmentEncryptor.seal(
      plaintext: plain.readAsBytesSync(),
      bindingHash: args['bindingHash'] as Uint8List,
      attachmentId: args['attachmentId'] as String,
      objectKey: args['objectKey'] as String,
      mime: args['mime'] as String,
      name: args['name'] as String,
      contentKey: contentKey,
      baseNonce: baseNonce,
    );

    final File cipher = File('${tmp.path}/c1.bin');
    final SealedAttachmentFile sealed = await AttachmentEncryptor.sealToFile(
      plaintextFile: plain,
      cipherFile: cipher,
      bindingHash: bindingHash,
      attachmentId: 'att-1',
      objectKey: 'u1/file/e2ee-x',
      mime: 'image/png',
      name: 'x.png',
      contentKey: contentKey,
      baseNonce: baseNonce,
    );

    expect(cipher.existsSync(), isTrue);
    expect(cipher.lengthSync(), mem.ciphertext.length);
    expect(sealed.ciphertextSize, mem.ciphertext.length);
    // 逐字节等价（固定 key/nonce/input：同密文，T24）
    final Uint8List fileBytes = cipher.readAsBytesSync();
    expect(fileBytes.length, mem.ciphertext.length);
    bool identical = true;
    for (int i = 0; i < fileBytes.length; i++) {
      if (fileBytes[i] != mem.ciphertext[i]) {
        identical = false;
        break;
      }
    }
    expect(identical, isTrue, reason: '同 key/nonce/input 新旧密文必须逐字节等价');
    // descriptor 等值（plain hash/size/chunkCount）
    expect(sealed.descriptor.plainSha256, mem.descriptor.plainSha256);
    expect(sealed.descriptor.plainSize, mem.descriptor.plainSize);
    expect(sealed.descriptor.chunkCount, mem.descriptor.chunkCount);
    expect(sealed.ciphertextSha256Hex, mem.ciphertextSha256Hex);
  });

  test('openToFile round-trip 恢复原明文（原子暴露后 .part 消失）', () async {
    final File plain = writePlain(
      'p2.bin',
      AttachmentEncryptor.defaultChunkSize + 42,
    );
    final File cipher = File('${tmp.path}/c2.bin');
    final SealedAttachmentFile sealed = await AttachmentEncryptor.sealToFile(
      plaintextFile: plain,
      cipherFile: cipher,
      bindingHash: bindingHash,
      attachmentId: 'att-1',
      objectKey: 'u1/file/e2ee-x',
      mime: 'image/png',
      name: 'x.png',
      contentKey: contentKey,
      baseNonce: baseNonce,
    );

    final File out = File('${tmp.path}/plain-out.bin');
    await AttachmentEncryptor.openToFile(
      cipherFile: cipher,
      plaintextOut: out,
      descriptor: sealed.descriptor,
      bindingHash: bindingHash,
    );

    expect(out.existsSync(), isTrue);
    expect(out.lengthSync(), plain.lengthSync());
    expect(
      out.existsSync() && File('${out.path}.part').existsSync(),
      isFalse,
      reason: '隔离临时文件在原子 rename 后不应残留',
    );
    // 字节一致
    final Uint8List a = out.readAsBytesSync();
    final Uint8List b = plain.readAsBytesSync();
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) fail('round-trip 明文在第 $i 字节不一致');
    }
  });

  test('末块 tag 破坏：抛错且无明文暴露', () async {
    final File plain = writePlain(
      'p3.bin',
      AttachmentEncryptor.defaultChunkSize + 100,
    );
    final File cipher = File('${tmp.path}/c3.bin');
    final SealedAttachmentFile sealed = await AttachmentEncryptor.sealToFile(
      plaintextFile: plain,
      cipherFile: cipher,
      bindingHash: bindingHash,
      attachmentId: 'att-1',
      objectKey: 'u1/file/e2ee-x',
      mime: 'image/png',
      name: 'x.png',
      contentKey: contentKey,
      baseNonce: baseNonce,
    );

    // 破坏末块最后一个字节（tag 区）
    final Uint8List bytes = cipher.readAsBytesSync();
    bytes[bytes.length - 1] ^= 0xFF;
    cipher.writeAsBytesSync(bytes);

    final File out = File('${tmp.path}/plain-out3.bin');
    await expectLater(
      AttachmentEncryptor.openToFile(
        cipherFile: cipher,
        plaintextOut: out,
        descriptor: sealed.descriptor,
        bindingHash: bindingHash,
      ),
      throwsA(isA<AttachmentSealException>()),
    );
    expect(out.existsSync(), isFalse, reason: '失败后不得有可见明文');
    expect(
      File('${out.path}.part').existsSync(),
      isFalse,
      reason: '隔离临时文件必须被清理',
    );
  });

  test('中块 tag 破坏：抛错且无明文暴露', () async {
    final File plain = writePlain(
      'p4.bin',
      AttachmentEncryptor.defaultChunkSize * 3,
    );
    final File cipher = File('${tmp.path}/c4.bin');
    final SealedAttachmentFile sealed = await AttachmentEncryptor.sealToFile(
      plaintextFile: plain,
      cipherFile: cipher,
      bindingHash: bindingHash,
      attachmentId: 'att-1',
      objectKey: 'u1/file/e2ee-x',
      mime: 'image/png',
      name: 'x.png',
      contentKey: contentKey,
      baseNonce: baseNonce,
    );
    final Uint8List bytes = cipher.readAsBytesSync();
    bytes[AttachmentEncryptor.defaultChunkSize + 5] ^= 0x01; // 第 1 块中部
    cipher.writeAsBytesSync(bytes);

    final File out = File('${tmp.path}/plain-out4.bin');
    await expectLater(
      AttachmentEncryptor.openToFile(
        cipherFile: cipher,
        plaintextOut: out,
        descriptor: sealed.descriptor,
        bindingHash: bindingHash,
      ),
      throwsA(isA<AttachmentSealException>()),
    );
    expect(out.existsSync(), isFalse);
  });

  test('descriptor plainSha256 谎报：全 hash 门拒绝，无明文暴露', () async {
    final File plain = writePlain('p5.bin', 1024);
    final File cipher = File('${tmp.path}/c5.bin');
    final SealedAttachmentFile sealed = await AttachmentEncryptor.sealToFile(
      plaintextFile: plain,
      cipherFile: cipher,
      bindingHash: bindingHash,
      attachmentId: 'att-1',
      objectKey: 'u1/file/e2ee-x',
      mime: 'image/png',
      name: 'x.png',
      contentKey: contentKey,
      baseNonce: baseNonce,
    );

    final Uint8List fakeHash = Uint8List(sealed.descriptor.plainSha256.length);
    final AttachmentDescriptor lied = AttachmentDescriptor(
      attachmentId: sealed.descriptor.attachmentId,
      objectKey: sealed.descriptor.objectKey,
      contentKey: sealed.descriptor.contentKey,
      cipher: sealed.descriptor.cipher,
      chunkSize: sealed.descriptor.chunkSize,
      chunkCount: sealed.descriptor.chunkCount,
      baseNonce: sealed.descriptor.baseNonce,
      plainSize: sealed.descriptor.plainSize,
      plainSha256: fakeHash,
      mime: sealed.descriptor.mime,
      name: sealed.descriptor.name,
    );

    final File out = File('${tmp.path}/plain-out5.bin');
    await expectLater(
      AttachmentEncryptor.openToFile(
        cipherFile: cipher,
        plaintextOut: out,
        descriptor: lied,
        bindingHash: bindingHash,
      ),
      throwsA(isA<AttachmentSealException>()),
    );
    expect(out.existsSync(), isFalse, reason: 'full hash 不过，明文不得暴露');
  });

  test('sealToFile 失败清理 .part（如明文文件中途消失）', () async {
    final File plain = writePlain('p6.bin', 2048);
    final File cipher = File('${tmp.path}/c6.bin');
    await expectLater(() async {
      final Future<SealedAttachmentFile> sealing =
          AttachmentEncryptor.sealToFile(
            plaintextFile: plain,
            cipherFile: cipher,
            bindingHash: bindingHash,
            attachmentId: 'att-1',
            objectKey: 'u1/file/e2ee-x',
            mime: 'image/png',
            name: 'x.png',
            contentKey: contentKey,
            baseNonce: baseNonce,
          );
      // 写中途删明文源（模拟所有权清理竞态）
      plain.deleteSync();
      return sealing;
    }(), throwsA(anything));
    expect(
      File('${cipher.path}.part').existsSync(),
      isFalse,
      reason: '失败必须清理 .part（I13：无未认证暴露面）',
    );
  });
}
