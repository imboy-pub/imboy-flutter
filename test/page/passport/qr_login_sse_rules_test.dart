/// QR SSE 帧解析 + 降级决策单测（PR-4α RED→GREEN→REFACTOR）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/qr_login_sse_rules.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';

void main() {
  // -------------------------------------------------------------------------
  // parseSseFrame: SSE 帧解析（10 测）
  // -------------------------------------------------------------------------
  group('parseSseFrame', () {
    test('data: {"status":"waiting"} → QrStatusWaiting', () {
      final event = parseSseFrame('data: {"status":"waiting"}');
      expect(event, isA<QrStatusWaiting>());
    });

    test('data: {"status":"scanned"} → QrStatusScanned', () {
      final event = parseSseFrame('data: {"status":"scanned"}');
      expect(event, isA<QrStatusScanned>());
    });

    test('data: {"status":"confirmed","token":"jwt_xyz"} → QrStatusConfirmed("jwt_xyz")', () {
      final event = parseSseFrame('data: {"status":"confirmed","token":"jwt_xyz"}');
      expect(event, isA<QrStatusConfirmed>());
      expect((event as QrStatusConfirmed).token, 'jwt_xyz');
    });

    test('data: {"status":"expired"} → QrStatusExpired', () {
      final event = parseSseFrame('data: {"status":"expired"}');
      expect(event, isA<QrStatusExpired>());
    });

    test('data: {"status":"cancelled"} → QrStatusCancelled', () {
      final event = parseSseFrame('data: {"status":"cancelled"}');
      expect(event, isA<QrStatusCancelled>());
    });

    test('data: {"status":"future_unknown"} → QrStatusUnknown(透传)', () {
      final event = parseSseFrame('data: {"status":"future_unknown"}');
      expect(event, isA<QrStatusUnknown>());
      expect((event as QrStatusUnknown).rawStatus, 'future_unknown');
    });

    test('data: {"status":"confirmed"} 缺 token → QrStatusUnknown("confirmed") (协议违反防御)', () {
      // 与 parseQrStatusResponse:155 行为对齐：confirmed 必须附 token
      final event = parseSseFrame('data: {"status":"confirmed"}');
      expect(event, isA<QrStatusUnknown>());
      expect((event as QrStatusUnknown).rawStatus, 'confirmed');
    });

    test('非 data: 前缀（如 SSE comment ":heartbeat"）→ QrStatusStopPolling', () {
      // SSE 规范允许 `:heartbeat` 注释行；客户端不应解析为 event
      final event = parseSseFrame(':heartbeat');
      expect(event, isA<QrStatusStopPolling>());
    });

    test('JSON 解析失败 → QrStatusStopPolling（防御网络截断）', () {
      final event = parseSseFrame('data: {invalid json');
      expect(event, isA<QrStatusStopPolling>());
    });

    test('空字符串 → QrStatusStopPolling', () {
      expect(parseSseFrame(''), isA<QrStatusStopPolling>());
    });

    test('data:{"status":"waiting"} 无空格也接受（SSE 规范允许）', () {
      final event = parseSseFrame('data:{"status":"waiting"}');
      expect(event, isA<QrStatusWaiting>());
    });
  });

  // -------------------------------------------------------------------------
  // shouldFallbackToPolling: 降级决策（6 测）
  // -------------------------------------------------------------------------
  group('shouldFallbackToPolling', () {
    test('sseAttemptFailed=true → 立即降级（连接异常路径）', () {
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: true,
          silentSeconds: 0,
        ),
        isTrue,
      );
    });

    test('未连且超出宽限期（silentSeconds=3）→ 降级', () {
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: false,
          silentSeconds: 3,
        ),
        isTrue,
      );
    });

    test('未连但还在宽限期（silentSeconds=2）→ 不降级', () {
      // 企业代理 SSE 握手可能慢，避免误判
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: false,
          silentSeconds: 2,
        ),
        isFalse,
      );
    });

    test('已连接即使长时间无 event 也不降级（waiting 阶段正常）', () {
      expect(
        shouldFallbackToPolling(
          sseConnected: true,
          sseAttemptFailed: false,
          silentSeconds: 999,
        ),
        isFalse,
      );
    });

    test('已连接 + attemptFailed=true（不太可能但防御）→ 仍降级', () {
      // attemptFailed 应优先于 sseConnected（语义：连接出过问题，不可信）
      expect(
        shouldFallbackToPolling(
          sseConnected: true,
          sseAttemptFailed: true,
          silentSeconds: 0,
        ),
        isTrue,
      );
    });

    test('自定义 gracePeriodSeconds=10 → silentSeconds=5 时不降级', () {
      // 弱网环境可调高宽限期
      expect(
        shouldFallbackToPolling(
          sseConnected: false,
          sseAttemptFailed: false,
          silentSeconds: 5,
          gracePeriodSeconds: 10,
        ),
        isFalse,
      );
    });
  });
}
