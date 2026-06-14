# 组件层 (Component Layer) 文档

[根目录](../../CLAUDE.md) > [lib](../) > **component**

组件层（`lib/component/`）提供可复用 UI 组件、工具类和辅助功能，是应用基础设施层。

---

## 子模块总览

| 子模块 | 职责 | 关键文件 |
|-------|------|---------|
| `ui/` | 通用 UI 组件 | `avatar.dart`, `button.dart`, `common_bar.dart`, `gesture_page_route.dart` |
| `chat/` | 聊天消息组件 | `message.dart`, `message_*_builder.dart` |
| `helper/` | 辅助工具函数 | `func.dart`, `datetime.dart`, `string.dart`, `permission.dart`, `picker_method.dart` |
| `http/` | 网络请求封装 | `http_client.dart`, `http_interceptor.dart`, `http_response.dart` |
| `video/` | 视频处理 | `video_compress_manager.dart`, `video_thumbnail.dart` |
| `webrtc/` | WebRTC 通话 | `session.dart`, `func.dart` |
| `extension/` | 扩展方法 | `device_ext.dart`, `imboy_cache_manager.dart` |
| `voice_record/` | 语音录制 | `voice_widget.dart` |
| `image_gallery/` | 图片浏览 | `image_gallery.dart` |
| `location/` | 位置服务 | `amap_helper.dart` |
| `observer/` | 生命周期监听 | `lifecycle.dart` |

---

## UI 组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `Avatar` | `ui/avatar.dart` | 头像，内置授权，勿直接用裸 URL |
| `ButtonWidget` | `ui/button.dart` | 统一按钮 |
| `CommonBar` | `ui/common_bar.dart` | 通用导航栏 |
| `SearchField` | `ui/search_field.dart` | 搜索框 |
| `Password` | `ui/password.dart` | 密码输入 |
| `ContactCard` | `ui/contact_card.dart` | 联系人卡片 |
| `GesturePageRoute` | `ui/gesture_page_route.dart` | iOS 风格滑动返回路由 |

路由跳转推荐：`CupertinoPageRoute` 或 `RouteHelper.pushWithGesture(context, builder)`。

---

## 聊天组件

| Builder | 文件 | 触发条件 |
|---------|------|---------|
| `MessageImageBuilder` | `message_image_multi_builder.dart` | msgType == 'image' |
| `MessageAudioBuilder` | `message_audio_builder.dart` | msgType == 'audio' |
| `MessageQuoteBuilder` | `message_quote_builder.dart` | msgType == 'quote' |
| `MessageRevokedBuilder` | `message_revoked_builder.dart` | msgType == 'revoke' |
| `MessageLocationBuilder` | `message_location_builder.dart` | msgType == 'location' |
| `MessageVisitCardBuilder` | `message_visit_card_builder.dart` | msgType == 'visit_card' |
| `MessageWebRTCBuilder` | `message_webrtc_builder.dart` | msgType == 'webrtc' |
| `MessageUnsupportedBuilder` | `message_unsupported_builder.dart` | 兜底 |

---

## 辅助工具 (`helper/`)

| 函数/类 | 文件 | 作用 |
|--------|------|------|
| `cachedImageProvider(url, w)` | `func.dart` | 内置 `AssetsService.viewUrl`，返回 ImageProvider |
| `dynamicAvatar(url)` | `func.dart` | 头像 BoxDecoration，调用 `cachedImageProvider` |
| `iPrint` / `ePrint` | `func.dart` | 信息/错误日志 |
| `generateUUID()` | `func.dart` | 生成 UUID |
| `strEmpty` / `strNoEmpty` | `string.dart` | 字符串空判断 |
| `hiddenPhone(phone)` | `string.dart` | 隐藏手机号中间四位 |
| `isPhone(phone)` | `string.dart` | 手机号格式校验 |
| `DateTimeHelper.parseTimestamp` | `datetime.dart` | 解析时间戳 |
| `requestCameraPermission()` | `permission.dart` | 请求相机权限 |
| `pickImages(maxSize)` | `picker_method.dart` | 选择图片（最多 N 张） |
| `pickVideo()` | `picker_method.dart` | 选择视频 |

---

## 网络组件 (`http/`)

```dart
final response = await HttpClient.client.get('/api/users');
final response = await HttpClient.client.post('/api/login', data: {...});
if (response.ok) { print(response.payload); }
```

拦截器自动处理：Token 注入 / 错误处理 / 日志记录。

---

## 关键依赖

| 包 | 用途 |
|----|------|
| `flutter_screenutil` | 屏幕适配 |
| `flutter_easyloading` | Loading/Toast 提示 |
| `cached_network_image` | 图片缓存（勿直接用，走 `cachedImageProvider`） |
| `image_picker` / `wechat_assets_picker` | 图片/资源选择 |
| `video_compress` | 视频压缩 |

内部依赖链：`lib/service/` → `lib/store/` → `lib/theme/`

---

**相关文档**：[页面层](../page/CLAUDE.md) | [服务层](../service/CLAUDE.md) | [主题系统](../theme/CLAUDE.md)
