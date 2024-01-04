import 'package:flutter/cupertino.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';
import 'package:sqflite/sqflite.dart';

import 'contact_repo_sqlite.dart';
import 'conversation_repo_sqlite.dart';
import 'message_repo_sqlite.dart';
import 'new_friend_repo_sqlite.dart';
import 'user_collect_repo_sqlite.dart';
import 'user_denylist_repo_sqlite.dart';
import 'user_device_repo_sqlite.dart';

class SqliteDdl {
  /// 联系人
  ///
  static contact(Database db) async {
    String contactSql = '''
      CREATE TABLE IF NOT EXISTS ${ContactRepo.tableName} (
        auto_id INTEGER,
        ${ContactRepo.userId} varchar(40) NOT NULL,
        ${ContactRepo.peerId} varchar(40) NOT NULL,
        ${ContactRepo.nickname} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.avatar} varchar(255) NOT NULL DEFAULT '',
        ${ContactRepo.gender} int(4) NOT NULL DEFAULT 0,
        ${ContactRepo.account} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.status} varchar(20) NOT NULL DEFAULT '',
        ${ContactRepo.remark} varchar(255) DEFAULT '',
        ${ContactRepo.tag} varchar(1600) DEFAULT '',
        ${ContactRepo.region} varchar(80) DEFAULT '',
        ${ContactRepo.sign} varchar(255) NOT NULL DEFAULT '',
        ${ContactRepo.source} varchar(40) NOT NULL DEFAULT '',
        ${ContactRepo.updateAt} int(16) NOT NULL DEFAULT 0,
        ${ContactRepo.isFriend} int(4) NOT NULL DEFAULT 0,
        ${ContactRepo.isFrom} int(4) NOT NULL DEFAULT 0,
        ${ContactRepo.categoryId} int(20) NOT NULL DEFAULT 0,
        PRIMARY KEY("auto_id"),
        CONSTRAINT uk_FromTo UNIQUE (
            ${ContactRepo.userId},
            ${ContactRepo.peerId}
        )
        );
      ''';
    debugPrint("> on _onCreate \n$contactSql\n");
    await db.execute(contactSql);
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_UserId_IsFriend_UpdateTime
          ON ${ContactRepo.tableName} 
          (${ContactRepo.userId}, ${ContactRepo.isFriend}, ${ContactRepo.updateAt});
        ''');
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_UserId_CategoryId
          ON ${ContactRepo.tableName} 
          (${ContactRepo.userId}, ${ContactRepo.categoryId});
        ''');

    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_Nickname
          ON ${ContactRepo.tableName} 
          (${ContactRepo.nickname});
        ''');
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_Remark
          ON ${ContactRepo.tableName} 
          (${ContactRepo.remark});
        ''');
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_Tag
          ON ${ContactRepo.tableName} 
          (${ContactRepo.tag});
        ''');
  }

  /// 会话
  static conversation(Database db) async {
    String conversationSql = '''
      CREATE TABLE IF NOT EXISTS ${ConversationRepo.tableName} (
        `${ConversationRepo.id}` INTEGER,
        `${ConversationRepo.userId}` varchar(40) NOT NULL,
        `${ConversationRepo.peerId}` varchar(40) NOT NULL,
        `${ConversationRepo.avatar}` varchar(255) NOT NULL DEFAULT '',
        `${ConversationRepo.title}` varchar(40) NOT NULL DEFAULT '',
        `${ConversationRepo.subtitle}` varchar(255) DEFAULT '',
        `${ConversationRepo.region}` varchar(255) DEFAULT '',
        `${ConversationRepo.sign}` varchar(255) DEFAULT '',
        `${ConversationRepo.unreadNum}` int NOT NULL DEFAULT 0,
        `${ConversationRepo.type}` varchar(40) NOT NULL,
        `${ConversationRepo.msgType}` varchar(40) NOT NULL,
        `${ConversationRepo.isShow}` int NOT NULL DEFAULT 0,
        `${ConversationRepo.lastTime}` int DEFAULT 0,
        `${ConversationRepo.lastMsgId}` varchar(40) NOT NULL,
        `${ConversationRepo.lastMsgStatus}` int DEFAULT 0,
        `${ConversationRepo.payload}` TEXT,
        PRIMARY KEY(${ConversationRepo.id}),
        CONSTRAINT uk_FromTo UNIQUE (
            ${ConversationRepo.userId},
            ${ConversationRepo.peerId}
        )
        );
      ''';
    // debugPrint("> on _onCreate \n$conversationSql\n");
    await db.execute(conversationSql);
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_UserId_IsShow_LastTime
          ON ${ConversationRepo.tableName} 
          (${ConversationRepo.userId},${ConversationRepo.isShow}, ${ConversationRepo.lastTime});
        ''');
  }

  /// 消息
  static message(Database db) async {
    String messageSql = '''
      CREATE TABLE IF NOT EXISTS ${MessageRepo.tableName} (
        auto_id INTEGER,
        ${MessageRepo.id} varchar(40) NOT NULL,
        ${MessageRepo.type} VARCHAR (20),
        ${MessageRepo.from} VARCHAR (80),
        ${MessageRepo.to} VARCHAR (80),
        ${MessageRepo.payload} TEXT,
        ${MessageRepo.createdAt} INTERGER,
        ${MessageRepo.serverTs} INTERGER,
        ${MessageRepo.conversationId} int DEFAULT 0,
        ${MessageRepo.status} INTERGER,
        PRIMARY KEY(auto_id),
        CONSTRAINT uk_MsgId UNIQUE (
            ${MessageRepo.id}
        )
        );
      ''';
    debugPrint("> on _onCreate messageSql \n$messageSql\n");
    await db.execute(messageSql);
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_ConversationId_CreatedAt 
          ON ${MessageRepo.tableName} 
          (${MessageRepo.conversationId}, ${MessageRepo.createdAt});
        ''');
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_FromUid 
          ON ${MessageRepo.tableName} 
          (${MessageRepo.from});
        ''');
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_ToUid 
          ON ${MessageRepo.tableName} 
          (${MessageRepo.to});
        ''');
  }

  /// 新朋友
  static newFriend(Database db) async {
    String newFriendSql = '''
      CREATE TABLE IF NOT EXISTS ${NewFriendRepo.tableName} (
        auto_id INTEGER,
        ${NewFriendRepo.uid} varchar(40) NOT NULL,
        ${NewFriendRepo.from} varchar(40) NOT NULL,
        ${NewFriendRepo.to} varchar(40) NOT NULL,
        ${NewFriendRepo.nickname} varchar(40) NOT NULL DEFAULT '',
        ${NewFriendRepo.avatar} varchar(255) NOT NULL DEFAULT '',
        ${NewFriendRepo.msg} varchar(255) NOT NULL DEFAULT '',
        ${NewFriendRepo.status} varchar(20) NOT NULL DEFAULT '',
        ${NewFriendRepo.payload} text DEFAULT '',
        ${NewFriendRepo.updateAt} int(16) NOT NULL DEFAULT 0,
        ${NewFriendRepo.createAt} int(16) NOT NULL DEFAULT 0,
        PRIMARY KEY("auto_id"),
        CONSTRAINT uk_FromTo UNIQUE (
            ${NewFriendRepo.from},
            ${NewFriendRepo.to}
        )
        );
      ''';
    debugPrint("> on _onCreate \n$newFriendSql\n");
    await db.execute(newFriendSql);
  }

  /// 用户禁用名单 DDL
  static userDenylist(Database db) async {
    String denylistSql = '''
      CREATE TABLE IF NOT EXISTS ${UserDenylistRepo.tableName} (
        auto_id INTEGER,
        ${UserDenylistRepo.uid} varchar(40) NOT NULL,
        ${UserDenylistRepo.deniedUid} varchar(40) NOT NULL,
        ${UserDenylistRepo.nickname} varchar(40) NOT NULL DEFAULT '',
        ${UserDenylistRepo.avatar} varchar(255) NOT NULL DEFAULT '',
        ${UserDenylistRepo.gender} int(4) NOT NULL DEFAULT 0,
        ${UserDenylistRepo.account} varchar(40) NOT NULL DEFAULT '',
        ${UserDenylistRepo.region} varchar(80) DEFAULT '',
        ${UserDenylistRepo.sign} varchar(255) NOT NULL DEFAULT '',
        ${UserDenylistRepo.source} varchar(40) NOT NULL DEFAULT '',
        ${UserDenylistRepo.remark} varchar(255) DEFAULT '',
        ${UserDenylistRepo.createdAt} int(16) NOT NULL DEFAULT 0,
        PRIMARY KEY("auto_id"),
        CONSTRAINT i_Uid_DeniedUid UNIQUE (
            ${UserDenylistRepo.uid},
            ${UserDenylistRepo.deniedUid}
        )
        );
      ''';
    debugPrint("> on _onCreate \n$denylistSql\n");
    await db.execute(denylistSql);
  }

  /// 用户设备 DDL 语句
  static userDevice(Database db) async {
    String userDeviceSql = '''
      CREATE TABLE IF NOT EXISTS ${UserDeviceRepo.tableName} (
        auto_id INTEGER,
        ${UserDeviceRepo.userId} varchar(40) NOT NULL,
        ${UserDeviceRepo.deviceId} varchar(80) NOT NULL DEFAULT '',
        ${UserDeviceRepo.deviceName} varchar(255) NOT NULL DEFAULT '',
        ${UserDeviceRepo.deviceType} varchar(40) NOT NULL DEFAULT '',
        ${UserDeviceRepo.lastActiveAt} int(16) NOT NULL DEFAULT 0,
        ${UserDeviceRepo.deviceVsn} varchar(255) DEFAULT '',
        PRIMARY KEY("auto_id"),
        CONSTRAINT i_Uid_DeviceId UNIQUE (
            ${UserDeviceRepo.userId},
            ${UserDeviceRepo.deviceId}
        )
        );
      ''';
    debugPrint("> on _onCreate \n$userDeviceSql\n");
    await db.execute(userDeviceSql);
  }

  /// 用户收藏 DDL 语句
  static userCollect(Database db) async {
    String userCollectSql = '''
      CREATE TABLE IF NOT EXISTS ${UserCollectRepo.tableName} (
        auto_id INTEGER,
        ${UserCollectRepo.userId} varchar(40) NOT NULL,
        ${UserCollectRepo.kind} int(16) NOT NULL DEFAULT '',
        ${UserCollectRepo.kindId} varchar(40) NOT NULL DEFAULT '',
        ${UserCollectRepo.source} varchar(255) NOT NULL DEFAULT '',
        ${UserCollectRepo.remark} varchar(255) NOT NULL DEFAULT '',
        ${UserCollectRepo.tag} varchar(1600) NOT NULL DEFAULT '',
        ${UserCollectRepo.updatedAt} int(16) NOT NULL DEFAULT 0,
        ${UserCollectRepo.createdAt} int(16) NOT NULL DEFAULT 0,
        ${UserCollectRepo.info} text DEFAULT '',
        PRIMARY KEY("auto_id"),
        CONSTRAINT i_Uid_KindId UNIQUE (
            ${UserCollectRepo.userId},
            ${UserCollectRepo.kindId}
        )
        );
      ''';
    debugPrint("> on _onCreate \n$userCollectSql\n");
    await db.execute(userCollectSql);
    //
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_Source
          ON ${UserCollectRepo.tableName} 
          (${UserCollectRepo.source});
        ''');
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_Remark
          ON ${UserCollectRepo.tableName} 
          (${UserCollectRepo.remark});
        ''');
    await db.execute('''
          CREATE INDEX IF NOT EXISTS i_Tag
          ON ${UserCollectRepo.tableName} 
          (${UserCollectRepo.tag});
        ''');
  }

  /// 用户标签 DDL 语句
  static userTag(Database db) async {
    String userTagSql = '''
      CREATE TABLE IF NOT EXISTS ${UserTagRepo.tableName} (
        auto_id INTEGER,
        ${UserTagRepo.userId} varchar(40) NOT NULL,
        ${UserTagRepo.tagId} int(16) NOT NULL DEFAULT '',
        ${UserTagRepo.scene} int(8) NOT NULL DEFAULT '',
        ${UserTagRepo.name} varchar(255) NOT NULL DEFAULT '',
        ${UserTagRepo.subtitle} varchar(800) NOT NULL DEFAULT '',
        ${UserTagRepo.refererTime} int(16) NOT NULL DEFAULT 0,
        ${UserTagRepo.updatedAt} int(16) NOT NULL DEFAULT 0,
        ${UserTagRepo.createdAt} int(16) NOT NULL DEFAULT 0,
        PRIMARY KEY("auto_id"),
        CONSTRAINT i_Uid_Scene_Name UNIQUE (
            ${UserTagRepo.userId},
            ${UserTagRepo.scene},
            ${UserTagRepo.name}
        )
        );
      ''';
    debugPrint("> on _onCreate \n$userTagSql\n");
    await db.execute(userTagSql);

    // String userTagRelationSql = '''
    //   CREATE TABLE IF NOT EXISTS ${UserTagRelationRepo.tableName} (
    //     auto_id INTEGER,
    //     ${UserTagRelationRepo.userId} varchar(40) NOT NULL,
    //     ${UserTagRelationRepo.tagId} int(16) NOT NULL DEFAULT '',
    //     ${UserTagRelationRepo.scene} int(8) NOT NULL DEFAULT '',
    //     ${UserTagRelationRepo.objectId} varchar(40) NOT NULL DEFAULT '',
    //     ${UserTagRelationRepo.createdAt} int(16) NOT NULL DEFAULT 0,
    //     PRIMARY KEY("auto_id"),
    //     CONSTRAINT uk_user_tag_Scene_UserId_ObjectId_TagId UNIQUE (
    //         ${UserTagRelationRepo.scene},
    //         ${UserTagRelationRepo.userId},
    //         ${UserTagRelationRepo.objectId},
    //         ${UserTagRelationRepo.tagId}
    //     )
    //     );
    //   ''';
    // debugPrint("> on _onCreate \n$userTagRelationSql\n");
    // await db.execute(userTagRelationSql);
  }

  static Future onCreate(Database db, int version) async {
    await SqliteDdl.contact(db);
    await SqliteDdl.conversation(db);
    await SqliteDdl.message(db);
    await SqliteDdl.newFriend(db);
    await SqliteDdl.userDenylist(db);
    await SqliteDdl.userDevice(db);
    await SqliteDdl.userCollect(db);
    await SqliteDdl.userTag(db);
  }

  static Future onUpgrade(Database db, int oldVsn, int newVsn) async {
    final List<String> ddl = await vsnProvider.sqliteUpgradeDdl(
      oldVsn,
      newVsn,
    );
    if (ddl.isEmpty) {
      return;
    }

    for (var ddl1 in ddl) {
      if (ddl1.isNotEmpty) await db.execute(ddl1);
    }
  }

  static Future onDowngrade(Database db, int oldVsn, int newVsn) async {
    final List<String> ddl = await vsnProvider.sqliteDowngradeDdl(
      oldVsn,
      newVsn,
    );
    if (ddl.isEmpty) {
      return;
    }

    for (var ddl1 in ddl) {
      if (ddl1.isNotEmpty) await db.execute(ddl1);
    }
  }
}
