part of 'attachment_forward_test.dart';

/// 捕获上传链三个 seam（多次调用按序记录）。
///
/// [label] 用于区分不同 capture 实例产出的 object_key——真实服务端每次
/// presign 都签发全新 key，fake 若按实例各自从 0 计数会在跨实例断言时撞名。
class _UploadCapture {
  _UploadCapture([this.label = 'x']);

  final String label;
  final List<String> objectKeys = [];
  final List<Uint8List> putBytes = [];
  final List<Map<String, dynamic>> confirmBodies = [];

  PresignFn get presignFn => (f, m) async {
    final k = 'u-dest/$label/${objectKeys.length}/$f';
    objectKeys.add(k);
    return IMBoyHttpResponse.success(<String, dynamic>{
      'put_url': 'https://example.invalid/put/${objectKeys.length}',
      'object_key': k,
    });
  };

  PutFn get putFn =>
      (url, b, mime, process) async => putBytes.add(b);

  ConfirmFn get confirmFn => (body) async {
    confirmBodies.add(body);
    return IMBoyHttpResponse.success(<String, dynamic>{});
  };
}
