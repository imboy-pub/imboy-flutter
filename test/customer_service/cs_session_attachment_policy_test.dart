import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_attachment_preparation.dart';

/// 只实现 preparation 读取的三个事实（名字/路径/长度），其余按 PlatformFile 默认。
final class PickedFile extends PlatformFile {
  PickedFile(this.name, String path) : _uri = Uri.file(path);
  @override
  final String name;
  final Uri _uri;
  @override
  Uri get uri => _uri;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0];

/// ISO BMFF：`ftyp` + 主品牌 `heic`（iPhone 相册直出格式的真魔数切片）。
const _heic = <int>[
  0,
  0,
  0,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x68,
  0x65,
  0x69,
  0x63,
];

/// HEIF 通用容器：主品牌 `mif1`。
const _heif = <int>[
  0,
  0,
  0,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x6D,
  0x69,
  0x66,
  0x31,
];

/// 无 `ftyp` 的旧版 QuickTime：首原子直接是 `mdat`。
const _mov = <int>[0, 0, 0, 0x10, 0x6D, 0x64, 0x61, 0x74, 0, 0, 0, 0];

/// ISO BMFF 但主品牌 `isom`：同一容器，不是 HEIF。
const _mp4 = <int>[
  0,
  0,
  0,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x69,
  0x73,
  0x6F,
  0x6D,
];

/// EBML 头：mime 包会把它判成 `audio/weba`，必须靠扩展名回退到 mkv。
const _mkv = <int>[0x1A, 0x45, 0xDF, 0xA3, 0x01, 0x02];

/// gzip：mime 包既无 `.gz` 扩展映射也无魔数，走本文件的极小兜底表。
const _gzip = <int>[0x1F, 0x8B, 0x08, 0x00];

/// OLE2 复合文档头（.xls/.ppt 老格式与 .doc 共用）。
const _ole2 = <int>[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

const _flac = <int>[0x66, 0x4C, 0x61, 0x43, 0x00];

CsSessionAttachmentPreparation _preparation({
  required String name,
  required String path,
  required int declaredLength,
  required List<int> bytes,
  void Function()? onReadBytes,
}) => CsSessionAttachmentPreparation(
  pickFiles: () async => [PickedFile(name, path)],
  readLength: (File _) async => declaredLength,
  readHead: (File _) async => Uint8List.fromList(bytes.take(64).toList()),
  readBytes: (File _) async {
    onReadBytes?.call();
    return Uint8List.fromList(bytes);
  },
);

void main() {
  group('seat attachment policy mirrors the server whitelist', () {
    test('a whitelisted type is prepared with the detected mime', () async {
      final prepared = await _preparation(
        name: 'note.png',
        path: '/tmp/note.png',
        declaredLength: _png.length,
        bytes: _png,
      ).prepare(canWrite: () => true);

      expect(prepared, isNotNull);
      expect(prepared!.mime, 'image/png');
      expect(prepared.fileName, 'note.png');
      expect(prepared.bytes.length, _png.length);
    });

    /// 2026-10-30：iOS 直出格式转为可发。服务端同步接收（ISO BMFF 主品牌
    /// 复核），客户端这里必须能识别出正确 mime，否则会在 presign 前自我否决。
    for (final accepted in const [
      ('photo.heic', 'image/heic', _heic),
      ('photo.heif', 'image/heif', _heif),
      ('clip.mov', 'video/quicktime', _mov),
      ('movie.mkv', 'video/x-matroska', _mkv),
      ('sheet.xls', 'application/vnd.ms-excel', _ole2),
      ('voice.flac', 'audio/x-flac', _flac),
      ('logs.gz', 'application/gzip', _gzip),
    ]) {
      test('${accepted.$2} is prepared, not refused', () async {
        final prepared = await _preparation(
          name: accepted.$1,
          path: '/tmp/${accepted.$1}',
          declaredLength: accepted.$3.length,
          bytes: accepted.$3,
        ).prepare(canWrite: () => true);

        expect(prepared, isNotNull);
        expect(prepared!.mime, accepted.$2);
      });
    }

    for (final rejected in const [
      ('setup.exe', 'application/x-msdownload'),
      ('page.html', 'text/html'),
      ('app.apk', 'application/vnd.android.package-archive'),
    ]) {
      test('${rejected.$2} is refused before any request', () async {
        var readBytes = 0;
        final preparation = _preparation(
          name: rejected.$1,
          path: '/tmp/${rejected.$1}',
          declaredLength: 10,
          bytes: const [1, 2, 3],
          onReadBytes: () => readBytes++,
        );

        await expectLater(
          preparation.prepare(canWrite: () => true),
          throwsA(isA<CsUnsupportedSeatAttachment>()),
        );
        expect(readBytes, 0, reason: '不受支持的类型不该先把整个文件读进内存');
        expect(
          kSeatAttachmentAllowedMimes.contains(rejected.$2),
          isFalse,
          reason: '该类型确实不在与服务端对齐的白名单内',
        );
      });
    }

    test('a plain ftyp container is not accepted as an image', () async {
      // 只有 ftyp、主品牌不属于 HEIF 家族：客户端按 mime 包判定为 video/mp4，
      // 不能因为「白名单里有 video/mp4」就把它当成 HEIC 放行。
      final prepared = await _preparation(
        name: 'whatever.heic',
        path: '/tmp/whatever.heic',
        declaredLength: _mp4.length,
        bytes: _mp4,
      ).prepare(canWrite: () => true);

      expect(prepared?.mime, isNot('image/heic'));
    });

    test('a file above 25 MiB is oversize, not a retryable failure', () async {
      var readBytes = 0;
      final preparation = _preparation(
        name: 'big.png',
        path: '/tmp/big.png',
        declaredLength: kSeatAttachmentMaxBytes + 1,
        bytes: _png,
        onReadBytes: () => readBytes++,
      );

      await expectLater(
        preparation.prepare(canWrite: () => true),
        throwsA(isA<CsOversizeSeatAttachment>()),
      );
      expect(readBytes, 0);
    });

    test('an empty file is oversize rather than a zero-byte upload', () async {
      final preparation = _preparation(
        name: 'empty.png',
        path: '/tmp/empty.png',
        declaredLength: 0,
        bytes: const [],
      );

      await expectLater(
        preparation.prepare(canWrite: () => true),
        throwsA(isA<CsOversizeSeatAttachment>()),
      );
    });

    test('a scope change during preparation yields no upload', () async {
      final preparation = _preparation(
        name: 'note.png',
        path: '/tmp/note.png',
        declaredLength: _png.length,
        bytes: _png,
      );

      expect(await preparation.prepare(canWrite: () => false), isNull);
    });
  });
}
