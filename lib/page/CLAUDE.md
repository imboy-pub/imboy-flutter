# 页面层 (Page Layer) 文档

[根目录](../../CLAUDE.md) > [lib](../) > **page**

> 最后更新：2026-01-05 14:12:27 CST

---

## 变更记录 (Changelog)

### 2026-01-05
- 初始化页面层文档
- 完成模块结构分析

---

## 模块职责

页面层（`lib/page/`）是应用的用户界面层，负责展示 UI 和处理用户交互。所有页面遵循 GetX 的 MVVM 架构模式。

### 核心职责
- 页面视图渲染（View）
- 用户交互处理（Logic）
- 页面状态管理（State）
- 依赖注入和生命周期管理（Binding）

---

## 模块结构

### 主要模块列表

| 模块 | 职责描述 | 关键文件 |
|-----|---------|---------|
| `chat/` | 聊天相关页面 | `chat/chat_view.dart`, `chat/chat_setting_view.dart` |
| `contact/` | 联系人管理 | `contact/contact_view.dart`, `contact/people_info_view.dart` |
| `group/` | 群组管理 | `group/group_list_view.dart`, `group/group_detail_view.dart` |
| `mine/` | 个人中心 | `mine/mine_view.dart`, `mine/setting_view.dart` |
| `conversation/` | 会话列表 | `conversation/conversation_view.dart` |
| `passport/` | 登录注册 | `passport/login_view.dart`, `passport/welcome_view.dart` |
| `personal_info/` | 个人信息编辑 | `personal_info/profile_view.dart` |
| `user_tag/` | 用户标签管理 | `user_tag/contact_tag_list_view.dart` |
| `bottom_navigation/` | 底部导航 | `bottom_navigation_view.dart` |
| `search/` | 搜索功能 | `search/search_chat_view.dart` |
| `scanner/` | 二维码扫描 | `scanner/scanner_view.dart` |
| `qrcode/` | 二维码生成 | `qrcode/qrcode_view.dart` |
| `single/` | 单页面组件 | `single/markdown.dart`, `single/video_viewer.dart` |
| `live_room/` | 直播间 | `live_room/publisher_view.dart`, `live_room/subscriber_view.dart` |

---

## GetX 架构模式

每个功能模块遵循 GetX 的标准四层架构：

### 文件命名规范
```
<module>_<name>/
├── <name>_view.dart      # 视图层
├── <name>_logic.dart     # 业务逻辑层
├── <name>_state.dart     # 状态管理层
└── <name>_binding.dart   # 依赖注入层（可选）
```

### 示例：聊天页面
```
lib/page/chat/chat/
├── chat_view.dart       # UI 视图
├── chat_logic.dart      # 业务逻辑
├── chat_state.dart      # 状态定义
└── chat_binding.dart    # 依赖注入
```

---

## 入口与启动

### 应用入口
- **主入口**：`lib/main.dart`
- **运行入口**：`lib/run.dart` - `IMBoyApp` 组件

### 路由配置
- **路由定义**：`lib/config/routes.dart` - `AppRoutes`
- **页面注册**：`lib/page/pages.dart` - `AppPages.routes`
- **路由守卫**：`lib/middleware/router_auth.dart` - `RouteAuthMiddleware`

### 首页判断
```dart
// lib/run.dart
home: UserRepoLocal.to.currentUid.isNotEmpty
    ? BottomNavigationPage()  // 已登录 - 底部导航
    : const WelcomePage(),     // 未登录 - 欢迎页
```

---

## 对外接口

### 主要页面路由

```dart
// 免登陆页面
AppRoutes.initial        // 欢迎页
AppRoutes.signIn         // 登录页

// 需要登录的页面
AppRoutes.mine           // 个人中心
AppRoutes.contact        // 联系人列表
AppRoutes.conversation   // 会话列表
AppRoutes.groupAnnouncement  // 群组公告
AppRoutes.chatSetting    // 聊天设置
```

### 页面跳转示例
```dart
// GetX 路由跳转
Get.toNamed(AppRoutes.mine);
Get.to(() => ContactPage(), binding: ContactBinding());
Get.offAll(() => BottomNavigationPage());
```

---

## 关键依赖与配置

### 依赖的模块
- `lib/component/` - UI 组件和工具
- `lib/service/` - 业务服务
- `lib/store/` - 数据层
- `lib/theme/` - 主题系统

### 核心服务依赖
```dart
// 常用服务
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/theme_manager.dart';
```

---

## 数据模型

### 常用数据模型
```dart
// 从 lib/store/model/ 导入
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/user_model.dart';
```

---

## 测试与质量

### 测试策略
- 页面组件测试：`test/widget_test.dart`
- 业务逻辑测试：`test/` 目录下的单元测试

### 质量检查
- 遵循 Flutter 代码规范
- 使用 `flutter_lints` 进行静态检查
- 建议使用格式化工具：`dart format .`

---

## 页面开发指南

### 创建新页面

1. **创建目录结构**
```bash
lib/page/my_feature/
├── my_feature_view.dart
├── my_feature_logic.dart
├── my_feature_state.dart
└── my_feature_binding.dart
```

2. **View 层示例**
```dart
class MyFeatureView extends GetView<MyFeatureLogic> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MyFeature')),
      body: Obx(() => Text(controller.state.data.value)),
    );
  }
}
```

3. **Logic 层示例**
```dart
class MyFeatureLogic extends GetxController {
  final MyFeatureState state = MyFeatureState();

  @override
  void onInit() {
    super.onInit();
    // 初始化逻辑
  }
}
```

4. **State 层示例**
```dart
class MyFeatureState {
  final RxString data = ''.obs;
}
```

5. **Binding 层示例**
```dart
class MyFeatureBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MyFeatureLogic());
  }
}
```

6. **注册路由**
```dart
// lib/page/pages.dart
GetPage(
  name: '/my_feature',
  page: () => MyFeatureView(),
  binding: MyFeatureBinding(),
),
```

---

## 常见问题 (FAQ)

### Q: 如何获取当前用户信息？
A: 使用 `UserRepoLocal.to.currentUid` 和 `UserRepoLocal.to.currentUser`。

### Q: 如何显示 Toast 提示？
A: 使用 `FlutterEasyLoading`：
```dart
EasyLoading.showToast('提示信息');
EasyLoading.showSuccess('操作成功');
```

### Q: 如何跳转到聊天页面？
A: 使用 `ChatLogic`：
```dart
Get.toNamed('/chat', arguments: {'conversationUk3': uk3});
```

### Q: 如何刷新列表数据？
A: 在 Logic 中调用更新方法：
```dart
state.data.refresh();
```

---

## 相关文件清单

### 路由和导航
- `lib/config/routes.dart` - 路由常量定义
- `lib/page/pages.dart` - 页面注册
- `lib/middleware/router_auth.dart` - 路由守卫

### 核心页面
- `lib/page/bottom_navigation/bottom_navigation_view.dart` - 底部导航
- `lib/page/conversation/conversation_view.dart` - 会话列表
- `lib/page/chat/chat/chat_view.dart` - 聊天页面
- `lib/page/contact/contact/contact_view.dart` - 联系人列表
- `lib/page/mine/mine/mine_view.dart` - 个人中心

### 登录注册
- `lib/page/passport/welcome_view.dart` - 欢迎页
- `lib/page/passport/login_view.dart` - 登录页
- `lib/page/passport/signup_view.dart` - 注册页

---

**相关文档**
- [组件层文档](../component/CLAUDE.md)
- [服务层文档](../service/CLAUDE.md)
- [数据层文档](../store/CLAUDE.md)
