# 存量集成测试健康检查报告（2026-09-01）

> 执行者：auto_test 循环会话 | 设备：华为 MRD-AL00（EMUI 9，armeabi-v7a）+ macOS 宿主
> 后端：本地 127.0.0.1:9800（strict E2EE：e2ee_mode=required / storage_mode=secure_e2ee）
> 结论：**68 个测试文件 100% 目录覆盖扫描，28 个文件级 PASS（约 90 用例），39 个 skip/阻塞全部定性归因，1 个 P0 产品 bug 修复，6 处测试适配落地。无未知悬置。**

---

## 一、总账

| 结果 | 数量 | 说明 |
|---|---|---|
| 文件级 PASS | 28 | 真机 + macOS 宿主 + dart test，约 90 用例 |
| skip/阻塞（全部定性） | 39 | 五型，见 §三 |
| 产品 bug | 1 | **P0：C2G PFv3 恒判 context_mismatch_gid**（已修 imboyapp `1ca36ed4`） |
| 测试适配/修复落地 | 6 | 见 §四 |

## 二、分目录结果

| 目录/文件 | 数量 | PASS | 主要发现 |
|---|---|---|---|
| 根目录（e2ee_*/sqlcipher） | 7 | 6 | **P0 gid 绑定 bug 暴露于此**；interop 需 TEST_INTEROP_ROLE 双设备 |
| chat/ | 8 | 6 | voice 断言 strict 化改造；quick_reply Cupertino 化适配 |
| group/ | 5 | 5 | 全只读类，真机全绿 |
| smoke/mine/contact/auth | 7 | 4 | 注册/改密/新朋友 3 skip 均为设计性或数据依赖 |
| channel/ | 5 | 1 | 4 skip=无已订阅/可发布频道数据 |
| demo_flow/ | 28 | 10 | 宿主类 +37 用例；双设备协作 4；参数化夹具体系 |
| wallet/ | 1 | 1 | E2EE 恢复指南弹窗处理（全新环境首登必弹） |
| sqlite_migration/ | 2 | 2 | **kill_replay 两阶段编排实证通过**（KILLED_ROLLED_BACK） |
| two_client/ | 3 | 0 | QA 账号（uid4 等）凭证依赖的双端探针 |
| patrol/ | 2 | 0 | 工具链未接通（test_bundle Unknown package） |
| all_tests.dart 等聚合 | 3 | — | 聚合入口/已覆盖，无需单跑 |

## 三、skip/阻塞五型定性

1. **双设备协作（4+）**：dual_account 系列、interop 系列。需 `TEST_DUAL_ROLE=sender/receiver` + `TEST_DUAL_RUN_ID` 配对，单设备 sender 半程已实证（等 receiver 超时）。→ 需第二台设备。
2. **数据依赖**：group_chat（无 C2G 会话）、channel 系列（无订阅/可发布频道）、paid_channel（需 `TEST_PAID_CHANNEL_ID` fixture 产出）、confirm_new_friend（无待接受申请）。→ 解法=测试自带 API fixture 造数（c2c_e2ee_send_render 已示范）。
3. **参数化夹具**：local_e2ee_group_fixture（`TEST_LOCAL_E2EE_GROUP_FIXTURE=true` + owner/member uid + `LOCAL-E2EE-GROUP-` 前缀标题）、join_probe（专用群主 uid=50）、role_flow（授权账号 uid=4）、readback（标题+公告双标记）、moments/red_packet。
4. **专用账号/环境**：pro_readonly（生产只读契约账号 118@imboy.pub）、two_client（QA 账号）、patrol（工具链原生配置未接通）。
5. **资金域**：wallet_transfer（资金写授权门）。

## 四、本轮修复/适配清单（均已提交）

| 提交 | 内容 |
|---|---|
| `1ca36ed4` | **P0 修复**：C2G PFv3 恒判 context_mismatch_gid——帧三段均无 gid 字段，_validateContextBinding 4.5 步改条件化；e2ee_group_outbound_frame 断言 v2→v3 信封适配 |
| `9c7cd16a` | quick_reply 断言适配 Cupertino 化（FAB/对话框/拖拽把手三处）+ 真机 PASS |
| `8b51ff07` | demo_flow 两处：同集多群拍板语义钉死（旧幂等断言反转）+ DF-08 建群后补 set_e2ee_mode fixture |
| `9e269601` | wallet E2EE 恢复指南弹窗处理 |
| `4226a71a` | dismissRecoveryGuide 提升共享 helper；e2e_chat 定性（取代性覆盖，建议废弃/改造，**待拍板**） |
| `bad46302`~`ebe3e08c` | FlowApiClient md5 门槛、smoke 前置链、明文拒收回归、加密全链发送、voice strict 化（前序） |

## 五、复跑指南

### 三分法（按文件性质选跑法）
- **纯 dart test**（仅 import dart:* + ApiTestClient，头部注释写明「纯 dart test，无设备」）：`dart test <file> --concurrency=1` + 环境变量
- **Flutter binding + 宿主环境变量**（import flutter 但读 Platform.environment）：`flutter test <file> -d macos` + 环境变量
- **真机**（其余全部）：`flutter test <file> -d <device>` + dart-define 全套

### 真机全套 dart-define
```
APP_ENV=local
API_BASE_URL=http://127.0.0.1:9800          # 测试客户端用
API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 # app 内覆盖（必传！烘焙 IP 会失效）
WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws
TEST_PHONE=at20260830210132a@at.local TEST_PASSWORD=admin888
SOLIDIFIED_KEY_OVERRIDE=<后端 sys.local.config 的 solidified_key>
SOLIDIFIED_KEY_IV_OVERRIDE=<同文件 solidified_key_iv>
```
### 宿主环境变量（dart test / flutter test -d macos）
```
IMBOY_SOLIDIFIED_KEY=<同上 solidified_key>
API_BASE_URL=http://127.0.0.1:9800
TEST_PHONE / TEST_PASSWORD / TEST_PHONE2 / TEST_PASSWORD2（at 账号对）
TEST_ALLOW_API_WRITES=true（总门）
分域附加：TEST_ALLOW_CHANNEL_WRITES / TEST_ALLOW_PAID_CHANNEL_WRITES /
TEST_ALLOW_DUAL_ACCOUNT_PROD_WRITES / TEST_ALLOW_DUAL_GROUP_PROD_WRITES /
TEST_ALLOW_DUAL_ACCOUNT_GROUP_PROD_WRITES / TEST_ALLOW_DUAL_ACCOUNT_GROUP_COLLAB_PROD_WRITES
```

### 运行注意（实证教训）
- zsh 下 dart-define 必须用数组 `"${DEFS[@]}"`，`$VAR` 不分词会静默失效（症状=日志出现 pro.imboy.pub）
- flutter test 结束会卸载 app 且 harness APK 手动启动卡死——跑完需 `flutter build apk` 重装恢复
- 每次 invocation 重装 app：**前次造数必然清失，同 invocation 多文件也不共享 app 数据**——数据依赖测试必须自带 fixture
- 并行会话编辑期编译窗口不稳定：发批次前 `dart analyze` 轮询抢窗口
- 安装卡 Installing 超 2 分钟：kill flutter 进程 → `adb install -r` 手动装 → 重跑（EMUI 安装服务间歇抖动）

## 六、遗留待办

| 项 | 归属 |
|---|---|
| 裸 WS 下行 0 帧（DF-08：ACK/policy_violation 收不到而后端落库正常；websocket_ds 07-25 后零改动，非近期回归）。服务端门与返回链逐环验证正常；**根因范围锁定：下行投递依赖在线表注册（user_logic:online），同 uid 多连接并存时裸 WS 注册被真机连接覆盖**——需后端侧确认 | 待排障（后端侧） |
| e2e_chat 废弃/改造（被 c2c_e2ee_send_render 取代性覆盖） | **待拍板** |
| strict 群双真机群聊收发走查（P0 修复后的端到端人工验收） | 需第二台设备 |
| patrol 原生配置按官方文档接通 | 待立项 |
| 数据依赖类测试自带 API fixture 化（系统性改造） | 待立项 |
