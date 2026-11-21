import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const _package = 'pub.imboy.app.masterqa';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Text('FL-15 QA'))));
  try {
    await _run().timeout(const Duration(seconds: 30));
    debugPrint('FL15_DEVICE_PROBE_PASS');
  } catch (error) {
    // Transport exceptions can embed request details.
    debugPrint('FL15_DEVICE_PROBE_FAIL ${error.runtimeType}');
  }
}

Future<void> _run() async {
  if (!Platform.isAndroid ||
      (await PackageInfo.fromPlatform()).packageName != _package) {
    throw StateError('FL15_DEVICE_PACKAGE');
  }
  final directory = await getApplicationSupportDirectory();
  final fixture = jsonDecode(
    await File('${directory.path}/fl15-device-fixture.json').readAsString(),
  ) as Map<String, dynamic>;
  final headers = Map<String, String>.from(fixture['headers'] as Map);
  if ((await DeviceInfoPlugin().androidInfo).id != headers['did'] ||
      headers['pkg'] != _package) {
    throw StateError('FL15_DEVICE_PROFILE');
  }

  final origin = Uri.parse(fixture['origin'] as String);
  final ca = base64Decode(fixture['ca'] as String);
  if (origin.scheme != 'https' ||
      origin.host != '127.0.0.1' ||
      !origin.hasPort ||
      origin.userInfo.isNotEmpty ||
      origin.path.isNotEmpty ||
      origin.hasQuery ||
      origin.hasFragment ||
      sha256.convert(ca).toString() != fixture['ca_sha256']) {
    throw StateError('FL15_TLS_FIXTURE');
  }

  final context = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(ca);
  final client = HttpClient(context: context)
    ..badCertificateCallback = null
    ..findProxy = (_) => 'DIRECT';
  try {
    final org = fixture['org'] as String;
    final workspace = fixture['workspace'] as String;
    final session = fixture['session'] as String;
    final base = '/api/v1/cs/organizations/$org/seats';
    final list = await _get(
      client,
      origin.replace(
        path: '$base/sessions',
        queryParameters: {'workspace_id': workspace, 'status': 'active'},
      ),
      headers,
    );
    final body = await utf8.decoder.bind(list).join();
    if (!body.contains(session)) {
      throw StateError('FL15_SESSION_ABSENT');
    }
    debugPrint('FL15_DEVICE_LIST_PASS');

    final stream = await _get(
      client,
      origin.replace(
        path: '$base/me/events',
        queryParameters: {'workspace_id': workspace},
      ),
      headers,
    );
    if (stream.headers.contentType?.mimeType != 'text/event-stream' ||
        !await utf8.decoder
            .bind(stream)
            .transform(const LineSplitter())
            .any((line) => line.startsWith('retry:'))
            .timeout(const Duration(seconds: 10))) {
      throw StateError('FL15_STREAM_ABSENT');
    }
    debugPrint('FL15_DEVICE_SSE_PASS');
  } finally {
    client.close(force: true);
  }
}

Future<HttpClientResponse> _get(
  HttpClient client,
  Uri uri,
  Map<String, String> headers,
) async {
  final request = await client.getUrl(uri);
  request.followRedirects = false;
  headers.forEach(request.headers.set);
  final response = await request.close();
  if (response.statusCode != 200) throw StateError('FL15_RESPONSE_STATUS');
  return response;
}
