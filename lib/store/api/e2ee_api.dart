import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class E2EEApi extends HttpClient {
  Future<List<Map<String, dynamic>>> userKeys({required String uid}) async {
    IMBoyHttpResponse resp = await get(
      '/v1/e2ee/user_keys',
      queryParameters: {'uid': uid},
    );
    if (!resp.ok) return [];
    final payload = resp.payload;
    final devices = payload['devices'];
    if (devices is List) {
      return devices.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> groupMemberKeys({required String gid}) async {
    IMBoyHttpResponse resp = await get(
      '/v1/e2ee/group_member_keys',
      queryParameters: {'gid': gid},
    );
    if (!resp.ok) return [];
    final payload = resp.payload;
    final members = payload['members'];
    if (members is List) {
      return members.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  void debugLogUserKeys(List<Map<String, dynamic>> list) {
    if (kDebugMode) {
      debugPrint('E2EEApi.userKeys count=${list.length}');
    }
  }
}
