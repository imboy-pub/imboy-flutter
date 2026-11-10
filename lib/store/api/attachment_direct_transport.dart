part of 'attachment_direct_api.dart';

/// 默认 PUT：dart:io HttpClient fixed-length streaming。
///
/// * contentLength 显式设置 → 非 chunked（Garage/S3 签名 PUT 必需；
///   Dio+Stream 在 Android 忽略手动 content-length 的前科见
///   [AttachmentApi._rawDioPut] 注释——本引擎不经 Dio）；
/// * headers 原样发送且**只发** required_headers（无业务凭据，T29/T07）；
/// * 取消：[DirectUploadCancelled] 由调用方通过 abort 回调注入（HttpClientRequest.abort）。
Future<void> _ioFilePut(
  String url,
  io.File file,
  int length,
  Map<String, String> headers, {
  void Function(int sent, int total)? onProgress,
  CancelToken? cancelToken,
}) async {
  DirectAttachmentApi._checkCancelled(cancelToken);
  final io.HttpClient client = io.HttpClient();
  client.connectionTimeout = const Duration(milliseconds: 30000);
  io.HttpClientRequest? activeRequest;
  var finished = false;
  unawaited(
    cancelToken?.whenCancel.then((_) {
      if (finished) return;
      activeRequest?.abort(const DirectUploadCancelled(''));
      client.close(force: true);
    }),
  );
  try {
    final io.HttpClientRequest request = await client.openUrl(
      'PUT',
      Uri.parse(url),
    );
    activeRequest = request;
    unawaited(
      request.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    DirectAttachmentApi._checkCancelled(cancelToken);
    request.followRedirects = false;
    headers.forEach((String k, String v) {
      request.headers.set(k, v);
    });
    request.contentLength = length;
    var sent = 0;
    await request.addStream(
      file.openRead().map((chunk) {
        DirectAttachmentApi._checkCancelled(cancelToken);
        sent += chunk.length;
        onProgress?.call(sent, length);
        return chunk;
      }),
    );
    DirectAttachmentApi._checkCancelled(cancelToken);
    final io.HttpClientResponse response = await request.close();
    DirectAttachmentApi._checkCancelled(cancelToken);
    // 签名 PUT 的负向（缺头/换值/换正文）由存储端拒绝；这里只区分成败，
    // 错误体不读取（服务端 finalize 的 proof 才是权威，T05/T06）。
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw Exception('direct put failed: http ${response.statusCode}');
    }
    await response.drain<void>();
  } catch (_) {
    DirectAttachmentApi._checkCancelled(cancelToken);
    rethrow;
  } finally {
    finished = true;
    client.close(force: true);
    try {
      await activeRequest?.done;
    } on Object {
      // The abort error was surfaced by the upload operation.
    }
    activeRequest = null;
  }
}
