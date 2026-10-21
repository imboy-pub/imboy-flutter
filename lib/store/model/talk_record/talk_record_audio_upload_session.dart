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

  const TalkRecordUploadRef({
    this.putUrl = '',
    this.objectKey = '',
    this.clientUploadId = '',
    this.uploadCapability = '',
    this.expiresAt,
    this.gateway = false,
    this.integrationPending = true,
  });

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
    return TalkRecordUploadRef(
      putUrl: text('put_url'),
      objectKey: text('object_key'),
      clientUploadId: text('client_upload_id'),
      uploadCapability: text('upload_capability'),
      expiresAt: expiresAt,
      gateway: json['gateway'] == true,
      integrationPending: json['integration_pending'] == true,
    );
  }

  /// Missing, pending, malformed or expired tickets must never start a PUT.
  bool canUploadAt(DateTime now) {
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
