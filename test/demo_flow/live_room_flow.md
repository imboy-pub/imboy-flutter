# DF-22 直播间列表 → 开播 → 观看

> 优先级：P1
> 状态：`本地列表状态与 API 只读回读通过，开播/观看阻塞（媒体服务缺失）`
> 条件：媒体服务和双端设备
> 最近验证：2026-08-17

## 1. 目标

验证用户可以发现直播间，主播进入发布页开播，观众进入订阅页观看并在结束后退出。

## 2. 前置条件

- [ ] 准备主播账号、观众账号和可用媒体服务。
- [ ] 使用非生产直播间和明确授权的测试账号。
- [ ] 摄像头、麦克风、网络和推流配置已准备。

## 3. TODO 步骤

- [ ] 观众打开直播间列表并刷新。
  - 预期：直播状态、主播信息和空态/错误态正确。
  - 页面计划：[live_room_list_page.md](../auto_test/live_room/live_room_list_page.md)
- [ ] 主播进入发布页，开始和结束一次测试直播。
  - 预期：权限、准备中、开播、停止状态正确。
  - 页面计划：[publisher_page.md](../auto_test/live_room/publisher_page.md)
- [ ] 观众打开直播间观看。
  - 预期：订阅页加载、媒体状态、退出和断线重连正确。
  - 页面计划：[subscriber_page.md](../auto_test/live_room/subscriber_page.md)

## 4. 验收标准

- [ ] 主播状态和观众可见状态一致。
- [ ] 开播、观看、停止和异常断线均有媒体服务证据。
- [ ] 不能用直播列表出现代替实际媒体播放验证。

## 5. 当前覆盖与阻塞

- 现有直播页面计划中有较多阻塞项，依赖真实媒体服务和发布者权限。
- 开播会产生对外可见内容，默认只在隔离环境执行。
- 2026-08-09：本地直播状态测试通过；媒体服务、主播/观众双账号和隔离开播条件不足，开播、观看媒体和停止后的状态闭环保持 `BLOCKED`。
- 直播列表或页面状态出现不能替代真实推流/播放证据。
- 2026-08-17（DEMO-FLOW-20260817）：后端路由只读探查（`imboy_router.erl`）：直播 API 共 6 个端点——`/api/v1/live_room/{list, my_list, create, start, stop, detail}`；`list/my_list/detail` 为只读，`create/start/stop` 为写入。
- 2026-08-17（DEMO-FLOW-20260817）：本地登录后只读回读（测试账号 13900001002，未执行任何写入）：`list` → `code=0` 空列表（`total=0`，正常空态）；`my_list` → `code=0` 空列表；`detail?room_id=999999999999` → 业务错误「直播间不存在」（无效房间边界正确；注意参数名是 `room_id` 不是 `id`）。
- 2026-08-17（DEMO-FLOW-20260817）：生产匿名探测 `GET https://pro.imboy.pub/api/v1/live_room/list` → HTTP `200` + `code=902 签名验证失败`，入口路由可达且签名中间件正常（alpha.36，无 502/404）。
- 2026-08-17（DEMO-FLOW-20260817）：本地无头复跑 `live_room_list_provider_test.dart` `12` 项全部通过，覆盖直播列表加载、分页 loadMore、加载态防重入等状态逻辑。
- 开播（`create/start/stop`）保持 `BLOCKED`：① 生产写入红线禁止创建/开播直播间；② 本地后端 `config/sys.local.config` 无 `livekit` 配置段（与 DF-21 `rtc/room/join` 500 同根因），即使本地写入也无可用 LiveKit SFU 签发推流凭证；按约束不干预后端进程与配置。
- 观看媒体保持 `BLOCKED`：无推流源、无观众端媒体环境；列表空态与页面状态不能替代播放证据。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/live_room_flow_test.dart`；默认只做列表和订阅页冒烟，真实开播另设受控任务。
