import 'package:flutter/material.dart';

const appVsn = "1.0.0";

const defIcon = 'assets/images/def_avatar.png';

const String defGroupAvatar =
    'http://www.flutterj.com/content/uploadfile/zidingyi/g.png';

const contactAssets = 'assets/images/contact/';

const defAvatar = 'http://flutterj.com/f.jpeg';

const myCode = 'http://flutterj.com/c.jpg';

const download = 'http://flutterj.com/download.png';

const CONST_HELP_URL =
    'https://kf.qq.com/touch/product/wechat_app.html?scene_id=kf338';

const defContentImg =
    'https://www.runoob.com/wp-content/uploads/2015/06/image_1c58e950q14da167k1nqpu2hn5e9.png';

class Keys {
  // 客服端Key
  static final String currentLanguageCode = "current_language_code";
  static final String currentLanguage = "current_language";

  static final String currentUid = "current_uid";
  static final String currentUser = "current_user";

  static final String account = "account";
  static final String password = "password";
  static final String nickname = 'nickname';
  static final String avatar = 'avatar';
  static final String gender = 'gender';

  // 与服务端约定的Key
  static const tokenKey = 'authorization';
  static const refreshtokenKey = 'imboy-refreshtoken';
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

  static const TitleColor = 0xff181818;
  static const ButtonArrowColor = 0xffadadad;


  static const ChatBg = Color.fromRGBO(243, 243, 243, 1.0);
  static const ChatSendMessgeBgColor = Color.fromRGBO(169, 234, 122, 1.0);
  static const ChatSentMessageBodyTextColor = Color.fromRGBO(19, 29, 13, 1.0);

  static const ChatReceivedMessageBodyTextColor = Color.fromRGBO(25, 25, 25, 1.0);
  static const ChatReceivedMessageBodyBgColor = Color.fromRGBO(255, 255, 255, 1.0);
  static const ChatInputBackgroundColor = Color.fromRGBO(240, 240, 240, 1.0);
  static const ChatInputFillGgColor = Color.fromRGBO(255, 255, 255, 1.0);

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
  static const init = '/init';
  static const refreshtoken = '/refreshtoken';
  static const login = '/passport/login';
  static const register = '/passport/register';
  static const friendList = '/friend/list';
  static const conversationList = '/conversation/mine';

  static const avatarUrl = 'http://www.lorempixel.com/200/200/';
  static const cat = 'https://api.thecatapi.com/v1/images/search';
  static const upImg = "http://111.230.251.115/oldchen/fUser/oneDaySuggestion";
  static const update = 'http://www.flutterj.com/api/update.json';
  static const uploadImg = 'http://www.flutterj.com/upload/avatar';
}

// class AppStyles {
//   static const DefStyle = TextStyle(color: Colors.white);
//
//   static const TitleStyle = TextStyle(
//     fontSize: Constants.TitleTextSize,
//     color: const Color(AppColors.TitleColor),
//   );
//
//   static const DesStyle = TextStyle(
//     fontSize: Constants.DesTextSize,
//     color: Color(AppColors.DesTextColor),
//   );
//
//   static const UnreadMsgCountDotStyle = TextStyle(
//     fontSize: 12.0,
//     color: Color(AppColors.NotifyDotText),
//   );
//
//   static const DeviceInfoItemTextStyle = TextStyle(
//     fontSize: Constants.DesTextSize,
//     color: Color(AppColors.DeviceInfoItemText),
//   );
//
//   static const GroupTitleItemTextStyle = TextStyle(
//     fontSize: 14.0,
//     color: Color(AppColors.ContactGroupTitleText),
//   );
//
//   static const IndexLetterBoxTextStyle =
//       TextStyle(fontSize: 32.0, color: Colors.white);
//
//   static const HeaderCardTitleTextStyle = TextStyle(
//       fontSize: 20.0,
//       color: Color(AppColors.HeaderCardTitleText),
//       fontWeight: FontWeight.bold);
//
//   static const HeaderCardDesTextStyle = TextStyle(
//       fontSize: 14.0,
//       color: Color(AppColors.HeaderCardDesText),
//       fontWeight: FontWeight.normal);
//
//   static const ButtonDesTextStyle = TextStyle(
//       fontSize: 12.0,
//       color: Color(AppColors.ButtonDesText),
//       fontWeight: FontWeight.bold);
//
//   static const NewTagTextStyle = TextStyle(
//       fontSize: Constants.DesTextSize,
//       color: Colors.white,
//       fontWeight: FontWeight.bold);
//
//   static const ChatBoxTextStyle = TextStyle(
//       textBaseline: TextBaseline.alphabetic,
//       fontSize: Constants.ContentTextSize,
//       color: const Color(AppColors.TitleColor));
// }
