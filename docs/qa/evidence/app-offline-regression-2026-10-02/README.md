# App 离线回归 / App offline regression

测试源码提交：`d8b50d0def7a36207f2949829cabc60c274df70a`。本目录是其文档后继，不表示测试命令在后继提交重新执行。

728 个测试文件；7327 项通过，0 失败，98 项跳过。状态仅为 `PASS_OFFLINE_SCOPED`。真实 API 的 32 个测试文件未运行，98 个跳过记录均保留在 result.json，不算通过；设备、客户 OA、生产验收不由此结果证明。

首次运行有 11 项失败，原因是独立工作树找不到已有 vodozemac 原生库。使用本工作树已有的 macOS 构建库冻结副本后，先复跑这 11 个套件（100 通过、0 失败、0 跳过），再完成本次离线回归。未修改业务代码、E2EE 开关、测试断言或跳过条件。

result.json 保存实际完整命令、结果、排除文件和跳过项；inputs.json 保存源码、依赖配置、执行器及原生库的冻结哈希。执行前后这些输入、源码提交和干净工作树均一致。原始日志仅保留于私有临时路径，仓内只保存其 SHA256。

Reproduction: restore the recorded candidate and locked dependencies, provide the existing native dylib with the recorded SHA256, and run the exact command in result.json with FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR pointing to that library directory. runner.py.txt records the actual machine-specific controller and its timeout/result checks; adjust its workspace path only for a new independently recorded run.

This proves offline regression only. Skipped tests, excluded real API files, customer OA, iOS, and production remain outside this PASS.
