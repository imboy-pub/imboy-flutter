import 'package:imboy/store/model/workspace_model.dart';

/// Nested s3_put grant descriptor returned by the direct attachment service.
/// 旧 gateway ticket 形态（put_url/upload_capability/gateway）已随 backend
/// V3-20 零签发退役：descriptor 是唯一上传形态（CONFIRMED_DECISIONS 决策 5）。
class TalkRecordUploadRef {
  final String objectKey;
  final String clientUploadId;

  /// V3-18 direct s3_put descriptor：正文直传对象存储（BEAM 零正文）。
  /// 服务端 presign 已绑定 content-type + x-amz-checksum-sha256，
  /// requiredHeaders 原样发送即可，客户端不本地重算、不附加业务凭证。
  final String transport;
  final String grantUrl;
  final Map<String, String> requiredHeaders;

  const TalkRecordUploadRef({
    this.objectKey = '',
    this.clientUploadId = '',
    this.transport = '',
    this.grantUrl = '',
    this.requiredHeaders = const {},
  });

  /// direct s3_put 投影（backend attach_direct_logic grant descriptor）。
  bool get isS3Put => transport == 's3_put' && grantUrl.isNotEmpty;

  factory TalkRecordUploadRef.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] is String ? json[key] as String : '';
    // V3-18：nested grant descriptor（{transport, url, required_headers}）
    final grant = json['grant'];
    Map<String, String> reqHeaders = const {};
    String grantUrl = '';
    String grantTransport = '';
    if (grant is Map<String, dynamic>) {
      grantTransport = grant['transport'] is String
          ? grant['transport'] as String
          : '';
      grantUrl = grant['url'] is String ? grant['url'] as String : '';
      final rawHeaders = grant['required_headers'];
      if (rawHeaders is Map) {
        reqHeaders = rawHeaders.map(
          (k, v) => MapEntry(k is String ? k : '', v is String ? v : ''),
        );
      }
    }
    return TalkRecordUploadRef(
      objectKey: text('object_key'),
      clientUploadId: text('client_upload_id'),
      transport: grantTransport,
      grantUrl: grantUrl,
      requiredHeaders: reqHeaders,
    );
  }

  /// Missing, malformed or non-s3_put descriptors must never start a PUT.
  /// 签名 URL 自带过期（presign TTL），descriptor 无业务 expires_at 字段。
  bool get uploadable {
    if (!isS3Put) return false;
    final uri = Uri.tryParse(grantUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        objectKey.isNotEmpty &&
        requiredHeaders.isNotEmpty;
  }
}

class TalkRecordAudioUploadSession {
  final EntityId partId;
  final EntityId attachmentId;
  final TalkRecordUploadRef uploadRef;
  final Map<String, dynamic> raw;

  const TalkRecordAudioUploadSession({
    this.partId = '',
    this.attachmentId = '',
    this.uploadRef = const TalkRecordUploadRef(),
    this.raw = const {},
  });

  factory TalkRecordAudioUploadSession.fromJson(Map<String, dynamic> json) {
    final nested = json['upload_ref'];
    return TalkRecordAudioUploadSession(
      partId: entityIdOf(json['part_id']),
      attachmentId: entityIdOf(json['attachment_id']),
      uploadRef: nested is Map<String, dynamic>
          ? TalkRecordUploadRef.fromJson(nested)
          : const TalkRecordUploadRef(),
      raw: json,
    );
  }
}
