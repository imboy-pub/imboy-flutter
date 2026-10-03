# F00-S01 写者声明与并行协调记录（WRITER CLAIM）

## 写者身份

- **会话**：ZCode（本机 leeyi@darwin），2026-10-03 本轮会话
- **角色自认**：F00-S01 执行者（execution-contract 第 4 节行 1：Coordinator 自留卡）
- **声明时间**：2026-10-03T04:05:00Z（本地 12:05）
- **触发原因**：用户于本轮中途告知主计划
  `imboy/docs/plans/2026-10-03-full-product-android-macos-integration-acceptance-v1.md`
  **正在并行执行**，要求注意协调。

## 本会话已写入清单（全部限于本卡目录，无公共位置写入）

| 文件 | 说明 |
|---|---|
| `input-snapshot.json` | 六项哈希绑定实测、三仓 HEAD、漂移登记、上游 UNKNOWN 固化 |
| `e2ee-protected-paths.tsv` | E2EE 所有权只读候选 85 行（imboyapp 54 + imboy/src 31） |
| `WRITER-CLAIM.md` | 本文件 |
| `README.md` | 卡说明与验收核对 |
| `proposed-run-root/` | RUN_ROOT 结构提案**副本**（未写入 .Codex/runs 公共位置） |

## 侦察结论（2026-10-03T04:07:00Z）

- `full_acceptance/` 下无其他写者产物；`.Codex/runs`、`.locks`、
  `.Codex/coordination`、三仓工作区最近 15–30 分钟无并行写痕迹。
- 现存锁 `cd952bd4….lock` 心跳 2026-09-25，早已失活，与本计划无关。
- 并行执行者对本机文件系统**当前不可见**（可能在别处/别会话/未落盘）。

## 对并行执行者的协调约定（依 execution-contract 第 2 节）

1. **本卡目录唯一写者 = 本会话**，直至本声明被推翻或移交。若你（并行方）持有
   Coordinator 身份并要重做/合并 F00-S01：本目录产物可整体验收、接管或要求重做，
   但请勿静默覆盖；先在本文件追加你的身份与动作记录。
2. **公共位置冻结**：在并行方身份确认前，本会话不再写任何共享路径
   （`.Codex/runs/` 根、resource-registry、lease 公共表、catalog、公共 fixture、
   runner）。RUN_ROOT 提案见 `proposed-run-root/`，待唯一 Coordinator 确认后
   由其提升为公共文件。
3. **lease_root 候选已登记**（仅提案，未占用）：
   - run 级：`.Codex/runs/.locks/`（原子 mkdir `<sha256>.lock/owner.json`，
     字段 run_id/pid/pgid/process_start/heartbeat/epoch/supervisor_id，与合同
     第 2.4 条兼容，需增补 plan/run/card/heartbeat/namespace）
   - 协调级：`.Codex/coordination/locks/`
   - 状态：`PENDING_PARALLEL_PEER_CONFIRM`——需要两个执行方在同一登记处互见后生效。
4. **上游资源登记仍 NOT_FOUND**（execution-contract 第 2.2 条降级条款继续生效）：
   取得登记前，任何一方不得占用设备/Flutter SDK/macOS 容器与钥匙串/端口/DB/
   Garage 前缀等共享资源。
5. 若你已在别处产出 F00-S01 或等价输入绑定，请以"并行证据合并"处理：
   双方产物都保留、各标写者，由 Coordinator 裁决唯一有效版本，不得互删。

## 移交即弃条款

本会话若在后续轮次被用户指派其他卡，此声明对本卡目录的独占随之失效，
新写者在此追加记录即可接管。
