import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:imboy/config/const.dart';

@immutable
class IMBoyChatTheme extends ChatTheme {
  /// Creates a default chat theme. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatTheme]
  const IMBoyChatTheme({
    super.attachmentButtonIcon,
    super.backgroundColor = AppColors.ChatBg,
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
      color: AppColors.MainTextColor,
      fontFamily: 'Avenir',
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 2.0,
    ),
    super.errorColor = error,
    super.errorIcon,
    super.inputBackgroundColor = AppColors.ChatInputBackgroundColor,
    super.inputSurfaceTintColor = AppColors.ChatInputBackgroundColor,
    super.inputPadding = EdgeInsets.zero,
    super.inputTextColor = AppColors.MainTextColor,
    super.inputTextCursorColor,
    super.inputTextDecoration = const InputDecoration(
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ),
      contentPadding: EdgeInsets.fromLTRB(8, 7, 8, 8),
      isCollapsed: false,
      filled: true,
      fillColor: AppColors.ChatInputFillGgColor,
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
    super.secondaryColor = AppColors.ChatReceivedMessageBodyBgColor,
    super.inputTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 16,
      height: 1.375,
      color: AppColors.ChatInputFillGgColor,
    ),
    super.primaryColor = AppColors.ChatSendMessageBgColor,
    super.sentMessageBodyTextStyle = const TextStyle(
      color: AppColors.ChatSentMessageBodyTextColor,
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

LoginTheme loginTheme = LoginTheme(
  // backgroound
  primaryColor: AppColors.primaryBackground,
  accentColor: AppColors.primaryBackground,
  footerBackgroundColor: AppColors.primaryBackground,
  logoWidth: 1,
  headerMargin: 10,
  titleStyle: const TextStyle(
    color: AppColors.primaryElement,
  ),
  buttonTheme: LoginButtonTheme(
    splashColor: AppColors.TipColor,
    backgroundColor: AppColors.primaryElement,
    highlightColor: AppColors.secondaryElementText,
    elevation: 9.0,
    shape: BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(2),
    ),
  ),
  inputTheme: const InputDecorationTheme(
    filled: true,
    iconColor: AppColors.primaryElement,
    suffixIconColor: AppColors.primaryElement,
  ),
);

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
