# Chat Provider 重构方案

## 📋 概述

`chat_provider.dart` 当前有 **2,462 行代码**，严重违反单一职责原则（SRP）。本方案将其拆分为 **7 个独立模块**，每个模块职责清晰。

## 🎯 目标

- 提升代码可维护性
- 便于单元测试
- 遵循 SOLID 原则
- 减少代码耦合

## 📁 拆分后的目录结构

```
lib/page/chat/chat/
├── chat_provider.dart              # 核心 Notifier（精简版，~300行）
├── chat_state.dart                 # 状态类定义（~100行）
├── providers/
│   ├── chat_message_sender.dart    # 消息发送逻辑
│   ├── chat_message_loader.dart    # 消息加载逻辑
│   ├── chat_audio_handler.dart     # 音频播放管理
│   ├── chat_e2ee_handler.dart      # E2EE 加密处理
│   ├── chat_reaction_handler.dart  # 消息反应处理
│   └── chat_burn_handler.dart      # 阅后即焚处理
└── mixin/
    └── chat_event_handler.dart     # 事件订阅管理
```

## 📊 职责划分

| 模块 | 职责 | 预估行数 |
|------|------|----------|
| `chat_provider.dart` | 状态管理入口、协调各 Handler | ~300 |
| `chat_state.dart` | 状态类定义、不可变数据 | ~100 |
| `chat_message_sender.dart` | 消息发送、WebSocket 通信、重试 | ~400 |
| `chat_message_loader.dart` | 分页加载、消息转换 | ~300 |
| `chat_audio_handler.dart` | 语音播放、自动播放下一条 | ~200 |
| `chat_e2ee_handler.dart` | 端到端加密、密钥管理 | ~350 |
| `chat_reaction_handler.dart` | 消息反应、更新 UI | ~200 |
| `chat_burn_handler.dart` | 阅后即焚定时器、清理 | ~250 |
| `chat_event_handler.dart` | EventBus 订阅、事件分发 | ~300 |

## 🔄 迁移步骤

### Phase 1: 提取状态类（低风险）
1. 创建 `chat_state.dart`
2. 移动 `ChatState` 类
3. 更新导入

### Phase 2: 提取独立处理器（中风险）
1. 提取 `ChatAudioHandler`
2. 提取 `ChatBurnHandler`
3. 提取 `ChatReactionHandler`

### Phase 3: 提取核心逻辑（高风险）
1. 提取 `ChatMessageSender`
2. 提取 `ChatMessageLoader`
3. 提取 `ChatE2EEHandler`

### Phase 4: 重构主 Provider
1. 简化 `ChatNotifier`
2. 整合 Handler
3. 更新测试

## 🧪 测试策略

每个提取的模块都需要：
- 单元测试（业务逻辑）
- Mock 依赖（数据库、网络）
- 集成测试（与主 Provider 协作）

## ⚠️ 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 导入循环依赖 | 编译失败 | 使用依赖注入 |
| 状态共享问题 | 数据不一致 | 使用 Riverpod ref |
| 事件订阅遗漏 | 功能丢失 | 完整的测试覆盖 |

## 📅 时间估算

- Phase 1: 2-3 小时
- Phase 2: 4-5 小时
- Phase 3: 6-8 小时
- Phase 4: 3-4 小时
- **总计: 15-20 小时**

## ✅ 验收标准

- [ ] 所有现有测试通过
- [ ] 单文件不超过 500 行
- [ ] 每个模块有独立测试
- [ ] 无循环依赖
- [ ] 代码覆盖率 ≥ 60%
