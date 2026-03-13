import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class UserDeviceModel {
  String deviceId;
  String deviceName;
  String deviceType;
  int lastActiveAt;
  bool online;
  Map<dynamic, dynamic> deviceVsn;

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
    final deviceVsn = parseModelJsonMap(json['device_vsn']) ?? {};
    return UserDeviceModel(
      deviceId: parseModelString(json['device_id']),
      deviceName: parseModelString(json['device_name']),
      deviceType: parseModelString(json['device_type']),
      lastActiveAt: DateTimeHelper.parseTimestamp(json['last_active_at']),
      // 本地数据库 online ，线上获取有 online
      online: parseModelBool(json['online']),
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
