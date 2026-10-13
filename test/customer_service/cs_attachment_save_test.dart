import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_attachment_save.dart';

CsVerifiedAssetContent verified() {
  final bytes = Uint8List.fromList([0, 255, 65]);
  return CsVerifiedAssetContent.fromResponse(
    Response(
      requestOptions: RequestOptions(path: '/synthetic'),
      data: bytes,
      statusCode: 200,
      headers: Headers.fromMap({
        'x-asset-id': ['9'],
        'x-asset-sha256': [sha256.convert(bytes).toString()],
        'content-length': ['3'],
        'content-type': ['application/octet-stream'],
      }),
    ),
    '9',
  );
}

void main() {
  test(
    'save receives exact verified bytes and a safe history basename',
    () async {
      String? name;
      Uint8List? saved;
      final save = CsAttachmentSave(
        saveFile:
            ({required fileName, required bytes, required mimeType}) async {
              name = fileName;
              saved = bytes;
              return Uri.file('/synthetic-save');
            },
      );
      expect(
        await save.save(
          content: verified(),
          fileName: '../unsafe\\sample\u0000.pdf',
          isCurrent: () => true,
        ),
        CsAttachmentSaveResult.saved,
      );
      expect(name, 'sample_.pdf');
      expect(saved, [0, 255, 65]);
    },
  );
  test('cancelled save is not success', () async {
    final save = CsAttachmentSave(
      saveFile: ({
        required fileName,
        required bytes,
        required mimeType,
      }) async => null,
    );
    expect(
      await save.save(
        content: verified(),
        fileName: 'sample.bin',
        isCurrent: () => true,
      ),
      CsAttachmentSaveResult.cancelled,
    );
  });
  test('revoked scope performs zero save', () async {
    var calls = 0;
    final save = CsAttachmentSave(
      saveFile: ({required fileName, required bytes, required mimeType}) async {
        calls++;
        return null;
      },
    );
    expect(
      await save.save(
        content: verified(),
        fileName: 'sample.bin',
        isCurrent: () => false,
      ),
      CsAttachmentSaveResult.stale,
    );
    expect(calls, 0);
  });
}
