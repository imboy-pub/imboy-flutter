/// APP 版本信息模型
///
/// 服务端版本检查 API 返回的结构化数据
class AppVersionInfo {
  /// 最新版本号
  final String vsn;

  /// 下载地址
  final String downloadUrl;

  /// 更新描述（纯文本，向后兼容）
  final String description;

  /// 升级类型：force / recommend / silent / none
  final String upgradeType;

  /// 最低支持版本
  final String minSupportedVsn;

  /// 结构化更新日志
  /// 格式: [{"tag":"新功能","text":"支持频道聊天"}, ...]
  final List<Map<String, dynamic>> changelog;

  /// 安装包文件大小（字节）
  final int fileSize;

  /// 安装包 SHA256 校验值
  final String fileHash;

  /// 是否可更新
  final bool updatable;

  /// 客户端检查间隔（小时）
  final int checkIntervalHours;

  /// 旧字段兼容：是否强制更新（1=是 2=否）
  final int forceUpdate;

  const AppVersionInfo({
    required this.vsn,
    required this.downloadUrl,
    this.description = '',
    this.upgradeType = 'none',
    this.minSupportedVsn = '0.0.0',
    this.changelog = const [],
    this.fileSize = 0,
    this.fileHash = '',
    this.updatable = false,
    this.checkIntervalHours = 24,
    this.forceUpdate = 2,
  });

  /// 从服务端 JSON 解析
  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    // 解析 changelog：可能是 List 或 JSON 字符串
    List<Map<String, dynamic>> changelogList = [];
    final rawChangelog = json['changelog'];
    if (rawChangelog is List) {
      changelogList = rawChangelog
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return AppVersionInfo(
      vsn: json['vsn'] as String? ?? '0.0.0',
      downloadUrl: json['download_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      upgradeType: json['upgrade_type'] as String? ?? 'none',
      minSupportedVsn: json['min_supported_vsn'] as String? ?? '0.0.0',
      changelog: changelogList,
      fileSize: json['file_size'] as int? ?? 0,
      fileHash: json['file_hash'] as String? ?? '',
      updatable: json['updatable'] as bool? ?? false,
      checkIntervalHours: json['check_interval_hours'] as int? ?? 24,
      forceUpdate: json['force_update'] as int? ?? 2,
    );
  }

  /// 是否需要强制升级
  bool get isForceUpgrade => upgradeType == 'force';

  /// 是否推荐升级
  bool get isRecommendUpgrade => upgradeType == 'recommend';

  /// 是否静默提示
  bool get isSilentUpgrade => upgradeType == 'silent';

  /// 是否无需更新
  bool get isNoUpgrade => upgradeType == 'none';

  /// 是否有更新可用（任何类型）
  bool get hasUpdate => updatable && !isNoUpgrade;

  /// 格式化的文件大小
  String get fileSizeText {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}
