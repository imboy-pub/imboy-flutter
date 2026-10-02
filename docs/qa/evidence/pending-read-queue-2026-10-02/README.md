# 阅读上报队列的并发与重试检查

运行 `flutter test --no-pub test/unit_test/page/chat/pending_read_queue_test.dart`，退出0；该文件静态检查无问题。

使用生产 ChatNotifier 公共 markAsRead、生产 v32 数据库迁移建成的真实内存 SQLite、真实300ms/5s计时器，控制 HTTP 边界挂起和503失败。检查首请求挂起时新增阅读记录不会被覆盖，释放后自动派发；外国账号记录保留；失败记录无需新输入也会重试。整个检查不替换队列算法。

SharedPreferences使用测试mock后端，WorkspaceApi网请求通过Completer控制，无关音频Provider替换。该记录证明队列并发算法和重试调度，不证明原生偏好存储、真实HTTP认证或消息阅读界面；对应 macOS 原生阅读和实际服务端游标另见 workspace-native-unread-history-2026-10-02。完整目标仍待全量回归和逐项核验。
