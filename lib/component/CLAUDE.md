# 组件层 (Component Layer) 文档

[根目录](../../CLAUDE.md) > [lib](../) > **component**

> 最后更新：2026-01-05 14:12:27 CST

---

## 变更记录 (Changelog)

### 2026-01-05
- 初始化组件层文档
- 完成模块结构分析

---

## 模块职责

组件层（`lib/component/`）提供可复用的 UI 组件、工具类和辅助功能，是应用的基础设施层。

### 核心职责
- 通用 UI 组件封装
- 聊天相关组件
- 网络请求封装
- 辅助工具函数
- 扩展方法集合

---

## 模块结构

### 主要子模块

| 子模块 | 职责描述 | 关键文件 |
|-------|---------|---------|
| `ui/` | 通用 UI 组件 | `avatar.dart`, `button.dart`, `common_bar.dart` |
| `chat/` | 聊天相关组件 | `message.dart`, `message_location_builder.dart` |
| `helper/` | 辅助工具函数 | `func.dart`, `datetime.dart`, `string.dart` |
| `http/` | 网络请求封装 | `http_client.dart`, `http_interceptor.dart` |
| `video/` | 视频处理 | `video_compress_manager.dart`, `video_thumbnail.dart` |
| `location/` | 位置服务 | `amap_helper.dart` |
| `webrtc/` | WebRTC 通讯 | `session.dart`, `func.dart` |
| `observer/` | 生命周期监听 | `lifecycle.dart` |
| `extension/` | 扩展方法 | `device_ext.dart`, `imboy_cache_manager.dart` |
| `voice_record/` | 语音录制 | `voice_widget.dart` |
| `image_gallery/` | 图片浏览 | `image_gallery.dart` |

---

## 入口与启动

### 组件导入方式
```dart
// UI 组件
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';

// 聊天组件
import 'package:imboy/component/chat/message.dart';

// 辅助工具
import 'package:imboy/component/helper/func.dart';

// 网络请求
import 'package:imboy/component/http/http_client.dart';
```

---

## 对外接口

### UI 组件

#### Avatar 组件
```dart
Avatar(
  avatarUrl: 'https://example.com/avatar.jpg',
  size: 48,
)
```

#### Button 组件
```dart
ButtonWidget(
  text: '点击我',
  onPressed: () => print('Clicked'),
)
```

#### CommonBar 组件
```dart
CommonBar(
  title: '标题',
  actions: [
    IconButton(icon: Icon(Icons.more_horiz), onPressed: () {}),
  ],
)
```

#### GesturePageRoute（手势返回路由）
**新增组件** - 提供统一的 iOS 风格滑动返回体验

```dart
import 'package:imboy/component/ui/gesture_page_route.dart';

// 使用便捷函数（推荐）
await RouteHelper.pushWithGesture(
  context: context,
  builder: (context) => MyPage(),
);

// 或直接使用 CupertinoPageRoute
Navigator.push(
  context,
  CupertinoPageRoute(builder: (context) => MyPage()),
);
```

**详细文档**: [README.md#uiux-minimal-rules](../../README.md#uiux-minimal-rules)

### 聊天组件

#### Message Builder
```dart
// 图片消息
MessageImageBuilder(message: message)

// 视频消息
MessageVideoBuilder(message: message)

// 音频消息
MessageAudioBuilder(message: message)

// 引用消息
MessageQuoteBuilder(message: message)

// 撤回消息
MessageRevokedBuilder(message: message)
```

### 辅助工具

#### 字符串工具
```dart
import 'package:imboy/component/helper/string.dart';

strEmpty(str)        // 判断字符串是否为空
strNoEmpty(str)      // 判断字符串是否非空
hiddenPhone(phone)   // 隐藏手机号中间四位
isPhone(phone)       // 验证手机号格式
```

#### 日期时间工具
```dart
import 'package:imboy/component/helper/datetime.dart';

DateTimeHelper.parseTimestamp(timestamp)  // 解析时间戳
DateTimeHelper.formatDuration(seconds)    // 格式化时长
```

---

## 关键依赖与配置

### 外部依赖
- `flutter_screenutil` - 屏幕适配
- `flutter_easyloading` - Loading 提示
- `cached_network_image` - 图片缓存
- `image_picker` - 图片选择
- `wechat_assets_picker` - 资源选择器
- `video_compress` - 视频压缩

### 内部依赖
- `lib/service/` - 服务层
- `lib/store/` - 数据层
- `lib/theme/` - 主题系统

---

## 数据模型

组件层主要使用以下数据模型：
```dart
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
```

---

## 测试与质量

### 组件测试
- 建议为每个复杂组件编写 Widget 测试
- 使用 `test/` 目录下的测试文件

### 质量标准
- 遵循 Flutter 组件设计规范
- 组件应支持主题定制
- 组件应支持无障碍访问

---

## 通用 UI 组件

### Avatar（头像组件）
```dart
Avatar(
  avatarUrl: user.avatar,
  size: 48,
  name: user.nickname,
)
```

### ImageButton（图片按钮）
```dart
ImageButton(
  image: AssetImage('assets/icon.png'),
  onPressed: () {},
)
```

### SearchField（搜索框）
```dart
SearchField(
  hintText: '搜索',
  onChanged: (value) => print(value),
)
```

### EasyDialog（对话框）
```dart
EasyDialog.show(
  title: '提示',
  content: '确定要删除吗？',
  onConfirm: () => print('Confirmed'),
)
```

### Password（密码输入）
```dart
Password(
  onSubmitted: (password) => print(password),
)
```

### ContactCard（联系人卡片）
```dart
ContactCard(
  contact: contactModel,
  onTap: () => print('Tapped'),
)
```

---

## 聊天组件

### Message 类型枚举
```dart
enum MessageType {
  text,       // 文本消息
  image,      // 图片消息
  video,      // 视频消息
  audio,      // 音频消息
  file,       // 文件消息
  location,   // 位置消息
  custom,     // 自定义消息
  quote,      // 引用消息
  webrtc,     // WebRTC 消息
  revoke,     // 撤回消息
}
```

### Message Builder 使用
```dart
Widget buildMessage(MessageModel message) {
  switch (message.msgType) {
    case 'image':
      return MessageImageBuilder(message: message);
    case 'video':
      return MessageVideoBuilder(message: message);
    case 'audio':
      return MessageAudioBuilder(message: message);
    case 'quote':
      return MessageQuoteBuilder(message: message);
    default:
      return MessageTextBuilder(message: message);
  }
}
```

---

## 网络组件

### HTTP 客户端
```dart
import 'package:imboy/component/http/http_client.dart';

// GET 请求
final response = await HttpClient.client.get('/api/users');

// POST 请求
final response = await HttpClient.client.post('/api/login', data: {
  'username': 'user',
  'password': 'pass',
});

// 响应处理
if (response.ok) {
  print(response.payload);
}
```

### 拦截器
- 自动添加 Token
- 自动处理错误
- 日志记录

---

## 辅助工具

### Func 常用函数
```dart
import 'package:imboy/component/helper/func.dart';

// 系统语言
sysLang('jiffy')  // 获取 Jiffy 语言代码

// 日志输出
iPrint('Info');   // 信息日志
ePrint('Error');  // 错误日志

// UUID 生成
generateUUID()    // 生成唯一标识符
```

### Permission 权限工具
```dart
import 'package:imboy/component/helper/permission.dart';

// 请求相机权限
await requestCameraPermission();

// 请求存储权限
await requestStoragePermission();

// 请求麦克风权限
await requestMicrophonePermission();
```

### PickerMethod 选择器工具
```dart
import 'package:imboy/component/helper/picker_method.dart';

// 选择图片
final images = await pickImages(maxSize: 9);

// 选择视频
final video = await pickVideo();

// 选择文件
final file = await pickFile();
```

---

## WebRTC 组件

### Session 管理
```dart
import 'package:imboy/component/webrtc/session.dart';

WebRTCSession session = WebRTCSession(
  localUserId: 'user1',
  remoteUserId: 'user2',
);

// 发起通话
await session.startCall();

// 结束通话
await session.endCall();
```

---

## 常见问题 (FAQ)

### Q: 如何创建新的 UI 组件？
A: 在 `lib/component/ui/` 下创建新的组件文件，遵循现有组件的命名和结构规范。

### Q: 如何使用消息组件？
A: 根据消息类型选择对应的 Builder，传入 `MessageModel` 对象即可。

### Q: 如何自定义主题？
A: 使用 `ThemeManager` 获取当前主题颜色，确保组件支持主题切换。

### Q: 如何处理网络错误？
A: `HttpClient` 已内置错误处理，通过 `response.ok` 判断请求是否成功。

---

## 相关文件清单

### UI 组件
- `lib/component/ui/avatar.dart` - 头像组件
- `lib/component/ui/button.dart` - 按钮组件
- `lib/component/ui/common_bar.dart` - 通用导航栏
- `lib/component/ui/search_field.dart` - 搜索框
- `lib/component/ui/password.dart` - 密码输入
- `lib/component/ui/contact_card.dart` - 联系人卡片
- `lib/component/ui/easy_dialog.dart` - 对话框
- `lib/component/ui/sound_manager.dart` - 声音管理
- `lib/component/ui/gesture_page_route.dart` - 手势返回路由（新增）

### 聊天组件
- `lib/component/chat/message.dart` - 消息主入口和 CustomMessageBuilder
- `lib/component/chat/message_audio_builder.dart` - 音频消息
- `lib/component/chat/message_image_multi_builder.dart` - 多图消息
- `lib/component/chat/message_location_builder.dart` - 位置消息
- `lib/component/chat/message_quote_builder.dart` - 引用消息
- `lib/component/chat/message_revoked_builder.dart` - 撤回消息
- `lib/component/chat/message_unsupported_builder.dart` - 不支持的消息
- `lib/component/chat/message_visit_card_builder.dart` - 名片消息
- `lib/component/chat/message_webrtc_builder.dart` - WebRTC 消息
- `lib/component/chat/enum.dart` - 消息类型枚举

### 辅助工具
- `lib/component/helper/func.dart` - 通用函数
- `lib/component/helper/string.dart` - 字符串工具
- `lib/component/helper/datetime.dart` - 时间日期工具
- `lib/component/helper/permission.dart` - 权限工具
- `lib/component/helper/picker_method.dart` - 选择器工具
- `lib/component/helper/log.dart` - 日志工具

### 网络组件
- `lib/component/http/http_client.dart` - HTTP 客户端
- `lib/component/http/http_interceptor.dart` - 请求拦截器
- `lib/component/http/http_response.dart` - 响应处理
- `lib/component/http/http_config.dart` - 配置

---

**相关文档**
- [页面层文档](../page/CLAUDE.md)
- [服务层文档](../service/CLAUDE.md)
- [主题系统文档](../theme/CLAUDE.md)
