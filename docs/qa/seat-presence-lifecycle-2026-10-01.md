# 坐席心跳生命周期隔离 — 2026-10-01

English summary: Stopped seat presence controllers reject late heartbeat/manual responses and resume callbacks. Targeted checks pass; this is not a device or production acceptance result.

## 问题与处理

企业切换或页面销毁会调用 stop，但原实现只取消定时器：未完成心跳仍更新状态、通知页面；旧 resumed 请求完成后仍调用刷新回调。手动状态也有相同的过期回填问题。

复用现有控制器，stop 清除状态并推进请求代次；心跳、手动状态和 resumed 刷新统一验证控制器仍有效。停止后不再发送新请求，重新 start 不接受之前的响应。已发送的服务器写入不能撤销；本次隔离的是客户端回填与回调。

## 验证

- 修改前：新增生命周期检查 4 项失败，复现晚到成功、失败、手动响应和跨空间刷新。
- 修改后：`flutter test test/customer_service/cs_presence_lifecycle_test.dart test/customer_service/cs_presence_read_state_test.dart test/customer_service/cs_workspace_state_test.dart test/customer_service/cs_workspace_org_test.dart --reporter expanded`，退出 0，29 项通过，其中新增 5 项。
- `flutter analyze lib/modules/customer_service/domain/cs_presence_controller.dart test/customer_service/cs_presence_lifecycle_test.dart`，退出 0，无问题。
- 手工检查所有调用点：工作台切组织与销毁都调用 stop；仍复用原有 API、定时器与刷新信号，无新依赖。未使用独立审查代理。

## 证据与边界

源码 SHA256 见下方；日志摘要存于本机 `/tmp/gz-seat-presence-{baseline,tests,analyze}.log`。这些检查使用可控 API 与组件测试，未构成真实后端、真机接待/转接/结束的完整旅程，也未证明六大目标投产完成。没有推送、部署、生产迁移或对外通知。

```json
[
  {
    "path": "lib/modules/customer_service/domain/cs_presence_controller.dart",
    "sha256": "c4fd7d98e540c68b598c4bce826bed2174ad0c1c9fe0aa21bfb8e34d87e94d19"
  },
  {
    "path": "test/customer_service/cs_presence_lifecycle_test.dart",
    "sha256": "583cadd52a1b73977eb42374aed84167d42d6bd7b1d19d0690e74780a8b598a9"
  }
]
```

## 后续闭环：切企业时提交状态隔离

English summary: Presence action busy state now belongs to the current workspace controller; an older request cannot block or unlock actions in another organization.

- 根因：页面的 `_presenceBusy` 在组织切换时未清空；旧操作 finally 无条件清空当前 busy。
- 修复：重建控制器时清空提交状态；finally 仅在请求控制器仍为当前控制器时结束提交。
- 新增组件检查走真实页面、Dio 请求与两个企业的有效工作空间：甲企业 PUT 挂起 → 切乙 → 乙 PUT 能发送；甲返回 → 乙重复点击不得发送第二次 PUT；乙返回 → 显示服务端“离开”。传输出口可控，不能视为真实后端或真机证明。
- 修改前该检查退出 1，预期两企业各有一次请求，实际只有甲企业一次请求。修复后退出 0。
- 连同既有心跳/已读、队列、组织切换与 UX 矩阵：`flutter test test/customer_service/cs_presence_lifecycle_test.dart test/customer_service/cs_presence_read_state_test.dart test/customer_service/cs_workspace_state_test.dart test/customer_service/cs_workspace_org_test.dart test/customer_service/ux_matrix/cs_pages_ux_matrix_test.dart --reporter expanded`，退出 0，33 项通过。
- `flutter analyze lib/modules/customer_service/presentation/cs_workspace_page.dart test/customer_service/cs_workspace_org_test.dart`，退出 0，无问题。手工复核请求控制器捕获、组织切换与页面销毁，不新增状态层或依赖。
- 本机日志 `/tmp/gz-seat-presence-busy-{baseline,fixed,tests,analyze}.log`；仍需完整联调与真机验收，未部署。

```json
[
  {
    "path": "lib/modules/customer_service/presentation/cs_workspace_page.dart",
    "sha256": "5eebff843d607849311e09e1131123d29591b09e437c3c5c6f90e51b29ca7841"
  },
  {
    "path": "test/customer_service/cs_workspace_org_test.dart",
    "sha256": "81d26c2a4a5f39b746670be64b78c60d3ae3346dee5d40adad35a0412767acbb"
  }
]
```
