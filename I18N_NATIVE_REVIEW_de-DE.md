# i18n 母语审核包 —— de-DE

> 本文件为 [I18N_NATIVE_REVIEW_PACKAGE.md](./I18N_NATIVE_REVIEW_PACKAGE.md) 的按语言分发版（2026-09-06 拆分）。
> 审核完成后请回填每行「结论」列（APPROVED / CHANGES_REQUESTED + 建议译文 / BLOCKED_NO_REVIEWER），
> 并由集成者回写主包总览表。审核人：________　日期：________


### de-DE

| # | Tier | Key | zh-CN（基准） | de-DE 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | Kontosicherheit | | ✅ |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | Kontosicherheit verbessern | | ✅ |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | Zahlung erfolgreich | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | Nach erfolgreicher Zahlung 5 g grüne Energie erhalten | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | Bitte Zahlungs-Passwort eingeben | | ✅ |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | Betrag: | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | Zahlungsart wählen | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | Möchten Sie sich wirklich abmelden? | | ✅ |
| 9 | T1 | `account.bindAlipay` | 绑定支付宝 | Alipay verknüpfen | | ✅ |
| 10 | T1 | `account.bindMobile` | 绑定手机号 | Mobilfunknummer verbinden | | ✅ |
| 11 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | Für Anmeldung, Passwort-Wiederherstellung und Empfang wichtiger Benachrichtigungen | | ⚠️ 长度比2.82 |
| 12 | T1 | `account.changeLoginPassword` | 修改登录密码 | Anmeldepasswort ändern | | ✅ |
| 13 | T1 | `account.changeMobile` | 更换手机号 | Mobilfunknummer ändern | | ✅ |
| 14 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | Bestätigungscode an E-Mail gesendet | | ✅ |
| 15 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | Bestätigungscode an Mobilfunknummer gesendet | | ✅ |
| 16 | T1 | `account.currentDevice` | 当前设备 | Aktuelles Gerät | | ✅ |
| 17 | T1 | `account.currentMobile` | 当前手机号 | Aktuelle Mobilfunknummer | | ✅ |
| 18 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | Verfügbarer Speicherplatz auf dem Gerät | | ⚠️ 长度比3.58 |
| 19 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | Geräteschlüssel aktualisiert | | ✅ |
| 20 | T1 | `account.deviceList` | 设备列表 | Geräteliste | | ✅ |
| 21 | T1 | `account.deviceName` | 设备名称 | Gerätename | | ✅ |
| 22 | T1 | `account.deviceType` | 设备类型 | Gerätetyp | | ✅ |
| 23 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | Vom Gerät verwendeter Speicherplatz | | ✅ |
| 24 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | Geräte-ID | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | one:「Vor $n Tag」 / other:「Vor $n Tagen」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | one:「Vor $n Stunde」 / other:「Vor $n Stunden」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | one:「Vor $n Minute」 / other:「Vor $n Minuten」 | | ✅ |
| 28 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | Der vom Server bereitgestellte öffentliche Compliance-Schlüssel stimmt nicht mit dem lokal gepinnten Wert überein. Handelt es sich um eine beabsichtigte Schlüsselrotation durch den Administrator, tippen Sie auf „Rotation bestätigen“; andernfalls senden Sie keine weiteren verschlüsselten Nachrichten und kontaktieren Sie den Administrator zur Prüfung. | | ⚠️ 长度比2.88 |
| 29 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | Vergleichen Sie den Sicherheitscode persönlich oder telefonisch mit der anderen Person. Bei Übereinstimmung wird Ihre Kommunikation nicht abgehört; bei Abweichung beenden Sie sofort das Gespräch und verifizieren Sie die Identität über einen anderen Kanal. Der Verifizierungsstatus wird nur auf diesem Gerät gespeichert. | | ✅ |
| 30 | T3 | `chat.e2eeRecoveryNewDeviceBody` | 为保护消息安全，本设备已生成新的端到端加密密钥。 历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「本地备份导入」恢复。 | Zum Schutz deiner Nachrichten wurde auf diesem Gerät ein neuer Ende-zu-Ende-Verschlüsselungsschlüssel erzeugt. Ältere Nachrichten wurden mit dem Schlüssel des alten Geräts verschlüsselt und sind erst nach Wiederherstellung des Schlüssels sichtbar. Du kannst ihn über „Lokales Backup importieren“ wiederherstellen. | | ✅ |

