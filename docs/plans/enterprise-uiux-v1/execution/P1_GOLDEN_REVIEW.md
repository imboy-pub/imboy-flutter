# P1 GOLDEN REVIEW — imboy-enterprise-uiux-v1（T22.b）

> 审查身份：**SELF_REVIEW_ONLY**（当前会话无独立审查工具/第二审查人；
> 不伪造 INDEPENDENT 结论）。封存工程基线 ≠ 产品 UX 人工通过。

## 1. 封存事实

| 项 | 值 |
|---|---|
| 封存目录 | `runtime golden/p1/sealed/p1/`（git 外运行时区） |
| 数量 | 120（= T22.a 候选全量） |
| hash 清单 | `sealed/sealed_hashes.json`（sha256 逐张） |
| 封存方式 | 候选直接拷贝封存（首次生成，无 W0 旧基线可比较；全部 NEW_SCENARIO） |
| 零 diff 复跑 | `flutter test test/uiux/golden/p1_golden_test.dart`（**不带任何 update 参数**）→ 120/120 通过（像素零 diff），退出码 0 |
| 不可变性 | sealed 目录无任何工具写路径；重跑比较只读；`p1_missing_or_changed_sealed_file_fails` 由比较模式天然覆盖（缺文件/内容变化即比较失败） |

## 2. 逐张结论（组审声明）

120 张按 5 场景组审（同场景仅平台/视口/主题/缩放维度差异，语义断言
一致），manifest 仍逐配置登记：

| 场景组 | 张数 | review 结论 |
|---|---|---|
| content-long-name | 24 | PASS — 长名截断（ellipsis）无溢出；紧凑 HeaderBar 无重复大标题（P1-01） |
| stats-disabled | 24 | PASS — 无骨架占位；订阅数兜底直显（P1-02） |
| initial-error | 24 | PASS — 图标+标题+说明+重试两段结构（P1-03）；无 raw exception/URL |
| empty | 24 | PASS — 空态零孤立日期（P1-07）；只读形态无发布 CTA |
| filters-expanded | 24 | PASS — 高级筛选展开（标签+全部·精华）与搜索常驻行同屏（P1-06/D09） |

差异理由：全部为 NEW_SCENARIO 首次封存（无 before 基线可 diff）；
每张图 sha256/env/input/requirement/task 见 P1_GOLDEN_MANIFEST.json。

## 3. 边界声明

- 本审查为**工程基线封存**：同一 GOLDEN_ENV 内的像素回归判定依据，
  **不构成**产品 UX 人工通过；人工样张核对（before/after/diff 与
  可读性）为 manual_steps，保持 MANUAL_PENDING 记账。
- 恢复（rollback）后**不得**自动 update：比较模式失败即回到原页
  修复（failure_route），基线变更必须走 T22.a 重新生成 + 新审查。
