# 消息类型实现与优化计划

> 计划创建时间：2026-01-28
> 计划状态：待确认
> 预估工作量：8-12 小时

---

## 目录

- [需求重述](#需求重述)
- [现状分析](#现状分析)
- [实施计划](#实施计划)
- [风险评估](#风险评估)
- [验收标准](#验收标准)

---

## 需求重述

### 核心目标

在现有代码基础上实现 15 种基础消息类型，优先使用 `flutter_chat_ui` 库的 `flyer_chat_*` 组件，没有的才使用自定义 builder。

### 消息类型清单

| msg_type | 说明 | UI 组件 | Payload 示例 |
|----------|------|---------|-------------|
| `text` | 文本消息 | flyer_chat_text_message | `{"content": "Hello"}` |
| `textStream` | 文本流消息 | flyer_chat_text_stream_message | `{"content": "Hello"}` |
| `image` | 图片消息 | flyer_chat_image_message | `{"url": "...", "width": 1024, "height": 768}` |
| `imageMulti` | 多图片消息 | ImageMultiMessageBuilder | `{"images": [...]}` |
| `file` | 文件消息 | flyer_chat_file_message | `{"url": "...", "name": "doc.pdf", "size": 102400}` |
| `location` | 位置消息 | flyer_chat_location_message | `{"latitude": 39.9, "longitude": 116.4}` |
| `audio` | 语音消息 | flyer_chat_audio_message | `{"url": "...", "duration": 30}` |
| `video` | 视频消息 | flyer_chat_video_message | `{"url": "...", "duration": 60}` |
| `system` | 系统消息 | flyer_chat_system_message | `{}` |
| `quote` | 引用消息 | QuoteMessageBuilder | `{}` |
| `revoked` | 撤回消息 | RevokedMessageBuilder | `{}` |
| `visitCard` | 个人名片消息 | VisitCardMessageBuilder | `{}` |
| `webrtcAudio` | WebRTC 音频消息 | WebRTCMessageBuilder | `{}` |
| `webrtcVideo` | WebRTC 视频消息 | WebRTCMessageBuilder | `{}` |
| `unsupported` | 不支持的消息 | UnsupportedMessageBuilder | 自定义字段 |

### 附加需求

1. **补全文档**：完善 `websocket-api-2.md` 中各消息类型的 Payload 示例
2. **代码清理**：优化和清理 `lib/component/chat/` 目录下的代码

---

## 现状分析

### 已实现的基础设施

✅ **WebSocket API v2.0 适配完成**
- `MessageModel` 已支持 v2.0 格式（msg_type/action/e2ee 顶层字段）
- 消息解析和序列化已完整实现

✅ **消息类型常量定义完整**
- `lib/service/message_type_constants.dart` 定义了所有消息类型常量
- `MsgTypeEnum` 提供类型安全的枚举

✅ **已有的自定义 Builder**（8 个）
- `AudioMessageBuilder` - 音频消息
- `ImageMultiMessageBuilder` - 多图消息
- `LocationMessageBuilder` - 位置消息
- `QuoteMessageBuilder` - 引用消息
- `RevokedMessageBuilder` - 撤回消息
- `UnsupportedMessageBuilder` - 不支持的消息
- `VisitCardMessageBuilder` - 名片消息
- `WebRTCMessageBuilder` - WebRTC 消息

✅ **flutter_chat_ui 集成**
- 项目已使用 `flyer_chat_*` 系列组件
- 文本、图片、文件、视频等基础类型可直接使用

### 核心路由逻辑

**现有消息路由**（`lib/component/chat/message.dart`）：
```dart
// 优先级检查顺序：
// 1. status 字段（撤回状态 30-39）
// 2. custom_type（WebRTC、名片等）
// 3. msg_type（内容类型）
```

### 已识别的问题

⚠️ **命名不一致**
- 音频消息：`audio` vs `voice`（WebSocket API v2.0 推荐使用 `voice`）
- 代码中同时存在两种用法

⚠️ **可能的重复代码**
- `lib/component/chat/` 下有 18 个文件，需要检查是否有未使用或重复的逻辑

---

## 实施计划

### 阶段一：消息类型实现（4-5 小时）

#### 1.1 确认 flutter_chat_ui 组件可用性（30 分钟）

**任务**：检查所有 `flyer_chat_*` 组件的导入和使用方式

**文件**：`lib/page/chat/chat/barrel/ui_packages.dart`

**验证清单**：
- [ ] `flyer_chat_text_message` 可导入
- [ ] `flyer_chat_text_stream_message` 可导入
- [ ] `flyer_chat_image_message` 可导入
- [ ] `flyer_chat_file_message` 可导入
- [ ] `flyer_chat_video_message` 可导入
- [ ] `flyer_chat_audio_message` 可导入
- [ ] `flyer_chat_location_message` 可导入
- [ ] `flyer_chat_system_message` 可导入

#### 1.2 更新 CustomMessageBuilder 路由逻辑（1 小时）

**文件**：`lib/component/chat/message.dart`

**变更内容**：
```dart
// 在 switch 语句中添加缺失的消息类型
switch (msgType) {
  // 现有的...
  case 'text':
    // 使用 flyer_chat_text_message
    content = FlyerChatTextMessage(message: message);
    break;
  case 'textStream':
    // 使用 flyer_chat_text_stream_message
    content = FlyerChatTextStreamMessage(message: message);
    break;
  case 'video':
    // 使用 flyer_chat_video_message
    content = FlyerChatVideoMessage(message: message);
    break;
  case 'file':
    // 使用 flyer_chat_file_message
    content = FlyerChatFileMessage(message: message);
    break;
  case 'system':
    // 使用 flyer_chat_system_message
    content = FlyerChatSystemMessage(message: message);
    break;
}
```

#### 1.3 创建 VideoMessageBuilder（如需要）（30 分钟）

**评估**：`flyer_chat_video_message` 是否满足需求

**如果不满足**，创建 `lib/component/chat/message_video_builder.dart`

#### 1.4 创建 FileMessageBuilder（如需要）（30 分钟）

**评估**：`flyer_chat_file_message` 是否满足需求

**如果不满足**，创建 `lib/component/chat/message_file_builder.dart`

#### 1.5 更新 MessageModel.toTypeMessage()（1 小时）

**文件**：`lib/store/model/message_model.dart`

**确保支持所有消息类型**

#### 1.6 更新 MessageModel.fromMessage()（30 分钟）

**文件**：`lib/store/model/message_model.dart`

**确保序列化支持所有消息类型**

#### 1.7 测试所有消息类型（1 小时）

**测试用例**：
- 发送文本消息 → 验证显示
- 发送图片消息 → 验证显示
- 发送多图消息 → 验证显示
- 发送文件消息 → 验证显示
- 发送视频消息 → 验证显示
- 发送语音消息 → 验证显示
- 发送位置消息 → 验证显示
- 发送引用消息 → 验证显示
- 撤回消息 → 验证撤回状态
- 发送名片 → 验证名片显示
- WebRTC 通话 → 验证通话消息

---

### 阶段二：文档补全（2-3 小时）

#### 2.1 更新 WebSocket API 文档（1.5 小时）

**文件**：`/Users/leeyi/project/imboy.pub/imboy/doc/api/websocket-api-2.md`

**补全所有消息类型的 Payload 示例**

#### 2.2 添加 Payload 详细说明（1 小时）

为每种消息类型添加详细的字段说明和示例

#### 2.3 添加使用示例（30 分钟）

添加发送各种消息类型的代码示例

---

### 阶段三：代码清理与优化（2-3 小时）

#### 3.1 代码分析（1 小时）

**工具**：使用静态分析工具

**分析内容**：
- 查找未使用的导入
- 查找未使用的类和方法
- 查找重复代码
- 分析代码复杂度

**文件**：`lib/component/chat/` 下的所有文件

#### 3.2 清理未使用代码（1 小时）

**清理内容**：
- 删除未使用的导入
- 删除未使用的类和方法
- 合并重复的逻辑
- 移除过时的注释

**注意事项**：
- 每次删除后运行测试
- 确保不影响现有功能
- 保留必要的文档注释

#### 3.3 统一命名规范（30 分钟）

**统一项**：
- 音频消息：统一使用 `voice`（符合 WebSocket API v2.0）
- 添加 `audio` 作为 `voice` 的别名（向后兼容）

**变更位置**：
- `lib/service/message_type_constants.dart`
- `lib/component/chat/message.dart`
- `lib/store/model/message_model.dart`

---

### 阶段四：测试与验证（1 小时）

#### 4.1 单元测试

**测试文件**：`test/message_type_test.dart`

**测试用例**：
- 所有消息类型的序列化/反序列化
- MessageModel.toTypeMessage() 正确性
- CustomMessageBuilder 路由正确性

#### 4.2 集成测试

**测试场景**：
- 发送各种类型的消息
- 接收各种类型的消息
- 消息撤回
- 消息编辑

#### 4.3 UI 测试

**测试场景**：
- 验证各种消息类型的 UI 显示
- 验证消息交互（点击、长按等）
- 验证主题适配

---

## 风险评估

### 高风险项

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| `flyer_chat_*` 组件不满足需求 | 需要自定义实现 | 评估阶段确认，准备备用方案 |
| 现有消息格式兼容性问题 | 旧消息无法显示 | 保留旧格式支持，渐进式迁移 |
| 代码清理导致功能异常 | 现有功能失效 | 充分测试，分步骤提交 |

### 中风险项

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 命名统一导致兼容性问题 | 旧代码无法运行 | 添加别名支持，逐步迁移 |
| 文档不完整 | 开发者使用困难 | 逐步完善文档 |

### 低风险项

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 测试覆盖不足 | 潜在 bug 未发现 | 补充测试用例 |

---

## 验收标准

### 功能验收

- [ ] 所有 15 种消息类型都能正确显示
- [ ] 消息发送和接收正常
- [ ] 消息撤回功能正常
- [ ] 消息编辑功能正常
- [ ] 文档 Payload 示例完整且准确

### 代码质量验收

- [ ] 0 errors, 0 warnings（`flutter analyze`）
- [ ] 所有测试通过（`flutter test`）
- [ ] 代码格式化（`dart format .`）
- [ ] 未使用代码已清理
- [ ] 命名规范统一

### 性能验收

- [ ] 消息列表滚动流畅（60fps）
- [ ] 消息发送响应及时
- [ ] 内存占用合理

---

## 实施时间表

| 阶段 | 预估时间 | 依赖 |
|------|----------|------|
| 阶段一：消息类型实现 | 4-5 小时 | 无 |
| 阶段二：文档补全 | 2-3 小时 | 阶段一 |
| 阶段三：代码清理 | 2-3 小时 | 阶段一 |
| 阶段四：测试验证 | 1 小时 | 阶段一、二、三 |
| **总计** | **9-12 小时** | - |

---

## 后续优化建议

1. **性能优化**：大图片、视频的懒加载
2. **缓存优化**：消息缩略图缓存策略
3. **离线支持**：离线消息查看
4. **国际化**：多语言支持
5. **无障碍**：屏幕阅读器支持

---

**等待确认后开始实施**
