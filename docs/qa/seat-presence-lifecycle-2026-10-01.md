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

## 后续闭环：真实字节类型、撤权与连接释放

English summary: Real Dio streams emit Uint8List chunks. Casting at the shared decoding boundary fixes a runtime transformer mismatch. Seat-context revalidation now removes revoked contexts; request cancellation releases the underlying SSE connection.

- 新增传输组件检查使用真实页面与 Dio，出口为可控的 `Stream<Uint8List>`。修改前三项失败：seat.changed、assignment.changed 与前台资格重查。进一步探测发现 `Utf8Decoder` 与 `StreamTransformer<Uint8List,String>` 的运行期类型不兼容；原先只有 List<int> 的纯流检查漏掉了实际网络类型。
- 共享解码边界使用 cast<List<int>>()；默认 opener 将已有 Dio CancelToken 传给现有 API。dispose/流关闭取消请求，过期打开失败不回调已销毁消费者；组织撤权检查同时断言旧请求实际收到取消。
- seat.changed、assignment.changed、resync.required 触发完整资格重查，立即停止旧流与心跳。仍有效的当前组织保留；当前组织失效时选择剩余可用组织；全部失效时清空操作和计数。请求代次隔离晚到上下文结果。普通队列与会话事件仍复用列表刷新，不能覆盖撤权刷新。
- 回前台重新确认资格，无控制器时也能发现新授权。SSE 401/403 清空旧操作并停止自动重连，提供显式重试；不让持久拒绝形成重连循环。网络等其他故障保留既有退避。
- 流资源检查初期发现 Dio 接收超时仍待处理；最终测试没有关闭或绕过接收超时，而由请求取消释放计时资源。临时探测输出已删除。
- 最终命令：`flutter test test/customer_service/cs_presence_lifecycle_test.dart test/customer_service/cs_presence_read_state_test.dart test/customer_service/cs_workspace_state_test.dart test/customer_service/cs_workspace_org_test.dart test/customer_service/cs_seat_events_stream_test.dart test/customer_service/ux_matrix/cs_pages_ux_matrix_test.dart --reporter expanded`，退出 0，44 项通过。
- `flutter analyze lib/modules/customer_service/infrastructure/cs_api.dart lib/modules/customer_service/infrastructure/cs_seat_events_stream.dart lib/modules/customer_service/presentation/cs_workspace_page.dart test/customer_service/cs_workspace_org_test.dart`，退出 0，无问题。手工复核 API 所有调用点、事件流及页面生命周期；无独立代理审查。
- 日志 `/tmp/gz-seat-revocation-{baseline,root-fixed,final-tests,analyze}.log`。本次传输出口可控，虽然覆盖 Dio 实际字节类型、取消与页面行为，仍不是网络后端、真实账号撤权或真机完整接待旅程的证明；六项投产目标继续，未部署。

```json
[
  {
    "path": "lib/modules/customer_service/infrastructure/cs_api.dart",
    "sha256": "99690b0f2498cdea3334723c24652deed67908bfb47247c98cf6eac576f34682"
  },
  {
    "path": "lib/modules/customer_service/infrastructure/cs_seat_events_stream.dart",
    "sha256": "f4bf67efb64f83b28420cb9245da907cd2eb4396d95c041b55efc6fc410b938f"
  },
  {
    "path": "lib/modules/customer_service/presentation/cs_workspace_page.dart",
    "sha256": "cc038bec67c0c72c5ca65b9a700c31bb5c690592b1108b4acca80f4290bbfe58"
  },
  {
    "path": "test/customer_service/cs_workspace_org_test.dart",
    "sha256": "04b05b688c9f4a8bb558ec00cdd3d17fcb8ba87ae8e6071b0ec4dcd53eaed96d"
  }
]
```

## 协议对照修正：首连重同步保留连接

English summary: The backend sends resync.required on every connection without a cursor. Context revalidation must retain the live connection when organization, identity and workspace remain valid; otherwise reconnecting causes an endless initial-resync loop.

- 当前后端 `cs_seat_event_app:cursor_scope/3` 无游标固定 resync；`cs_tenant_handler:stream/4` 首写合成帧。对照后发现上一批客户端逻辑在重同步时重建流，导致“首连 → 重同步 → 重开”循环。
- 复现新增有真实 Dio 字节类型的首连 resync 组件检查，旧逻辑持续产生日志，无法结束检查；仅终止本轮确认归属的两个进程。日志记录 45016 条 SSE URI（含请求和响应记录，不等同连接数），大小 31129131 字节；终止后的退出码不算测试 PASS。
- 修正重查资格时默认保留当前流；组织、业务身份或工作空间改变才重建。失败则停止流并展示错误；首次进入与显式错误重试仍重建。保留完整资格与列表刷新，不删除重同步功能。
- 将结果应用集中到 `_applyContexts`，两函数都小于 50 行。新增断言首连仅打开一次流、资格读取两次并正常显示列表；撤权、重新授权、拒绝访问与取消请求回归继续通过。
- 客户端：`flutter test test/customer_service/cs_presence_lifecycle_test.dart test/customer_service/cs_presence_read_state_test.dart test/customer_service/cs_workspace_state_test.dart test/customer_service/cs_workspace_org_test.dart test/customer_service/cs_seat_events_stream_test.dart test/customer_service/ux_matrix/cs_pages_ux_matrix_test.dart --reporter expanded`，退出 0，45 项通过；两处修改静态分析退出 0，无问题。
- 后端候选 835cb67bf40bbf94bc0cfe09b132e6d5ab219bf3：从当前源码重编全部产品模块与客服测试支持，运行 `eunit:test([cs_seat_event_app_tests,cs_seat_workbench_tests],[verbose])`，退出 0，35 项通过，覆盖无游标首连、有效游标续传、跨组织/空间及真实 Cowboy HTTP 首帧格式。业务 facade 是测试替身、没有数据库；不称为跨端真实账号全旅程。
- 客户端日志 `/tmp/gz-seat-initial-resync-{baseline,fixed,tests,analyze}.log`；后端日志目录 `/var/folders/8m/wbjj0qmn4ml0mgn56wm56j2m0000gn/T/gz-seat-protocol-ueka2z87`。后端业务源码未修改。手工复核请求代次、保留/重建条件与失效清理，无独立代理审查。未部署，完整六项目标未完成。

```json
[
  {
    "path": "lib/modules/customer_service/presentation/cs_workspace_page.dart",
    "sha256": "602c80d147ebaffba4828e6c49b142b9cff8413e289a3da6d251b0ed6736e494"
  },
  {
    "path": "test/customer_service/cs_workspace_org_test.dart",
    "sha256": "128f8cad401f6de0e89da566e67b9f5d7a2ab8f19e5abe5ca608bb442146dd4a"
  }
]
```
