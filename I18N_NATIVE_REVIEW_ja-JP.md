# i18n 母语审核包 —— ja-JP

> 本文件为 [I18N_NATIVE_REVIEW_PACKAGE.md](./I18N_NATIVE_REVIEW_PACKAGE.md) 的按语言分发版（2026-09-06 拆分）。
> 审核完成后请回填每行「结论」列（APPROVED / CHANGES_REQUESTED + 建议译文 / BLOCKED_NO_REVIEWER），
> 并由集成者回写主包总览表。审核人：________　日期：________


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
| 9 | T1 | `account.bindAlipay` | 绑定支付宝 | Alipayを連携 | | ✅ |
| 10 | T1 | `account.bindMobile` | 绑定手机号 | 携帯電話番号を登録 | | ✅ |
| 11 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | ログイン、パスワード回復、重要通知の受信に使用します | | ✅ |
| 12 | T1 | `account.changeLoginPassword` | 修改登录密码 | ログインパスワードを変更 | | ✅ |
| 13 | T1 | `account.changeMobile` | 更换手机号 | 携帯電話番号を変更 | | ✅ |
| 14 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | 認証コードをメールに送信しました | | ✅ |
| 15 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | 認証コードを携帯電話に送信しました | | ✅ |
| 16 | T1 | `account.currentDevice` | 当前设备 | 現在のデバイス | | ✅ |
| 17 | T1 | `account.currentMobile` | 当前手机号 | 現在の携帯電話番号 | | ✅ |
| 18 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | デバイスの空き容量 | | ✅ |
| 19 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | デバイスキーを更新しました | | ✅ |
| 20 | T1 | `account.deviceList` | 设备列表 | デバイスリスト | | ✅ |
| 21 | T1 | `account.deviceName` | 设备名称 | デバイス名 | | ✅ |
| 22 | T1 | `account.deviceType` | 设备类型 | デバイスタイプ | | ✅ |
| 23 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | デバイスの使用容量 | | ✅ |
| 24 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | デバイス ID | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | other:「$n日前」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | other:「$n時間前」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | other:「$n分前」 | | ✅ |
| 28 | T3 | `common.complianceKeyChangedBody` | 服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。 | サーバーから配信されたコンプライアンス監査の公開鍵が、ローカルの固定値と一致しません。これが管理者による意図的なキーローテーションであれば「ローテーションを承認」をタップしてください。そうでない場合は、暗号化メッセージの送信をやめ、管理者に確認してください。 | | ✅ |
| 29 | T3 | `discovery.nearbyPeopleExplain` | 附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。 | 近くのユーザーがあなたのプロフィールを表示してメッセージを送ることができます。これは新しい友達を見つけるのに役立つかもしれませんが、過度な注意を引く可能性もあります。いつでもプロフィールの共有を停止できます。 電話番号は非表示になります。 | | ✅ |
| 30 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | 対面または電話で、相手と安全番号を照合してください。一致していれば、通信が中間者によって盗聴されていないことを意味します。一致しない場合は、直ちに会話を中止し、別の手段で相手の身元を確認してください。検証状態はこの端末にのみ保存されます。 | | ✅ |

