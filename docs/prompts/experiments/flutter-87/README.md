# Flutter #87 模型对照实验

此实验是 [ECC-027](../../ECC_USE_CASES.zh-CN.md#ecc-027--websocket-重连和消息-ack) 的专项重放。任务从 [Issue #6](https://github.com/imboy-pub/imboy-flutter/issues/6) 出发，评估握手卡死、退避与连接资源生命周期。录音与同期 CI 修整不计入此项。

| 输入 | 固定值 |
| --- | --- |
| 修复前提交 | `946be831b5383141e652d6f30d358749aaed3fea` |
| Flutter / Dart | `3.50.0` / `3.14.0` |
| `flutter_chat_ui` 子模块 | `62245bd40067d73ddb5bf98d340537cbbe2ae3e7` |
| 含子模块内容的 checkout tree | `7ae35918257afcb00d681f9505d573bf7bb1e5d1` |
| `pubspec.lock` SHA-256 | `66b49c7ffe4a3fa5d514e32031fe63a4917297afcebde8fffd2302105cc38848` |
| 默认对照 | `gpt-6.1-sol` 与 `gpt-6.2-sol`，均使用 `low`，每轮限时 12 分钟 |

`PROMPT.md` 提供统一任务。实现组使用独立的新会话和无历史的新 checkout。严格盲测时，仅向实现组挂载自己的 checkout、SDK 和依赖缓存。原仓历史、参考实现及评分文件留在独立评估环境。原始 PR 的 Git 元数据无法证明其生成模型身份。[Flutter PR #87](https://github.com/imboy-pub/imboy-flutter/pull/87)

## 五项验收

| 编号 | 可观察行为 |
| --- | --- |
| ECC027-01 | 握手在第 14 秒仍等待，第 15 秒结束并调度重试。后续真实升级请求与计数推进一致。 |
| ECC027-02 | 每次超时的原生连接分别到达 TCP 对端 EOF。 |
| ECC027-03 | 永久关闭后待定升级释放，推进时钟 60 秒状态保持断开且没有后续请求。 |
| ECC027-04 | 正常认证升级后，原有文本协议保持双向收发。 |
| ECC027-05 | 正常认证升级后，V2 二进制帧保持双向收发。 |

验收还运行修复前版本的 `websocket_reinit_test.dart` 与 `websocket_send_session_test.dart`。评分器要求全部预期用例实际执行，原有回归需全部成功。原有 `connection_attempts` 在调度退避时递增。Native VM 结果与 Chrome 兼容性分别验收。

## 重放

使用 Python 3.12+、固定版本的 Flutter、包含历史提交的本地 checkout 和已预热的 Pub 缓存。先初始化 Git 子模块，再按仓库的标准流程用 `flutter pub get --enforce-lockfile` 预热依赖。执行机需要允许绑定 `127.0.0.1` 的临时端口。`synthetic-env/` 来源于修复前提交中的 `.github/scripts/ci_gen_env.sh`，包含生成的合成配置，所有轮次复用相同字节。

从本目录执行。每个 `--out` 都应为新目录。

```bash
repo=/path/to/imboy-flutter
sdk=/path/to/flutter/bin/flutter
out=/path/to/ecc027-runs

for control in base initial fixed; do
  python3 replay.py --source "$repo" --flutter "$sdk" --out "$out/control-$control" \
    judge --control "$control" || exit $?
done
```

校准通过时启动同一版本的 Codex CLI。建议每组至少三轮，轮换每轮的启动顺序，报告有效轮次、阻塞轮次、耗时中位数和逐项结果。正式计分前应先校准基线、仅加握手超时的初版、最终修复。原始测试进程在基线和初版预计退出 1，校准器会核对具体红绿组合，无缺项或额外失败才退出 0。

| 校准快照 | 01 | 02 | 03 | 04 | 05 |
| --- | --- | --- | --- | --- | --- |
| `base` | FAIL | FAIL | FAIL | PASS | PASS |
| `initial` | PASS | FAIL | FAIL | PASS | PASS |
| `fixed` | PASS | PASS | PASS | PASS | PASS |

```bash
python3 replay.py --source "$repo" --flutter "$sdk" --out "$out/old-1" \
  trial --model old --round 1
python3 replay.py --source "$repo" --flutter "$sdk" --out "$out/grade-old-1" \
  judge --patch "$out/old-1/evidence/candidate.patch"
```

将模型切换为 `new` 后用新的输出目录运行。每次调用保存命令、原始退出码、运行耗时和日志 SHA-256。候选评分以独立验收和原有回归为准。

Chrome 兼容性可在应用候选补丁的独立 checkout 中用仓内用例验证。

```bash
flutter test --no-pub --concurrency=1 --platform=chrome --machine \
  test/service/web_human_device_qr_ws_chrome_test.dart
```
