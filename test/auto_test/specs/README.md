# 可执行页面规格

每个 JSON 文件描述一个页面级真机回归样板。它不会存放账号、密码、生产地址或截图产物。

`checkpoints` 对应集成测试中的 `takeScreenshot` 名称；采集脚本会在这些检查点暂停后由主机侧 ADB 抓取截图。规格声明的检查点必须真实存在于对应测试中，避免“有规格、无证据”。

`scripts/run_test_suite.sh` 的 L0 层会自动运行此规格校验，因此普通 quick/full/release 回归也会发现规格、源码路径或截图检查点失配；它只做静态检查，不会启动真机或模型。

```bash
python3 scripts/auto_test.py validate
python3 scripts/auto_test.py coverage-report
python3 scripts/auto_test.py next-batch --limit 12
python3 scripts/auto_test.py plan --phase p0
python3 scripts/auto_test.py impact lib/page/wallet/transfer_send_page.dart
python3 scripts/auto_test.py run --phase p0 --device <真实设备ID> --dry-run
python3 scripts/auto_test.py capture --case CONVERSATION-LIST-001 --device <Android真实设备ID>
python3 scripts/auto_test.py visual-request --case CONVERSATION-LIST-001 --screenshot <当前截图.png> --device <设备型号> --theme light --output <任务.json>
python3 scripts/auto_test.py visual-diff --baseline <基线.png> --current <当前截图.png> --diff <差异.png>
python3 scripts/auto_test.py visual-review --request <任务.json> --output <结果.json>
python3 scripts/auto_test.py baseline-register --case CONVERSATION-LIST-001 --screenshot <已人工确认截图.png> --device android-1080x2400 --theme light
python3 scripts/auto_test.py render-report --summary test/auto_test/reports/<run-id>/summary.json --output test/auto_test/reports/<run-id>/report.md
```

只有显式传入 `--execute`，且目标为本地地址，执行器才会运行 Flutter/Patrol 测试；远程环境还需要 `IMBOY_ALLOW_REMOTE_TEST=1`。高风险 case 的 `safe_to_execute` 默认是 `false`，执行器只会报告阻塞。

`visual-request` 生成供应商无关任务包，可交给已配置的低成本视觉模型；`visual-diff` 用 ImageMagick 先做确定性像素差异筛选，只有 `REVIEW` 才值得调用模型。

`visual-review --execute` 只通过私有适配命令调用模型：必须同时设置 `IMBOY_ALLOW_VISION_UPLOAD=1` 与 `IMBOY_VISION_REVIEW_COMMAND`。适配命令接收任务 JSON 路径作为唯一参数、从标准输出返回视觉准则规定的 JSON；API Key 只能存放在用户环境或私有密钥管理器，严禁写入仓库。

`baseline-register` 只允许登记已人工确认的截图，并同时写入 SHA-256 元数据。已有基线不会被静默覆盖；视觉设计确有意更新时才可显式传 `--replace`，并应在提交中说明原因。

`render-report` 将功能执行摘要和零个或多个 `--visual <结果.json>` 渲染为可归档 Markdown。没有视觉结果、存在 `PLANNED`/`BLOCKED`/`REVIEW` 时结论只能是 `PARTIAL` 或 `BLOCKED`，不会形成真机 UI/UX 的假通过。

Android 机型的截图采集使用主机侧 ADB，避免部分厂商 ROM 的 Flutter surface 截图阻塞：

```bash
export IMBOY_TEST_PHONE='<测试账号>'
export IMBOY_TEST_PASSWORD='<测试密码>'
python3 scripts/capture_integration_screenshots.py \
  --target integration_test/chat/conversation_test.dart \
  --device <Android真实设备ID> \
  --output test/auto_test/reports/<run-id>/screenshots
```

该脚本只在现有 `takeScreenshot` 检查点短暂停留并抓屏；没有显式配置测试账号时会在启动前 `BLOCKED`。

也可以通过规格入口统一调度：`capture` 默认只打印采集计划；只有加 `--execute` 才会调用采集器。它仅允许 `safe_to_execute: true` 的 Flutter case，远程地址仍须显式设置 `IMBOY_ALLOW_REMOTE_TEST=1`。

iOS 真机可使用同一入口并加 `--platform ios`，但必须由你提供私有采集器命令 `IMBOY_IOS_SCREENSHOT_COMMAND`。命令必须同时包含 `{device}` 与 `{output}` 占位符；未配置时脚本会在启动测试前 `BLOCKED`，不会假装 iOS 截图已支持。

仓内提供 Gemini 适配器，默认 `gemini-2.5-flash-lite`；需要更强视觉判断时可用 `GEMINI_MODEL=gemini-2.5-flash` 覆盖。真实运行示例：

```bash
export GEMINI_API_KEY='<仅在当前 shell 或密钥管理器中提供>'
export IMBOY_ALLOW_VISION_UPLOAD=1
export IMBOY_VISION_REVIEW_COMMAND='python3 scripts/gemini_vision_adapter.py'
python3 scripts/auto_test.py visual-review --request <任务.json> --output <结果.json> --execute
```
