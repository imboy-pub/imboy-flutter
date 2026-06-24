# 页面层 (Page Layer) 文档

[根目录](../../CLAUDE.md) > [lib](../) > **page**

页面层（`lib/page/`）是应用 UI 层，负责展示视图和处理用户交互，全面采用 Riverpod 架构。

---

## 模块列表

| 模块 | 职责 | 关键文件 |
|-----|------|---------|
| `chat/` | 聊天页面 | `chat/chat_page.dart`, `chat/chat_provider.dart` |
| `contact/` | 联系人管理 | `contact/contact_page.dart`, `contact/people_info_page.dart` |
| `group/` | 群组管理 | `group/group_list_page.dart`, `group/group_detail_page.dart` |
| `mine/` | 个人中心 | `mine/mine_page.dart`, `mine/setting_page.dart` |
| `conversation/` | 会话列表 | `conversation/conversation_page.dart` |
| `passport/` | 登录注册 | `passport/login_page.dart`, `passport/welcome_page.dart`, `passport/signup_continue_page.dart` |
| `personal_info/` | 个人信息编辑 | `personal_info/profile_page.dart` |
| `user_tag/` | 用户标签管理 | `user_tag/contact_tag_list_page.dart` |
| `bottom_navigation/` | 底部导航 | `bottom_navigation_page.dart` |
| `search/` | 搜索 | `search/search_chat_page.dart`, `search/web_search_page.dart` |
| `scanner/` | 二维码扫描 | `scanner/scanner_page.dart` |
| `moment/` | 朋友圈 | `moment/moment_feed_page.dart`, `moment/moment_notify/` |
| `channel/` | 频道 | `channel/channel_list_page.dart`, `channel/channel_detail_page.dart` |
| `live_room/` | 直播间 | `live_room/publisher_page.dart`, `live_room/subscriber_page.dart` |
| `single/` | 单页面组件 | `single/markdown.dart`, `single/video_viewer.dart` |

---

## Riverpod 架构规范

### 文件命名规范

```
lib/page/<feature>/
├── <feature>_page.dart         # UI 视图（ConsumerWidget / ConsumerStatefulWidget）
├── <feature>_provider.dart     # Riverpod Provider + Notifier
└── <feature>_state.dart        # 状态定义（可选，复杂状态时用）
```

### Provider 类型选择

| 类型 | 用途 |
|------|------|
| `NotifierProvider` | 可变状态管理（推荐首选） |
| `FutureProvider` | 一次性异步数据获取 |
| `StreamProvider` | 流式数据监听 |
| `Provider` | 不可变依赖注入 |

### 最小模板

```dart
// page
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProvider);
    return Scaffold(body: Text(state.data));
  }
}

// notifier
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() => MyState.initial();
  Future<void> load() async { /* ... */ }
}
final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);
```

---

## 路由配置

| 文件 | 职责 |
|------|------|
| `lib/config/routes.dart` | 路由常量定义（`AppRoutes.*`） |
| `lib/config/router/app_router.dart` | go_router 配置 + 认证守卫 |
| `lib/config/router/barrel/pages_barrel.dart` | 页面导出 barrel |

**认证守卫**：未登录自动重定向到登录页；免登页：初始页、登录页、注册页、忘记密码。

```dart
// 跳转
context.go(AppRoutes.mine);
context.push('/chat/$peerId');
```

**首页判断**：
```dart
home: UserRepoLocal.to.currentUid.isNotEmpty
    ? BottomNavigationPage()   // 已登录
    : const WelcomePage();     // 未登录
```

---

## 常用服务引用

```dart
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/theme/theme_manager.dart';

// 获取当前用户
UserRepoLocal.to.currentUid
UserRepoLocal.to.currentUser

// Toast
AppLoading.showToast('提示信息');
AppLoading.showSuccess('操作成功');

// 刷新 Provider
ref.read(myProvider.notifier).refresh();
```

---

## 已知修复记录（勿回退）

| 文件 | 问题 | 修复 |
|------|------|------|
| `passport/signup_continue_page.dart` | SnackBar 弹出屏幕外断言失败 | 使用 `ScaffoldMessenger.of(context)` + `SnackBarBehavior.fixed`，添加 `context.mounted` 检查 |
| `passport/signup_continue_page.dart` | RenderFlex 溢出 48px | 移除 `MainAxisAlignment.center`，底部加 `SizedBox(height: 80)` |

---

## 核心页面文件索引

| 文件 | 说明 |
|------|------|
| `lib/page/bottom_navigation/bottom_navigation_page.dart` | 主框架底部导航 |
| `lib/page/conversation/conversation_page.dart` | 会话列表 |
| `lib/page/chat/chat/chat_page.dart` | 聊天主页面 |
| `lib/page/contact/contact/contact_page.dart` | 联系人列表 |
| `lib/page/mine/mine/mine_page.dart` | 个人中心 |
| `lib/page/passport/welcome_page.dart` | 欢迎页（未登录首页） |

---

**相关文档**：[组件层](../component/CLAUDE.md) | [服务层](../service/CLAUDE.md) | [数据层](../store/CLAUDE.md)
