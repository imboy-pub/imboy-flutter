# 当前 App 候选回归

源码候选 1950abb3fb7f046706ada30651ae38fd883f848c；执行前后 1977 项源码、依赖、执行器及已有原生库输入哈希一致，HEAD 和干净工作树一致。

离线命令指定 729 个测试文件，报告生成 726 个 suite：7332 项成功、0 失败、98 项跳过。3 个指定文件没有 suite 事件，另有32个真实API测试文件未执行；这些情况和跳过均保存在 result.json，不计为通过。报告为 PASS_OFFLINE_SCOPED，不能替代真实设备、服务端权限或生产验收。

同一 HEAD 完成 flutter analyze --no-pub，exit 0、No issues found，1975 项源码与依赖输入前后不变。suite-results.json 记录本轮逐文件结果，导航、切换、未读、历史消息和待上报队列的最新 suite 可由此绑定；真实 UI / DB oracle 仍以各专项记录为准。

source-binding.tsv 为摘要在前的逐文件冻结绑定，result.json 保存完整命令及私有日志摘要；runner.py.txt 是实际控制器副本。已有 vodozemac 原生库是冻结副本，无新增依赖。原始运行日志留在私有临时路径，仓内不保存原始运行输出。
