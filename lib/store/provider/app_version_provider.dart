import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

class AppVersionProvider extends HttpClient {
  Future<Map<String, dynamic>> check(String vsn) async {
    IMBoyHttpResponse resp = await get(API.appVersionCheck, queryParameters: {
      'vsn': vsn,
    });
    debugPrint("AppVersionProvider_check resp: ${resp.payload.toString()}");
    return resp.payload ?? {};
  }

  Future<List<String>> sqliteUpgradeDdl(int oldVsn, int newVsn) async {
    IMBoyHttpResponse resp = await get(API.sqliteUpgradeDdl, queryParameters: {
      'old_vsn': oldVsn,
      'new_vsn': newVsn,
    });
    debugPrint(
        "AppVersionProvider_sqliteUpgradeDdl resp: ${resp.payload.toString()}");
    return resp.payload['ddl'] ?? [];
  }

  Future<List<String>> sqliteDowngradeDdl(int oldVsn, int newVsn) async {
    IMBoyHttpResponse resp =
        await get(API.sqliteDowngradeDdl, queryParameters: {
      'old_vsn': oldVsn,
      'new_vsn': newVsn,
    });
    debugPrint(
        "AppVersionProvider_sqliteUpgradeDdl resp: ${resp.payload.toString()}");
    return resp.payload['ddl'] ?? [];
  }

  Future<List<String>> sqliteCreateDdl(int version) async {
    IMBoyHttpResponse resp = await get(API.sqliteCreateDdl, queryParameters: {
      'version': version,
    });
    debugPrint(
        "AppVersionProvider_sqliteUpgradeDdl resp: ${resp.payload.toString()}");
    return resp.payload['ddl'] ?? [];
  }
}