import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/qrcode/qrcode_url.dart';

/// 二维码 URL 构造单测。
///
/// 2026-08-08 BUG：原页面内联拼接漏 `/api/v1` 段（apiBaseUrl 为裸域名），
/// 扫出的码 GET 裸路径 404 → 扫码报「错误」。收敛为共享函数后，
/// 注入固定 baseUrl 断言段前缀与参数形状，防回归。
/// tk 为 md5("${exp}_${solidifiedKey}")（32 位 hex，值随构建 key 变化），
/// 只断言参数存在，不断言具体值。
void main() {
  const host = 'https://test.imboy.pub';

  test('user 码含 /api/v1 段、uid 与后缀', () {
    final url = buildUserQrcodeUrl('58628', baseUrl: host);
    expect(url, startsWith('$host/api/v1/user/qrcode?id=58628&'));
    expect(url, endsWith('s=app_qrcode'));
    expect(url.contains('/api/v1/user/qrcode'), isTrue);
  });

  test('channel 码含 /api/v1 段、id/exp/tk 与后缀', () {
    final url = buildChannelQrcodeUrl(
      channelId: 'ch123',
      expiredAt: 1786000000000,
      baseUrl: host,
    );
    expect(url, startsWith('$host/api/v1/channel/qrcode?id=ch123&exp='));
    expect(url.contains('exp=1786000000000&tk='), isTrue);
    expect(url, matches(RegExp(r'tk=[0-9a-f]{32}&s=app_qrcode$')));
  });

  test('group 码含 /api/v1 段、id/exp/tk 与后缀', () {
    final url = buildGroupQrcodeUrl(
      groupId: 42,
      expiredAt: 1786000000000,
      baseUrl: host,
    );
    expect(url, startsWith('$host/api/v1/group/qrcode?id=42&exp='));
    expect(url.contains('exp=1786000000000&tk='), isTrue);
    expect(url, matches(RegExp(r'tk=[0-9a-f]{32}&s=app_qrcode$')));
  });
}
