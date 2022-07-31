import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:imboy/config/const.dart';

@immutable
class ImboyChatTheme extends ChatTheme {
  /// Creates a default chat theme. Use this constructor if you want to
  /// override only a couple of properties, otherwise create a new class
  /// which extends [ChatTheme]
  const ImboyChatTheme({
    Widget? attachmentButtonIcon,
    Color backgroundColor = AppColors.ChatBg,
    TextStyle dateDividerTextStyle = const TextStyle(
      color: neutral2,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    Widget? deliveredIcon,
    Widget? documentIcon,
    TextStyle emptyChatPlaceholderTextStyle = const TextStyle(
      color: AppColors.MainTextColor,
      fontFamily: 'Avenir',
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 2.0,
    ),
    Color errorColor = error,
    Widget? errorIcon,
    Color inputBackgroundColor = AppColors.ChatInputBackgroundColor,
    EdgeInsets inputPadding = EdgeInsets.zero,
    Color inputTextColor = AppColors.MainTextColor,
    Color? inputTextCursorColor,
    InputDecoration inputTextDecoration = const InputDecoration(
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ),
      contentPadding: EdgeInsets.fromLTRB(8, 7, 8, 8),
      isCollapsed: true,
      filled: true,
      fillColor: AppColors.ChatInputFillGgColor,
    ),
    double messageBorderRadius = 20,
    double messageInsetsHorizontal = 16,
    double messageInsetsVertical = 8,
    TextStyle receivedMessageBodyTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    TextStyle receivedMessageCaptionTextStyle = const TextStyle(
      color: neutral2,
      fontFamily: 'Avenir',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.333,
    ),
    Color receivedMessageDocumentIconColor = primary,
    TextStyle receivedMessageLinkDescriptionTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.428,
    ),
    TextStyle receivedMessageLinkTitleTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1.375,
    ),
    Widget? seenIcon,
    Widget? sendButtonIcon,
    Widget? sendingIcon,
    Color secondaryColor = AppColors.ChatReceivedMessageBodyBgColor,
    TextStyle inputTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 16,
      height: 1.375,
      color: AppColors.ChatInputFillGgColor,
    ),
    Color primaryColor = AppColors.ChatSendMessgeBgColor,
    TextStyle sentMessageBodyTextStyle = const TextStyle(
      color: AppColors.ChatSentMessageBodyTextColor,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    TextStyle sentMessageCaptionTextStyle = const TextStyle(
      color: neutral7WithOpacity,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.375,
    ),
    Color sentMessageDocumentIconColor = neutral7,
    TextStyle sentMessageLinkDescriptionTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.428,
    ),
    TextStyle sentMessageLinkTitleTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.375,
    ),
    Color userAvatarImageBackgroundColor = Colors.transparent,
    List<Color> userAvatarNameColors = colors,
    TextStyle userAvatarTextStyle = const TextStyle(
      color: neutral7,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    TextStyle userNameTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w800,
      height: 1.333,
    ),
    //
    EdgeInsets dateDividerMargin = const EdgeInsets.only(
      bottom: 8,
      top: 12,
    ),
    TextStyle receivedEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    TextStyle sentEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    EdgeInsets statusIconPadding = const EdgeInsets.symmetric(horizontal: 4),
  }) : super(
          sendButtonMargin: null,
          attachmentButtonMargin: null,
          attachmentButtonIcon: attachmentButtonIcon,
          backgroundColor: backgroundColor,
          dateDividerMargin: dateDividerMargin,
          dateDividerTextStyle: dateDividerTextStyle,
          deliveredIcon: deliveredIcon,
          documentIcon: documentIcon,
          emptyChatPlaceholderTextStyle: emptyChatPlaceholderTextStyle,
          errorColor: errorColor,
          errorIcon: errorIcon,
          inputBackgroundColor: inputBackgroundColor,
          inputPadding: inputPadding,
          inputTextColor: inputTextColor,
          inputTextCursorColor: inputTextCursorColor,
          inputTextDecoration: inputTextDecoration,
          inputTextStyle: inputTextStyle,
          messageBorderRadius: messageBorderRadius,
          messageInsetsHorizontal: messageInsetsHorizontal,
          messageInsetsVertical: messageInsetsVertical,
          primaryColor: primaryColor,
          receivedEmojiMessageTextStyle: receivedEmojiMessageTextStyle,
          receivedMessageBodyTextStyle: receivedMessageBodyTextStyle,
          receivedMessageCaptionTextStyle: receivedMessageCaptionTextStyle,
          receivedMessageDocumentIconColor: receivedMessageDocumentIconColor,
          receivedMessageLinkDescriptionTextStyle:
              receivedMessageLinkDescriptionTextStyle,
          receivedMessageLinkTitleTextStyle: receivedMessageLinkTitleTextStyle,
          secondaryColor: secondaryColor,
          seenIcon: seenIcon,
          sendButtonIcon: sendButtonIcon,
          sendingIcon: sendingIcon,
          sentEmojiMessageTextStyle: sentEmojiMessageTextStyle,
          sentMessageBodyTextStyle: sentMessageBodyTextStyle,
          sentMessageCaptionTextStyle: sentMessageCaptionTextStyle,
          sentMessageDocumentIconColor: sentMessageDocumentIconColor,
          sentMessageLinkDescriptionTextStyle:
              sentMessageLinkDescriptionTextStyle,
          sentMessageLinkTitleTextStyle: sentMessageLinkTitleTextStyle,
          statusIconPadding: statusIconPadding,
          userAvatarImageBackgroundColor: userAvatarImageBackgroundColor,
          userAvatarNameColors: userAvatarNameColors,
          userAvatarTextStyle: userAvatarTextStyle,
          userNameTextStyle: userNameTextStyle,
          inputBorderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
          ),
          inputMargin: const EdgeInsets.fromLTRB(16, 8, 18, 8),
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
