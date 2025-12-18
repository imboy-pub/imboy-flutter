import 'package:imboy/theme/default/font_types.dart';

/// 主题设置数据模型
/// 用于持久化存储用户的主题偏好设置
class ThemeSettings {
  /// 是否使用暗色主题
  final bool isDarkMode;

  /// 字体大小选项
  final FontSizeOption fontSizeOption;

  /// 是否跟随系统主题
  final bool followSystemTheme;

  /// 是否使用动态颜色（Material You）
  final bool useDynamicColor;

  /// 主题切换动画持续时间（毫秒）
  final int animationDuration;

  /// 是否启用OLED优化模式（纯黑背景）
  final bool isOLEDMode;

  /// 是否启用护眼模式（暖色调）
  final bool isEyeCareMode;

  const ThemeSettings({
    this.isDarkMode = false,
    this.fontSizeOption = FontSizeOption.normal,
    this.followSystemTheme = false,
    this.useDynamicColor = false,
    this.animationDuration = 300,
    this.isOLEDMode = false,
    this.isEyeCareMode = false,
  });

  /// 默认设置
  static const ThemeSettings defaultSettings = ThemeSettings();

  /// 从 Map 创建 ThemeSettings
  factory ThemeSettings.fromMap(Map<String, dynamic> map) {
    return ThemeSettings(
      isDarkMode: _safeBoolFromMap(map, 'isDarkMode', false),
      fontSizeOption:
          FontSizeOption.fromValue(
            _safeStringFromMap(map, 'fontSizeOption', 'normal'),
          ) ??
          FontSizeOption.normal,
      followSystemTheme: _safeBoolFromMap(map, 'followSystemTheme', false),
      useDynamicColor: _safeBoolFromMap(map, 'useDynamicColor', false),
      animationDuration: _safeIntFromMap(map, 'animationDuration', 300),
      isOLEDMode: _safeBoolFromMap(map, 'isOLEDMode', false),
      isEyeCareMode: _safeBoolFromMap(map, 'isEyeCareMode', false),
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'isDarkMode': isDarkMode,
      'fontSizeOption': fontSizeOption.value,
      'followSystemTheme': followSystemTheme,
      'useDynamicColor': useDynamicColor,
      'animationDuration': animationDuration,
      'isOLEDMode': isOLEDMode,
      'isEyeCareMode': isEyeCareMode,
    };
  }

  /// 从 JSON 字符串创建 ThemeSettings
  factory ThemeSettings.fromJson(String json) {
    try {
      final map = Map<String, dynamic>.from(
        // 这里需要 json.decode，但为了避免导入依赖，我们使用简单的解析
        _parseSimpleJson(json),
      );
      return ThemeSettings.fromMap(map);
    } catch (e) {
      // 解析失败时返回默认设置
      return ThemeSettings.defaultSettings;
    }
  }

  /// 转换为 JSON 字符串
  String toJson() {
    final map = toMap();
    return _encodeSimpleJson(map);
  }

  /// 创建副本并修改指定属性
  ThemeSettings copyWith({
    bool? isDarkMode,
    FontSizeOption? fontSizeOption,
    bool? followSystemTheme,
    bool? useDynamicColor,
    int? animationDuration,
    bool? isOLEDMode,
    bool? isEyeCareMode,
  }) {
    return ThemeSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      fontSizeOption: fontSizeOption ?? this.fontSizeOption,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      animationDuration: animationDuration ?? this.animationDuration,
      isOLEDMode: isOLEDMode ?? this.isOLEDMode,
      isEyeCareMode: isEyeCareMode ?? this.isEyeCareMode,
    );
  }

  /// 验证设置是否有效
  bool isValid() {
    return animationDuration >= 0 &&
        animationDuration <= 2000 && // 最大2秒动画
        FontScaleCalculator.isValidScale(fontSizeOption.scale);
  }

  /// 获取安全的设置（应用边界检查）
  ThemeSettings getSafeSettings() {
    return ThemeSettings(
      isDarkMode: isDarkMode,
      fontSizeOption: fontSizeOption,
      followSystemTheme: followSystemTheme,
      useDynamicColor: useDynamicColor,
      animationDuration: animationDuration.clamp(0, 2000),
      isOLEDMode: isOLEDMode,
      isEyeCareMode: isEyeCareMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeSettings &&
        other.isDarkMode == isDarkMode &&
        other.fontSizeOption == fontSizeOption &&
        other.followSystemTheme == followSystemTheme &&
        other.useDynamicColor == useDynamicColor &&
        other.animationDuration == animationDuration &&
        other.isOLEDMode == isOLEDMode &&
        other.isEyeCareMode == isEyeCareMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      isDarkMode,
      fontSizeOption,
      followSystemTheme,
      useDynamicColor,
      animationDuration,
      isOLEDMode,
      isEyeCareMode,
    );
  }

  @override
  String toString() {
    return 'ThemeSettings('
        'isDarkMode: $isDarkMode, '
        'fontSizeOption: $fontSizeOption, '
        'followSystemTheme: $followSystemTheme, '
        'useDynamicColor: $useDynamicColor, '
        'animationDuration: $animationDuration, '
        'isOLEDMode: $isOLEDMode, '
        'isEyeCareMode: $isEyeCareMode'
        ')';
  }

  // 简单的 JSON 解析器（避免引入额外依赖）
  static Map<String, dynamic> _parseSimpleJson(String json) {
    final map = <String, dynamic>{};

    // 移除大括号和空格
    final content = json.replaceAll(RegExp(r'[{}"\s]'), '');

    // 按逗号分割
    final pairs = content.split(',');

    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0];
        final value = keyValue[1];

        // 尝试解析不同类型的值
        if (value == 'true') {
          map[key] = true;
        } else if (value == 'false') {
          map[key] = false;
        } else if (int.tryParse(value) != null) {
          map[key] = int.parse(value);
        } else {
          map[key] = value;
        }
      }
    }

    return map;
  }

  // 简单的 JSON 编码器
  static String _encodeSimpleJson(Map<String, dynamic> map) {
    final pairs = <String>[];

    map.forEach((key, value) {
      String valueStr;
      if (value is String) {
        valueStr = '"$value"';
      } else {
        valueStr = value.toString();
      }
      pairs.add('"$key": $valueStr');
    });

    return '{${pairs.join(', ')}}';
  }

  // 安全的类型转换方法
  static bool _safeBoolFromMap(
    Map<String, dynamic> map,
    String key,
    bool defaultValue,
  ) {
    final value = map[key];
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return defaultValue;
  }

  static String _safeStringFromMap(
    Map<String, dynamic> map,
    String key,
    String defaultValue,
  ) {
    final value = map[key];
    if (value is String) return value;
    if (value != null) return value.toString();
    return defaultValue;
  }

  static int _safeIntFromMap(
    Map<String, dynamic> map,
    String key,
    int defaultValue,
  ) {
    final value = map[key];
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return defaultValue;
  }
}
