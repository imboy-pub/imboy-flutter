/// T09 — P3 坐席三态字段夹具（imboy-enterprise-uiux-v1）
///
/// 目标：以相同合成 wire DTO（真实 [CsQueueItem.fromJson] 解析，不改
/// DTO 层）驱动三态摘要、来源渠道与业务调用 trace。
///
/// 约束：测试时钟以固定偏移回推（queued_at = now − 固定分钟），不注入
/// 全局时钟；网络出口复用 HttpClient.adapterForTest 记录参数与调用次数；
/// 合成数据不含任何真实客户信息。
library;

import 'dart:async' show Stream;
import 'dart:convert' show jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/storage.dart';

/// 固定 org（TSID 形态合成值）。
const String p3OrgId = '7266418340025468901';

/// 合成队列 item wire 形状（[CsQueueItem.fromJson] 的真实输入）。
Map<String, dynamic> p3QueueItemWire({
  String id = '7266418340025500001',
  String maskedName = '张*三',
  String? preview = '你好，想咨询一下',
  bool hasLastMessage = true,
  String source = 'widget',
  int version = 3,
  int queuedMinutesAgo = 65,
  String status = 'queued',
}) {
  final Map<String, dynamic> wire = <String, dynamic>{
    'id': id,
    'contact_id': '7266418340025500099',
    'contact': <String, dynamic>{'masked_name': maskedName},
    // 测试时钟固定：以固定分钟偏移回推 epoch 秒（断言等待时长稳定）。
    'queued_at':
        (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 -
                queuedMinutesAgo * 60)
            .toString(),
    'version': version,
    'status': status,
    'source': source,
    'organization_id': p3OrgId,
    'conversation_id': '7266418340025468950',
    'business_identity_id': '',
  };
  if (hasLastMessage) {
    // hasLastMessage 由 last_message.id 非空决定；preview 可空（附件-only
    // /解密降级）→ 三态摘要的中间态。
    wire['last_message'] = <String, dynamic>{
      'id': '7266418340025500777',
      'preview': preview,
    };
  }
  return wire;
}

/// 队列页 payload（A0 键 `sessions` + 服务端计数）。
Map<String, dynamic> p3QueuePagePayload(List<Map<String, dynamic>> items) =>
    <String, dynamic>{
      'sessions': items,
      'next_after_id': null,
      'total': items.length,
      'total_by_status': <String, int>{'queued': items.length},
    };

/// 记录请求参数与调用次数；claim 按配置返回成功/409/403。
class P3RecordingAdapter implements HttpClientAdapter {
  P3RecordingAdapter({
    required this.queuePayload,
    this.claimStatusCode = 0,
    this.claimDelay = Duration.zero,
  });

  final Map<String, dynamic> queuePayload;
  final int claimStatusCode;
  final Duration claimDelay;

  final List<String> paths = <String>[];
  final List<String> methods = <String>[];
  final List<Map<String, dynamic>> claimBodies = <Map<String, dynamic>>[];
  int queueCalls = 0;
  int claimCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    methods.add(options.method);
    if (options.uri.path.endsWith('/claim')) {
      claimCalls++;
      claimBodies.add(
        options.data is Map
            ? Map<String, dynamic>.from(options.data as Map<dynamic, dynamic>)
            : <String, dynamic>{},
      );
      if (claimDelay > Duration.zero) {
        await Future<void>.delayed(claimDelay);
      }
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'code': claimStatusCode,
          'msg': claimStatusCode == 0 ? 'success' : 'synthetic-error',
          if (claimStatusCode == 0)
            'payload': <String, dynamic>{
              'session_id': '7266418340025500001',
              'business_identity_id': '7266418340025468902',
              'version': 4,
            },
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    queueCalls++;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'code': 0,
        'msg': 'success',
        'payload': queuePayload,
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 夹具句柄。
class P3FixtureHandle {
  final P3RecordingAdapter adapter;

  P3FixtureHandle({required this.adapter});
}

/// 挂载真实待接队列视图（CsQueueView → CsApi → 拦截出口）。
Future<P3FixtureHandle> pumpP3QueueFixture(
  WidgetTester tester, {
  required List<Map<String, dynamic>> items,
  int claimStatusCode = 0,
  Duration claimDelay = Duration.zero,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageService.init();

  final P3RecordingAdapter adapter = P3RecordingAdapter(
    queuePayload: p3QueuePagePayload(items),
    claimStatusCode: claimStatusCode,
    claimDelay: claimDelay,
  );
  final HttpClientAdapter? prevAdapter = HttpClient.adapterForTest;
  HttpClient.adapterForTest = adapter;
  // 出口替换须覆盖整个测试期（claim 点击发生在测试体）——tearDown 恢复，
  // 不在挂载函数 finally 里提前撤掉。
  addTearDown(() => HttpClient.adapterForTest = prevAdapter);

  await tester.pumpWidget(
    // 对齐 run.dart：TranslationProvider 在 builder 内，AppLoading host
    // 挂 EasyLoading（claim 结果 toast 路径可用）。
    MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          TranslationProvider(child: AppLoading.init()(context, child!)),
      home: const CsQueueView(orgId: p3OrgId),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return P3FixtureHandle(adapter: adapter);
}
