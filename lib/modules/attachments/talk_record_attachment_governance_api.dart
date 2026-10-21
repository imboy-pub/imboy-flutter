/// Metadata governance uses the talk-record endpoint, never delegated OA identity.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/enterprise_app/public.dart';
import 'package:imboy/store/api/workspace_api.dart';

final talkAttachmentGovernanceApiProvider = Provider(
  (ref) => TalkAttachmentGovernanceApi(),
);

class TalkAttachmentGovernanceSnapshot {
  TalkAttachmentGovernanceSnapshot._(this.data, this.etag);
  final Map<String, dynamic> data;
  final String etag;
  AssetRetentionRecord get retention => AssetRetentionRecord(
    fileId: entityIdOf(data['attachment_id']),
    retentionUntil: data['retention_until'] as String? ?? '',
    holdState: data['hold_state'] == 'held'
        ? AssetHoldState.held
        : AssetHoldState.none,
    holdReason: data['hold_reason'] as String? ?? '',
    purgeState: data['purge_state'] == 'purged'
        ? AssetPurgeState.purged
        : AssetPurgeState.live,
  );

  static TalkAttachmentGovernanceSnapshot parse(
    Map<String, dynamic> data,
    String? etag,
    String org,
    String record,
    String attachment,
  ) {
    final valid =
        etag != null &&
        RegExp(r'^"[1-9][0-9]*"$').hasMatch(etag) &&
        entityIdOf(data['organization_id']) == org &&
        entityIdOf(data['record_id']) == record &&
        entityIdOf(data['attachment_id']) == attachment &&
        ['none', 'held'].contains(data['hold_state']) &&
        ['live', 'purged'].contains(data['purge_state']) &&
        (data['retention_until'] == null ||
            data['retention_until'] is String) &&
        (data['hold_reason'] == null || data['hold_reason'] is String);
    if (!valid) {
      throw const WorkspaceApiException(502, 'Invalid governance response');
    }
    return TalkAttachmentGovernanceSnapshot._(Map.unmodifiable(data), etag);
  }
}

/// Per-request transformer retains actual response headers; revision is not an ETag.
class _GovernanceTransformer extends HttpTransformer {
  String? etag;
  @override
  IMBoyHttpResponse parse(Response<dynamic> response, String uri) {
    etag = response.headers.value('etag');
    return DefaultHttpTransformer.getInstance().parse(response, uri);
  }
}

class TalkAttachmentGovernanceApi {
  TalkAttachmentGovernanceApi({this.client});
  final HttpClient? client;
  HttpClient get _http => client ?? HttpClient.client;

  Future<TalkAttachmentGovernanceSnapshot> read(
    String org,
    String record,
    String attachment,
  ) => _request(org, record, attachment);

  Future<TalkAttachmentGovernanceSnapshot> mutate(
    String org,
    String record,
    String attachment, {
    required String etag,
    required String intent,
    required Map<String, dynamic> body,
  }) =>
      _request(org, record, attachment, etag: etag, intent: intent, body: body);

  Future<TalkAttachmentGovernanceSnapshot> _request(
    String org,
    String record,
    String attachment, {
    String? etag,
    String? intent,
    Map<String, dynamic>? body,
  }) async {
    if ([
      org,
      record,
      attachment,
    ].any((s) => !RegExp(r'^[1-9][0-9]*$').hasMatch(s))) {
      throw const WorkspaceApiException(400, 'Invalid governance identity');
    }
    final path =
        '/api/v1/talk-records/$record/attachments/$attachment/governance';
    final transformer = _GovernanceTransformer();
    final response = body == null
        ? await _http.get(path, httpTransformer: transformer)
        : await _http.post(
            path,
            data: body,
            options: Options(
              headers: {'If-Match': etag, 'Idempotency-Key': intent},
            ),
            httpTransformer: transformer,
          );
    if (!response.ok) throw WorkspaceApiException(response.code, response.msg);
    if (response.payload is! Map) {
      throw const WorkspaceApiException(502, 'Invalid governance response');
    }
    return TalkAttachmentGovernanceSnapshot.parse(
      Map<String, dynamic>.from(response.payload as Map),
      transformer.etag,
      org,
      record,
      attachment,
    );
  }
}
