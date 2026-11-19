part of '../qr_login_persistence_test.dart';

class _SyntheticHttpAdapter implements HttpClientAdapter {
  Map<String, dynamic>? qrStatusResponse;
  String qrSessionToken = 'synthetic-session';
  Future<void> Function()? beforeCreateResponse;
  void Function(RequestOptions)? beforeQrStatus;
  Future<void> Function()? beforeStatusResponse;
  int statusRequests = 0;
  int createRequests = 0;
  Map<String, dynamic>? lastCreateBody;
  int profileRequests = 0;
  int profileStatusCode = 200;
  int? lastProfileStatusCode;
  Future<void> Function()? beforeProfileResponse;
  Map<String, dynamic> profileResponse = {
    'code': 0,
    'payload': {
      'uid': '9007199254740993',
      'nickname': 'Hydrated synthetic',
      'account': 'hydrated-account',
      'email': '',
      'avatar': '',
      'gender': 3,
      'region': 'Hydrated region',
      'sign': 'Hydrated sign',
      'setting': {
        'allow_search': 2,
        'enable_visibility_read': 'false',
        'visibility_read_fraction': '0.83',
        'visibility_read_delay_ms': '1350',
        'font_size': 'huge',
      },
    },
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var responseStatus = 200;
    Map<String, dynamic> response = {
      'code': 503,
      'msg': 'synthetic unavailable',
    };
    if (options.path == '/api/v1/passport/qr_login/create') {
      createRequests++;
      lastCreateBody = Map<String, dynamic>.from(options.data as Map);
      final sessionToken = qrSessionToken;
      await beforeCreateResponse?.call();
      response = {
        'code': 0,
        'payload': {
          'qr_token': 'synthetic-qr-code',
          'session_token': sessionToken,
          'expires_in': 60,
        },
      };
    } else if (options.path == '/api/v1/user/me') {
      profileRequests++;
      responseStatus = profileStatusCode;
      lastProfileStatusCode = responseStatus;
      await beforeProfileResponse?.call();
      response = profileResponse;
    } else if (options.path == '/api/v1/passport/qr_login/status') {
      statusRequests++;
      beforeQrStatus?.call(options);
      await beforeStatusResponse?.call();
      response = qrStatusResponse ?? response;
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      responseStatus,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
