# i18n 母语审核分发指南（给项目所有者）

> 目的：把 8 份语言审核包发给母语审核人，收齐结论后交回 AI 会话回填。
> 每份审核包已内嵌审核人母语导读（2026-09-06）——审核人打开文件就知道做什么，无需额外解释。
> 当前发布状态：CONDITIONAL GO。审核**不阻塞**发布决策；但 8 语言全部 APPROVED 是升格 GO 的唯一条件。

## 一、发什么、怎么说

每位审核人只发**一个文件**（文件路径相对 `imboyapp/`）。随文件附一句话邀约，下表可直接复制：

| 语言 | 发送文件 | 一句话邀约（复制即用） |
|---|---|---|
| 繁體中文 | `I18N_NATIVE_REVIEW_zh-Hant.md` | 幫我校一份繁中 UI 文案（31 行，約 15 分鐘），逐行打 ✅ 或給建議，感謝！ |
| 日本語 | `I18N_NATIVE_REVIEW_ja-JP.md` | 日本語UI文案の最終チェックをお願いできますか？31行・15分ほどで、各行に✅か修正案を書くだけです。 |
| 한국어 | `I18N_NATIVE_REVIEW_ko-KR.md` | 한국어 UI 문구를 검토해 주실 수 있을까요? 31행, 15분 정도면 끝나고, 각 행에 ✅ 또는 수정안만 적으면 됩니다. |
| Deutsch | `I18N_NATIVE_REVIEW_de-DE.md` | Kannst du unsere deutschen UI-Texte gegenlesen? Ca. 31 Zeilen, 15–20 Min., pro Zeile ✅ oder Verbesserung. Danke! |
| Français | `I18N_NATIVE_REVIEW_fr-FR.md` | Peux-tu relire nos textes UI en français ? ~31 lignes, 15–20 min : ✅ ou correction par ligne. Merci ! |
| Italiano | `I18N_NATIVE_REVIEW_it-IT.md` | Puoi rileggere i testi UI in italiano? ~31 righe, 15–20 min: ✅ o correzione per riga. Grazie! |
| Русский | `I18N_NATIVE_REVIEW_ru-RU.md` | Можешь вычитать наши русские тексты интерфейса? ~31 строк, 15–20 минут: ✅ или свой вариант. Спасибо! |
| العربية | `I18N_NATIVE_REVIEW_ar-SA.md` | هل يمكنك مراجعة نصوص الواجهة العربية؟ 31 سطرًا، 15–20 دقيقة: ✅ أو تصحيح لكل سطر. شكرًا! |

渠道随意：微信/Telegram/邮件附件均可——文件是纯 Markdown，任何编辑器（含手机备忘录式逐条回复）都能处理。

## 二、收什么

- **优先**：审核人回传填好的 `.md` 文件（每行「结论」列有 ✅ 或 ✗）。
- **也可以**：截图、聊天里逐条给结论——只要每行结论可辨认即可，回填由 AI 会话代劳。

## 三、收齐后交回 AI 会话

把回传材料放进 `imboyapp/` 仓库根（或直接在会话里粘贴），说一句「审核结论回来了」即可。之后按 `I18N_AUDIT_REPORT.md` §14 SOP 执行：

- 全 ✅ → 该语言记 APPROVED；8 语言全 APPROVED → 结论升格 **GO**，主包总览表回写。
- 有 ✗ → 按建议译文做受守卫替换 → `dart run slang` → 严格审计门 → UI Gate → DCO 提交，改完可再请该审核人确认一眼。

## 四、某语言找不到审核人怎么办

在该语言主包总览表一行写 **BLOCKED_NO_REVIEWER** 即可。该语言维持 CONDITIONAL GO 已接受的既有风险（机器门全绿 + 术语表上下文校对），**不阻塞其余 7 语言**，也不阻塞发布。

## 五、审核人常见问题（可转述）

- **「我不懂中文怎么办？」** 不需要懂。中文列只是原文参考，审核对象是您母语那一列。
- **「✅ 已经在最后一列了，我是不是不用动？」** 那是默认占位。请把 verdict 写在**第六列（结论，空着的那列）**：✅ 或 ✗。
- **「专有名词/品牌名要不要翻？」** 不翻。Alipay / WeChat Pay / Huabei 等按惯例保留拉丁原文。
- **「表格里的 `one:` / `other:` 是什么？」** 复数分支——请每个分支都看一遍，分别给结论。
