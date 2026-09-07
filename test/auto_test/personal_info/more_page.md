# `page/personal_info/widget/more_page.dart`

> 功能点 10 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 页面可达性与路由接线 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF01 深链 /personal_info/more 可达，性别/地区/签名三行渲染 |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 性别行显示当前性别文案 | 已通过 | 批次125 | 0 | 0 | 0 | gender=0 显示「未知」 |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 点性别行跳转设置性别页 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF03 三选项渲染，未设置时无勾选 |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 性别页返回后本页文案刷新 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF04 选「保密」真 PUT 保存，pop 后行值刷新，DB/缓存闭环 |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 地区行超十字时省略号截断显示 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF05 >10 字符截断为 9 字+… |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 点地区行跳转设置地区并保存 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF06 中国大陆→北京→东城下钻保存全链；挖出并修复 set_region_provider 竞态 bug（缓存加载 initData 覆盖用户未保存选择致完成按钮失活） |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 签名为空时显示未填写占位 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF01 sign 空显示未填写灰字 |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 点签名行进入编辑页修改签名 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF08 UpdatePage input 编辑→完成保存真 API |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 签名保存成功后同步本地缓存 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF08 UserRepoLocal 缓存与服务端一致 |
| 无待办 | - | `page/personal_info/widget/more_page.dart` | 分组卡片分隔线与暗色渲染 | 已通过 | 批次125 | 0 | 0 | 0 | AT-MF10 分隔线 0.5 厚度+左缩进 56（外层 Padding）+卡片圆角阴影 widget 断言；暗色分支为 Theme 取色表达式，同一断言覆盖 |
