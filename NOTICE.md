# NOTICE — 第三方许可证状态与本项目决策

## 当前依赖的许可证警示（2026-08-02 起）

本项目当前依赖：

- `flutter_vodozemac` / `vodozemac`（dart 绑定，famedly）— **AGPL-3.0**
- `vodozemac`（Rust crate 本体，matrix.org）— **Apache-2.0**

AGPL-3.0 义务在**分发**时触发（应用上架、交付买家私有化部署、公开仓库含该依赖的构建产物）：整个客户端可能被要求按 AGPL-3.0 开源，与本项目 MulanPSL2 + 商业 License 模式冲突。

## 项目决策（2026-08-02，leeyi）

**选择 ③：自建 Apache-2.0 FFI 绑定**——直接基于 Apache-2.0 的 vodozemac Rust crate 编写本项目自有绑定，替换 famedly 的 AGPL dart 绑定。实施任务跟踪于 `imboy/docs/guides/e2ee/standard/gap-matrix.md` X15。

**过渡期纪律**：在绑定替换完成前，任何分发动作（应用商店上架 / 交付买家 / 公开仓发布含 vodozemac 依赖的代码或产物）**暂停**；确需分发须回到该决策重选（①客户端 AGPL 开源 / ②购买 famedly 商业授权）。

## 其他主要加密相关依赖

- `pointycastle`（Dart RSA/AES 原语）— 见其包许可证
- `sqflite_sqlcipher`（SQLCipher 本地加密库）— 见其包许可证
- Erlang/OTP `crypto`（服务端验签）— Apache-2.0

> 完整密码学清单（原语/参数/版本/commit 锚）随审计就绪包 P5-2 任务生成。
