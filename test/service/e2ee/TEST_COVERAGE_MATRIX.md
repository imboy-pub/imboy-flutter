# E2EE v2 测试覆盖矩阵（B.5）

> ADR 08 §4（威胁-守护矩阵）+ ADR 11（向后兼容矩阵）→ 对应测试文件与覆盖状态。
> 图例：✅ 已覆盖（自动化断言） · ⚠️ 部分覆盖 · ❌ 未覆盖（原因见备注）。
> 原则：以现有实现为基础补测试，不改协议设计、不新增功能；能模拟的不依赖真机、不用 TEST_PHONE。
> 路径前缀：`app` = `imboyapp/`，`be` = `imboy/`。

---

## 1. ADR 08 §4 威胁-守护矩阵（16 项）

| # | 防御点 | 威胁 | 测试文件 | 状态 |
|---|---|---|---|---|
| 1 | 服务端零密码学 | T1,T3 | `be scripts/check_server_zero_crypto.sh`（接入 backend-ci.yml） | ✅ |
| 2 | 私钥永不落 DB | T3 | `be src/repo/olm_identity_repo.erl`（仅公钥列）+ migration 41 DROP | ✅（结构级） |
| 3 | Per-message PFS（Olm DR） | T5 | — | ❌ 需 vodozemac 运行时/真机，headless 不可模拟 |
| 4 | Post-Compromise Security | T5 | — | ❌ 需真机 ratchet 推进 |
| 5 | AEAD（AES-256-GCM）篡改 | T4 | `app test/service/e2ee/threat_model_guard_test.dart`（aes_gcm_tamper_fails，**B.5 新增**：篡改密文/错密钥/错 AAD 均抛） | ✅ |
| 6 | Ed25519 身份键签名 | T2,T4 | `be test/logic/e2ee_trust_logic_tests.erl`（Ed25519 验签往返，B.3.3） | ⚠️ 后端验签机制已测；客户端 identity_blob 验签未落地 |
| 7 | Safety Number | T2,T8 | — | ❌ 客户端 SN 算法未实现（ADR 06 客户端流程未落地，本轮不做 Flutter） |
| 8 | Signed Capabilities | T2 | `app test/service/e2ee/capability_negotiator_test.dart`（cap_sig_tampered_rejected） | ✅ |
| 9 | 本地降级告警 | T2 | — | ❌ B.2 发送侧未做（`useOlmForC2C=false`） |
| 10 | OTK 原子 claim | T7 | `be test/logic/olm_identity_logic_tests.erl` + `be scripts/verify_device_api_sql.sh`（claim UPDATE 审计语义，B.3.2） | ⚠️ 单次 claim 语义已测；100 并发 SKIP LOCKED 未压测 |
| 11 | room key 域一致性 | T7 | `be test/logic/group_e2ee_logic_tests.erl`（后端已落地） | ✅ |
| 12 | 消息重放/乱序 | T7 | 应用层 `msg_id` `ON CONFLICT DO NOTHING` 去重（已存在） | ⚠️ msg_id 去重已存在；ADR 05 message counter 未定义/未测 |
| 13 | KDF 可迁移（PBKDF2→Argon2id） | T6 | `be test/logic/e2ee_backup_logic_tests.erl`（PBKDF2 往返） | ⚠️ PBKDF2 已测；argon2id 迁移未实现（ADR 09-R5 本轮保留 PBKDF2） |
| 14 | Trust State 审计 | T2,T8 | `be test/logic/e2ee_trust_logic_tests.erl`（T-06-11 append-only / T-06-12 验签失败拒写 / T-06-13 广播，B.3.3） | ✅ |
| 15 | Device identity 版本单调 | T9 | — | ❌ 客户端 `highest_seen_identity_signed_at` 比对未实现 |
| 16 | Megolm session rotate 单调 | T9 | — | ❌ 需 vodozemac 运行时/真机 |

**小计**：✅ 6 · ⚠️ 4 · ❌ 6。

---

## 2. ADR 08 §4 附加（客户端地基守护，非 16 项但同矩阵思想）

| 防御点 | 威胁 | 测试文件 | 状态 |
|---|---|---|---|
| Olm pickle key CSPRNG | T5 | `app test/service/e2ee/threat_model_guard_test.dart`（olm_pickle_key_csprng，B.2.1） | ✅ |
| Registry 路由完整性/无静默 fallback | T2 | `app test/service/e2ee/threat_model_guard_test.dart`（registry_routing_completeness，B.2.1） | ✅ |

---

## 3. ADR 11 向后兼容矩阵

| ADR 11 条目 | 测试文件 | 状态 |
|---|---|---|
| §1 协商交集（capability negotiation + SECURITY_RANK） | `app test/service/e2ee/capability_negotiator_test.dart` | ✅ |
| §2 `rsa-oaep` encrypt 抛 UnsupportedError（防降级 T2） | `app test/service/e2ee/e2ee_bootstrap_test.dart` | ✅ |
| §2 `rsa-oaep` decrypt 永久保留（历史消息） | `app test/service/olm_suite_routing_test.dart`（RSA 路由） | ✅ |
| §2 `megolm`/`olm` active，`mls` reserved（未注册，version=0） | `app test/service/e2ee/e2ee_protocol_test.dart`（mls 占位）+ registry all() | ✅ |
| §3 metadata v1 legacy 解析（3 种历史字符串） | `app test/service/e2ee/e2ee_protocol_test.dart`（fromMetadata 兼容矩阵） | ✅ |
| §3 metadata v2 三元组优先于 v1（双写读取） | `app test/service/e2ee/e2ee_protocol_test.dart`（v2 优先于 v1） | ✅ |
| §3 双写期发送同写 v1+v2 字段 | — | ⚠️ fromMetadata 双向已测；adapter encrypt 双写需 vodozemac，headless 未测 |
| §6 未知套件 → FormatException/legacy 兜底 | `app test/service/e2ee/e2ee_protocol_test.dart` + `e2ee_bootstrap_test.dart` | ✅ |
| §4 服务端协议无关透传 | `be scripts/check_server_zero_crypto.sh` + 现有 e2ee 透传测试 | ✅ |

**小计**：✅ 8 · ⚠️ 1 · ❌ 0。

---

## 4. 未覆盖项的共同原因与后续归属

| 原因 | 涉及条目 | 归属 Slice |
|---|---|---|
| 需 vodozemac 原生运行时/真机（headless 不可模拟 Olm/Megolm ratchet） | §4.3/4/16 PFS/PCS/Megolm rotate | 真机集成（需设备，本轮排除） |
| 客户端流程未实现（Safety Number / rollback 比对 / 降级告警） | §4.7/9/15 | B.2 发送侧 + ADR 06 客户端流程（未改 Flutter，本轮不做） |
| 功能本轮不实现（argon2id 迁移） | §4.13 | ADR 09-R5 保留 PBKDF2，未来 revisit |
| 并发压测未做（100 并发 claim） | §4.10 | 可后续加并发集成脚本 |

---

## 5. 实现与 ADR 一致性观察（不擅自修改，仅记录）

1. **§4.11 room key 域一致性 / §4.6 Ed25519 签名**：后端已具备验签机制（`e2ee_trust_logic` 用 `crypto:verify(eddsa)`），但 **客户端对设备列表 `identity_signature` 的验签（ADR 03 §8.2 步骤 1）尚未实现**——属 Flutter 消费侧，本轮不改 Flutter，标为 ⚠️/❌。
2. **§3 双写期（ADR 05 §4）**：`ProtocolSuite.fromMetadata` 读取侧双向兼容已测；写入侧双写（adapter encrypt 同写 v1+v2）依赖 vodozemac 运行时，headless 无法断言字段同存，需真机或将 metadata 构造逻辑从 encrypt 中剥离（属重构，本轮不做）。
3. 以上均为**覆盖缺口**，非实现与 ADR 冲突；未发现需修改架构的不一致。

---

## 6. 本轮（B.5）净增

- `threat_model_guard_test.dart`：`aes_gcm_tamper_fails`（T4）从 skip 占位转为 4 个真实断言（正常往返 + 篡改密文 + 错密钥 + 错 AAD）。
- 本覆盖矩阵文档。
- 未新增功能、未改协议实现、未依赖真机/TEST_PHONE。
