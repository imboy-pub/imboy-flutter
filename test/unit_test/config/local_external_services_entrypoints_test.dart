import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/config/local_external_services_policy.dart';
import 'package:imboy/service/jpush_flutter_binding.dart';
import 'package:imboy/service/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('service entrypoints follow explicit isolation mode', () async {
    const requested = bool.fromEnvironment(
      'IMBOY_LOCAL_EXTERNAL_SERVICES_DISABLED',
    );
    expect(LocalExternalServicesPolicy.suppressed, requested);
    if (!requested) {
      // Ordinary builds still reach the existing SDK enablement decision.
      var enabledChecks = 0;
      await JPushSdkWiring.withDefaults(
        enabledCheck: () {
          enabledChecks++;
          return false;
        },
      ).initialize();
      expect(enabledChecks, 1);
      LocalExternalServicesPolicy.validateEnvironment('pro');
      return;
    }
    var calls = 0;
    for (final channel in [
      'amap_flutter_location',
      'plugins.flutter.io/firebase_core',
      'plugins.flutter.io/firebase_messaging',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async {
            calls++;
            throw StateError('Unexpected external platform call');
          });
    }
    addTearDown(() {
      for (final channel in [
        'amap_flutter_location',
        'plugins.flutter.io/firebase_core',
        'plugins.flutter.io/firebase_messaging',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), null);
      }
    });
    // No storage bootstrap: an accidental NTP/cache path must fail this test.
    expect(await NtpHelper.getOffset(), NtpHelper.offset);
    AMapHelper.init();
    AMapHelper.setApiKey();
    AMapHelper.updatePrivacyShow(true, true);
    AMapHelper.updatePrivacyAgree(true);
    expect(await AMapHelper().startLocation(), isNull);
    expect(await LocationService().getCurrentPosition(), isNull);
    expect(LocationService().getPositionStream(), isNull);
    await PushNotificationService.instance.initialize();
    var enabledChecks = 0;
    await JPushSdkWiring.withDefaults(
      enabledCheck: () {
        enabledChecks++;
        return true;
      },
    ).initialize();
    expect(enabledChecks, 0);
    expect(calls, 0);
    expect(PushNotificationService.instance.fcmEnabled, isFalse);
    expect(PushNotificationService.instance.pushToken, isNull);
    expect(
      () => LocalExternalServicesPolicy.validateEnvironment('pro'),
      throwsStateError,
    );
  });
}
