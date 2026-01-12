/// 事件总线单元测试
///
/// 测试事件总线的核心功能，包括：
/// - 基本发布订阅
/// - 多订阅者
/// - 取消订阅
/// - 事件过滤
/// - 事件转换
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/service/events/common_events.dart';

void main() {
  group('EventBus 基础功能测试', () {
    tearDown(() {
      // 每个测试后不需要特殊清理，因为 EventBus 是静态的
    });

    test('should publish and receive event', () async {
      // 安排
      final completer = Completer<UserLoginEvent>();
      UserLoginEvent? receivedEvent;

      // 行动
      final subscription = AppEventBus.on<UserLoginEvent>().listen((event) {
        receivedEvent = event;
        completer.complete(event);
      });

      AppEventBus.fire(UserLoginEvent(
        userId: 'test123',
        username: 'testuser',
      ));

      // 等待事件被处理
      final result = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('事件未在超时时间内接收到'),
      );

      // 断言
      expect(result, isNotNull);
      expect(result.userId, equals('test123'));
      expect(result.username, equals('testuser'));
      expect(receivedEvent, equals(result));

      // 清理
      subscription.cancel();
    });

    test('multiple subscribers should receive event', () async {
      // 安排
      final completer1 = Completer<UserLoginEvent>();
      final completer2 = Completer<UserLoginEvent>();
      final completer3 = Completer<UserLoginEvent>();

      final receivedEvents = <UserLoginEvent>[];

      // 行动 - 创建多个订阅者
      final sub1 = AppEventBus.on<UserLoginEvent>().listen((event) {
        receivedEvents.add(event);
        completer1.complete(event);
      });

      final sub2 = AppEventBus.on<UserLoginEvent>().listen((event) {
        receivedEvents.add(event);
        completer2.complete(event);
      });

      final sub3 = AppEventBus.on<UserLoginEvent>().listen((event) {
        receivedEvents.add(event);
        completer3.complete(event);
      });

      // 发布事件
      final testEvent = UserLoginEvent(
        userId: 'multi123',
        username: 'multiuser',
      );
      AppEventBus.fire(testEvent);

      // 等待所有订阅者接收到事件
      await Future.wait([
        completer1.future.timeout(const Duration(seconds: 2)),
        completer2.future.timeout(const Duration(seconds: 2)),
        completer3.future.timeout(const Duration(seconds: 2)),
      ]);

      // 断言
      expect(receivedEvents.length, equals(3));
      expect(receivedEvents.every((e) => e.userId == 'multi123'), isTrue);
      expect(receivedEvents.every((e) => e.username == 'multiuser'), isTrue);

      // 清理
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    });

    test('should not receive event after unsubscribe', () async {
      // 安排
      final receivedEvents = <UserLoginEvent>[];

      // 行动 - 创建订阅
      final subscription = AppEventBus.on<UserLoginEvent>().listen((event) {
        receivedEvents.add(event);
      });

      // 发布第一个事件（应该被接收）
      AppEventBus.fire(UserLoginEvent(
        userId: 'user1',
        username: 'user1',
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // 取消订阅
      subscription.cancel();

      // 等待一小段时间确保取消完成
      await Future.delayed(const Duration(milliseconds: 50));

      // 发布第二个事件（不应该被接收）
      AppEventBus.fire(UserLoginEvent(
        userId: 'user2',
        username: 'user2',
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // 断言 - 只应该接收到第一个事件
      expect(receivedEvents.length, equals(1));
      expect(receivedEvents[0].userId, equals('user1'));
    });

    test('should filter events', () async {
      // 安排
      final receivedEvents = <UserLoginEvent>[];
      final completer = Completer<void>();

      // 行动 - 创建带过滤的订阅
      final subscription = AppEventBus
          .on<UserLoginEvent>()
          .where((event) => event.userId.startsWith('target'))
          .listen((event) {
        receivedEvents.add(event);
        if (receivedEvents.length >= 2) {
          completer.complete();
        }
      });

      // 发布多个事件
      AppEventBus.fire(UserLoginEvent(userId: 'other1', username: 'other1'));
      AppEventBus.fire(UserLoginEvent(userId: 'target1', username: 'target1'));
      AppEventBus.fire(UserLoginEvent(userId: 'other2', username: 'other2'));
      AppEventBus.fire(UserLoginEvent(userId: 'target2', username: 'target2'));
      AppEventBus.fire(UserLoginEvent(userId: 'other3', username: 'other3'));

      // 等待过滤后的事件
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('过滤事件未在超时时间内接收到'),
      );

      // 断言
      expect(receivedEvents.length, equals(2));
      expect(receivedEvents[0].userId, equals('target1'));
      expect(receivedEvents[1].userId, equals('target2'));
      expect(receivedEvents.every((e) => e.userId.startsWith('target')), isTrue);

      // 清理
      subscription.cancel();
    });

    test('should transform events with map', () async {
      // 安排
      final completer = Completer<String>();
      String? transformedData;

      // 行动 - 创建带转换的订阅
      final subscription = AppEventBus
          .on<UserLoginEvent>()
          .map((event) => '${event.username}:${event.userId}')
          .listen((transformed) {
        transformedData = transformed;
        completer.complete(transformed);
      });

      // 发布事件
      AppEventBus.fire(UserLoginEvent(
        userId: 'map123',
        username: 'mapuser',
      ));

      // 等待转换后的数据
      final result = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('转换事件未在超时时间内接收到'),
      );

      // 断言
      expect(result, equals('mapuser:map123'));
      expect(transformedData, equals('mapuser:map123'));

      // 清理
      subscription.cancel();
    });

    test('should handle different event types independently', () async {
      // 安排
      final loginEvents = <UserLoginEvent>[];
      final logoutEvents = <UserLogoutEvent>[];
      final completer = Completer<void>();

      // 行动
      AppEventBus.on<UserLoginEvent>().listen((e) {
        loginEvents.add(e);
        if (loginEvents.isNotEmpty && logoutEvents.isNotEmpty && !completer.isCompleted) {
          completer.complete();
        }
      });

      AppEventBus.on<UserLogoutEvent>().listen((e) {
        logoutEvents.add(e);
        if (loginEvents.isNotEmpty && logoutEvents.isNotEmpty && !completer.isCompleted) {
          completer.complete();
        }
      });

      // 发布不同类型的事件
      AppEventBus.fire(UserLoginEvent(userId: 'user1', username: 'user1'));
      AppEventBus.fire(UserLogoutEvent(userId: 'user1', reason: 'timeout'));

      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('事件未在超时时间内接收到'),
      );

      // 断言
      expect(loginEvents.length, equals(1));
      expect(logoutEvents.length, equals(1));
      expect(loginEvents[0].userId, equals('user1'));
      expect(logoutEvents[0].userId, equals('user1'));
    });

    test('should handle rapid event publishing', () async {
      // 安排
      final receivedEvents = <UserLoginEvent>[];
      final completer = Completer<void>();

      // 行动
      final subscription = AppEventBus.on<UserLoginEvent>().listen((event) {
        receivedEvents.add(event);
        if (receivedEvents.length >= 100) {
          completer.complete();
        }
      });

      // 快速发布100个事件
      for (int i = 0; i < 100; i++) {
        AppEventBus.fire(UserLoginEvent(
          userId: 'rapid$i',
          username: 'rapiduser$i',
        ));
      }

      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('快速事件未在超时时间内全部接收'),
      );

      // 断言
      expect(receivedEvents.length, equals(100));

      // 清理
      subscription.cancel();
    });
  });
}
