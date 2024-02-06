import 'dart:convert';

class UserDeviceModel {
  String deviceId;
  String deviceName;
  String deviceType;
  int lastActiveAt;
  bool online;
  Map<dynamic, dynamic> deviceVsn;

  int get lastActiveAtLocal =>
      lastActiveAt + DateTime.now().timeZoneOffset.inMilliseconds;

  UserDeviceModel({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.lastActiveAt,
    this.online = false,
    required this.deviceVsn,
  });

  String get showType {
    if (deviceType == 'android') {
      return "$deviceType ${deviceVsn['version.sdkInt'] ?? ''}";
    } else if (deviceType == 'ios') {
      return "iPhone iOS ${deviceVsn['systemVersion'] ?? ''}";
    }
    return deviceType;
  }

  factory UserDeviceModel.fromJson(Map<String, dynamic> json) {
    var deviceVsn = json['device_vsn'] ?? '{}';
    try {
      deviceVsn = jsonDecode(deviceVsn);
    } catch (e) {
      deviceVsn = {};
    }
    return UserDeviceModel(
      deviceId: json['device_id'],
      deviceName: json['device_name'],
      deviceType: json['device_type'],
      lastActiveAt: json['last_active_at'],
      // 本地数据库 online ，线上获取有 online
      online: json['online'] ?? false,
      deviceVsn: deviceVsn,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['device_id'] = deviceId;
    data['device_name'] = deviceName;
    data['device_type'] = deviceType;
    data['last_active_at'] = lastActiveAt;
    data['online'] = online;
    data['device_vsn'] = deviceVsn;
    return data;
  }
}
