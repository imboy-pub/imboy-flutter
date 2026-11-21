import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/optional_sdk_consent.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/jpush_flutter_binding.dart';
import 'package:imboy/service/notification_payload_rules.dart';

class _PushChannel implements JPushPluginChannel {
  int setups = 0;
  int launches = 0;
  int reads = 0;
  Future<String> registration = Future.value('test-registration-id');
  Future<void> Function(Map<String, dynamic>)? connected;

  @override
  void setup({required bool production, required String channel}) => setups++;

  @override
  void registerHandlers({
    Future<void> Function(Map<String, dynamic>)? onOpenNotification,
    Future<void> Function(Map<String, dynamic>)? onReceiveNotification,
    Future<void> Function(Map<String, dynamic>)? onConnected,
  }) => connected = onConnected;

  @override
  Future<String> fetchRegistrationId() {
    reads++;
    return registration;
  }

  @override
  Future<Map<dynamic, dynamic>> fetchLaunchNotification() async {
    launches++;
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'durable grants are purpose, account, environment and policy scoped',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      OptionalSdkScope scope = (
        environment: 'local',
        endpoint: 'https://localhost',
        uid: 'tester-a',
        generation: 1,
      );
      final consent = OptionalSdkConsent(
        readScope: () => scope,
        policyVersion: '1',
      );
      expect(consent.grant(OptionalSdkPurpose.push), isNull);
      await consent.setGranted(OptionalSdkPurpose.push, true);
      final firstGrant = consent.grant(OptionalSdkPurpose.push);
      expect(firstGrant, isNotNull);
      expect(consent.grant(OptionalSdkPurpose.maps), isNull);
      final rebooted = OptionalSdkConsent(
        readScope: () => scope,
        policyVersion: '1',
      );
      expect(rebooted.grant(OptionalSdkPurpose.push), isNotNull);
      final upgraded = OptionalSdkConsent(
        readScope: () => scope,
        policyVersion: '2',
      );
      expect(upgraded.grant(OptionalSdkPurpose.push), isNull);

      final original = scope;
      scope = (
        environment: 'test',
        endpoint: scope.endpoint,
        uid: scope.uid,
        generation: 1,
      );
      expect(consent.grant(OptionalSdkPurpose.push), isNull);
      scope = (
        environment: 'local',
        endpoint: scope.endpoint,
        uid: 'tester-b',
        generation: 2,
      );
      expect(consent.grant(OptionalSdkPurpose.push), isNull);
      scope = original;
      final withdrawal = consent.setGranted(OptionalSdkPurpose.push, false);
      expect(consent.grant(OptionalSdkPurpose.push), isNull);
      await withdrawal;
      expect(rebooted.grant(OptionalSdkPurpose.push), isNull);
      await consent.setGranted(OptionalSdkPurpose.push, true);
      expect(consent.grant(OptionalSdkPurpose.push), isNot(firstGrant));
    },
  );

  test(
    'absent permission makes no SDK calls and can subsequently be granted',
    () async {
      final channel = _PushChannel();
      final tokens = <String>[];
      Object? grant;
      final wiring = JPushSdkWiring.withDefaults(
        plugin: channel,
        enabledCheck: () => true,
        readConsent: () => grant,
        tokenInjector: (id) async => tokens.add(id),
        registrationIdPollAttempts: 1,
      );

      await wiring.initialize();
      expect((channel.setups, channel.launches, channel.reads), (0, 0, 0));
      expect(tokens, isEmpty);

      grant = Object();
      await wiring.initialize();
      await pumpEventQueue();
      expect((channel.setups, channel.launches, channel.reads), (1, 1, 1));
      expect(tokens, ['test-registration-id']);
    },
  );

  test(
    'withdrawal and a new grant fence stale registration and taps',
    () async {
      final pending = Completer<String>();
      final channel = _PushChannel()..registration = pending.future;
      final tokens = <String>[];
      final taps = <NotificationParseResult>[];
      Object? grant = Object();
      final wiring = JPushSdkWiring.withDefaults(
        plugin: channel,
        enabledCheck: () => true,
        readConsent: () => grant,
        tokenInjector: (id) async => tokens.add(id),
        tapRouter: taps.add,
        registrationIdPollAttempts: 1,
      );

      await wiring.initialize();
      expect(channel.reads, 1);
      grant = null;
      await wiring.handleOpenNotification({});
      await channel.connected!({});
      expect(taps, isEmpty);
      expect(channel.reads, 1);

      grant = Object();
      pending.complete('previous-grant-id');
      await pumpEventQueue();
      expect(tokens, isEmpty);

      final previousCallback = channel.connected!;
      channel.registration = Future.value('current-grant-id');
      await wiring.stop();
      await wiring.initialize();
      await pumpEventQueue();
      await previousCallback({});
      expect(tokens, ['current-grant-id']);
    },
  );
}
