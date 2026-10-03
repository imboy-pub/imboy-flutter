# F15-S01 写者声明（WRITER CLAIM）

- **写者**：ZCode 会话（同 F00-S01/F00-S02 写者）
- **身份**：F15-S01「路由与 WS 清单」静态枚举产出
- **写入时间**：2026-10-03T04:3xZ（本地 12:3x）
- **产物**：`route-inventory.tsv`（791 条 v2）、`ws-inventory.tsv`、
  `open-whitelist.tsv`（39 项）、`stats.json`、`README.md`、本文件、`state.json`

## 职责边界（execution-contract 第 4 节 F15-S01 行）

- 交付：operation 矩阵——已按 `section/path/handler/action/open/option/kind` 全列。
- 「本地可枚举」✓：全部来自 `imboy/src/imboy_router.erl` 源码解析，非 OpenAPI。
- 「不能只看 OpenAPI 存在」✓：本清单直接解析 router 源码，且标注了 OpenAPI
  无法表达的三层事实（见 README）。

## 对并行执行者的约定

同 F00-S01 条款：本目录本会话独占至移交；接管/合并前追加记录；公共位置冻结；
源码仓只读（本次未修改 imboy 任何文件）。若并行方已有等价清单，按并行证据
合并处理，双方保留、Coordinator 裁决。
