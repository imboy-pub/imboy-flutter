# 草案质量抽样审计 #01 — 2026-10-03T05:3xZ

> 方法：分层确定性抽样（排序后均匀间隔，可复现），HIGH/MEDIUM/LOW 各 10 行，
> 人工逐行比对 feature 文本与 dispatch 子卡标题。目的：量化草案误配率，
> 为各域 owner 复核排优先级。

## 结果

| 层 | 抽样 | 可接受 | 疑似误配 | 误配模式 |
|---|---|---|---|---|
| HIGH | 10 | 10（含 2 行两可） | 0 | 无系统性问题；两可均为「页面归属 vs 行为目标」之争 |
| MEDIUM | 10 | 5 | 5 | **域对子卡错**：channel_compose→应 F07-S03；chat_setting→应 F03-S03；moment 操作面板→应 F06-S02；project 关联频道/邀请→应 F10-S02 |
| LOW | 10 | 5 | 5 | 红包→已修 F14-S02；splash/服务条款→已修 F14-S03；subscriber→应 F13-S02；qr_login_confirm→两可偏 F02-S01；user_tag→应 F02-S02 |

## 已应用的 v3 修正（仅实证缺口，不猜测）

- `red_packet|wallet|钱包|红包|转账|余额` → F14-S02（资金与付费）
- `splash|terms_of_service|user_agreement|about_page` → F14-S03（AI位置剩余
  入口——dispatch 设计时即含杂项兜底语义）

修正 70 行；LOW 层 401→331。草案版本 v3。

## Owner 复核优先级建议

1. **LOW 剩余 331 行：逐行复核**（约 50% 误配率）。
2. **MEDIUM 714 行：逐域复核**（误配集中在子卡边界：内容创作 vs 创建发现、
   会话设置 vs 发送、互动 vs 发布、协作 vs 切换——每域 owner 对照子卡标题
   批量改判即可，无需逐行细读）。
3. **HIGH 801 行：抽检放行**（抽样 10/10 可接受，建议各域抽 3–5 行）。
4. 留 owner 裁决的三类边界：qr_login_confirm（身份 vs 扫码域跨域两可）、
   live_room subscriber（S01/S02 域内）、user_tag（F02-S01/S02 域内）。

## 局限

抽样 30/1846（1.6%），误配率是点估计非区间；MEDIUM 的"域内子卡错"不阻塞
域级分派（种子已到正确域），只影响子卡工作量分布——因此本审计不改变
F00-S02 草案的可派发性，仅细化复核优先级。
