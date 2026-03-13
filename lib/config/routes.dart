// ✅ 路由常量定义
// 此文件仅保留路由路径常量，路由配置已迁移到 go_router
// 完整路由配置请查看 lib/config/router/app_router.dart

/// 应用路由常量
///
/// 定义所有路由的路径常量，用于程序化导航
/// 路由配置和守卫已迁移到 go_router
class AppRoutes {
  // ==================== 根路径 ====================
  /// 应用初始路径（启动页）
  static const initial = '/';

  // ==================== 认证相关 ====================
  /// 登录页
  static const signIn = '/sign_in';

  /// 注册页
  static const signUp = '/sign_up';

  /// 忘记密码页
  static const forgotPassword = '/forgot_password';

  // ==================== 主功能页 ====================
  /// 个人中心
  static const mine = '/mine';

  /// 联系人列表
  static const contact = '/contact';

  /// 联系人详情（已废弃，使用 /contact/people/:id）
  @Deprecated('Use /contact/people/:id instead')
  static const contactDetail = '/contact_detail';

  /// 会话列表
  static const conversation = "/conversation";

  /// 朋友圈流
  static const momentFeed = '/moment/feed';

  /// 朋友圈发布
  static const momentCreate = '/moment/create';

  /// 朋友圈动态详情根路径（拼接 `/$momentId`）
  static const momentRoot = '/moment';

  /// 群组公告
  static const groupAnnouncement = '/group/announcement';

  /// 聊天设置
  static const chatSetting = '/chat/setting';

  // ==================== Single 页面 ====================
  /// Markdown 查看器
  static const markdown = '/markdown';

  /// 视频播放器
  static const videoViewer = '/video_viewer';

  /// 应用升级页
  static const upgrade = '/upgrade';

  /// 网络失败引导页
  static const networkFailureGuidance = '/network_failure_guidance';

  // ==================== 群功能增强 ====================
  /// 群分组
  static const groupCategory = '/group/category';

  /// 群标签
  static const groupTag = '/group/:groupId/tag';

  /// 群投票
  static const groupVote = '/group/:groupId/vote';

  /// 群日程
  static const groupSchedule = '/group/:groupId/schedule';

  /// 群作业
  static const groupTask = '/group/:groupId/task';

  // ==================== @提及 ====================
  /// @提及列表
  static const mentionList = '/mention';
}
