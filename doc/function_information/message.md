
## WebSocket 服务与消息模块的关系


**WebSocket 服务**是消息系统的底层通信基础，负责：
- 建立和维护 WebSocket 连接
- 发送和接收原始消息数据
- 管理连接状态和重连机制
- 提供消息确认机制

**消息模块**采用模块化架构，包含：
- `message_core.dart`: 核心服务，基础初始化和事件分发
- `message_handler.dart`: 消息处理器，处理不同类型消息
- `message_actions.dart`: 消息操作（撤回、编辑等）
- `message_webrtc.dart`: WebRTC 消息处理
- `message_retry.dart`: 消息重试机制
- `websocket_message_queue.dart`: 消息队列持久化

## 交互方式

1. **事件总线通信**: WebSocket 接收消息后通过 `eventBus.fire()` 分发，MessageCore 监听并处理
2. **直接调用**: 消息模块通过 `WebSocketService.to.sendMessage()` 发送消息
3. **状态同步**: MessageCore 监听 WebSocket 连接状态，网络恢复时触发消息重试
4. **确认机制**: WebSocket 的消息确认与消息状态更新紧密结合

## 消息流向

**接收**: WebSocket → 事件总线 → MessageCore → MessageHandler → 具体处理器 → 数据库 → UI
**发送**: UI → MessageActions/Retry → WebSocket → 服务器 → 确认 → 状态更新

这种设计实现了职责分离、可靠传递、可扩展性和可维护性，WebSocket 专注通信，消息模块专注业务逻辑，通过事件总线和直接调用相结合的方式协作。