# 企业通讯录账号隔离 / Directory account isolation

基线 / Base: `a7bacce0111e68f20d021209352ad114636df656`。

共享通讯录页面改为监听当前登录账号。换账号、登出或企业/部门上下文改变时取消未执行的搜索 debounce、清空搜索和旧目录，并重新配置既有目录控制器。空账号不请求目录；页面关闭后的异步响应不会再写控制器。未传企业名称时标题显示「通讯录」。

企业切换的准备、提交完成和页面副作用均校验当前账号/请求代次。旧请求不调用新的提交步骤，也不能把新账号目录重新配置为旧身份；进入本地指针写入后如发现账号已变化，补偿仍限于捕获的旧账号存储。企业切换弹层监听账号变化，撤下旧企业列表并关闭。弹层拆为同模块独立文件，使通讯录主页面低于 800 行。

English: The shared directory responds to the current account. Account changes invalidate old searches, cursor data and delayed results. Logged-out callers do not fetch directory resources. Disposed controllers and obsolete organization-switch continuations cannot update current state. The organization chooser disappears on account change; local compensation remains bound to the captured account.

## 验证 / Verification

```
flutter test --no-pub --concurrency=1 \
  test/organization/human_directory_controller_test.dart \
  test/organization/human_directory_page_widget_test.dart \
  test/organization/human_directory_api_contract_test.dart \
  test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart
```

53 项通过：含空账号无请求、登出丢弃迟到响应、切换准备期间换账号不提交、提交等待期间换账号不覆盖新身份、销毁后返回不写状态、同型同企业页面换账号清搜索及拒绝旧结果、切换企业取消旧 debounce、账号变化关闭弹层，以及既有目录分页/搜索/失败补偿和企业壳回归。

相关源码及测试 `dart analyze`：No issues found。`git diff --check` 通过。手动检查异步 continuation、所有搜索清空调用方及指针补偿；无独立审查代理证据。

本地组件/合成异步响应证据不代表真实设备、OA 联调或生产验证，六项交付目标继续进行。
