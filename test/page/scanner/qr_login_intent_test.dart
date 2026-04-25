/// QR 扫码意图识别纯函数测试（RED）。
///
/// 上下文：现有 `lib/page/scanner/scanner_page.dart:80-148` 的 `onDetect` 仅
/// 识别两类 QR：
///   1. 后缀为 `s=app_qrcode` 的 HTTP(S) URL（user / group / channel 名片，
///      由后端 GET 路由返回 `{type, result, ...}` 决定后续动作）
///   2. 其他文本 → 走 `ScannerResultPage` 显示
///
/// 现要新增第 3 类：**Web 端登录 QR**，对齐后端 `imboy/src/api/qr_login_handler.erl:88-90`
/// 生成的 `qr_token`。约定 QR 编码时使用 `imboy://qr_login/<qr_token>` 私有 scheme，
/// 避免与已有 HTTP URL QR 冲突。
///
/// 兼容形式：
///   - 形式 1（推荐）：`imboy://qr_login/<qr_token>` — 私有 scheme，scheme 大小写不敏感
///   - 形式 2（备用）：`<host>/passport/qr_login_qr?token=<qr_token>` — HTTP URL 形式，
///     供未来后端可能新增的网关式短链接使用
///
/// 本文件零外部依赖，纯 Dart 单测。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/scanner/qr_login_intent.dart';

void main() {
  group('detectQrLoginIntent — 形式 1: imboy:// 私有 scheme', () {
    test('imboy://qr_login/<token> → QrLoginIntentWebLogin(token)', () {
      final result = detectQrLoginIntent('imboy://qr_login/abc123def456');
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc123def456');
    });

    test('scheme 大小写不敏感（IMBOY:// = imboy://）', () {
      final result = detectQrLoginIntent('IMBOY://qr_login/abc');
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc');
    });

    test('包含 base64 padding "=" 的 token 正确保留', () {
      // 后端 `generate_qr_token` 用 base64 编码，可能含 "=" padding
      final result = detectQrLoginIntent('imboy://qr_login/YWJjOjEyMw==');
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'YWJjOjEyMw==');
    });

    test('包含 ":" 的 token 正确保留（base64 解码后内含分隔符不影响外层）', () {
      final result = detectQrLoginIntent('imboy://qr_login/abc:123:456');
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc:123:456');
    });

    test('imboy://qr_login/ （空 token）→ Other', () {
      final result = detectQrLoginIntent('imboy://qr_login/');
      expect(result, isA<QrLoginIntentOther>());
    });

    test('imboy://qr_login （无尾斜杠 + 无 token）→ Other', () {
      final result = detectQrLoginIntent('imboy://qr_login');
      expect(result, isA<QrLoginIntentOther>());
    });

    test('imboy://qr_login/<空白 token>（空白 trim 后为空）→ Other', () {
      final result = detectQrLoginIntent('imboy://qr_login/   ');
      expect(result, isA<QrLoginIntentOther>());
    });

    test('整体两端空白 → trim 后正确识别', () {
      final result = detectQrLoginIntent('  imboy://qr_login/abc  ');
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc');
    });

    test('imboy:// 但 host 不是 qr_login（如 imboy://chat/x）→ Other', () {
      final result = detectQrLoginIntent('imboy://chat/x');
      expect(result, isA<QrLoginIntentOther>());
    });
  });

  group('detectQrLoginIntent — 形式 2: HTTP(S) URL with /qr_login_qr', () {
    test('https://host/passport/qr_login_qr?token=abc → WebLogin(abc)', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/passport/qr_login_qr?token=abc123',
      );
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc123');
    });

    test('http (非 https) 也支持 → WebLogin', () {
      final result = detectQrLoginIntent(
        'http://localhost:9802/passport/qr_login_qr?token=abc',
      );
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc');
    });

    test('带额外 query 参数 → token 仍正确提取', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/passport/qr_login_qr?token=abc&from=app',
      );
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc');
    });

    test('URL 路径 /qr_login_qr 缺失 → Other', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/passport/login?token=abc',
      );
      expect(result, isA<QrLoginIntentOther>());
    });

    test('URL 缺 token query 参数 → Other', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/passport/qr_login_qr',
      );
      expect(result, isA<QrLoginIntentOther>());
    });

    test('URL token=空字符串 → Other', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/passport/qr_login_qr?token=',
      );
      expect(result, isA<QrLoginIntentOther>());
    });
  });

  group('detectQrLoginIntent — 不应误判（user/group/channel 名片 QR）', () {
    test('用户名片 QR (s=app_qrcode 后缀) → Other', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/user/qrcode?id=12345&s=app_qrcode',
      );
      expect(result, isA<QrLoginIntentOther>());
    });

    test('群组 QR (s=app_qrcode 后缀) → Other', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/group/qrcode?gid=999&s=app_qrcode',
      );
      expect(result, isA<QrLoginIntentOther>());
    });

    test('频道 QR (s=app_qrcode 后缀) → Other', () {
      final result = detectQrLoginIntent(
        'https://api.example.com/channel/qrcode?cid=8&s=app_qrcode',
      );
      expect(result, isA<QrLoginIntentOther>());
    });
  });

  group('detectQrLoginIntent — 边界 / 防御', () {
    test('空字符串 → Other', () {
      final result = detectQrLoginIntent('');
      expect(result, isA<QrLoginIntentOther>());
    });

    test('全空白字符串 → Other', () {
      final result = detectQrLoginIntent('   \t\n  ');
      expect(result, isA<QrLoginIntentOther>());
    });

    test('普通文本 → Other', () {
      final result = detectQrLoginIntent('hello world');
      expect(result, isA<QrLoginIntentOther>());
    });

    test('外部 HTTP URL（如 google.com）→ Other', () {
      final result = detectQrLoginIntent('https://www.google.com');
      expect(result, isA<QrLoginIntentOther>());
    });

    test('Other 分支保留原始 raw 字符串便于上层 fallback 处理', () {
      final result = detectQrLoginIntent('some_random_text');
      expect(result, isA<QrLoginIntentOther>());
      expect((result as QrLoginIntentOther).raw, 'some_random_text');
    });

    test('Other 保留前后空白（不 trim raw，避免上层语义丢失）', () {
      final result = detectQrLoginIntent('  hello  ');
      expect(result, isA<QrLoginIntentOther>());
      expect((result as QrLoginIntentOther).raw, '  hello  ');
    });

    test('类似但非合法的 imboy://qr_login/abc/xyz（多段 path）→ WebLogin（整段后缀作为 token）', () {
      // 设计决策：path 多段时整体作为 token 保留，由后端 parse_qr_token 决定合法性
      final result = detectQrLoginIntent('imboy://qr_login/abc/xyz');
      expect(result, isA<QrLoginIntentWebLogin>());
      expect((result as QrLoginIntentWebLogin).qrToken, 'abc/xyz');
    });
  });

  group('sealed exhaustiveness', () {
    test('QrLoginIntent switch 穷尽所有变体（编译期保护）', () {
      final result = detectQrLoginIntent('imboy://qr_login/abc');
      final label = switch (result) {
        QrLoginIntentWebLogin() => 'web_login',
        QrLoginIntentOther() => 'other',
      };
      expect(label, isNotEmpty);
    });
  });
}
