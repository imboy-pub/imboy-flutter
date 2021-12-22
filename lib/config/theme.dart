import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
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
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 2.0,
    ),
    Color errorColor = error,
    Widget? errorIcon,
    Color inputBackgroundColor = AppColors.ChatInputBackgroundColor,
    BorderRadius inputBorderRadius = const BorderRadius.vertical(
      top: Radius.circular(2),
    ),
    EdgeInsetsGeometry inputPadding = EdgeInsets.zero,
    Color inputTextColor = AppColors.MainTextColor,
    Color? inputTextCursorColor,
    InputDecoration inputTextDecoration = const InputDecoration(
      border: InputBorder.none,
      contentPadding: EdgeInsets.fromLTRB(4, 4, 4, 4),
      isCollapsed: true,
      filled: true,
      fillColor: AppColors.ChatInputFillGgColor,
    ),
    double messageBorderRadius = 24,
    double messageInsetsHorizontal = 16,
    double messageInsetsVertical = 8,
    TextStyle receivedMessageBodyTextStyle = const TextStyle(
      color: neutral0,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
    TextStyle receivedMessageCaptionTextStyle = const TextStyle(
      color: neutral2,
      fontFamily: 'Avenir',
      fontSize: 12,
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
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.375,
    ),
    Widget? seenIcon,
    Widget? sendButtonIcon,
    Widget? sendingIcon,
    Color secondaryColor = AppColors.ChatReceivedMessageBodyBgColor,
    TextStyle inputTextStyle = const TextStyle(
      fontFamily: 'Avenir',
      fontSize: 14,
      height: 2.0,
      color: AppColors.ChatInputFillGgColor,
    ),
    Color primaryColor = AppColors.ChatSendMessgeBgColor,
    TextStyle sentMessageBodyTextStyle = const TextStyle(
      color: AppColors.ChatSentMessageBodyTextColor,
      fontFamily: 'Avenir',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
    TextStyle sentMessageCaptionTextStyle = const TextStyle(
      color: neutral7WithOpacity,
      fontFamily: 'Avenir',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.333,
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
    EdgeInsetsGeometry dateDividerMargin = const EdgeInsets.only(
      bottom: 8,
      top: 12,
    ),
    TextStyle receivedEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    TextStyle sentEmojiMessageTextStyle = const TextStyle(fontSize: 20),
    EdgeInsetsGeometry statusIconPadding =
        const EdgeInsets.symmetric(horizontal: 4),
  }) : super(
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
          inputBorderRadius: inputBorderRadius,
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
        );
}

class AppColors2 {
  /// 主背景 白色
  static const Color primaryBackground = Color.fromARGB(255, 255, 255, 255);

  /// 主文本 灰色
  static const Color primaryText = Color.fromARGB(255, 45, 45, 47);

  /// 主控件-背景 蓝色
  static const Color primaryElement = Color.fromARGB(255, 41, 103, 255);

  /// 主控件-文本 白色
  static const Color primaryElementText = Color.fromARGB(255, 255, 255, 255);

  // *****************************************

  /// 第二种控件-背景色 淡灰色
  static const Color secondaryElement = Color.fromARGB(255, 246, 246, 246);

  /// 第二种控件-文本 浅蓝色
  static const Color secondaryElementText = Color.fromARGB(255, 41, 103, 255);

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
}
