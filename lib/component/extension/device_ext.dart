import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:imboy/component/helper/func.dart';
// 条件导入：在非 Web 平台使用存根，避免 dart:js_interop 错误
import 'device_ext_web_stub.dart'
    if (dart.library.html) 'device_ext_web.dart';

/// 设备信息扩展
///
/// 迁移说明：
/// - 已移除 GetX 依赖
/// - 使用单例模式替代 Get.find()
/// - 支持 Web 平台
class DeviceExt extends DeviceInfoPlugin {
  static DeviceExt? _instance;
  static DeviceExt get to {
    _instance ??= DeviceExt();
    return _instance!;
  }

  static Future<String> get did async {
    final Map<String, dynamic>? info = await to.detail;
    return info!["did"];
  }

  Future<Map<String, dynamic>?> get detail async {
    // 👇 Web 平台设备信息
    if (kIsWeb) {
      final browser = webBrowser;
      final userAgent = browser.userAgent;
      final screenWidth = browser.screenWidth;
      final screenHeight = browser.screenHeight;
      final language = browser.language;

      // 生成唯一的设备 ID（使用 localStorage 持久化）
      String? deviceId = browser.getItem('web_device_id');
      if (deviceId == null || deviceId.isEmpty) {
        final newDeviceId =
            'web_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
        browser.setItem('web_device_id', newDeviceId);
        deviceId = newDeviceId;
      }

      iPrint("DeviceExt/detail Web: $deviceId");

      return {
        "cos": "web",
        "did": deviceId,
        "id": deviceId,  // 👈 后端期望的 id 字段
        "deviceName": "Web Browser",
        "deviceVersion": json.encode({
          'userAgent': userAgent,
          'language': language,
          'screenWidth': screenWidth,
          'screenHeight': screenHeight,
          'platform': browser.platform,
          'vendor': browser.vendor,
          'cookieEnabled': browser.cookieEnabled,
          'onLine': browser.onLine,
        }),
      };
    }

    // 👇 移动端/桌面端设备信息
    if (Platform.isAndroid) {
      var data = await androidInfo;
      iPrint("DeviceExt/detail ${data.id}, ${data.toString()}");
      return {
        "cos": "android",
        "did": data.id,
        "deviceName": data.model,
        "deviceVersion": json.encode({
          'version.securityPatch': data.version.securityPatch,
          'version.sdkInt': data.version.sdkInt,
          'version.release': data.version.release,
          'version.previewSdkInt': data.version.previewSdkInt,
          'version.incremental': data.version.incremental,
          'version.codename': data.version.codename,
          'version.baseOS': data.version.baseOS,
          'board': data.board,
          'bootloader': data.bootloader,
          'brand': data.brand,
          'device': data.device,
          'display': data.display,
          'fingerprint': data.fingerprint,
          'hardware': data.hardware,
          'host': data.host,
          'id': data.id,
          'manufacturer': data.manufacturer,
          'model': data.model,
          'product': data.product,
          'supported32BitAbis': data.supported32BitAbis,
          'supported64BitAbis': data.supported64BitAbis,
          'supportedAbis': data.supportedAbis,
          'tags': data.tags,
          'type': data.type,
          'isPhysicalDevice': data.isPhysicalDevice,
          'systemFeatures': data.systemFeatures,
        }),
      };

      //UUID for Android
    } else if (Platform.isIOS) {
      var data = await iosInfo;
      return {
        "cos": "ios",
        "did": data.identifierForVendor,
        "deviceName": data.name,
        "deviceVersion": json.encode({
          'systemVersion': data.systemVersion,
          'model': data.model,
          'localizedModel': data.localizedModel,
          'identifierForVendor': data.identifierForVendor,
          'isPhysicalDevice': data.isPhysicalDevice,
          'utsname.sysname:': data.utsname.sysname,
          'utsname.nodename:': data.utsname.nodename,
          'utsname.release:': data.utsname.release,
          'utsname.version:': data.utsname.version,
          'utsname.machine:': data.utsname.machine,
        }),
      };
    } else if (Platform.isMacOS) {
      var data = await macOsInfo;
      return {
        "cos": "macos",
        "did": data.systemGUID,
        "deviceName": data.model,
        "deviceVersion": json.encode({
          'kernelVersion': data.kernelVersion,
          'computerName': data.computerName,
          'hostName': data.hostName,
          'arch': data.arch,
          'osRelease': data.osRelease,
          'activeCPUs': data.activeCPUs,
          'memorySize': data.memorySize,
          'cpuFrequency': data.cpuFrequency,
          'systemGUID': data.systemGUID,
        }),
      };
    } else if (Platform.isLinux) {
      var data = await linuxInfo;
      return {
        "cos": "linux",
        "did": data.id,
        "deviceName": data.name,
        "deviceVersion": json.encode({
          'version': data.version,
          'idLike': data.idLike,
          'versionCodename': data.versionCodename,
          'versionId': data.versionId,
          'prettyName': data.prettyName,
          'buildId': data.buildId,
          'variant': data.variant,
          'variantId': data.variantId,
          'machineId': data.machineId,
        }),
      };
    } else if (Platform.isWindows) {
      var data = await windowsInfo;
      return {
        "cos": "windows",
        "did": data.deviceId,
        "deviceName": data.productName,
        "deviceVersion": json.encode({
          'computerName': data.computerName,
          'numberOfCores': data.numberOfCores,
          'systemMemoryInMegabytes': data.systemMemoryInMegabytes,
          'userName': data.userName,
          'majorVersion': data.majorVersion,
          'minorVersion': data.minorVersion,
          'buildNumber': data.buildNumber,
          'platformId': data.platformId,
          'csdVersion': data.csdVersion,
          'servicePackMajor': data.servicePackMajor,
          'servicePackMinor': data.servicePackMinor,
          'suitMask': data.suitMask,
          'productType': data.productType,
          'reserved': data.reserved,
          'buildLab': data.buildLab,
          'buildLabEx': data.buildLabEx,
          'digitalProductId': data.digitalProductId,
          'displayVersion': data.displayVersion,
          'editionId': data.editionId,
          'installDate': data.installDate,
          'productId': data.productId,
          'productName': data.productName,
          'registeredOwner': data.registeredOwner,
          'releaseId': data.releaseId,
          'deviceId': data.deviceId,
        }),
      };
    }
    return {};
  }

  /// 生成随机字符串（用于 Web 设备 ID）
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final sb = StringBuffer();
    for (int i = 0; i < length; i++) {
      sb.write(chars[(random + i) % chars.length]);
    }
    return sb.toString();
  }
}
