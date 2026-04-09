import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/user_device_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserDeviceRepo {
  static String tableName = 'user_device';

  static String userId = 'user_id'; //
  static String deviceId = 'device_id'; //
  static String deviceName = 'device_name'; //
  static String deviceType = 'device_type'; //
  static String lastActiveAt = 'last_active_at';
  static String deviceVsn = 'device_vsn';

  final SqliteService _db = SqliteService.to;

  Future<List<UserDeviceModel>> page({int limit = 1000, int offset = 0}) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserDeviceRepo.tableName,
      columns: [
        // UserDeviceRepo.userId,
        UserDeviceRepo.deviceId,
        UserDeviceRepo.deviceName,
        UserDeviceRepo.deviceType,
        UserDeviceRepo.lastActiveAt,
        UserDeviceRepo.deviceVsn,
      ],
      where: '${UserDeviceRepo.userId}=?',
      whereArgs: [UserRepoLocal.to.currentUid],
      orderBy: "${UserDeviceRepo.lastActiveAt} desc",
      limit: limit,
      offset: offset,
    );
    if (maps.isEmpty) {
      return [];
    }

    List<UserDeviceModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(UserDeviceModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<UserDeviceModel> insert(
    UserDeviceModel obj, {
    Transaction? txn,
  }) async {
    Map<String, dynamic> insert = {
      UserDeviceRepo.userId: UserRepoLocal.to.currentUid,
      UserDeviceRepo.deviceId: obj.deviceId,
      UserDeviceRepo.deviceName: obj.deviceName,
      UserDeviceRepo.deviceType: obj.deviceType,
      UserDeviceRepo.lastActiveAt: obj.lastActiveAt,
      UserDeviceRepo.deviceVsn: jsonEncode(obj.deviceVsn),
    };
    if (txn != null) {
      await txn.insert(UserDeviceRepo.tableName, insert);
    } else {
      await _db.insert(UserDeviceRepo.tableName, insert);
    }
    return obj;
  }

  // 根据ID删除信息
  Future<int> delete(String did) async {
    return await _db.delete(
      UserDeviceRepo.tableName,
      where: '${UserDeviceRepo.userId} = ? and ${UserDeviceRepo.deviceId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, did],
    );
  }

  // 更新信息
  Future<int> update(
    String did,
    Map<String, dynamic> json, {
    Transaction? txn,
  }) async {
    Map<String, Object?> data = {};
    if (strNoEmpty(json[UserDeviceRepo.deviceVsn])) {
      data[UserDeviceRepo.deviceVsn] = json[UserDeviceRepo.deviceVsn];
    }
    if (strNoEmpty(json[UserDeviceRepo.deviceName])) {
      data[UserDeviceRepo.deviceName] = json[UserDeviceRepo.deviceName];
    }

    int lastActiveAt = json[UserDeviceRepo.lastActiveAt] ?? 0;
    if (lastActiveAt > 0) {
      data[UserDeviceRepo.lastActiveAt] = lastActiveAt;
    }

    if (strNoEmpty(did)) {
      if (txn != null) {
        return await txn.update(
          UserDeviceRepo.tableName,
          data,
          where:
              '${UserDeviceRepo.userId} = ? and ${UserDeviceRepo.deviceId} = ?',
          whereArgs: [UserRepoLocal.to.currentUid, did],
        );
      } else {
        return await _db.update(
          UserDeviceRepo.tableName,
          data,
          where:
              '${UserDeviceRepo.userId} = ? and ${UserDeviceRepo.deviceId} = ?',
          whereArgs: [UserRepoLocal.to.currentUid, did],
        );
      }
    } else {
      return 0;
    }
  }

  Future<UserDeviceModel?> find(String deviceId, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        UserDeviceRepo.tableName,
        columns: [
          // UserDeviceRepo.userId,
          UserDeviceRepo.deviceId,
          UserDeviceRepo.deviceName,
          UserDeviceRepo.deviceType,
          UserDeviceRepo.lastActiveAt,
          UserDeviceRepo.deviceVsn,
        ],
        where: '${UserDeviceRepo.userId}=? and ${UserDeviceRepo.deviceId}=?',
        whereArgs: [UserRepoLocal.to.currentUid, deviceId],
        limit: 1,
      );
    } else {
      maps = await _db.query(
        UserDeviceRepo.tableName,
        columns: [
          // UserDeviceRepo.userId,
          UserDeviceRepo.deviceId,
          UserDeviceRepo.deviceName,
          UserDeviceRepo.deviceType,
          UserDeviceRepo.lastActiveAt,
          UserDeviceRepo.deviceVsn,
        ],
        where: '${UserDeviceRepo.userId}=? and ${UserDeviceRepo.deviceId}=?',
        whereArgs: [UserRepoLocal.to.currentUid, deviceId],
        limit: 1,
      );
    }
    if (maps.isEmpty) {
      return null;
    }
    return UserDeviceModel.fromJson(maps.first);
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
