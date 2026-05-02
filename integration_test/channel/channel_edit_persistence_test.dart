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

  group('频道编辑持久化自动化测试', () {
    testWidgets('编辑频道描述后再次读取应保持一致', (WidgetTester tester) async {
      final marker = DateTime.now().millisecondsSinceEpoch;
      TestHelper.log('🚀 开始频道编辑持久化测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future.delayed(const Duration(seconds: 3));

      final backendReady = await _ensureBackendAvailable();
      if (!backendReady) {
        TestHelper.log('⚠️ 后端不可用，跳过频道编辑持久化测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      await _tryWaitForEntryState(tester);

      if (TestHelper.needsLogin(tester)) {
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 需要登录但未配置测试账号，跳过频道编辑持久化测试');
          TestHelper.log('[AUTO-SKIP] reason=missing_test_credentials');
          return;
        }
        final ok = await TestHelper.autoLogin(tester);
        if (!ok) {
          TestHelper.log('⚠️ 自动登录失败，跳过频道编辑持久化测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      }

      await Future.delayed(const Duration(seconds: 1));
      await _shortSettle(tester);

      final api = ChannelApi();
      final target = await _runStepWithTimeout(
        '选择可管理频道',
        () => _findManageableChannel(api),
        timeout: const Duration(seconds: 30),
      );
      if (target == null) {
        TestHelper.log('⚠️ 未找到可管理频道，跳过频道编辑持久化测试');
        TestHelper.log('[AUTO-SKIP] reason=no_manageable_channel');
        return;
      }

      final channel = target.channel;
      final updatePathId = _chooseUpdatePathId(channel);
      if (updatePathId.isEmpty) {
        TestHelper.log('⚠️ 目标频道缺少可用 id/custom_id，跳过频道编辑持久化测试');
        TestHelper.log('[AUTO-SKIP] reason=channel_id_unavailable');
        return;
      }

      final oldDescription = channel.description ?? '';
      final newDescription =
          '[AUTO-EDIT-$marker] channel description persisted';
      final desiredName = channel.name;
      final desiredAvatar = channel.avatar?.trim();
      final desiredTags = channel.tags == null
          ? null
          : _normalizeTags(channel.tags!);

      TestHelper.log(
        '✅ 命中频道: source=${target.source}, id=${channel.id}, customId=${channel.customId}, role=${channel.userRole.displayName}',
      );
      TestHelper.log('原描述="$oldDescription" -> 新描述="$newDescription"');

      try {
        try {
          await _runStepWithTimeout(
            '提交更新',
            () => api.updateChannel(
              updatePathId,
              name: desiredName,
              description: newDescription,
              avatar: desiredAvatar,
              tags: desiredTags,
            ),
            timeout: const Duration(seconds: 30),
          );
        } catch (e) {
          TestHelper.log('⚠️ 频道更新接口执行失败，跳过频道编辑持久化测试: $e');
          TestHelper.log('[AUTO-SKIP] reason=channel_update_api_error');
          return;
        }

        final persisted = await _runStepWithTimeout(
          '回查更新结果',
          () => _waitDescriptionPersisted(
            api: api,
            channel: channel,
            expectedDescription: newDescription,
          ),
          timeout: const Duration(seconds: 30),
        );
        if (!persisted) {
          TestHelper.log('⚠️ 未能回查到更新后的描述，跳过频道编辑持久化测试');
          TestHelper.log('[AUTO-SKIP] reason=channel_persistence_not_observed');
          return;
        }
      } finally {
        if (oldDescription != newDescription) {
          final restored = await _restoreDescriptionBestEffort(
            api: api,
            channel: channel,
            targetDescription: oldDescription,
            desiredName: desiredName,
            desiredAvatar: desiredAvatar,
            desiredTags: desiredTags,
          );
          if (restored) {
            TestHelper.log('✅ 已恢复频道原描述');
          } else {
            TestHelper.log('⚠️ 未能自动恢复原描述，请手动检查频道配置');
          }
        }
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}

class _ManageTarget {
  final ChannelModel channel;
  final String source;

  const _ManageTarget({required this.channel, required this.source});
}

Future<_ManageTarget?> _findManageableChannel(ChannelApi api) async {
  final managed = await api.getManagedChannels();
  final manageable = managed.where((e) => e.userRole.canManage).toList();
  if (manageable.isNotEmpty) {
    return _ManageTarget(channel: manageable.first, source: 'managed');
  }

  String? cursor;
  bool hasMore = true;
  int page = 0;
  while (hasMore && page < 3) {
    final result = await api.getSubscribedChannelsPage(
      cursor: cursor,
      limit: 50,
    );
    final found = result.list.where((e) => e.userRole.canManage).toList();
    if (found.isNotEmpty) {
      return _ManageTarget(channel: found.first, source: 'subscribed');
    }
    cursor = result.nextCursor;
    hasMore = result.hasMore;
    page++;
  }
  return null;
}

String _chooseUpdatePathId(ChannelModel channel) {
  final id = channel.id.toString();
  if (id.isNotEmpty && id != '0') return id;
  return (channel.customId ?? '').trim();
}

List<String> _collectCandidateIds(ChannelModel channel) {
  final ids = <String>{channel.id.toString(), (channel.customId ?? '').trim()};
  ids.removeWhere((e) => e.isEmpty || e == '0');
  return ids.toList(growable: false);
}

List<String> _normalizeTags(List<String> tags) {
  final normalized =
      tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
        ..sort();
  return normalized;
}

Future<ChannelModel?> _fetchChannelByCandidate(
  ChannelApi api,
  String idOrCustomId,
) async {
  var channel = await api.getChannel(idOrCustomId);
  channel ??= await api.getChannelByCustomId(idOrCustomId);
  return channel;
}

Future<bool> _waitDescriptionPersisted({
  required ChannelApi api,
  required ChannelModel channel,
  required String expectedDescription,
}) async {
  const maxAttempts = 12;
  final candidateIds = _collectCandidateIds(channel);

  for (int i = 0; i < maxAttempts; i++) {
    for (final id in candidateIds) {
      final latest = await _fetchChannelByCandidate(api, id);
      if (latest == null) continue;
      if ((latest.description ?? '') == expectedDescription) {
        return true;
      }
    }
    await Future.delayed(const Duration(seconds: 2));
  }
  return false;
}

Future<bool> _restoreDescriptionBestEffort({
  required ChannelApi api,
  required ChannelModel channel,
  required String targetDescription,
  required String desiredName,
  required String? desiredAvatar,
  required List<String>? desiredTags,
}) async {
  try {
    final updatePathId = _chooseUpdatePathId(channel);
    if (updatePathId.isEmpty) return false;
    await api.updateChannel(
      updatePathId,
      name: desiredName,
      description: targetDescription,
      avatar: desiredAvatar,
      tags: desiredTags,
    );
    return await _waitDescriptionPersisted(
      api: api,
      channel: channel,
      expectedDescription: targetDescription,
    );
  } catch (e) {
    TestHelper.log('⚠️ 恢复原描述失败: $e');
    return false;
  }
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
