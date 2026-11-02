import 'package:imboy/store/model/workspace_model.dart';

/// Nested attachment ticket returned by the existing attachment upload service.
class TalkRecordUploadRef {
  final String putUrl;
  final String objectKey;
  final String clientUploadId;
  final String uploadCapability;
  final DateTime? expiresAt;
  final bool gateway;
  final bool integrationPending;

  /// V3-18 direct s3_put descriptor：正文直传对象存储（BEAM 零正文）。
  /// 服务端 presign 已绑定 content-type + x-amz-checksum-sha256，
  /// requiredHeaders 原样发送即可，客户端不本地重算、不附加业务凭证。
  final String transport;
  final String grantUrl;
  final Map<String, String> requiredHeaders;

  const TalkRecordUploadRef({
    this.putUrl = '',
    this.objectKey = '',
    this.clientUploadId = '',
    this.uploadCapability = '',
    this.expiresAt,
    this.gateway = false,
    this.integrationPending = true,
    this.transport = '',
    this.grantUrl = '',
    this.requiredHeaders = const {},
  });

  /// direct s3_put 投影（backend attach_direct_logic grant descriptor）。
  bool get isS3Put => transport == 's3_put' && grantUrl.isNotEmpty;

  factory TalkRecordUploadRef.fromJson(Map<String, dynamic> json) {
    final expiry = json['expires_at'] ?? json['expiry'];
    DateTime? expiresAt;
    if (expiry is int && expiry > 0 && expiry <= 8640000000000) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiry * 1000,
        isUtc: true,
      );
    } else if (expiry is String) {
      expiresAt = DateTime.tryParse(expiry);
    }
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
      putUrl: text('put_url'),
      objectKey: text('object_key'),
      clientUploadId: text('client_upload_id'),
      uploadCapability: text('upload_capability'),
      expiresAt: expiresAt,
      gateway: json['gateway'] == true,
      integrationPending: json['integration_pending'] == true,
      transport: grantTransport,
      grantUrl: grantUrl,
      requiredHeaders: reqHeaders,
    );
  }

  /// Missing, pending, malformed or expired tickets must never start a PUT.
  /// V3-18：s3_put descriptor 的可用性独立判（签名 URL 自带过期；不依赖
  /// 业务 expires_at 字段——descriptor 投影无该字段）。
  bool canUploadAt(DateTime now) {
    if (isS3Put) {
      final uri = Uri.tryParse(grantUrl);
      return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasFragment &&
          objectKey.isNotEmpty &&
          requiredHeaders.isNotEmpty;
    }
    final uri = Uri.tryParse(putUrl);
    return !integrationPending &&
        uri != null &&
        _validDestination(uri) &&
        objectKey.isNotEmpty &&
        clientUploadId.isNotEmpty &&
        expiresAt != null &&
        now.isBefore(expiresAt!);
  }

  bool _validDestination(Uri uri) {
    if (!gateway) {
      return (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasFragment;
    }
    // Gateway tickets stay relative to the authenticated API client's base URL.
    return !uri.hasScheme &&
        !uri.hasAuthority &&
        !uri.hasFragment &&
        uri.path == '/api/v1/attachment/gateway/$clientUploadId' &&
        uploadCapability.isNotEmpty &&
        uri.queryParametersAll['capability']?.length == 1 &&
        uri.queryParameters['capability'] == uploadCapability;
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

  DateTime? get expiresAt => uploadRef.expiresAt;

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
