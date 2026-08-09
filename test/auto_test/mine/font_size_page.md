# `page/mine/font_size/font_size_page.dart`

> 功能点 10 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 预览卡片随档位改变三级字号 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 真机拖到 0% 档预览三级文本联动「当前：小 90%」；代码 L145-165 标题/正文/辅助三级 getPreviewTextStyle
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 拖动滑块实时更新预览效果 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 真机滑块 20%→0% 实时更新档位+百分比+SeekBar 进度；代码 L223-227 onChanged→updatePreview
| 无待办 | - | `page/mine/font_size/font_size_page.dart` | 松手后应用字号并双写持久化 | 已通过 | §十七 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 应用成功弹出更新成功提示 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 真机松手应用 theme_font_size=small 持久化实锤成功；代码 L229-234 showSuccess；toast 一闪未抓
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 应用失败回滚滑块与预览档位 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 代码确认 L115-121 catch→回滚 previewOption+sliderValue 到当前真实档位→rethrow；失败路径需存储异常未构造
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 回显当前档位名称与缩放百分比 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 真机「当前：标准 100%」↔「当前：小 90%」随档位实时切换；代码 L266-269 currentFontScale
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 字号过小时提示可读性风险 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 代码确认 isAccessibleSize≥10pt，6 档最小 0.9×14=12.6pt 恒达标→警告分支当前不可达（防御性）；真机最小档仍「可读性良好」
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 展示较小与较大端点标签 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 真机滑块两端「更小」「更大」；代码 L250-262
| 无待办 | - | `page/mine/font_size/font_size_page.dart` | 重启应用后字号设置仍保持 | 已通过 | §十七 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/font_size/font_size_page.dart` | 渲染推荐档位徽标 | 已通过 | §十七 | 0 | 0 | 0 | | 批次53 真机预览卡右下「推荐」徽标；代码 L271-289 iosBlue 10% alpha 底+圆角 6
