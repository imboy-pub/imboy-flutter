/// W08（channel-group-ux-v2.2 §6.8 C4/D3）：查看更新边界离线向量。
///
/// 覆盖：门精度（view_watermark 恰为整数 1）、可见面积占比计算、
/// 500ms 停留达成/未达成（J13.a）、遮蔽重置（J13.c）、边界固定于
/// 内容响应（不并入未展示推送）、客户端不倒退护栏 + markViewed API
/// 传输形状。J13.b（置顶/筛选/跳转不推进）由调用方分支契约承载
/// （tracker 只接受未筛选正常流的候选），J13.d 服务端 GREATEST 由
/// 后端 PG 套件覆盖；两者在此以护栏断言编码。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/channel/channel_view_tracker.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visibleFraction（可见面积占比）', () {
    const viewport = Rect.fromLTWH(0, 0, 100, 400);
    test('完全在视口内 → 1.0', () {
      expect(
        visibleFraction(const Rect.fromLTWH(0, 0, 100, 80), viewport),
        1.0,
      );
    });

    test('恰好一半在视口内 → 0.5（≥50% 门槛临界）', () {
      final f = visibleFraction(const Rect.fromLTWH(0, 360, 100, 80), viewport);
      expect(f, moreOrLessEquals(0.5, epsilon: 1e-9));
    });

    test('完全在视口外 → 0', () {
      expect(
        visibleFraction(const Rect.fromLTWH(0, 500, 100, 80), viewport),
        0,
      );
      expect(
        visibleFraction(const Rect.fromLTWH(0, -80, 100, 80), viewport),
        0,
      );
    });

    test('空矩形 → 0', () {
      expect(visibleFraction(Rect.zero, viewport), 0);
    });
  });

  group('ChannelViewTracker（J13 向量）', () {
    test('J13.a：≥50% 连续 500ms 达成 → 推进该响应边界', () {
      final tracker = ChannelViewTracker()..onContentResponse(7);
      tracker.beginCandidate(nowMs: 1000);
      expect(tracker.advanceIfDue(nowMs: 1499), isNull);
      expect(tracker.advanceIfDue(nowMs: 1500), 7);
      // 消费后候选耗尽，重复调用不再返回。
      expect(tracker.advanceIfDue(nowMs: 1600), isNull);
    });

    test('J13.a：候选未设置或未起算 → 不推进', () {
      final tracker = ChannelViewTracker();
      expect(tracker.advanceIfDue(nowMs: 9999), isNull);
      tracker.onContentResponse(3);
      expect(tracker.advanceIfDue(nowMs: 9999), isNull);
    });

    test('J13.c：400ms 时遮蔽 → 立即重置；再暴露需重新满 500ms', () {
      final tracker = ChannelViewTracker()..onContentResponse(5);
      tracker.beginCandidate(nowMs: 0);
      tracker.onObscured(); // 400ms 处弹层/后台
      tracker.beginCandidate(nowMs: 1000);
      expect(tracker.advanceIfDue(nowMs: 1400), isNull);
      expect(tracker.advanceIfDue(nowMs: 1500), 5);
    });

    test('内容响应固定边界：新响应替换候选并重置累计（不并入未展示推送）', () {
      final tracker = ChannelViewTracker()..onContentResponse(5);
      tracker.beginCandidate(nowMs: 0);
      tracker.onContentResponse(9); // 新内容响应（页不取最大值，固定新值）
      expect(tracker.candidateBoundary, 9);
      expect(tracker.accumulating, isFalse);
      tracker.beginCandidate(nowMs: 2000);
      expect(tracker.advanceIfDue(nowMs: 2499), isNull);
      expect(tracker.advanceIfDue(nowMs: 2500), 9);
    });

    test('客户端不倒退护栏：已发送边界之后，更旧候选不发送（J13.d 客户端侧）', () {
      final tracker = ChannelViewTracker()..onContentResponse(9);
      tracker.markSent(9);
      // 同边界/更旧边界候选直接拒绝。
      tracker.onContentResponse(9);
      tracker.beginCandidate(nowMs: 0);
      expect(tracker.advanceIfDue(nowMs: 600), isNull);
      // 更新边界仍可推进。
      tracker.onContentResponse(11);
      tracker.beginCandidate(nowMs: 1000);
      expect(tracker.advanceIfDue(nowMs: 1500), 11);
    });
  });

  group('view_watermark 能力门精度（与 J27.b 同款）', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
    });

    tearDown(() {
      AppManifestService.replaceForTest(<String, dynamic>{});
    });

    test('恰为整数 1 才启用', () {
      AppManifestService.replaceForTest({
        'channel_contracts': {'view_watermark': 1},
      });
      expect(AppManifestService.manifest?.viewWatermarkEnabled, isTrue);
    });

    test('缺失 / true / "1" / 2 一律不启用（未知能力不发送新边界）', () {
      for (final raw in const [null, true, '1', 2, 1.0]) {
        AppManifestService.replaceForTest({
          'channel_contracts': {'view_watermark': raw},
        });
        expect(
          AppManifestService.manifest?.viewWatermarkEnabled,
          isFalse,
          reason: 'view_watermark=$raw 不应启用',
        );
      }
    });
  });

  group('ChannelApi.markViewed（传输形状）', () {
    late List<RequestOptions> requests;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      await StorageService.to.setBool('token_decryption_failed', false);
      requests = <RequestOptions>[];
    });

    tearDown(() {
      HttpClient.adapterForTest = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          );
    });

    ResponseBody _respond(Map<String, dynamic> payload, {int code = 0}) =>
        ResponseBody.fromString(
          jsonEncode({'code': code, 'msg': 'ok', 'payload': payload}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    test('POST viewed 携带 boundary；成功解析 (view_seq, unseen_count)', () async {
      HttpClient.adapterForTest = _CaptureAdapter(requests, (options) {
        expect(options.uri.path, '/api/v1/channel/880910/viewed');
        expect(options.data['boundary'], '7');
        return _respond({'view_seq': 7, 'unseen_count': 0});
      });
      final result = await ChannelApi().markViewed('880910', '7');
      expect(result, isNotNull);
      expect(result!.viewSeq, 7);
      expect(result.unseenCount, 0);
      expect(requests, hasLength(1));
    });

    test('失败返回 null（调用方给重试，不洗成已查看）', () async {
      HttpClient.adapterForTest = _CaptureAdapter(requests, (options) {
        return _respond(<String, dynamic>{}, code: 400);
      });
      final result = await ChannelApi().markViewed('880910', '7');
      expect(result, isNull);
    });
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.requests, this.responder);

  final List<RequestOptions> requests;
  final ResponseBody Function(RequestOptions options) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}
