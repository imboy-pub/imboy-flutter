import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:get/get.dart';

//调用的时候需要把hex改一下，比如#223344 needs change to 0xFF223344
//即把#换成0xFF即可
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

const Color lightBgColor = Color.fromRGBO(248, 248, 248, 1.0);
// const Color lightInputBgColor = Colors.white70;
const Color lightPrimaryColor = Color.fromRGBO(236, 236, 236, 1);
const Color lightOnPrimaryColor = Color.fromRGBO(68, 68, 68, 1.0);
const Color lightInputTextColor = Color.fromRGBO(10, 25, 12, 1.0);
const Color lightInputFillColor = Color.fromRGBO(255, 255, 255, 1.0);

const Color darkBgColor = Color.fromRGBO(40, 40, 40, 1.0);
// const Color darkInputBgColor = Colors.black87;
const Color darkPrimaryColor = Color.fromRGBO(26, 26, 26, 1);
const Color darkOnPrimaryColor = Color.fromRGBO(208, 208, 208, 1.0);
const Color darkInputTextColor = Color.fromRGBO(255, 255, 255, 1.0);
const Color darkInputFillColor = Color.fromRGBO(44, 44, 44, 1.0);

class ChatColor {
  // for chat
  // static const ChatBg = Color.fromRGBO(243, 243, 243, 1.0);
  static const ChatSendMessageBgColor = Color.fromRGBO(178, 236, 114, 1.0);
  static const ChatSentMessageBodyTextColor = Color.fromRGBO(19, 29, 13, 1.0);

  static const ChatReceivedMessageBodyTextColor =
      Color.fromRGBO(255, 255, 255, 1.0);
  static const ChatReceivedMessageBodyBgColor = Color.fromRGBO(48, 48, 48, 1.0);

  static const ChatInputFillGgColor = Color.fromRGBO(220, 220, 220, 1.0);

// static const MainTextColor = Color.fromRGBO(115, 115, 115, 1.0);
// end for chat
}

final ColorScheme lightColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.light,
  seedColor: Colors.black,
  primary: lightPrimaryColor,
  // 主色调，用于突出显示和主要操作
  onPrimary: lightOnPrimaryColor,
  // 主色调上的文字或图标颜色
  primaryContainer: lightPrimaryColor.withOpacity(0.8),
  // 主色调的容器背景色，更淡一些以提供对比
  onPrimaryContainer: Colors.black54,
  // 主色调容器上的文字或图标颜色
  background: lightBgColor,
  // 背景颜色，比表面颜色稍深一些以提供对比
  onBackground: Colors.black54,
  // 背景颜色上的文字或图标颜色
  error: Colors.red,
  // 错误状态的颜色
  onError: Colors.white, // 错误状态上的文字或图标颜色
);
final ColorScheme darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: Colors.black,
  primary: darkPrimaryColor,
  // 主色调保持不变，以确保品牌一致性
  onPrimary: darkOnPrimaryColor,
  // 主色调上的文字颜色改为黑色或深色
  primaryContainer: darkPrimaryColor.withOpacity(0.8),
  // 主色调的容器背景色，更淡一些以提供对比
  onPrimaryContainer: Colors.black54,
  // 主色调容器上的文字或图标颜色
  background: darkBgColor,
  // 背景颜色改为更深的黑色调
  onBackground: Colors.white70,
  // 背景颜色上的文字颜色保持一定的透明度
  error: Colors.red,
  // 错误颜色
  onError: Colors.white, // 错误颜色上的文字颜色改为黑色
);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  platform: TargetPlatform.iOS,
  useMaterial3: true,
  primarySwatch: createMaterialColor(const Color(0xFF223344)),
  colorScheme: lightColorScheme,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  platform: TargetPlatform.iOS,
  primarySwatch: createMaterialColor(const Color(0x00ffffff)),
  useMaterial3: true,
  colorScheme: darkColorScheme,
    // inputDecorationTheme: InputDecorationTheme(),
);

final LoginTheme loginTheme = LoginTheme(
  // background
  primaryColor: Get.isDarkMode ? darkPrimaryColor : lightPrimaryColor,
  accentColor: Theme.of(Get.context!).colorScheme.onPrimary,
  footerBackgroundColor: Colors.green,
  logoWidth: 1,
  headerMargin: 10,
  titleStyle: TextStyle(
    color: Theme.of(Get.context!).colorScheme.onPrimary,
  ),
  buttonTheme: LoginButtonTheme(
    splashColor: Theme.of(Get.context!).colorScheme.onPrimary,
    backgroundColor: Colors.green,
    highlightColor: Colors.white,
    elevation: 9.0,
    shape: BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(2),
    ),
  ),
  inputTheme: const InputDecorationTheme(
    filled: true,
    // iconColor: Colors.red,
    // suffixIconColor: AppColors.primaryElement,
  ),
);

@immutable
class AppDarkChatTheme extends ChatTheme {
  /// Creates a default chat theme. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatTheme]
  const AppDarkChatTheme({
    super.backgroundColor = darkBgColor,
    super.inputBackgroundColor = const Color.fromRGBO(34, 34, 34, 1.0),
    super.inputSurfaceTintColor = const Color.fromRGBO(34, 34, 34, 1.0),
    super.attachmentButtonIcon,
    super.dateDividerTextStyle = const TextStyle(
      color: neutral2,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    super.deliveredIcon,
    super.documentIcon,
    super.emptyChatPlaceholderTextStyle = const TextStyle(
      // color: Colors.black,
      fontFamily: 'Avenir',
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 2.0,
    ),
    super.errorColor = error,
    super.errorIcon,
    super.inputPadding = EdgeInsets.zero,
    super.inputTextColor = darkInputTextColor,
    super.inputTextCursorColor,
    super.inputTextDecoration = const InputDecoration(
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ),
      contentPadding: EdgeInsets.fromLTRB(8, 7, 8, 8),
      isCollapsed: false,
      filled: true,
      // fillColor: ChatColor.ChatInputFillGgColor,
      fillColor: darkInputFillColor,
    ),
    super.messageBorderRadius = 20,
    super.messageInsetsHorizontal = 16,
    super.messageInsetsVertical = 8,
    super.receivedMessageBodyTextStyle = const TextStyle(
      // color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    super.receivedMessageCaptionTextStyle = const TextStyle(
      color: neutral2,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.333,
    ),
    super.receivedMessageDocumentIconColor = primary,
    super.receivedMessageLinkDescriptionTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.428,
    ),
    super.receivedMessageLinkTitleTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.375,
    ),
    super.seenIcon,
    super.sendButtonIcon,
    super.sendingIcon,
    super.secondaryColor = const Color.fromRGBO(48, 48, 48, 1.0),
    super.inputTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 16,
      height: 1.375,
      color: ChatColor.ChatInputFillGgColor,
    ),
    super.primaryColor = ChatColor.ChatSendMessageBgColor,
    super.sentMessageBodyTextStyle = const TextStyle(
      color: ChatColor.ChatSentMessageBodyTextColor,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    super.sentMessageCaptionTextStyle = const TextStyle(
      color: neutral7WithOpacity,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    super.sentMessageDocumentIconColor = neutral7,
    super.sentMessageLinkDescriptionTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.428,
    ),
    super.sentMessageLinkTitleTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.375,
    ),
    super.userAvatarImageBackgroundColor = Colors.transparent,
    super.userAvatarNameColors = colors,
    super.userAvatarTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    super.userNameTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    //
    super.dateDividerMargin = const EdgeInsets.only(
      bottom: 8,
      top: 12,
    ),
    super.receivedEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    super.sentEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    super.statusIconPadding = const EdgeInsets.symmetric(horizontal: 4),
    super.typingIndicatorTheme = const TypingIndicatorTheme(
      animatedCirclesColor: neutral1,
      animatedCircleSize: 5.0,
      bubbleBorder: BorderRadius.all(Radius.circular(27.0)),
      bubbleColor: neutral7,
      countAvatarColor: primary,
      countTextColor: secondary,
      multipleUserTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: neutral2,
      ),
    ),
    super.messageMaxWidth = double.infinity,
  }) : super(
          sendButtonMargin: null,
          attachmentButtonMargin: null,
          inputElevation: 0,
          systemMessageTheme: const SystemMessageTheme(
            margin: EdgeInsets.only(
              bottom: 24,
              top: 8,
              left: 8,
              right: 8,
            ),
            textStyle: TextStyle(
              color: neutral2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.333,
            ),
          ),
          inputBorderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
          ),
          inputMargin: const EdgeInsets.fromLTRB(16, 8, 18, 8),
          unreadHeaderTheme: const UnreadHeaderTheme(
            color: secondary,
            textStyle: TextStyle(
              color: neutral2,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.333,
            ),
          ),
        );
}

@immutable
class LightChatTheme extends ChatTheme {
  /// Creates a default chat theme. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatTheme]
  const LightChatTheme({
    super.backgroundColor = lightBgColor,
    super.attachmentButtonIcon,
    super.dateDividerTextStyle = const TextStyle(
      color: neutral2,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    super.deliveredIcon,
    super.documentIcon,
    super.emptyChatPlaceholderTextStyle = const TextStyle(
      // color: Theme.of(Get.context!).colorScheme.onPrimary,
      fontFamily: 'Avenir',
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 2.0,
    ),
    super.errorColor = error,
    super.errorIcon,
    super.inputBackgroundColor = const Color.fromRGBO(246, 246, 246, 1.0),
    super.inputSurfaceTintColor = const Color.fromRGBO(246, 246, 246, 1.0),
    super.inputPadding = EdgeInsets.zero,
    super.inputTextColor = lightInputTextColor,
    super.inputTextCursorColor,
    super.inputTextDecoration = const InputDecoration(
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ),
      contentPadding: EdgeInsets.fromLTRB(8, 7, 8, 8),
      isCollapsed: false,
      filled: true,
      fillColor: ChatColor.ChatInputFillGgColor,
    ),
    super.messageBorderRadius = 20,
    super.messageInsetsHorizontal = 16,
    super.messageInsetsVertical = 8,
    super.receivedMessageBodyTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    super.receivedMessageCaptionTextStyle = const TextStyle(
      color: neutral2,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.333,
    ),
    super.receivedMessageDocumentIconColor = primary,
    super.receivedMessageLinkDescriptionTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.428,
    ),
    super.receivedMessageLinkTitleTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.375,
    ),
    super.seenIcon,
    super.sendButtonIcon,
    super.sendingIcon,
    super.secondaryColor = const Color.fromRGBO(255, 255, 255, 1.0),
    super.inputTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 16,
      height: 1.375,
      color: ChatColor.ChatInputFillGgColor,
    ),
    super.primaryColor = ChatColor.ChatSendMessageBgColor,
    super.sentMessageBodyTextStyle = const TextStyle(
      color: ChatColor.ChatSentMessageBodyTextColor,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    super.sentMessageCaptionTextStyle = const TextStyle(
      color: neutral7WithOpacity,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    super.sentMessageDocumentIconColor = neutral7,
    super.sentMessageLinkDescriptionTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.428,
    ),
    super.sentMessageLinkTitleTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.375,
    ),
    super.userAvatarImageBackgroundColor = Colors.transparent,
    super.userAvatarNameColors = colors,
    super.userAvatarTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    super.userNameTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    //
    super.dateDividerMargin = const EdgeInsets.only(
      bottom: 8,
      top: 12,
    ),
    super.receivedEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    super.sentEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    super.statusIconPadding = const EdgeInsets.symmetric(horizontal: 4),
    super.typingIndicatorTheme = const TypingIndicatorTheme(
      animatedCirclesColor: neutral1,
      animatedCircleSize: 5.0,
      bubbleBorder: BorderRadius.all(Radius.circular(27.0)),
      bubbleColor: neutral7,
      countAvatarColor: primary,
      countTextColor: secondary,
      multipleUserTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: neutral2,
      ),
    ),
    super.messageMaxWidth = double.infinity,
  }) : super(
          sendButtonMargin: null,
          attachmentButtonMargin: null,
          inputElevation: 0,
          systemMessageTheme: const SystemMessageTheme(
            margin: EdgeInsets.only(
              bottom: 24,
              top: 8,
              left: 8,
              right: 8,
            ),
            textStyle: TextStyle(
              color: neutral2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.333,
            ),
          ),
          inputBorderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
          ),
          inputMargin: const EdgeInsets.fromLTRB(16, 8, 18, 8),
          unreadHeaderTheme: const UnreadHeaderTheme(
            color: secondary,
            textStyle: TextStyle(
              color: neutral2,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.333,
            ),
          ),
        );
}

class AppStyle {
  static TextStyle navAppBarTitleStyle = TextStyle(
    color: Theme.of(Get.context!).colorScheme.onPrimary,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
  );
}