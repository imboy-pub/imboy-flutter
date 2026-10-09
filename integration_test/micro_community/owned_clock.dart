// Seed the normal time cache from this run's real backend before initialization.
// This prevents public NTP lookups without replacing any business response.
import 'dart:convert';
import 'dart:io';

import 'package:imboy/service/storage.dart';

Future<void> prepareOwnedClock() async {
  const base = String.fromEnvironment('API_BASE_URL_OVERRIDE');
  final endpoint = Uri.parse(base).replace(path: '/api/v1/app/features');
  if (endpoint.scheme != 'http' ||
      endpoint.host != '127.0.0.1' ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.query.isNotEmpty ||
      endpoint.fragment.isNotEmpty) {
    throw StateError('owned clock requires an explicit local backend');
  }
  final clock = await _readServerClock(endpoint);
  final now = DateTime.now().millisecondsSinceEpoch;
  if (clock <= 0 ||
      (clock - now).abs() > const Duration(hours: 24).inMilliseconds) {
    throw StateError('owned backend clock is outside the accepted boundary');
  }
  final saved = await StorageService.to.setString(
    'ntp_offset_v2',
    jsonEncode({
      'ntp_time': DateTime.fromMillisecondsSinceEpoch(
        clock,
        isUtc: true,
      ).toIso8601String(),
      'device_ts': now,
      'offset': clock - now,
    }),
  );
  if (!saved) throw StateError('owned clock persistence failed');
}

Future<int> _readServerClock(Uri endpoint) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(endpoint);
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('owned clock rejected');
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length > 65536) {
        throw StateError('owned clock response oversized');
      }
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map || data['code'] != 0 || data['sv_ts'] is! int) {
      throw StateError('owned clock response invalid');
    }
    return data['sv_ts'] as int;
  } catch (_) {
    throw StateError('owned backend clock acquisition failed');
  } finally {
    client.close(force: true);
  }
}
