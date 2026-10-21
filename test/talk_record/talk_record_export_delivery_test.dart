import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_export_delivery.dart';

void main() {
  const owner = TalkRecordAccount('http://127.0.0.1:1234', '7');
  const path = '/api/v1/talk-records/1/exports/2/download?ticket=abc';
  Future<TalkRecordExportSaveResult> deliver(
    TalkRecordExportDelivery service,
  ) => service.deliver(
    url: path,
    recordId: '1',
    exportId: '2',
    extension: 'txt',
    owner: service.account,
    isCurrent: () => true,
  );
  test(
    'rejects cross origin, wrong record, redirects as URL, duplicate ticket',
    () {
      for (final url in [
        'https://evil.test$path',
        '//evil.test$path',
        '/api/v1/talk-records/3/exports/2/download?ticket=a',
        '$path&ticket=b',
      ]) {
        expect(
          () => TalkRecordExportDelivery.scopedPath(
            url,
            owner.endpoint,
            '1',
            '2',
          ),
          throwsA(anything),
        );
      }
      expect(
        TalkRecordExportDelivery.scopedPath(
          '${owner.endpoint}$path',
          owner.endpoint,
          '1',
          '2',
        ),
        path,
      );
    },
  );
  test(
    'real local HTTP bytes arrive at save gateway only after stream completes',
    () async {
      final previousOverrides = io.HttpOverrides.current;
      io.HttpOverrides.global = null;
      addTearDown(() => io.HttpOverrides.global = previousOverrides);
      final server = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        0,
      );
      final bytes = utf8.encode('真实面聊导出\n');
      server.listen((request) async {
        request.response.add(bytes);
        await request.response.close();
      });
      final dio = Dio();
      final account = TalkRecordAccount('http://127.0.0.1:${server.port}', '7');
      var saved = false;
      final service = TalkRecordExportDelivery(
        account: () => account,
        fetch: (path) async => (await dio.get<ResponseBody>(
          '${account.endpoint}$path',
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
          ),
        )).data!,
        save: ({required fileName, required bytes, required mimeType}) async {
          expect(utf8.decode(bytes), '真实面聊导出\n');
          expect(fileName, 'talk-record-export.txt');
          saved = true;
          return Uri.file('/synthetic/export.txt');
        },
      );
      expect(await deliver(service), TalkRecordExportSaveResult.saved);
      expect(saved, true);
      dio.close(force: true);
      await server.close(force: true);
    },
  );
  test('cancelled save is distinct from successful save', () async {
    final service = TalkRecordExportDelivery(
      account: () => owner,
      fetch: (_) async => ResponseBody.fromString('hello', 200),
      save: ({required fileName, required bytes, required mimeType}) async =>
          null,
    );
    expect(await deliver(service), TalkRecordExportSaveResult.cancelled);
  });
  test('oversized stream never invokes save', () async {
    final service = TalkRecordExportDelivery(
      account: () => owner,
      maxBytes: 3,
      fetch: (_) async => ResponseBody.fromString('hello', 200),
      save: ({required fileName, required bytes, required mimeType}) async {
        fail('save invoked');
      },
    );
    await expectLater(deliver(service), throwsA(anything));
  });
  test('403 and 410 bytes responses never invoke save', () async {
    for (final code in [403, 410, 302]) {
      final service = TalkRecordExportDelivery(
        account: () => owner,
        fetch: (_) async => ResponseBody.fromString('refused', code),
        save: ({required fileName, required bytes, required mimeType}) async {
          fail('save invoked');
        },
      );
      await expectLater(deliver(service), throwsA(anything));
    }
  });
  test('account change during fetch prevents native save', () async {
    var account = owner;
    final service = TalkRecordExportDelivery(
      account: () => account,
      fetch: (_) async {
        account = const TalkRecordAccount('http://127.0.0.1:1234', '8');
        return ResponseBody.fromBytes(Uint8List.fromList([1]), 200);
      },
      save: ({required fileName, required bytes, required mimeType}) async {
        fail('save invoked');
      },
    );
    expect(await deliver(service), TalkRecordExportSaveResult.stale);
  });
}
