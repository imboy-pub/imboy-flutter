import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// 应用组件尺寸 Design Tokens
///
/// 定义应用中所有固定组件尺寸，确保界面一致性和可预测性。
/// 尺寸基于触摸目标最小尺寸（48dp）和内容密度平衡。
///
/// 使用示例：
/// ```dart
/// // 直接使用常量
/// SizedBox(
///   width: AppSizes.buttonHeight,
///   height: AppSizes.buttonHeight,
/// )
///
/// // 用于约束
/// ConstrainedBox(
///   constraints: BoxConstraints(
///     minHeight: AppSizes.touchTarget,
///   ),
/// )
/// ```
///
/// 尺寸规范：
/// - 触摸目标最小 48px（符合 WCAG AAA 标准）
/// - 按钮高度 40/44/48px
/// - 图标尺寸 16/20/24/32/48px
/// - 头像尺寸 32/40/48/64/80px
class AppSizes {
  AppSizes._();

  // ==================== 触摸目标 ====================

  /// 触摸目标最小尺寸 - 48px
  ///
  /// 使用场景：
  /// - 所有可交互元素的最小尺寸
  /// - 按钮、链接、图标按钮
  /// - 符合 WCAG 2.1 AAA 级标准
  static const double touchTarget = 48.0;

  /// 紧凑触摸目标 - 40px
  ///
  /// 使用场景：
  /// - 空间受限时的小按钮
  /// - 工具栏按钮
  /// ⚠️ 确保有足够的点击区域
  static const double touchTargetCompact = 40.0;

  // ==================== 按钮尺寸 ====================

  /// 小按钮高度 - 36px
  ///
  /// 使用场景：
  /// - **小号按钮**（ButtonStyle.small）
  /// - 紧凑表单中的按钮
  /// - 图标+文字的组合按钮
  static const double buttonHeightSmall = 36.0;

  /// 中按钮高度 - 40px
  ///
  /// 使用场景：
  /// - **中号按钮**（默认）
  /// - 表单中的提交按钮
  /// - 对话框中的按钮
  static const double buttonHeightMedium = 40.0;

  /// 大按钮高度 - 48px
  ///
  /// 使用场景：
  /// - **大号按钮**（ButtonStyle.large）
  /// - 主要操作按钮
  /// - 底部固定按钮
  static const double buttonHeightLarge = 48.0;

  /// 超大按钮高度 - 56px
  ///
  /// 使用场景：
  /// - 特殊强调按钮
  /// - 营销活动按钮
  static const double buttonHeightXLarge = 56.0;

  /// 按钮最小宽度 - 72px
  ///
  /// 使用场景：
  /// - 文字按钮的最小宽度
  /// - 确保按钮不会太窄
  static const double buttonMinWidth = 72.0;

  /// 浮动按钮尺寸 - 56px
  ///
  /// 使用场景：
  /// - **FloatingActionButton** 标准尺寸
  static const double fabSize = 56.0;

  /// 小浮动按钮尺寸 - 40px
  ///
  /// 使用场景：
  /// - **FloatingActionButton.small**
  static const double fabSizeSmall = 40.0;

  /// 大浮动按钮尺寸 - 64px
  ///
  /// 使用场景：
  /// - **FloatingActionButton.large**
  /// 扩展的浮动按钮
  static const double fabSizeLarge = 64.0;

  // ==================== 输入框尺寸 ====================

  /// 输入框高度 - 48px
  ///
  /// 使用场景：
  /// - **TextField**、**TextFormField** 标准高度
  /// - 搜索框
  /// - 下拉选择框
  static const double inputHeight = 48.0;

  /// 小输入框高度 - 40px
  ///
  /// 使用场景：
  /// - 紧凑表单中的输入框
  static const double inputHeightSmall = 40.0;

  /// 大输入框高度 - 56px
  ///
  /// 使用场景：
  /// - 需要突出显示的输入框
  static const double inputHeightLarge = 56.0;

  /// 多行输入框最小高度 - 80px
  ///
  /// 使用场景：
  /// - **TextField** maxLines > 1 时
  /// - 文本区域
  static const double inputMinHeightMultiLine = 80.0;

  // ==================== 图标尺寸 ====================

  /// 超小图标 - 16px
  ///
  /// 使用场景：
  /// - 按钮内的小图标
  /// - 列表项前缀图标
  /// - 文本行内图标
  static const double iconSizeXSmall = 16.0;

  /// 小图标 - 20px
  ///
  /// 使用场景：
  /// - 表单标签图标
  /// - 小型装饰图标
  static const double iconSizeSmall = 20.0;

  /// 标准图标 - 24px
  ///
  /// 使用场景：
  /// - **默认图标尺寸**
  /// - 导航栏图标
  /// - 列表项图标
  /// - 按钮图标
  static const double iconSizeMedium = 24.0;

  /// 大图标 - 32px
  ///
  /// 使用场景：
  /// - 空状态图标
  /// - 功能图标
  /// - 设置页面图标
  static const double iconSizeLarge = 32.0;

  /// 超大图标 - 48px
  ///
  /// 使用场景：
  /// - 大型装饰图标
  /// - 页面中心图标
  static const double iconSizeXLarge = 48.0;

  // ==================== 头像尺寸 ====================

  /// 超小头像 - 24px
  ///
  /// 使用场景：
  /// - 消息列表中的小头像
  /// - 标签页中的头像
  static const double avatarSizeXSmall = 24.0;

  /// 小头像 - 32px
  ///
  /// 使用场景：
  /// - 群组成员头像
  /// - 评论区头像
  static const double avatarSizeSmall = 32.0;

  /// 标准头像 - 40px
  ///
  /// 使用场景：
  /// - **联系人列表头像**（默认）
  /// - 会话列表头像
  static const double avatarSizeMedium = 40.0;

  /// 大头像 - 48px
  ///
  /// 使用场景：
  /// - 聊天页面头像
  /// - 个人中心头像
  static const double avatarSizeLarge = 48.0;

  /// 超大头像 - 64px
  ///
  /// 使用场景：
  /// - 个人信息页面头像
  /// - 设置页面头像
  static const double avatarSizeXLarge = 64.0;

  /// 特大头像 - 80px
  ///
  /// 使用场景：
  /// - 用户资料页头像
  static const double avatarSizeXXLarge = 80.0;

  // ==================== 列表项尺寸 ====================

  /// 列表项高度 - 小 - 48px
  ///
  /// 使用场景：
  /// - 紧凑列表项
  static const double listItemHeightSmall = 48.0;

  /// 列表项高度 - 标准 - 56px
  ///
  /// 使用场景：
  /// - **标准列表项**（ListTile）
  /// - 设置项
  static const double listItemHeightMedium = 56.0;

  /// 列表项高度 - 大 - 72px
  ///
  /// 使用场景：
  /// - **会话列表项**（ConversationItem）
  /// - 大型列表项
  static const double listItemHeightLarge = 72.0;

  /// 列表项高度 - 超大 - 88px
  ///
  /// 使用场景：
  /// - 包含多行内容的列表项
  static const double listItemHeightXLarge = 88.0;

  // ==================== 卡片尺寸 ====================

  /// 小卡片最小高度 - 80px
  ///
  /// 使用场景：
  /// - 小型信息卡片
  static const double cardMinHeightSmall = 80.0;

  /// 标准卡片最小高度 - 120px
  ///
  /// 使用场景：
  /// - 标准信息卡片
  static const double cardMinHeightMedium = 120.0;

  /// 大卡片最小高度 - 160px
  ///
  /// 使用场景：
  /// - 大型内容卡片
  static const double cardMinHeightLarge = 160.0;

  // ==================== 导航栏尺寸 ====================

  /// 顶部导航栏高度 - 56px
  ///
  /// 使用场景：
  /// - **AppBar** 标准高度
  /// - 页面标题栏
  static const double appBarHeight = 56.0;

  /// 底部导航栏高度 - 56px
  ///
  /// 使用场景：
  /// - **BottomNavigationBar** 高度
  /// - 底部标签栏
  static const double bottomNavHeight = 56.0;

  /// 选项卡高度 - 48px
  ///
  /// 使用场景：
  /// - **TabBar** 高度
  static const double tabBarHeight = 48.0;

  // ==================== 对话框尺寸 ====================

  /// 对话框最大宽度 - 560px
  ///
  /// 使用场景：
  /// - **Dialog**、**AlertDialog** 最大宽度
  static const double dialogMaxWidth = 560.0;

  /// 小对话框宽度 - 280px
  ///
  /// 使用场景：
  /// - 确认对话框
  static const double dialogWidthSmall = 280.0;

  /// 标准对话框宽度 - 320px
  ///
  /// 使用场景：
  /// - 标准对话框
  static const double dialogWidthMedium = 320.0;

  /// 底部菜单最大高度 - 屏幕高度的 50%
  ///
  /// 使用场景：
  /// - **BottomSheet** 最大高度
  static const double bottomSheetMaxHeightFactor = 0.5;

  /// 侧边抽屉宽度 - 304px
  ///
  /// 使用场景：
  /// - **Drawer** 标准宽度
  static const double drawerWidth = 304.0;

  // ==================== 间距组件尺寸 ====================

  /// 分割线高度 - 1px
  ///
  /// 使用场景：
  /// - **Divider** 高度
  static const double dividerThickness = 1.0;

  /// 垂直分割线宽度 - 1px
  ///
  /// 使用场景：
  /// - **VerticalDivider** 宽度
  static const double dividerThicknessVertical = 1.0;

  /// 进度条高度 - 4px
  ///
  /// 使用场景：
  /// - **LinearProgressIndicator** 高度
  static const double progressBarHeight = 4.0;

  /// 滑块高度 - 32px
  ///
  /// 使用场景：
  /// - **Slider** 触摸区域高度
  static const double sliderHeight = 32.0;

  /// 开关宽度 - 48px
  ///
  /// 使用场景：
  /// - **Switch** 宽度
  static const double switchWidth = 48.0;

  /// 开关高度 - 28px
  ///
  /// 使用场景：
  /// - **Switch** 高度
  static const double switchHeight = 28.0;

  // ==================== 聊天组件尺寸 ====================

  /// 聊天消息最大宽度 - 屏幕宽度的 75%
  ///
  /// 使用场景：
  /// - 消息气泡最大宽度
  static const double messageBubbleMaxWidthFactor = 0.75;

  /// 聊天消息最大宽度 - 280px
  ///
  /// 使用场景：
  /// - 消息气泡绝对最大宽度
  static const double messageBubbleMaxWidth = 280.0;

  /// 语音消息最小宽度 - 80px
  ///
  /// 使用场景：
  /// - 语音消息气泡
  static const double voiceMessageMinWidth = 80.0;

  // ==================== 图片尺寸 ====================

  /// 缩略图尺寸 - 48px
  ///
  /// 使用场景：
  /// - 图片缩略图
  static const double thumbnailSize = 48.0;

  /// 小图片尺寸 - 80px
  ///
  /// 使用场景：
  /// - 小型图片预览
  static const double imageSizeSmall = 80.0;

  /// 中图片尺寸 - 120px
  ///
  /// 使用场景：
  /// - 中型图片预览
  static const double imageSizeMedium = 120.0;

  /// 大图片尺寸 - 200px
  ///
  /// 使用场景：
  /// - 大型图片预览
  static const double imageSizeLarge = 200.0;

  // ==================== 辅助方法 ====================

  /// 根据屏幕宽度计算响应式尺寸
  ///
  /// [context] BuildContext
  /// [small] 小屏幕尺寸
  /// [medium] 中等屏幕尺寸
  /// [large] 大屏幕尺寸
  static double responsive(
    BuildContext context, {
    required double small,
    double? medium,
    double? large,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width < AppBreakpoints.mobile) {
      return small;
    } else if (width < AppBreakpoints.wide) {
      return medium ?? small * 1.2;
    } else {
      return large ?? small * 1.4;
    }
  }

  /// 创建自定义尺寸的 SizedBox
  ///
  /// [width] 宽度
  /// [height] 高度
  static SizedBox box({double? width, double? height}) {
    return SizedBox(width: width, height: height);
  }

  /// 创建正方形容器
  ///
  /// [size] 边长
  static SizedBox square(double size) {
    return SizedBox(width: size, height: size);
  }
}
