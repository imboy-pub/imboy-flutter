import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';

class DeviceExt extends DeviceInfoPlugin {
  static DeviceExt get to => Get.find();

  static Future<String> get did async {
    Map<String, dynamic>? info = await to.detail;
    return info!["did"];
  }

  Future<Map<String, dynamic>?> get detail async {
    if (Platform.isAndroid) {
      var data = await androidInfo;
      return {
        "cos": "android",
        "deviceName": data.model,
        "deviceVersion": json.encode(data.version.toMap()),
        "did": data.id,
      };

      //UUID for Android
    } else if (Platform.isIOS) {
      var data = await iosInfo;
      return {
        "cos": "ios",
        "deviceName": data.name,
        "deviceVersion": data.systemVersion,
        "did": data.identifierForVendor,
      };
    } else if (Platform.isMacOS) {
      var data = await macOsInfo;
      return {
        "cos": "macOs",
        "deviceName": data.model,
        "deviceVersion": data.kernelVersion,
        "did": data.systemGUID,
      };
    }
    return null;
  }
}
