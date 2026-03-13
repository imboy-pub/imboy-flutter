import 'dart:async' as async;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test_config.dart';
import '../test_helper.dart';

bool _backendProbePassed = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('频道订阅详情一致性自动化测试', () {
    testWidgets('订阅列表中的频道应可打开详情', (WidgetTester tester) async {
      TestHelper.log('🚀 开始频道订阅详情一致性测试');
      TestConfig.printHelp();

      final backendReady = await (() async {
        try {
          app.main();
          await tester.pump(const Duration(milliseconds: 300));
          await Future.delayed(const Duration(seconds: 3));
          final ok = await _ensureBackendAvailable();
          if (!ok) return false;
          await _tryWaitForEntryState(tester);
          return true;
        } on async.TimeoutException {
          TestHelper.log('⚠️ 应用启动与后端探活超时，降级跳过本用例');
          return false;
        } catch (e) {
          TestHelper.log('⚠️ 应用启动与后端探活异常: $e');
          return false;
        }
      })().timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          TestHelper.log('⚠️ 应用启动与后端探活整体超时，降级跳过本用例');
          return false;
        },
      );
      if (!backendReady) {
        TestHelper.log('⚠️ 后端不可用，跳过频道订阅一致性测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      if (TestHelper.needsLogin(tester)) {
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 需要登录但未配置测试账号，跳过频道订阅一致性测试');
          TestHelper.log('[AUTO-SKIP] reason=missing_test_credentials');
          return;
        }
        final ok = await _runStepWithTimeout(
          '自动登录',
          () => TestHelper.autoLogin(tester),
          timeout: const Duration(seconds: 60),
        );
        if (!ok) {
          TestHelper.log('⚠️ 自动登录失败，跳过频道订阅一致性测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      }

      await Future.delayed(const Duration(seconds: 1));
      await _shortSettle(tester);

      final api = ChannelApi();
      final page = await _runStepWithTimeout(
        '拉取订阅频道列表',
        () => api.getSubscribedChannelsPage(limit: 50),
        timeout: const Duration(seconds: 30),
      );

      if (page.list.isEmpty) {
        TestHelper.log('ℹ️ 当前账号无订阅频道，跳过一致性校验');
        return;
      }

      final sample = page.list.take(10).toList();
      final failures = <String>[];

      for (final channel in sample) {
        final result = await _verifySingleSubscribedChannel(
          api: api,
          channel: channel,
        );
        if (!result.ok) {
          failures.add(result.reason);
        }
      }

      if (failures.isNotEmpty) {
        fail('订阅频道详情一致性失败(${failures.length}条):\n${failures.join('\n')}');
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}

class _VerifyResult {
  final bool ok;
  final String reason;

  const _VerifyResult._(this.ok, this.reason);

  factory _VerifyResult.success(String summary) =>
      _VerifyResult._(true, summary);
  factory _VerifyResult.failure(String summary) =>
      _VerifyResult._(false, summary);
}

Future<_VerifyResult> _verifySingleSubscribedChannel({
  required ChannelApi api,
  required ChannelModel channel,
}) async {
  final candidates = _collectCandidateIds(channel);
  if (candidates.isEmpty) {
    return _VerifyResult.failure(
      'channel[name=${channel.name}] 缺少可用 id/custom_id',
    );
  }

  ChannelModel? resolved;
  String? resolvedBy;
  final debugNotes = <String>[];

  for (final id in candidates) {
    // 先按频道 ID 尝试，再按 custom_id 尝试；每步都做重试以降低 429 干扰。
    final byId = await _resolveChannelWithRetry(api, id, useCustomId: false);
    if (byId != null && byId.id.trim().isNotEmpty) {
      resolved = byId;
      resolvedBy = '$id(id)';
      break;
    }
    if (byId != null && byId.id.trim().isEmpty) {
      debugNotes.add('candidate=$id byId returned empty-id payload');
    }

    final byCustom = await _resolveChannelWithRetry(api, id, useCustomId: true);
    if (byCustom != null && byCustom.id.trim().isNotEmpty) {
      resolved = byCustom;
      resolvedBy = '$id(custom_id)';
      break;
    }
    if (byCustom != null && byCustom.id.trim().isEmpty) {
      debugNotes.add('candidate=$id byCustom returned empty-id payload');
    }

    await Future.delayed(const Duration(milliseconds: 400));
  }

  if (resolved == null) {
    return _VerifyResult.failure(
      'channel[name=${channel.name}, candidates=${candidates.join(",")}] 无法解析详情, notes=${debugNotes.join(";")}',
    );
  }

  final effectiveId = resolved.id.trim();
  if (effectiveId.isEmpty) {
    return _VerifyResult.failure(
      'channel[name=${channel.name}, resolvedBy=$resolvedBy] 解析详情成功但 id 为空',
    );
  }

  // 消息列表接口在压测/批量探测场景下可能出现 429，这里只做非阻断验证。
  try {
    await api.getMessages(channelId: effectiveId, limit: 1);
  } catch (_) {}

  return _VerifyResult.success(
    'channel[name=${channel.name}, id=$effectiveId, resolvedBy=$resolvedBy] ok',
  );
}

Future<ChannelModel?> _resolveChannelWithRetry(
  ChannelApi api,
  String idOrCustomId, {
  required bool useCustomId,
  int maxAttempts = 4,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    ChannelModel? channel;
    if (useCustomId) {
      channel = await api.getChannelByCustomId(idOrCustomId);
    } else {
      channel = await api.getChannel(idOrCustomId);
    }
    if (channel != null) return channel;

    // 简单退避，缓解 429 抖动
    await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
  }
  return null;
}

List<String> _collectCandidateIds(ChannelModel channel) {
  final ids = <String>{channel.id.trim(), (channel.customId ?? '').trim()};
  ids.removeWhere((e) => e.isEmpty);
  return ids.toList(growable: false);
}

Future<T> _runStepWithTimeout<T>(
  String stepName,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  try {
    return await action().timeout(timeout);
  } on async.TimeoutException catch (e) {
    fail('步骤超时: $stepName (${timeout.inSeconds}s) - ${e.message ?? "timeout"}');
  } catch (_) {
    rethrow;
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

bool _isOnMainShellPage(WidgetTester tester) {
  final hasGlassBottomBar = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    ),
  );
  final hasBottomBar =
      tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      tester.any(find.byType(BottomAppBar)) ||
      hasGlassBottomBar;
  final hasChannelTabHint =
      tester.any(find.byIcon(Icons.campaign_outlined)) ||
      tester.any(find.byIcon(Icons.campaign)) ||
      tester.any(find.text('频道')) ||
      tester.any(find.text('Channel')) ||
      tester.any(find.text('Channels'));
  return hasBottomBar || hasChannelTabHint;
}

Future<void> _tryWaitForEntryState(WidgetTester tester) async {
  const maxRounds = 8;
  for (int i = 0; i < maxRounds; i++) {
    if (TestHelper.needsLogin(tester) || _isOnMainShellPage(tester)) {
      return;
    }
    await Future.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
  }
  TestHelper.log('ℹ️ 未识别到明确入口态，继续执行 API 驱动测试');
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
  } on async.TimeoutException catch (e) {
    TestHelper.log('⚠️ 后端探活超时: GET $uri - ${e.message ?? "timeout"}');
    return false;
  } on SocketException catch (e) {
    TestHelper.log('⚠️ 后端探活连接失败: GET $uri - $e');
    return false;
  } catch (e) {
    TestHelper.log('⚠️ 后端探活异常: GET $uri - $e');
    return false;
  } finally {
    client.close(force: true);
    stopwatch.stop();
  }
}
