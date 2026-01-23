# 消息类型实现执行计划

> 创建时间：2026-01-20
> 任务：实现完整的基础消息类型支持
> 目标：统一使用 flutter_chat_ui 库组件，优化现有代码，补全缺失类型

---

## 一、任务概述

### 1.1 目标
在现有代码基础上实现 15 种基础消息类型，优先使用 flutter_chat_ui 库的组件，优化清理 lib/component/chat 目录代码。

### 1.2 消息类型清单

| msg_type | Payload 示例 | 消息UI | 实现策略 |
|----------|-------------|-------------------|---------|
| `text` | `{"text": "Hello"}` | flyer_chat_text_message | 使用 flutter_chat_ui |
| `textStream` | `{"text": "Hello", "index": 0}` | flyer_chat_text_stream_message | 使用 flutter_chat_ui |
| `image` | `{"uri": "...", "size": 102400, "width": 1920, "height": 1080}` | flyer_chat_image_message | 使用 flutter_chat_ui |
| `imageMulti` | `{"images": [{"uri": "...", "width": 1920, "height": 1080}]}` | ImageMultiMessageBuilder | 新增 |
| `file` | `{"uri": "...", "name": "doc.pdf", "size": 102400}` | flyer_chat_file_message | 使用 flutter_chat_ui |
| `location` | `{"latitude": 39.9, "longitude": 116.4, "title": "..."}` | flyer_chat_location_message | 使用 flutter_chat_ui |
| `audio` | `{"uri": "...", "duration_ms": 15000}` | AudioMessageBuilder | 保留现有 |
| `video` | `{"uri": "...", "duration_ms": 60000, "thumb": {...}}` | flyer_chat_video_message | 使用 flutter_chat_ui |
| `system` | `{"text": "..."}` | flyer_chat_system_message | 使用 flutter_chat_ui |
| `quote` | `{"quote_msg_id": "msg100", "text": "回复"}` | QuoteMessageBuilder | 保留现有 |
| `revoked` | `{"original_msg_id": "msg105"}` | RevokedMessageBuilder | 保留现有 |
| `visitCard` | `{"user_id": "user123", "nickname": "张三"}` | VisitCardMessageBuilder | 保留现有 |
| `webrtcAudio` | `{"call_id": "call_123", "status": "ended", "duration": 60}` | WebRTCMessageBuilder | 保留现有（需更新以区分音频/视频） |
| `webrtcVideo` | `{"call_id": "call_456", "status": "ended", "duration": 120}` | WebRTCMessageBuilder | 保留现有（需更新以区分音频/视频） |
| `unsupported` | `{"error": "unknown_msg_type"}` | UnsupportedMessageBuilder | 新增 |

---

## 二、消息 Payload 详细设计

### 2.1 Payload 设计原则

1. **必需字段 vs 可选字段**: 明确区分，确保核心功能可用
2. **数据类型**: 严格定义数据类型（String, int, double, bool, Array, Object）
3. **命名规范**: 使用 snake_case 命名，与后端 API 保持一致
4. **扩展性**: 通过可选字段支持未来功能扩展
5. **向后兼容**: 新增字段必须为可选，不破坏旧版本

### 2.2 消息 Payload 完整设计

#### 1. text (文本消息)

**用途**: 发送纯文本消息，支持 Emoji、换行等基本文本格式

**Payload 结构**:
```json
{
  "text": "string, 必需, 消息文本内容",
  "client_send_ts": "int, 可选, 客户端发送时间戳(毫秒)",
  "mentioned_user_ids": "array, 可选, @用户ID列表",
  "entities": "array, 可选, 文本实体(链接、话题等)"
}
```

**完整示例**:
```json
{
  "text": "Hello, @张三! 今天天气不错 ☀️",
  "client_send_ts": 1642579200000,
  "mentioned_user_ids": ["user123"],
  "entities": [
    {"type": "mention", "offset": 7, "length": 3, "user_id": "user123"},
    {"type": "emoji", "offset": 22, "length": 2}
  ]
}
```

**最小示例**:
```json
{"text": "Hello"}
```

---

#### 2. textStream (文本流消息)

**用途**: 支持 AI 对话等流式文本输出场景，文本分段传输

**Payload 结构**:
```json
{
  "text": "string, 必需, 当前分片文本",
  "index": "int, 必需, 分片序号(从0开始)",
  "is_end": "bool, 可选, 是否为最后一个分片, 默认false",
  "stream_id": "string, 可选, 流ID, 用于关联同一流的所有分片",
  "total_length": "int, 可选, 完整文本总长度(字符数)"
}
```

**完整示例**:
```json
{
  "text": "人工",
  "index": 0,
  "is_end": false,
  "stream_id": "stream_abc123",
  "total_length": 12
}
```

**流式输出示例** (3个分片):
```json
// 分片 1
{"text": "人工", "index": 0, "is_end": false, "stream_id": "stream_001"}
// 分片 2
{"text": "智能", "index": 1, "is_end": false, "stream_id": "stream_001"}
// 分片 3
{"text": "助手", "index": 2, "is_end": true, "stream_id": "stream_001"}
```

---

#### 3. image (图片消息)

**用途**: 发送单张图片

**Payload 结构**:
```json
{
  "uri": "string, 必需, 图片URL(CDN地址)",
  "size": "int, 必需, 文件大小(字节)",
  "width": "int, 可选, 图片宽度(像素)",
  "height": "int, 可选, 图片高度(像素)",
  "thumb": "object, 可选, 缩略图信息",
  "thumbhash": "string, 可选, 缩略图哈希(用于渐进式加载)",
  "format": "string, 可选, 图片格式(jpg, png, webp, gif)",
  "name": "string, 可选, 原始文件名"
}
```

**thumb 子结构**:
```json
{
  "uri": "string, 缩略图URL",
  "width": "int, 缩略图宽度",
  "height": "int, 缩略图高度"
}
```

**完整示例**:
```json
{
  "uri": "https://cdn.imboy.pub/images/msg_abc123.jpg",
  "size": 524288,
  "width": 1920,
  "height": 1080,
  "format": "jpg",
  "name": "photo_20250120.jpg",
  "thumb": {
    "uri": "https://cdn.imboy.pub/thumbs/msg_abc123_240.jpg",
    "width": 240,
    "height": 135
  },
  "thumbhash": "UoSCQAAMDw9FhAeH1glH1keHDxHh"
}
```

**最小示例**:
```json
{
  "uri": "https://cdn.imboy.pub/images/msg_abc123.jpg",
  "size": 524288
}
```

---

#### 4. imageMulti (多图消息)

**用途**: 一次发送多张图片（最多9张）

**Payload 结构**:
```json
{
  "images": "array, 必需, 图片数组",
  "total": "int, 可选, 总数"
}
```

**images 数组项结构** (与单张图片相同):
```json
{
  "uri": "string, 必需, 图片URL",
  "size": "int, 必需, 文件大小",
  "width": "int, 可选, 宽度",
  "height": "int, 可选, 高度"
}
```

**完整示例** (3张图片):
```json
{
  "images": [
    {
      "uri": "https://cdn.imboy.pub/images/img1.jpg",
      "size": 327680,
      "width": 1920,
      "height": 1080
    },
    {
      "uri": "https://cdn.imboy.pub/images/img2.jpg",
      "size": 456789,
      "width": 1080,
      "height": 1920
    },
    {
      "uri": "https://cdn.imboy.pub/images/img3.jpg",
      "size": 512000,
      "width": 1280,
      "height": 720
    }
  ],
  "total": 3
}
```

**UI 展示**: 3x3 网格布局，点击可预览大图

---

#### 5. file (文件消息)

**用途**: 发送任意类型文件（PDF、Word、Excel 等）

**Payload 结构**:
```json
{
  "uri": "string, 必需, 文件下载URL",
  "name": "string, 必需, 文件名",
  "size": "int, 必需, 文件大小(字节)",
  "mime_type": "string, 可选, MIME类型",
  "extension": "string, 可选, 文件扩展名",
  "thumbnail": "string, 可选, 文件预览图URL(仅特定格式)"
}
```

**完整示例** (PDF 文件):
```json
{
  "uri": "https://cdn.imboy.pub/files/report_2025.pdf",
  "name": "2025年度报告.pdf",
  "size": 2097152,
  "mime_type": "application/pdf",
  "extension": "pdf",
  "thumbnail": "https://cdn.imboy.pub/thumbs/report_2025_preview.jpg"
}
```

**常见 MIME 类型**:
- PDF: `application/pdf`
- Word: `application/msword` / `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
- Excel: `application/vnd.ms-excel` / `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- 压缩包: `application/zip`, `application/x-rar-compressed`

---

#### 6. location (位置消息)

**用途**: 分享地理位置信息

**Payload 结构**:
```json
{
  "latitude": "double, 必需, 纬度",
  "longitude": "double, 必需, 经度",
  "title": "string, 必需, 位置标题",
  "address": "string, 可选, 详细地址",
  "poi_id": "string, 可选, 兴趣点ID",
  "poi_name": "string, 可选, 兴趣点名称",
  "static_map_url": "string, 可选, 静态地图图片URL"
}
```

**完整示例**:
```json
{
  "latitude": 39.9042,
  "longitude": 116.4074,
  "title": "北京市朝阳区建国路88号",
  "address": "朝阳区建国路88号SOHO现代城",
  "poi_id": "B000A85BD6",
  "poi_name": "SOHO现代城",
  "static_map_url": "https://cdn.imboy.pub/maps/static_loc_abc123.png"
}
```

**坐标范围**:
- 纬度: -90 ~ 90
- 经度: -180 ~ 180

---

#### 7. audio (语音消息)

**用途**: 发送语音录音

**Payload 结构**:
```json
{
  "uri": "string, 必需, 音频文件URL",
  "duration_ms": "int, 必需, 音频时长(毫秒)",
  "format": "string, 可选, 音频格式(aac, mp3, m4a)",
  "size": "int, 可选, 文件大小(字节)",
  "waveform": "array, 可选, 波形数据(用于可视化)",
  "played": "bool, 可选, 是否已播放, 默认false"
}
```

**waveform 数组结构**:
```json
[0.3, 0.5, 0.8, 0.6, 0.4, ...]  // 0.0~1.0 的浮点数数组
```

**完整示例**:
```json
{
  "uri": "https://cdn.imboy.pub/audio/voice_msg_aac123.aac",
  "duration_ms": 15300,
  "format": "aac",
  "size": 48256,
  "waveform": [0.2, 0.4, 0.7, 0.5, 0.3, 0.6, 0.8, 0.4, 0.2, 0.1],
  "played": false
}
```

**时长限制**:
- 最短: 1000ms (1秒)
- 最长: 60000ms (60秒)

---

#### 8. video (视频消息)

**用途**: 发送视频文件

**Payload 结构**:
```json
{
  "uri": "string, 必需, 视频文件URL",
  "duration_ms": "int, 必需, 视频时长(毫秒)",
  "thumb": "object, 可选, 视频封面图",
  "size": "int, 可选, 文件大小(字节)",
  "width": "int, 可选, 视频宽度",
  "height": "int, 可选, 视频高度",
  "format": "string, 可选, 视频格式(mp4, mov)"
}
```

**thumb 子结构**:
```json
{
  "uri": "string, 封面图URL",
  "width": "int, 封面宽度",
  "height": "int, 封面高度"
}
```

**完整示例**:
```json
{
  "uri": "https://cdn.imboy.pub/videos/video_msg_mp4123.mp4",
  "duration_ms": 32000,
  "size": 5242880,
  "width": 1920,
  "height": 1080,
  "format": "mp4",
  "thumb": {
    "uri": "https://cdn.imboy.pub/thumbs/video_msg_mp4123.jpg",
    "width": 320,
    "height": 180
  }
}
```

---

#### 9. system (系统消息)

**用途**: 系统通知、提示信息

**Payload 结构**:
```json
{
  "text": "string, 必需, 系统消息文本",
  "type": "string, 可选, 子类型(info, warning, error, success)",
  "action_url": "string, 可选, 点击跳转URL",
  "action_text": "string, 可选, 操作按钮文本"
}
```

**完整示例**:
```json
{
  "text": "您已添加 李四 为好友",
  "type": "info",
  "action_url": "imboy://contact/user123",
  "action_text": "查看资料"
}
```

**常见子类型**:
- `info`: 普通信息（蓝色）
- `warning`: 警告（橙色）
- `error`: 错误（红色）
- `success`: 成功（绿色）

---

#### 10. quote (引用消息)

**用途**: 回复/引用某条消息

**Payload 结构**:
```json
{
  "quote_msg_id": "string, 必需, 被引用消息ID",
  "quote_text": "string, 必需, 被引用消息文本(预览)",
  "text": "string, 必需, 回复内容",
  "quote_msg_type": "string, 可选, 被引用消息类型",
  "quote_author_id": "string, 可选, 被引用消息作者ID",
  "quote_author_name": "string, 可选, 被引用消息作者昵称"
}
```

**完整示例**:
```json
{
  "quote_msg_id": "msg_abc123",
  "quote_text": "明天下午开会吗？",
  "text": "好的，下午3点见",
  "quote_msg_type": "text",
  "quote_author_id": "user456",
  "quote_author_name": "张三"
}
```

**UI 展示**:
- 上方显示引用内容（灰色背景，左侧竖线）
- 下方显示回复内容

---

#### 11. revoked (撤回消息)

**用途**: 消息撤回提示

**Payload 结构**:
```json
{
  "original_msg_id": "string, 必需, 被撤回消息ID",
  "original_msg_type": "string, 可选, 原始消息类型",
  "revoker_id": "string, 可选, 撤回者用户ID",
  "revoker_name": "string, 可选, 撤回者昵称",
  "revoke_time": "int, 可选, 撤回时间戳(毫秒)"
}
```

**完整示例**:
```json
{
  "original_msg_id": "msg_def456",
  "original_msg_type": "text",
  "revoker_id": "user789",
  "revoker_name": "李四",
  "revoke_time": 1642579260000
}
```

**UI 展示**:
- 自己撤回: "你撤回了一条消息"
- 对方撤回: "对方撤回了一条消息"

---

#### 12. visitCard (个人名片)

**用途**: 分享联系人名片

**Payload 结构**:
```json
{
  "user_id": "string, 必需, 用户ID",
  "nickname": "string, 必需, 用户昵称",
  "avatar": "string, 可选, 用户头像URL",
  "region": "string, 可选, 用户地区",
  "sign": "string, 可选, 用户签名",
  "description": "string, 可选, 附加描述"
}
```

**完整示例**:
```json
{
  "user_id": "user999",
  "nickname": "王五",
  "avatar": "https://cdn.imboy.pub/avatars/user999.jpg",
  "region": "北京市",
  "sign": "热爱生活，热爱编程",
  "description": "推荐添加"
}
```

---

#### 13. webrtcAudio (音频通话)

**用途**: WebRTC 音频通话邀请/记录

**Payload 结构**:
```json
{
  "call_id": "string, 必需, 通话会话ID",
  "status": "string, 必需, 通话状态",
  "duration": "int, 可选, 通话时长(秒)",
  "caller_id": "string, 可选, 发起者ID",
  "caller_name": "string, 可选, 发起者昵称",
  "start_time": "int, 可选, 开始时间戳",
  "end_time": "int, 可选, 结束时间戳",
  "end_reason": "string, 可选, 结束原因"
}
```

**status 枚举值**:
- `calling`: 呼叫中
- `connected`: 已接通
- `ended`: 已结束
- `rejected`: 已拒绝
- `missed`: 未接
- `cancelled`: 已取消

**完整示例** (已接通):
```json
{
  "call_id": "call_audio_001",
  "status": "ended",
  "duration": 185,
  "caller_id": "user111",
  "caller_name": "赵六",
  "start_time": 1642579200000,
  "end_time": 1642579385000,
  "end_reason": "normal"
}
```

**完整示例** (未接):
```json
{
  "call_id": "call_audio_002",
  "status": "missed",
  "caller_id": "user222",
  "caller_name": "钱七",
  "start_time": 1642579200000,
  "end_time": 1642579260000,
  "end_reason": "timeout"
}
```

---

#### 14. webrtcVideo (视频通话)

**用途**: WebRTC 视频通话邀请/记录

**Payload 结构** (与音频通话相同):
```json
{
  "call_id": "string, 必需, 通话会话ID",
  "status": "string, 必需, 通话状态",
  "duration": "int, 可选, 通话时长(秒)",
  "caller_id": "string, 可选, 发起者ID",
  "caller_name": "string, 可选, 发起者昵称",
  "start_time": "int, 可选, 开始时间戳",
  "end_time": "int, 可选, 结束时间戳",
  "end_reason": "string, 可选, 结束原因"
}
```

**完整示例**:
```json
{
  "call_id": "call_video_003",
  "status": "ended",
  "duration": 420,
  "caller_id": "user333",
  "caller_name": "孙八",
  "start_time": 1642579000000,
  "end_time": 1642579420000,
  "end_reason": "normal"
}
```

---

#### 15. unsupported (不支持的消息类型)

**用途**: 客户端无法识别或处理的消息类型

**Payload 结构**:
```json
{
  "error": "string, 可选, 错误类型",
  "original_type": "string, 可选, 原始消息类型",
  "original_payload": "object, 可选, 原始payload内容",
  "fallback_text": "string, 可选, 降级显示文本"
}
```

**完整示例**:
```json
{
  "error": "unknown_msg_type",
  "original_type": "future_msg_type_xyz",
  "original_payload": {"some_field": "some_value"},
  "fallback_text": "收到一条不支持的消息，请升级客户端查看"
}
```

**UI 展示**:
- 显示友好的提示信息
- 可在调试模式下显示原始数据

---

### 2.3 Payload 字段类型汇总表

| 字段名 | 类型 | 说明 | 示例值 |
|-------|------|------|--------|
| `text` | string | 文本内容 | "Hello World" |
| `uri` | string | 资源URL | "https://cdn.imboy.pub/..." |
| `url` | string | 资源URL (同uri) | "https://..." |
| `size` | int | 文件大小(字节) | 102400 |
| `width` | int | 宽度(像素) | 1920 |
| `height` | int | 高度(像素) | 1080 |
| `duration` | int | 时长(秒) | 60 |
| `duration_ms` | int | 时长(毫秒) | 60000 |
| `latitude` | double | 纬度 | 39.9042 |
| `longitude` | double | 经度 | 116.4074 |
| `name` | string | 文件名 | "report.pdf" |
| `nickname` | string | 用户昵称 | "张三" |
| `user_id` | string | 用户ID | "user123" |
| `msg_id` | string | 消息ID | "msg_abc123" |
| `call_id` | string | 通话ID | "call_001" |
| `status` | string | 状态枚举 | "ended" |
| `mime_type` | string | MIME类型 | "application/pdf" |
| `thumbhash` | string | 缩略图哈希 | "UoSCQAAMDw9F..." |
| `format` | string | 格式 | "jpg", "aac", "mp4" |
| `index` | int | 序号 | 0, 1, 2... |
| `is_end` | bool | 是否结束 | true/false |
| `played` | bool | 是否已播放 | true/false |
| `images` | array | 图片数组 | [...] |
| `waveform` | array | 波形数据 | [0.3, 0.5, ...] |
| `entities` | array | 文本实体 | [...] |

---

### 2.4 消息类型与 flutter_chat_ui 组件映射

| msg_type | Payload 主类型 | flutter_chat_ui 组件 | 现有 Builder |
|----------|--------------|---------------------|--------------|
| `text` | TextMessage | FlyerChatTextMessage | - |
| `textStream` | TextMessage + metadata | FlyerChatTextStreamMessage | - |
| `image` | ImageMessage | FlyerChatImageMessage | MessageImageBuilder |
| `imageMulti` | CustomMessage + images[] | - | ImageMultiMessageBuilder (新增) |
| `file` | FileMessage | FlyerChatFileMessage | - |
| `location` | CustomMessage | FlyerChatLocationMessage | LocationMessageBuilder |
| `audio` | CustomMessage | FlyerChatAudioMessage | AudioMessageBuilder (保留) |
| `video` | CustomMessage | FlyerChatVideoMessage | VideoMessageBuilder |
| `system` | CustomMessage | FlyerChatSystemMessage | - |
| `quote` | CustomMessage | - | QuoteMessageBuilder (保留) |
| `revoked` | CustomMessage | - | RevokedMessageBuilder (保留) |
| `visitCard` | CustomMessage | - | VisitCardMessageBuilder (保留) |
| `webrtcAudio` | CustomMessage | - | WebRTCMessageBuilder (保留) |
| `webrtcVideo` | CustomMessage | - | WebRTCMessageBuilder (保留) |
| `unsupported` | CustomMessage | - | UnsupportedMessageBuilder (新增) |

---

## 三、代码分析总结

### 3.1 现有实现状态

| 文件 | 状态 | 说明 |
|------|------|------|
| `lib/component/chat/enum.dart` | ✅ 已有 | CustomMessageType 枚举定义 |
| `lib/component/chat/message.dart` | ✅ 已有 | CustomMessageBuilder 主入口 |
| `lib/component/chat/message_audio_builder.dart` | ✅ 已有 | 音频消息（功能完善，保留） |
| `lib/component/chat/message_image_builder.dart` | ⚠️ 待替换 | 可替换为 flyer_chat_image_message |
| `lib/component/chat/message_video_builder.dart` | ⚠️ 待替换 | 可替换为 flyer_chat_video_message |
| `lib/component/chat/message_location_builder.dart` | ⚠️ 待替换 | 可替换为 flyer_chat_location_message |
| `lib/component/chat/message_quote_builder.dart` | ✅ 保留 | 引用消息（保留现有实现） |
| `lib/component/chat/message_revoked_builder.dart` | ✅ 保留 | 撤回消息（保留现有实现） |
| `lib/component/chat/message_visit_card_builder.dart` | ✅ 保留 | 名片消息（保留现有实现） |
| `lib/component/chat/message_webrtc_builder.dart` | ✅ 保留 | WebRTC消息（保留现有实现） |
| `lib/service/message_type_constants.dart` | ✅ 已有 | 消息类型常量定义 |

### 3.2 flutter_chat_ui 可用组件

| 组件包名 | 文件位置 | 用途 |
|---------|---------|------|
| `flyer_chat_text_message` | plugin/flutter_chat_ui/packages/flyer_chat_text_message | 文本消息 |
| `flyer_chat_text_stream_message` | plugin/flutter_chat_ui/packages/flyer_chat_text_stream_message | 文本流消息 |
| `flyer_chat_image_message` | plugin/flutter_chat_ui/packages/flyer_chat_image_message | 图片消息 |
| `flyer_chat_video_message` | plugin/flutter_chat_ui/packages/flyer_chat_video_message | 视频消息 |
| `flyer_chat_file_message` | plugin/flutter_chat_ui/packages/flyer_chat_file_message | 文件消息 |
| `flyer_chat_audio_message` | plugin/flutter_chat_ui/packages/flyer_chat_audio_message | 音频消息 |
| `flyer_chat_location_message` | plugin/flutter_chat_ui/packages/flyer_chat_location_message | 位置消息 |
| `flyer_chat_system_message` | plugin/flutter_chat_ui/packages/flyer_chat_system_message | 系统消息 |
| `flyer_chat_custom_message` | plugin/flutter_chat_ui/packages/flyer_chat_custom_message | 自定义消息 |

---

## 四、详细执行步骤

### 阶段 1：准备工作（Step 1-3）

#### Step 1: 更新消息类型常量定义
**文件**: `lib/service/message_type_constants.dart`

**操作**:
- 添加 `textStream` 消息类型常量
- 添加 `imageMulti` 消息类型常量
- 确保 `MessageType` 类包含所有基础类型

**预期结果**:
```dart
abstract class MessageType {
  static const String text = 'text';
  static const String textStream = 'textStream';  // 新增
  static const String image = 'image';
  static const String imageMulti = 'imageMulti';  // 新增
  static const String file = 'file';
  static const String location = 'location';
  static const String audio = 'audio';
  static const String video = 'video';
  static const String system = 'system';
  static const String quote = 'quote';
  static const String revoked = 'revoked';
  static const String visitCard = 'visitCard';
  static const String webrtcAudio = 'webrtcAudio';
  static const String webrtcVideo = 'webrtcVideo';
  static const String unsupported = 'unsupported';  // 新增
}
```

---

#### Step 2: 更新 CustomMessageType 枚举
**文件**: `lib/component/chat/enum.dart`

**操作**:
- 添加 `imageMulti` 枚举值
- 添加 `unsupported` 枚举值
- 移除未使用的枚举值（如有）

**预期结果**:
```dart
enum CustomMessageType {
  text,
  textStream,   // 新增
  image,
  imageMulti,   // 新增
  file,
  location,
  audio,
  video,
  unsupported,  // 新增
  system,
  custom,
  webrtcAudio,
  webrtcVideo,
  quote,
}
```

---

#### Step 3: 更新 MessageModel.toTypeMessage() 转换逻辑
**文件**: `lib/store/model/message_model.dart`

**操作**:
- 在 `toTypeMessage()` 方法中添加新消息类型的转换
- 处理 `textStream` → TextMessage（带特殊 metadata）
- 处理 `imageMulti` → CustomMessage（带 images 数组）
- 处理 `unsupported` → CustomMessage（带错误标识）

**预期结果**:
```dart
// 在 toTypeMessage() 中添加：
if (currentMsgType == 'text_stream') {
  message = TextMessage(
    authorId: author.id,
    createdAt: createdDt,
    id: id!,
    text: payloadData['text'] ?? '',
    metadata: {
      ...metadata,
      'index': payloadData['index'] ?? 0,
      'is_end': payloadData['is_end'] ?? false,
    },
  );
} else if (currentMsgType == 'imageMulti') {
  message = CustomMessage(
    authorId: author.id,
    id: id!,
    createdAt: createdDt,
    metadata: {
      ...metadata,
      'images': payloadData['images'] ?? [],
    },
  );
}
```

---

### 阶段 2：实现新消息类型（Step 4-5）

#### Step 4: 创建 ImageMultiMessageBuilder
**文件**: `lib/component/chat/message_image_multi_builder.dart`（新建）

**操作**:
- 创建多图消息组件
- 使用 `GridView` 展示多张图片
- 支持点击预览
- 复用现有的图片加载逻辑

**预期结果**:
```dart
class ImageMultiMessageBuilder extends StatefulWidget {
  final String type;
  final CustomMessage message;
  final User user;

  const ImageMultiMessageBuilder({
    super.key,
    required this.type,
    required this.message,
    required this.user,
  });

  @override
  State<ImageMultiMessageBuilder> createState() => _ImageMultiMessageBuilderState();
}

class _ImageMultiMessageBuilderState extends State<ImageMultiMessageBuilder> {
  late List<Map<String, dynamic>> images;

  @override
  void initState() {
    super.initState();
    images = List<Map<String, dynamic>>.from(
      widget.message.metadata?['images'] ?? [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.618,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final img = images[index];
          return GestureDetector(
            onTap: () => _previewImage(index),
            child: CachedNetworkImage(
              imageUrl: img['uri'] ?? '',
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }

  void _previewImage(int index) {
    // 实现图片预览
  }
}
```

---

#### Step 5: 创建 UnsupportedMessageBuilder
**文件**: `lib/component/chat/message_unsupported_builder.dart`（新建）

**操作**:
- 创建不支持消息类型的展示组件
- 显示友好的错误提示
- 可选：显示原始数据供调试

**预期结果**:
```dart
class UnsupportedMessageBuilder extends StatelessWidget {
  final String type;
  final CustomMessage message;
  final User user;

  const UnsupportedMessageBuilder({
    super.key,
    required this.type,
    required this.message,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final msgType = message.metadata?['msg_type'] ?? 'unknown';
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16),
          const SizedBox(width: 8),
          Text('不支持的消息类型: $msgType'),
        ],
      ),
    );
  }
}
```

---

### 阶段 3：集成 flutter_chat_ui 组件（Step 6-8）

#### Step 6: 在 ChatPage 中配置 flutter_chat_ui
**文件**: `lib/page/chat/chat/chat_page.dart`

**操作**:
- 导入所需的 flyer_chat_* 组件
- 在 `ChatWidget` builders 中配置各类型 builder
- 确保与现有主题系统集成

**预期结果**:
```dart
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:flyer_chat_location_message/flyer_chat_location_message.dart';
import 'package:flyer_chat_video_message/flyer_chat_video_message.dart';
import 'package:flyer_chat_system_message/flyer_chat_system_message.dart';

// 在 ChatWidget 中配置：
ChatWidget(
  builders: ChatWidgetBuilders(
    textMessageBuilder: (_, message, {width}) => FlyerChatTextMessage(message: message),
    imageMessageBuilder: (_, message, {width}) => FlyerChatImageMessage(message: message),
    fileMessageBuilder: (_, message, {width}) => FlyerChatFileMessage(message: message),
    locationMessageBuilder: (_, message, {width}) => FlyerChatLocationMessage(message: message),
    videoMessageBuilder: (_, message, {width}) => FlyerChatVideoMessage(message: message),
    systemMessageBuilder: (_, message, {width}) => FlyerChatSystemMessage(message: message),
    customMessageBuilder: (_, message, {width}) => CustomMessageBuilder(
      type: conversationType,
      message: message,
    ),
  ),
  // ... 其他配置
)
```

---

#### Step 7: 更新 CustomMessageBuilder
**文件**: `lib/component/chat/message.dart`

**操作**:
- 添加 `imageMulti` 和 `unsupported` 的处理分支
- 区分 `webrtcAudio` 和 `webrtcVideo` 两种 WebRTC 消息类型
- 移除已被 flutter_chat_ui 替换的 builder 调用
- 确保 WebRTCMessageBuilder 能正确区分音频和视频通话

**预期结果**:
```dart
switch (messageType) {
  // ... 保留现有的 case

  case 'image_multi':
    content = ImageMultiMessageBuilder(
      type: type,
      message: message,
      user: user,
    );
    break;

  case 'webrtc_audio':
  case 'webrtc_video':
    // WebRTC 消息需要区分音频和视频
    // WebRTCMessageBuilder 内部会根据 msg_type 显示不同的图标和交互
    content = WebRTCMessageBuilder(
      user: user,
      message: message,
    );
    break;

  case 'unsupported':
    content = UnsupportedMessageBuilder(
      type: type,
      message: message,
      user: user,
    );
    break;

  default:
    debugPrint("未知的消息类型: $messageType");
    content = UnsupportedMessageBuilder(
      type: type,
      message: message,
      user: user,
    );
    break;
}
```

**WebRTC 消息类型区分说明**:

| msg_type | UI 展示 | 点击行为 |
|----------|---------|---------|
| `webrtcAudio` | 📞 电话图标 + 通话状态 | 打开音频通话界面 |
| `webrtcVideo` | 📹 视频图标 + 通话状态 | 打开视频通话界面 |

**WebRTCMessageBuilder 需要的更新**:
1. 从 `message.metadata?['msg_type']` 获取消息类型（而非从 `custom_type`）
2. 根据 msg_type 显示对应的图标：
   - `webrtcAudio`: 显示 `Icons.call` 或 `Icons.phone`
   - `webrtcVideo`: 显示 `Icons.videocam`
3. 点击时传递正确的 media 参数给 `openCallScreen()`

**更新后的 WebRTCMessageBuilder 关键代码**:
```dart
@override
Widget build(BuildContext context) {
  // 获取 msg_type（优先于 custom_type）
  final msgType = message.metadata?['msg_type'] ?? '';
  final customType = message.metadata?['custom_type'] ?? '';

  // 兼容新旧方式：优先使用 msg_type
  final isVideo = msgType == 'webrtcVideo' || customType == 'webrtc_video';
  final media = isVideo ? 'video' : 'audio';

  // 根据类型显示不同图标
  final icon = isVideo ? Icons.videocam : Icons.call;

  // ...
}
```

---

#### Step 7.5: 更新 WebRTCMessageBuilder 以支持 msg_type 区分
**文件**: `lib/component/chat/message_webrtc_builder.dart`

**操作**:
1. 修改消息类型获取逻辑，优先使用 `msg_type` 而非 `custom_type`
2. 根据 `msg_type` 值区分音频和视频通话
3. 确保向后兼容旧数据（仍使用 `custom_type` 的消息）

**关键修改点**:

| 原代码行 | 修改前 | 修改后 |
|---------|-------|-------|
| 97 | `String media = message.metadata?['media'] ?? 'audio';` | 根据 `msg_type` 或 `custom_type` 判断 |
| 97 | `String customType = message.metadata?['custom_type'] ?? '';` | 优先使用 `msg_type` |

**完整修改示例**:
```dart
@override
Widget build(BuildContext context) {
  bool userIsAuthor = UserRepoLocal.to.currentUid == message.authorId;
  String peerId = userIsAuthor
      ? (message.metadata?['peer_id'] ?? '')
      : message.authorId;
  int state = message.metadata?['state'] ?? 0;

  // 新增：优先使用 msg_type 判断消息类型
  final msgType = message.metadata?['msg_type'] ?? '';
  final customType = message.metadata?['custom_type'] ?? '';

  // 兼容新旧数据格式
  // 新格式：msg_type = 'webrtcAudio' 或 'webrtcVideo'
  // 旧格式：custom_type = 'webrtc_audio' 或 'webrtc_video'
  final isVideo = msgType == 'webrtcVideo' || customType == 'webrtc_video';
  String media = isVideo ? 'video' : 'audio';

  int startAt = message.metadata?['start_at'] ?? 0;
  int endAt = message.metadata?['end_at'] ?? 0;
  // ... 其余代码保持不变

  return InkWell(
    onTap: () async {
      ContactModel? peer = await ContactRepo().findByUid(peerId);
      if (peer != null) {
        openCallScreen(
          context,
          peer,
          {'media': media},  // 传递正确的 media 类型
          caller: true,
        );
      }
    },
    child: Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 8),
      child: _buildBody(context, msgType.isNotEmpty ? msgType : customType, title, userIsAuthor),
    ),
  );
}

Widget _buildBody(
  BuildContext context,
  String messageType,  // 改名：customType -> messageType，更准确
  String title,
  bool userIsAuthor,
) {
  Widget row;
  // 根据 messageType 判断是否为视频通话
  final isVideo = messageType == 'webrtcVideo' || messageType == 'webrtc_video';

  if (userIsAuthor) {
    row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 4),
          child: Text(
            title,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Color.fromRGBO(34, 34, 34, 1.0),
              fontSize: 14.0,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 根据类型显示不同图标
        isVideo
            ? const Icon(
                Icons.videocam,
                color: Color.fromRGBO(34, 34, 34, 1.0),
              )
            : const Icon(
                Icons.call,
                color: Color.fromRGBO(34, 34, 34, 1.0),
              ),
      ],
    );
  } else {
    row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // 根据类型显示不同图标
        isVideo ? const Icon(Icons.videocam) : const Icon(Icons.call),
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 4),
          child: Text(
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 15.0,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  return row;
}
```

**测试验证**:
- [ ] `webrtcAudio` 消息显示电话图标
- [ ] `webrtcVideo` 消息显示视频图标
- [ ] 点击音频通话消息打开音频通话界面
- [ ] 点击视频通话消息打开视频通话界面
- [ ] 兼容旧的 `custom_type` 数据

---

#### Step 8: 移除/标记过时的 Builder 文件
**文件**: `lib/component/chat/message_image_builder.dart` 等

**操作**:
- 为已被替换的 builder 添加 `@Deprecated` 注解
- 在注释中说明替换原因和替代方案
- 不立即删除，保持向后兼容性

**预期结果**:
```dart
/// @Deprecated 使用 flyer_chat_image_message 代替
/// 这个实现已由 flutter_chat_ui 库中的 FlyerChatImageMessage 替换
/// 保留此文件仅用于向后兼容，新代码请使用 FlyerChatImageMessage
@Deprecated('Use FlyerChatImageMessage from flyer_chat_image_message package')
class MessageImageBuilder extends StatelessWidget {
  // ... 现有实现
}
```

---

### 阶段 4：文档更新（Step 9-10）

#### Step 9: 更新 API 文档
**文件**: `/Users/leeyi/project/imboy.pub/imboy/doc/api/websocket-api-2.md`

**操作**:
- 在"基础消息类型 (msg_type)"章节补全 Payload 示例
- 添加新增的 `textStream`、`imageMulti`、`unsupported` 类型
- 更新 Payload 必需字段表格

**预期结果**:
```markdown
### 基础消息类型 Payload 完整示例

| msg_type | Payload 必需字段 | 可选字段 | 示例值 |
|----------|-----------------|---------|--------|
| **text** | `text` | `client_send_ts` | `{"text": "Hello World", "client_send_ts": 1642579200000}` |
| **textStream** | `text`, `index` | `is_end` | `{"text": "Streaming...", "index": 0, "is_end": false}` |
| **image** | `uri`, `size` | `width`, `height`, `thumbhash` | `{"uri": "https://...", "size": 102400, "width": 1920, "height": 1080}` |
| **imageMulti** | `images[]` | - | `{"images": [{"uri": "...", "width": 1920, "height": 1080}]}` |
| **file** | `uri`, `name`, `size` | `mime_type` | `{"uri": "https://...", "name": "report.pdf", "size": 1024000}` |
| **location** | `latitude`, `longitude`, `title` | `address` | `{"latitude": 39.9042, "longitude": 116.4074, "title": "北京市朝阳区"}` |
| **audio** | `uri`, `duration_ms` | - | `{"uri": "https://...", "duration_ms": 15000}` |
| **video** | `uri`, `duration_ms` | `thumb`, `size` | `{"uri": "https://...", "thumb": {"uri": "https://..."}, "duration_ms": 60000}` |
| **system** | `text` | - | `{"text": "系统通知内容"}` |
| **quote** | `quote_msg_id`, `text` | `quote_text` | `{"quote_msg_id": "msg100", "quote_text": "原文", "text": "回复"}` |
| **revoked** | `original_msg_id` | `revoker_id` | `{"original_msg_id": "msg105", "revoker_id": "user123"}` |
| **visitCard** | `user_id`, `nickname` | `avatar` | `{"user_id": "user123", "nickname": "张三", "avatar": "https://..."}` |
| **webrtcAudio** | `call_id`, `status` | `duration` | `{"call_id": "call_123", "duration": 60, "status": "ended"}` |
| **webrtcVideo** | `call_id`, `status` | `duration` | `{"call_id": "call_456", "duration": 120, "status": "ended"}` |
| **unsupported** | - | 自定义字段 | `{"error": "unknown_msg_type", "original_type": "unknown"}` |
```

---

#### Step 10: 更新代码文档
**文件**: `lib/component/chat/CLAUDE.md`

**操作**:
- 更新消息类型枚举文档
- 添加新 builder 的使用说明
- 更新 flutter_chat_ui 组件集成说明

---

### 阶段 5：代码清理（Step 11-12）

#### Step 11: 清理未使用的代码
**操作**:
- 检查 `lib/component/chat/` 目录下所有文件
- 移除未被引用的辅助函数
- 统一导入语句

**检查清单**:
- [ ] `message_image_builder.dart` - 已被 flyer_chat_image_message 替换，标记 @Deprecated
- [ ] `message_video_builder.dart` - 已被 flyer_chat_video_message 替换，标记 @Deprecated
- [ ] `message_location_builder.dart` - 已被 flyer_chat_location_message 替换，标记 @Deprecated
- [ ] 检查并移除未使用的工具函数

---

#### Step 12: 运行静态分析和测试
**操作**:
```bash
# 运行 Dart 分析
flutter analyze

# 运行测试
flutter test

# 检查代码格式
flutter format --set-exit-if-changed lib/component/chat/
```

---

## 五、验证检查清单

### 5.1 功能验证
- [ ] 所有 15 种消息类型能正确显示
- [ ] 文本消息正常显示
- [ ] 文本流消息支持分片显示
- [ ] 图片消息正确加载和预览
- [ ] 多图消息使用网格展示
- [ ] 文件消息可下载/打开
- [ ] 位置消息显示正确
- [ ] 音频消息可播放
- [ ] 视频消息可播放
- [ ] 系统消息正确显示
- [ ] 引用消息正确显示引用内容
- [ ] 撤回消息显示撤回提示
- [ ] 名片消息可点击查看用户信息
- [ ] WebRTC 消息显示通话记录
- [ ] 不支持消息显示友好提示

### 5.2 代码质量
- [ ] 无编译错误
- [ ] 无静态分析警告
- [ ] 代码格式符合规范
- [ ] 所有导出文件正确导出新组件

---

## 六、风险和注意事项

### 6.1 兼容性风险
- **问题**: 替换现有 builder 可能影响依赖它们的代码
- **缓解**: 使用 `@Deprecated` 注解而非直接删除，保持向后兼容

### 6.2 性能考虑
- **问题**: flutter_chat_ui 组件可能有不同的性能特性
- **缓解**: 进行性能测试，特别是长列表滚动场景

### 6.3 主题集成
- **问题**: flutter_chat_ui 组件需要与现有主题系统集成
- **缓解**: 配置正确的主题参数和颜色方案

---

## 七、后续优化建议

1. **渐进式迁移**: 先在新功能中使用 flutter_chat_ui 组件，逐步替换旧实现
2. **统一主题配置**: 创建一个统一的配置类管理所有消息类型的主题
3. **性能优化**: 对图片加载、视频播放等进行性能优化
4. **单元测试**: 为每个 builder 添加单元测试
5. **组件文档**: 为每个新组件添加使用示例和文档

---

**文档版本**: v1.0
**创建时间**: 2026-01-20
