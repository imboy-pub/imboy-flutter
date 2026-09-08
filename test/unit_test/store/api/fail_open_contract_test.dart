/// 拉列表的 API 不许把"请求失败"伪装成"没有数据"。
///
/// 这是 2026-07-31 那次真机验收暴露的缺陷类：断网进群相册，页面显示的是
/// "暂无群相册"而不是"加载失败 + 重试"。根因不在 service 层（那里的
/// rethrow 全是死代码），而在 API 层——`HttpClient` 从不抛异常，失败只体现
/// 为 `resp.ok == false`，于是 `if (!resp.ok) return []` 把失败吃掉了，
/// 页面拿到一个合法的空列表，只能渲染空态。
///
/// 本文件覆盖的是**第二批**：这几条链路的页面早就写好了 `_error` +
/// `AsyncStateView(onRetry:)` 的失败态 UI，只是永远等不到那个异常。
///
/// 测试原理：注入一个恒返 503 的 HttpClientAdapter，让每个调用都必然落在
/// "请求失败"分支上——该抛就抛、该返 null 就返 null，返回空集合即为回归。
///
/// ⚠️ 必须自己注入出口，不能指望 `flutter test` 内置的 HttpOverrides mock：
/// 本项目的 HttpClient 用 `Http2Adapter`，自己管 socket，完全绕过 dart:io 的
/// HttpOverrides。不注入的话这个文件会真的打到 pro.imboy.pub——实测跑十几个
/// 用例就会被限流返 429。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_client.dart';

import 'package:imboy/service/group_schedule_service.dart';
import 'package:imboy/service/mention_service.dart';
import 'package:imboy/service/group_task_service.dart';
import 'package:imboy/store/api/agent_api.dart';
import 'package:imboy/store/api/denylist_api.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/store/api/feedback_api.dart';
import 'package:imboy/store/api/group_category_api.dart';
import 'package:imboy/store/api/group_schedule_api.dart';
import 'package:imboy/store/api/group_task_api.dart';
import 'package:imboy/store/api/mention_api.dart';
import 'package:imboy/store/api/user_device_api.dart';

/// 恒定失败的出口：不建连接，直接给一个 503。
class _AlwaysFailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('', 503);
  }

  @override
  void close({bool force = false}) {}
}

/// 恒定返回同一状态码与 JSON 体的出口：用来构造"业务失败
/// （HTTP 200 + code != 0）"和"畸形成功响应（HTTP 200 + code 0 但
/// payload 形状不对）"这两种 503 出口覆盖不到的分支。
class _StaticJsonAdapter implements HttpClientAdapter {
  _StaticJsonAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() {
    HttpClient.adapterForTest = _AlwaysFailingAdapter();
  });

  tearDownAll(() {
    HttpClient.adapterForTest = null;
  });

  /// 失败时必须抛，不能返回 null / [] / {} 这类"看起来正常的空"。
  void mustThrowOnFailure(String name, Future<Object?> Function() call) {
    test('$name 请求失败时抛出，不返回空兜底', () async {
      Object? returned;
      Object? thrown;
      try {
        returned = await call();
      } on Object catch (e) {
        thrown = e;
      }
      expect(
        thrown,
        isNotNull,
        reason:
            '返回了 $returned —— 页面会把它当成"暂无数据"渲染，'
            '用户看不出是断网还是真的没内容，也点不到重试',
      );
    });
  }

  group('黑名单', () {
    mustThrowOnFailure('DenylistApi.page', () => DenylistApi().page());
  });

  group('群日程', () {
    final api = GroupScheduleApi();
    mustThrowOnFailure('getSchedules', () => api.getSchedules(groupId: '1'));
    mustThrowOnFailure('getMySchedules', () => api.getMySchedules());
    mustThrowOnFailure(
      'getSchedule',
      () => api.getSchedule(groupId: '1', scheduleId: '1'),
    );
  });

  group('群分类', () {
    mustThrowOnFailure(
      'getCategories',
      () => GroupCategoryApi().getCategories(),
    );
  });

  group('群任务', () {
    final api = GroupTaskApi();
    mustThrowOnFailure('getTasks', () => api.getTasks(groupId: '1'));
    mustThrowOnFailure('getTask', () => api.getTask(groupId: '1', taskId: '1'));
    mustThrowOnFailure('getMyTasks', () => api.getMyTasks());
    mustThrowOnFailure(
      'getPendingReview',
      () => api.getPendingReview(taskId: '1'),
    );
  });

  group('登录设备', () {
    final api = UserDeviceApi();
    mustThrowOnFailure('page', () => api.page());
    mustThrowOnFailure('getActiveSessions', () => api.getActiveSessions());
  });

  group('意见反馈', () {
    final api = FeedbackApi();
    mustThrowOnFailure('page', () => api.page());
    mustThrowOnFailure('pageReply', () => api.pageReply(1));
  });

  // service 层是第二道吞噬点：API 抛了，service 里一句 `return null` 就能
  // 把它变回"没这条数据"。详情页拿到 null 会渲染成"日程/任务不存在"，
  // 和加载失败完全分不开。
  group('service 层不得二次吞掉', () {
    mustThrowOnFailure(
      'GroupScheduleService.getSchedule',
      () => GroupScheduleService.to.getSchedule(groupId: '1', scheduleId: '1'),
    );
    mustThrowOnFailure(
      'GroupTaskService.getTask',
      () => GroupTaskService.to.getTask(groupId: '1', taskId: '1'),
    );
  });

  // 另一种同样有效的失败信号：不抛异常，而是返回 null。@提及列表和助手广场
  // 走的是这条路——`null` 表示"请求失败"，成功但没内容返回的是带空 list 的
  // map。两者语义不同，页面才能把"加载失败+重试"和"暂无数据"分开渲染。
  //
  // 这组断言防的是有人"顺手"把 `return null` 改成 `return {}` / `return []`：
  // 那一改失败态就永久消失了，且不会有任何测试变红——除了这几条。
  void mustReturnNullOnFailure(String name, Future<Object?> Function() call) {
    test('$name 请求失败时返回 null，不返回空集合', () async {
      expect(
        await call(),
        isNull,
        reason: '返回了非 null 的空结果，页面会渲染成"暂无数据"，失败态和重试入口都没了',
      );
    });
  }

  group('null 即失败（不抛异常的那一派）', () {
    mustReturnNullOnFailure(
      'MentionApi.getMentions',
      () => MentionApi().getMentions(),
    );
    mustReturnNullOnFailure(
      'MentionService.getMentions',
      () => MentionService.to.getMentions(),
    );
    mustReturnNullOnFailure(
      'AgentApi.agentList',
      () => AgentApi.to.agentList(),
    );
  });

  // E2EEApi 的五个查询方法已 fail-closed：传输失败、业务失败、畸形成功
  // 响应一律抛错，绝不把失败压成空集合/"没有密钥"。reportDeviceKey 的
  // 契约刻意保持不变（失败返回 E2EEReportResult(ok:false)，由调用方
  // 决定重试），末尾有回归用例锁住。
  //
  // null 取舍：getComplianceKey / keyStatus 在 ok 且 payload 为 null 时
  // 返回 null——null 是这两条链路契约里写明的"无密钥/无法确认"空语义，
  // 下游（PolicyGate 拒发、恢复引导跳过）对 null 本来就是 fail-closed
  // 处理；只有 payload 非 Map 非 null 的畸形成功响应才抛 FormatException。
  //
  // 注意：adapterForTest 只对**之后构造**的实例生效，所以下面每个用例
  // 都先换 adapter、再在用例内现建 E2EEApi。
  group('E2EE 查询 fail-closed', () {
    /// 把出口临时换成恒返 [statusCode] + JSON [body] 的 adapter，
    /// 用例结束恢复 null，不污染同文件其他用例。
    void useAdapter(int statusCode, Map<String, dynamic> body) {
      HttpClient.adapterForTest = _StaticJsonAdapter(statusCode, body);
      addTearDown(() => HttpClient.adapterForTest = null);
    }

    Map<String, dynamic> envelope({int code = 0, dynamic payload}) {
      return {
        'code': code,
        'msg': code == 0 ? 'success' : 'business error',
        if (payload != null) 'payload': payload,
      };
    }

    test('传输失败（恒返 503）：五个查询方法全部抛错', () async {
      HttpClient.adapterForTest = _AlwaysFailingAdapter();
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = E2EEApi();
      await expectLater(api.userKeys(uid: '1'), throwsA(isA<Exception>()));
      await expectLater(
        api.groupMemberKeys(gid: '1'),
        throwsA(isA<Exception>()),
      );
      await expectLater(api.getComplianceKey(), throwsA(isA<Exception>()));
      await expectLater(api.keyStatus(), throwsA(isA<Exception>()));
      await expectLater(api.pullNotifications(), throwsA(isA<Exception>()));
    });

    test('业务失败（HTTP 200 + code != 0）：五个查询方法全部抛错', () async {
      useAdapter(200, envelope(code: 1));
      final api = E2EEApi();
      await expectLater(api.userKeys(uid: '1'), throwsA(isA<Exception>()));
      await expectLater(
        api.groupMemberKeys(gid: '1'),
        throwsA(isA<Exception>()),
      );
      await expectLater(api.getComplianceKey(), throwsA(isA<Exception>()));
      await expectLater(api.keyStatus(), throwsA(isA<Exception>()));
      await expectLater(api.pullNotifications(), throwsA(isA<Exception>()));
    });

    test('userKeys 畸形成功：缺 devices 抛 FormatException', () async {
      useAdapter(200, envelope(payload: <String, dynamic>{}));
      await expectLater(
        E2EEApi().userKeys(uid: '1'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('userKeys'),
          ),
        ),
      );
    });

    test('userKeys 畸形成功：devices 非 List 抛 FormatException', () async {
      useAdapter(200, envelope(payload: {'devices': 'oops'}));
      await expectLater(
        E2EEApi().userKeys(uid: '1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('userKeys 畸形成功：devices 元素非 Map 抛 FormatException', () async {
      useAdapter(
        200,
        envelope(
          payload: {
            'devices': ['oops'],
          },
        ),
      );
      await expectLater(
        E2EEApi().userKeys(uid: '1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('userKeys 畸形成功：payload 非 Map（如 String）抛 FormatException', () async {
      useAdapter(200, envelope(payload: 'oops'));
      await expectLater(
        E2EEApi().userKeys(uid: '1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('groupMemberKeys 畸形成功：缺 members 抛 FormatException', () async {
      useAdapter(200, envelope(payload: <String, dynamic>{}));
      await expectLater(
        E2EEApi().groupMemberKeys(gid: '1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('groupMemberKeys 畸形成功：members 非 List 抛 FormatException', () async {
      useAdapter(200, envelope(payload: {'members': 42}));
      await expectLater(
        E2EEApi().groupMemberKeys(gid: '1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('groupMemberKeys 畸形成功：payload 非 Map 抛 FormatException', () async {
      useAdapter(200, envelope(payload: 'oops'));
      await expectLater(
        E2EEApi().groupMemberKeys(gid: '1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('getComplianceKey 畸形成功：payload 非 Map 非 null 抛错', () async {
      useAdapter(200, envelope(payload: 'oops'));
      await expectLater(
        E2EEApi().getComplianceKey(),
        throwsA(isA<FormatException>()),
      );
    });

    test('keyStatus 畸形成功：payload 非 Map 非 null 抛错', () async {
      useAdapter(200, envelope(payload: [1, 2]));
      await expectLater(E2EEApi().keyStatus(), throwsA(isA<FormatException>()));
    });

    test('pullNotifications 畸形成功：Map 缺 notifications/list 抛错', () async {
      useAdapter(200, envelope(payload: {'count': 0}));
      await expectLater(
        E2EEApi().pullNotifications(),
        throwsA(isA<FormatException>()),
      );
    });

    test('pullNotifications 畸形成功：payload 非 Map 非 List 抛错', () async {
      useAdapter(200, envelope(payload: 3));
      await expectLater(
        E2EEApi().pullNotifications(),
        throwsA(isA<FormatException>()),
      );
    });

    test('合法空语义：devices=[] 返回 []，不是失败', () async {
      useAdapter(200, envelope(payload: {'devices': <dynamic>[]}));
      expect(await E2EEApi().userKeys(uid: '1'), isEmpty);
    });

    test('合法空语义：members=[] 返回 []', () async {
      useAdapter(200, envelope(payload: {'members': <dynamic>[]}));
      expect(await E2EEApi().groupMemberKeys(gid: '1'), isEmpty);
    });

    test('合法空语义：notifications=[] 返回 []', () async {
      useAdapter(
        200,
        envelope(payload: {'notifications': <dynamic>[], 'count': 0}),
      );
      expect(await E2EEApi().pullNotifications(), isEmpty);
    });

    test('合法空语义：getComplianceKey ok 且 payload 为 null 返回 null', () async {
      // 无 payload 键：契约里的"无密钥"空语义。下游 PolicyGate 对 null
      // 拒发，仍是 fail-closed。
      useAdapter(200, envelope());
      expect(await E2EEApi().getComplianceKey(), isNull);
    });

    test('合法空语义：keyStatus ok 且 payload 为 null 返回 null', () async {
      useAdapter(200, envelope());
      expect(await E2EEApi().keyStatus(), isNull);
    });

    test('pullNotifications 顶层 List 形状仍兼容', () async {
      useAdapter(
        200,
        envelope(
          payload: [
            {'user_id': 'u1'},
          ],
        ),
      );
      final list = await E2EEApi().pullNotifications();
      expect(list, hasLength(1));
      expect(list.first['user_id'], 'u1');
    });

    test('reportDeviceKey 业务失败仍返回 ok:false（契约不变，不抛错）', () async {
      useAdapter(200, envelope(code: 1));
      final r = await E2EEApi().reportDeviceKey(
        deviceId: 'dev-1',
        deviceType: 'android',
        publicKey: '-----BEGIN PUBLIC KEY-----',
        keyId: 'kid-1',
      );
      expect(r.ok, isFalse);
      expect(r.otherDeviceCount, 0);
      expect(r.hasOtherDevice, isFalse);
    });

    test('reportDeviceKey 恒返 503 也返回 ok:false（契约不变）', () async {
      HttpClient.adapterForTest = _AlwaysFailingAdapter();
      addTearDown(() => HttpClient.adapterForTest = null);
      final r = await E2EEApi().reportDeviceKey(
        deviceId: 'dev-1',
        deviceType: 'android',
        publicKey: '-----BEGIN PUBLIC KEY-----',
        keyId: 'kid-1',
      );
      expect(r.ok, isFalse);
      expect(r.hasOtherDevice, isFalse);
    });

    test('reportDeviceKey 成功返回 other_device_count（契约不变）', () async {
      useAdapter(200, envelope(payload: {'other_device_count': 2}));
      final r = await E2EEApi().reportDeviceKey(
        deviceId: 'dev-1',
        deviceType: 'android',
        publicKey: '-----BEGIN PUBLIC KEY-----',
        keyId: 'kid-1',
      );
      expect(r.ok, isTrue);
      expect(r.otherDeviceCount, 2);
      expect(r.hasOtherDevice, isTrue);
    });
  });
}
