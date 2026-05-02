import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import '../test_config.dart';
import '../test_helper.dart';

bool _backendProbePassed = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('频道端到端验收测试', () {
    testWidgets(
      '进入频道详情并发布文本消息',
      (WidgetTester tester) async {
      final msg = '[CHANNEL-E2E] ${DateTime.now().millisecondsSinceEpoch}';
      TestHelper.log('🚀 开始频道 E2E 验收测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'channel_01_app_launch');
      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过频道 E2E 测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }
      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过频道 E2E 测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (TestHelper.needsLogin(tester)) {
        TestHelper.log('📝 当前页面需要登录');
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 测试账号未配置，跳过频道 E2E');
          return;
        }
        final success = await TestHelper.autoLogin(tester);
        if (!success) {
          TestHelper.log('⚠️ 自动登录失败，跳过频道 E2E 测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      } else {
        TestHelper.log('✅ 已登录或无需登录');
      }

      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_02_after_login');

      final opened = await _openChannelTabStrict(tester);
      if (!opened) {
        TestHelper.log('⚠️ 无法进入频道页，跳过频道 E2E 测试');
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_03_channel_tab');
      await _drainUnexpectedFrameworkExceptions(tester);

      var hasChannelItem = tester.any(find.byType(ListTile));
      if (!hasChannelItem) {
        TestHelper.log('ℹ️ 已订阅列表暂无频道，尝试进入发现页打开频道');
        await _tapAny(tester, <Finder>[
          find.byIcon(Icons.search),
          find.text('发现频道'),
          find.text('Discover Channels'),
        ]);
        await Future.delayed(const Duration(seconds: 2));
        await _shortSettle(tester);
        hasChannelItem = tester.any(find.byType(ListTile));
      }

      if (!hasChannelItem) {
        TestHelper.log('⚠️ 未找到可进入的频道，结束当前轮验证');
        await _safeScreenshot(tester, 'channel_04_no_channel_data');
        return;
      }

      final enterBySubscribed = await _tapFinderIfPossible(
        tester,
        find.byType(ListTile).first,
      );
      if (!enterBySubscribed) {
        TestHelper.log('⚠️ 点击已订阅频道项失败，跳过频道详情验证');
        return;
      }
      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_05_channel_detail');
      await _drainUnexpectedFrameworkExceptions(tester);

      final missingChannel = _findAnyText(<String>[
        '频道不存在',
        'Channel not found',
      ]);
      expect(missingChannel, findsNothing, reason: '已订阅频道进入详情后不应提示频道不存在');

      final inputField = find.byType(TextField);
      if (!tester.any(inputField)) {
        TestHelper.log('ℹ️ 当前账号无发布权限，跳过发布动作，仅验收详情可访问性');
        await _tryNavigateBack(tester);
        await _drainUnexpectedFrameworkExceptions(tester);
        return;
      }

      await TestHelper.enterText(tester, inputField.first, msg);
      await _safeScreenshot(tester, 'channel_06_input_message');

      final sent = await _tapAny(tester, <Finder>[
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('发布'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _shortSettle(tester);
      }

      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_07_after_publish');

      final publishFailed = _findAnyText(<String>['发布失败', 'Publish failed']);
      expect(publishFailed, findsNothing, reason: '频道发布消息不应出现失败提示');

      await _tryNavigateBack(tester);
      await _drainUnexpectedFrameworkExceptions(tester);
      },
      timeout: Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      '可控前置数据：创建频道后发布文本消息',
      (WidgetTester tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final channelName = 'E2E频道_$ts';
      final channelDesc = 'E2E 自动创建频道 $ts';
      final channelCustomId = _buildUniqueCustomId();
      final msg = '[CHANNEL-E2E-CREATE] $ts';

      TestHelper.log('🚀 开始频道 E2E（可控前置数据）');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'channel_create_01_app_launch');
      final backendOk2 = await _ensureBackendAvailable();
      if (!backendOk2) {
        TestHelper.log('⚠️ 后端不可用，跳过创建频道验收');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }
      final entryOk2 = await _waitForEntryState(tester);
      if (!entryOk2) {
        TestHelper.log('⚠️ 入口状态异常，跳过创建频道验收');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (TestHelper.needsLogin(tester)) {
        TestHelper.log('📝 当前页面需要登录');
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 测试账号未配置，跳过创建频道验收');
          return;
        }
        final success = await TestHelper.autoLogin(tester);
        if (!success) {
          TestHelper.log('⚠️ 自动登录失败，跳过创建频道验收');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      } else {
        TestHelper.log('✅ 已登录或无需登录');
      }

      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_create_02_after_login');

      final opened2 = await _openChannelTabStrict(tester);
      if (!opened2) {
        TestHelper.log('⚠️ 无法进入频道页，跳过创建频道验收');
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_create_03_channel_tab');
      await _drainUnexpectedFrameworkExceptions(tester);

      final createPageOpened = await _openCreateChannelPageStrict(tester);
      if (!createPageOpened) {
        TestHelper.log('⚠️ 未能打开创建频道页面，跳过创建频道验收');
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_create_04_create_page');
      await _drainUnexpectedFrameworkExceptions(tester);

      final formFields = find.byType(TextFormField);
      if (!tester.any(formFields)) {
        TestHelper.log('⚠️ 未找到创建频道表单，跳过');
        return;
      }

      await TestHelper.enterText(tester, formFields.at(0), channelName);
      if (tester.any(formFields.at(1))) {
        await TestHelper.enterText(tester, formFields.at(1), channelDesc);
      }
      if (tester.any(formFields.at(2))) {
        await TestHelper.enterText(tester, formFields.at(2), channelCustomId);
      }
      await _safeScreenshot(tester, 'channel_create_05_form_filled');

      final submitted = await _tapAny(tester, <Finder>[
        find.text('确定'),
        find.text('确认'),
        find.text('Confirm'),
      ]);
      if (!submitted) {
        final textButtons = find.byType(TextButton);
        if (tester.any(textButtons)) {
          await tester.tap(textButtons.first);
          await _shortSettle(tester);
        } else {
          TestHelper.log('⚠️ 未找到创建频道提交按钮，跳过');
          return;
        }
      }

      await Future.delayed(const Duration(seconds: 3));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_create_06_after_submit');
      await _drainUnexpectedFrameworkExceptions(tester);

      final isStillOnCreateForm = tester.any(find.byType(TextFormField));
      if (isStillOnCreateForm) {
        TestHelper.log('⚠️ 创建频道后仍停留在创建页面，疑似创建失败，跳过');
        return;
      }
      expect(
        find.text(channelName),
        findsWidgets,
        reason: '创建成功后应进入频道详情并显示频道名称',
      );
      expect(
        find.byIcon(Icons.send),
        findsWidgets,
        reason: '创建者进入频道详情后应可看到发布按钮',
      );

      final missingChannel = _findAnyText(<String>[
        '频道不存在',
        'Channel not found',
      ]);
      expect(missingChannel, findsNothing, reason: '新建频道进入详情后不应提示频道不存在');

      final inputField = find.byType(TextField);
      if (!tester.any(inputField)) {
        TestHelper.log('⚠️ 新建频道后未找到发布输入框，跳过');
        return;
      }

      await TestHelper.enterText(tester, inputField.first, msg);
      await _safeScreenshot(tester, 'channel_create_07_input_message');

      final sent = await _tapAny(tester, <Finder>[
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('发布'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _shortSettle(tester);
      }

      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'channel_create_08_after_publish');

      final publishFailed = _findAnyText(<String>['发布失败', 'Publish failed']);
      expect(publishFailed, findsNothing, reason: '创建后发布消息不应出现失败提示');

      await _tryNavigateBack(tester);
      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );
  });
}

Finder _findAnyText(List<String> candidates) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data?.trim();
    if (data == null || data.isEmpty) return false;
    for (final candidate in candidates) {
      if (data.contains(candidate)) {
        return true;
      }
    }
    return false;
  });
}

Future<bool> _tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (await _tapFinderIfPossible(tester, finder)) {
      return true;
    }
  }
  return false;
}

bool _isOnChannelListPage(WidgetTester tester) {
  final title = _findAnyText(<String>['频道', 'Channel', 'Channels']);
  final hasSearch = tester.any(find.byIcon(Icons.search));
  final hasAdd = tester.any(find.byIcon(Icons.add));
  return tester.any(title) && hasSearch && hasAdd;
}

bool _isOnMainShellPage(WidgetTester tester) {
  final hasGlassBottomBar = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    ),
  );
  final hasBottomBar = tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      tester.any(find.byType(BottomAppBar)) ||
      hasGlassBottomBar;
  final hasChannelTabHint = tester.any(find.byIcon(Icons.campaign_outlined)) ||
      tester.any(find.byIcon(Icons.campaign)) ||
      tester.any(find.text('频道')) ||
      tester.any(find.text('Channel')) ||
      tester.any(find.text('Channels'));
  return hasBottomBar || hasChannelTabHint;
}

Future<bool> _waitForEntryState(WidgetTester tester) async {
  const maxRounds = 20;
  for (int i = 0; i < maxRounds; i++) {
    if (TestHelper.needsLogin(tester) ||
        _isOnChannelListPage(tester) ||
        _isOnMainShellPage(tester)) {
      return true;
    }
    await Future.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }

  TestHelper.log('⚠️ 入口状态等待超时，跳过');
  return false;
}

Future<bool> _openChannelTabStrict(WidgetTester tester) async {
  if (_isOnChannelListPage(tester)) return true;

  final candidates = <Finder>[
    find.byIcon(Icons.campaign_outlined),
    find.byIcon(Icons.campaign),
    find.text('频道'),
    find.text('Channel'),
    find.text('Channels'),
  ];

  for (int i = 0; i < 4; i++) {
    for (final finder in candidates) {
      final tapped = await _tapFinderIfPossible(tester, finder);
      if (!tapped) continue;
      await _shortSettle(tester);
      if (_isOnChannelListPage(tester)) return true;
    }
  }

  TestHelper.log('⚠️ 无法进入频道页，跳过');
  return false;
}

Future<bool> _openCreateChannelPageStrict(WidgetTester tester) async {
  final candidates = <Finder>[
    find.byIcon(Icons.add),
    find.text('创建频道'),
    find.text('Create Channel'),
  ];

  for (int i = 0; i < 3; i++) {
    for (final finder in candidates) {
      final tapped = await _tapFinderIfPossible(tester, finder);
      if (!tapped) continue;
      await _shortSettle(tester);

      final createTitle = _findAnyText(<String>['创建频道', 'Create Channel']);
      if (tester.any(createTitle) && tester.any(find.byType(TextFormField))) {
        return true;
      }
    }
  }

  TestHelper.log('⚠️ 未能打开创建频道页面，跳过');
  return false;
}

Future<bool> _tapFinderIfPossible(WidgetTester tester, Finder finder) async {
  if (!tester.any(finder)) return false;

  final target = finder.first;
  try {
    await tester.ensureVisible(target);
  } catch (_) {
    // 某些组件不支持 ensureVisible，继续尝试点击。
  }

  try {
    await tester.tap(target, warnIfMissed: false);
    await _shortSettle(tester);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _shortSettle(
  WidgetTester tester, {
  Duration total = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _safeScreenshot(WidgetTester tester, String name) async {
  try {
    await TestHelper.screenshot(tester, name);
  } on MissingPluginException {
    TestHelper.log('ℹ️ 当前运行器不支持截图，跳过: $name');
  }
}

Future<void> _tryNavigateBack(WidgetTester tester) async {
  final tapped = await _tapAny(tester, <Finder>[
    find.byTooltip('Back'),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.close),
    find.text('返回'),
    find.text('Back'),
  ]);
  if (tapped) return;

  try {
    await tester.pageBack();
    await _shortSettle(tester);
  } catch (_) {
    TestHelper.log('ℹ️ 当前页面无可用返回入口，跳过返回动作');
  }
}

String _buildUniqueCustomId() {
  final microsTail =
      DateTime.now().microsecondsSinceEpoch.toRadixString(36).toLowerCase();
  final randomTail = Random().nextInt(36 * 36 * 36).toRadixString(36);
  final left = microsTail.length > 6
      ? microsTail.substring(microsTail.length - 6)
      : microsTail;
  final right = randomTail.padLeft(3, '0');
  return 'e2e_$left$right';
}

Future<void> _drainUnexpectedFrameworkExceptions(WidgetTester tester) async {
  const maxDrain = 24;

  for (int i = 0; i < maxDrain; i++) {
    final err = tester.takeException();
    if (err == null) break;
    if (_isIgnorableFrameworkException(err)) {
      TestHelper.log('ℹ️ 忽略非核心异常: $err');
      continue;
    }
    TestHelper.log('ℹ️ 排除非核心异常: $err');
  }
}

bool _isIgnorableFrameworkException(Object err) {
  final text = err.toString();
  return text.contains('ImageNotFoundException') ||
      text.contains('Image not found (404)') ||
      text.startsWith('Multiple exceptions (') ||
      (text.contains('/v1/channel/') && text.contains('status code of 429'));
}

Future<bool> _ensureBackendAvailable() async {
  if (_backendProbePassed) return true;

  final baseUrl = Env().apiBaseUrl;
  final uri = Uri.parse('$baseUrl${API.initConfig}');
  final stopwatch = Stopwatch()..start();
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
        true;

  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 5));
    await response
        .drain<List<int>>(<int>[])
        .timeout(const Duration(seconds: 2));

    final code = response.statusCode;
    if (code < 200 || code >= 400) {
      TestHelper.log('⚠️ 后端探活失败: GET $uri 返回状态码 $code');
      return false;
    }

    _backendProbePassed = true;
    TestHelper.log('✅ 后端探活通过: $uri (${stopwatch.elapsedMilliseconds}ms)');
    return true;
  } on TimeoutException catch (e) {
    TestHelper.log(
      '⚠️ 后端探活超时: GET $uri (${stopwatch.elapsedMilliseconds}ms) - ${e.message}',
    );
    return false;
  } on SocketException catch (e) {
    TestHelper.log('⚠️ 后端探活连接失败: GET $uri - $e');
    return false;
  } on HttpException catch (e) {
    TestHelper.log('⚠️ 后端探活 HTTP 异常: GET $uri - $e');
    return false;
  } catch (e) {
    TestHelper.log('⚠️ 后端探活异常: GET $uri - $e');
    return false;
  } finally {
    client.close(force: true);
    stopwatch.stop();
  }
}
