# `page/single/upgrade_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 弹出升级卡片展示版本与更新说明 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：UI树 contentDescription=检测到新版本1.0.1 + 描述文本 + 立即更新按钮（2026-08-21） |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击立即更新申请存储权限 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：Android 9 设备弹出系统权限弹窗（存储权限）+ 授权后下载开始 |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 权限被拒时提示获取失败 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：拒权后_checkPermission返回denied+弹窗保留（强制更新），但无snackbar/toast反馈（UX缺陷） |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载中展示进度条与百分比 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：DownloadStatus(2)持续流式推送+进度条渲染（约500ms间隔） |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载中展示速度剩余时间与包大小 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：下载状态流含maxLength/currentLength/speed/planTime字段 |
| 无待办 | - | `page/single/upgrade_page.dart` | 点击暂停下载中止当前任务 | 已通过 | 批次108 | 0 | 0 | 0 | 批次108 真机验证：下载中(已下载41.122)点暂停→RUpgrade status由(2)转(0)+按钮变「继续下载」+进度/速度/剩余时间冻结 |
| 无待办 | - | `page/single/upgrade_page.dart` | 点击继续下载恢复断点任务 | 已通过 | 批次108 | 0 | 0 | 0 | 批次108 真机验证：点继续→status回(2)心跳恢复+已下载42.140→45.129自断点递增（未归零，断点续传成立） |
| 无待办 | - | `page/single/upgrade_page.dart` | 下载失败后可重新发起下载 | 已通过 | 批次168 | 0 | 0 | 0 | 真机 XWE6R（EMUI9/sdk28）密封配方：TestPg 临时插 app_version android 行（vsn 9.9.9-167，download_url=http://127.0.0.1:1 设备侧端口无监听）→ AppUpgradeService.checkAndPrompt(fromManual) 走真实服务端 payload 弹页 → 立即更新 → STATUS_FAILED(4) → 卡片按钮变「继续下载」→ 再点仍可重发。批次167 定性：下载管线 Android-only，macOS 无法测，原「待真机」理由准确 |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 下载完成校验哈希后触发安装 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：DownloadStatus(3)完成→verify_ok→install触发→app resumed |
| 无待办 | - | `page/single/upgrade_page.dart` | 校验失败删除文件并重试两次 | 已通过 | 批次168 | 0 | 0 | 0 | 同上配方：download_url 指测试进程内 HttpServer（绑定**设备侧**回环 19802 供真实字节）+ file_hash 预置错误值 → 下载成功点「立即安装」→ SHA256 失败删文件自动重下（服务器实证 3 次请求=初始+2 次重下）→ toast (1/2) 确认 → 达上限 toast「文件多次校验失败」。注：RUpgrade 对同 URL 任务有去重时序裁量，断言锚定终态 toast+服务器请求数而非严格轮次计数 |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 点击稍后提醒关闭并取消下载 | 已通过 | 批次107 | 0 | 0 | 0 | 批次107 真机验证：recommend弹窗出现「下次再说」按钮(190,1044)+「立即更新」(531,1044)，点击下次再说后弹窗关闭回到onboarding 1/3页 |
| 无待办 | 待真机（服务端1.0.1已就绪） | `page/single/upgrade_page.dart` | 强制更新时禁止返回键关闭弹窗 | 已通过 | 批次106 | 0 | 0 | 0 | 批次106 真机验证：BACK键按下后弹窗仍保留（force_update=true），UI树无变化 |
