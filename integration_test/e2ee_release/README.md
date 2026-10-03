# E2EE Release Harness（C11 / run-20261003-094804）

AC-22（两账号真实 C2C）与 AC-23（四账号 C2G）真实旅程测试的 harness。
场景合同（前置 fixture / 步骤 / 双方 oracle / PASS 条件）见后端计划目录：
`imboy/docs/design/2026-10-03-e2ee-production-excellence/attack-matrix.md`。

## 结构

```
fixture_contract.dart        合成 fixture 合同（账号/设备/群/消息 ID/canary 命名规范）
harness_smoke_test.dart      harness 冒烟自检（flutter test 可离线运行）
harness/
  vodozemac_loader.dart      vodozemac 原生库加载（env var 优先）
  backend_transport.dart     传输抽象：内存替身（冒烟）+ RealBackendTransport stub
  simulated_device.dart      模拟设备：真实 vodozemac Olm + 生产 PFv3 信封
  malicious_proxy.dart       可控恶意代理注入器（W1–W4 注入点）
journeys/
  journey.dart               旅程定义类型 + JourneyCatalog 权威全集
  c2c_journeys.dart          AC-22 场景（S01–S06 / M01–M05）
  c2g_journeys.dart          AC-23 场景（G01–G06 / M01–M05）
```

## 冒烟自检运行方式

```sh
# worktree 根目录；dylib 指向主仓 build 产物（worktree 无 gitignored spikes 产物）
FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR=/path/to/imboyapp/spikes/e2ee-group/rust/target/release/ \
  flutter test integration_test/e2ee_release/harness_smoke_test.dart --reporter expanded
```

注意：`integration_test/` 不被 `flutter test test/` 扫到，必须显式指定本文件。

## 防伪边界（重要）

- 冒烟层 = 双端模拟设备 + 本地嵌入式服务器替身（内存消息总线 + 密文存储）。
  它只证明 harness 自身可用：fixture 合同合法、vodozemac 真实加解密工作、
  oracle 断言器有效、注入器能触发 fail-closed。
- **冒烟层不构成 AC-22/AC-23 证据**（与历史 `e2ee_cross_platform_interop_test.dart`
  合成 interop 同一判定口径）。
- 真实层入口 `RealBackendTransport` 是 stub，一律标注
  `REQUIRES_AUTHORIZED_BACKEND`，未授权时抛 `UnsupportedError`。

## 真实层前置依赖（REQUIRES_AUTHORIZED_BACKEND）

1. 授权隔离后端 / PG / 对象存储 / Push stub（占位符由用户逐项确认）；
2. C07（多设备身份与生产接线）、C08（群成员/room-key/历史授权）、C10（KT）完成；
3. 合成账号按 fixture contract 在授权后端注册（凭据经本地环境注入，不入仓）；
4. 真机设备清单授权（Android/iOS/macOS 支持矩阵；禁模拟器与脚本默认设备 ID）;
5. 本地可控 MITM 代理授权（W1 WS 帧级 / W2 目录级 / W3 流量调度 / W4 回滚）；
6. 服务端 DB/日志/备份/对象/Push 五面只读查询授权（与 C13 同一授权窗口）。

详见 attack-matrix.md §9。
