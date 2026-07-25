<!-- Generated: 2026-06-18 | Files scanned: 368 (pages) + 111 (components) | Token estimate: ~900 -->

# 前端架构 | Frontend Architecture

**最后更新 / Last Updated:** 2026-06-18 CST

---

## 页面树 | Page Tree (22 modules, 368 files)

```
page/                   368 files (+55 from 2026-04-17)
├── mine/               50  个人空间、设备、钱包、收藏
│   ├── mine_page.dart                  主页面（4 Tab 切换）
│   ├── device_list_page.dart           已登设备列表
│   ├── device_detail_page.dart         设备详情与登出
│   ├── favorite_list_page.dart         收藏列表与管理
│   ├── wallet_page.dart                账户余额、交易记录
│   ├── setting_page.dart               应用设置
│   ├── profile_view.dart               个人资料展示
│   └── [其他 42 个文件] ─── 认证、账户、品牌
│
├── group/              55  群组 CRUD、成员、设置、相册
│   ├── group_list_page.dart            群组列表
│   ├── create_group_page.dart          创建群组
│   ├── group_detail_page.dart          群详情（名称、公告、规则）
│   ├── group_member_list_page.dart     成员列表（含禁言操作）
│   ├── group_member_detail_page.dart   成员详情（角色、权限）
│   ├── group_album_page.dart           群相册浏览
│   ├── group_album_detail_page.dart    相册详情（发布、删除）
│   ├── group_edit_page.dart            群设置编辑
│   ├── group_notice_page.dart          群公告管理
│   ├── group_role_page.dart            角色权限配置
│   └── [其他 44 个文件] ─── 分享、邀请、转移
│
├── chat/               53  C2C/C2G 消息、聊天体验
│   ├── chat_page.dart                  主聊天界面 (8 个 Mixin)
│   │   └── mixin/
│   │       ├── chat_initialization_handler.dart    初始化、数据加载
│   │       ├── chat_message_handler.dart           消息发送/接收
│   │       ├── chat_scroll_handler.dart            滚动、分页、跳转
│   │       ├── chat_input_handler.dart             输入框、@提及、语音
│   │       ├── chat_reaction_handler.dart          消息反应（emoji）
│   │       ├── chat_selection_handler.dart         多选、转发、撤销
│   │       ├── chat_media_handler.dart             图片/视频/文件上传
│   │       └── chat_webrtc_handler.dart            语音/视频通话
│   ├── chat_provider.dart              Riverpod 状态管理
│   ├── message_bubble.dart             消息气泡渲染
│   ├── message_input_field.dart        输入框组件
│   ├── message_reaction_widget.dart    反应展示
│   └── [其他 41 个文件] ─── 类型渲染、预览、转发
│
├── contact/            30  好友列表、申请、标签
│   ├── contact_list_page.dart          好友列表
│   ├── friend_request_page.dart        申请处理（待审、已批准）
│   ├── add_friend_page.dart            添加好友（搜索、ID、二维码）
│   ├── user_profile_page.dart          用户资料展示
│   ├── block_list_page.dart            黑名单管理
│   ├── tag_management_page.dart        标签管理
│   └── [其他 24 个文件] ─── 搜索、推荐、分享
│
├── personal_info/      22  个人编辑、头像、认证
│   ├── personal_info_page.dart         个人信息编辑
│   ├── avatar_edit_page.dart           头像裁剪、上传
│   ├── nickname_edit_page.dart         昵称编辑（字数限制）
│   ├── status_edit_page.dart           个性签名编辑
│   ├── authentication_page.dart        身份认证（RealName）
│   └── [其他 17 个文件] ─── 生日、地区、职位
│
├── passport/           27  登录、注册、生物识别
│   ├── login_page.dart                 用户名/手机登录
│   ├── register_page.dart              注册（邮箱/手机）
│   ├── password_reset_page.dart        忘记密码
│   ├── password_reset_verify_page.dart 验证码确认
│   ├── new_password_page.dart          新密码设置
│   ├── biometric_auth_page.dart        生物识别注册
│   ├── sso_login_page.dart             SSO 第三方登录
│   └── [其他 20 个文件] ─── 验证、极光认证、OTP
│
├── channel/            18  频道浏览、订阅、推荐
│   ├── channel_list_page.dart          频道列表
│   ├── channel_detail_page.dart        频道内容浏览
│   ├── channel_message_page.dart       频道消息流
│   ├── channel_subscribe_page.dart     订阅管理
│   ├── channel_recommendation_page.dart 推荐频道
│   └── [其他 13 个文件] ─── 搜索、分享、举报
│
├── settings/           13  应用设置、E2EE、隐私
│   ├── settings_page.dart              设置首页
│   ├── e2ee_settings_page.dart         E2EE 加密设置
│   ├── privacy_settings_page.dart      隐私控制（@、位置）
│   ├── notification_settings_page.dart 通知设置（静音、优先级）
│   ├── appearance_settings_page.dart   外观设置（暗黑模式、字号）
│   └── [其他 8 个文件] ─── 通知、缓存、关于
│
├── user_tag/           14  标签与分类、关键词
│   ├── tag_list_page.dart              标签列表
│   ├── tag_create_page.dart            新建标签
│   ├── tag_edit_page.dart              编辑标签
│   ├── tag_assign_page.dart            给用户分配标签
│   └── [其他 10 个文件] ─── 搜索、推荐、同步
│
├── web_shell/          16  网页容器、H5 加载
│   ├── web_shell_page.dart             WebView 容器
│   ├── web_shell_provider.dart         WebView 状态管理
│   ├── js_bridge.dart                  JS↔Dart 通信桥接
│   └── [其他 13 个文件] ─── 加载、注入、安全
│
├── search/              8  全局搜索、索引、过滤
│   ├── search_page.dart                搜索界面
│   ├── search_provider.dart            搜索 Provider
│   ├── search_history_widget.dart      搜索历史
│   └── [其他 5 个文件] ─── 过滤、排序、保存
│
├── scanner/            10  二维码、NFC 扫描
│   ├── scanner_page.dart               二维码扫描界面
│   ├── scanner_provider.dart           扫描状态管理
│   ├── qr_code_content_page.dart       扫描结果页
│   └── [其他 7 个文件] ─── NFC、内容解析
│
├── moment/             11  社交动态、朋友圈、评论
│   ├── moment_list_page.dart           动态列表（信息流）
│   ├── moment_detail_page.dart         动态详情
│   ├── moment_create_page.dart         发布动态（文字、图片、视频）
│   ├── moment_like_list_page.dart      点赞列表
│   ├── moment_comment_list_page.dart   评论列表
│   └── [其他 6 个文件] ─── 分享、删除、举报
│
├── live_room/           8  直播、流媒体、实时互动
│   ├── live_room_page.dart             直播房间
│   ├── live_stream_provider.dart       直播流 Provider
│   ├── live_controls_widget.dart       直播控制条
│   └── [其他 5 个文件] ─── 评论、打赏、分享
│
├── qrcode/              6  二维码展示、分享、导入
│   ├── qr_code_page.dart               二维码展示页
│   ├── qr_code_share_page.dart         分享二维码
│   └── [其他 4 个文件] ─── 导入、编辑、保存
│
├── wallet/              6  支付、充值、交易记录
│   ├── wallet_page.dart                钱包首页
│   ├── recharge_page.dart              充值页面
│   ├── transaction_list_page.dart      交易记录
│   └── [其他 3 个文件] ─── 提现、设置、统计
│
├── single/              6  独立屏幕、弹窗、模态
│   ├── single_image_viewer_page.dart   图片全屏查看
│   ├── single_video_viewer_page.dart   视频播放器
│   └── [其他 4 个文件] ─── 文件、位置、音频
│
├── conversation/        9  会话列表、快捷操作
│   ├── conversation_list_page.dart     会话列表主页
│   ├── conversation_provider.dart      会话 Provider
│   ├── conversation_sort_menu.dart     排序菜单（时间/未读）
│   └── [其他 6 个文件] ─── 搜索、筛选、置顶
│
├── bottom_navigation/   3  底部 4-Tab 导航
│   ├── bottom_navigation_bar.dart      导航栏
│   ├── bottom_navigation_provider.dart Tab 状态管理
│   └── [其他 1 个文件] ─── Badge 显示
│
└── [其他模块]          11  文件
    ├── welcome/        1  欢迎页
    ├── splash/         1  启动屏（品牌、进度）
    ├── discover/       1  探索广场
    └── mention/        1  @mention 提及列表
```

---

## 组件层次 | Component Hierarchy (111 files)

```
component/                111 files
├── ui/                  28  基础 UI 原件（Material 3 兼容）
│   ├── button.dart          按钮（Primary / Secondary / Text / Icon）
│   ├── card.dart            卡片（阴影、圆角、padding）
│   ├── dialog.dart          对话框（确认/输入/选择）
│   ├── avatar.dart          头像（用户/群组，支持 Placeholder）
│   ├── badge.dart           徽章（通知红点、数字）
│   ├── chip.dart            Chip（标签、可删除）
│   ├── dropdown.dart        下拉菜单
│   ├── switch.dart          开关
│   ├── slider.dart          滑杆
│   ├── progress.dart        进度条（线性、圆形）
│   ├── tab_bar.dart         标签栏（顶部 / 底部）
│   ├── text_field.dart      文本输入（带校验）
│   ├── search_bar.dart      搜索栏
│   ├── list_tile.dart       列表项（图标、标题、副标题）
│   ├── divider.dart         分割线
│   ├── snackbar.dart        顶部/底部提示
│   ├── toast.dart           浮窗提示
│   ├── loading.dart         加载动画（微调进度）
│   ├── empty_state.dart     空状态（图片、文案、操作）
│   └── [其他 10 个文件] ─── 选择器、时间、颜色
│
├── chat/                23  聊天特定组件
│   ├── message_bubble.dart           消息气泡（发送/接收）
│   ├── message_input_field.dart      输入框（多行、@提及、emoji）
│   ├── message_reaction_widget.dart  反应展示与编辑
│   ├── message_builder.dart          消息类型构建器
│   ├── text_message_widget.dart      文本消息渲染
│   ├── image_message_widget.dart     图片消息渲染
│   ├── video_message_widget.dart     视频消息渲染
│   ├── file_message_widget.dart      文件消息渲染
│   ├── voice_message_widget.dart     语音消息渲染
│   ├── location_message_widget.dart  位置消息渲染
│   ├── card_message_widget.dart      卡片消息渲染
│   ├── system_message_widget.dart    系统消息渲染
│   ├── mention_popup.dart            @提及浮窗
│   ├── forward_sheet.dart            转发菜单（单选、多选）
│   ├── reply_widget.dart             引用回复显示
│   └── [其他 8 个文件] ─── 长按菜单、时间戳、已读
│
├── webrtc/              20  WebRTC 通话 UI
│   ├── call_page.dart                通话界面（视频/语音）
│   ├── call_provider.dart            通话状态 Provider
│   ├── call_controls_widget.dart     通话控制条（静音、切换摄像头）
│   ├── video_renderer_widget.dart    视频渲染
│   ├── audio_waveform_widget.dart    音频波形
│   ├── call_info_widget.dart         通话信息展示
│   ├── call_duration_widget.dart     通话时长计时
│   ├── call_incoming_widget.dart     来电提示（头像、名称）
│   ├── call_quality_indicator.dart   网络质量指示
│   └── [其他 11 个文件] ─── 信令、群通话、录制
│
├── helper/              15  工具函数与提供者
│   ├── image_picker_helper.dart      图片选择（单选/多选）
│   ├── file_picker_helper.dart       文件选择
│   ├── date_time_helper.dart         日期格式化
│   ├── validation_helper.dart        输入校验（邮箱、手机、URL）
│   ├── cached_image_provider.dart    缓存图片提供（已授权 URL）
│   ├── image_cache_manager.dart      自定义缓存管理
│   ├── platform_helper.dart          平台差异处理（iOS/Android）
│   ├── permissions_helper.dart       权限申请（位置、相机、麦克风）
│   ├── app_links_helper.dart         深链接处理
│   └── [其他 6 个文件] ─── 剪贴板、计时、数据转换
│
├── http/                 8  HTTP/WebSocket 客户端层
│   ├── dio_client.dart               Dio 封装（超时、重试）
│   ├── request_interceptor.dart      请求拦截器（token 注入）
│   ├── response_interceptor.dart     响应拦截器（错误转换）
│   ├── error_handler.dart            错误处理（网络/业务/解析）
│   ├── retry_policy.dart             重试策略（指数退避）
│   └── [其他 3 个文件] ─── 缓存、代理、日志
│
├── extension/            4  Dart 扩展
│   ├── string_extension.dart         String（去空格、截断、加密）
│   ├── build_context_extension.dart  BuildContext（媒体查询、路由）
│   ├── list_extension.dart           List（分组、扁平化、排序）
│   └── [其他 1 个文件] ─── DateTime、数值扩展
│
├── location/             3  地理定位与地图
│   ├── amap_service.dart             高德地图集成
│   ├── location_picker_page.dart     位置选择器
│   └── [其他 1 个文件] ─── 地址反查
│
├── voice_record/         2  音频录制
│   ├── voice_recorder.dart           录音机逻辑
│   └── [其他 1 个文件] ─── 播放、波形
│
├── image_gallery/        2  相册与媒体
│   ├── gallery_picker_page.dart      相册选择
│   └── [其他 1 个文件] ─── 滤镜、编辑
│
├── widget/               2  Widget 辅助
│   ├── if_widget.dart                条件渲染
│   └── [其他 1 个文件] ─── 循环、错误边界
│
├── locales/              1  本地化
│   └── locale_switcher.dart          语言切换器
│
└── video/                1  视频播放
    └── video_player_widget.dart      视频播放器封装
```

---

## ChatPage Mixin 分层架构 | ChatPage Mixin Architecture

```
ChatPage extends ConsumerStatefulWidget
├── Mixin 1: ChatInitializationHandler
│   ├── initState()        初始化 WebSocket、加载历史消息
│   ├── loadHistoryMessages()  分页加载（向上滚动触发）
│   └── setupProviderListeners() 监听 Riverpod 状态变化
│
├── Mixin 2: ChatMessageHandler
│   ├── handleIncomingMessage()  处理 S2C 消息
│   ├── sendMessage()       发送消息（包装、加密、重试）
│   ├── resendMessage()     重发失败消息
│   └── markAsRead()        标记已读 ACK
│
├── Mixin 3: ChatScrollHandler
│   ├── onScroll()          滚动事件处理（加载更多）
│   ├── scrollToBottom()    跳转到底部新消息
│   ├── scrollToMessage()   跳转到指定消息
│   └── updateReadPosition() 更新阅读位置（用于分页查询）
│
├── Mixin 4: ChatInputHandler
│   ├── onInputChanged()    输入框变化（正在输入提示）
│   ├── handleMentions()    @提及弹窗逻辑
│   ├── insertMention()     插入 @用户
│   ├── recordVoice()       语音录制
│   └── cancelVoice()       取消语音
│
├── Mixin 5: ChatReactionHandler
│   ├── showReactionPicker() emoji 选择器
│   ├── addReaction()        添加反应
│   ├── removeReaction()     删除反应
│   └── updateReactionUI()   更新 UI
│
├── Mixin 6: ChatSelectionHandler
│   ├── toggleSelectMode()   进入多选模式
│   ├── selectMessage()      选中消息（高亮）
│   ├── handleForward()      转发消息
│   ├── handleDelete()       删除消息
│   └── handleRevoke()       撤销消息（时间限制）
│
├── Mixin 7: ChatMediaHandler
│   ├── pickImage()          选择图片
│   ├── pickVideo()          选择视频
│   ├── pickFile()           选择文件
│   ├── pickLocation()       选择位置
│   └── compressMedia()      压缩媒体（图片/视频）
│
└── Mixin 8: ChatWebRTCHandler
    ├── initiateCalls()      发起语音/视频通话
    ├── handleIncomingCall() 处理来电
    ├── rejectCall()         拒绝通话
    └── endCall()            结束通话
```

**特点：**
- ✅ 行为分离，各 Mixin 职责单一
- ✅ 易于单元测试（提取纯逻辑）
- ✅ 易于维护（修改不影响其他 Mixin）
- ✅ 支持扩展（添加新 Mixin 无需修改现有代码）

---

## 状态管理流 | State Management Flow

```
ConsumerWidget / ConsumerStatefulWidget
  ↓
ref.watch(chatMessagesProvider)       ← 读取消息列表
ref.read(chatNotifier.notifier)       ← 触发发送消息
  ↓
ChatNotifier.build()                  ← 返回 AsyncValue<List<Message>>
  ↓
message_provider.dart                 ← 监听消息变化
  ├── watchMessages(convKey)          从 Repository 查询
  ├── sendMessage(model)              调用 API + SQLite 持久化
  └── updateMessage(id, status)       更新状态
  ↓
Repository (SQLite)                   ← 数据持久化
  ↓
Service (WebSocket, 加密, 通知)        ← 业务逻辑
  ↓
Widget 重建 / UI Rebuild               ← 显示新数据
```

---

## 关键 Provider/Notifier 伪代码 | Provider Pseudocode

```dart
// lib/page/chat/chat_provider.dart
final chatMessagesProvider = StateNotifierProvider.family<
  ChatNotifier,
  AsyncValue<List<MessageModel>>,
  String  // convKey
>((ref, convKey) {
  final repo = ref.watch(messageRepositoryProvider);
  return ChatNotifier(repo, convKey);
});

class ChatNotifier extends StateNotifier<AsyncValue<List<MessageModel>>> {
  ChatNotifier(this._repo, this._convKey) : super(const AsyncValue.loading());

  Future<void> sendMessage(CreateMessageRequest req) async {
    // 1. 乐观更新 UI
    // 2. 调用 API
    // 3. 更新 SQLite
    // 4. 处理错误回滚
  }

  Future<void> loadMore() async {
    // 1. 分页加载历史消息
    // 2. 去重（检查 msg_id）
    // 3. 更新状态
  }
}

// lib/page/mine/mine_provider.dart
final userProfileProvider = FutureProvider<UserModel>((ref) async {
  final api = ref.watch(userApiProvider);
  return api.getUserProfile();
});

// lib/service/websocket_provider.dart
final webSocketProvider = StateProvider<WebSocketService>((ref) {
  return WebSocketService();
});
```

---

## 路由导航 | Routing with go_router

```dart
// lib/config/router_config.dart
final routerConfig = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
      routes: [
        // 认证路由
        GoRoute(
          path: 'passport/login',
          builder: (context, state) => const LoginPage(),
        ),
        // 主导航（4-Tab）
        GoRoute(
          path: 'conversation',
          builder: (context, state) => const ConversationListPage(),
          routes: [
            GoRoute(
              path: 'chat/:convKey',
              builder: (context, state) => ChatPage(
                convKey: state.pathParameters['convKey']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'contact',
          builder: (context, state) => const ContactListPage(),
        ),
        GoRoute(
          path: 'group',
          builder: (context, state) => const GroupListPage(),
        ),
        GoRoute(
          path: 'mine',
          builder: (context, state) => const MinePage(),
        ),
      ],
    ),
  ],
);
```

---

## 设计令牌 | Design Tokens (from lib/theme/)

```dart
// lib/theme/app_colors.dart
abstract final class AppColors {
  static const Color primary = Color(0xFF2474E5);     // 品牌蓝
  static const Color iosBlue = Color(0xFF007AFF);     // iOS 链接色
  static const Color iosRed = Color(0xFFFF3B30);      // 破坏性操作
  static const Color surface = Color(0xFFF5F5F5);     // 背景
  static const Color onSurface = Color(0xFF000000);   // 文本
  // ... 更多色彩
}

// lib/theme/app_spacing.dart
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

// lib/theme/font_size_type.dart
enum FontSizeType {
  bodySmall(12),
  body(14),
  bodyLarge(16),
  titleSmall(16),
  titleMedium(18),
  titleLarge(24),
  headlineSmall(28),
  headlineMedium(32),
  headlineLarge(40);
}
```

---

## 常见页面开发流程 | Common Page Development Workflow

```
1. 在 lib/config/router_config.dart 添加路由
2. 创建 lib/page/feature/feature_page.dart
3. 创建 lib/page/feature/feature_provider.dart
4. 定义 Provider（数据来源）和 Notifier（业务逻辑）
5. 使用 ConsumerWidget 绑定 Provider
6. 使用 AppColors / AppSpacing / FontSizeType Token
7. 单元测试（test/ 目录）
8. 集成测试（test_driver/ 目录）
9. 提交前运行 `dart analyze lib` + `flutter test`
```

---

**更新者 / Updated by:** Claude Code  
**更新周期 / Update Cycle:** 6 weeks (architecture), 2 weeks (minor)
