/*
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();
  final FlutterLocalNotificationsPlugin np = FlutterLocalNotificationsPlugin();

  @override
  void onInit() {
    super.onInit();

    var android = const AndroidInitializationSettings("@mipmap/logo");
    // var ios = const IOSInitializationSettings();

    np.initialize(InitializationSettings(
      android: android,
      // iOS: ios,
    ));
  }

  @override
  void onClose() {
    np.cancelAll();
    super.onClose();
  }

  void send(String title, String body) {
    // 构建描述
    var androidDetails = const AndroidNotificationDetails('id描述', '名称描述',
        importance: Importance.max, priority: Priority.high);
    // var iosDetails = const IOSNotificationDetails();
    var details = NotificationDetails(
      android: androidDetails,
      // iOS: iosDetails,
    );

    // 显示通知, 第一个参数是id,id如果一致则会覆盖之前的通知
    np.show(DateTime.now().millisecondsSinceEpoch >> 10, title, body, details);
  }
}
*/