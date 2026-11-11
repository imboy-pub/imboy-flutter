/// 导出占位文案与文档标签（W1-C / chat_export_share_v1；W3-J 接 i18n）。
///
/// **默认值 = W1-C 冻结的 zh-CN 契约**：不注入翻译时（含 W1-C 既有测试）
/// 输出与 Wave 1 逐字节一致。
///
/// W3-J 翻译缝（不改 [ChatExportFormatter] 纯函数签名）：
/// 平台层在导出前调 [ChatExportPlaceholders.applyTranslations] 注入
/// `t.chat.exportPlaceholder*` / `t.chat.exportLabel*` 映射（键为
/// [ChatExportTranslationKey] 常量），格式化器经同名 getter 读取——
/// 覆盖只影响本次进程后续格式化，未注入的键回落 zh-CN 常量。
library;

/// 翻译映射的键空间（[ChatExportPlaceholders.applyTranslations] 入参）。
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

/// 导出用占位文案/标签（不可实例化）。
///
/// zh-CN 常量为 W1-C 冻结契约的**兜底真源**；运行时翻译经
/// [applyTranslations] 注入（W3-J），getter 先查覆盖再回落常量。
abstract final class ChatExportPlaceholders {
  ChatExportPlaceholders._();

  static Map<String, String> _overrides = const <String, String>{};

  /// 注入（或传 null 清除）运行时翻译映射。
  ///
  /// - 值为非空字符串才生效（空串视为未翻译，回落 zh-CN 常量）；
  /// - 传入映射被复制为不可变快照（调用方后续改原 map 不影响本类）；
  /// - W3-J 平台层每次导出前用当前 locale 的 `t.chat.*` 重建映射。
  static void applyTranslations(Map<String, String>? translations) {
    _overrides = translations == null
        ? const <String, String>{}
        : Map<String, String>.unmodifiable(translations);
  }

  /// 当前覆盖映射（只读；测试断言用）。
  static Map<String, String> get translations =>
      Map<String, String>.unmodifiable(_overrides);

  static String _resolve(String key, String zhCnFallback) {
    final overridden = _overrides[key];
    return (overridden == null || overridden.isEmpty)
        ? zhCnFallback
        : overridden;
  }

  /// image / imageMulti → `[图片]`
  static String get image => _resolve(ChatExportTranslationKey.image, _kImage);

  /// voice（含 audio 协议别称）→ `[语音]`
  static String get voice => _resolve(ChatExportTranslationKey.voice, _kVoice);

  /// video → `[视频]`
  static String get video => _resolve(ChatExportTranslationKey.video, _kVideo);

  /// file → `[文件] 文件名.ext`（无文件名时仅 `[文件]`）
  static String get file => _resolve(ChatExportTranslationKey.file, _kFile);

  /// location → `[位置] 标题`（无标题时仅 `[位置]`）
  static String get location =>
      _resolve(ChatExportTranslationKey.location, _kLocation);

  /// expression → `[表情]`
  static String get expression =>
      _resolve(ChatExportTranslationKey.expression, _kExpression);

  /// 无可读内容的兜底占位。
  static String get messageFallback =>
      _resolve(ChatExportTranslationKey.messageFallback, _kMessageFallback);

  // ---- 文档头标签（txt / html 共用）----

  static String get conversationLabel =>
      _resolve(ChatExportTranslationKey.conversationLabel, _kConversationLabel);

  static String get exportedAtLabel =>
      _resolve(ChatExportTranslationKey.exportedAtLabel, _kExportedAtLabel);

  static String get countLabel =>
      _resolve(ChatExportTranslationKey.countLabel, _kCountLabel);

  /// html 文档兜底标题（会话名为空时使用）。
  static String get htmlTitle =>
      _resolve(ChatExportTranslationKey.htmlTitle, _kHtmlTitle);

  /// html 根元素 lang 属性（BCP 47；默认随基准语言 zh-CN）。
  static String get htmlLang =>
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
