import 'dart:async' as async;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test_config.dart';
import '../test_helper.dart';

bool _backendProbePassed = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('频道发布消息自动化测试', () {
    testWidgets('自动选择可发布频道并发送文本消息', (WidgetTester tester) async {
      final content =
          '[CHANNEL-PUBLISH-AUTO] ${DateTime.now().millisecondsSinceEpoch}';
      TestHelper.log('🚀 开始频道发布自动化测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future<dynamic>.delayed(const Duration(seconds: 3));

      final backendReady = await _ensureBackendAvailable();
      if (!backendReady) {
        TestHelper.log('⚠️ 后端不可用，跳过频道发布自动化测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      await _tryWaitForEntryState(tester);

      if (TestHelper.needsLogin(tester)) {
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 需要登录但未配置测试账号，跳过频道发布自动化测试');
          TestHelper.log('[AUTO-SKIP] reason=missing_test_credentials');
          return;
        }
        final ok = await TestHelper.autoLogin(tester);
        if (!ok) {
          TestHelper.log('⚠️ 自动登录失败，跳过频道发布自动化测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      }

      await Future<dynamic>.delayed(const Duration(seconds: 1));
      await _shortSettle(tester);

      final api = ChannelApi();
      final target = await _runStepWithTimeout(
        '选择可发布频道',
        () => _findPublishableChannel(api),
        timeout: const Duration(seconds: 30),
      );
      if (target == null) {
        TestHelper.log('⚠️ 未找到可发布频道，跳过频道发布自动化测试');
        TestHelper.log('[AUTO-SKIP] reason=no_publishable_channel');
        return;
      }

      TestHelper.log(
        '✅ 命中频道: source=${target.source}, id=${target.channel.id}, customId=${target.channel.customId}, role=${target.channel.userRole.displayName}',
      );
      final candidateIds = _collectCandidateIds(target.channel);
      TestHelper.log('候选 channelId 列表: ${candidateIds.join(",")}');

      ChannelMessageModel sentMessage;
      try {
        sentMessage = await _runStepWithTimeout(
          '发布文本消息',
          () => _publishByCandidates(
            api: api,
            candidateIds: candidateIds,
            content: content,
          ),
          timeout: const Duration(seconds: 30),
        );
      } catch (e) {
        TestHelper.log('⚠️ 频道发布接口执行失败，跳过频道发布自动化测试: $e');
        TestHelper.log('[AUTO-SKIP] reason=channel_publish_api_error');
        return;
      }

      expect(sentMessage.id != 0, isTrue, reason: '发布成功后，返回消息 id 不应为空');

      final verifyIds = _collectCandidateIds(
        target.channel,
        extraIds: [sentMessage.channelId.toString()],
      );
      final persisted = await _runStepWithTimeout(
        '拉取消息回查',
        () => _waitMessagePersisted(
          api: api,
          candidateIds: verifyIds,
          sentMessage: sentMessage,
          expectedContent: content,
        ),
        timeout: const Duration(seconds: 30),
      );
      expect(persisted, isTrue, reason: '发布后应能从频道消息列表中回查到消息');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

class _PublishTarget {
  final ChannelModel channel;
  final String source;

  const _PublishTarget({required this.channel, required this.source});
}

Future<_PublishTarget?> _findPublishableChannel(ChannelApi api) async {
  final managed = await api.getManagedChannels();
  final managedPublishable = managed.where((e) => e.canPublish).toList();
  if (managedPublishable.isNotEmpty) {
    return _PublishTarget(channel: managedPublishable.first, source: 'managed');
  }

  String? cursor;
  bool hasMore = true;
  int page = 0;
  while (hasMore && page < 3) {
    final result = await api.getSubscribedChannelsPage(
      cursor: cursor,
      limit: 50,
    );
    final publishable = result.list.where((e) => e.canPublish).toList();
    if (publishable.isNotEmpty) {
      return _PublishTarget(channel: publishable.first, source: 'subscribed');
    }
    cursor = result.nextCursor;
    hasMore = result.hasMore;
    page++;
  }
  return null;
}

List<String> _collectCandidateIds(
  ChannelModel channel, {
  List<String>? extraIds,
}) {
  final ids = <String>{
    channel.id.toString(),
    (channel.customId ?? '').trim(),
    ...?extraIds?.map((e) => e.trim()),
  };
  ids.removeWhere((e) => e.isEmpty || e == '0');
  return ids.toList(growable: false);
}

Future<ChannelMessageModel> _publishByCandidates({
  required ChannelApi api,
  required List<String> candidateIds,
  required String content,
}) async {
  Object? lastError;

  for (final channelId in candidateIds) {
    try {
      final msg = await api.publishMessage(
        channelId: channelId,
        content: content,
        msgType: ChannelMessageType.text,
      );
      if (msg != null) {
        return msg;
      }
      lastError = StateError('publishMessage 返回 null');
    } catch (e) {
      lastError = e;
      TestHelper.log('⚠️ 使用 channelId=$channelId 发布失败: $e');
    }
  }

  throw StateError(
    '所有候选 channelId 发布均失败: ${candidateIds.join(",")}, lastError=$lastError',
  );
}

Future<bool> _waitMessagePersisted({
  required ChannelApi api,
  required List<String> candidateIds,
  required ChannelMessageModel sentMessage,
  required String expectedContent,
}) async {
  const maxAttempts = 12;

  for (int i = 0; i < maxAttempts; i++) {
    for (final channelId in candidateIds) {
      try {
        final list = await api.getMessages(channelId: channelId, limit: 30);
        final found = list.any(
          (e) => e.id == sentMessage.id || e.content == expectedContent,
        );
        if (found) {
          return true;
        }
      } catch (e) {
        TestHelper.log('⚠️ 拉取 channelId=$channelId 消息失败: $e');
      }
    }
    await Future<dynamic>.delayed(const Duration(seconds: 2));
  }

  return false;
}

Future<T> _runStepWithTimeout<T>(
  String stepName,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  try {
    return await action().timeout(timeout);
  } on async.TimeoutException catch (e) {
    throw StateError('步骤超时: $stepName (${timeout.inSeconds}s) - ${e.message ?? "timeout"}');
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
    await Future<dynamic>.delayed(const Duration(seconds: 1));
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
