import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/store/api/user_device_api.dart' as api;
import 'package:imboy/store/repository/user_device_repo_sqlite.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_device_provider.g.dart';

/// UserDevice 模块的状态
class UserDeviceState {
  final List<UserDeviceModel> deviceList;
  final String currentDeviceId;
  final bool isLoading;

  // 新增：活跃会话列表
  final List<Map<String, dynamic>> activeSessions;
  final bool isLoadingSessions;

  const UserDeviceState({
    this.deviceList = const [],
    this.currentDeviceId = '',
    this.isLoading = false,
    this.activeSessions = const [],
    this.isLoadingSessions = false,
  });

  UserDeviceState copyWith({
    List<UserDeviceModel>? deviceList,
    String? currentDeviceId,
    bool? isLoading,
    List<Map<String, dynamic>>? activeSessions,
    bool? isLoadingSessions,
  }) {
    return UserDeviceState(
      deviceList: deviceList ?? this.deviceList,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      isLoading: isLoading ?? this.isLoading,
      activeSessions: activeSessions ?? this.activeSessions,
      isLoadingSessions: isLoadingSessions ?? this.isLoadingSessions,
    );
  }
}

@riverpod
class UserDeviceNotifier extends _$UserDeviceNotifier {
  @override
  UserDeviceState build() {
    // 初始化时设置当前设备ID
    return UserDeviceState(currentDeviceId: deviceId);
  }

  /// 设置当前设备ID
  void setCurrentDeviceId(String did) {
    state = state.copyWith(currentDeviceId: did);
  }

  /// 分页查询设备列表
  Future<List<UserDeviceModel>> fetchPage({int page = 1, int size = 10}) async {
    state = state.copyWith(isLoading: true);
    try {
      List<UserDeviceModel> list = [];
      page = page > 1 ? page : 1;
      int offset = (page - 1) * size;
      var repo = UserDeviceRepo();

      // 检查网络状态
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        // 离线模式：从本地数据库读取
        list = await repo.page(limit: size, offset: offset);
      } else {
        // 在线模式：从服务器获取
        Map<String, dynamic>? payload = await api.UserDeviceApi().page(
          page: page,
          size: size,
        );
        if (payload != null) {
          // 修复：添加空值检查
          final dynamic listData = payload['list'];
          if (listData is List) {
            for (var json in listData) {
              if (json is Map<String, dynamic>) {
                UserDeviceModel model = UserDeviceModel.fromJson(json);
                await repo.insert(model);
                list.add(model);
              }
            }
          }
        }
      }

      // 确保当前设备在列表中
      final currentDid = state.currentDeviceId;
      final hasCurrentDevice = list.any((d) => d.deviceId == currentDid);

      if (!hasCurrentDevice && currentDid.isNotEmpty) {
        // 获取设备信息
        final deviceInfo = await DeviceExt.to.detail;
        final deviceType = _getCurrentDeviceType();

        // 解析设备版本信息
        Map<dynamic, dynamic> deviceVsn = {};
        if (deviceInfo != null && deviceInfo['deviceVersion'] != null) {
          try {
            final vsnStr = parseModelString(deviceInfo['deviceVersion']);
            if (vsnStr.isNotEmpty) {
              deviceVsn = jsonDecode(vsnStr) as Map<dynamic, dynamic>;
            }
          } on Exception catch (e) {
            if (kDebugMode) {}
            deviceVsn = {};
          }
        }

        // 创建当前设备的模型
        final currentDevice = UserDeviceModel(
          deviceId: currentDid,
          deviceName: t.account.currentDevice,
          deviceType: deviceType,
          lastActiveAt: DateTimeHelper.millisecond(),
          online: true,
          deviceVsn: deviceVsn,
        );

        // 检查本地数据库中是否有当前设备的信息
        final localDevice = await repo.find(currentDid);
        if (localDevice != null) {
          // 使用本地数据库中的设备名称（可能已被用户修改）
          list.insert(0, localDevice);
        } else {
          // 使用默认名称并保存到数据库
          await repo.insert(currentDevice);
          list.insert(0, currentDevice);
        }
      }

      state = state.copyWith(deviceList: list, isLoading: false);
      return list;
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false);
      if (kDebugMode) {}
      return [];
    }
  }

  /// 删除设备
  Future<bool> deleteDevice(String deviceId) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    bool res2 = await api.UserDeviceApi().deleteDevice(deviceId: deviceId);
    if (res2 == false) {
      return false;
    }

    await UserDeviceRepo().delete(deviceId);

    // 从列表中移除
    final newList = List<UserDeviceModel>.from(state.deviceList);
    newList.removeWhere((e) => e.deviceId == deviceId);
    state = state.copyWith(deviceList: newList);

    return true;
  }

  /// 更改设备名称
  /// 返回: {success: bool, errorMsg: String?}
  Future<Map<String, dynamic>> changeName({
    required String deviceId,
    required String name,
  }) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return {'success': false, 'errorMsg': t.common.tipConnectDesc};
    }

    final apiResp = await api.UserDeviceApi().changeNameWithResponse(
      deviceId: deviceId,
      name: name,
    );

    if (!apiResp.ok) {
      return {
        'success': false,
        'errorMsg': apiResp.msg.isNotEmpty ? apiResp.msg : t.common.tipFailed,
      };
    }

    await UserDeviceRepo().update(deviceId, {UserDeviceRepo.deviceName: name});

    // 更新列表中的设备名称
    final newList = List<UserDeviceModel>.from(state.deviceList);
    final index = newList.indexWhere((e) => e.deviceId == deviceId);
    if (index >= 0) {
      newList[index] = UserDeviceModel(
        deviceId: newList[index].deviceId,
        deviceName: name,
        deviceType: newList[index].deviceType,
        lastActiveAt: newList[index].lastActiveAt,
        online: newList[index].online,
        deviceVsn: newList[index].deviceVsn,
      );
      state = state.copyWith(deviceList: newList);
    }

    return {'success': true, 'errorMsg': null};
  }

  /// 获取活跃会话列表
  /// 返回包含活跃设备和会话信息的列表
  Future<bool> loadActiveSessions() async {
    state = state.copyWith(isLoadingSessions: true);
    try {
      // 检查网络状态
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        state = state.copyWith(isLoadingSessions: false);
        return false;
      }

      final result = await api.UserDeviceApi().getActiveSessions();
      if (result != null) {
        final devices = result['devices'] as List<dynamic>? ?? [];
        state = state.copyWith(
          activeSessions: List<Map<String, dynamic>>.from(
            devices.map(
              (d) => Map<String, dynamic>.from(d as Map<dynamic, dynamic>),
            ),
          ),
          isLoadingSessions: false,
        );
        return true;
      }

      state = state.copyWith(isLoadingSessions: false);
      return false;
    } on Exception catch (e) {
      if (kDebugMode) {}
      state = state.copyWith(isLoadingSessions: false);
      return false;
    }
  }

  /// 检查登录冲突
  /// 返回包含冲突信息的 Map
  Future<Map<String, dynamic>?> checkLoginConflict(String deviceType) async {
    try {
      // 检查网络状态
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return null;
      }

      return await api.UserDeviceApi().checkLoginConflict(
        deviceType: deviceType,
      );
    } on Exception catch (e) {
      if (kDebugMode) {}
      return null;
    }
  }

  /// 踢出指定设备
  /// [deviceType] 要踢出的设备类型
  /// [deviceId] 要踢出的设备 ID
  /// 返回操作是否成功
  Future<Map<String, dynamic>?> kickDevice({
    required String deviceType,
    required String deviceId,
  }) async {
    try {
      // 检查网络状态
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return null;
      }

      final result = await api.UserDeviceApi().kickDevice(
        deviceType: deviceType,
        deviceId: deviceId,
      );

      if (result != null) {
        // 刷新设备列表
        await fetchPage();
      }

      return result;
    } on Exception catch (e) {
      if (kDebugMode) {}
      return null;
    }
  }

  /// 踢出所有其他设备
  /// 保留当前设备，踢出其他所有设备的会话
  /// [deviceType] 当前设备类型
  /// [deviceId] 当前设备 ID
  /// 返回操作是否成功
  Future<Map<String, dynamic>?> kickAllOtherDevices({
    required String deviceType,
    required String deviceId,
  }) async {
    try {
      // 检查网络状态
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return null;
      }

      final result = await api.UserDeviceApi().kickAllOtherDevices(
        deviceType: deviceType,
        deviceId: deviceId,
      );

      if (result != null) {
        // 刷新设备列表
        await fetchPage();
      }

      return result;
    } on Exception catch (e) {
      if (kDebugMode) {}
      return null;
    }
  }

  /// 获取设备名称，优先级：内存列表 > 本地库
  Future<String> getDeviceName(String deviceId) async {
    // 内存列表（若列表已加载）
    try {
      final idx = state.deviceList.indexWhere((e) => e.deviceId == deviceId);
      if (idx >= 0) {
        final name = state.deviceList[idx].deviceName;
        if (name.isNotEmpty) {
          return name;
        }
      }
    } catch (e) {}

    // 本地库回退
    try {
      final repo = UserDeviceRepo();
      final m = await repo.find(deviceId);
      if (m != null && m.deviceName.isNotEmpty) {
        return m.deviceName;
      }
    } catch (e) {}

    return '';
  }

  /// 让指定设备下线（向后端请求下发 S2C 指令）
  /// 参数:
  /// - deviceId: 目标设备ID（did）
  /// 返回:
  /// - true 表示请求成功（服务端将尝试向该设备下发下线指令），false 表示请求失败
  Future<bool> forceOffline(String deviceId) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    String name = await getDeviceName(deviceId);

    final message = {
      "id": "device_force_offline",
      "type": "S2C",
      "msg_type": "device_force_offline",
      "payload": {
        "by_did": deviceId,
        "by_name": name.isEmpty ? t.account.otherDevice : name,
      },
    };

    // 解耦：通过事件发送消息
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(message),
        messageId: message['id']?.toString(),
      ),
    );

    return true;
  }

  /// 加载设备列表
  Future<void> loadDevices({int page = 1, int size = 10}) async {
    await fetchPage(page: page, size: size);
  }

  /// 获取当前设备类型
  String _getCurrentDeviceType() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  }
}
