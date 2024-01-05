// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

class Keys {
  // 客服端Key
  static const String currentLanguageCode = "current_language_code";
  static const String currentLanguage = "current_language";

  static const String currentUid = "current_uid";
  static const String currentUser = "current_user";

  static const String account = "account";
  static const String password = "password";
  static const String nickname = 'nickname';
  static const String avatar = 'avatar';
  static const String gender = 'gender';

  // 与服务端约定的Key
  static const tokenKey = 'authorization';
  static const refreshTokenKey = 'imboy-refreshtoken';

  static String lastLoginAccount = 'lastLoginAccount';
}

class AppColors {
  static const AppBarColor = Color.fromRGBO(237, 237, 237, 1);

  static const BgColor = Color.fromRGBO(255, 255, 255, 1);

  static const LineColor = Colors.grey;

  static const TipColor = Color.fromRGBO(89, 96, 115, 1.0);

  static const MainTextColor = Color.fromRGBO(115, 115, 115, 1.0);

  static const LabelTextColor = Color.fromRGBO(144, 144, 144, 1.0);

  static const ItemBgColor = Color.fromRGBO(75, 75, 75, 1.0);

  static const ItemOnColor = Color.fromRGBO(68, 68, 68, 1.0);

  static const ButtonTextColor = Color.fromRGBO(112, 113, 135, 1.0);

  ///

  /// 主背景 白色
  static const Color primaryBackground = Color.fromARGB(255, 255, 255, 255);

  /// 主文本 灰色
  static const Color primaryText = Color.fromARGB(255, 45, 45, 47);

  /// 主控件-背景 绿色
  static const Color primaryElement = Color.fromARGB(255, 109, 192, 102);

  /// 主控件-文本 白色
  static const Color primaryElementText = Color.fromARGB(255, 255, 255, 255);

  // *****************************************

  /// 第二种控件-背景色 淡灰色
  static const Color secondaryElement = Color.fromARGB(255, 246, 246, 246);

  /// 第二种控件-文本 浅绿色
  static const Color secondaryElementText = Color.fromRGBO(169, 234, 122, 1.0);

  // *****************************************

  /// 第三种控件-背景色 石墨色
  static const Color thirdElement = Color.fromARGB(255, 45, 45, 47);

  /// 第三种控件-文本 浅灰色2
  static const Color thirdElementText = Color.fromARGB(255, 141, 141, 142);

  // *****************************************

  /// tabBar 默认颜色 灰色
  static const Color tabBarElement = Color.fromARGB(255, 208, 208, 208);

  /// tabCellSeparator 单元格底部分隔条 颜色
  static const Color tabCellSeparator = Color.fromARGB(255, 230, 230, 231);

  // for chat
  static const ChatBg = Color.fromRGBO(243, 243, 243, 1.0);
  static const ChatSendMessageBgColor = Color.fromRGBO(169, 234, 122, 1.0);
  static const ChatSentMessageBodyTextColor = Color.fromRGBO(19, 29, 13, 1.0);

  static const ChatReceivedMessageBodyTextColor =
      Color.fromRGBO(25, 25, 25, 1.0);

  static const ChatReceivedMessageBodyBgColor =
      Color.fromRGBO(255, 255, 255, 1.0);

  static const ChatInputBackgroundColor = Color.fromRGBO(240, 240, 240, 1.0);
  static const ChatInputFillGgColor = Color.fromRGBO(251, 251, 251, 1.0);
// end for chat
}

const mainSpace = 10.0;
const mainLineWidth = 0.3;

class Constants {
  static const IconFontFamily = "appIconFont";
  static const ActionIconSize = 20.0;
  static const ActionIconSizeLarge = 32.0;
  static const AvatarRadius = 4.0;
  static const ConversationAvatarSize = 48.0;
  static const DividerWidth = 0.2;
  static const ConversationMuteIconSize = 18.0;
  static const ContactAvatarSize = 42.0;
  static const TitleTextSize = 16.0;
  static const ContentTextSize = 20.0;
  static const DesTextSize = 13.0;
  static const IndexBarWidth = 24.0;
  static const IndexLetterBoxSize = 64.0;
  static const IndexLetterBoxRadius = 4.0;
  static const FullWidthIconButtonIconSize = 25.0;
  static const ChatBoxHeight = 48.0;

  static const String MENU_MARK_AS_UNREAD = 'MENU_MARK_AS_UNREAD';
  static const String MENU_MARK_AS_UNREAD_VALUE = '标为未读';
  static const String MENU_PIN_TO_TOP = 'MENU_PIN_TO_TOP';
  static const String MENU_PIN_TO_TOP_VALUE = '置顶聊天';
  static const String MENU_DELETE_CONVERSATION = 'MENU_DELETE_CONVERSATION';
  static const String MENU_DELETE_CONVERSATION_VALUE = '删除该聊天';
  static const String MENU_PIN_PA_TO_TOP = 'MENU_PIN_PA_TO_TOP';
  static const String MENU_PIN_PA_TO_TOP_VALUE = '置顶公众号';
  static const String MENU_UNSUBSCRIBE = 'MENU_UNSUBSCRIBE';
  static const String MENU_UNSUBSCRIBE_VALUE = '取消关注';
}

class API {
  static const initConfig = '/init';
  static const refreshToken = '/refreshtoken';
  static const login = '/passport/login';
  static const signup = '/passport/signup';
  static const getCode = '/passport/getcode';
  static const findPassword = '/passport/findpassword';
  static const assetsToken = '/auth/get_token';
  static const appVersionCheck = '/app_version/check';
  static const sqliteUpgradeDdl = '/app_version/upgrade_ddl';
  static const sqliteDowngradeDdl = '/app_version/downgrade_ddl';

  static const addFriend = '/friend/add';
  static const confirmFriend = '/friend/confirm';
  static const deleteFriend = '/friend/delete';
  static const friendList = '/friend/list';
  static const friendChangeRemark = '/friend/change_remark';

  static const conversationList = '/conversation/mine';

  static const denylistAdd = '/friend/denylist/add';
  static const denylistRemove = '/friend/denylist/remove';
  static const denylistPage = '/friend/denylist/page';

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
