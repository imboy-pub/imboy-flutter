// 一次性诊断探针：复刻客户端 e2ee_room_key 帧（C2G action、无 e2ee、带 keys
// payload），经 imboy.v2 子协议 WS 直发本地后端，观察服务端回帧。
// 用法：PROBE_TOKEN=<bearer> PROBE_SIGN_KEY=<key> dart run tool/ws_roomkey_probe.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:imboy/service/protocol/imboy_frame.dart';

String _sign(String deviceId, String key) {
  final raw = '$deviceId|0.8.0|macos|pub.imboy.app';
  final sig = crypto.Hmac(
    crypto.sha512,
    utf8.encode(key),
  ).convert(utf8.encode(raw)).bytes;
  return base64.encode(sig);
}

Future<void> main() async {
  final did = 'roomkey-probe-02';
  final token = Platform.environment['PROBE_TOKEN'] ?? '';
  final signKey = Platform.environment['PROBE_SIGN_KEY'] ?? '';
  if (token.isEmpty || signKey.isEmpty) {
    stderr.writeln('需要 PROBE_TOKEN 和 PROBE_SIGN_KEY 环境变量');
    exit(2);
  }
  final headers = {
    'cos': 'macos',
    'vsn': '0.8.0',
    'pkg': 'pub.imboy.app',
    'did': did,
    'tz_offset': '28800000',
    'method': 'sha512',
    'sk': '1',
    'sign': _sign(did, signKey),
    'authorization': 'Bearer $token',
  };
  final ws = await WebSocket.connect(
    'ws://127.0.0.1:9801/api/v1/ws',
    headers: headers,
    protocols: const ['imboy.v2'],
  );
  final sub = ws.listen((data) {
    if (data is String) {
      stderr.writeln('TEXT: $data');
    } else {
      final bytes = Uint8List.fromList(data as List<int>);
      final decoded = ImboyFrame.tryDecode(bytes);
      stderr.writeln(
        'BIN: type=${decoded?.frame.type} payload=${decoded == null ? "<undecoded>" : utf8.decode(decoded.frame.payload, allowMalformed: true).substring(0, decoded.frame.payload.length > 300 ? 300 : decoded.frame.payload.length)}',
      );
    }
  });
  await Future<void>.delayed(const Duration(seconds: 1));

  final msgId = 'rk_probe_${DateTime.now().millisecondsSinceEpoch}';
  final frame = ImboyFrame.encode(
    type: 0x21, // FrameType.msgC2G
    flags: 0,
    payload: Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'id': msgId,
          'type': 'C2G',
          'to': Platform.environment['PROBE_GID'] ?? '110572649006237696',
          'msg_type': 'e2ee_room_key',
          'action': 'e2ee_room_key',
          'payload': {
            'msg_type': 'e2ee_room_key',
            'keys': [
              {
                'device_id': 'probe-device',
                'olm': {'type': 'm.room_key', 'body': 'x' * 128},
              },
            ],
          },
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }),
      ),
    ),
  );
  ws.add(frame);
  stderr.writeln('sent frame msgId=$msgId');
  await Future<void>.delayed(const Duration(seconds: 6));
  await sub.cancel();
  await ws.close();
}
