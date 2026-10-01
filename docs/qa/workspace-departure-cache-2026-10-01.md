# 企业退出后的工作区缓存清理

源码基线：b3388a04c39e3845c18817c0d7826cf3a891a753。业务文件由同提交 source-sha256.txt 绑定。

退出页面曾整体失效五类工作区 Provider，遗漏消息摘要，还刷新其他企业缓存。现在 WorkspaceShellNotifier.forgetOrganization 在删除已知工作区前，按该企业的工作区 ID 失效六类数据：概览、频道、群、消息摘要、成员、项目。页面保留企业入口失效，删除重复的全局工作区失效代码及无用 import。账号/加载 generation 防护沿用原实现。

基线回归明确失败：两个已退出工作区的消息/频道请求计数未增加。修复后 31 项 focused Flutter 测试通过，包含保留其他企业缓存、旧请求迟到不能覆盖新权限拒绝；三文件 analyze 无问题，diff --check 通过。测试使用受控 Provider/既有页面 HTTP 桩，不能代替真实后端退出、真机及全资料撤权证明。清理范围是当前壳已经加载的工作区；其他独立资料/聊天持久缓存的全访问面仍需完整验收。

命令：flutter test test/unit_test/page/workspace_shell/workspace_departure_cache_test.dart test/unit_test/page/workspace_shell/workspace_shell_provider_test.dart test/organization/organization_detail_hub_widget_test.dart；flutter analyze 上述两源码文件和新测试文件。人工复核调用方、失效范围和迟到请求行为；未执行独立 agent 审查。原始证据见 evidence/workspace-departure-cache-2026-10-01/。六项目标未完成，未执行部署/外向操作。
