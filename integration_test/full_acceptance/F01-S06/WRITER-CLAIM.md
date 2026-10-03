# F01-S06 写者声明（WRITER CLAIM）

- **写者**：ZCode 会话（同前五卡写者）
- **身份**：坏样本数据集构造（合同 §6 条 1–8 + bonus）；verifier 本体实现属
  F01 唯一 owner（runner/catalog/公共 fixture 同源职责），本会话不越权实现
- **产物**：`bad-samples/`（9 样本 + index.json）、`README.md`、`state.json`
- **约定**：同前五卡条款；全部样本标 `is_verifier_fixture` 与
  `NEVER_COUNTS_AS_PRODUCT_PASS`；imboyapp 既有代码零修改
（`scripts/auto_test_lib/result.py`、`report.py` 只读引用其语义）
