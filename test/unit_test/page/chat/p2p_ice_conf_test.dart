// ICE 配置组装回归测试
//
// 真机实测：后端未配 eturnal 时 webrtc_credential 返回空 turn_urls/
// stun_urls 列表，空 urls 传给原生 IceServer.Builder 抛
// IllegalArgumentException → PeerConnection 建不起来、呼叫静默死亡。
// buildIceServers 必须过滤空条目；无有效 TURN 时返回 null 让调用方
// 降级纯 STUN。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';

void main() {
  test('空 turn_urls（后端未配 eturnal）→ null 降级纯 STUN', () {
    expect(
      P2pCallScreenNotifier.buildIceServers({
        'turn_urls': [],
        'stun_urls': [],
        'username': 'u',
        'credential': 'c',
      }),
      isNull,
    );
    expect(
      P2pCallScreenNotifier.buildIceServers({
        'error': 'eturnal_secret_not_configured',
        'stun_urls': [],
      }),
      isNull,
    );
  });

  test('有效凭证 → 组装完整且无空 urls 条目', () {
    final servers = P2pCallScreenNotifier.buildIceServers({
      'turn_urls': 'turn:1.2.3.4:3478?transport=udp',
      'stun_urls': 'stun:1.2.3.4:3478',
      'username': 'u',
      'credential': 'c',
    })!;

    for (final s in servers) {
      final urls = s['urls'];
      expect(
        (urls is String && urls.isNotEmpty) ||
            (urls is List && urls.isNotEmpty),
        isTrue,
        reason: '不得存在空 urls 条目: $s',
      );
    }
    // udp → tcp 派生条目存在
    expect(
      servers.any((s) => s['urls'].toString().contains('transport=tcp')),
      isTrue,
    );
  });

  test('stun_urls 为空但 turn_urls 有效 → 跳过 stun 条目不崩', () {
    final servers = P2pCallScreenNotifier.buildIceServers({
      'turn_urls': ['turn:1.2.3.4:3478?transport=udp'],
      'stun_urls': [],
      'username': 'u',
      'credential': 'c',
    })!;
    expect(servers.first['urls'], 'stun:stun.l.google.com:19302');
  });
}
