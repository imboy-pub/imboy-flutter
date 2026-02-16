/// Web 平台响应式布局服务
///
/// 提供类似 WhatsApp Web 的响应式布局支持
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// 屏幕断点定义
class Breakpoints {
  /// 手机端断点
  static const double mobile = 600;

  /// 平板端断点
  static const double tablet = 900;

  /// 桌面端断点
  static const double desktop = 1200;

  /// 大屏幕断点
  static const double large = 1600;
}

/// 设备类型
enum DeviceType {
  /// 手机
  mobile,

  /// 平板
  tablet,

  /// 桌面
  desktop,

  /// 大屏幕
  large,
}

/// 响应式布局信息
class ResponsiveInfo {
  final DeviceType deviceType;
  final double width;
  final double height;
  final bool isPortrait;
  final bool isLandscape;

  const ResponsiveInfo({
    required this.deviceType,
    required this.width,
    required this.height,
    required this.isPortrait,
    required this.isLandscape,
  });

  /// 是否为手机端
  bool get isMobile => deviceType == DeviceType.mobile;

  /// 是否为平板端
  bool get isTablet => deviceType == DeviceType.tablet;

  /// 是否为桌面端
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// 是否为大屏幕
  bool get isLarge => deviceType == DeviceType.large;

  /// 是否为窄屏（手机或平板）
  bool get isNarrow => isMobile || isTablet;

  /// 获取布局列数
  int get columns {
    switch (deviceType) {
      case DeviceType.mobile:
        return 4;
      case DeviceType.tablet:
        return 8;
      case DeviceType.desktop:
        return 12;
      case DeviceType.large:
        return 16;
    }
  }

  /// 获取边距
  double get padding {
    switch (deviceType) {
      case DeviceType.mobile:
        return 16;
      case DeviceType.tablet:
        return 24;
      case DeviceType.desktop:
        return 32;
      case DeviceType.large:
        return 48;
    }
  }

  /// 获取间距
  double get spacing {
    switch (deviceType) {
      case DeviceType.mobile:
        return 8;
      case DeviceType.tablet:
        return 12;
      case DeviceType.desktop:
        return 16;
      case DeviceType.large:
        return 24;
    }
  }

  /// 根据屏幕尺寸选择值
  T select<T>({
    T? mobile,
    T? tablet,
    T? desktop,
    T? large,
    required T defaultValue,
  }) {
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile ?? defaultValue;
      case DeviceType.tablet:
        return tablet ?? mobile ?? defaultValue;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile ?? defaultValue;
      case DeviceType.large:
        return large ?? desktop ?? tablet ?? mobile ?? defaultValue;
    }
  }
}

/// 响应式布局 Builder
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveInfo info) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final width = size.width;

    final deviceType = _getDeviceType(width);
    final info = ResponsiveInfo(
      deviceType: deviceType,
      width: size.width,
      height: size.height,
      isPortrait: size.height > size.width,
      isLandscape: size.width >= size.height,
    );

    return builder(context, info);
  }

  DeviceType _getDeviceType(double width) {
    if (width < Breakpoints.mobile) {
      return DeviceType.mobile;
    } else if (width < Breakpoints.tablet) {
      return DeviceType.tablet;
    } else if (width < Breakpoints.desktop) {
      return DeviceType.desktop;
    } else {
      return DeviceType.large;
    }
  }
}

/// 响应式布局组件
///
/// 类似 WhatsApp Web 的三栏布局：
/// - 左侧：会话列表
/// - 中间：聊天内容
/// - 右侧：详情面板（可选）
class ResponsiveLayout extends StatelessWidget {
  /// 左侧面板（会话列表）
  final Widget leftPanel;

  /// 中间面板（聊天内容）
  final Widget centerPanel;

  /// 右侧面板（详情，可选）
  final Widget? rightPanel;

  /// 左侧面板宽度
  final double leftPanelWidth;

  /// 右侧面板宽度
  final double rightPanelWidth;

  /// 是否显示右侧面板
  final bool showRightPanel;

  /// 左侧面板最小宽度
  final double leftPanelMinWidth;

  /// 左侧面板最大宽度
  final double leftPanelMaxWidth;

  const ResponsiveLayout({
    super.key,
    required this.leftPanel,
    required this.centerPanel,
    this.rightPanel,
    this.leftPanelWidth = 400,
    this.rightPanelWidth = 320,
    this.showRightPanel = false,
    this.leftPanelMinWidth = 280,
    this.leftPanelMaxWidth = 500,
  });

  @override
  Widget build(BuildContext context) {
    // 非 Web 平台使用简单布局
    if (!kIsWeb) {
      return _buildMobileLayout(context);
    }

    return ResponsiveBuilder(
      builder: (context, info) {
        if (info.isMobile) {
          return _buildMobileLayout(context);
        } else if (info.isTablet) {
          return _buildTabletLayout(context, info);
        } else {
          return _buildDesktopLayout(context, info);
        }
      },
    );
  }

  /// 手机布局：单栏
  Widget _buildMobileLayout(BuildContext context) {
    return leftPanel;
  }

  /// 平板布局：两栏
  Widget _buildTabletLayout(BuildContext context, ResponsiveInfo info) {
    final leftWidth = info.width * 0.35;

    return Row(
      children: [
        SizedBox(
          width: leftWidth.clamp(leftPanelMinWidth, leftPanelMaxWidth),
          child: leftPanel,
        ),
        Container(
          width: 1,
          color: const Color(0xFF2A3942),
        ),
        Expanded(
          child: centerPanel,
        ),
      ],
    );
  }

  /// 桌面布局：两栏或三栏
  Widget _buildDesktopLayout(BuildContext context, ResponsiveInfo info) {
    final leftWidth = leftPanelWidth.clamp(leftPanelMinWidth, leftPanelMaxWidth);

    return Row(
      children: [
        SizedBox(
          width: leftWidth,
          child: leftPanel,
        ),
        Container(
          width: 1,
          color: const Color(0xFF2A3942),
        ),
        Expanded(
          child: centerPanel,
        ),
        if (showRightPanel && rightPanel != null) ...[
          Container(
            width: 1,
            color: const Color(0xFF2A3942),
          ),
          SizedBox(
            width: rightPanelWidth,
            child: rightPanel,
          ),
        ],
      ],
    );
  }
}

/// 响应式值选择器
///
/// 根据屏幕宽度选择不同的值
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;
  final T? large;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.large,
  });

  /// 从 BuildContext 获取值
  T of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < Breakpoints.mobile) {
      return mobile;
    } else if (width < Breakpoints.tablet) {
      return tablet ?? mobile;
    } else if (width < Breakpoints.desktop) {
      return desktop ?? tablet ?? mobile;
    } else {
      return large ?? desktop ?? tablet ?? mobile;
    }
  }
}

/// 响应式间距
class ResponsiveSpacing {
  /// 小间距
  static ResponsiveValue<double> small = ResponsiveValue(
    mobile: 8,
    tablet: 10,
    desktop: 12,
  );

  /// 中等间距
  static ResponsiveValue<double> medium = ResponsiveValue(
    mobile: 12,
    tablet: 16,
    desktop: 20,
  );

  /// 大间距
  static ResponsiveValue<double> large = ResponsiveValue(
    mobile: 16,
    tablet: 24,
    desktop: 32,
  );

  /// 获取间距
  static double of(BuildContext context, ResponsiveValue<double> spacing) {
    return spacing.of(context);
  }
}

/// 响应式字体大小
class ResponsiveFontSize {
  /// 标题字体
  static ResponsiveValue<double> heading = ResponsiveValue(
    mobile: 20,
    tablet: 24,
    desktop: 28,
    large: 32,
  );

  /// 正文字体
  static ResponsiveValue<double> body = ResponsiveValue(
    mobile: 14,
    tablet: 15,
    desktop: 16,
  );

  /// 小字体
  static ResponsiveValue<double> caption = ResponsiveValue(
    mobile: 11,
    tablet: 12,
    desktop: 13,
  );
}
