# F01-S06 反造假坏样本数据集

> execution-contract 第 6 节：F01-S06 须构造独立坏样本，每个应非零且定位缺失项。

## 状态与诚实边界

**样本已构造，验证器未实现**——`SAMPLES_CONSTRUCTED_VERIFIER_NOT_IMPLEMENTED`。
"应非零"的实际执行依赖 F01-S06 在现有 auto_test 报告/结果库上扩展的验证器
（FINAL_COMMAND_REGISTRY producer = F01-S01 + F01-S06）。本数据集是验证器的
测试输入，全部标注 `is_verifier_fixture` 与 `NEVER_COUNTS_AS_PRODUCT_PASS`。

## 样本清单（bad-samples/）

| 样本 | 合同条 | 注入缺陷 | 必须定位 |
|---|---|---|---|
| BAD-01 | §6.1 | 缺父 ID / 未知 ID F99-A01 / 主键重复 | 三处各自报出 |
| BAD-02 | §6.2 | 删 seed 映射 / 隐藏新页面 / 歧义行标已核验 / placeholder oracle | 覆盖缺口与伪核验 |
| BAD-03 | §6.3 | app_head SHA 漂移 / 上游 plan 过期 / 缺祖先 | SHA_DRIFT 三处 |
| BAD-04 | §6.4 | exit0 零测试 / required skip / 仅截图 / 无接收端事实 | 假绿四特征 |
| BAD-05 | §6.5 | 路径逃逸 / worker 自签 verdict / 跨平台日志复用 | 证据污染三处 |
| BAD-06 | §6.6 | 缺设备写 N/A / iOS BLOCKED 宣称全过 | 适用性造假两处 |
| BAD-07 | §6.7 | 丢弃失败 attempt / 混合指纹合并 | 审计缺失 + MULTIPLE_ATTEMPT_MERGE_INVALID |
| BAD-08 | bonus | parsed 含 password 字段 | report.py SECRET_FIELD_REJECTED |
| GOOD-01 | §6.8 | 无（最小完整合成样本） | 结构门必须通过；绝不计入产品 PASS |

## 与现有代码的贴合依据

- attempt 结构与指纹六键（app_head/backend_head/target_sha256/config_sha256/
  fixture_fingerprint/device_fingerprint）对齐 `scripts/auto_test_lib/result.py`
  的 `ATTEMPT_FINGERPRINT_KEYS`；
- BAD-07 变体的判据直接引用 `classify_attempts` 的
  `MULTIPLE_ATTEMPT_MERGE_INVALID` 语义；
- BAD-08 对齐 `report.py` 的 `SECRET_FIELD_REJECTED` 门（该门已存在，样本用于
  防回归，不是新能力）；
- GOOD-01 的上游子格如实填 `verified_stage=UNKNOWN`、
  `claims.e2ee_production_qualified=false`（与 acceptance-set 一致）。

## 观察记录（供 F01-S06 实现时留意）

result.py `INFRA_RETRY_LIMIT=3`（3 连 infra 耗尽），而执行合同第 5 节写
"原尝试+最多 2 次"重试预算——两者粒度不同（一个是分类器判定阈值，一个是
重试预算），实现验证器时须确认口径，避免把合同预算误当分类器阈值。

## 已实现的准备入口

`scripts/auto_test.py acceptance-preflight` 是只读准备检查，不是最终验证器。
冻结描述文件必须使用整数 `schema_version: 2`，包含 `acceptance_ids`、
`required_cases`、三仓 `candidates`、`required_runtime_binding_ids` 和
`runtime_bindings`。报告必须给出对应的 case、candidate 和 runtime bindings。
第1版描述文件现在返回错误，不能沿用其历史成功记录。

每条 binding 包含唯一 `binding_id`、`kind` 和 `artifact`；后者为证据根内
相对 `path` 与64位小写 `sha256`。source、config、build、fixture、device
五类缺一即失败。冻结集合及其哈希必须由协调者独立提供；入口比对完整记录，
重算实际文件哈希，拒绝删项、改指纹、重复文件、越界路径和符号链接。

该门仅证明已列文件及绑定结构一致，不证明设备真实存在、运行配置真实生效、
源码枚举完整或业务通过。成功退出仍输出 `PREPARATION_INPUTS_ONLY` 和
`product_pass: false`；失败退出码为2。完整 §6 坏样本、真实旅程、attempt
审计、上游资格与用户UX评审仍是未闭合的最终门。

冻结描述还必须含独立固定的 `attempt_index`，每项为唯一 `attempt_id` 和
完整记录的 `record_sha256`。报告的 `attempts` 必须按原顺序精确对应。
哈希编码为完整记录的 UTF-8 JSON：键排序、非有限数拒绝、Unicode不转义、
分隔符为逗号与冒号且无额外空白。缺历史、删失败留成功、重排或改写均失败。
索引必须来自执行期独立记录，不能从最终报告自行生成后冒充完整历史。
该检查只证明相对索引的保留性，真实执行和独立索引完整性仍须另外验收。

## 精确原始用例事件组件

`auto_test_lib.acceptance_case_events.audit_case_event_artifact` 读取单个实际hash绑定的Flutter machine日志，校验非隐藏成功测试名称与协调者独立冻结的绑定全集精确相等。绑定行只含case_id、platform、profile、role_variant、test_name；必须覆盖传入的全部冻结required格子，且测试名称唯一。调用方必须先从独立固定hash加载冻结集合，不能根据日志反向生成绑定。

相同数量但不同名称、漏项、未知项、重复名称、hidden/skip required均拒绝。此组件只证明日志身份结构和产物完整性，不能证明日志真实执行、平台配置、业务事实或完整attempt来源；当前未接入最终CLI，不构成F01-S06或产品PASS。

只读入口已注册为 `python3 scripts/auto_test.py acceptance-case-events --evidence-root <run-root> --frozen-input <relative-json> --frozen-sha256 <independently-pinned-hash>`。单目标冻结输入使用schema_version整数1，必含required_cases、case_event_bindings、event_artifact（相对path与sha256）。此结构独立于acceptance-preflight的schema2；任一入口单独成功都不是总验收。

入口始终输出scope=RAW_CASE_IDENTITY_ONLY、product_pass=false及剩余门禁。退出0只表示该冻结集合与日志结构一致；错误返回2。入口不启动测试、不改证据、不根据worker报告生成冻结绑定。不同平台/profile/角色若同目标并发执行，冻结的完整测试名称必须唯一且能区分其格子；仍须另行验证运行时来源和真实业务事实。

## 运行记录组合入口

`acceptance-execution-preflight` 使用与 `acceptance-preflight` 相同的五个输入参数；schema2冻结输入额外必须包含非空case_event_runs。每组含完整required_cases子集、case_event_bindings、event_artifact及process_exit_code整数0。各组的四维键必须互斥且逐整行覆盖全量冻结required集合；原始日志路径和内容hash都不得复用。

该入口同时执行候选/运行指纹/尝试保留门及原始用例身份门，始终输出EXECUTION_RECORD_INPUTS_ONLY和product_pass=false。尚不能证明各组日志与独立attempt索引是同一次真实执行，真实业务事实、完整覆盖、UX和最终资格仍必须完成。
