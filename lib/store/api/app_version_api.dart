import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class AppVersionApi extends HttpClient {
  Future<Map<String, dynamic>> check(String vsn) async {
    IMBoyHttpResponse resp = await get(
      API.appVersionCheck,
      queryParameters: {'vsn': vsn},
    );
    if (kDebugMode) {
      debugPrint("AppVersionApi_check resp: ok=${resp.ok}");
    }
    return resp.payload ?? {};
  }

  Future<List<String>> sqliteUpgradeDdl(int oldVsn, int newVsn) async {
    IMBoyHttpResponse resp = await get(
      API.sqliteUpgradeDdl,
      queryParameters: {'old_vsn': oldVsn, 'new_vsn': newVsn},
    );
    if (kDebugMode) {
      debugPrint("AppVersionApi_sqliteUpgradeDdl resp: ok=${resp.ok}");
    }
    if (!resp.ok || resp.payload is! Map) return [];
    return List<String>.from((resp.payload['ddl'] ?? []) as List<dynamic>);
  }

  Future<List<String>> sqliteDowngradeDdl(int oldVsn, int newVsn) async {
    IMBoyHttpResponse resp = await get(
      API.sqliteDowngradeDdl,
      queryParameters: {'old_vsn': newVsn, 'new_vsn': oldVsn},
    );
    if (kDebugMode) {
      debugPrint("AppVersionApi_sqliteDowngradeDdl resp: ok=${resp.ok}");
    }
    if (!resp.ok || resp.payload is! Map) return [];
    return List<String>.from((resp.payload['ddl'] ?? []) as List<dynamic>);
  }
}
