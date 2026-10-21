/// Downloads a scoped export through the authenticated client before native save.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_runtime.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';

enum TalkRecordExportSaveResult { saved, cancelled, stale }

typedef TalkRecordExportSave = Future<Uri?> Function({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
});
typedef TalkRecordExportFetch = Future<ResponseBody> Function(String path);

class TalkRecordExportDelivery {
  TalkRecordExportDelivery({
    TalkRecordExportFetch? fetch,
    TalkRecordExportSave? save,
    TalkRecordAccount Function()? account,
    this.maxBytes = 16 * 1024 * 1024,
  }) : _fetch = fetch ?? _authenticatedFetch,
       _save = save ?? _saveFile,
       _account = account ?? currentTalkRecordAccount;

  final TalkRecordExportFetch _fetch;
  final TalkRecordExportSave _save;
  final TalkRecordAccount Function() _account;
  final int maxBytes;

  TalkRecordAccount get account => _account();

  Future<TalkRecordExportSaveResult> deliver({
    required String url,
    required String recordId,
    required String exportId,
    required String extension,
    required TalkRecordAccount owner,
    required bool Function() isCurrent,
  }) async {
    bool current() => owner.valid && _account() == owner && isCurrent();
    if (!current()) return TalkRecordExportSaveResult.stale;
    final path = scopedPath(url, owner.endpoint, recordId, exportId);
    final body = await _fetch(path);
    if (body.statusCode != 200) {
      await body.stream.listen(null).cancel();
      throw TalkRecordApiException(body.statusCode, 'export_download_failed');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      if (!current()) return TalkRecordExportSaveResult.stale;
      if (builder.length + chunk.length > maxBytes) {
        throw const TalkRecordApiException(413, 'export_too_large');
      }
      builder.add(chunk);
    }
    if (!current()) return TalkRecordExportSaveResult.stale;
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) throw const TalkRecordApiException(502, 'empty_export');
    final ext = extension == 'md' ? 'md' : 'txt';
    try {
      final result = await _save(
        fileName: 'talk-record-export.$ext',
        bytes: bytes,
        mimeType: ext == 'md' ? 'text/markdown' : 'text/plain',
      );
      if (!current()) return TalkRecordExportSaveResult.stale;
      return result == null
          ? TalkRecordExportSaveResult.cancelled
          : TalkRecordExportSaveResult.saved;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static String scopedPath(
    String raw,
    String endpoint,
    String rid,
    String eid,
  ) {
    final base = Uri.parse(endpoint);
    final parsed = Uri.parse(raw);
    final uri = base.resolveUri(parsed);
    final expected = '/api/v1/talk-records/$rid/exports/$eid/download';
    if (!{'http', 'https'}.contains(base.scheme) ||
        uri.origin != base.origin ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path != expected ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['ticket']?.length != 1 ||
        (uri.queryParameters['ticket'] ?? '').isEmpty) {
      throw const TalkRecordApiException(422, 'invalid_export_ticket');
    }
    return '$expected?${uri.query}';
  }

  static Future<ResponseBody> _authenticatedFetch(String path) async {
    final response = await HttpClient.client.get(
      path,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: {'accept': 'text/plain, text/markdown'},
      ),
      httpTransformer: _ExportStreamTransformer(),
    );
    if (!response.ok) {
      throw TalkRecordApiException(response.code, 'export_download_failed');
    }
    return response.payload as ResponseBody;
  }

  static Future<Uri?> _saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) =>
      FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
}

class _ExportStreamTransformer extends HttpTransformer {
  @override
  IMBoyHttpResponse parse(Response<dynamic> response, String uri) {
    final mime = (response.headers.value('content-type') ?? '')
        .split(';')
        .first
        .trim();
    if (response.statusCode != 200 ||
        response.data is! ResponseBody ||
        !{'text/plain', 'text/markdown'}.contains(mime)) {
      final body = response.data;
      if (body is ResponseBody) body.stream.listen(null).cancel();
      return IMBoyHttpResponse.failure(
        errCode: response.statusCode == 200 ? 502 : response.statusCode ?? 502,
        errMsg: 'export_download_failed',
      );
    }
    return IMBoyHttpResponse.success(response.data);
  }
}
