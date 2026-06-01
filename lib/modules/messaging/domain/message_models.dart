/// 消息模块对外类型聚合 barrel / Messaging shared-type barrel（T4.2c）。
///
/// **架构决策（2026-06-01，T4.2c 定）**：本文件**有意保持为纯 re-export barrel**，
/// 仅收敛对外暴露的消息相关类型，**不在此新建领域自有 Message 实体**替代
/// `flutter_chat_core.Message`。
///
/// 理由（KISS / YAGNI）：当前消费方（chat_page 及 flutter_chat_ui 渲染层）直接
/// 依赖 `flutter_chat_core.Message` UI 模型,新建域 Message 实体替代将引入大量
/// 边界映射且无实际领域不变量收益。领域不变量已由 `domain/message.dart`
/// （撤回/编辑充血实体）与 `domain/policy/*`（纯函数策略）承载,二者各司其职。
///
/// ⚠️ 故本 barrel **非技术债**,勿误判为「待升级真实定义」而强行替换。
library;

export 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
export 'package:imboy/service/events/message_events.dart'
    show E2EEKeyMismatchEvent, TypingStatus;
export 'package:imboy/store/model/contact_model.dart' show ContactModel;
export 'package:imboy/store/model/message_model.dart'
    show IMBoyMessageStatus, MessageModel, ReEditMessage;
export 'package:imboy/store/repository/message_repo_sqlite.dart'
    show MessageRepo;
