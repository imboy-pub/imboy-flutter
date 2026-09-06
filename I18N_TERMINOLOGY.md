# IMBoy i18n 产品术语治理基线（I18N_TERMINOLOGY.md）

> 创建：2026-09-05 | 任务：P2（Terminology Governance）| 状态基线：10 locale 补齐波次完成后
> 证据来源：`assets/i18n/<locale>/*.i18n.yaml` 实测值 + 2026-09-05 十语言专员 Agent 的术语决策记录（每个 Agent 均以"同 locale 现有译文一致性优先"原则执行并回报决策）
> 复核状态说明：所有非中英语言当前均无真人母语审核，统一标 `NEEDS_NATIVE_REVIEW`；标注 `PINNED` 的为仓库现有惯例，改动需一次性决策。

---

## 1. 治理规则（不变量）

以下概念在任何语言中必须保持可区分，禁止因译文方便而合并：

```text
Workspace Member ≠ Project Member ≠ Group Member ≠ Channel Subscriber
Join Workspace   ≠ Join Group   ≠ Subscribe Channel
Invite（动作）    ≠ Invitation（邀请函/码）
Delete Account   ≠ Log Out
Remove Member    ≠ Leave Group/Workspace
Encryption failed ≠ Decryption failed
Message ≠ Chat ≠ Channel Post ≠ Comment
```

权威先例：`assets/i18n/en-US/workspace.i18n.yaml` 文件头注释（WP5 落地时写入）：
> Terminology (plan §1.4): always disambiguate — Workspace Member / Group Member / Channel Subscriber. Members nav may be short, but page titles and descriptions must say "Workspace Members".

通用规则：

1. 同一 locale 内，同一概念全库只用一个词（以本表为准）。
2. 品牌/技术词保留拉丁原文：IMBoy、URL、ID、Hash、E2EE、TOFU、WHIP/WHEP、Alipay、WeChat Pay、Owner/Member/Guest（角色词，见 §3）。
3. 值中 placeholder（`$name`/`${count}`/`{n}`/`$n`）数量与名字必须与 zh-CN 一致，任何语言不得增删。
4. 拿不准的译文给当前最佳值并列入"待母语审核"，**禁止**在 YAML 值中写标记、留空或保留中文。

---

## 2. 空间与组织

| Concept | English | zh-CN | zh-Hant | ja-JP | ko-KR | de-DE | fr-FR | it-IT | ru-RU | ar-SA |
|---|---|---|---|---|---|---|---|---|---|---|
| Workspace | Workspace | 工作区 | 工作區 | ワークスペース | 워크스페이스 | Arbeitsbereich | Espace de travail | Area di lavoro | рабочее пространство | مساحة العمل |
| Project | Project | 项目 | 項目 | プロジェクト | 프로젝트 | Projekt | Projet | Progetto | проект/этapel | مشروع |
| Group | Group | 群组 | 群組 | グループ | 그룹 | Gruppe | Groupe | Gruppo | группа | المجموعة |
| Channel | Channel | 频道 | 頻道 | チャンネル | 채널 | Kanal | Canal | Canale | канал | القناة |

规则：
- **Workspace 与 Group 是不同实体**，禁止都译成"群"（zh-Hant 禁用 群組 指 Workspace）。
- ru `этapel` 注：P14 Agent 将里程碑 milestone 译为 этап；project 语境用 проект。
- Review Status：zh-CN/en-US = PINNED；其余 8 语言 = NEEDS_NATIVE_REVIEW（Agent 决策记录在案）。

## 3. 成员与角色

| Concept | English | zh-CN | ja-JP | ko-KR | de-DE | fr-FR | it-IT | ru-RU | ar-SA |
|---|---|---|---|---|---|---|---|---|---|
| Workspace Member | Workspace Member | 工作区成员 | ワークスペースメンバー | 워크스페이스 구성원 | Arbeitsbereich-Mitglied | membre de l'espace de travail | membro dell'area di lavoro | участник рабочего пространства | عضو مساحة العمل |
| Group Member | Group Member | 群成员 | グループメンバー | 그룹 구성원 | Gruppenmitglied | membre du groupe | membro del gruppo | участник группы | عضو المجموعة |
| Channel Subscriber | Subscriber | 订阅者 | **購読者** | 구독자 | Abonnent | abonné | iscritto | подписчик | مشترك |
| Owner / Admin / Guest 角色词 | Owner / Admin / Guest | Owner | Owner | Owner | Owner | Owner | Owner | Owner | Owner |

关键裁决：
- **角色词 Owner/Member/Guest 全语言保留拉丁**（`workspace.roleOwner` 在 10 个 locale 实测全部为 `Owner`；zh-CN 源即英文）。这是 PINNED 现有惯例；若产品决定本地化角色词，必须一次性全语言变更并重审 UI 长度，禁止个别语言单方面改动。
- **ja 購読者 vs 登録者**：裁决为 **購読者**（P9，2026-09-05）。理由：channel 命名空间既有 25 处一致使用 購読/購読解除；「登録」已承载"注册"语义（buttonRegister: 登録）。**禁用** 登録者 指频道订阅者（会与注册用户混淆）。
- Channel Subscriber 在 de/fr/it 语境按各语言订阅动词派生（Abonnent/abonné/iscritto），与"群成员"词根（Mitglied/membre/membro）保持距离。

## 4. 邀请与加入

| Concept | English | zh-CN | Recommended（非中英） | Discouraged |
|---|---|---|---|---|
| Invite（动作） | Invite | 邀请 | ja 招待 / ko 초대 / de Einladen / fr Inviter / it Invitare / ru Пригласить / ar دعوة | 与 Invitation 混用 |
| Invitation（函/码） | Invitation | 邀请函 / 邀请码 | ja 招待状・招待コード / fr invitation・code d'invitation / ru приглашение・код приглашения | 用 Invite 动作词指邀请函 |
| Invite Code | Invite Code | 邀请码 | ko 팀 코드（团队码）/ de Einladungscode / fr code d'équipe / ru код команды（团队码线） | 缩写致歧 |
| Join Workspace | Join | 加入工作区 | de Arbeitsbereich beitreten / fr rejoindre l'espace / ru присоединиться к рабочему пространству | 译成"订阅" |
| Join Group | Join | 加入群组 | ja グループに参加 / ko 그룹 가입 / ru вступить в группу | — |
| Subscribe Channel | Subscribe | 订阅 | ja 購読 / ko 구독 / de Abonnieren / fr S'abonner / it Iscriviti / ru Подписаться / ar اشتراك | ja 用 登録（见 §3 裁决） |
| Unsubscribe | Unsubscribe | 取消订阅 | ja 購読解除 / ko 구독 해지 / de Abbestellen / fr Se désabonner / it Disiscriviti / ru Отписаться | ja 用 登録解除 |
| Leave | Leave | 退出 | ja 退出 / ko 나가기 / de Verlassen / fr Quitter / it Esci / ru Выйти（群）/ Покинуть | 与 Delete/Remove 混用 |

注意：`channel.unsubscribe` 与 `channel.unsubscribeConfirm` 在 zh-CN 同值"取消订阅"——前者为动作、后者为确认弹窗语境，P5 已记录为疑似合理设计，**不改**（NEEDS_PRODUCT_CONFIRMATION 轻项）。

## 5. 用户与身份

| Concept | English | zh-CN | Recommended | Notes |
|---|---|---|---|---|
| User | User | 用户 | zh-Hant 使用者（台）| ja ユーザー / ko 사용자 / de Benutzer / fr utilisateur / it utente / ru пользователь / ar مستخدم |
| Account | Account | 账号 | zh-Hant 帳號 | **禁用** 帐号（错别字，P5 已全库修正为 账号；zh-Hant 為 帳號） |
| Profile | Profile | 个人资料 | ja プロフィール / ko 프로필 / de Profil / fr profil / it profilo / ru профиль | — |
| Friend | Friend | 好友 | ja 友だち / ko 친구 / de Freund / fr ami / it amico / ru друг / ar صديق | — |
| Contact | Contact | 联系人 | ja 連絡先 / ko 연락처 / de Kontakte / fr contacts / it contatti / ru контакты / ar جهات الاتصال | 与 Friend 是两个概念（联系人=通讯录层） |

## 6. 消息与内容

| Concept | English | zh-CN | Recommended | Notes |
|---|---|---|---|---|
| Message | Message | 消息 | zh-Hant 訊息 / ja メッセージ / ko 메시지 / de Nachricht / fr message / it messaggio / ru сообщение / ar رسالة | — |
| Chat | Chat | 聊天 | ja チャット / ko 채팅 / de Chat / fr discussion（对话语境）/ it chat / ru чат | Chat 是场景，Message 是对象，不得互换 |
| Channel Post | Post | 频道帖子/发布 | 各语言用"发布/帖子"词根，不用"消息"词根 | 频道内容 ≠ 即时消息 |
| Comment | Comment | 评论 | zh-Hant 留言（讨论区语义，P8 裁决）/ ja コメント / ko 댓글 / de Kommentar / fr commentaire / it commento / ru комментарий | — |
| Reply | Reply | 回复 | ja 返信 / ko 답장 / de Antworten / fr Répondre / it Rispondi / ru Ответить | `channel.replyTo`（回复对象前缀）与普通回复区分，ja 取 返信先（P9 源语义澄清） |

## 7. 隐私与安全

| Concept | English | zh-CN | Recommended | Notes |
|---|---|---|---|---|
| Privacy | Privacy | 隐私 | zh-Hant 隱私 / ja プライバシー / ko 개인정보（保护语境）/ de Datenschutz / fr confidentialité / it privacy / ru конфиденциальность / ar الخصوصية | de 用 Datenschutz（法定词） |
| Security | Security | 安全 | zh-Hant 安全性 / ja セキュリティ / ko 보안 / de Sicherheit / fr sécurité / it sicurezza / ru безопасность / ar الأمان | — |
| E2EE | E2EE / End-to-end encryption | 端到端加密 | 全语言保留 E2EE 缩写可用；全称 de Ende-zu-Ende-Verschlüsselung / fr chiffrement de bout en bout / it crittografia end-to-end / ru сквозное шифрование / ar التشفير من طرف إلى طرف | — |
| Device | Device | 设备 | zh-Hant 裝置（台）/ ja デバイス / ko 기기 / de Gerät / fr appareil / it dispositivo / ru устройство / ar جهاز | zh-Hant **禁用** 设備（大陆词形） |
| Session | Session | 会话 | ja セッション / ko 세션 / de Sitzung / fr session / it sessione / ru сессия | 安全语境 ≠ 聊天会话（chat thread） |
| Verification（码/身份） | Verification / Security Code | 验证码 / 安全码 | de Sicherheitscode / fr code de sécurité / it codice di sicurezza / ru код безопасности / ja 安全番号（跟随既有 e2eePeerKeyChanged）/ ko 보안 번호 / ar رمز الأمان | ja 安全番号 为既有惯例，PINNED；码=code 类，ar رمز |
| Recovery | Recovery key | 恢复密钥 | ja リカバリーキー / ko 복구 키 / de Wiederherstellungsschlüssel / fr clé de récupération / it chiave di recupero / ru ключ восстановления | passphrase（口令）≠ recovery key，en 已区分 |

## 8. 破坏性与治理动作

| Concept | English | zh-CN | Recommended | Discouraged |
|---|---|---|---|---|
| Delete | Delete | 删除 | 各语言常规删除词（de Löschen / fr Supprimer / it Elimina / ru Удалить / ja 削除 / ko 삭제 / ar حذف） | — |
| Remove（成员/内容移除） | Remove | 移除 | de Entfernen / ru Исключить（移出群语境）| 与 Delete 混用（Delete=销毁对象，Remove=移出容器） |
| Leave | Leave | 退出（自己离开）| 见 §4 | 用 Delete 词根（自身退出不是删除） |
| Block | Block | 拉黑/屏蔽 | ja ブロック / ko 차단 / de Blockieren / fr Bloquer / it Blocca / ru Заблокировать / ar حظر | — |
| Report | Report | 举报 | ja 通報 / ko 신고 / de Melden / fr Signaler / it Segnala / ru Пожаловаться / ar إبلاغ | 与投诉 complaint（de Beschwerde 线）区分 |
| Mute | Mute | 禁言/免打扰 | ja ミュート / ko 뮤트 / de Stumm / fr Muet / it Silenzia / ru Без звука（通知语境）| 禁言（群治理）与免打扰（个人通知）若同键复用需上下文可辨 |

## 9. 支付与注销

| Concept | English | zh-CN | Recommended | Notes |
|---|---|---|---|---|
| Payment 支付方式 | Payment method | 支付方式 | Alipay / WeChat Pay 全语言保留拉丁；de Zahlungsart / fr moyen de paiement / it metodo di pagamento / ru способ оплаты | — |
| 花呗 | Huabei | 花呗 | 各语言 Huabei（拉丁白名单）| P11 de "Huabei-Ratenzahlung"、P14/ko 拉丁，PINNED |
| Delete Account（注销） | Delete account | 注销账号 | de Konto löschen / fr supprimer le compte / it Elimina account / ru Удалить аккаунт / ar إلغاء الحساب / ja アカウント削除 | **≠ Log Out**（退出登录：Abmelden / Se déconnecter / Выйти / ログアウト） |
| 注销申请 | Deletion request | 注销申请 | de Löschantrag / it richiesta di disattivazione（it 现有惯例 PINNED）/ en deletion request | it 用 disattivazione 词根为既有惯例（P13），与 delete 并存 |
| 红包 | Red Packet | 红包 | ja お年玉（既有）/ ko 복주머니（既有）/ de Geschenk（既有）/ fr hongbao / it busta rossa / ru конверт / ar 分类词根 | 各 locale 词根不同但各自内部一致；吉祥话（大吉大利恭喜发财）均意译，全部 NEEDS_NATIVE_REVIEW |
| 转账 | Transfer | 转账 | zh-Hant 轉帳（台，P8）/ it bonifico（既有）/ ko 송금 / ru перевод | — |

## 10. 语言专项规则

### zh-Hant（台湾惯例为默认，P8 裁决）
儲值（充值）、轉帳（转账）、付款（支付，旧键"支付密码"保留）、影片（视频）、檔案（文件）、使用者（用户）、連結（链接）、網路（网络）、伺服器（服务器）、裝置（设备）、剪貼簿（剪贴板）、頁面（页面）。
已解决（2026-09-06 用户拍板统一台式）：用家 15 处→使用者（§5 User 钉定词）、賬號 10 处→帳號，零残留。

### ja-JP
敬体です・ます；按钮体言止め；**購読者（禁 登録者）**；安全番号（PINNED）；红包=お年玉（PINNED）。日中同形规避变体约 21 键待母语复核（字号 小さめ/中くるい 等——若审核接受同形原形「小/中/大/特大」则 untranslated 工具存在盲区，见 P9 报告）。

### ru-RU
CLDR 复数：`timeMinutesAgo(plural)` 等必须保持 one/few/many/other 四分支（2026-09-05 已补全）；时间状语用宾格（минуту назад）；数字+名词组合用属格固定式规避（«Участников: $count»）。

### ar-SA
数字沿用西方数字（既有惯例 PINNED）；拉丁白名单=品牌/技术词；RTL 语境下占位符按语序放置；「→」方向语义在 RTL 中取反向（P15 裁决 discussInGroupGuide 用 ←）。

### 全语言技术字段（RTL 局部 LTR 白名单，只记录不大改）
URL、ID、Hash、安全码显示值、颜色值（#RRGGBB）、日期模板（YYYY-MM-DD）——这些字段在 RTL 界面中如需强制 LTR，应在字段级 widget 局部包 Directionality(ltr)（lib/run.dart 全局层已移除，见 P6）。

## 11. NEEDS_PRODUCT_CONFIRMATION 汇总

| # | 事项 | 现状 | 影响 |
|---|---|---|---|
| 1 | zh-CN「您/你」混用 | ✅ 已解决（2026-09-06 用户拍板统一为「你」）：17 处值级替换零残留；八目标语言人称语态经普查各自语内自洽（de/fr/ru 全语料敬体、it/ja 非敬体惯例、ko 规约敬语），无需联动改写 |
| 2 | zh-Hant 港式「用家/賬號」 | ✅ 已解决（2026-09-06 用户拍板统一台式）：25 处替换零残留 |
| 3 | 角色词 Owner/Member/Guest 是否本地化 | 全语言拉丁（PINNED） | 一旦本地化需 10 语言一次性变更+UI 长度重审 |
| 4 | `channel.unsubscribe`/`unsubscribeConfirm` 同值 | 保留 | 疑似动作/确认弹窗有意同文案 |
| 5 | `main.timeWeekdays` 半角逗号分隔 | 保留 | 疑为程序 split 数据值，非 UI 文案 |
| 6 | 红包吉祥话各语言意译差异 | 已译 | 各语言文化转写不同，需统一审美裁决或接受差异 |

## 12. 审核状态总览

| Locale | 状态 | 依据 |
|---|---|---|
| zh-CN | PINNED（源语义，P5 冻结） | 19 处值级修正，2026-09-05 |
| en-US | PINNED（语义桥接层，P7 补齐） | 144 键补齐，Agent 决策在案 |
| zh-Hant / ja-JP / ko-KR / de-DE / fr-FR / it-IT / ru-RU / ar-SA | NEEDS_NATIVE_REVIEW | 各 Agent 补齐+修正，无真人母语审核；待审清单见各 Agent 报告（约 60 键） |

> 本表为活文档：后续 Key 变更、母语审核结论（APPROVED/CHANGES_REQUESTED）应回写对应小节并更新本行状态。
