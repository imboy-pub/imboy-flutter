// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

const contactAssets = 'assets/images/contact/';

const CONST_HELP_URL =
    'https://kf.qq.com/touch/product/wechat_app.html?scene_id=kf338';

String qrcodeDataSuffix = "s=app_qrcode";

const RECORD_LOG = true;

Icon navigateNextIcon = const Icon(
  Icons.navigate_next,
);

class Keys {

  static const String wsUrl = "ws_url";
  static const String apiPublicKey = "api_public_key";
  static const String uploadUrl = "upload_url";
  static const String uploadKey = "upload_key";
  static const String uploadScene = "upload_scene";

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
  static String themeType = 'theme_type';
  static String needSetPwd = 'need_set_password';
}


class API {
  static const initConfig = '/init';
  static const refreshToken = '/refreshtoken';
  static const login = '/passport/login';
  static const signup = '/passport/signup';
  static const getCode = '/passport/getcode';
  static const quickLogin = '/passport/quick_login';
  static const findPassword = '/passport/findpassword';
  static const assetsToken = '/auth/get_token';
  static const appVersionCheck = '/app_version/check';
  static const sqliteUpgradeDdl = '/app_ddl/get?type=upgrade';
  static const sqliteDowngradeDdl = '/app_ddl/get?type=downgrade';

  static const addFriend = '/friend/add';
  static const confirmFriend = '/friend/confirm';
  static const deleteFriend = '/friend/delete';
  static const friendList = '/friend/list';
  static const friendChangeRemark = '/friend/change_remark';

  static const conversationList = '/conversation/mine';

  static const denylistAdd = '/friend/denylist/add';
  static const denylistRemove = '/friend/denylist/remove';
  static const denylistPage = '/friend/denylist/page';

  static const groupFace2face = '/group/face2face';
  static const groupFace2faceSave = '/group/face2face_save';
  static const groupAdd = '/group/add';
  static const groupEdit = '/group/edit';
  static const groupDetail = '/group/detail';
  static const groupDissolve = '/group/dissolve';
  static const groupPage = '/group/page';
  static const groupMsgPage = '/group/msg_page';
  static const groupMemberPage = '/group_member/page';
  static const groupMemberJoin = '/group_member/join';
  static const groupMemberLeave = '/group_member/leave';
  static const groupMemberSameGroup = '/group_member/same_group';


  static const userShow = '/user/show';
  static const turnCredential = '/user/credential';
  static const userUpdate = '/user/update';
  static const userChangePassword = '/user/change_password';
  static const userSetPassword = '/user/set_password';
  static const userApplyLogout = '/user/apply_logout';
  static const userCancelLogout = '/user/cancel_logout';
  static const userSearch = '/user/search';

  static const ftsRecentlyUser = '/fts/recently_user';

  static const userDevicePage = '/user_device/page';
  static const userDeviceChangeName = '/user_device/change_name';
  static const userDeviceDelete = '/user_device/delete';
  static const userDeviceAdd = '/user_device/add';

  static const userCollectPage = '/user_collect/page';
  static const userCollectAdd = '/user_collect/add';
  static const userCollectRemove = '/user_collect/remove';
  static const userCollectChange = '/user_collect/change';

  static const userTagPage = '/user_tag/page';
  static const userTagAdd = '/user_tag/add';
  static const userTagDelete = '/user_tag/delete';
  static const userTagChangeName = '/user_tag/change_name';

  static const userTagRelationFriendPage = '/user_tag_relation/friend_page';
  static const userTagRelationCollectPage = '/user_tag_relation/collect_page';
  static const userTagRelationAdd = '/user_tag_relation/add';
  static const userTagRelationSet = '/user_tag_relation/set';
  static const userTagRelationRemove = '/user_tag_relation/remove';

  static const feedbackPage = '/feedback/page';
  static const feedbackAdd = '/feedback/add';
  static const feedbackRemove = '/feedback/remove';
  static const feedbackChange = '/feedback/change';
  static const feedbackPageReply = '/feedback/page_reply';
  static const feedbackReply = '/feedback/reply';

  // 附近的人
  static const peopleNearby = '/location/peopleNearby';
  static const makeMyselfVisible = '/location/makeMyselfVisible';
  static const makeMyselfUnVisible = '/location/makeMyselfUnvisible';

  static const avatarUrl = 'http://www.lorempixel.com/200/200/';
  static const cat = 'https://api.thecatapi.com/v1/images/search';
  static const upImg = "http://111.230.251.115/oldchen/fUser/oneDaySuggestion";
  static const update = 'http://www.flutterj.com/api/update.json';
  static const uploadImg = 'http://www.flutterj.com/upload/avatar';
}
