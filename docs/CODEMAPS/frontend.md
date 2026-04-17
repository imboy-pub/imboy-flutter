<!-- Generated: 2026-04-17 | Files scanned: 313 (pages) + 113 (components) | Token estimate: ~850 -->

# 前端架构 | Frontend Architecture

**最后更新 / Last Updated:** 2026-04-17 CST

---

## 页面树 | Page Tree (22 modules, 313 files)

```
page/
├── chat/              39  C2C/C2G 消息、消息展示 (Mixin 分层架构)
│   ├── chat_page.dart                    主聊天界面 (8 个 Mixin)
│   ├── chat_provider.dart                Riverpod 状态管理
│   ├── mixin/                            行为分离 Mixin
│   │   ├── chat_initialization_handler.dart
│   │   ├── chat_message_handler.dart
│   │   ├── chat_scroll_handler.dart
│   │   ├── chat_input_handler.dart
│   │   ├── chat_reaction_handler.dart
│   │   ├── chat_selection_handler.dart
│   │   ├── chat_media_handler.dart
│   │   └── chat_webrtc_handler.dart
│   └── [其他 UI 组件]
├── mine/              50  个人资料、设置、收藏、设备
├── group/             45  群组 CRUD、成员、设置、相册
├── contact/           29  联系人列表、好友申请、标签
├── personal_info/     21  个人编辑、头像
├── passport/          15  登录、注册、认证
├── user_tag/          14  用户标签与分类
├── settings/          13  应用/E2EE 设置
├── channel/           10  频道浏览、订阅、置顶区 (新增 2026-04)
├── live_room/          8  直播流
├── search/             7  全局搜索
├── conversation/       6  会话列表、未读数合流 (更新 2026-04)
├── single/             6  独立屏幕
├── scanner/            4  二维码扫描
├── moment/             4  社交动态
├── qrcode/             3  二维码展示
├── bottom_navigation/  3  底部导航控制器 (更新至 4-Tab 2026-04)
├── wallet/             2  支付
├── discover/           1  探索广场
├── mention/            1  @mention
├── splash/             1  启动屏
└── welcome/            1  欢迎页
```

---

## 组件层次 | Component Hierarchy (113 files)

```
component/
├── ui/            28  按钮、卡片、对话框、头像、徽章 (通用 UI 原件)
├── chat/          23  消息气泡、输入框、反应、构建器 (聊天特定)
├── webrtc/        20  语音/视频通话 UI + 信令
├── helper/        15  图片、日期、验证、缓存图片提供 (工具函数)
├── http/           8  Dio 客户端、拦截器、错误处理
├── extension/      4  String、BuildContext、List 扩展
├── location/       3  高德地图集成、地理定位
├── voice_record/   2  音频录制
├── image_gallery/  2  相册/媒体选择
├── widget/         2  Widget 辅助 (if_widget, when_widget)
├── locales/        1  本地化相关组件
└── video/          1  视频播放
```

---

## 状态管理流 | State Management Flow

```
ConsumerWidget / ConsumerStatefulWidget
  → ref.watch(xxxProvider)           读取状态
  → ref.read(xxxProvider.notifier)  触发操作
  → Notifier.build() / state        返回新状态
  → Widget 重建 / Widget rebuild

关键 Provider 位置：
├── lib/page/chat/chat_provider.dart              消息列表、发送、输入框
├── lib/page/conversation/conversation_provider.dart
│   未读数、会话列表、最后消息
├── lib/page/contact/contact_provider.dart       联系人列表、搜索、标签
├── lib/page/group/group_provider.dart           群组列表、成员
├── lib/service/websocket_status_provider.dart   WebSocket 连接状态
├── lib/service/message_providers.dart           消息处理、S2C 事件
└── lib/service/notification_provider.dart       通知状态（新增 2026-04）
```

---

## 路由导航 | Navigation (go_router)

```
路由结构 / Route Structure：

/                             → BottomNavigation
├── /conversation             会话列表 (Tab 0)
├── /contact                  联系人列表 (Tab 1)
├── /channel                  频道广场 (Tab 2, 新增 2026-04)
├── /mine                     我的 (Tab 3)
│   ├── /mine/my_channels     我的频道 (新增 2026-04)
│   ├── /mine/device          设备列表
│   └── /mine/settings        应用设置
│
├── /chat/:type/:id           聊天页面
│   ├── /chat/c2c/:uid        私聊
│   └── /chat/c2g/:gid        群聊
│
├── /group/:gid               群组详情
│   ├── /group/:gid/member    群成员列表
│   ├── /group/:gid/edit      群编辑
│   └── /group/:gid/album     群相册
│
├── /contact/add              加好友页面
├── /channel/:cid             频道详情
├── /channel/admin            频道管理
├── /settings/e2ee            E2EE 设置
├── /scanner                  二维码扫描
├── /search                   全局搜索
├── /login                    登录页
├── /register                 注册页
└── /splash                   启动屏
```

---

## 聊天页 Mixin 架构 | ChatPage Mixin Architecture

**文件：** `lib/page/chat/chat/chat_page.dart`

```dart
ChatPage (StatefulWidget, 1808 行)
  ├── ChatInitializationHandler         初始化、加载、dispose
  │   ├── _initChat()                   数据加载、WebSocket 连接
  │   ├── _loadInitialMessages()        分页加载初始消息
  │   └── _setupEventListeners()        事件总线订阅
  │
  ├── ChatMessageHandler               发送/接收消息、重试、ACK
  │   ├── _sendTextMessage()            发送文本（含 @所有人 权限校验）
  │   ├── _sendMediaMessage()           发送媒体 (图片/视频/音频)
  │   ├── _retryMessage()               重试失败消息
  │   └── _applyGroupMemberMuteState()  禁言状态应用
  │
  ├── ChatScrollHandler                滚动、分页、加载更多
  │   ├── _onScrolling()                滚动检测
  │   ├── _loadMoreMessages()           向上翻页加载历史
  │   └── _jumpToLatest()               跳转至最新
  │
  ├── ChatInputHandler                输入框、文本编辑、禁言检测
  │   ├── _onTextChanged()              实时输入监听
  │   ├── _detectMentions()             提及候选 (@all / @某人)
  │   └── _checkMutedStatus()           检查群成员禁言状态
  │
  ├── ChatReactionHandler             表情反应、表情选择
  │   ├── _onReactionTap()              处理表情长按
  │   └── _showEmojiPicker()            显示表情选择器
  │
  ├── ChatSelectionHandler            多选、批量删除
  │   ├── _toggleSelection()            切换消息选中状态
  │   └── _batchDelete()                批量删除消息
  │
  ├── ChatMediaHandler                图片/视频/音频处理
  │   ├── _pickImage()                  选择图片
  │   ├── _recordVoice()                录音
  │   └── _previewMedia()               预览媒体
  │
  └── ChatWebRTCHandler               语音/视频通话信令
      ├── _initiateCall()               发起通话
      └── _handleCallSignaling()        处理信令消息

Mixin 分离好处：
✅ 单个 Mixin ≤ 300 行，职责单一
✅ 易于测试、维护、扩展
✅ 避免 2000+ 行 God Object
✅ 特性可根据需要启用/禁用
```

---

## 关键 Provider / Notifier 模式 | Key Providers

### ChatProvider

```dart
// 文件：lib/page/chat/chat/chat_provider.dart
@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  Future<ChatState> build() async {
    // 加载初始消息、会话信息、群成员（如果 c2g）
  }

  Future<void> sendMessage(MessageModel msg) async {
    // 1. 检查禁言状态 → 如禁言则 toast + return
    // 2. 调用 MessageService.send()
    // 3. 订阅 WebSocket ACK / 失败事件
    // 4. 更新本地消息列表 state
  }

  void onMessageReceived(MessageModel msg) {
    // S2C 或 WebSocket 推送的消息到达
    // 检查去重 + 插入本地 + 更新 UI
  }
}

class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final String? error;
  final bool isMuted;  // 群成员禁言状态
  final String? muteMessage;  // 禁言提示文案
  // ...
}
```

### ConversationProvider

```dart
// 文件：lib/page/conversation/conversation_provider.dart
@riverpod
class ConversationNotifier extends _$ConversationNotifier {
  @override
  Future<List<ConversationModel>> build() async {
    // 加载会话列表、未读数、最后消息
  }

  void updateConversation(String convKey, ConversationModel updated) {
    // 实时更新会话列表项（未读数、最后消息、时间）
  }
}
```

### ContactProvider

```dart
// 文件：lib/page/contact/contact_provider.dart
@riverpod
class ContactNotifier extends _$ContactNotifier {
  @override
  Future<List<ContactModel>> build() async {
    // 加载联系人列表、分类、标签
  }

  Future<void> searchContacts(String query) async {
    // 搜索、过滤、排序
  }
}
```

---

## 设计系统 | Design System

### 颜色令牌 | Color Tokens
```dart
// lib/theme/default/colors.dart
AppColors.primary       // 品牌蓝 #2474E5 (Logo, 主按钮, 发送气泡)
AppColors.iosBlue       // iOS 系统蓝 #007AFF (链接, Nav 按钮, 取消)
AppColors.surface       // 卡片背景
AppColors.iosRed        // 破坏性操作 #FF3B30
AppColors.success       // 成功状态绿
AppColors.error         // 错误红
```

### 间距令牌 | Spacing Tokens
```dart
AppSpacing.xs           // 4px
AppSpacing.sm           // 8px
AppSpacing.md           // 12px
AppSpacing.lg           // 16px (页面标准 padding)
AppSpacing.xl           // 24px
AppSpacing.xxl          // 32px
```

### 触达区域 | Touch Targets
```
所有可点击元素 ≥ 44×44pt (iOS HIG minimum)
按钮间距 ≥ 8pt
```

---

## 最近变化 | Recent Updates (Apr 2026)

| 日期 / Date | 变化 / Change | 影响 / Impact |
|-----------|---------|---------|
| 2026-04-17 | 添加 `InboundPipeline` 去重阶段 | 消息管道架构完善 |
| 2026-04-17 | 添加 `NotificationGateway` 纯函数 | 通知决策可测试化 |
| 2026-04-15 | 群成员禁言/解禁 S2C 接线 | 聊天页输入框实时禁用/恢复 |
| 2026-04-15 | 频道置顶区 UI (Slice-5) | 会话列表顶部新增频道带状 |
| 2026-04-10 | 四 Tab 导航重构 (Option C) | 消息/联系人/频道/我的 |
| 2026-04-10 | 未读数合流 (私聊+频道) | 消息 Tab Badge 统计更新 |

---

## 性能优化 | Performance Optimization

| 优化 / Optimization | 实现 / Implementation | 收益 / Benefit |
|-----------|---------|---------|
| 消息分页 | 每页 50 条 + 向上加载 | 避免加载全量消息 |
| 图片缓存 | `IMBoyCacheManager` + `cachedImageProvider` | 减少重复下载 |
| 查询缓存 | `CachedSQLiteService` | 减少 DB 查询次数 |
| Lazy loading | Provider auto-dispose + watch | 自动内存回收 |
| 虚拟列表 | 聊天气泡列表使用 `ListView` | 仅渲染可见行 |

---

**相关文档 / Related Docs**
- [`architecture.md`](./architecture.md) — 系统整体设计
- [`data.md`](./data.md) — 数据库与模型
- [`CLAUDE.md`](../../CLAUDE.md) — 项目 CLAUDE 规范
