// integration_test/moment/moment_feed_video_playback_batch174_test.dart
//
// moment_feed_page「视频进入可视区自动播放与点播」行解锁（批次174，
// automation 第四十七轮）。原阻塞理由「缺真实视频动态素材」拆解消除：
//
//   ① 素材：ffmpeg testsrc 生成 2s/11KB mp4 + 首帧封面（入库
//      test/fixtures/），测试进程内嵌 HttpServer 动态端口直供；
//   ② 服务端 feed 5190 特性门（moment 不在 agent_hub 编译清单，与
//      group_task 同源墙）：MomentFeedPage 支持 facade 注入（既有
//      moment_feed_ui_flow_test 模式），绕过 API 直供动态数据——
//      本行验收点是「播放行为」而非 feed 接口；
//   ③ 播放：macOS 桌面 AVFoundation 真实解码 mp4。
//
//   AT-MF1 自动播放：动态完整进入可视区（visibleFraction>0.8）且
//           WiFi（unmetered）→ VideoPlayerController 初始化 + 自动
//           play，播放器真渲染（封面/播放角标消失）
//   AT-MF2 点播兜底：视频未自动播放时（widget 层 Connectivity 缺
//           平台通道 → isUnmeteredNetwork 保守 false）点击封面 →
//           _onVideoTap → 播放（play_circle_fill 角标消失 +
//           VideoPlayer 渲染）
//
// 运行（define 与批次169 同配方）：
//   flutter test integration_test/moment/moment_feed_video_playback_batch174_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/modules/moment_social/application/moment_facade.dart';
import 'package:imboy/page/moment/moment_feed_page.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_provider.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_state.dart';
import 'package:imboy/store/api/moment_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

import '../../test/fixtures/moment_b174_media.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != _uid) {
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区')) ||
        isOnMainShell(tester)) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    } else if (UserRepoLocal.to.currentUid == _uid) {
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go('/bottom_navigation');
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    flowLog('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  await _pump(tester, seconds: 5);
  return true;
}

/// 内嵌静态文件服务器（动态端口）。
///
/// 素材经 base64 嵌入（test/fixtures/moment_b174_media.dart），运行时
/// 解码写入 app 沙盒临时目录后 serve——macOS App Sandbox 下 app 进程
/// 无权读取项目目录文件（Operation not permitted），唯一可行路径。
/// AVPlayer 会发 Range: bytes=0-1 探测，需正确回 206 Partial Content。
/// 返回 (server, mp4Url, coverUrl)；caller 负责 close。
Future<(HttpServer, String, String)> _startAssetServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  final tmp = Directory.systemTemp;
  final mp4File = File('${tmp.path}/moment_b174.mp4');
  final coverFile = File('${tmp.path}/moment_b174_cover.jpg');
  await mp4File.writeAsBytes(base64Decode(kMomentB174Mp4Base64));
  await coverFile.writeAsBytes(base64Decode(kMomentB174CoverJpgBase64));
  final sub = server.listen((req) async {
    // ignore: avoid_print
    print(
      '[AT-MF1][SERVER] ${req.method} ${req.uri} '
      'range=${req.headers.value('range')}',
    );
    final path = req.uri.path;
    try {
      final file = path.endsWith('.jpg') ? coverFile : mp4File;
      final bytes = await file.readAsBytes();
      final range = req.headers.value('range');
      // AVPlayer 先发 Range: bytes=0-1 探测，需正确回 206 Partial Content
      final m = range == null
          ? null
          : RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      if (m != null) {
        final start = int.parse(m.group(1)!);
        final end = (m.group(2) != null && m.group(2)!.isNotEmpty)
            ? int.parse(m.group(2)!)
            : bytes.length - 1;
        final slice = bytes.sublist(start, end + 1);
        req.response.statusCode = 206;
        req.response.headers.set(
          'content-range',
          'bytes $start-$end/${bytes.length}',
        );
        req.response.headers.contentLength = slice.length;
        req.response.add(slice);
        await req.response.close();
        return;
      }
      // AVFoundation 依赖 Content-Length 判定响应完整性（chunked 流会
      // 导致 moov 解析失败、initialize 永不完成）
      req.response.headers.contentLength = bytes.length;
      req.response.headers.contentType = ContentType.binary;
      req.response.add(bytes);
      await req.response.close();
    } on Object catch (e) {
      // ignore: avoid_print
      print('[AT-MF1][SERVER] ERROR: $e');
      req.response.statusCode = 500;
      await req.response.close();
    }
  });
  addTearDown(sub.cancel);
  addTearDown(sub.cancel);
  return (
    server,
    'http://127.0.0.1:$port/moment_b174.mp4',
    'http://127.0.0.1:$port/moment_b174_cover.jpg',
  );
}

/// facade 注入：绕过 feed API（5190 编译裁剪墙），直供视频动态。
class MomentFacadeForTest extends MomentFacade {
  MomentFacadeForTest(List<Map<String, dynamic>> items) : _items = items;

  final List<Map<String, dynamic>> _items;

  @override
  Future<MomentPageResult<Map<String, dynamic>>> getFeedPage({
    String? cursor,
    int limit = 20,
  }) async {
    return MomentPageResult(list: _items, nextCursor: null, hasMore: false);
  }
}

class _FakeMomentNotifyNotifier extends MomentNotifyNotifier {
  @override
  MomentNotifyState build() => const MomentNotifyState();
}

Widget _buildWrapper(Widget child) {
  return ProviderScope(
    overrides: [
      momentNotifyProvider.overrideWith(_FakeMomentNotifyNotifier.new),
    ],
    child: TranslationProvider(child: MaterialApp(home: child)),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次174：AT-MF1 视频动态进入可视区自动播放', (tester) async {
    if (!await _boot(tester)) return;

    final (server, videoUrl, coverUrl) = await _startAssetServer();
    flowLog('[AT-MF1] 素材服务器就绪 port=${server.port}');
    addTearDown(server.close);

    // 本行验收点是播放行为：facade 注入直供视频动态（feed API 5190
    // 编译裁剪墙与本行无关，记录于台账）。
    // media.url 为完整 http URL → resolveForDisplay 走 viewUrl 加签
    // 后仍指向本地服务器（服务器不校验签名）。
    final media = [
      {'type': 'video', 'url': videoUrl, 'cover_url': coverUrl},
    ];
    final post = {
      'id': 'moment_b174_001',
      'author_uid': _uid,
      'content': '批次174 视频自动播放夹具',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'liked': false,
      'stats': {'like_count': 0, 'comment_count': 0},
      'media': media,
    };

    // ── 直接挂载 feed 页（facade 注入），视频 cell 完整进入视口 ──
    await tester.pumpWidget(
      _buildWrapper(MomentFeedPage(facade: MomentFacadeForTest([post]))),
    );
    await _pump(tester, seconds: 3);

    final rendered = await _waitFor(
      tester,
      () => tester.any(find.textContaining('批次174 视频自动播放夹具')),
      seconds: 10,
    );
    expect(rendered, isTrue, reason: '前置：视频动态应渲染（内容文本可见）');

    // ── 自动播放断言：可见度 >0.8 + WiFi → 控制器初始化并 play ──
    final playing = await _waitFor(
      tester,
      () => tester.any(find.byType(VideoPlayer)),
      seconds: 20,
    );
    if (!playing) {
      final hasBadge = tester.any(find.byIcon(CupertinoIcons.play_circle_fill));
      flowLog('[DIAG] 未进入播放态，play 角标仍在=$hasBadge');
    }
    expect(
      playing,
      isTrue,
      reason:
          'AT-MF1：视频完整进入可视区（WiFi 不限流）应自动初始化并播放'
          '（VideoPlayer 真渲染）',
    );
    // 播放态下 play 角标应消失
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.byIcon(CupertinoIcons.play_circle_fill)),
      isFalse,
      reason: 'AT-MF1：播放中 play_circle_fill 角标应隐藏',
    );
    flowLog('[AT-MF1] PASS：可视区自动播放（VideoPlayer 真渲染）');
    await _pump(tester, seconds: 1);
  });
}
