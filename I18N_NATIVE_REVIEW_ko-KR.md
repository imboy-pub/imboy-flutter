# i18n 母语审核包 —— ko-KR

> 本文件为 [I18N_NATIVE_REVIEW_PACKAGE.md](./I18N_NATIVE_REVIEW_PACKAGE.md) 的按语言分发版（2026-09-06 拆分）。
> 审核完成后请回填每行「结论」列（APPROVED / CHANGES_REQUESTED + 建议译文 / BLOCKED_NO_REVIEWER），
> 并由集成者回写主包总览表。审核人：________　日期：________


## 검토자님께
안녕하세요! IMBoy는 종단간 암호화를 지원하는 셀프호스팅 채팅 앱입니다. 출시 전에 원어민 분들께 UI 문구를 최종 검토받고 있어요. 도움 주셔서 감사합니다!

**진행 방법**: 아래 표를 한 줄씩 확인하며 「ko-KR 译文」 열(한국어 번역)을 점검해 주세요(중국어 열은 참고용이며, 중국어를 읽지 않으셔도 됩니다):

- 번역에 문제없음 → 여섯 번째 열(제목 结论, 현재 비어 있음)에 `✅` 표기
- 수정 필요 → 여섯 번째 열에 `✗` 표기 후, 마지막 열(제목 建议译文, 기본값 ✅)에 수정안을 작성

총 31행, 약 15~20분 걸립니다. 고유명사와 브랜드명(Alipay, WeChat Pay, Huabei 등)은 의도적으로 라틴 문자로 유지하고 있습니다. 명백한 오류가 아니면 바꾸지 않으셔도 됩니다.

다 보신 후 이 파일을 요청드린 분께 그대로 돌려주시면 됩니다. 감사합니다!

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
| 9 | T1 | `account.bindAlipay` | 绑定支付宝 | Alipay 연동 | | ✅ |
| 10 | T1 | `account.bindMobile` | 绑定手机号 | 휴대폰 번호 연결 | | ✅ |
| 11 | T1 | `account.bindMobileFor` | 用于登录、找回密码和接收重要通知 | 로그인, 비밀번호 찾기 및 중요 알림 수신에 사용 | | ✅ |
| 12 | T1 | `account.changeLoginPassword` | 修改登录密码 | 로그인 비밀번호 변경 | | ✅ |
| 13 | T1 | `account.changeMobile` | 更换手机号 | 휴대폰 번호 변경 | | ✅ |
| 14 | T1 | `account.codeSentToEmail` | 验证码已发送到邮箱 | 인증 코드가 이메일로 전송되었습니다 | | ✅ |
| 15 | T1 | `account.codeSentToMobile` | 验证码已发送到手机 | 인증 코드가 휴대폰으로 전송되었습니다 | | ✅ |
| 16 | T1 | `account.currentDevice` | 当前设备 | 현재 기기 | | ✅ |
| 17 | T1 | `account.currentMobile` | 当前手机号 | 현재 휴대폰 번호 | | ✅ |
| 18 | T1 | `account.deviceAvailableSpace` | 设备可用空间 | 기기 사용 가능 공간 | | ✅ |
| 19 | T1 | `account.deviceKeyRefreshed` | 设备密钥已刷新 | 기기 키가 새로고침되었습니다 | | ✅ |
| 20 | T1 | `account.deviceList` | 设备列表 | 기기 목록 | | ✅ |
| 21 | T1 | `account.deviceName` | 设备名称 | 기기 이름 | | ✅ |
| 22 | T1 | `account.deviceType` | 设备类型 | 기기 유형 | | ✅ |
| 23 | T1 | `account.deviceUsedSpace` | 设备已使用空间 | 기기 사용 공간 | | ✅ |
| 24 | T1 | `account.e2eeDeviceIdLabel` | 设备 ID | 기기 ID | | ✅ |
| 25 | T2 | `common.timeDaysAgo(plural)` | other:「$n天前」 | other:「$n일 전」 | | ✅ |
| 26 | T2 | `common.timeHoursAgo(plural)` | other:「$n小时前」 | other:「$n시간 전」 | | ✅ |
| 27 | T2 | `common.timeMinutesAgo(plural)` | other:「$n分钟前」 | other:「$n분 전」 | | ✅ |
| 28 | T3 | `main.safetyNumberHint` | 请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。 | 대면 또는 전화로 상대방과 보안 번호를 비교해 주세요. 일치하면 두 사람의 통신에 중간자가 없는 것이고, 일치하지 않으면 즉시 대화를 중단하고 다른 경로로 상대방의 신원을 확인하세요. 검증 상태는 이 기기에만 저장됩니다. | | ✅ |
| 29 | T3 | `discovery.nearbyPeopleExplain` | 附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。 | 주변 사용자가 귀하의 프로필을 보고 메시지를 보낼 수 있습니다. 이는 새 친구를 찾는 데 도움이 될 수 있지만 과도한 주의를 끌 수도 있습니다. 언제든지 프로필 공유를 중단할 수 있습니다. 전화번호는 숨겨집니다. | | ✅ |
| 30 | T3 | `chat.e2eeRecoveryNewDeviceBody` | 为保护消息安全，本设备已生成新的端到端加密密钥。 历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「本地备份导入」恢复。 | 메시지를 보호하기 위해 이 기기에서 새로운 종단간 암호화 키를 생성했습니다. 이전 메시지는 이전 기기의 키로 암호화되어 있어 키를 복원해야 볼 수 있습니다. "로컬 백업 가져오기"를 통해 복원할 수 있습니다. | | ✅ |
| 31† | T1 | `common.e2eeBackupImportSuccessNote` | 注意：仅备份中包含且成功写入的群聊会话可用于读取对应历史；单聊历史无法恢复，因为单聊密钥不跨设备备份 | 참고: 이 백업에 포함되고 정상적으로 저장된 그룹 세션만 해당 기록을 읽는 데 사용할 수 있습니다. 1:1 키는 기기 간에 백업되지 않으므로 개인 대화 기록은 복원할 수 없습니다. | | ✅ |
> † 2026-09-08 增补：包生成后该键译文被更新（E2EE 备份导入语义精确化），纳入本轮审核范围。

