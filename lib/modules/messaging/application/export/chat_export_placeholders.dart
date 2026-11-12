/// 导出占位文案与文档标签（W1-C / chat_export_share_v1；W3-J 接 i18n）。
///
/// **默认值 = W1-C 冻结的 zh-CN 契约**：不注入翻译时（含 W1-C 既有测试）
/// 输出与 Wave 1 逐字节一致（[ChatExportPlaceholders.zhCn]）。
///
/// W5-G3-5 参数化：翻译经 [ChatExportPlaceholders.of] 构造为**单次导出的
/// 不可变快照**，由 [ChatExportFormatter] 显式参数接收、controller 每次
/// 导出构造传入——不再有进程级 static 覆写与跨导出残留语义。键空间 =
/// [ChatExportTranslationKey]；未注入/空串的键回落 zh-CN 常量。
library;

/// 翻译映射的键空间（[ChatExportPlaceholders.of] 入参）。
/// 键集合与下方成员一一对应；值必须是非空字符串。
abstract final class ChatExportTranslationKey {
  static const String image = 'image';
  static const String voice = 'voice';
  static const String video = 'video';
  static const String file = 'file';
  static const String location = 'location';
  static const String expression = 'expression';
  static const String messageFallback = 'message_fallback';
  static const String conversationLabel = 'conversation_label';
  static const String exportedAtLabel = 'exported_at_label';
  static const String countLabel = 'count_label';
  static const String htmlTitle = 'html_title';
  static const String htmlLang = 'html_lang';
}

/// 单次导出的占位文案/标签快照（不可变值对象）。
///
/// zh-CN 常量为 W1-C 冻结契约的**兜底真源**；运行时翻译经 [of] 注入，
/// getter 先查覆盖再回落常量。默认实例 [zhCn] 即纯兜底口径。
class ChatExportPlaceholders {
  const ChatExportPlaceholders._(this._overrides);

  /// W1-C 冻结的 zh-CN 兜底实例（格式化器缺省参数；无翻译注入时用）。
  static const ChatExportPlaceholders zhCn = ChatExportPlaceholders._(
    <String, String>{},
  );

  /// 以 [ChatExportTranslationKey] 键空间构造翻译快照；传 null = 纯 zh-CN。
  ///
  /// - 值为非空字符串才生效（空串视为未翻译，回落 zh-CN 常量）；
  /// - 传入映射被复制为不可变快照（调用方后续改原 map 不影响本对象）；
  /// - 平台层每次导出前用当前 locale 的 `t.chat.*` 重建映射后传入。
  factory ChatExportPlaceholders.of(Map<String, String>? translations) {
    return ChatExportPlaceholders._(
      translations == null
          ? const <String, String>{}
          : Map<String, String>.unmodifiable(translations),
    );
  }

  final Map<String, String> _overrides;

  /// 当前覆盖映射（只读；测试断言用）。
  Map<String, String> get translations =>
      Map<String, String>.unmodifiable(_overrides);

  String _resolve(String key, String zhCnFallback) {
    final overridden = _overrides[key];
    return (overridden == null || overridden.isEmpty)
        ? zhCnFallback
        : overridden;
  }

  /// image / imageMulti → `[图片]`
  String get image => _resolve(ChatExportTranslationKey.image, _kImage);

  /// voice（含 audio 协议别称）→ `[语音]`
  String get voice => _resolve(ChatExportTranslationKey.voice, _kVoice);

  /// video → `[视频]`
  String get video => _resolve(ChatExportTranslationKey.video, _kVideo);

  /// file → `[文件] 文件名.ext`（无文件名时仅 `[文件]`）
  String get file => _resolve(ChatExportTranslationKey.file, _kFile);

  /// location → `[位置] 标题`（无标题时仅 `[位置]`）
  String get location =>
      _resolve(ChatExportTranslationKey.location, _kLocation);

  /// expression → `[表情]`
  String get expression =>
      _resolve(ChatExportTranslationKey.expression, _kExpression);

  /// 无可读内容的兜底占位。
  String get messageFallback =>
      _resolve(ChatExportTranslationKey.messageFallback, _kMessageFallback);

  // ---- 文档头标签（txt / html 共用）----

  String get conversationLabel =>
      _resolve(ChatExportTranslationKey.conversationLabel, _kConversationLabel);

  String get exportedAtLabel =>
      _resolve(ChatExportTranslationKey.exportedAtLabel, _kExportedAtLabel);

  String get countLabel =>
      _resolve(ChatExportTranslationKey.countLabel, _kCountLabel);

  /// html 文档兜底标题（会话名为空时使用）。
  String get htmlTitle =>
      _resolve(ChatExportTranslationKey.htmlTitle, _kHtmlTitle);

  /// html 根元素 lang 属性（BCP 47；默认随基准语言 zh-CN）。
  String get htmlLang =>
      _resolve(ChatExportTranslationKey.htmlLang, _kHtmlLang);

  // ---- W1-C 冻结的 zh-CN 常量（兜底真源，勿改值）----

  static const String _kImage = '[图片]';
  static const String _kVoice = '[语音]';
  static const String _kVideo = '[视频]';
  static const String _kFile = '[文件]';
  static const String _kLocation = '[位置]';
  static const String _kExpression = '[表情]';
  static const String _kMessageFallback = '[消息]';
  static const String _kConversationLabel = '会话';
  static const String _kExportedAtLabel = '导出时间';
  static const String _kCountLabel = '条数';
  static const String _kHtmlTitle = 'IMBoy 聊天记录';
  static const String _kHtmlLang = 'zh-CN';
}
