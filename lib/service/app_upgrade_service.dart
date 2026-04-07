import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/single/upgrade.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/app_upgrade_log_api.dart';
import 'package:imboy/store/api/app_version_api.dart';
import 'package:imboy/store/model/app_version_model.dart';

/// APP 升级检查服务
///
/// 实现三级升级策略：
/// - force: 全屏弹窗不可关闭
/// - recommend: 弹窗可关闭，下次启动再提醒
/// - silent: 设置页小红点，不弹窗
///
/// 检查时机：
/// - APP 启动后延迟 3 秒
/// - 定时检查（间隔从服务端获取，默认 24 小时）
/// - 收到 S2C app_upgrade 消息
/// - 设置页手动触发
class AppUpgradeService {
  AppUpgradeService._();
  static final AppUpgradeService _instance = AppUpgradeService._();
  static AppUpgradeService get to => _instance;

  /// 存储 key
  static const String _lastCheckTimeKey = 'app_upgrade_last_check_time';
  static const String _dismissedVsnKey = 'app_upgrade_dismissed_vsn';
  static const String _checkIntervalKey = 'app_upgrade_check_interval_hours';

  /// 最新版本信息缓存
  AppVersionInfo? _cachedInfo;

  /// 定时检查定时器
  Timer? _periodicTimer;

  /// 是否正在显示升级弹窗（防止重复弹窗）
  bool _isShowingDialog = false;

  /// 获取缓存的版本信息（供设置页红点使用）
  AppVersionInfo? get cachedInfo => _cachedInfo;

  /// 是否有静默更新可用（设置页红点）
  bool get hasSilentUpdate =>
      _cachedInfo != null && _cachedInfo!.isSilentUpgrade;

  /// 是否有任何更新可用
  bool get hasUpdate => _cachedInfo != null && _cachedInfo!.hasUpdate;

  /// APP 启动时调用
  Future<void> init() async {
    // 延迟 3 秒，不阻塞启动
    Future.delayed(const Duration(seconds: 3), () {
      checkAndPrompt();
    });
  }

  /// 停止定时检查
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// 检查版本并根据策略提示用户
  ///
  /// [fromManual] 是否手动触发（手动触发时忽略"稍后提醒"记录）
  Future<AppVersionInfo?> checkAndPrompt({bool fromManual = false}) async {
    final info = await _fetchVersionInfo();
    if (info == null) return null;

    _cachedInfo = info;
    _setupPeriodicCheck(info.checkIntervalHours);

    // 上报 check 事件
    AppUpgradeLogApi.report(
      event: 'check',
      targetVsn: info.hasUpdate ? info.vsn : '',
      upgradeType: info.upgradeType,
    );

    if (!info.hasUpdate) return info;

    switch (info.upgradeType) {
      case 'force':
        // 强制升级：立即弹窗，不可关闭
        await _showUpgradePage(info);
        break;

      case 'recommend':
        // 推荐升级：检查是否已经点过"稍后提醒"
        if (fromManual || !_isDismissed(info.vsn)) {
          await _showUpgradePage(info);
        }
        break;

      case 'silent':
        // 静默提示：只缓存信息，不弹窗
        // 设置页通过 hasSilentUpdate 展示红点
        iPrint(
          'AppUpgradeService: silent update available ${info.vsn}',
        );
        break;

      default:
        break;
    }

    return info;
  }

  /// 手动检查（设置页"检查更新"按钮）
  Future<AppVersionInfo?> manualCheck() async {
    return checkAndPrompt(fromManual: true);
  }

  /// S2C 推送触发的检查
  Future<void> onS2CUpgradeNotice(Map<String, dynamic> payload) async {
    // S2C 推送直接携带了版本信息，可以直接使用
    final info = AppVersionInfo.fromJson(payload);
    _cachedInfo = info;

    if (info.hasUpdate) {
      if (info.isForceUpgrade) {
        await _showUpgradePage(info);
      } else if (info.isRecommendUpgrade && !_isDismissed(info.vsn)) {
        await _showUpgradePage(info);
      }
      // silent 不弹窗
    }
  }

  /// 从服务端获取版本信息
  Future<AppVersionInfo?> _fetchVersionInfo() async {
    try {
      final api = AppVersionApi();
      final json = await api.check(appVsn);
      if (json.isEmpty) return null;
      return AppVersionInfo.fromJson(json);
    } catch (e) {
      iPrint('AppUpgradeService: check failed $e');
      return null;
    }
  }

  /// 显示升级页面
  Future<void> _showUpgradePage(AppVersionInfo info) async {
    if (_isShowingDialog) return;
    if (info.downloadUrl.isEmpty) return;

    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    _isShowingDialog = true;

    // 上报 prompted 事件
    AppUpgradeLogApi.report(
      event: 'prompted',
      targetVsn: info.vsn,
      upgradeType: info.upgradeType,
    );

    try {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => UpgradePage(
            version: info.vsn,
            downLoadUrl: info.downloadUrl,
            message: _buildChangelogText(info),
            isForce: info.isForceUpgrade,
            fileHash: info.fileHash,
          ),
        ),
      );

      // 如果是推荐升级且用户关闭了弹窗，记录已忽略
      if (info.isRecommendUpgrade) {
        _setDismissed(info.vsn);
      }
    } finally {
      _isShowingDialog = false;
    }
  }

  /// 构建更新日志文本
  ///
  /// 优先使用结构化 changelog，降级使用纯文本 description
  String _buildChangelogText(AppVersionInfo info) {
    if (info.changelog.isNotEmpty) {
      final buffer = StringBuffer();
      for (final item in info.changelog) {
        final tag = item['tag'] ?? '';
        final text = item['text'] ?? '';
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

  /// 设置定时检查
  void _setupPeriodicCheck(int intervalHours) {
    _periodicTimer?.cancel();
    final interval = Duration(hours: intervalHours);
    _periodicTimer = Timer.periodic(interval, (_) {
      checkAndPrompt();
    });
    // 保存间隔到本地
    StorageService.to.setString(_checkIntervalKey, intervalHours.toString());
  }

  /// 检查某版本是否已被用户点过"稍后提醒"
  bool _isDismissed(String vsn) {
    final dismissed = StorageService.to.getString(_dismissedVsnKey);
    if (dismissed != vsn) return false;

    // 检查是否超过 24 小时（超过后重新提醒）
    final lastCheck =
        int.tryParse(StorageService.to.getString(_lastCheckTimeKey)) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastCheck;
    return elapsed < const Duration(hours: 24).inMilliseconds;
  }

  /// 记录用户点了"稍后提醒"
  void _setDismissed(String vsn) {
    StorageService.to.setString(_dismissedVsnKey, vsn);
    StorageService.to.setString(
      _lastCheckTimeKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}
