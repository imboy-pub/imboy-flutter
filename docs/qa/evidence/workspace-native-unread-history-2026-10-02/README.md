# 企业未读和历史消息原生验收

实际 macOS App、全量迁移的独立 PostgreSQL、独立 Garage，仅合成账号与数据。两条群消息的投递 ACK 已确认但仍显示未读 2；打开群后历史正文正常显示，实际阅读上报使服务端未读归零，返回企业消息列表后徽标隐藏。数据库关联当前未结束成员 generation，恰一条 read_cursor，read_seq=2。

修复两个真实契约缺口：预览时间解析兼容服务端毫秒时间戳；归档适配器仅在消息 ID/type 匹配时解包完整消息信封。身份仍来自权威归档行，旧正文格式和历史密文保留兼容。相关 24 项测试通过，静态检查无问题，两名既有审查者 APPROVE。

原生测试退出0且五项数据库 oracle通过，同次企业群发送、频道讨论、组织治理、企业加入退出、无OA官网工作台与文件上传/删除审计均通过。冻结源码和迁移摘要见 source-binding.tsv。运行入口为 integration_test/enterprise/enterprise_scope_native_test.dart；本次测试服务驱动 /tmp/gz-macos-unread-r7-sequential.py。

此前R1/R2/R4/R5失败、R3主动停止、R6测试服务端口占用均未计PASS。未证明受控的阅读队列并发调度、iOS或客户OA；完整目标仍待最终跨域和连续全量后端回归。
