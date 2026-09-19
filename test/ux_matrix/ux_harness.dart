/// RUN: three-plan-integration-20260918T124045Z-6af21b0d | Card: R-UXAPP-01
///
/// UX 力学矩阵共享 harness（Organization / Customer Service 页面）。
///
/// 职责：
/// - 静态 HTTP 桩（dio `HttpClient.adapterForTest`，按 path 片段路由、
///   响应按序消费、耗尽停留最后一个；未命中路由返回 200 空 payload 对象，
///   避免 null 炸掉宽容解析）；
/// - mock flutter_secure_storage 平台通道（既有 widget 测试同款：无 mock
///   时 FakeAsync 内通道调用永不完成，页面永停 loading 并触发登出链）；
/// - 组合化 pump：viewport（logical px，dpr=1）× textScale × light/dark，
///   真实异步（dio 拦截器/transformer 链）用 runAsync 放行后 pump 反映；
/// - 机械断言工具：takeException 检查、可滚动结构存在性、有界
///   pumpUntilFound。
///
/// 纪律：本 harness 只服务测试，不改任何产品代码；overflow / 布局破绽
/// 一律保留 RED 断言（不放宽 takeException）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本次集成 run 与任务卡（文件头溯源用）。
const String kUxMatrixRunId =
    'three-plan-integration-20260918T124045Z-6af21b0d';
const String kUxMatrixCardId = 'R-UXAPP-01';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// 按 path 片段路由的静态响应桩。
///
/// 路由按声明顺序匹配（**更具体的片段必须放前面**，例如
/// `/organizations/7901/members` 要先于 `/organizations/7901`）；
/// 同片段响应按序消费、耗尽后停留最后一个（重复 GET 幂等友好）。
class RouteStubAdapter implements HttpClientAdapter {
  RouteStubAdapter(this.routes);

  final List<(String fragment, List<(int, Map<String, dynamic>)>)> routes;
  final Map<String, int> _cursor = {};
  int requestCount = 0;

  (int, Map<String, dynamic>) _match(String path) {
    for (final (fragment, responses) in routes) {
      if (path.contains(fragment)) {
        final i = _cursor.putIfAbsent(fragment, () => 0);
        _cursor[fragment] = (i + 1).clamp(0, responses.length - 1);
        return responses[i];
      }
    }
    // 未命中：200 + 空 payload 对象（宽容解析安全；null 会炸 fromJson）。
    return (
      200,
      <String, dynamic>{
        'code': 0,
        'msg': 'success',
        'payload': <String, dynamic>{},
      },
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    final (status, body) = _match(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> uxEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

/// 安装路由桩并在测试结束自动卸载（须在 testWidgets 体内调用）。
void uxInstallStub(RouteStubAdapter adapter) {
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = null);
}

/// 列表 envelope（departments 等纯列表端点：payload 协议必须为 Map，
/// 键 `list` 为数组——payload 直接给 List 会被 payloadList 判空）。
Map<String, dynamic> uxListPayload(List<dynamic> list) =>
    uxEnvelope(payload: {'list': list});

/// 分页 envelope（org mine / members 列表）。
Map<String, dynamic> uxPage(List<dynamic> list) => uxEnvelope(
  payload: {
    'list': list,
    'page': 1,
    'size': 10,
    'total': list.length,
    'total_page': 1,
  },
);

/// 初始化测试 binding / 存储 / secure_storage 通道 mock。
Future<void> initUxHarness() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
        if (call.method == 'readAll') return <String, String>{};
        return null;
      });
  await StorageService.init();
}

/// 撤销通道 mock 与 HTTP 桩。
void teardownUxHarness() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, null);
  HttpClient.adapterForTest = null;
}

/// 一个 UX 组合：viewport（logical px）× textScale × 亮暗。
class UxCombo {
  final Size viewport;
  final double textScale;
  final Brightness brightness;

  const UxCombo(
    this.viewport, {
    this.textScale = 1.0,
    this.brightness = Brightness.light,
  });
}

/// 小屏（iPhone SE 一代近似）。
const Size kUxSmallViewport = Size(320, 568);

/// 常规（iPhone 14/15 近似）。
const Size kUxMediumViewport = Size(390, 844);

/// 大屏（iPhone 15 Pro Max 近似）。
const Size kUxLargeViewport = Size(430, 932);

/// viewport sweep 组合（textScale 1.0 light）。
const List<Size> kUxViewportSweep = [
  kUxSmallViewport,
  kUxMediumViewport,
  kUxLargeViewport,
];

/// 统一 host：Material 主题（light/dark）+ TranslationProvider +
/// AppLoading host + MediaQuery textScaler 注入。
/// 对齐既有 CS widget 测试：TranslationProvider 挂在 MaterialApp.builder
/// 内（InheritedWidget 需在导航子树内）。
Widget uxHost(Widget page, UxCombo combo) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.light,
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      brightness: Brightness.dark,
    ),
    themeMode: combo.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light,
    builder: (context, child) {
      final wrapped = TranslationProvider(
        child: AppLoading.init()(context, child),
      );
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(combo.textScale)),
        child: wrapped,
      );
    },
    home: page,
  );
}

/// bootstrap 链路（token / dio 拦截器）含真实异步，fakeAsync pump 推不动：
/// runAsync 放行真实时间，再 pump 反映状态（对齐既有 CS widget 测试）。
Future<void> settleUx(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 按组合设置 surface 并 pump 页面；每拍后有界 settle。
Future<void> pumpUxCombo(
  WidgetTester tester,
  Widget page,
  UxCombo combo,
) async {
  tester.view.physicalSize = combo.viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(uxHost(page, combo));
  await settleUx(tester);
}

/// 有界 pumpUntilFound：fake pump 驱动纯异步链（对齐既有 org widget 测试）。
Future<void> pumpUntilUxFound(
  WidgetTester tester,
  Finder finder, {
  int rounds = 30,
}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
  }
}

/// 页面主内容是否在可滚动结构内（机械 find：任一滚动容器存在即通过）。
bool uxHasScrollable(WidgetTester tester) {
  return find.byType(SingleChildScrollView).evaluate().isNotEmpty ||
      find.byType(ListView).evaluate().isNotEmpty ||
      find.byType(CustomScrollView).evaluate().isNotEmpty;
}

/// 标准组合文案（reason 溯源用）。
String uxComboLabel(String page, UxCombo combo) {
  final mode = combo.brightness == Brightness.dark ? 'dark' : 'light';
  return '$page ${combo.viewport.width.toInt()}x'
      '${combo.viewport.height.toInt()} @${combo.textScale} $mode';
}
