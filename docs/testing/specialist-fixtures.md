# 专项 fixture 与证据合同

基础命令、状态和计数见 [统一测试执行说明](execution.md)。本页补充已有验收和 owned-session
目标需要的真实输入。准备输入通过不代表设备、后端或完整回归通过；执行器不创建授权、
抢占租约、清理设备数据或连接生产服务。

## full_acceptance 三目标

billing、organization 为 Android/macOS；navigation 为 Android/macOS × channel enabled/disabled。
这些 Git 跟踪的目标即使被 ignore 规则匹配也必须进入归属检查。

| 环境变量 | 内容 |
|---|---|
| IMBOY_ACCEPTANCE_EVIDENCE_ROOT | 独立验收证据根目录 |
| IMBOY_ACCEPTANCE_CONTEXT | 根目录内的 context JSON 相对路径 |
| IMBOY_ACCEPTANCE_CONTEXT_SHA256 | 独立提供的 context SHA256 |
| IMBOY_ACCEPTANCE_LEASES_DIR | 现有 state.py 的真实设备租约目录 |
| IMBOY_BACKEND_ROOT / IMBOY_ADMIN_ROOT | 可选并排源码位置；默认 imboy / imboyadmin |

Context 的 `schema_version=1`，包含 `frozen`、`report` 两个 `{path, sha256}` 描述符和
`instances` 数组。每项精确声明 target/platform/product_profile/role、
`case={case_id, platform, profile, role_variant}`，以及 authorization/runtime/fixture/device
四个描述符。路径必须位于证据根内，不含 symlink 或目录越界；同一实例恰有一项。

复用 `acceptance_preflight.audit_preparation_inputs` 核对冻结的 required cases、三个干净
候选仓库的真实 HEAD/祖先关系、source/config/build/fixture/device 五类 runtime bindings
和既有执行历史。四个描述符必须分别绑定为 config/config/fixture/device。navigation 的
case.profile 为 enabled 或 disabled；其他目标按产品 profile。

首次准备只允许 frozen.attempt_index 与 report.attempts **同时显式为空列表**，由 adapter
以 `allow_initial_empty_history=True` 调用。原 CLI 和执行后验收默认仍要求历史；缺字段、
遗漏已存在记录或改写历史均失败，不自动生成历史。

| 输入 | 必需字段与约束 |
|---|---|
| authorization | 实际 approved_by/approval_ref、approved=true、scope=isolated-device-preparation、未过期 expires_at；精确 target/platform/product/role/device/UID、runtime/fixture hash、lease |
| runtime | app_env=local、字面 loopback API/WS URL及显式端口、external_services_disabled=true、与 frozen candidates 一致的三个 heads |
| fixture | synthetic=true、fixture_id、values；所有目标都需正 int64 TEST_EXPECTED_UID |
| device | 实际 device_id/platform、现有 lease owner；navigation 另需 0 < logical_width < 600 |

billing 的 fixture values 还需 ACCEPTANCE_PLAN_NAME、非负整数 ACCEPTANCE_PLAN_PRICE。
organization 还需 ACCEPTANCE_ORG_ID/NAME、ACCEPTANCE_DIRECTORY_MEMBER_ID/NAME。
navigation 要求 runtime.channel_enabled 与所选组合一致、experience=chat；Dart 再检查真实
AppFeatureRegistry 和实际窗口宽度，不通过 define 伪装产品行为。

租约沿用 state.py 的 run/step/agent/process/resource。资源为 ANDROID_DEVICE:<id> 或
MACOS_DEVICE:<id>；真实 owner.json 必须匹配，heartbeat 有限、非未来且未过期。资源所有者
维持租约，执行器不获取、接管或续租。调用方的同名 fixture 环境值若与固定输入矛盾则阻塞。

验证成功后才派生 ACCEPTANCE_RUNNER_VERIFIED 及各 provenance define。输入记录保存为
acceptance-environment.json，明确标注 DEVICE_PREPARATION_INPUTS_ONLY、product_pass=false。
单独设置 RUNNER_VERIFIED=true 无效；hash 也不能认证虚构的批准者或替代真实授权。

## MC owned Android 与 coordinator

负例目标保留 live/reconnect 两个实例，使用不同的可丢弃 fixture、账号存储和 lease context。
设备变量为 IMBOY_EXECUTION_DEVICE_MC_LIVE / IMBOY_EXECUTION_DEVICE_MC_RECONNECT。
两个模式不能靠复用已登录 APK 冒充隔离；可使用独立设备或分别准备的实例分片后对账。

| 环境变量 | 用途 |
|---|---|
| IMBOY_MC_OWNED_CONTEXT_LIVE 与 _SHA256 | live 私有 context |
| IMBOY_MC_OWNED_CONTEXT_RECONNECT 与 _SHA256 | reconnect 私有 context |
| IMBOY_MC_OWNED_CONTEXT_POSITIVE 与 _SHA256 | owned 正例 context |
| IMBOY_MC_OWNED_CONTEXT 与 _SHA256 | 单实例的显式备用名称 |
| IMBOY_MC_OWNED_LEASES_DIR | 真实活动设备租约目录 |

Context 必须为绝对路径、当前用户所有、0600、无 symlink，且匹配独立提供的 SHA256。
共同字段：package=pub.imboy.app.gzcustomer、device_id、不同的 api_port/bootstrap_port
（1024..65535）、合成 uid/channel_id/group_id、channel_name、至少32字符 bootstrap_key、
精确 lease owner。正例还需 MC_POST_TAG、MC_POST_QUERY、MC_EXPECTED_BODY。

负例额外使用现有 `scripts/mc22_owned_coordinator.py` 的 negative_mode、phase_path、
control_path、phase_key/control_key；重用其 validate_context。所有 endpoint 从已验证的
loopback 端口派生。调用方别名不能覆盖已固定的 Dart defines。使用 gzCustomer flavor、
禁用远程 push；当前编译产物需 channel，隔离会话返回 community runtime profile。

这些目标使用 owned bootstrap，不要求手机号登录，但仍需基础隔离 opt-in、签名 key/IV、
业务写入许可。Dart 继续验证空账号存储、物理 Android、合成身份和 session 合同。

执行器同时运行已有 coordinator 与真实 Flutter。coordinator 要求已准备好的 owned fixture
和 adb reverse mapping，发送真实 OS VIEW 并只调整其拥有的 mapping，finally 恢复它。
不创建 fixture、账号、数据库或授权。缺 context、lease、adb、隔离 app/fixture 为 ENV_MISSING。

coordinator 是 `coordinator-gate`，不计 Flutter 用例数。其 receipt 保存 instance_id/target/mode、
退出码、命令、context hash，以及工件内的 log/events/process receipt 和各自 SHA256。
最终汇总重读文件，验证精确阶段顺序、最终 coordinator_verified 和单调时间，并与父实例绑定。
仅退出0或仅父 Flutter PASS 均不足；私有 context 含密钥，不复制进可公开上传的工件。

## SQLite kill-replay 与离线 E2EE 入口

`integration_test/sqlite_migration/sqlite_migration_kill_replay_test.dart` 使用自己的
`imboy_wp7_kill/replay_N.db` 合成数据库，不登录、不连接后端、不使用客户数据库。
它需要 `prepare` 和 `verify` 两阶段，不能直接作为普通单设备目标执行。统一合同将它
归入 device-single，编排方式为 `sqlite-kill-replay`；目前只有 Android standard flavor
的 `adb` 控制器，对应应用包 `pub.imboy.app`。iOS/macOS 为 PLATFORM_NA；即使按其他
平台生成计划，Android 适用义务仍保留。

在明确用于本测试的物理 Android 设备上，准备 Flutter/Dart、项目锁定依赖、adb，以及
可安装 standard 测试应用的环境。设备 ID 必须显式提供；attempt 是 1 到 999999999 的整数，
用于隔离本次合成库。执行器只 force-stop 所选设备上的固定测试包，不清除包数据。

```bash
# 无设备、SDK 或凭证也能查看计划
bash scripts/run_kill_replay.sh --dry-run --output "$REPORT_DIR/kill-replay-plan.json"
# ANDROID_TEST_DEVICE 由调用者选择隔离测试设备，不设默认真实设备 ID
IMBOY_TEST_ISOLATED=true bash scripts/run_kill_replay.sh "$ANDROID_TEST_DEVICE" 1 \
  --artifact-dir "$REPORT_DIR/kill-replay"
```

运行器从 Flutter machine 的 print 事件读取相同 attempt 的 `kill_seeded`、`kill_ready`，
核对合成库命名空间，记录准备阶段证据前缀，再确认测试包 PID、受控 force-stop、确认 PID
消失。随后使用同一 attempt 执行 verify，沿用 machine events、进程退出码和零执行/skip
判定。成功还必须有 `KILLED_ROLLED_BACK`；缺 ready、错 attempt、漏过中断窗口、PID 未停止、
verify 非零/跳过或缺少任何阶段证据均不能通过。准备阶段是协调证据，不计业务用例；
最终计数只来自 verify。汇总重新核验阶段命令、进程收据、事件顺序和文件 SHA-256。

现有 Dart 在调用 `db.transaction` **之前**打印 `kill_ready`，因此这套证据证明“观察到就绪、
受控停止、重开后保留 v16 和数据”，不能精确证明停止发生在 SQLite 事务内部。更严格的
事务内杀点需要另行补充可观测契约和真实设备验证；不能靠更改报告措辞扩大结论。

`run_cross_platform_e2ee_interop.sh` 和 `run_cross_platform_e2ee_group_interop.sh` 也只转交
同一 device-pair profile 的对应目标。它们需要明确的 Android sender 和 macOS receiver，
由现有向量传递控制器执行 sender → receiver → final，保留每阶段机器事件及最终对账。
两个 wrapper 均支持 `--dry-run`；设备变量、原生加密库和角色准备按主说明，不再内置设备 ID
或用日志里的 PASS 文本作为结果。离线合成互操作不需要真实后端或产品登录。

## 其他专项

- Golden p1/p2/p3 及企业 OA 的 `t15_enterprise_layout_test.dart`：使用
  `golden_font_loader.dart` 的原登记环境。文本字体为
  `/Library/Fonts/Arial Unicode.ttf`，SHA-256 与许可说明以该源码为准。
  图标字体原路径为 `/Users/leeyi/dev/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf`
  和 `/Users/leeyi/.pub-cache/hosted/pub.dev/cupertino_icons-2.0.0/assets/CupertinoIcons.ttf`。
  在已有合法本机 SDK/缓存环境准备这些文件，基线维护者将三个精确绝对路径及对应
  SHA-256 写入 `IMBOY_GOLDEN_ENVIRONMENT` 的 `fonts`；文本哈希不能偏离源码登记。
  预检核验所有文件存在和字节，包括原 Dart loader 容错跳过的图标字体，缺失即 ENV_MISSING。
  其他机器不能用任意外部路径或不相关字体代替；迁移登记需要审查 loader 与基线环境，
  不自动复制或分发系统字体。专项 SDK 必须符合源码 `kFlutterVersionPin`（当前 3.47.7）及
  清单的 framework/engine revision。基线仍只允许仓内已批准文件，预检成功不是像素通过。
- RTC group：两台不同 Android、不同合成 UID、同一 TEST_GROUP_ID，要求真实远端 tracks。
  RTC negative matrix 使用真实 WS 和已有 mock 媒体，不额外要求真实 SFU。两者均需已核验的
  full-selected/RTC 真实编译产物；缺时为 ENV_MISSING。
- 相机：macOS、`IMBOY_REAL_CAMERA_SMOKE=true`、`IMBOY_CAMERA_PERMISSION_READY=true`。
  先为终端/IDE授权，准备合成场景。计划注入 IMBOY_REAL_CAMERA_REQUIRED=true；没有真实
  viewfinder 不得以原“无相机降级”路径声称拍照成功。
- j16c / j28b：消息注入或旧客户端 companion 的绝对路径和独立 SHA256 见主说明；当前仓库
  不包含这些外部 fixture，必须明确准备后执行，不能把现有单端文件当成配对完成。
- Patrol：读取本次 instrumentation JUnit 并校验 Dart case 对应关系。当前环境无 Patrol，
  未臆造 CLI 参数；真实版本的依赖解析行为仍需验证，源/lock变化会被指纹复核阻塞。
- Route quarantine：路由仍各自独立进程。需要纳入隔离中的路由时使用原 wrapper 的
  `--include-quarantined` 或 `IMBOY_SMOKE_INCLUDE_QUARANTINED=true`；这不提供 skip 豁免。
  已选目标仍 skip 会报 UNEXPECTED_SKIP，不能用范围过滤声称 full 完成。

本任务实际没有运行上述真实环境。准备完毕后先看统一计划，再执行目标及最终 summary，
分别报告工具、Flutter、后端、设备/双端和全量的证据等级。
