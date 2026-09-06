# i18n 母语审核包 —— fr-FR

> 本文件为 [I18N_NATIVE_REVIEW_PACKAGE.md](./I18N_NATIVE_REVIEW_PACKAGE.md) 的按语言分发版（2026-09-06 拆分）。
> 审核完成后请回填每行「结论」列（APPROVED / CHANGES_REQUESTED + 建议译文 / BLOCKED_NO_REVIEWER），
> 并由集成者回写主包总览表。审核人：________　日期：________


## Au relecteur / à la relectrice
Bonjour ! IMBoy est une application de messagerie chiffrée de bout en bout (auto-hébergeable). Avant la publication, nous faisons relire nos textes d'interface par des locuteurs natifs — merci pour votre aide !

**Mode d'emploi** : parcourez le tableau ci-dessous ligne par ligne et vérifiez la colonne « fr-FR 译文 » (traduction française ; la colonne chinoise n'est qu'une référence, pas besoin de lire le chinois) :

- traduction correcte → écrivez `✅` dans la sixième colonne (en-tête 结论, vide pour l'instant) ;
- traduction à corriger → écrivez `✗` dans la sixième colonne et proposez votre version dans la dernière colonne (en-tête 建议译文, qui contient ✅ par défaut).

30 lignes au total, 15 à 20 minutes environ. Les noms propres et marques (Alipay, WeChat Pay, Huabei…) restent volontairement en caractères latins — ne les modifiez que s'ils sont réellement erronés.

Une fois terminé, renvoyez simplement ce fichier à la personne qui vous a contacté. Merci beaucoup !

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
| 9 | T1 | `account.bindAlipay` | 绑定支付宝 | Lier Alipay | | ✅ |
| 10 | T1 | `account.bindMobile` | 绑定手机号 | Associer le numéro de téléphone | | ⚠️ 长度比3.41 |
| 11 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | Utilisé pour la connexion, la récupération du mot de passe et la réception de notifications importantes. | | ⚠️ 长度比3.57 |
| 12 | T1 | `account.changeLoginPassword` | 修改登录密码 | Modifier le mot de passe de connexion | | ⚠️ 长度比3.39 |
| 13 | T1 | `account.changeMobile` | 更换手机号 | Changer de numéro de téléphone | | ⚠️ 长度比3.30 |
| 14 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | Code envoyé par e-mail | | ✅ |
| 15 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | Code envoyé par SMS | | ✅ |
| 16 | T1 | `account.currentDevice` | 当前设备 | Appareil actuel | | ✅ |
| 17 | T1 | `account.currentMobile` | 当前手机号 | Numéro de téléphone actuel | | ⚠️ 长度比2.86 |
| 18 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | Espace disponible sur l'appareil | | ⚠️ 长度比2.93 |
| 19 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | Clé actualisée | | ✅ |
| 20 | T1 | `account.deviceList` | 设备列表 | Liste des appareils | | ✅ |
| 21 | T1 | `account.deviceName` | 设备名称 | Nom de l'appareil | | ✅ |
| 22 | T1 | `account.deviceType` | 设备类型 | Type d'appareil | | ✅ |
| 23 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | Espace utilisé sur l'appareil | | ✅ |
| 24 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | ID d'appareil | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | one:「Il y a $n jour」 / other:「Il y a $n jours」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | one:「Il y a $n heure」 / other:「Il y a $n heures」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | one:「Il y a $n minute」 / other:「Il y a $n minutes」 | | ✅ |
| 28 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | Comparez le code de sécurité avec votre correspondant en personne ou par téléphone. S'il correspond, vos communications ne sont pas interceptées par un intermédiaire ; dans le cas contraire, arrêtez immédiatement la conversation et vérifiez son identité par un autre canal. L'état de vérification n'est conservé que sur cet appareil. | | ✅ |
| 29 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | La clé publique d'audit de conformité fournie par le serveur ne correspond pas à la valeur épinglée localement. S'il s'agit d'une rotation de clés voulue par l'administrateur, appuyez sur « Confirmer la rotation » ; sinon, n'envoyez plus de messages chiffrés et contactez l'administrateur pour vérification. | | ✅ |
| 30 | T3 | `chat.e2eeRecoveryNewDeviceBody` | 为保护消息安全，本设备已生成新的端到端加密密钥。 历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「本地备份导入」恢复。 | Pour protéger vos messages, une nouvelle clé de chiffrement de bout en bout a été générée sur cet appareil. Les anciens messages ont été chiffrés avec la clé de l'ancien appareil et ne seront visibles qu'après restauration de la clé. Vous pouvez la restaurer via « Importer une sauvegarde locale ». | | ✅ |

