import 'package:imboy/store/model/app_version_model.dart';

/// 升级策略工具类 / Upgrade strategy utilities
///
/// 纯函数，不依赖 Flutter 框架和单例服务，方便单元测试。
/// Pure functions with no Flutter or singleton dependencies — easy to unit test.
class UpgradeStrategy {
  const UpgradeStrategy._();

  /// 构建更新日志文本。
  ///
  /// 优先使用结构化 [AppVersionInfo.changelog]；
  /// changelog 为空时降级到 [AppVersionInfo.description]。
  ///
  /// Build changelog display text.
  /// Prefers structured [AppVersionInfo.changelog]; falls back to
  /// [AppVersionInfo.description] when changelog is empty.
  static String buildChangelogText(AppVersionInfo info) {
    if (info.changelog.isNotEmpty) {
      final buffer = StringBuffer();
      for (final item in info.changelog) {
        final tag = item['tag'] as String? ?? '';
        final text = item['text'] as String? ?? '';
        if (tag.isNotEmpty) {
          buffer.writeln('[$tag] $text');
        } else {
          buffer.writeln(text);
        }
      }
      if (info.fileSizeText.isNotEmpty) {
        buffer.writeln('\n安装包大小: ${info.fileSizeText}');
      }
      return buffer.toString().trimRight();
    }
    return info.description;
  }

  /// 根据升级类型和 dismiss 状态判断是否应弹出升级提示。
  ///
  /// Decide whether to show the upgrade prompt based on upgrade type
  /// and dismiss state.
  ///
  /// - `force`    : 始终提示（即使 dismissed）/ always prompts
  /// - `recommend`: 未 dismissed 时提示；手动触发时忽略 dismissed
  /// - `silent`   : 从不弹窗 / never prompts
  /// - `none`     : 从不弹窗 / never prompts
  ///
  /// 前提：info.hasUpdate 必须为 true，否则直接返回 false。
  static bool shouldPrompt(
    AppVersionInfo info, {
    required bool isDismissed,
    required bool fromManual,
  }) {
    if (!info.hasUpdate) return false;

    switch (info.upgradeType) {
      case 'force':
        return true;
      case 'recommend':
        if (fromManual) return true;
        return !isDismissed;
      case 'silent':
      case 'none':
      default:
        return false;
    }
  }
}

// ---------------------------------------------------------------------------
// AppUpgradeDismissState — dismiss 状态存储
// dismiss state storage
// ---------------------------------------------------------------------------

/// dismiss 状态管理，封装"稍后提醒"的存储和过期判断。
///
/// Manages dismiss state for "remind me later" functionality.
/// Supports injection of a storage stub for testing via duck-typing:
/// the [storage] argument must expose:
///   - `String getString(String key)`
///   - `void setString(String key, String value)`
/// Both `StorageService` and the test `FakeStorage` satisfy this contract.
class AppUpgradeDismissState {
  static const String dismissedVsnKey = 'app_upgrade_dismissed_vsn';
  static const String lastCheckTimeKey = 'app_upgrade_last_check_time';

  /// 24 小时后重新提醒 / Re-prompt after 24 hours
  static const Duration _dismissDuration = Duration(hours: 24);

  // Duck-typed storage: requires getString(String) → String
  //                                    setString(String, String) → void/Future
  final dynamic _storage;

  const AppUpgradeDismissState({required dynamic storage}) : _storage = storage;

  /// 某版本是否在有效期内被用户忽略。
  /// Whether the user dismissed [vsn] within the dismiss window.
  bool isDismissed(String vsn) {
    final dismissed = '${_storage.getString(dismissedVsnKey)}';
    if (dismissed != vsn) return false;

    final lastCheckStr = '${_storage.getString(lastCheckTimeKey)}';
    final lastCheck = int.tryParse(lastCheckStr) ?? 0;
    if (lastCheck == 0) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastCheck;
    return elapsed < _dismissDuration.inMilliseconds;
  }

  /// 记录用户点了"稍后提醒"。
  /// Record that the user tapped "remind me later" for [vsn].
  void setDismissed(String vsn) {
    _storage.setString(dismissedVsnKey, vsn);
    _storage.setString(
      lastCheckTimeKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}
