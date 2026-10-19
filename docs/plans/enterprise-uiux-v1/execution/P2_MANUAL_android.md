# P2 原生验收（Android）— T31.a — MANUAL_PENDING

> kind=manual｜required_for_local=false｜**状态：MANUAL_PENDING（诚实记账）**

## 原因

本执行环境无 Android 真机/桌面运行目标与人工操作者：卡要求按平台
case 表逐项进入页面、执行单一交互并保存截图/录屏或读屏记录
（build_sha、OS、device、theme、system-font 逐项登记）。自动会话无法
诚实产出这些证据——不伪造。

## 待人工执行（一旦具备设备）

- 按本平台case表进入指定页面或状态。
- 只执行该case指定的一项交互。
- 核对断言并保存截图/录屏或读屏记录。

## 输入就绪情况（自动侧已备）

- 候选 K = `571f7aaf7`（T29 冻结；等级 PARTIAL_BLOCKED，e2ee 范围外套件见 FINAL_GATES.md）
- 结构矩阵：P2_MATRIX.md（全部配置 executed）
- golden：P2_GOLDEN_MANIFEST.json + sealed（312 全量的一部分）
- 行为回归：PP2_REGRESSION.md（LEGACY 全绿）

## 通过条件

每 case 有 case_id、build_sha、OS、device、theme、system-font、观察与
证据路径；失败不可改成缺环境；其他平台不计入本卡。
