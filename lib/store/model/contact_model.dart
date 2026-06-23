import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';

/// 联系人数据模型
/// 纯数据模型，不包含响应式状态
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

String getSourceTr(String? source) {
  if (source == null) {
    return '';
  }
  String sourceTr = "";
  // 通过QQ好友添加
  // 通过群聊添加
  switch (source.toLowerCase()) {
    case 'visitcard':
      sourceTr = t.common.personalCard;
      break;
    case 'qrcode':
      sourceTr = t.account.sourceQrcode;
      break;
    case 'people_nearby':
      sourceTr = t.discovery.peopleNearby;
      break;
    case 'recently_user':
      sourceTr = t.account.newlyRegisteredPeople;
      break;
    case 'user_search':
      sourceTr = t.common.search;
      break;
    default:
      sourceTr = source.toString();
      break;
  }
  return sourceTr;
}

class ContactModel extends ISuspensionBean {
  ContactModel({
    required this.peerId,
    required this.nickname,
    this.account = "",
    this.avatar = "",
    this.gender = 0,
    this.status,
    this.lastSeenAt,
    this.remark = "",
    this.tag = "",
    this.region = "",
    this.sign = "",
    this.source = "",
    this.updatedAt = 0,
    this.isFriend = 1,
    // isFrom 好友关系发起人
    this.isFrom = 0,
    this.categoryId = 0,
    //
    this.nameIndex = "",
    this.namePinyin,
    this.firstLetter,
    this.onPressed,
    this.onLongPressed,
  });

  final int peerId; // 联系人用户ID
  final String account; // 联系人用户账号
  final String nickname; // 联系人用户 备注 or 昵称
  final String avatar; // 用户头像
  int gender; // 1 男  2 女  3 保密  0 未知
  final String? status; // offline | online |
  final int? lastSeenAt; // 最后在线时间戳
  final String remark;

  // 朋友标签，半角逗号分割，单个表情不超过14字符
  String tag;
  final String region;
  final String sign;

  // source 可能的值
  // visitCard | qrcode | people_nearby | user_search
  // recently_user
  final String source;
  final int updatedAt;
  int isFriend;

  // isFrom 好友关系发起人
  int isFrom;
  int categoryId;

  String nameIndex;
  String? namePinyin;
  String? firstLetter;

  bool selected = false;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  /// 是否为联系人菜单入口（朋友圈/附近的人/新的朋友/群聊/标签）。
  ///
  /// 菜单入口使用负值 `peerId` sentinel（见 contact_provider.dart 的
  /// `kPeerId*` 常量），真实联系人 `peerId > 0`。纯数据谓词，不含 UI 关注点。
  bool get isMenuEntry => peerId < 0;

  /// 联系人来源描述
  String get sourceTr {
    return getSourceTr(source);
  }

  /// 联系人title显示规则： remark > nickname > account
  String get title {
    if (strNoEmpty(remark)) {
      return remark;
    } else if (strNoEmpty(nickname)) {
      return nickname;
    } else {
      return account;
    }
  }

  factory ContactModel.fromMap(Map<String, dynamic> json) {
    final isFrom = parseModelInt(json[ContactRepo.isFrom]);
    String tag = parseModelString(json[ContactRepo.tag]);
    tag = tag.replaceAll(',,', ',');
    tag = tag.endsWith(',') ? tag.substring(0, tag.length - 1) : tag;

    final peerId = parseModelInt(json['id'] ?? json[ContactRepo.peerId]);
    if (peerId == 0) {
      throw Exception('ContactModel peerId is empty');
    }

    final rawLastSeenAt = json['last_seen_at'];
    int? lastSeenAt;
    if (rawLastSeenAt != null && rawLastSeenAt.toString().isNotEmpty) {
      if (rawLastSeenAt is num) {
        lastSeenAt = rawLastSeenAt.toInt();
      } else {
        lastSeenAt = int.tryParse(rawLastSeenAt.toString());
      }
    }

    // updated_at 缺失时回退到 created_at：对齐后端 /api/v1/friend/list SELECT
    // 仅返回 f.created_at（imboy/src/ds/friend_ds.erl:315），避免 UI 侧显示
    // "刚刚" 之类的虚假时间戳。两者都缺才回退到 DateTime.now()。
    final updateAt = parseModelDateTime(
      json[ContactRepo.updatedAt] ?? json['created_at'],
    ).millisecondsSinceEpoch;
    return ContactModel(
      peerId: peerId,
      account: parseModelString(json['account']),
      nickname: parseModelString(json['nickname']),
      avatar: parseModelString(json['avatar']),
      gender: parseModelInt(json['gender']),
      status: parseModelString(json['status']),
      lastSeenAt: lastSeenAt,
      remark: parseModelString(json['remark']),
      tag: tag,
      region: parseModelString(json['region']),
      source: parseModelString(json['source']),
      sign: parseModelString(json['sign']),
      // 单位毫秒，13位时间戳  1561021145560
      updatedAt: updateAt,
      isFriend: parseModelInt(json[ContactRepo.isFriend]),
      categoryId: parseModelInt(json[ContactRepo.categoryId]),
      isFrom: isFrom,
    );
  }

  Map<String, dynamic> toJson() => {
    ContactRepo.peerId: peerId,
    'account': account,
    'nickname': nickname,
    'avatar': avatar,
    'gender': gender,
    'status': status,
    'last_seen_at': lastSeenAt,
    'remark': remark,
    'region': region,
    'sign': sign,
    'source': source,
    ContactRepo.tag: tag,
    ContactRepo.updatedAt: updatedAt,
    ContactRepo.isFriend: isFriend,
    ContactRepo.isFrom: isFrom,
    ContactRepo.categoryId: categoryId,
    //
    'firstLetter': firstLetter,
    'nameIndex': nameIndex,
    'namePinyin': namePinyin,
  };

  @override
  String getSuspensionTag() => nameIndex;

  @override
  String toString() => 'ContactModel(peerId: $peerId)';
}
