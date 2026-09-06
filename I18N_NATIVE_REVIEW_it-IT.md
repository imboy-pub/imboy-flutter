# i18n 母语审核包 —— it-IT

> 本文件为 [I18N_NATIVE_REVIEW_PACKAGE.md](./I18N_NATIVE_REVIEW_PACKAGE.md) 的按语言分发版（2026-09-06 拆分）。
> 审核完成后请回填每行「结论」列（APPROVED / CHANGES_REQUESTED + 建议译文 / BLOCKED_NO_REVIEWER），
> 并由集成者回写主包总览表。审核人：________　日期：________


### it-IT

| # | Tier | Key | zh-CN（基准） | it-IT 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | Sicurezza account | | ✅ |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | Migliora la sicurezza dell'account | | ⚠️ 长度比3.12 |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | Pagamento riuscito | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | Pagamento riuscito: ottieni 5g di energia verde | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | Inserisci la password di pagamento | | ✅ |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | Importo: | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | Seleziona metodo di pagamento | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | Sei sicuro di volerti disconnettere? | | ✅ |
| 9 | T1 | `account.bindAlipay` | 绑定支付宝 | Collega Alipay | | ✅ |
| 10 | T1 | `account.bindMobile` | 绑定手机号 | Collega numero di telefono | | ⚠️ 长度比2.86 |
| 11 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | Usato per accedere, recuperare la password e ricevere notifiche importanti | | ✅ |
| 12 | T1 | `account.changeLoginPassword` | 修改登录密码 | Modifica password di accesso | | ✅ |
| 13 | T1 | `account.changeMobile` | 更换手机号 | Cambia numero di telefono | | ✅ |
| 14 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | Codice di verifica inviato all'email | | ✅ |
| 15 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | Codice di verifica inviato al telefono | | ✅ |
| 16 | T1 | `account.currentDevice` | 当前设备 | Dispositivo corrente | | ✅ |
| 17 | T1 | `account.currentMobile` | 当前手机号 | Numero di telefono attuale | | ⚠️ 长度比2.86 |
| 18 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | Spazio disponibile dispositivo | | ✅ |
| 19 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | Chiave aggiornata | | ✅ |
| 20 | T1 | `account.deviceList` | 设备列表 | Lista dispositivi | | ✅ |
| 21 | T1 | `account.deviceName` | 设备名称 | Nome dispositivo | | ✅ |
| 22 | T1 | `account.deviceType` | 设备类型 | Tipo dispositivo | | ✅ |
| 23 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | Spazio utilizzato dispositivo | | ✅ |
| 24 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | ID dispositivo | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | one:「$n giorno fa」 / other:「$n giorni fa」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | one:「$n ora fa」 / other:「$n ore fa」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | one:「$n minuto fa」 / other:「$n minuti fa」 | | ✅ |
| 28 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | Confronta il codice di sicurezza con l'altro di persona o al telefono. Se corrisponde, le vostre comunicazioni non sono intercettate da un attacco man-in-the-middle; se non corrisponde, interrompi subito la conversazione e verifica l'identità dell'altro tramite un altro canale. Lo stato di verifica è salvato solo su questo dispositivo. | | ✅ |
| 29 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | La chiave pubblica di audit di conformità distribuita dal server non corrisponde al valore bloccato localmente. Se si tratta di una rotazione della chiave intenzionale dell'amministratore, tocca «Conferma rotazione»; in caso contrario non continuare a inviare messaggi cifrati e contatta l'amministratore per una verifica. | | ✅ |
| 30 | T3 | `chat.e2eeRecoveryNewDeviceBody` | 为保护消息安全，本设备已生成新的端到端加密密钥。 历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「本地备份导入」恢复。 | Per proteggere i messaggi, su questo dispositivo è stata generata una nuova chiave di crittografia end-to-end. I messaggi precedenti sono stati crittografati con la chiave del vecchio dispositivo e saranno visibili solo dopo il ripristino della chiave. Puoi ripristinarla tramite "Importa backup locale". | | ✅ |

