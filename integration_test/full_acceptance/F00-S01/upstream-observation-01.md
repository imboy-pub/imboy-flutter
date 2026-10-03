# 上游活动观察 #01 — 2026-10-03T05:1xZ（本地 13:1x）

> F00-S01 的追加观察记录（不改写历史快照 input-snapshot.json，只追加）。
> 全程只读上游目录，未修改/暂存/覆盖任何上游文件。

## 观察

上游 `imboy/docs/design/2026-10-03-e2ee-production-excellence/` 在本地
11:44–11:58（本会话工作期间）新增 3 项产物，从 2 文件变为 5 项：

| 产物 | 时间 | 性质（据文件自述，浅读） |
|---|---|---|
| `attack-matrix.md`（18.6KB） | 11:44 | C11 卡：AC-22/AC-23 攻击矩阵与真实旅程合同；**自称"尚未执行任何真实旅程"**；引用 run id `run-20261003-094804` |
| `fixtures/`（3 文件） | 11:52–11:58 | generate.escript / vectors.json / verify_python.py 测试向量体系 |
| `identity-transparency-profile.md`（28.3KB） | 11:56 | 身份透明 profile（未细读） |

## 对本计划的影响判定

1. **plan.md SHA 未变**（维护核对 6/6 绑定一致）→ 不构成合同 1.3 的
   "上游变更 plan/SHA/schema/原生库/配置"情形，**不触发失效重集成**，
   既有证据与绑定全部保留有效。
2. **verified_stage 仍为 UNKNOWN**：文件落盘 ≠ 运行账本交接。attack-matrix
   自称尚未执行真实旅程；run-20261003-094804 只是被引用的 ID，handoff.json
   仍未收到。**不能据此推定任何上游 C 卡 PASS**（合同 1.1/1.2 不变）。
3. **并行执行者确认活跃**：与用户此前"主计划并行执行"告知相互印证的间接
   证据（此为上游 E2EE 计划的执行者；主计划 full-product-acceptance 的并行
   方仍无踪迹，公共位置冻结维持）。
4. 后续核对应把上游目录基线更新为 5 项；若出现 handoff.json 或 plan.md
   SHA 变化，按合同 1.3 走失效/重核验流程。

## 维护核对 #01 的两处修正

- `HEAD_DRIFT: imboyadmin` 为**核对脚本自身笔误**（expected 手写 997971a1，
  实际与快照完整 hash 完全一致 997971a8829…），非真实漂移。
- `UPSTREAM_DIR_CHANGED` 由本观察吸收为登记项，非缺陷。
