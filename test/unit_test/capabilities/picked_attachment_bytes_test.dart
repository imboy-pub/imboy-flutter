import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/capabilities/adapters/picked_attachment_bytes.dart';

final class _BlobPick extends PlatformFile {
  _BlobPick({required this.stream, this.size});
  final Stream<Uint8List> Function() stream;
  final int? size;
  var reads = 0;
  @override
  String get name => '原始文件名.bin';
  @override
  Uri get uri => Uri.parse('blob:https://web.invalid/synthetic');
  @override
  String? get path => throw StateError('Browser input must not access a path');
  @override
  Future<int?> length() async => size;
  @override
  Stream<Uint8List> readAsByteStream() {
    reads++;
    return stream();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused picker operation');
}

void main() {
  test(
    'Blob input preserves exact bytes without consulting a native path',
    () async {
      final file = _BlobPick(
        size: 4,
        stream: () => Stream.fromIterable([
          Uint8List.fromList([0, 255]),
          Uint8List.fromList([13, 10]),
        ]),
      );
      expect(
        await readPickedAttachmentBytes(
          file,
          maxBytes: 4,
          requireCurrent: () {},
        ),
        [0, 255, 13, 10],
      );
      expect(file.reads, 1);
    },
  );

  test(
    'Oversized metadata is rejected before opening the byte stream',
    () async {
      final file = _BlobPick(size: 5, stream: () => const Stream.empty());
      await expectLater(
        readPickedAttachmentBytes(file, maxBytes: 4, requireCurrent: () {}),
        throwsStateError,
      );
      expect(file.reads, 0);
    },
  );

  test(
    'Unknown length cannot bypass the byte limit and closes its stream',
    () async {
      var released = false;
      Stream<Uint8List> chunks() async* {
        try {
          yield Uint8List(3);
          yield Uint8List(2);
        } finally {
          released = true;
        }
      }

      await expectLater(
        readPickedAttachmentBytes(
          _BlobPick(stream: chunks),
          maxBytes: 4,
          requireCurrent: () {},
        ),
        throwsStateError,
      );
      expect(released, isTrue);
    },
  );

  test(
    'Owner change during streaming aborts instead of returning old bytes',
    () async {
      var current = true, released = false;
      Stream<Uint8List> chunks() async* {
        try {
          yield Uint8List(1);
          current = false;
          yield Uint8List(1);
        } finally {
          released = true;
        }
      }

      await expectLater(
        readPickedAttachmentBytes(
          _BlobPick(stream: chunks),
          maxBytes: 4,
          requireCurrent: () {
            if (!current) throw StateError('old account');
          },
        ),
        throwsStateError,
      );
      expect(released, isTrue);
    },
  );

  for (final declared in [null, 2]) {
    test('Empty or changed input is rejected (declared=$declared)', () async {
      await expectLater(
        readPickedAttachmentBytes(
          _BlobPick(size: declared, stream: () => const Stream.empty()),
          maxBytes: 4,
          requireCurrent: () {},
        ),
        throwsStateError,
      );
    });
  }
}
