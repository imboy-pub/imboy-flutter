// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

const contactAssets = 'assets/images/contact/';

const constHelpUrl =
    'https://kf.qq.com/touch/product/wechat_app.html?scene_id=kf338';

String qrcodeDataSuffix = "s=app_qrcode";

const recordLog = true;

Icon navigateNextIcon = const Icon(Icons.navigate_next);

class Keys {
  static const String wsUrl = "ws_url";
  static const String apiPublicKey = "api_public_key";
  static const String uploadUrl = "upload_url";
  static const String uploadKey = "upload_key";
  static const String uploadScene = "upload_scene";
  static const String appFeatures = "app_features";

  static const String publicKey = "public_key";
  static const String privateKey = "private_key";

  // 客服端Key
  static const String currentLanguageCode = "current_language_code";
  static const String currentLanguage = "current_language";

  static const String currentUid = "current_uid";
  static const String currentUser = "current_user";
  static const String currentLang = 'user_current_lang';

  static const String account = "account";
  static const String password = "password";
  static const String nickname = 'nickname';
  static const String avatar = 'avatar';
  static const String gender = 'gender';

  // 与服务端约定的Key
  static const tokenKey = 'authorization';
  static const refreshTokenKey = 'imboy-refreshtoken';

  static String lastLoginAccount = 'lastLoginAccount';
  static String loginHistory = 'loginHistory';
  static String loginHistoryAccount = 'loginHistoryAccount';
  static String loginHistoryMobile = 'loginHistoryMobile';
  static String loginHistoryEmail = 'loginHistoryEmail';
  static String themeType = 'theme_type';
  static String needSetPwd = 'need_set_password';
  static const String groupMembershipSelfHealPrefix =
      'group_membership_self_heal';
}

class API {
  static const initConfig = '/v1/init';
  static const refreshToken = '/v1/refreshtoken';
  static const login = '/v1/passport/login';
  static const signup = '/v1/passport/signup';
  static const getCode = '/v1/passport/getcode';
  static const quickLogin = '/v1/passport/quick_login';
  static const findPassword = '/v1/passport/findpassword';
  static const assetsToken = '/v1/auth/assets';
  static const appVersionCheck = '/v1/app_version/check';
  static const appFeatures = '/v1/app/features';
  static const sqliteUpgradeDdl = '/v1/app_ddl/get?type=upgrade';
  static const sqliteDowngradeDdl = '/v1/app_ddl/get?type=downgrade';

  static const addFriend = '/v1/friend/add';
  static const confirmFriend = '/v1/friend/confirm';
  static const deleteFriend = '/v1/friend/delete';
  static const friendList = '/v1/friend/list';
  static const friendChangeRemark = '/v1/friend/change_remark';

  static const conversationList = '/v1/conversation/mine';
  // 拉取离线
  static const msgOffline = '/v1/msg/offline';
  // 确认离线消息已处理
  static const msgOfflineAck = '/v1/msg/offline_ack';

  static const denylistAdd = '/v1/friend/denylist/add';
  static const denylistRemove = '/v1/friend/denylist/remove';
  static const denylistPage = '/v1/friend/denylist/page';

  static const groupFace2face = '/v1/group/face2face';
  static const groupFace2faceSave = '/v1/group/face2face_save';
  static const groupAdd = '/v1/group/add';
  static const groupEdit = '/v1/group/edit';
  static const groupDetail = '/v1/group/detail';
  static const groupDissolve = '/v1/group/dissolve';
  static const groupPage = '/v1/group/page';
  static const groupMsgPage = '/v1/group/msg_page';
  static const groupMemberPage = '/v1/group_member/page';
  static const groupMemberJoin = '/v1/group_member/join';
  static const groupMemberLeave = '/v1/group_member/leave';
  static const groupMemberAlias = '/v1/group_member/alias';
  static const groupMemberSameGroup = '/v1/group_member/same_group';
  static const groupMemberRole = '/v1/group_member/role';
  static const groupMemberMute = '/v1/group_member/mute';
  static const groupTransfer = '/v1/group/transfer';

  static const userShow = '/v1/user/show';
  static const turnCredential = '/v1/user/credential';
  static const userUpdate = '/v1/user/update';
  static const userSetting = '/v1/user/setting';
  static const userChangePassword = '/v1/user/change_password';
  static const userSetPassword = '/v1/user/set_password';
  static const userApplyLogout = '/v1/user/apply_logout';
  static const userCancelLogout = '/v1/user/cancel_logout';
  static const userSearch = '/v1/user/search';

  static const ftsRecentlyUser = '/v1/fts/recently_user';
  static const ftsMessage = '/v1/fts/msg';

  static const userDevicePage = '/v1/user_device/page';
  static const userDeviceChangeName = '/v1/user_device/change_name';
  static const userDeviceDelete = '/v1/user_device/delete';
  static const userDeviceSessions = '/v1/user_device/sessions';
  static const userDeviceCheckLogin = '/v1/user_device/check_login';
  static const userDeviceKick = '/v1/user_device/kick';
  static const userDeviceKickOthers = '/v1/user_device/kick-others';
  static const userDeviceAdd = '/v1/user_device/add';

  static const userCollectPage = '/v1/user_collect/page';
  static const userCollectAdd = '/v1/user_collect/add';
  static const userCollectRemove = '/v1/user_collect/remove';
  static const userCollectChange = '/v1/user_collect/change';

  static const userTagPage = '/v1/user_tag/page';
  static const userTagAdd = '/v1/user_tag/add';
  static const userTagDelete = '/v1/user_tag/delete';
  static const userTagChangeName = '/v1/user_tag/change_name';

  static const userTagRelationFriendPage = '/v1/user_tag_relation/friend_page';
  static const userTagRelationCollectPage =
      '/v1/user_tag_relation/collect_page';
  static const userTagRelationAdd = '/v1/user_tag_relation/add';
  static const userTagRelationSet = '/v1/user_tag_relation/set';
  static const userTagRelationRemove = '/v1/user_tag_relation/remove';

  static const feedbackPage = '/v1/feedback/page';
  static const feedbackAdd = '/v1/feedback/add';
  static const feedbackRemove = '/v1/feedback/remove';
  static const feedbackChange = '/v1/feedback/change';
  static const feedbackPageReply = '/v1/feedback/page_reply';
  static const feedbackReply = '/v1/feedback/reply';

  // 附近的人
  static const peopleNearby = '/v1/location/peopleNearby';
  static const makeMyselfVisible = '/v1/location/makeMyselfVisible';
  static const makeMyselfUnVisible = '/v1/location/makeMyselfUnvisible';

  static const avatarUrl = 'http://www.lorempixel.com/200/200/';
  static const cat = 'https://api.thecatapi.com/v1/images/search';
  static const upImg = "http://111.230.251.115/oldchen/fUser/oneDaySuggestion";
  static const update = 'http://www.flutterj.com/api/update.json';
  static const uploadImg = 'http://www.flutterj.com/upload/avatar';
}
