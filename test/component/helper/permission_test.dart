// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/permission.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _GrantedPermissionHandlerPlatform extends PermissionHandlerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return PermissionStatus.granted;
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async {
    return ServiceStatus.enabled;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return {
      for (final permission in permissions)
        permission: PermissionStatus.granted,
    };
  }
}

class _GrantedPhotoManagerPlugin extends PhotoManagerPlugin {
  @override
  Future<PermissionState> requestPermissionExtend(
    PermissionRequestOption requestOption,
  ) async {
    return PermissionState.authorized;
  }
}

void main() {
  late PermissionHandlerPlatform originalPermissionPlatform;
  late PhotoManagerPlugin originalPhotoManagerPlugin;

  setUpAll(() {
    originalPermissionPlatform = PermissionHandlerPlatform.instance;
    originalPhotoManagerPlugin = PhotoManager.plugin;

    PermissionHandlerPlatform.instance = _GrantedPermissionHandlerPlatform();
    PhotoManager.withPlugin(_GrantedPhotoManagerPlugin());
  });

  tearDownAll(() {
    PermissionHandlerPlatform.instance = originalPermissionPlatform;
    PhotoManager.withPlugin(originalPhotoManagerPlugin);
  });

  group('requestPhotoPermission', () {
    test('在当前非 Web 实现下，授权后应该返回 true', () async {
      bool result = await requestPhotoPermission();
      expect(result, isTrue);
    });
  });

  group('requestCameraPermission', () {
    test('在当前非 Web 实现下，相机授权后应该返回 true', () async {
      bool result = await requestCameraPermission();
      expect(result, isTrue);
    });
  });

  group('requestLocationPermission', () {
    test('在当前平台符合现有实现约定', () async {
      final result = await requestLocationPermission();
      expect(result, Platform.isMacOS ? isFalse : isTrue);
    });
  });
}
