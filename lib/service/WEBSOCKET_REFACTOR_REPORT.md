# WebSocket 服务重构报告

## 重构概述

本次重构成功移除了 `WebSocketService` 对 `MessageService` 的直接依赖，改用事件总线（EventBus）进行通信，实现了模块解耦。

**重构日期**: 2026-01-12
**重构文件**: `lib/service/websocket.dart`
**新增文件**:
- `lib/service/websocket_events.dart` - 事件定义
- `lib/service/websocket_events_example.dart` - 使用示例

---

## 修改统计

### 文件修改统计

| 文件 | 修改行数 | 新增行数 | 删除行数 | 说明 |
|------|---------|---------|---------|------|
| `websocket.dart` | 约 45 行 | 30 行 | 15 行 | 重构核心逻辑 |
| `websocket_events.dart` | 0 行 | 147 行 | 0 行 | 新增事件类 |
| `websocket_events_example.dart` | 0 行 | 144 行 | 0 行 | 新增使用示例 |

### 关键变更点

#### 1. 导入语句修改（第 1-24 行）

**修改前**:
```dart
import 'package:imboy/service/message.dart';
```

**修改后**:
```dart
import 'websocket_events.dart';
```

✅ **移除了对 MessageService 的直接导入**

#### 2. 订阅管理（第 41-44 行）

**新增**:
```dart
StreamSubscription? _messageSendSubscription;
```

✅ **新增消息发送事件的订阅管理**

#### 3. 初始化方法修改（第 50-83 行）

**新增**:
```dart
// 订阅消息发送请求事件
_messageSendSubscription = eventBus.on<MessageSendRequestedEvent>().listen(
  (event) {
    iPrint('📤 [WS] 收到消息发送请求: ${event.messageId}');
    sendMessage(event.message, event.messageId);
  },
  onError: (error) {
    iPrint('⚠️ [WS] 消息发送订阅错误: $error');
  },
);
```

✅ **订阅消息发送请求事件**

#### 4. 状态更新方法修改（第 97-111 行）

**新增**:
```dart
// 发布状态变化事件
eventBus.fire(WebSocketStatusChangedEvent(
  status: newStatus.name,
));

iPrint('🔄 [WS] 状态变化: ${oldStatus.name} -> ${newStatus.name}');
```

✅ **状态变化时发布事件**

#### 5. 连接成功事件（第 170-174 行）

**新增**:
```dart
// 发布连接成功事件
eventBus.fire(WebSocketConnectedEvent(
  url: Env.wsUrl,
));
```

✅ **连接成功时发布事件**

#### 6. 连接失败事件（第 199-201 行）

**新增**:
```dart
// 发布连接错误事件
eventBus.fire(WebSocketErrorEvent(error: e));
```

✅ **连接失败时发布事件**

#### 7. 消息接收处理（第 268-291 行）⭐ **核心修改**

**修改前**:
```dart
// ⚡ 非阻塞处理：立即返回，后台异步处理
MessageService.to.processMessage(type, msg);
```

**修改后**:
```dart
// 【重构】使用事件总线发布消息接收事件，而不是直接调用 MessageService
// ⚡ 发布消息接收事件（非阻塞，不等待处理完成）
eventBus.fire(WebSocketMessageReceivedEvent(
  type: type,
  data: msg,
));

iPrint('📡 [WS] 已发布消息接收事件: type=$type, msgId=$messageId');
```

✅ **将直接调用改为发布事件**

#### 8. 错误处理事件（第 420-422 行）

**新增**:
```dart
// 发布 WebSocket 错误事件
eventBus.fire(WebSocketErrorEvent(error: e));
```

✅ **错误时发布事件**

#### 9. 断开连接事件（第 435-440 行）

**新增**:
```dart
// 发布断开连接事件
eventBus.fire(WebSocketDisconnectedEvent(
  reason: closeReason,
  closeCode: closeCode,
));
```

✅ **断开连接时发布事件**

#### 10. 资源清理（第 85-94 行，第 348-355 行）

**新增**:
```dart
// 取消消息发送事件订阅
_messageSendSubscription?.cancel();
```

✅ **确保资源正确清理**

---

## 新增事件类型

### 1. WebSocketMessageReceivedEvent
**用途**: WebSocket 收到消息时触发
```dart
eventBus.fire(WebSocketMessageReceivedEvent(
  type: 'C2C',
  data: {...},
));
```

### 2. WebSocketConnectedEvent
**用途**: WebSocket 连接成功时触发
```dart
eventBus.fire(WebSocketConnectedEvent(
  url: 'wss://...',
));
```

### 3. WebSocketDisconnectedEvent
**用途**: WebSocket 断开连接时触发
```dart
eventBus.fire(WebSocketDisconnectedEvent(
  reason: 'Connection closed',
  closeCode: 1000,
));
```

### 4. WebSocketErrorEvent
**用途**: WebSocket 发生错误时触发
```dart
eventBus.fire(WebSocketErrorEvent(
  error: error,
));
```

### 5. MessageSendRequestedEvent
**用途**: 请求发送消息时触发
```dart
eventBus.fire(MessageSendRequestedEvent(
  message: '{"type":"C2C",...}',
  messageId: 'msg123',
));
```

### 6. WebSocketStatusChangedEvent
**用途**: WebSocket 状态变化时触发
```dart
eventBus.fire(WebSocketStatusChangedEvent(
  status: 'connected',
));
```

---

## 使用示例

### 在 MessageService 中订阅消息接收事件

```dart
@override
void onInit() {
  super.onInit();

  // 订阅 WebSocket 消息接收事件
  _websocketEventSubscription = eventBus.on<WebSocketMessageReceivedEvent>().listen(
    (event) {
      // 处理接收到的消息
      processMessage(event.type, event.data);
    },
    onError: (error) {
      iPrint('WebSocket 消息事件订阅错误: $error');
    },
  );
}

@override
void onClose() {
  // 取消订阅
  _websocketEventSubscription?.cancel();
  super.onClose();
}
```

### 通过 WebSocket 发送消息

```dart
Future<void> sendMessage(String message, String? messageId) async {
  // 发布消息发送请求事件
  eventBus.fire(MessageSendRequestedEvent(
    message: message,
    messageId: messageId,
  ));

  // WebSocketService 会自动订阅此事件并处理发送
}
```

---

## 重构优势

### 1. 解耦合
- ✅ WebSocket 不再直接依赖 MessageService
- ✅ 降低了模块间的耦合度
- ✅ 提高了代码的可维护性

### 2. 灵活性
- ✅ 可以轻松添加新的消息处理逻辑
- ✅ 支持多个订阅者监听同一事件
- ✅ 便于功能扩展

### 3. 可测试性
- ✅ 更容易进行单元测试
- ✅ 可以模拟事件进行测试
- ✅ 降低了测试复杂度

### 4. 错误隔离
- ✅ 消息处理错误不会影响 WebSocket 连接
- ✅ 各模块可以独立处理错误
- ✅ 提高了系统稳定性

---

## 后续工作

### 必须完成的修改

1. **修改 MessageService**
   - 在 `onInit()` 中订阅 `WebSocketMessageReceivedEvent`
   - 在 `onClose()` 中取消订阅
   - 删除直接调用 `WebSocketService` 的代码（如果有）

2. **修改消息发送逻辑**
   - 将直接调用 `WebSocketService.to.sendMessage()` 改为发布 `MessageSendRequestedEvent`

3. **测试验证**
   - 测试消息接收流程
   - 测试消息发送流程
   - 测试连接状态变化
   - 测试错误处理

### 可选的优化

1. 添加事件重试机制
2. 添加事件监控和日志
3. 优化事件分发性能
4. 添加事件优先级

---

## 注意事项

### 1. 订阅生命周期管理
- ✅ 在 `onInit()` 中订阅
- ✅ 在 `onClose()` 中取消订阅
- ✅ 保存订阅引用以便取消

### 2. 错误处理
- ✅ 为每个订阅添加 `onError` 回调
- ✅ 记录错误日志
- ✅ 防止错误传播

### 3. 性能考虑
- ⚠️ 事件发布是非阻塞的，不等待处理完成
- ⚠️ 注意事件处理的顺序
- ⚠️ 避免在事件处理中执行耗时操作

### 4. 内存管理
- ✅ 确保所有订阅都被正确取消
- ✅ 使用弱引用或定期检查避免内存泄漏
- ✅ 在应用生命周期结束时清理资源

---

## 验证清单

- [x] 移除了对 MessageService 的导入
- [x] 创建了新的事件类文件
- [x] 修改了消息接收处理逻辑
- [x] 添加了消息发送事件订阅
- [x] 添加了连接状态事件
- [x] 添加了错误事件
- [x] 添加了资源清理逻辑
- [x] 添加了详细的注释
- [ ] MessageService 订阅消息接收事件（待完成）
- [ ] 修改消息发送逻辑（待完成）
- [ ] 进行完整的测试验证（待完成）

---

## 相关文档

- `lib/service/websocket_events.dart` - 事件定义
- `lib/service/websocket_events_example.dart` - 使用示例
- `lib/config/init.dart` - 全局 eventBus 定义
- `lib/service/CIRCULAR_DEPENDENCY_ANALYSIS.md` - 循环依赖分析

---

**重构完成度**: 80% (WebSocket 端已完成，等待 MessageService 端适配)

**下一步**: 修改 MessageService 以订阅新的事件，完成整个解耦流程。
