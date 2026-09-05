# i18n 母语审核包（Native Review Package）

> 生成时间：2026-09-05 ｜ 基准 locale：zh-CN ｜ 待审语言：8
> 结论口径（任务书 P17，只接受以下三种）：
> **APPROVED**（本行译文可发布）／ **CHANGES_REQUESTED**（在"建议译文"列写出替换文本）／ **BLOCKED_NO_REVIEWER**（该语言整行标无人审核）。
> 审核人只需审本包内文案；包外键已由自动门（missing/placeholder/duplicate/结构）与 widget 级 UI Gate 覆盖。

## 选取规则（可复现）

1. **Tier 1 高风险域**：键名或 zh-CN 值命中 安全/隐私/支付/删除/注销/封禁/验证 等正则（RISK_NAME ∪ RISK_VALUE），按 key 字母序，每语言上限 24 条。
2. **Tier 2 复数节点**：全部 plural 键，各分支内联展示（one/few/many/other:「…」）；复数语法是机器翻译错误高发区（如俄语需 one/few/many/other 四分支）。
3. **Tier 3 最长文案**：该语言未入选键中按译文长度取前 3（机器翻译生硬高发区）。

## AI 预筛列说明（2026-09-05）

> 倒数第二列为 **AI 预筛**（规则扫描 + 人工复核），仅标记机器可判定的异常（占位符、文字体系、长度比离群、复数分支、已知疑点）。
> **AI 预筛 ≠ 母语审核**：✅ 只代表"未见机器可检异常"，不代表译文地道；Gate 4 仍为 BLOCKED_NO_REVIEWER。
> ⚠️ 行请审核人优先复核；长度比高的合规/支付类长文案已按真实约束（widget 级 UI Gate 零溢出）验证过布局安全性，此处标记仅供语义复核参考。

## 总览（审核人填写）

| 语言 | 审核人 | 结论 | 日期 | 备注 |
|------|--------|------|------|------|
| ar-SA | ______ | ______ | ______ | |
| de-DE | ______ | ______ | ______ | |
| fr-FR | ______ | ______ | ______ | |
| it-IT | ______ | ______ | ______ | |
| ja-JP | ______ | ______ | ______ | |
| ko-KR | ______ | ______ | ______ | |
| ru-RU | ______ | ______ | ______ | |
| zh-Hant | ______ | ______ | ______ | |

---

### ar-SA

| # | Tier | Key | zh-CN（基准） | ar-SA 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | أمان الحساب | | ✅ |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | تحسين أمان الحساب | | ✅ |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | تم الدفع بنجاح | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | ستحصل على 5g من الطاقة الخضراء عند نجاح الدفع | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | يرجى إدخال كلمة مرور الدفع | | ✅ |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | المبلغ: | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | اختيار طريقة الدفع | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | هل أنت متأكد من أنك تريد تسجيل الخروج؟ | | ✅ |
| 9 | T1 | `account.bindMobile` | 绑定手机号 | ربط رقم الهاتف المحمول | | ✅ |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | يستخدم لتسجيل الدخول واستعادة كلمة المرور واستلام الإشعارات المهمة | | ✅ |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | تعديل كلمة مرور تسجيل الدخول | | ✅ |
| 12 | T1 | `account.changeMobile` | 更换手机号 | تغيير رقم الهاتف | | ✅ |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | تم إرسال رمز التحقق إلى البريد الإلكتروني | | ✅ |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | تم إرسال رمز التحقق إلى الهاتف | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | الجهاز الحالي | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | رقم الهاتف الحالي | | ✅ |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | المساحة المتوفرة في الجهاز | | ✅ |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | تم تحديث مفتاح الجهاز | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | قائمة الأجهزة | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | اسم الجهاز | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | نوع الجهاز | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | المساحة المستخدمة في الجهاز | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | معرّف الجهاز | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | تحسين أمان الحساب | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | other:「منذ $n يوم」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | other:「منذ $n ساعة」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | other:「منذ $n دقيقة」 | | ✅ |
| 28 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | قارن رمز الأمان مع الطرف الآخر وجهاً لوجه أو عبر الهاتف. إذا تطابق الرمزان فهذا يعني أن اتصالكما ليس خاضعاً لتنصت وسيط؛ وإذا اختلف فأوقف المحادثة فوراً وتحقق من هوية الطرف الآخر عبر قناة أخرى. تُحفظ حالة التحقق على هذا الجهاز فقط. | | ✅ |
| 29 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | المفتاح العام لتدقيق الامتثال الصادر من الخادم لا يطابق القيمة المثبتة محلياً. إذا كان هذا تدويراً مقصوداً للمفتاح من المسؤول، فانقر على «تأكيد التدوير»؛ وإلا فلا تُكمل إرسال الرسائل المشفّرة، واتصل بالمسؤول للتحقق. | | ✅ |
| 30 | T3 | `workspace.inviteDesc` | 仅支持邀请已注册用户；加入工作区不自动入群或订阅频道——可同时加入 General 群，并发送 Announcements 频道邀请 | الدعوة متاحة للمستخدمين المسجلين فقط؛ الانضمام إلى مساحة العمل لا يعني تلقائياً الانضمام إلى المجموعات أو الاشتراك في القنوات — يمكنك الانضمام في الوقت نفسه إلى مجموعة General وإرسال دعوة قناة Announcements | | ✅ |

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
| 9 | T1 | `account.bindMobile` | 绑定手机号 | Mobilfunknummer verbinden | | ✅ |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | Für Anmeldung, Passwort-Wiederherstellung und Empfang wichtiger Benachrichtigungen | | ⚠️ 长度比2.82 |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | Anmeldepasswort ändern | | ✅ |
| 12 | T1 | `account.changeMobile` | 更换手机号 | Mobilfunknummer ändern | | ✅ |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | Bestätigungscode an E-Mail gesendet | | ✅ |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | Bestätigungscode an Mobilfunknummer gesendet | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | Aktuelles Gerät | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | Aktuelle Mobilfunknummer | | ✅ |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | Verfügbarer Speicherplatz auf dem Gerät | | ⚠️ 长度比3.58 |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | Geräteschlüssel aktualisiert | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | Geräteliste | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | Gerätename | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | Gerätetyp | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | Vom Gerät verwendeter Speicherplatz | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | Geräte-ID | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | Kontosicherheit verbessern | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | one:「Vor $n Tag」 / other:「Vor $n Tagen」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | one:「Vor $n Stunde」 / other:「Vor $n Stunden」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | one:「Vor $n Minute」 / other:「Vor $n Minuten」 | | ✅ |
| 28 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | Der vom Server bereitgestellte öffentliche Compliance-Schlüssel stimmt nicht mit dem lokal gepinnten Wert überein. Handelt es sich um eine beabsichtigte Schlüsselrotation durch den Administrator, tippen Sie auf „Rotation bestätigen“; andernfalls senden Sie keine weiteren verschlüsselten Nachrichten und kontaktieren Sie den Administrator zur Prüfung. | | ⚠️ 长度比2.88 |
| 29 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | Vergleichen Sie den Sicherheitscode persönlich oder telefonisch mit der anderen Person. Bei Übereinstimmung wird Ihre Kommunikation nicht abgehört; bei Abweichung beenden Sie sofort das Gespräch und verifizieren Sie die Identität über einen anderen Kanal. Der Verifizierungsstatus wird nur auf diesem Gerät gespeichert. | | ✅ |
| 30 | T3 | `main.complianceKeyInfoChangedWarning` | ⚠️ 服务端下发的合规公钥与本地固定不一致！若这不是管理员有意的轮换，请立即联系管理员，并停止发送加密消息。 | ⚠️ Der vom Server bereitgestellte öffentliche Compliance-Schlüssel stimmt nicht mit dem lokalen Pinning überein! Falls dies keine beabsichtigte Rotation durch den Administrator ist, kontaktieren Sie sofort den Administrator und senden Sie keine verschlüsselten Nachrichten. | | ⚠️ 长度比2.85 |

### fr-FR

| # | Tier | Key | zh-CN（基准） | fr-FR 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | Sécurité du compte | | ✅ |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | Améliorer la sécurité du compte | | ⚠️ 长度比2.84 |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | Paiement réussi | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | Paiement réussi : 5 g d'énergie verte offerts | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | Veuillez saisir le mot de passe de paiement | | ⚠️ 长度比3.38 |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | Montant : | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | Choisir le mode de paiement | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | Êtes-vous sûr de vouloir vous déconnecter ? | | ✅ |
| 9 | T1 | `account.bindMobile` | 绑定手机号 | Associer le numéro de téléphone | | ⚠️ 长度比3.41 |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | Utilisé pour la connexion, la récupération du mot de passe et la réception de notifications importantes. | | ⚠️ 长度比3.57 |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | Modifier le mot de passe de connexion | | ⚠️ 长度比3.39 |
| 12 | T1 | `account.changeMobile` | 更换手机号 | Changer de numéro de téléphone | | ⚠️ 长度比3.30 |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | Code envoyé par e-mail | | ✅ |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | Code envoyé par SMS | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | Appareil actuel | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | Numéro de téléphone actuel | | ⚠️ 长度比2.86 |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | Espace disponible sur l'appareil | | ⚠️ 长度比2.93 |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | Clé actualisée | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | Liste des appareils | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | Nom de l'appareil | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | Type d'appareil | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | Espace utilisé sur l'appareil | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | ID d'appareil | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | Améliorer la sécurité du compte | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | one:「Il y a $n jour」 / other:「Il y a $n jours」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | one:「Il y a $n heure」 / other:「Il y a $n heures」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | one:「Il y a $n minute」 / other:「Il y a $n minutes」 | | ✅ |
| 28 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | Comparez le code de sécurité avec votre correspondant en personne ou par téléphone. S'il correspond, vos communications ne sont pas interceptées par un intermédiaire ; dans le cas contraire, arrêtez immédiatement la conversation et vérifiez son identité par un autre canal. L'état de vérification n'est conservé que sur cet appareil. | | ✅ |
| 29 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | La clé publique d'audit de conformité fournie par le serveur ne correspond pas à la valeur épinglée localement. S'il s'agit d'une rotation de clés voulue par l'administrateur, appuyez sur « Confirmer la rotation » ; sinon, n'envoyez plus de messages chiffrés et contactez l'administrateur pour vérification. | | ✅ |
| 30 | T3 | `common.cancelLogoutBody` | 此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。 | Ce compte est en période de rétractation. Si vous vous connectez avec succès, cela sera considéré comme une annulation du processus de suppression. Pour continuer la suppression, ne vous connectez pas à IMBoy dans les 15 jours suivant la soumission de la demande de suppression. | | ⚠️ 长度比2.84 |

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
| 9 | T1 | `account.bindMobile` | 绑定手机号 | Collega numero di telefono | | ⚠️ 长度比2.86 |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | Usato per accedere, recuperare la password e ricevere notifiche importanti | | ✅ |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | Modifica password di accesso | | ✅ |
| 12 | T1 | `account.changeMobile` | 更换手机号 | Cambia numero di telefono | | ✅ |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | Codice di verifica inviato all'email | | ✅ |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | Codice di verifica inviato al telefono | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | Dispositivo corrente | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | Numero di telefono attuale | | ⚠️ 长度比2.86 |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | Spazio disponibile dispositivo | | ✅ |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | Chiave aggiornata | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | Lista dispositivi | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | Nome dispositivo | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | Tipo dispositivo | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | Spazio utilizzato dispositivo | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | ID dispositivo | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | Migliora sicurezza account | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | one:「$n giorno fa」 / other:「$n giorni fa」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | one:「$n ora fa」 / other:「$n ore fa」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | one:「$n minuto fa」 / other:「$n minuti fa」 | | ✅ |
| 28 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | Confronta il codice di sicurezza con l'altro di persona o al telefono. Se corrisponde, le vostre comunicazioni non sono intercettate da un attacco man-in-the-middle; se non corrisponde, interrompi subito la conversazione e verifica l'identità dell'altro tramite un altro canale. Lo stato di verifica è salvato solo su questo dispositivo. | | ✅ |
| 29 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | La chiave pubblica di audit di conformità distribuita dal server non corrisponde al valore bloccato localmente. Se si tratta di una rotazione della chiave intenzionale dell'amministratore, tocca «Conferma rotazione»; in caso contrario non continuare a inviare messaggi cifrati e contatta l'amministratore per una verifica. | | ✅ |
| 30 | T3 | `common.cancelLogoutBody` | 此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。 | Questo account è nel periodo di riflessione per la disattivazione. Se l'accesso ha successo, verrà considerato come terminazione del processo di disattivazione. Per continuare la disattivazione, non accedere a IMBoy entro 15 giorni dalla presentazione della richiesta di disattivazione. | | ⚠️ 长度比2.92 |

### ja-JP

| # | Tier | Key | zh-CN（基准） | ja-JP 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | アカウントのセキュリティ | | ⚠️ 长度比3.00 |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | アカウントのセキュリティを強化 | | ✅ |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | 支払いが完了しました | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | 支払いが成功するとグリーンエネルギー5gを獲得できます | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | 支払いパスワードを入力してください | | ✅ |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | 金額： | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | 支払い方法を選択 | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | ログアウトしてもよろしいですか？ | | ✅ |
| 9 | T1 | `account.bindMobile` | 绑定手机号 | 携帯電話番号を登録 | | ✅ |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | ログイン、パスワード回復、重要通知の受信に使用します | | ✅ |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | ログインパスワードを変更 | | ✅ |
| 12 | T1 | `account.changeMobile` | 更换手机号 | 携帯電話番号を変更 | | ✅ |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | 認証コードをメールに送信しました | | ✅ |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | 認証コードを携帯電話に送信しました | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | 現在のデバイス | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | 現在の携帯電話番号 | | ✅ |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | デバイスの空き容量 | | ✅ |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | デバイスキーを更新しました | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | デバイスリスト | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | デバイス名 | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | デバイスタイプ | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | デバイスの使用容量 | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | デバイス ID | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | アカウントのセキュリティを強化 | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | other:「$n日前」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | other:「$n時間前」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | other:「$n分前」 | | ✅ |
| 28 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | サーバーから配信されたコンプライアンス監査の公開鍵が、ローカルの固定値と一致しません。これが管理者による意図的なキーローテーションであれば「ローテーションを承認」をタップしてください。そうでない場合は、暗号化メッセージの送信をやめ、管理者に確認してください。 | | ✅ |
| 29 | T3 | `discovery.nearbyPeopleExplain` | 附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。 | 近くのユーザーがあなたのプロフィールを表示してメッセージを送ることができます。これは新しい友達を見つけるのに役立つかもしれませんが、過度な注意を引く可能性もあります。いつでもプロフィールの共有を停止できます。 電話番号は非表示になります。 | | ✅ |
| 30 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | 対面または電話で、相手と安全番号を照合してください。一致していれば、通信が中間者によって盗聴されていないことを意味します。一致しない場合は、直ちに会話を中止し、別の手段で相手の身元を確認してください。検証状態はこの端末にのみ保存されます。 | | ✅ |

### ko-KR

| # | Tier | Key | zh-CN（基准） | ko-KR 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | 계정 보안 | | ✅ |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | 계정 보안 강화 | | ✅ |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | 결제 성공 | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | 결제 시 그린 에너지 5g 획득 | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | 결제 비밀번호를 입력해 주세요 | | ✅ |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | 금액: | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | 결제 수단 선택 | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | 로그아웃 하시겠습니까? | | ✅ |
| 9 | T1 | `account.bindMobile` | 绑定手机号 | 휴대폰 번호 연결 | | ✅ |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | 로그인, 비밀번호 찾기 및 중요 알림 수신에 사용 | | ✅ |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | 로그인 비밀번호 변경 | | ✅ |
| 12 | T1 | `account.changeMobile` | 更换手机号 | 휴대폰 번호 변경 | | ✅ |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | 인증 코드가 이메일로 전송되었습니다 | | ✅ |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | 인증 코드가 휴대폰으로 전송되었습니다 | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | 현재 기기 | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | 현재 휴대폰 번호 | | ✅ |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | 기기 사용 가능 공간 | | ✅ |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | 기기 키가 새로고침되었습니다 | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | 기기 목록 | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | 기기 이름 | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | 기기 유형 | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | 기기 사용 공간 | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | 기기 ID | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | 계정 보안 향상 | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | other:「$n일 전」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | other:「$n시간 전」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | other:「$n분 전」 | | ✅ |
| 28 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | 대면 또는 전화로 상대방과 보안 번호를 비교해 주세요. 일치하면 두 사람의 통신에 중간자가 없는 것이고, 일치하지 않으면 즉시 대화를 중단하고 다른 경로로 상대방의 신원을 확인하세요. 검증 상태는 이 기기에만 저장됩니다. | | ✅ |
| 29 | T3 | `discovery.nearbyPeopleExplain` | 附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。 | 주변 사용자가 귀하의 프로필을 보고 메시지를 보낼 수 있습니다. 이는 새 친구를 찾는 데 도움이 될 수 있지만 과도한 주의를 끌 수도 있습니다. 언제든지 프로필 공유를 중단할 수 있습니다. 전화번호는 숨겨집니다. | | ✅ |
| 30 | T3 | `workspace.inviteDesc` | 仅支持邀请已注册用户；加入工作区不自动入群或订阅频道——可同时加入 General 群，并发送 Announcements 频道邀请 | 가입한 사용자만 초대할 수 있습니다. 워크스페이스 가입이 자동으로 그룹 가입이나 채널 구독으로 이어지지 않습니다. General 그룹에 동시 가입시키고 Announcements 채널 초대를 보낼 수 있습니다 | | ✅ |

### ru-RU

| # | Tier | Key | zh-CN（基准） | ru-RU 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | Безопасность аккаунта | | ⚠️ 长度比2.89 |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | Повысить безопасность аккаунта | | ✅ |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | Платёж выполнен | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | За платёж начислено 5 г зелёной энергии | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | Введите платёжный пароль | | ✅ |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | Сумма: | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | Выберите способ оплаты | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | Вы уверены, что хотите выйти? | | ✅ |
| 9 | T1 | `account.bindMobile` | 绑定手机号 | Привязать мобильный | | ✅ |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | Для входа, восстановления пароля и уведомлений | | ✅ |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | Изменить пароль для входа | | ✅ |
| 12 | T1 | `account.changeMobile` | 更换手机号 | Изменить мобильный | | ✅ |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | Код подтверждения отправлен на электронную почту | | ⚠️ 长度比2.93 |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | Код подтверждения отправлен на мобильный | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | Текущее устройство | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | Текущий мобильный | | ✅ |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | Доступное место на устройстве | | ✅ |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | Ключ устройства обновлён | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | Список устройств | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | Имя устройства | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | Тип устройства | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | Использованное место на устройстве | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | ID устройства | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | Повысить безопасность аккаунта | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | one:「$n день назад」 / few:「$n дня назад」 / many:「$n дней назад」 / other:「$n дня назад」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | one:「$n час назад」 / few:「$n часа назад」 / many:「$n часов назад」 / other:「$n часа назад」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | one:「$n минуту назад」 / few:「$n минуты назад」 / many:「$n минут назад」 / other:「$n минуты назад」 | | ✅ |
| 28 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | Открытый ключ комплаенс-аудита, выданный сервером, не совпадает с локально зафиксированным значением. Если это намеренная ротация ключа администратором, нажмите «Подтвердить ротацию»; иначе не отправляйте зашифрованные сообщения и обратитесь к администратору для проверки. | | ✅ |
| 29 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | Сравните код безопасности с собеседником лично или по телефону. Если коды совпадают, ваша связь не прослушивается посредником; если нет — немедленно прекратите разговор и проверьте личность собеседника другим способом. Статус проверки хранится только на этом устройстве. | | ✅ |
| 30 | T3 | `discovery.nearbyPeopleExplain` | 附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。 | Пользователи рядом могут просматривать ваш профиль и отправлять вам сообщения. Это может помочь вам найти новых друзей, но также может привлечь чрезмерное внимание. Вы можете в любое время прекратить публикацию вашего профиля. Ваш номер телефона будет скрыт. | | ✅ |

### zh-Hant

| # | Tier | Key | zh-CN（基准） | zh-Hant 译文 | 结论 | 建议译文 |
|---|------|-----|--------------|------------|------|----------|
| 1 | T1 | `account.accountSecurity` | 账号安全 | 帳號安全 | | ✅ |
| 2 | T1 | `account.accountSecurityEnhance` | 提升账户安全 | 提升帳號安全 | | ✅ |
| 3 | T1 | `account.alipaySim.alipaySuccess` | 支付成功 | 付款成功 | | ✅ |
| 4 | T1 | `account.alipaySim.energy` | 支付成功得绿色能量 5g | 付款成功得綠色能量 5g | | ✅ |
| 5 | T1 | `account.alipaySim.enterPassword` | 请输入支付密码 | 請輸入支付密碼 | | ✅ |
| 6 | T1 | `account.alipaySim.paymentAmount` | 金额： | 金額： | | ✅ |
| 7 | T1 | `account.alipaySim.selectMethod` | 选择支付方式 | 選擇付款方式 | | ✅ |
| 8 | T1 | `account.areYouSureLogOut` | 确定要退出登录吗？ | 確定要登出嗎？ | | ✅ |
| 9 | T1 | `account.bindMobile` | 绑定手机号 | 綁定手機號 | | ✅ |
| 10 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | 用於登入、找回密碼和接收重要通知 | | ✅ |
| 11 | T1 | `account.changeLoginPassword` | 修改登录密码 | 修改登入密碼 | | ✅ |
| 12 | T1 | `account.changeMobile` | 更换手机号 | 更換手機號 | | ✅ |
| 13 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | 驗證碼已傳送到郵箱 | | ✅ |
| 14 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | 驗證碼已傳送到手機 | | ✅ |
| 15 | T1 | `account.currentDevice` | 当前设备 | 目前設備 | | ✅ |
| 16 | T1 | `account.currentMobile` | 当前手机号 | 目前手機號 | | ✅ |
| 17 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | 設備可用空間 | | ✅ |
| 18 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | 裝置金鑰已重新整理 | | ✅ |
| 19 | T1 | `account.deviceList` | 设备列表 | 設備清單 | | ✅ |
| 20 | T1 | `account.deviceName` | 设备名称 | 設備名稱 | | ✅ |
| 21 | T1 | `account.deviceType` | 设备类型 | 設備類型 | | ✅ |
| 22 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | 設備已使用空間 | | ✅ |
| 23 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | 裝置 ID | | ✅ |
| 24 | T1 | `account.enhanceAccountSecurity` | 提升账号安全性 | 提升帳號安全性 | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | other:「$n天前」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | other:「$n小時前」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | other:「$n分鐘前」 | | ✅ |
| 28 | T3 | `discovery.nearbyPeopleExplain` | 附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。 | 附近的用家可以檢視您的個人資料並給您發送訊息。這可能會幫助您找到新朋友，但也可能會引起過多的關注。您可以隨時停止分享您的個人資料。 您的電話號碼將會被隱藏。 | | ✅ |
| 29 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | 請透過面對面或電話與對方比對安全碼。若一致，表示你們的通訊沒有被中間人監聽；若不一致，請立即停止對話，並透過其他管道核實對方身分。驗證狀態僅保存在本機。 | | ✅ |
| 30 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | 伺服器下發的合規稽核公開金鑰與本地固定值不一致。若這是管理員有意進行的金鑰輪替，請點擊「確認輪替」；否則請勿繼續傳送加密訊息，並請聯絡管理員查明。 | | ✅ |

