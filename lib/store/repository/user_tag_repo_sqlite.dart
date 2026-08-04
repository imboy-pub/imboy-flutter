import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserTagRepo {
  static String tableName = 'user_tag';

  static String userId = 'user_id'; // creator_user_id 创建人用户ID
  static String tagId = 'tag_id'; // 标签ID
  static String scene = 'scene'; // 标签应用场景 1  用户收藏记录标签  2 用户朋友标签
  static String name = 'name'; // 标签名称
  static String subtitle = 'subtitle'; //  例如 "leeyi108古古惑惑还, 15000049665"
  static String refererTime = 'referer_time'; // 被引用次数 关联object_id 数量
  static String updatedAt = 'updated_at';
  static String createdAt = 'created_at';

  // 公共列名列表
  static final List<String> defaultColumns = [
    UserTagRepo.userId,
    UserTagRepo.tagId,
    UserTagRepo.scene,
    UserTagRepo.name,
    UserTagRepo.subtitle,
    UserTagRepo.refererTime,
    UserTagRepo.updatedAt,
    UserTagRepo.createdAt,
  ];

  final SqliteService _db = SqliteService.to;

  Future<List<UserTagModel>> page({
    int limit = 1000,
    int offset = 0,
    String where = "",
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    List<Map<String, dynamic>> maps = await _db.query(
      UserTagRepo.tableName,
      columns: defaultColumns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    if (maps.isEmpty) {
      return [];
    }

    List<UserTagModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(UserTagModel.fromJson(maps[i]));
    }
    return items;
  }

  // 插入一条数据
  Future<UserTagModel> insert(UserTagModel obj, {Transaction? txn}) async {
    Map<String, dynamic> insert = {
      UserTagRepo.userId: UserRepoLocal.to.currentUid,
      UserTagRepo.tagId: obj.tagId,
      UserTagRepo.scene: obj.scene,
      UserTagRepo.name: obj.name,
      UserTagRepo.subtitle: obj.subtitle,
      UserTagRepo.refererTime: obj.refererTime,
      UserTagRepo.updatedAt: obj.updatedAt,
      UserTagRepo.createdAt: obj.createdAt,
    };
    if (txn != null) {
      await txn.insert(UserTagRepo.tableName, insert);
    } else {
      await _db.insert(UserTagRepo.tableName, insert);
    }
    return obj;
  }

  // 根据ID删除信息
  Future<int> delete(int tagId) async {
    return await _db.delete(
      UserTagRepo.tableName,
      where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, tagId],
    );
  }

  /// 从入参挑出本次真正要写的列。
  ///
  /// 抽成纯函数是为了能直接测这几个守卫 —— 它们出过两个隐蔽 bug：
  /// 1. `strNoEmpty("${json[name]}")`：name 缺失时 null 被插值成字面量 "null"，
  ///    守卫判真 → 标签名被写成 "null"。而 setObject（增删成员）从不传 name，
  ///    于是每次改成员都毁掉标签名；列表优先读内存，重启后才显形，极难察觉。
  /// 2. `refererTime > 0`：成员被全部移除时 length 恰好是 0，这次合法更新被吞掉，
  ///    计数停在旧值。改为按「是否传了该键」判断。
  @visibleForTesting
  static Map<String, Object?> buildUpdateData(Map<String, dynamic> json) {
    final Map<String, Object?> data = {};

    final Object? name = json[UserTagRepo.name];
    if (name != null && strNoEmpty(name.toString())) {
      data[UserTagRepo.name] = name.toString();
    }

    final String? subtitle = json[UserTagRepo.subtitle] as String?;
    if (subtitle != null) {
      data[UserTagRepo.subtitle] = subtitle;
    }

    if (json.containsKey(UserTagRepo.refererTime)) {
      data[UserTagRepo.refererTime] =
          json[UserTagRepo.refererTime] as int? ?? 0;
    }

    final int updatedAt = json[UserTagRepo.updatedAt] as int? ?? 0;
    if (updatedAt > 0) {
      data[UserTagRepo.updatedAt] = updatedAt;
    }
    return data;
  }

  // 更新信息
  Future<int> update(Map<String, dynamic> json, {Transaction? txn}) async {
    Map<String, Object?> data = buildUpdateData(json);
    int tagId = json[UserTagRepo.tagId] as int? ?? (json['id'] as int? ?? 0);
    if (tagId > 0) {
      if (txn != null) {
        return await txn.update(
          UserTagRepo.tableName,
          data,
          where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
          whereArgs: [UserRepoLocal.to.currentUid, tagId],
        );
      } else {
        return await _db.update(
          UserTagRepo.tableName,
          data,
          where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
          whereArgs: [UserRepoLocal.to.currentUid, tagId],
        );
      }
    } else {
      return 0;
    }
  }

  Future<UserTagModel> save(Map<String, dynamic> json) async {
    int tagId = json[UserTagRepo.tagId] as int? ?? (json['id'] as int? ?? 0);
    return await _db.transaction<UserTagModel>((txn) async {
      UserTagModel? old = await findByTagId(tagId, txn: txn);
      iPrint("UserTagRepo_save $tagId, ${old?.toMap().toString()};");
      if (old == null) {
        UserTagModel model = UserTagModel.fromJson(json);
        await insert(model, txn: txn);
        return model;
      } else {
        await update(json, txn: txn);
        return (await findByTagId(tagId, txn: txn))!;
      }
    });
  }

  Future<UserTagModel?> findByTagId(int tagId, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        UserTagRepo.tableName,
        columns: [],
        where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, tagId],
      );
    } else {
      maps = await _db.query(
        UserTagRepo.tableName,
        columns: [],
        where: '${UserTagRepo.userId} = ? and ${UserTagRepo.tagId} = ?',
        whereArgs: [UserRepoLocal.to.currentUid, tagId],
      );
    }
    if (maps.isNotEmpty) {
      return UserTagModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
