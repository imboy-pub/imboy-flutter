import 'package:flutter/material.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UserTagRelationRepo {
  static String tableName = 'user_tag_relation';

  static String userId = 'user_id'; // creator_user_id 创建人用户ID
  static String tagId = 'tag_id'; // 标签ID
  static String scene = 'scene'; // 标签应用场景 1  用户收藏记录标签  2 用户朋友标签
  static String objectId = 'object_id'; // 打标签对象ID
  static String createdAt = 'created_at';

  final SqliteService _db = SqliteService.to;

  // 插入一条数据
  Future<int> insert(Map<String, dynamic> data) async {
    Map<String, dynamic> insert = {
      UserTagRelationRepo.userId: UserRepoLocal.to.currentUid,
      UserTagRelationRepo.tagId: data[UserTagRelationRepo.tagId],
      UserTagRelationRepo.scene: data[UserTagRelationRepo.scene],
      UserTagRelationRepo.objectId: data[UserTagRelationRepo.objectId],
      UserTagRelationRepo.createdAt: data[UserTagRelationRepo.createdAt],
    };
    debugPrint("> on UserTagRelationRepo/insert/1 $insert");

    await _db.insert(UserTagRelationRepo.tableName, insert);
    return 1;
  }

  // 根据ID删除信息
  Future<int> delete(int scene, String objectId, int tagId) async {
    // uk_user_tag_Scene_UserId_ObjectId_TagId
    return await _db.delete(
      UserTagRelationRepo.tableName,
      where: '${UserTagRelationRepo.userId} = ? and ${UserTagRelationRepo.tagId} = ?',
      whereArgs: [UserRepoLocal.to.currentUid, tagId],
    );
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
