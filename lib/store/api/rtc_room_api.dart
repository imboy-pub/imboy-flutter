import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 音视频房间（LiveKit SFU）API 客户端
///
/// POST /api/v1/rtc/room/join → payload {ws_url, token, room_name}
class RtcRoomApi extends HttpClient {
  /// 加入房间：成功返回 {wsUrl, token, roomName}，失败返回 null
  ///
  /// [kind] 'group' | 'c2c'；[targetId] 群 id 或对端 uid（TSID 十进制字符串）
  Future<Map<String, String>?> joinRoom({
    required String kind,
    required String targetId,
    String? did,
  }) async {
    // 后端契约 target_id 为 JSON integer（64-bit TSID，移动端 int 无损）
    final target = int.tryParse(targetId.trim());
    if (target == null) return null;

    final data = <String, dynamic>{'kind': kind, 'target_id': target};
    if (did != null && did.isNotEmpty) data['did'] = did;

    final resp = await post(API.rtcRoomJoin, data: data);
    if (!resp.ok || resp.payload is! Map) return null;

    final payload = resp.payload as Map;
    final wsUrl = '${payload['ws_url'] ?? ''}';
    final token = '${payload['token'] ?? ''}';
    final roomName = '${payload['room_name'] ?? ''}';
    if (wsUrl.isEmpty || token.isEmpty) return null;

    return {'wsUrl': wsUrl, 'token': token, 'roomName': roomName};
  }
}
