# EventSubscriptionManager 使用指南

> 最后更新：2026-01-12 19:30:00 CST

---

## 概述

`EventSubscriptionManager` 是一个用于简化事件订阅生命周期管理的 mixin。它自动收集所有订阅，并在服务销毁时统一取消，防止内存泄漏。

---

## 核心功能

1. **自动订阅收集** - 使用 `subscribeTo()` 包装订阅，自动添加到内部列表
2. **统一取消管理** - 调用 `cancelAllSubscriptions()` 一次性取消所有订阅
3. **防止内存泄漏** - 确保所有订阅在服务销毁时被正确取消
4. **简化代码** - 减少重复的订阅管理代码

---

## 快速开始

### 基本用法

```dart
import 'package:imboy/service/event_subscription_manager.dart';
import 'package:imboy/service/events/events.dart';

class MyService extends GetxService with EventSubscriptionManager {
  @override
  void onInit() {
    super.onInit();

    // 使用 subscribeTo 包装订阅
    subscribeTo(
      AppEventBus.on<MyEvent>().listen((event) {
        // 处理事件
      }),
    );
  }

  @override
  void onClose() {
    // 一次调用取消所有订阅
    cancelAllSubscriptions();
    super.onClose();
  }
}
```

---

## 详细说明

### subscribeTo 方法

```dart
StreamSubscription<T> subscribeTo<T extends AppEvent>(
  StreamSubscription<T> subscription,
)
```

**功能**：
- 将订阅添加到内部列表
- 返回原始订阅对象（可选）
- 支持泛型类型参数

**示例**：
```dart
// 订阅单个事件
subscribeTo(
  AppEventBus.on<MessageSendRequestedEvent>().listen((event) {
    sendMessage(event.message);
  }),
);

// 订阅带错误处理
subscribeTo(
  AppEventBus.on<MessageSendRequestedEvent>().listen(
    (event) => sendMessage(event.message),
    onError: (error) {
      AppLogger.error('消息发送错误: $error');
    },
  ),
);
```

### cancelAllSubscriptions 方法

```dart
void cancelAllSubscriptions()
```

**功能**：
- 取消所有通过 `subscribeTo()` 添加的订阅
- 清空内部订阅列表
- 通常在 `onClose()` 中调用

**示例**：
```dart
@override
void onClose() {
  cancelAllSubscriptions();  // 取消所有订阅
  super.onClose();
}
```

---

## 完整示例

### MessageService 实现

```dart
class MessageService extends GetxService with EventSubscriptionManager {
  @override
  void onInit() {
    super.onInit();

    // 订阅 WebSocket 消息接收事件
    subscribeTo(
      AppEventBus.on<WebSocketMessageReceivedEvent>().listen(_handleWebSocketMessage),
    );

    // 订阅 ACK 发送请求事件
    subscribeTo(
      AppEventBus.on<AckSendRequestedEvent>().listen(_handleAckSendRequest),
    );

    // 订阅消息状态更新请求事件
    subscribeTo(
      AppEventBus.on<MessageStatusUpdateRequestedEvent>().listen(_handleStatusUpdateRequest),
    );

    // 订阅 WebSocket 连接状态事件
    subscribeTo(
      AppEventBus.on<WebSocketStatusChangedEvent>().listen(_handleWebSocketStatusChange),
    );
  }

  @override
  void onClose() {
    // 一次调用取消所有订阅
    cancelAllSubscriptions();
    super.onClose();
  }

  void _handleWebSocketMessage(WebSocketMessageReceivedEvent event) {
    // 处理接收到的消息
  }

  void _handleAckSendRequest(AckSendRequestedEvent event) {
    // 处理 ACK 发送请求
  }

  void _handleStatusUpdateRequest(MessageStatusUpdateRequestedEvent event) {
    // 处理状态更新请求
  }

  void _handleWebSocketStatusChange(WebSocketStatusChangedEvent event) {
    // 处理 WebSocket 状态变化
  }
}
```

---

## 对比旧方式

### 旧方式（不推荐）

```dart
class MyService extends GetxService {
  StreamSubscription<MessageSendRequestedEvent>? _msgSendSubscription;
  StreamSubscription<AckSendRequestedEvent>? _ackSendSubscription;
  StreamSubscription<MessageStatusUpdateRequestedEvent>? _statusUpdateSubscription;
  StreamSubscription<WebSocketStatusChangedEvent>? _wsStatusSubscription;

  @override
  void onInit() {
    super.onInit();

    // 需要为每个订阅声明字段
    _msgSendSubscription = AppEventBus.on<MessageSendRequestedEvent>().listen(
      (event) => _handleMessageSend(event),
    );

    _ackSendSubscription = AppEventBus.on<AckSendRequestedEvent>().listen(
      (event) => _handleAckSend(event),
    );

    _statusUpdateSubscription = AppEventBus.on<MessageStatusUpdateRequestedEvent>().listen(
      (event) => _handleStatusUpdate(event),
    );

    _wsStatusSubscription = AppEventBus.on<WebSocketStatusChangedEvent>().listen(
      (event) => _handleStatusChange(event),
    );
  }

  @override
  void onClose() {
    // 需要逐个取消订阅，容易遗漏
    _msgSendSubscription?.cancel();
    _ackSendSubscription?.cancel();
    _statusUpdateSubscription?.cancel();
    _wsStatusSubscription?.cancel();
    super.onClose();
  }
}
```

**缺点**：
- 需要为每个订阅声明字段
- 容易遗漏取消订阅
- 代码重复
- 维护成本高

### 新方式（推荐）

```dart
class MyService extends GetxService with EventSubscriptionManager {
  @override
  void onInit() {
    super.onInit();

    // 使用 subscribeTo 包装订阅
    subscribeTo(AppEventBus.on<MessageSendRequestedEvent>().listen(_handleMessageSend));
    subscribeTo(AppEventBus.on<AckSendRequestedEvent>().listen(_handleAckSend));
    subscribeTo(AppEventBus.on<MessageStatusUpdateRequestedEvent>().listen(_handleStatusUpdate));
    subscribeTo(AppEventBus.on<WebSocketStatusChangedEvent>().listen(_handleStatusChange));
  }

  @override
  void onClose() {
    // 一次调用取消所有订阅
    cancelAllSubscriptions();
    super.onClose();
  }
}
```

**优点**：
- 无需声明订阅字段
- 自动管理生命周期
- 代码简洁
- 不会遗漏取消订阅

---

## 最佳实践

### 1. 始终在 onInit 中订阅

```dart
@override
void onInit() {
  super.onInit();
  // 在这里订阅事件
  subscribeTo(AppEventBus.on<Event>().listen(handle));
}
```

### 2. 始终在 onClose 中取消订阅

```dart
@override
void onClose() {
  cancelAllSubscriptions();  // 一定要调用
  super.onClose();
}
```

### 3. 添加错误处理

```dart
subscribeTo(
  AppEventBus.on<Event>().listen(
    (event) => handleEvent(event),
    onError: (error) {
      AppLogger.error('事件处理错误: $error');
    },
  ),
);
```

### 4. 使用命名方法作为回调

```dart
// ✅ 推荐：命名方法，易于调试
subscribeTo(AppEventBus.on<Event>().listen(_handleEvent));

void _handleEvent(Event event) {
  // 处理逻辑
}

// ❌ 不推荐：匿名方法，难以调试
subscribeTo(AppEventBus.on<Event>().listen((event) {
  // 处理逻辑
}));
```

### 5. 事件处理方法使用下划线前缀

```dart
// 私有方法，表示仅在内部使用
void _handleEvent(Event event) { }

void _handleWebSocketMessage(WebSocketMessageReceivedEvent event) { }

void _handleAckSendRequest(AckSendRequestedEvent event) { }
```

---

## 常见问题

### Q: 如果订阅不是 StreamSubscription 怎么办？

A: `subscribeTo()` 只支持 `StreamSubscription` 类型。如果你使用的是其他类型的监听器（如 ValueListenable），需要手动管理其生命周期。

```dart
// StreamSubscription - 使用 subscribeTo
subscribeTo(AppEventBus.on<Event>().listen(handle));

// ValueListenable - 手动管理
VoidCallback? _listener;
_listener = () { /* handle */ };
someValueListenable.addListener(_listener!);

@override
void onClose() {
  someValueListenable.removeListener(_listener!);
  cancelAllSubscriptions();
  super.onClose();
}
```

### Q: 可以在运行时动态添加订阅吗？

A: 可以。`subscribeTo()` 可以在任何时候调用，不仅限于 `onInit()`。

```dart
void addDynamicSubscription() {
  subscribeTo(
    AppEventBus.on<SomeEvent>().listen(_handleSomeEvent),
  );
}
```

### Q: 如何取消单个订阅？

A: `subscribeTo()` 返回 `StreamSubscription`，你可以保存引用并单独取消：

```dart
final subscription = subscribeTo(
  AppEventBus.on<Event>().listen(handle),
);

// 稍后取消
subscription.cancel();

// 注意：手动取消的订阅仍在内部列表中，cancelAllSubscriptions 不会报错
```

### Q: cancelAllSubscriptions 可以多次调用吗？

A: 可以。多次调用是安全的，内部已做防护。

---

## 相关文档

- 📖 [事件总线使用文档](./event_bus/README.md)
- 📖 [事件指南](./events/EVENT_GUIDE.md)
- 📖 [循环依赖分析](./CIRCULAR_DEPENDENCY_ANALYSIS.md)
- 📖 [WebSocket 事件示例](./websocket_events_example.dart)

---

**文档维护者**: ImBoy Team
**最后更新**: 2026-01-12 19:30:00 CST
