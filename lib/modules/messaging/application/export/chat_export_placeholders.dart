/// 导出占位文案与文档标签 —— zh-CN 硬编码常量（W1-C / chat_export_share_v1）。
///
/// ⚠️ Wave 2/3 接 i18n：本波（W1-C）禁改 i18n 源（assets/i18n 与
/// lib/i18n 生成物均为共享热点文件），故先以 zh-CN 常量钉死导出契约；
/// W3-J 接线时统一迁移到 `t.chat.*`（新键只进 chat namespace，
/// 见 APP_RULES 冻结决定）。迁移前这些字符串是格式化输出的稳定契约，
/// 测试以本类常量断言，改文案必须同步改测试。
library;

/// 导出用占位文案/标签常量（不可实例化）。
abstract final class ChatExportPlaceholders {
  /// image / imageMulti → `[图片]`
  static const String image = '[图片]';

  /// voice（含 audio 协议别称）→ `[语音]`
  static const String voice = '[语音]';

  /// video → `[视频]`
  static const String video = '[视频]';

  /// file → `[文件] 文件名.ext`（无文件名时仅 `[文件]`）
  static const String file = '[文件]';

  /// location → `[位置] 标题`（无标题时仅 `[位置]`）
  static const String location = '[位置]';

  /// expression → `[表情]`
  static const String expression = '[表情]';

  /// 无可读内容的兜底占位。
  static const String messageFallback = '[消息]';

  // ---- 文档头标签（txt / html 共用）----

  static const String conversationLabel = '会话';
  static const String exportedAtLabel = '导出时间';
  static const String countLabel = '条数';

  /// html 文档兜底标题（会话名为空时使用）。
  static const String htmlTitle = 'IMBoy 聊天记录';

  /// html 根元素 lang 属性。
  static const String htmlLang = 'zh-CN';
}
