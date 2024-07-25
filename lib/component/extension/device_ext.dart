import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

class DeviceExt extends DeviceInfoPlugin {
  static DeviceExt get to => Get.find();

  static Future<String> get did async {
    final Map<String, dynamic>? info = await to.detail;
    return info!["did"];
  }

  Future<Map<String, dynamic>?> get detail async {
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
}
