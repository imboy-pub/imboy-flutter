// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

const contactAssets = 'assets/images/contact/';

const CONST_HELP_URL =
    'https://kf.qq.com/touch/product/wechat_app.html?scene_id=kf338';

String userQrcodeDataSuffix = "s=uqrcode";

const RECORD_LOG = true;

String SENTRY_DSN = dotenv.get('SENTRY_DSN');
// 附件上传认证密钥
String UP_AUTH_KEY = dotenv.get('UP_AUTH_KEY');
// 用于服务端和APP交互数据对称加密的密钥 16 字符 或者32 位字符串， 需要和服务端一致
String SOLIDIFIED_KEY = dotenv.get('SOLIDIFIED_KEY');
// IV 必须都为128比特，也就是16字节，需要和服务端一致
String SOLIDIFIED_KEY_IV = dotenv.get('SOLIDIFIED_KEY_IV');

// 高德地图 key
String AMAP_WEBS_KEY = dotenv.get('AMAP_WEBS_KEY');
String AMAP_IOS_KEY = dotenv.get('AMAP_IOS_KEY');
String AMAP_ANDROID_KEY = dotenv.get('AMAP_ANDROID_KEY');

// 极光推送 APPKEY
String JPUSH_APPKEY = dotenv.get('JPUSH_APPKEY');

String WS_URL = dotenv.get('WS_URL');
String STUN_URL = dotenv.get('STUN_URL');
String TURN_URL = dotenv.get('TURN_URL');
String API_BASE_URL = dotenv.get('API_BASE_URL');
String UPLOAD_BASE_URL = dotenv.get('UPLOAD_BASE_URL');
String UPLOAD_SENCE = dotenv.get('UPLOAD_SENCE');

String IOS_APP_ID = dotenv.get('IOS_APP_ID');

Icon navigateNextIcon = const Icon(
  Icons.navigate_next,
);

class Keys {
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
  static String themeType = 'theme_type';
}

const mainSpace = 10.0;
double mainLineWidth = Get.isDarkMode ? 0.5 : 1.0;

class API {
  static const initConfig = '/init';
  static const refreshToken = '/refreshtoken';
  static const login = '/passport/login';
  static const signup = '/passport/signup';
  static const getCode = '/passport/getcode';
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

  static const userShow = '/user/show';
  static const turnCredential = '/user/credential';
  static const userUpdate = '/user/update';

  static const ftsRecentlyUser = '/fts/recently_user';
  static const ftsUserSearch = '/fts/user_search';

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
