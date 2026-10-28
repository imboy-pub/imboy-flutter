///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsZhCn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-CN>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$account$zh_CN account = Translations$account$zh_CN.internal(_root);
	late final Translations$agent$zh_CN agent = Translations$agent$zh_CN.internal(_root);
	late final Translations$agentTask$zh_CN agentTask = Translations$agentTask$zh_CN.internal(_root);
	late final Translations$appeal$zh_CN appeal = Translations$appeal$zh_CN.internal(_root);
	late final Translations$attachmentManager$zh_CN attachmentManager = Translations$attachmentManager$zh_CN.internal(_root);
	late final Translations$billing$zh_CN billing = Translations$billing$zh_CN.internal(_root);
	late final Translations$channel$zh_CN channel = Translations$channel$zh_CN.internal(_root);
	late final Translations$chat$zh_CN chat = Translations$chat$zh_CN.internal(_root);
	late final Translations$common$zh_CN common = Translations$common$zh_CN.internal(_root);
	late final Translations$complaint$zh_CN complaint = Translations$complaint$zh_CN.internal(_root);
	late final Translations$complaintReason$zh_CN complaintReason = Translations$complaintReason$zh_CN.internal(_root);
	late final Translations$contact$zh_CN contact = Translations$contact$zh_CN.internal(_root);
	late final Translations$customerService$zh_CN customerService = Translations$customerService$zh_CN.internal(_root);
	late final Translations$discovery$zh_CN discovery = Translations$discovery$zh_CN.internal(_root);
	late final Translations$enterpriseApp$zh_CN enterpriseApp = Translations$enterpriseApp$zh_CN.internal(_root);
	late final Translations$enterpriseOa$zh_CN enterpriseOa = Translations$enterpriseOa$zh_CN.internal(_root);
	late final Translations$error$zh_CN error = Translations$error$zh_CN.internal(_root);
	late final Translations$group$zh_CN group = Translations$group$zh_CN.internal(_root);
	late final Translations$groupCategory$zh_CN groupCategory = Translations$groupCategory$zh_CN.internal(_root);
	late final Translations$groupDiscovery$zh_CN groupDiscovery = Translations$groupDiscovery$zh_CN.internal(_root);
	late final Translations$groupList$zh_CN groupList = Translations$groupList$zh_CN.internal(_root);
	late final Translations$groupSchedule$zh_CN groupSchedule = Translations$groupSchedule$zh_CN.internal(_root);
	late final Translations$groupTag$zh_CN groupTag = Translations$groupTag$zh_CN.internal(_root);
	late final Translations$groupTask$zh_CN groupTask = Translations$groupTask$zh_CN.internal(_root);
	late final Translations$groupVote$zh_CN groupVote = Translations$groupVote$zh_CN.internal(_root);
	late final Translations$main$zh_CN main = Translations$main$zh_CN.internal(_root);
	late final Translations$mention$zh_CN mention = Translations$mention$zh_CN.internal(_root);
	late final Translations$momentFriendPicker$zh_CN momentFriendPicker = Translations$momentFriendPicker$zh_CN.internal(_root);
	late final Translations$momentNotify$zh_CN momentNotify = Translations$momentNotify$zh_CN.internal(_root);
	late final Translations$organization$zh_CN organization = Translations$organization$zh_CN.internal(_root);
	late final Translations$passport$zh_CN passport = Translations$passport$zh_CN.internal(_root);
	late final Translations$splash$zh_CN splash = Translations$splash$zh_CN.internal(_root);
	late final Translations$talkRecord$zh_CN talkRecord = Translations$talkRecord$zh_CN.internal(_root);
	late final Translations$welcome$zh_CN welcome = Translations$welcome$zh_CN.internal(_root);
	late final Translations$workspace$zh_CN workspace = Translations$workspace$zh_CN.internal(_root);
}

// Path: account
class Translations$account$zh_CN {
	Translations$account$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '账号'
	String get account => '账号';

	/// zh-CN: '账号安全'
	String get accountSecurity => '账号安全';

	/// zh-CN: '头像'
	String get avatar => '头像';

	/// zh-CN: '提升账户安全'
	String get accountSecurityEnhance => '提升账户安全';

	/// zh-CN: '绑定手机号'
	String get bindMobile => '绑定手机号';

	/// zh-CN: '用于登录、找回密码和接收重要通知'
	String get bindMobileFor => '用于登录、找回密码和接收重要通知';

	/// zh-CN: '关联邮箱'
	String get linkEmail => '关联邮箱';

	/// zh-CN: '用于登录、身份验证和接收账单'
	String get linkEmailFor => '用于登录、身份验证和接收账单';

	/// zh-CN: '验证码已发送到邮箱'
	String get codeSentToEmail => '验证码已发送到邮箱';

	/// zh-CN: '验证码已发送到手机'
	String get codeSentToMobile => '验证码已发送到手机';

	/// zh-CN: '当前设备'
	String get currentDevice => '当前设备';

	/// zh-CN: '设备可用空间'
	String get deviceAvailableSpace => '设备可用空间';

	/// zh-CN: '设备列表'
	String get deviceList => '设备列表';

	/// zh-CN: '设备名称'
	String get deviceName => '设备名称';

	/// zh-CN: '设备类型'
	String get deviceType => '设备类型';

	/// zh-CN: '设备已使用空间'
	String get deviceUsedSpace => '设备已使用空间';

	/// zh-CN: '邮箱'
	String get email => '邮箱';

	/// zh-CN: '忘记密码？'
	String get forgotPassword => '忘记密码？';

	/// zh-CN: '性别'
	String get gender => '性别';

	/// zh-CN: '群二维码'
	String get groupQrcode => '群二维码';

	/// zh-CN: '账号/邮箱'
	String get hintLoginAccount => '账号/邮箱';

	/// zh-CN: '退出登录'
	String get logOut => '退出登录';

	/// zh-CN: '确定要退出登录吗？'
	String get areYouSureLogOut => '确定要退出登录吗？';

	/// zh-CN: '登录'
	String get login => '登录';

	/// zh-CN: '登录设备管理'
	String get loginDeviceManagement => '登录设备管理';

	/// zh-CN: '登录邮箱'
	String get loginEmail => '登录邮箱';

	/// zh-CN: '注销账号'
	String get logoutAccount => '注销账号';

	/// zh-CN: '注销申请已提交，预计 $date 完成'
	String logoutPendingBanner({required Object date}) => '注销申请已提交，预计 ${date} 完成';

	/// zh-CN: '注销申请状态'
	String get logoutPendingHeader => '注销申请状态';

	/// zh-CN: '撤销注销申请'
	String get logoutCancelRequest => '撤销注销申请';

	/// zh-CN: '注销申请已撤销'
	String get logoutCancelledNote => '注销申请已撤销';

	/// zh-CN: '数据留存说明'
	String get logoutRetainedHeader => '数据留存说明';

	/// zh-CN: '删除完成后：审计日志与财务记录依法留存并匿名化；你拥有的群/工作区/频道将优先转移给继任成员'
	String get logoutRetainedNote => '删除完成后：审计日志与财务记录依法留存并匿名化；你拥有的群/工作区/频道将优先转移给继任成员';

	/// zh-CN: '手机'
	String get mobile => '手机';

	/// zh-CN: '一键登录'
	String get mobileQuickLogin => '一键登录';

	/// zh-CN: '我的账号'
	String get myAccount => '我的账号';

	/// zh-CN: '我的二维码'
	String get myQrcode => '我的二维码';

	/// zh-CN: '新的密码'
	String get newPassword => '新的密码';

	/// zh-CN: '新注册的人'
	String get newlyRegisteredPeople => '新注册的人';

	/// zh-CN: '昵称'
	String get nickname => '昵称';

	/// zh-CN: '请输入昵称'
	String get nicknameHint => '请输入昵称';

	/// zh-CN: '密码'
	String get password => '密码';

	/// zh-CN: '找回密码'
	String get recoverPassword => '找回密码';

	/// zh-CN: '生日'
	String get birthday => '生日';

	/// zh-CN: '地区'
	String get region => '地区';

	/// zh-CN: '重新输入密码'
	String get retypePassword => '重新输入密码';

	/// zh-CN: '扫描二维码'
	String get scanQrCode => '扫描二维码';

	/// zh-CN: '设置昵称'
	String get setNickname => '设置昵称';

	/// zh-CN: '个性签名'
	String get signature => '个性签名';

	/// zh-CN: '注册'
	String get signup => '注册';

	/// zh-CN: '通过扫一扫添加'
	String get sourceQrcode => '通过扫一扫添加';

	/// zh-CN: '修改邮箱'
	String get changeEmail => '修改邮箱';

	/// zh-CN: '绑定邮箱'
	String get bindEmail => '绑定邮箱';

	/// zh-CN: '当前邮箱'
	String get currentEmail => '当前邮箱';

	/// zh-CN: '设置密码'
	String get setPassword => '设置密码';

	/// zh-CN: '设置登录密码'
	String get setLoginPassword => '设置登录密码';

	/// zh-CN: '提升账号安全性'
	String get enhanceAccountSecurity => '提升账号安全性';

	/// zh-CN: '密码长度为4-32的任意字符'
	String get passwordLengthRequirement => '密码长度为4-32的任意字符';

	/// zh-CN: '密码至少需要$min个字符'
	String passwordMinLength({required Object min}) => '密码至少需要${min}个字符';

	/// zh-CN: '请输入密码'
	String get pleaseEnterPassword => '请输入密码';

	/// zh-CN: '更换手机号'
	String get changeMobile => '更换手机号';

	/// zh-CN: '当前手机号'
	String get currentMobile => '当前手机号';

	/// zh-CN: '新手机号'
	String get newMobile => '新手机号';

	/// zh-CN: '请输入手机号'
	String get enterMobileHint => '请输入手机号';

	/// zh-CN: '注销账号'
	String get privacyLogoutAccount => '注销账号';

	/// zh-CN: '钱包'
	String get wallet => '钱包';

	/// zh-CN: '修改登录密码'
	String get changeLoginPassword => '修改登录密码';

	/// zh-CN: '其他设备'
	String get otherDevice => '其他设备';

	/// zh-CN: '登录密码'
	String get loginPassword => '登录密码';

	/// zh-CN: '用于登录IMBoy账号'
	String get loginPasswordDesc => '用于登录IMBoy账号';

	/// zh-CN: '旧密码'
	String get oldPassword => '旧密码';

	/// zh-CN: '请输入旧密码'
	String get enterOldPassword => '请输入旧密码';

	/// zh-CN: '请输入新密码'
	String get enterNewPassword => '请输入新密码';

	/// zh-CN: '请再次输入新密码'
	String get enterNewPasswordAgain => '请再次输入新密码';

	/// zh-CN: '我的二维码'
	String get myQRCode => '我的二维码';

	/// zh-CN: '个人资料'
	String get profile => '个人资料';

	/// zh-CN: '设置性别'
	String get setGender => '设置性别';

	/// zh-CN: '设置生日'
	String get setBirthday => '设置生日';

	/// zh-CN: '• 昵称长度为2-24个字符 • 不能仅包含空白字符或表情符号 • 不能包含敏感词汇 • 修改后将在所有聊天中显示'
	String get nicknameRules => '• 昵称长度为2-24个字符 • 不能仅包含空白字符或表情符号 • 不能包含敏感词汇 • 修改后将在所有聊天中显示';

	/// zh-CN: '刷新设备密钥'
	String get refreshDeviceKey => '刷新设备密钥';

	/// zh-CN: '如果消息无法解密，点击此按钮刷新密钥'
	String get refreshDeviceKeyHint => '如果消息无法解密，点击此按钮刷新密钥';

	/// zh-CN: '正在刷新设备密钥...'
	String get refreshingDeviceKey => '正在刷新设备密钥...';

	/// zh-CN: '设备密钥已刷新'
	String get deviceKeyRefreshed => '设备密钥已刷新';

	/// zh-CN: '充值'
	String get rechargeTitle => '充值';

	/// zh-CN: '请输入充值金额（元），0.01元～10000元'
	String get rechargeAmountHint => '请输入充值金额（元），0.01元～10000元';

	/// zh-CN: '例如：100'
	String get rechargeAmountExample => '例如：100';

	/// zh-CN: '选择支付方式'
	String get payMethodTitle => '选择支付方式';

	/// zh-CN: '钱包余额'
	String get payMethodWallet => '钱包余额';

	/// zh-CN: '模拟支付（开发环境）'
	String get payMethodMock => '模拟支付（开发环境）';

	/// zh-CN: '支付宝'
	String get payMethodAlipay => '支付宝';

	/// zh-CN: '微信支付'
	String get payMethodWechat => '微信支付';

	/// zh-CN: '该支付方式即将开通，敬请期待'
	String get payMethodComingSoon => '该支付方式即将开通，敬请期待';

	/// zh-CN: '支付已取消'
	String get payCancelled => '支付已取消';

	/// zh-CN: '设备 ID'
	String get e2eeDeviceIdLabel => '设备 ID';

	/// zh-CN: '扫码登录'
	String get webQRLoginTitle => '扫码登录';

	/// zh-CN: '使用 ImBoy 手机版扫描二维码'
	String get webQRLoginHint => '使用 ImBoy 手机版扫描二维码';

	/// zh-CN: '使用账号密码登录'
	String get webSwitchToPassword => '使用账号密码登录';

	/// zh-CN: '账号登录'
	String get webPasswordLoginTitle => '账号登录';

	/// zh-CN: '请输入账号/手机号/邮箱'
	String get webAccountHint => '请输入账号/手机号/邮箱';

	/// zh-CN: '请输入密码'
	String get webPasswordHint => '请输入密码';

	/// zh-CN: '请重新登录'
	String get pleaseRelogin => '请重新登录';

	/// zh-CN: '其他登录方式'
	String get otherLoginMethods => '其他登录方式';

	late final Translations$account$alipaySim$zh_CN alipaySim = Translations$account$alipaySim$zh_CN.internal(_root);

	/// zh-CN: '绑定支付宝'
	String get bindAlipay => '绑定支付宝';

	/// zh-CN: '解除绑定'
	String get unbindAlipay => '解除绑定';

	/// zh-CN: '确认解除绑定'
	String get confirmUnbindAlipay => '确认解除绑定';
}

// Path: agent
class Translations$agent$zh_CN {
	Translations$agent$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: 'AI 助手广场'
	String get plazaTitle => 'AI 助手广场';

	/// zh-CN: '这里的成员都是 AI 助手，身份会明确标注；加密聊天里，只有真人。'
	String get transparencyBanner => '这里的成员都是 AI 助手，身份会明确标注；加密聊天里，只有真人。';

	/// zh-CN: '搜索助手'
	String get searchHint => '搜索助手';

	/// zh-CN: '暂无 AI 助手，稍后再来看看'
	String get emptyTitle => '暂无 AI 助手，稍后再来看看';

	/// zh-CN: '无匹配的助手'
	String get searchEmpty => '无匹配的助手';

	/// zh-CN: '发消息'
	String get sendMessage => '发消息';

	/// zh-CN: 'AI'
	String get badgeAi => 'AI';

	/// zh-CN: '官方'
	String get badgeOfficial => '官方';

	/// zh-CN: 'AI 助手'
	String get badgeAiA11y => 'AI 助手';

	/// zh-CN: '官方账号'
	String get badgeOfficialA11y => '官方账号';

	/// zh-CN: '此机器人入口已升级，请到 AI 助手广场与助手对话'
	String get legacyBotMigrated => '此机器人入口已升级，请到 AI 助手广场与助手对话';

	/// zh-CN: '去助手广场'
	String get legacyBotGoPlaza => '去助手广场';
}

// Path: agentTask
class Translations$agentTask$zh_CN {
	Translations$agentTask$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: 'AI 任务'
	String get title => 'AI 任务';

	/// zh-CN: '执行中'
	String get working => '执行中';

	/// zh-CN: '已提交'
	String get submitted => '已提交';

	/// zh-CN: '进行中'
	String get progress => '进行中';

	/// zh-CN: '已完成'
	String get completed => '已完成';

	/// zh-CN: '执行失败'
	String get failed => '执行失败';

	/// zh-CN: '已取消'
	String get cancelled => '已取消';

	/// zh-CN: '待审批'
	String get awaitingApproval => '待审批';

	/// zh-CN: '批准'
	String get approve => '批准';

	/// zh-CN: '拒绝'
	String get reject => '拒绝';
}

// Path: appeal
class Translations$appeal$zh_CN {
	Translations$appeal$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '处置与申诉'
	String get title => '处置与申诉';

	/// zh-CN: '针对我的处置'
	String get actionsSection => '针对我的处置';

	/// zh-CN: '暂无处置记录'
	String get actionsEmpty => '暂无处置记录';

	/// zh-CN: '我的申诉'
	String get appealsSection => '我的申诉';

	/// zh-CN: '暂无申诉记录'
	String get appealsEmpty => '暂无申诉记录';

	/// zh-CN: '发起申诉'
	String get dialogTitle => '发起申诉';

	/// zh-CN: '请说明申诉理由（必填）'
	String get reasonPlaceholder => '请说明申诉理由（必填）';

	/// zh-CN: '提交申诉'
	String get submit => '提交申诉';

	/// zh-CN: '申诉提交失败'
	String get submitFailed => '申诉提交失败';

	/// zh-CN: '已申诉'
	String get appealedTag => '已申诉';

	/// zh-CN: '可申诉'
	String get appealableTag => '可申诉';

	/// zh-CN: '警告'
	String get actionWarning => '警告';

	/// zh-CN: '群禁言'
	String get actionGroupMute => '群禁言';

	/// zh-CN: '移出群聊'
	String get actionGroupKick => '移出群聊';

	/// zh-CN: '驳回内容'
	String get actionReject => '驳回内容';

	/// zh-CN: '账号受限'
	String get actionAccountRestrict => '账号受限';

	/// zh-CN: '内容删除'
	String get actionContentRemoval => '内容删除';

	/// zh-CN: '待复审'
	String get statusPending => '待复审';

	/// zh-CN: '已翻案'
	String get statusAccepted => '已翻案';

	/// zh-CN: '已维持'
	String get statusRejected => '已维持';

	/// zh-CN: '一切正常'
	String get allClearTitle => '一切正常';

	/// zh-CN: '没有针对你的处置，也不需要申诉。'
	String get allClearSubtitle => '没有针对你的处置，也不需要申诉。';
}

// Path: attachmentManager
class Translations$attachmentManager$zh_CN {
	Translations$attachmentManager$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '附件'
	String get title => '附件';

	/// zh-CN: '检索当前工作区内有权查看的群组、频道和面聊附件。'
	String get centerHint => '检索当前工作区内有权查看的群组、频道和面聊附件。';

	/// zh-CN: '全部群组'
	String get allGroups => '全部群组';

	/// zh-CN: '全部频道'
	String get allChannels => '全部频道';

	/// zh-CN: '全部上传人'
	String get allPeople => '全部上传人';

	/// zh-CN: '上传人姓名、账号或编号'
	String get personSearch => '上传人姓名、账号或编号';

	/// zh-CN: '时间范围'
	String get dateRange => '时间范围';

	/// zh-CN: '清除筛选'
	String get clearFilters => '清除筛选';

	/// zh-CN: '本机附件'
	String get personalTitle => '本机附件';

	/// zh-CN: '企业附件'
	String get enterpriseTitle => '企业附件';

	/// zh-CN: '按本机聊天记录查找附件，点按文件返回来源消息。'
	String get personalHint => '按本机聊天记录查找附件，点按文件返回来源消息。';

	/// zh-CN: '本机可见不代表云端备份。清缓存保留消息索引；删除聊天记录后不会自动恢复。加密内容仍需要可用密钥。'
	String get personalBoundary => '本机可见不代表云端备份。清缓存保留消息索引；删除聊天记录后不会自动恢复。加密内容仍需要可用密钥。';

	/// zh-CN: '群组附件'
	String get groupSource => '群组附件';

	/// zh-CN: '选择当前工作区内的群组查看云端文件。'
	String get enterpriseHint => '选择当前工作区内的群组查看云端文件。';

	/// zh-CN: '已标记“企业留存”的附件由企业云端保留，不随本机缓存或聊天记录清理而删除；查看权限仍按来源群组、频道或面聊记录的权限控制。'
	String get enterpriseBoundary => '已标记“企业留存”的附件由企业云端保留，不随本机缓存或聊天记录清理而删除；查看权限仍按来源群组、频道或面聊记录的权限控制。';

	/// zh-CN: '搜索附件名称'
	String get searchHint => '搜索附件名称';

	/// zh-CN: '搜索群组'
	String get searchGroupsHint => '搜索群组';

	/// zh-CN: '暂无本机可查看附件'
	String get emptyLocal => '暂无本机可查看附件';

	/// zh-CN: '未找到匹配附件'
	String get emptySearch => '未找到匹配附件';

	/// zh-CN: '查看来源消息'
	String get openSource => '查看来源消息';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '本机消息索引'
	String get localOnly => '本机消息索引';

	/// zh-CN: '清理临时缓存？'
	String get cacheConfirmTitle => '清理临时缓存？';

	/// zh-CN: '将清理临时下载和预览缓存，不删除聊天记录、加密密钥或企业云端附件。部分内容再次查看时需要下载。'
	String get cacheConfirmBody => '将清理临时下载和预览缓存，不删除聊天记录、加密密钥或企业云端附件。部分内容再次查看时需要下载。';

	/// zh-CN: '缓存清理失败，请稍后重试'
	String get cacheFailed => '缓存清理失败，请稍后重试';

	/// zh-CN: '清理临时缓存'
	String get cacheAction => '清理临时缓存';

	/// zh-CN: '此处管理设备占用；查找和查看附件请使用本机附件。'
	String get storageHint => '此处管理设备占用；查找和查看附件请使用本机附件。';

	/// zh-CN: '来源会话已不存在，无法安全打开附件'
	String get unavailableSource => '来源会话已不存在，无法安全打开附件';

	/// zh-CN: '加载更多失败，请重试。'
	String get moreFailed => '加载更多失败，请重试。';

	/// zh-CN: '附件加载失败，请重试'
	String get loadFailed => '附件加载失败，请重试';

	/// zh-CN: '共 ${count} 个附件'
	String resultCount({required Object count}) => '共 ${count} 个附件';

	/// zh-CN: '试试调整关键词或筛选条件'
	String get emptyHint => '试试调整关键词或筛选条件';

	/// zh-CN: '清除筛选'
	String get clearFiltersAction => '清除筛选';

	/// zh-CN: '重试'
	String get retryAction => '重试';

	/// zh-CN: '选择群组'
	String get selectGroupTitle => '选择群组';

	/// zh-CN: '选择频道'
	String get selectChannelTitle => '选择频道';

	/// zh-CN: '企业留存'
	String get enterpriseRetained => '企业留存';

	/// zh-CN: '未纳入留存'
	String get enterpriseUnmanaged => '未纳入留存';

	/// zh-CN: '全部来源'
	String get sourceAll => '全部来源';

	/// zh-CN: '群组'
	String get sourceGroups => '群组';

	/// zh-CN: '频道'
	String get sourceChannels => '频道';

	/// zh-CN: '面聊记录'
	String get sourceTalkRecords => '面聊记录';

	/// zh-CN: '查看面聊记录；播放与导出仍按记录权限控制。'
	String get talkRecordSourceHint => '查看面聊记录；播放与导出仍按记录权限控制。';

	/// zh-CN: '检索本企业内有权查看的附件，包含未归入工作区的面聊记录。'
	String get organizationCenterHint => '检索本企业内有权查看的附件，包含未归入工作区的面聊记录。';

	/// zh-CN: '附件治理'
	String get governanceAction => '附件治理';

	/// zh-CN: '已批准清理'
	String get governancePurgeApproved => '已批准清理';

	/// zh-CN: '批准清理不代表文件已删除，实际进度以清理状态为准。'
	String get governancePhysicalPending => '批准清理不代表文件已删除，实际进度以清理状态为准。';

	/// zh-CN: '记录版本已变化，请刷新后核对再提交。'
	String get governanceRefreshConflict => '记录版本已变化，请刷新后核对再提交。';

	/// zh-CN: '保全原因（最多 200 字）'
	String get governanceHoldReason => '保全原因（最多 200 字）';

	/// zh-CN: '延长留存至'
	String get governanceExtendUntil => '延长留存至';

	/// zh-CN: '批准此附件清理？批准后不能恢复治理状态；仍须满足所有引用、上传及处理保护条件，才会进入清理。'
	String get governancePurgeConfirm => '批准此附件清理？批准后不能恢复治理状态；仍须满足所有引用、上传及处理保护条件，才会进入清理。';

	/// zh-CN: '设置保全'
	String get governanceHoldAction => '设置保全';

	/// zh-CN: '解除保全'
	String get governanceReleaseHoldAction => '解除保全';

	/// zh-CN: '延长留存'
	String get governanceExtendAction => '延长留存';

	/// zh-CN: '批准清理'
	String get governancePurgeAction => '批准清理';
}

// Path: billing
class Translations$billing$zh_CN {
	Translations$billing$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '套餐订阅'
	String get title => '套餐订阅';

	/// zh-CN: '月付'
	String get planPeriodMonthly => '月付';

	/// zh-CN: '年付'
	String get planPeriodYearly => '年付';

	/// zh-CN: '立即订阅'
	String get subscribe => '立即订阅';

	/// zh-CN: '当前套餐'
	String get currentPlan => '当前套餐';

	/// zh-CN: '暂无可售套餐，敬请期待'
	String get noPlans => '暂无可售套餐，敬请期待';

	/// zh-CN: '加载失败，请下拉重试'
	String get loadFailed => '加载失败，请下拉重试';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '订阅成功'
	String get paySuccess => '订阅成功';

	/// zh-CN: '支付失败'
	String get payFailed => '支付失败';

	/// zh-CN: '支付已取消'
	String get payCancelled => '支付已取消';

	/// zh-CN: '选择支付方式'
	String get payMethodTitle => '选择支付方式';

	/// zh-CN: '模拟支付（开发环境）'
	String get payMethodMock => '模拟支付（开发环境）';

	/// zh-CN: '支付宝'
	String get payMethodAlipay => '支付宝';

	/// zh-CN: '微信支付'
	String get payMethodWechat => '微信支付';

	/// zh-CN: '该支付方式即将开通，敬请期待'
	String get payMethodComingSoon => '该支付方式即将开通，敬请期待';

	/// zh-CN: '不限'
	String get quotaUnlimited => '不限';
}

// Path: channel
class Translations$channel$zh_CN {
	Translations$channel$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '已选图片不会保存，确定离开？'
	String get composeLeaveImagesLost => '已选图片不会保存，确定离开？';

	/// zh-CN: '频道'
	String get title => '频道';

	/// zh-CN: '加载中...'
	String get loading => '加载中...';

	/// zh-CN: '已订阅'
	String get subscribed => '已订阅';

	/// zh-CN: '管理中'
	String get managed => '管理中';

	/// zh-CN: '发现频道'
	String get discover => '发现频道';

	/// zh-CN: '创建频道'
	String get create => '创建频道';

	/// zh-CN: '创建结果未知，请稍后重试'
	String get creationRecoveryUnavailable => '创建结果未知，请稍后重试';

	/// zh-CN: '搜索频道名称或ID'
	String get searchHint => '搜索频道名称或ID';

	/// zh-CN: '未找到相关频道'
	String get noResults => '未找到相关频道';

	/// zh-CN: '暂无推荐频道 稍后再来看看吧'
	String get noRecommendedChannels => '暂无推荐频道 稍后再来看看吧';

	/// zh-CN: '暂无订阅的频道 去发现更多精彩频道吧'
	String get noSubscribedChannels => '暂无订阅的频道 去发现更多精彩频道吧';

	/// zh-CN: '暂无管理的频道 创建一个频道开始你的创作'
	String get noManagedChannels => '暂无管理的频道 创建一个频道开始你的创作';

	/// zh-CN: '订阅者'
	String get subscribers => '订阅者';

	/// zh-CN: '订阅'
	String get subscribe => '订阅';

	/// zh-CN: '订阅成功'
	String get subscribeSuccess => '订阅成功';

	/// zh-CN: '订阅失败'
	String get subscribeFailed => '订阅失败';

	/// zh-CN: '取消订阅'
	String get unsubscribe => '取消订阅';

	/// zh-CN: '取消订阅'
	String get unsubscribeConfirm => '取消订阅';

	/// zh-CN: '确定要取消订阅该频道吗？取消后将不再收到频道消息。'
	String get unsubscribeConfirmDesc => '确定要取消订阅该频道吗？取消后将不再收到频道消息。';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '分享功能即将上线'
	String get shareNotImplemented => '分享功能即将上线';

	/// zh-CN: '频道名称'
	String get nameLabel => '频道名称';

	/// zh-CN: '请输入频道名称'
	String get nameHint => '请输入频道名称';

	/// zh-CN: '频道名称不能为空'
	String get nameRequired => '频道名称不能为空';

	/// zh-CN: '频道名称不能超过50个字符'
	String get nameTooLong => '频道名称不能超过50个字符';

	/// zh-CN: '频道描述'
	String get descriptionLabel => '频道描述';

	/// zh-CN: '介绍一下你的频道（选填）'
	String get descriptionHint => '介绍一下你的频道（选填）';

	/// zh-CN: '自定义ID（选填）'
	String get customIdLabel => '自定义ID（选填）';

	/// zh-CN: '例如：my_channel'
	String get customIdHint => '例如：my_channel';

	/// zh-CN: '设置后可通过ID直接搜索到频道'
	String get customIdHelper => '设置后可通过ID直接搜索到频道';

	/// zh-CN: '只能包含字母、数字和下划线'
	String get customIdInvalid => '只能包含字母、数字和下划线';

	/// zh-CN: '长度需要在4-30个字符之间'
	String get customIdLength => '长度需要在4-30个字符之间';

	/// zh-CN: '公开'
	String get typePublic => '公开';

	/// zh-CN: '私有'
	String get typePrivate => '私有';

	/// zh-CN: '任何人都可以搜索到并订阅你的频道'
	String get typePublicDesc => '任何人都可以搜索到并订阅你的频道';

	/// zh-CN: '只有通过邀请链接才能订阅你的频道'
	String get typePrivateDesc => '只有通过邀请链接才能订阅你的频道';

	/// zh-CN: '创建频道后，你可以发布消息给所有订阅者。频道消息只有管理员可以发布。'
	String get createTips => '创建频道后，你可以发布消息给所有订阅者。频道消息只有管理员可以发布。';

	/// zh-CN: '今天'
	String get today => '今天';

	/// zh-CN: '昨天'
	String get yesterday => '昨天';

	/// zh-CN: '天前'
	String get daysAgo => '天前';

	/// zh-CN: '消息'
	String get messages => '消息';

	/// zh-CN: '阅读'
	String get views => '阅读';

	/// zh-CN: '编辑频道'
	String get editChannel => '编辑频道';

	/// zh-CN: '编辑频道功能即将上线'
	String get editChannelNotImplemented => '编辑频道功能即将上线';

	/// zh-CN: '管理管理员'
	String get manageAdmins => '管理管理员';

	/// zh-CN: '管理管理员功能即将上线'
	String get manageAdminsNotImplemented => '管理管理员功能即将上线';

	/// zh-CN: '管理订阅者'
	String get manageSubscribers => '管理订阅者';

	/// zh-CN: '管理订阅者功能即将上线'
	String get manageSubscribersNotImplemented => '管理订阅者功能即将上线';

	/// zh-CN: '删除频道'
	String get deleteChannel => '删除频道';

	/// zh-CN: '确定要删除该频道吗？此操作不可恢复。'
	String get deleteChannelConfirm => '确定要删除该频道吗？此操作不可恢复。';

	/// zh-CN: '删除频道功能即将上线'
	String get deleteChannelNotImplemented => '删除频道功能即将上线';

	/// zh-CN: '频道不存在'
	String get channelNotFound => '频道不存在';

	/// zh-CN: '频道已删除'
	String get channelDeleted => '频道已删除';

	/// zh-CN: '删除频道失败'
	String get deleteChannelFailed => '删除频道失败';

	/// zh-CN: '发布消息...'
	String get writeMessage => '发布消息...';

	/// zh-CN: '发布失败'
	String get publishFailed => '发布失败';

	/// zh-CN: '撰写图文'
	String get writeArticle => '撰写图文';

	/// zh-CN: '发布'
	String get publish => '发布';

	/// zh-CN: '预览'
	String get preview => '预览';

	/// zh-CN: '添加图片'
	String get addImage => '添加图片';

	/// zh-CN: '标题（选填）'
	String get titleOptional => '标题（选填）';

	/// zh-CN: '写点什么...支持加粗、斜体、标题、列表等格式'
	String get articleBodyHint => '写点什么...支持加粗、斜体、标题、列表等格式';

	/// zh-CN: '封面'
	String get coverLabel => '封面';

	/// zh-CN: '已设为封面'
	String get coverSet => '已设为封面';

	/// zh-CN: '加粗'
	String get formatBold => '加粗';

	/// zh-CN: '斜体'
	String get formatItalic => '斜体';

	/// zh-CN: '删除线'
	String get formatStrikethrough => '删除线';

	/// zh-CN: '标题'
	String get formatHeading => '标题';

	/// zh-CN: '列表'
	String get formatList => '列表';

	/// zh-CN: '引用'
	String get formatQuote => '引用';

	/// zh-CN: '链接'
	String get formatLink => '链接';

	/// zh-CN: '链接文字'
	String get linkTextPlaceholder => '链接文字';

	/// zh-CN: '置顶消息'
	String get pinMessage => '置顶消息';

	/// zh-CN: '取消置顶'
	String get unpinMessage => '取消置顶';

	/// zh-CN: '置顶功能即将上线'
	String get pinMessageNotImplemented => '置顶功能即将上线';

	/// zh-CN: '取消置顶功能即将上线'
	String get unpinMessageNotImplemented => '取消置顶功能即将上线';

	/// zh-CN: '消息已置顶'
	String get messagePinned => '消息已置顶';

	/// zh-CN: '已取消置顶'
	String get messageUnpinned => '已取消置顶';

	/// zh-CN: '删除消息'
	String get deleteMessage => '删除消息';

	/// zh-CN: '确定要删除这条消息吗？'
	String get deleteMessageConfirm => '确定要删除这条消息吗？';

	/// zh-CN: '消息已删除'
	String get messageDeleted => '消息已删除';

	/// zh-CN: '添加管理员'
	String get addAdmin => '添加管理员';

	/// zh-CN: '管理员添加成功'
	String get addAdminSuccess => '管理员添加成功';

	/// zh-CN: '添加管理员失败'
	String get addAdminFailed => '添加管理员失败';

	/// zh-CN: '移除管理员'
	String get removeAdmin => '移除管理员';

	/// zh-CN: '确定要移除该管理员吗？'
	String get removeAdminConfirm => '确定要移除该管理员吗？';

	/// zh-CN: '管理员已移除'
	String get removeAdminSuccess => '管理员已移除';

	/// zh-CN: '移除管理员失败'
	String get removeAdminFailed => '移除管理员失败';

	/// zh-CN: '更改角色'
	String get changeRole => '更改角色';

	/// zh-CN: '角色更新成功'
	String get updateRoleSuccess => '角色更新成功';

	/// zh-CN: '角色更新失败'
	String get updateRoleFailed => '角色更新失败';

	/// zh-CN: '从联系人选择'
	String get selectFromContacts => '从联系人选择';

	/// zh-CN: '搜索昵称或账号'
	String get searchContactsHint => '搜索昵称或账号';

	/// zh-CN: '所有好友都已是管理员'
	String get noContactsToAdd => '所有好友都已是管理员';

	/// zh-CN: '选择角色'
	String get selectRole => '选择角色';

	/// zh-CN: '暂无管理员'
	String get noAdmins => '暂无管理员';

	/// zh-CN: '创建者'
	String get roleCreator => '创建者';

	/// zh-CN: '管理员'
	String get roleAdmin => '管理员';

	/// zh-CN: '可管理频道'
	String get roleAdminDesc => '可管理频道';

	/// zh-CN: '编辑'
	String get roleEditor => '编辑';

	/// zh-CN: '可发布消息'
	String get roleEditorDesc => '可发布消息';

	/// zh-CN: '搜索订阅者'
	String get searchSubscribers => '搜索订阅者';

	/// zh-CN: '输入昵称或ID搜索'
	String get subscriberSearchHint => '输入昵称或ID搜索';

	/// zh-CN: '未找到匹配的订阅者'
	String get noSearchResults => '未找到匹配的订阅者';

	/// zh-CN: '暂无订阅者'
	String get noSubscribers => '暂无订阅者';

	/// zh-CN: '移除订阅者'
	String get removeSubscriber => '移除订阅者';

	/// zh-CN: '确定要移除该订阅者吗？'
	String get removeSubscriberConfirm => '确定要移除该订阅者吗？';

	/// zh-CN: '订阅者已移除'
	String get removeSubscriberSuccess => '订阅者已移除';

	/// zh-CN: '移除订阅者失败'
	String get removeSubscriberFailed => '移除订阅者失败';

	/// zh-CN: '订阅于'
	String get subscribedAt => '订阅于';

	/// zh-CN: '查看资料'
	String get viewProfile => '查看资料';

	/// zh-CN: '邀请好友'
	String get inviteFromContacts => '邀请好友';

	/// zh-CN: '搜索昵称或账号'
	String get inviteSearchHint => '搜索昵称或账号';

	/// zh-CN: '所有好友都已被邀请或已订阅'
	String get noContactsToInvite => '所有好友都已被邀请或已订阅';

	/// zh-CN: '邀请已发送'
	String get inviteSuccess => '邀请已发送';

	/// zh-CN: '邀请发送失败'
	String get inviteFailed => '邀请发送失败';

	/// zh-CN: '频道更新成功'
	String get updateSuccess => '频道更新成功';

	/// zh-CN: '频道更新失败'
	String get updateFailed => '频道更新失败';

	/// zh-CN: '创建后不可更改'
	String get typeCannotChange => '创建后不可更改';

	/// zh-CN: '统计信息'
	String get stats => '统计信息';

	/// zh-CN: '发送给好友'
	String get shareToChat => '发送给好友';

	/// zh-CN: '频道二维码'
	String get qrcode => '频道二维码';

	/// zh-CN: '二维码$days天内（$date前）有效'
	String qrcodeTips({required Object days, required Object date}) => '二维码${days}天内（${date}前）有效';

	/// zh-CN: '未命名频道'
	String get defaultName => '未命名频道';

	/// zh-CN: '我的订单'
	String get myOrders => '我的订单';

	/// zh-CN: '暂无订单记录'
	String get noOrders => '暂无订单记录';

	/// zh-CN: '有效期至'
	String get orderValidUntil => '有效期至';

	/// zh-CN: '待支付'
	String get orderStatusPending => '待支付';

	/// zh-CN: '已支付'
	String get orderStatusPaid => '已支付';

	/// zh-CN: '已退款'
	String get orderStatusRefunded => '已退款';

	/// zh-CN: '已取消'
	String get orderStatusCancelled => '已取消';

	/// zh-CN: '退款中'
	String get orderStatusRefunding => '退款中';

	/// zh-CN: '已过期'
	String get orderStatusExpired => '已过期';

	/// zh-CN: '订单详情'
	String get orderDetail => '订单详情';

	/// zh-CN: '订单号'
	String get orderNo => '订单号';

	/// zh-CN: '频道'
	String get orderChannel => '频道';

	/// zh-CN: '金额'
	String get orderAmount => '金额';

	/// zh-CN: '状态'
	String get orderStatusLabel => '状态';

	/// zh-CN: '支付方式'
	String get orderPaymentMethod => '支付方式';

	/// zh-CN: '下单时间'
	String get orderCreatedAt => '下单时间';

	/// zh-CN: '支付时间'
	String get orderPaidAt => '支付时间';

	/// zh-CN: '订阅周期'
	String get orderSubscriptionPeriod => '订阅周期';

	/// zh-CN: '钱包余额'
	String get payWallet => '钱包余额';

	/// zh-CN: '支付宝'
	String get payAlipay => '支付宝';

	/// zh-CN: '微信支付'
	String get payWechat => '微信支付';

	/// zh-CN: '申请退款'
	String get refundApply => '申请退款';

	/// zh-CN: '确认退款'
	String get refundConfirmTitle => '确认退款';

	/// zh-CN: '确定要对该订单申请退款吗？退款后将取消订阅。'
	String get refundConfirmMessage => '确定要对该订单申请退款吗？退款后将取消订阅。';

	/// zh-CN: '退款申请已提交'
	String get refundSuccess => '退款申请已提交';

	/// zh-CN: '取消订单'
	String get cancelOrder => '取消订单';

	/// zh-CN: '确认取消订单'
	String get cancelOrderConfirmTitle => '确认取消订单';

	/// zh-CN: '确定要取消该待支付订单吗？取消后不能继续支付。'
	String get cancelOrderConfirmMessage => '确定要取消该待支付订单吗？取消后不能继续支付。';

	/// zh-CN: '订单已取消'
	String get cancelOrderSuccess => '订单已取消';

	/// zh-CN: '继续支付'
	String get orderContinuePay => '继续支付';

	/// zh-CN: '评论'
	String get comment => '评论';

	/// zh-CN: '阅读全文'
	String get readFull => '阅读全文';

	/// zh-CN: '暂无评论'
	String get noComments => '暂无评论';

	/// zh-CN: '写评论...'
	String get writeComment => '写评论...';

	/// zh-CN: '回复'
	String get reply => '回复';

	/// zh-CN: '回复'
	String get replyTo => '回复';

	/// zh-CN: '点赞'
	String get like => '点赞';

	/// zh-CN: '评论失败'
	String get commentFailed => '评论失败';

	/// zh-CN: '删除评论'
	String get deleteComment => '删除评论';

	/// zh-CN: '确定删除这条评论吗？'
	String get deleteCommentConfirm => '确定删除这条评论吗？';

	/// zh-CN: '无权删除该评论'
	String get commentDeleteNoPermission => '无权删除该评论';

	/// zh-CN: '频道还没有发布任何内容'
	String get noMessagesManaged => '频道还没有发布任何内容';

	/// zh-CN: '作为频道主，你可以点击下方按钮发布第一条内容'
	String get noMessagesManagedDesc => '作为频道主，你可以点击下方按钮发布第一条内容';

	/// zh-CN: '订阅后查看频道内容'
	String get noMessagesVisitor => '订阅后查看频道内容';

	/// zh-CN: '本频道发布的精彩内容将在订阅后呈现'
	String get noMessagesVisitorDesc => '本频道发布的精彩内容将在订阅后呈现';

	/// zh-CN: '频道还没有发布内容'
	String get noMessagesSubscribed => '频道还没有发布内容';

	/// zh-CN: '订阅成功！请耐心等待作者发布新内容'
	String get noMessagesSubscribedDesc => '订阅成功！请耐心等待作者发布新内容';

	/// zh-CN: '继续编辑'
	String get continueEditing => '继续编辑';

	/// zh-CN: '发布第一条内容'
	String get publishFirstContent => '发布第一条内容';

	/// zh-CN: '还没有订阅者，分享给好友吧'
	String get noSubscribersDesc => '还没有订阅者，分享给好友吧';

	/// zh-CN: '全部'
	String get allCategories => '全部';

	/// zh-CN: '热门'
	String get sortPopular => '热门';

	/// zh-CN: '最新'
	String get sortNewest => '最新';

	/// zh-CN: '表情'
	String get emoji => '表情';

	/// zh-CN: '刚刚'
	String get justNow => '刚刚';

	/// zh-CN: '分钟前'
	String get minutesAgo => '分钟前';

	/// zh-CN: '小时前'
	String get hoursAgo => '小时前';

	/// zh-CN: '周前'
	String get weeksAgo => '周前';

	/// zh-CN: '可见性'
	String get visibilityLabel => '可见性';

	/// zh-CN: '付费属性'
	String get accessTypeLabel => '付费属性';

	/// zh-CN: '免费'
	String get accessTypeFree => '免费';

	/// zh-CN: '付费'
	String get accessTypePaid => '付费';

	/// zh-CN: '任何人都可以发现频道，购买后即可订阅'
	String get typePublicPaidDesc => '任何人都可以发现频道，购买后即可订阅';

	/// zh-CN: '仅受邀用户可进入购买流程，付款后即可订阅'
	String get typePrivatePaidDesc => '仅受邀用户可进入购买流程，付款后即可订阅';

	/// zh-CN: '频道信息'
	String get info => '频道信息';

	/// zh-CN: '频道设置'
	String get settings => '频道设置';

	/// zh-CN: '邀请管理员'
	String get inviteAdmins => '邀请管理员';

	/// zh-CN: '分享至我的动态'
	String get shareToMyStatus => '分享至我的动态';

	/// zh-CN: '创建者'
	String get creator => '创建者';

	/// zh-CN: '管理员'
	String get admin => '管理员';

	/// zh-CN: '编辑'
	String get editor => '编辑';

	/// zh-CN: '公开频道与隐私保护'
	String get privacyTitle => '公开频道与隐私保护';

	/// zh-CN: '任何人都可查找并关注此频道。你的电话号码对其他订阅者或频道管理员完全保密。'
	String get privacyDesc => '任何人都可查找并关注此频道。你的电话号码对其他订阅者或频道管理员完全保密。';

	/// zh-CN: '关于此频道'
	String get aboutThisChannel => '关于此频道';

	/// zh-CN: '修改照片'
	String get changePhoto => '修改照片';

	/// zh-CN: '添加照片'
	String get addPhoto => '添加照片';

	/// zh-CN: '添加描述'
	String get addDescription => '添加描述';

	/// zh-CN: '频道 “$name” 已创建'
	String channelCreated({required Object name}) => '频道 “${name}” 已创建';

	/// zh-CN: '开始发展壮大 “$name”'
	String startGrowing({required Object name}) => '开始发展壮大 “${name}”';

	/// zh-CN: '大家快来关注我的频道【$name】吧！$url'
	String shareInviteText({required Object name, required Object url}) => '大家快来关注我的频道【${name}】吧！${url}';

	/// zh-CN: '讨论区'
	String get discussion => '讨论区';

	/// zh-CN: '加入讨论'
	String get joinDiscussion => '加入讨论';

	/// zh-CN: '订阅该频道后才能加入其讨论群'
	String get discussionIneligible => '订阅该频道后才能加入其讨论群';

	/// zh-CN: '精华'
	String get essence => '精华';

	/// zh-CN: '全部内容'
	String get allPosts => '全部内容';

	/// zh-CN: '编辑标签'
	String get editPostTags => '编辑标签';

	/// zh-CN: '频道链接'
	String get linkTitle => '频道链接';

	/// zh-CN: '复制链接'
	String get copyLink => '复制链接';

	/// zh-CN: '分享链接'
	String get shareLink => '分享链接';

	/// zh-CN: '链接用于打开频道，访问和订阅仍需符合频道权限。企业频道仅限有权限的成员访问。'
	String get linkAccessHint => '链接用于打开频道，访问和订阅仍需符合频道权限。企业频道仅限有权限的成员访问。';

	/// zh-CN: '个人频道'
	String get personalChannelLabel => '个人频道';

	/// zh-CN: '企业内部频道'
	String get enterpriseChannelLabel => '企业内部频道';

	/// zh-CN: '已订阅，正在刷新'
	String get subscribePending => '已订阅，正在刷新';

	/// zh-CN: '刷新订阅状态'
	String get subscribeRefresh => '刷新订阅状态';

	/// zh-CN: '有 ${count} 条新更新'
	String unseenUpdatesBanner({required Object count}) => '有 ${count} 条新更新';
}

// Path: chat
class Translations$chat$zh_CN {
	Translations$chat$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '银行卡'
	String get bankCard => '银行卡';

	/// zh-CN: '说点什么...'
	String get messageInputHint => '说点什么...';

	/// zh-CN: '收付款'
	String get receivePayment => '收付款';

	/// zh-CN: '已是成员'
	String get alreadyMember => '已是成员';

	/// zh-CN: '待回复'
	String get awaitingReply => '待回复';

	/// zh-CN: '名片'
	String get businessCard => '名片';

	/// zh-CN: '对方正忙，请稍后重试'
	String get busyTryAgainLater => '对方正忙，请稍后重试';

	/// zh-CN: '以后再说'
	String get later => '以后再说';

	/// zh-CN: '$name 正在输入...'
	String peerIsTyping({required Object name}) => '${name} 正在输入...';

	/// zh-CN: '按住说话'
	String get chatHoldDownTalk => '按住说话';

	/// zh-CN: '聊天消息'
	String get chatMessage => '聊天消息';

	/// zh-CN: '消息免打扰'
	String get chatSettingMute => '消息免打扰';

	/// zh-CN: '已开启免打扰'
	String get chatSettingMuted => '已开启免打扰';

	/// zh-CN: '已关闭免打扰'
	String get chatSettingUnmuted => '已关闭免打扰';

	/// zh-CN: '发送中'
	String get chatStatusSending => '发送中';

	/// zh-CN: '已发送'
	String get chatStatusSent => '已发送';

	/// zh-CN: '已送达'
	String get chatStatusDelivered => '已送达';

	/// zh-CN: '已读'
	String get chatStatusSeen => '已读';

	/// zh-CN: '面对面建群'
	String get createGroupF2f => '面对面建群';

	/// zh-CN: '显示你的资料'
	String get displayProfile => '显示你的资料';

	/// zh-CN: '文件'
	String get file => '文件';

	/// zh-CN: '未知文件'
	String get unknownFile => '未知文件';

	/// zh-CN: '文件大小'
	String get fileSize => '文件大小';

	/// zh-CN: '转发'
	String get forward => '转发';

	/// zh-CN: '转发给'
	String get forwardTo => '转发给';

	/// zh-CN: '转发给朋友'
	String get forwardToFriend => '转发给朋友';

	/// zh-CN: '已转发给 $count 个会话'
	String forwardedToChats({required Object count}) => '已转发给 ${count} 个会话';

	/// zh-CN: '非常棒'
	String get great => '非常棒';

	/// zh-CN: '群文件'
	String get groupFile => '群文件';

	/// zh-CN: '图片预览'
	String get groupFileImagePreview => '图片预览';

	/// zh-CN: '视频预览'
	String get groupFileVideoPreview => '视频预览';

	/// zh-CN: '音频预览'
	String get groupFileAudioPreview => '音频预览';

	/// zh-CN: '暂停'
	String get groupFileMediaPause => '暂停';

	/// zh-CN: '播放'
	String get groupFileMediaPlay => '播放';

	/// zh-CN: '文件地址缺失，无法打开'
	String get groupFileUrlMissing => '文件地址缺失，无法打开';

	/// zh-CN: '文件地址无效'
	String get groupFileUrlInvalid => '文件地址无效';

	/// zh-CN: '文件预览'
	String get groupFilePreview => '文件预览';

	/// zh-CN: '未命名文件'
	String get groupFileUnnamed => '未命名文件';

	/// zh-CN: '${category}暂无文件'
	String groupFileCategoryEmpty({required Object category}) => '${category}暂无文件';

	/// zh-CN: '暂无群文件'
	String get groupFileEmpty => '暂无群文件';

	/// zh-CN: '文档'
	String get groupFileCategoryDoc => '文档';

	/// zh-CN: '图片'
	String get groupFileCategoryImage => '图片';

	/// zh-CN: '视频'
	String get groupFileCategoryVideo => '视频';

	/// zh-CN: '音频'
	String get groupFileCategoryAudio => '音频';

	/// zh-CN: '其他'
	String get groupFileCategoryOther => '其他';

	/// zh-CN: '群聊'
	String get groupChat => '群聊';

	/// zh-CN: '图片'
	String get image => '图片';

	/// zh-CN: '[图片]'
	String get imageMessage => '[图片]';

	/// zh-CN: '发起群聊'
	String get initiateChat => '发起群聊';

	/// zh-CN: '导出我的数据'
	String get exportMyData => '导出我的数据';

	/// zh-CN: '导出你的个人信息、联系人和聊天记录'
	String get exportDataDesc => '导出你的个人信息、联系人和聊天记录';

	/// zh-CN: '自定义消息'
	String get customMessage => '自定义消息';

	/// zh-CN: '名片'
	String get card => '名片';

	/// zh-CN: '撤回了一条消息'
	String get messageWasWithdrawn => '撤回了一条消息';

	/// zh-CN: '$param撤回了一条消息'
	String messageWasWithdrawnWithTitle({required Object param}) => '${param}撤回了一条消息';

	/// zh-CN: '离线'
	String get offline => '离线';

	/// zh-CN: '在线'
	String get online => '在线';

	/// zh-CN: '$param已存在'
	String paramAlreadyExist({required Object param}) => '${param}已存在';

	/// zh-CN: '置顶'
	String get pin => '置顶';

	/// zh-CN: '已置顶'
	String get pinned => '已置顶';

	/// zh-CN: '评级'
	String get rating => '评级';

	/// zh-CN: '已经阅读并同意$param'
	String readAgreeParam({required Object param}) => '已经阅读并同意${param}';

	/// zh-CN: '下次再说'
	String get remindMeLater => '下次再说';

	/// zh-CN: '管理快捷回复'
	String get quickReplyManage => '管理快捷回复';

	/// zh-CN: '暂无快捷回复，点击右下角添加'
	String get quickReplyEmpty => '暂无快捷回复，点击右下角添加';

	/// zh-CN: '内容已存在'
	String get quickReplyDuplicate => '内容已存在';

	/// zh-CN: '最多 $max 条'
	String quickReplyMaxReached({required Object max}) => '最多 ${max} 条';

	/// zh-CN: '输入内容...'
	String get quickReplyHint => '输入内容...';

	/// zh-CN: '禁言成员'
	String get muteMember => '禁言成员';

	/// zh-CN: '取消禁言'
	String get unmuteMember => '取消禁言';

	/// zh-CN: '已禁言'
	String get muted => '已禁言';

	/// zh-CN: '禁言 $label'
	String mutedFor({required Object label}) => '禁言 ${label}';

	/// zh-CN: '$count 分钟'
	String muteUnitMinutes({required Object count}) => '${count} 分钟';

	/// zh-CN: '$count 小时'
	String muteUnitHours({required Object count}) => '${count} 小时';

	/// zh-CN: '$count 天'
	String muteUnitDays({required Object count}) => '${count} 天';

	/// zh-CN: '你已被禁言'
	String get youAreMuted => '你已被禁言';

	/// zh-CN: '你已被禁言，剩余 $minutes 分钟'
	String youAreMutedWithTime({required Object minutes}) => '你已被禁言，剩余 ${minutes} 分钟';

	/// zh-CN: '回复于'
	String get repliedAt => '回复于';

	/// zh-CN: '回复'
	String get reply => '回复';

	/// zh-CN: '重发验证码'
	String get resendCode => '重发验证码';

	/// zh-CN: '撤回'
	String get revoke => '撤回';

	/// zh-CN: '扫描二维码名片'
	String get scanQrCodeBusinessCard => '扫描二维码名片';

	/// zh-CN: '私聊'
	String get privateChat => '私聊';

	/// zh-CN: '发送添加朋友申请'
	String get sendFriendRequest => '发送添加朋友申请';

	/// zh-CN: '消息已发出，但被对方拒收了。'
	String get sendMsgRejected => '消息已发出，但被对方拒收了。';

	/// zh-CN: '发消息'
	String get sendMessage => '发消息';

	/// zh-CN: '发送给'
	String get sendTo => '发送给';

	/// zh-CN: '发送'
	String get send => _root.common.buttonSend;

	/// zh-CN: '松开 转文字'
	String get releaseConvertToText => '松开 转文字';

	/// zh-CN: '松开 取消发送'
	String get voiceReleaseCancelSend => '松开 取消发送';

	/// zh-CN: '松开 取消'
	String get voiceReleaseCancel => '松开 取消';

	/// zh-CN: '上滑 取消 / 转文字'
	String get voiceSlideHint => '上滑 取消 / 转文字';

	/// zh-CN: '转文字'
	String get convertToText => '转文字';

	/// zh-CN: '正在发送...'
	String get sending => '正在发送...';

	/// zh-CN: '社交资料'
	String get socialProfile => '社交资料';

	/// zh-CN: '确定要打开文件吗？'
	String get sureOpenTheFile => '确定要打开文件吗？';

	/// zh-CN: '消息'
	String get titleMessage => '消息';

	/// zh-CN: '取消置顶'
	String get unpin => '取消置顶';

	/// zh-CN: '用户数据'
	String get userData => '用户数据';

	/// zh-CN: '视频'
	String get video => '视频';

	/// zh-CN: '[视频]'
	String get videoMessage => '[视频]';

	/// zh-CN: '浏览附件'
	String get viewAttachments => '浏览附件';

	/// zh-CN: '查看大图'
	String get viewLargeImage => '查看大图';

	/// zh-CN: '语音'
	String get voice => '语音';

	/// zh-CN: '语音消息'
	String get voiceMessage => '语音消息';

	/// zh-CN: '你撤回了一条消息'
	String get youWithdrewAMessage => '你撤回了一条消息';

	/// zh-CN: '格式检查'
	String get formatCheck => '格式检查';

	/// zh-CN: '功能请求'
	String get featureRequest => '功能请求';

	/// zh-CN: '重新发送'
	String get chatResend => '重新发送';

	/// zh-CN: '导出资料'
	String get profileExportProfile => '导出资料';

	/// zh-CN: '发送'
	String get momentsSend => '发送';

	/// zh-CN: '登录过期，请重新登录'
	String get loginExpiredMessage => '登录过期，请重新登录';

	/// zh-CN: '支付宝登录流程被系统中断，请重试'
	String get alipayLoginInterrupted => '支付宝登录流程被系统中断，请重试';

	/// zh-CN: '自定义图片'
	String get customImage => '自定义图片';

	/// zh-CN: '阅后即焚'
	String get burnAfterReading => '阅后即焚';

	/// zh-CN: '阅后'
	String get burnReadBadge => '阅后';

	/// zh-CN: '可读性良好'
	String get goodReadability => '可读性良好';

	/// zh-CN: '资料完善度'
	String get profileCompleteness => '资料完善度';

	/// zh-CN: '标签统计'
	String get tagStatistics => '标签统计';

	/// zh-CN: '不支持的消息类型'
	String get unsupportedMessageType => '不支持的消息类型';

	/// zh-CN: '两次密码不一致'
	String get passwordMismatch => '两次密码不一致';

	/// zh-CN: '请稍后重试'
	String get pleaseTryAgainLater => '请稍后重试';

	/// zh-CN: '历史消息暂不可用'
	String get historyUnavailable => '历史消息暂不可用';

	/// zh-CN: '服务端历史归档未开启或暂不可用，点击重试重新同步'
	String get historyUnavailableHint => '服务端历史归档未开启或暂不可用，点击重试重新同步';

	/// zh-CN: '拍摄视频'
	String get momentsRecordVideo => '拍摄视频';

	/// zh-CN: '仅自己'
	String get momentsVisibilityPrivate => '仅自己';

	/// zh-CN: '最多只能选择 9 张图片'
	String get momentsMediaTooManyImages => '最多只能选择 9 张图片';

	/// zh-CN: '最多只能选择 1 个视频'
	String get momentsMediaTooManyVideos => '最多只能选择 1 个视频';

	/// zh-CN: '图片和视频不能同时发布'
	String get momentsMediaMixedImageAndVideo => '图片和视频不能同时发布';

	/// zh-CN: '回复 @'
	String get momentsReplyPrefix => '回复 @';

	/// zh-CN: '：'
	String get momentsReplySeparator => '：';

	/// zh-CN: '正在回复 @{name}'
	String get momentsReplyingTo => '正在回复 @{name}';

	/// zh-CN: '发送新消息'
	String get sendNewMessage => '发送新消息';

	/// zh-CN: '标记已读'
	String get markRead => '标记已读';

	/// zh-CN: '标记未读'
	String get markUnread => '标记未读';

	/// zh-CN: '待处理'
	String get manualPendingBadge => '待处理';

	/// zh-CN: '取消待处理'
	String get cancelManualPending => '取消待处理';

	/// zh-CN: '非待处理'
	String get manualPendingOff => '非待处理';

	/// zh-CN: '服务端当前状态：${param}'
	String manualPendingConflict({required Object param}) => '服务端当前状态：${param}';

	/// zh-CN: '请输入个性签名'
	String get pleaseEnterSignature => '请输入个性签名';

	/// zh-CN: '导出资料'
	String get exportProfile => '导出资料';

	/// zh-CN: '设置个性签名'
	String get setSignature => '设置个性签名';

	/// zh-CN: '设置头像'
	String get setAvatar => '设置头像';

	/// zh-CN: '快进 $seconds秒'
	String fastForward({required Object seconds}) => '快进 ${seconds}秒';

	/// zh-CN: '消息ID'
	String get messageId => '消息ID';

	/// zh-CN: '聊天类型'
	String get chatType => '聊天类型';

	/// zh-CN: '正在删除...'
	String get deletingMessage => '正在删除...';

	/// zh-CN: '正在删除本地消息...'
	String get deletingLocalMessage => '正在删除本地消息...';

	/// zh-CN: '收到'
	String get quickReplyReceived => '收到';

	/// zh-CN: '谢谢'
	String get quickReplyThanks => '谢谢';

	/// zh-CN: '稍等'
	String get quickReplyWait => '稍等';

	/// zh-CN: '$count 个群聊'
	String groupCategoryGroupCount({required Object count}) => '${count} 个群聊';

	/// zh-CN: '新建群相册'
	String get groupAlbumCreateTitle => '新建群相册';

	/// zh-CN: '相册已创建'
	String get groupAlbumCreated => '相册已创建';

	/// zh-CN: '资料已完善！'
	String get profileCompleted => '资料已完善！';

	/// zh-CN: '${percent}% 完成'
	String profileProgress({required Object percent}) => '${percent}% 完成';

	/// zh-CN: '创建时间: $time'
	String createdAtLabel({required Object time}) => '创建时间: ${time}';

	/// zh-CN: '过期时间: $time'
	String expiredAtLabel({required Object time}) => '过期时间: ${time}';

	/// zh-CN: '我收到的'
	String get myReceivedTab => '我收到的';

	/// zh-CN: '状态: $status'
	String orderStatusLabel({required Object status}) => '状态: ${status}';

	/// zh-CN: '创建时间: $time'
	String orderCreatedAtLabel({required Object time}) => '创建时间: ${time}';

	/// zh-CN: '支付时间: $time'
	String orderPaymentAtLabel({required Object time}) => '支付时间: ${time}';

	/// zh-CN: '待支付'
	String get orderStatusPending => '待支付';

	/// zh-CN: '已支付'
	String get orderStatusPaid => '已支付';

	/// zh-CN: '已退款'
	String get orderStatusRefunded => '已退款';

	/// zh-CN: '已过期'
	String get orderStatusExpired => '已过期';

	/// zh-CN: '文件'
	String get defaultFileName => '文件';

	/// zh-CN: '文件链接无效'
	String get fileUrlInvalid => '文件链接无效';

	/// zh-CN: '可用'
	String get e2eeStatusAvailable => '可用';

	/// zh-CN: '生成新密钥'
	String get e2eeGenerateNewKey => '生成新密钥';

	/// zh-CN: '生成新的 E2EE 密钥对（旧消息将无法解密）'
	String get e2eeGenerateNewKeyDesc => '生成新的 E2EE 密钥对（旧消息将无法解密）';

	/// zh-CN: '已激活'
	String get e2eeActivated => '已激活';

	/// zh-CN: '创建时间'
	String get e2eeCreatedAtLabel => '创建时间';

	/// zh-CN: '正在生成密钥，请稍候...'
	String get e2eeGeneratingKey => '正在生成密钥，请稍候...';

	/// zh-CN: '新的 E2EE 密钥对已生成！'
	String get e2eeNewKeyGenerated => '新的 E2EE 密钥对已生成！';

	/// zh-CN: '多设备同步'
	String get webFeatureMultiDevice => '多设备同步';

	/// zh-CN: '在手机和电脑之间无缝切换，消息实时同步'
	String get webFeatureMultiDeviceDesc => '在手机和电脑之间无缝切换，消息实时同步';

	/// zh-CN: '端到端加密'
	String get webFeatureE2EE => '端到端加密';

	/// zh-CN: '所有消息都经过端到端加密，确保隐私安全'
	String get webFeatureE2EEDesc => '所有消息都经过端到端加密，确保隐私安全';

	/// zh-CN: '文件传输'
	String get webFeatureFileTransfer => '文件传输';

	/// zh-CN: '拖拽即可发送文件，支持各种格式'
	String get webFeatureFileTransferDesc => '拖拽即可发送文件，支持各种格式';

	/// zh-CN: '打开 ImBoy 手机版 > 设置 > 扫一扫'
	String get webQRStatusWaiting => '打开 ImBoy 手机版 > 设置 > 扫一扫';

	/// zh-CN: '请在手机上点击"确认登录"'
	String get webQRStatusScanned => '请在手机上点击"确认登录"';

	/// zh-CN: '正在验证...'
	String get webQRStatusVerifying => '正在验证...';

	/// zh-CN: '请点击刷新重新扫码'
	String get webQRStatusExpired => '请点击刷新重新扫码';

	/// zh-CN: '消息格式错误，加密失败'
	String get e2eeErrInvalidFormat => '消息格式错误，加密失败';

	/// zh-CN: '正在重新创建密钥...'
	String get e2eeRecreatingKey => '正在重新创建密钥...';

	/// zh-CN: '密钥已重新创建'
	String get e2eeKeyRecreated => '密钥已重新创建';

	/// zh-CN: '检测到新设备登录'
	String get e2eeRecoveryNewDeviceTitle => '检测到新设备登录';

	/// zh-CN: '为保护消息安全，本设备已生成新的端到端加密密钥。 历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「本地备份导入」恢复。'
	String get e2eeRecoveryNewDeviceBody => '为保护消息安全，本设备已生成新的端到端加密密钥。\n历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「本地备份导入」恢复。';

	/// zh-CN: '无法解密此消息'
	String get e2eeRecoveryDecryptFailedTitle => '无法解密此消息';

	/// zh-CN: '此消息由其他设备的密钥加密。 若你更换了设备或重新安装了应用，请恢复加密密钥后再查看历史消息。'
	String get e2eeRecoveryDecryptFailedBody => '此消息由其他设备的密钥加密。\n\n若你更换了设备或重新安装了应用，请恢复加密密钥后再查看历史消息。';

	/// zh-CN: '稍后'
	String get e2eeRecoveryLater => '稍后';

	/// zh-CN: '去恢复'
	String get e2eeRecoveryGoRecover => '去恢复';

	/// zh-CN: '部分加密聊天记录暂时无法显示，恢复密钥后即可查看，点此恢复'
	String get e2eeRecoveryBannerText => '部分加密聊天记录暂时无法显示，恢复密钥后即可查看，点此恢复';

	/// zh-CN: '此消息发送于本设备加入之前，无法在本设备显示'
	String get e2eeMsgBeforeDevice => '此消息发送于本设备加入之前，无法在本设备显示';

	/// zh-CN: '该消息加密时未包含本设备（如换设备前的历史消息），无法在此解密；不影响本设备收发的新消息'
	String get e2eeMsgBeforeDeviceTapHint => '该消息加密时未包含本设备（如换设备前的历史消息），无法在此解密；不影响本设备收发的新消息';

	/// zh-CN: '创建直播间'
	String get liveRoomCreateTitle => '创建直播间';

	/// zh-CN: '创建中...'
	String get liveRoomCreating => '创建中...';

	/// zh-CN: '观看直播'
	String get liveRoomWatch => '观看直播';

	/// zh-CN: '切换到语音输入'
	String get switchToVoiceInput => '切换到语音输入';

	/// zh-CN: '切换到键盘输入'
	String get switchToKeyboardInput => '切换到键盘输入';

	/// zh-CN: '附加项'
	String get extraItems => '附加项';

	/// zh-CN: '[不支持的消息]'
	String get invalidMessageType => '[不支持的消息]';

	/// zh-CN: '[加密消息]'
	String get encryptedMessagePlaceholder => '[加密消息]';

	/// zh-CN: '暂时无法访问加密存储，未能解密此消息；请重启应用后重试'
	String get e2eeDecryptStoreUnavailable => '暂时无法访问加密存储，未能解密此消息；请重启应用后重试';

	/// zh-CN: '[无效消息]'
	String get invalidMessagePlaceholder => '[无效消息]';

	/// zh-CN: '[视频通话]'
	String get videoCallPlaceholder => '[视频通话]';

	/// zh-CN: '[语音通话]'
	String get voiceCallPlaceholder => '[语音通话]';

	/// zh-CN: '非好友关系，无法发送消息'
	String get notFriendCannotSend => '非好友关系，无法发送消息';
}

// Path: common
class Translations$common$zh_CN {
	Translations$common$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '关于'
	String get about => '关于';

	/// zh-CN: '关于应用'
	String get aboutApp => '关于应用';

	/// zh-CN: '接受'
	String get accept => '接受';

	/// zh-CN: '通过好友验证'
	String get acceptFriendRequest => '通过好友验证';

	/// zh-CN: '接听'
	String get answer => '接听';

	/// zh-CN: '页面数据不存在或已失效'
	String get dataNotFound => '页面数据不存在或已失效';

	/// zh-CN: '拒绝'
	String get declineCall => '拒绝';

	/// zh-CN: '网络不佳，正在重连...'
	String get reconnecting => '网络不佳，正在重连...';

	/// zh-CN: '最小化'
	String get minimize => '最小化';

	/// zh-CN: '切换摄像头'
	String get switchCamera => '切换摄像头';

	/// zh-CN: '添加朋友'
	String get addFriend => '添加朋友';

	/// zh-CN: '零钱'
	String get smallChange => '零钱';

	/// zh-CN: '添加标签'
	String get addTag => '添加标签';

	/// zh-CN: '添加到通讯录'
	String get addToContacts => '添加到通讯录';

	/// zh-CN: '加入黑名单'
	String get addToDenylist => '加入黑名单';

	/// zh-CN: '已添加'
	String get added => '已添加';

	/// zh-CN: '已添加至黑名单，你将不再收到对方的消息'
	String get addedToDenylistTips => '已添加至黑名单，你将不再收到对方的消息';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '所有时间'
	String get allTime => '所有时间';

	/// zh-CN: '所有类型'
	String get allTypes => '所有类型';

	/// zh-CN: '允许搜索我'
	String get allowSearchMe => '允许搜索我';

	/// zh-CN: '最近新注册的并且允许被搜索到的朋友'
	String get allowedBeSearched => '最近新注册的并且允许被搜索到的朋友';

	/// zh-CN: '包含APP运行的必要文件，包括 APK 文件、优化的编译器输出和解压的原生库。'
	String get appSizeTips => '包含APP运行的必要文件，包括 APK 文件、优化的编译器输出和解压的原生库。';

	/// zh-CN: '申请添加朋友'
	String get applyAddFriend => '申请添加朋友';

	/// zh-CN: '等待验证'
	String get awaitingVerification => '等待验证';

	/// zh-CN: '完成'
	String get buttonAccomplish => '完成';

	/// zh-CN: '添加'
	String get buttonAdd => '添加';

	/// zh-CN: '返回'
	String get buttonBack => '返回';

	/// zh-CN: '绑定手机号和邮箱，让你的账户更安全'
	String get bindMobileAndEmailTips => '绑定手机号和邮箱，让你的账户更安全';

	/// zh-CN: '立即绑定'
	String get bindNow => '立即绑定';

	/// zh-CN: '取消'
	String get buttonCancel => '取消';

	/// zh-CN: '创建'
	String get buttonCreate => '创建';

	/// zh-CN: '请输入手机号'
	String get phoneInputHint => '请输入手机号';

	/// zh-CN: '更多'
	String get buttonMore => '更多';

	/// zh-CN: '刷新'
	String get buttonRefresh => '刷新';

	/// zh-CN: '关闭'
	String get buttonClose => '关闭';

	/// zh-CN: '确认'
	String get buttonConfirm => '确认';

	/// zh-CN: '继续'
	String get buttonContinue => '继续';

	/// zh-CN: '复制'
	String get buttonCopy => '复制';

	/// zh-CN: '删除'
	String get buttonDelete => '删除';

	/// zh-CN: '退出登录'
	String get buttonLogout => '退出登录';

	/// zh-CN: '确定'
	String get buttonOk => '确定';

	/// zh-CN: '重试'
	String get buttonRetry => '重试';

	/// zh-CN: '保存'
	String get buttonSave => '保存';

	/// zh-CN: '从相册选择'
	String get buttonSelectFromAlbum => '从相册选择';

	/// zh-CN: '发送'
	String get buttonSend => '发送';

	/// zh-CN: '拍照'
	String get buttonTakingPictures => '拍照';

	/// zh-CN: '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。'
	String get cacheTips => '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。';

	/// zh-CN: '通话时长'
	String get callDuration => '通话时长';

	/// zh-CN: '通话已结束'
	String get callEnded => '通话已结束';

	/// zh-CN: '正在通话'
	String get calling => '正在通话';

	/// zh-CN: '取消'
	String get cancel => _root.common.buttonCancel;

	/// zh-CN: '确定'
	String get ok => _root.common.buttonOk;

	/// zh-CN: '操作成功'
	String get operationSuccessful => '操作成功';

	/// zh-CN: '保存'
	String get save => _root.common.buttonSave;

	/// zh-CN: '重置'
	String get reset => '重置';

	/// zh-CN: '清空'
	String get clear => '清空';

	/// zh-CN: '保存标签 ($count)'
	String saveTag({required Object count}) => '保存标签 (${count})';

	/// zh-CN: '此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。'
	String get cancelLogoutBody => '此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。';

	/// zh-CN: '是否终止注销流程？'
	String get cancelLogoutTitle => '是否终止注销流程？';

	/// zh-CN: '已取消'
	String get cancelled => '已取消';

	/// zh-CN: '聊天背景'
	String get chatSettingBackground => '聊天背景';

	/// zh-CN: '置顶成功'
	String get chatSettingPinnedSuccess => '置顶成功';

	/// zh-CN: '取消置顶'
	String get chatSettingUnpinnedSuccess => '取消置顶';

	/// zh-CN: '聊天设置'
	String get chatSettings => '聊天设置';

	/// zh-CN: '发送失败'
	String get chatStatusFailed => '发送失败';

	/// zh-CN: '对方已将你加入黑名单'
	String get chatErrorInDenylist => '对方已将你加入黑名单';

	/// zh-CN: '检查更新'
	String get checkForUpdates => '检查更新';

	/// zh-CN: '清除全部'
	String get clearAll => '清除全部';

	/// zh-CN: '清空聊天记录'
	String get clearChatRecord => '清空聊天记录';

	/// zh-CN: '投诉已提交'
	String get complaintSuccess => '投诉已提交';

	/// zh-CN: '投诉失败，请稍后再试'
	String get complaintFailed => '投诉失败，请稍后再试';

	/// zh-CN: '确定删除聊天记录吗？'
	String get confirmDeleteChatRecord => '确定删除聊天记录吗？';

	/// zh-CN: '密码修改成功。'
	String get confirmRecoverSuccess => '密码修改成功。';

	/// zh-CN: '联系人设置'
	String get contactSetting => '联系人设置';

	/// zh-CN: '联系人标签'
	String get contactTags => '联系人标签';

	/// zh-CN: '联系人信息未同步'
	String get contactInfoNotSynced => '联系人信息未同步';

	/// zh-CN: '继续下载'
	String get continueDownloading => '继续下载';

	/// zh-CN: '复制'
	String get copy => '复制';

	/// zh-CN: '这些朋友也将进入群聊'
	String get createGroupF2fConfirmTips => '这些朋友也将进入群聊';

	/// zh-CN: '和身边的朋友输入同样的四个数字，进入同一个群聊'
	String get createGroupF2fTips => '和身边的朋友输入同样的四个数字，进入同一个群聊';

	/// zh-CN: '暗号'
	String get f2fSecretCode => '暗号';

	/// zh-CN: '$count 人即将进入群聊'
	String f2fEnteringGroup({required Object count}) => '${count} 人即将进入群聊';

	/// zh-CN: '删除'
	String get delete => _root.common.buttonDelete;

	/// zh-CN: '删除后无法恢复，确定要删除这条收藏吗？'
	String get deleteCollectConfirmDesc => '删除后无法恢复，确定要删除这条收藏吗？';

	/// zh-CN: '删除联系人'
	String get deleteContact => '删除联系人';

	/// zh-CN: '删除所有人的消息'
	String get deleteForEveryone => '删除所有人的消息';

	/// zh-CN: '删除我的消息'
	String get deleteForMe => '删除我的消息';

	/// zh-CN: '删除标签后，标签中的联系人不会被删除'
	String get deleteTagTips => '删除标签后，标签中的联系人不会被删除';

	/// zh-CN: '删除该设备'
	String get deleteThisDevice => '删除该设备';

	/// zh-CN: '删除后，下次在该设备登录时需要进行安全验证。'
	String get deleteThisDeviceTips => '删除后，下次在该设备登录时需要进行安全验证。';

	/// zh-CN: '被拉黑的用户无法给你发送消息，也无法查看你的动态。点击用户可以查看详情。'
	String get denylistNoteDesc => '被拉黑的用户无法给你发送消息，也无法查看你的动态。点击用户可以查看详情。';

	/// zh-CN: '黑名单说明'
	String get denylistNoteTitle => '黑名单说明';

	/// zh-CN: '详情'
	String get details => '详情';

	/// zh-CN: '设备详情'
	String get deviceDetails => '设备详情';

	/// zh-CN: '已下载'
	String get downloaded => '已下载';

	/// zh-CN: '编辑'
	String get edit => '编辑';

	/// zh-CN: '编辑标签'
	String get editTag => '编辑标签';

	/// zh-CN: '$param 是空的'
	String errorEmptyDirectory({required Object param}) => '${param} 是空的';

	/// zh-CN: '错误'
	String get errorFailedConnectServer => _root.common.error;

	/// zh-CN: '错误'
	String get errorHttpNotSupported => _root.common.error;

	/// zh-CN: '错误'
	String get errorInternalServer => _root.common.error;

	/// zh-CN: '$param 是无效的'
	String errorInvalid({required Object param}) => '${param} 是无效的';

	/// zh-CN: '错误'
	String get errorInvalidRequest => _root.common.error;

	/// zh-CN: '$param 长度必须在 $min 和 $max 之间'
	String errorLengthBetween({required Object param, required Object min, required Object max}) => '${param} 长度必须在 ${min} 和 ${max} 之间';

	/// zh-CN: '请求过于频繁'
	String get errorManyRequest => '请求过于频繁';

	/// zh-CN: '密码错误'
	String get errorPassword => '密码错误';

	/// zh-CN: '错误'
	String get errorRequestForbidden => _root.common.error;

	/// zh-CN: '错误'
	String get errorRequestSyntax => _root.common.error;

	/// zh-CN: '$param 是必须的'
	String errorRequired({required Object param}) => '${param} 是必须的';

	/// zh-CN: '错误'
	String get errorRetypePassword => _root.common.error;

	/// zh-CN: '错误'
	String get errorServerDown => _root.common.error;

	/// zh-CN: '错误'
	String get errorServerRefused => _root.common.error;

	/// zh-CN: '错误'
	String get errorUnexpected => _root.common.error;

	/// zh-CN: '网络错误'
	String get failedGetLatLong => _root.common.errorNetwork;

	/// zh-CN: '网络错误'
	String get failedGetMapTryAgain => _root.common.errorNetwork;

	/// zh-CN: '网络错误'
	String get failedRequestPleaseCheckNetwork => _root.common.errorNetwork;

	/// zh-CN: '反馈建议'
	String get feedback => '反馈建议';

	/// zh-CN: '反馈内容不能为空'
	String get feedbackContentRequired => '反馈内容不能为空';

	/// zh-CN: '反馈建议明细'
	String get feedbackDetails => '反馈建议明细';

	/// zh-CN: '你的反馈问题我们已经收到了，会尽快处理！'
	String get feedbackSuccessMsg => '你的反馈问题我们已经收到了，会尽快处理！';

	/// zh-CN: '开启后，将跟随系统打开或关闭深色模式'
	String get followSystemTips => '开启后，将跟随系统打开或关闭深色模式';

	/// zh-CN: '性别设置失败，请重试'
	String get genderUpdateFailed => '性别设置失败，请重试';

	/// zh-CN: '群公告'
	String get groupAnnouncement => '群公告';

	/// zh-CN: '文件上传成功'
	String get groupFileUploadSuccess => '文件上传成功';

	/// zh-CN: '文件上传失败，请稍后重试'
	String get groupFileUploadFailed => '文件上传失败，请稍后重试';

	/// zh-CN: '文件已删除'
	String get groupFileDeleteSuccess => '文件已删除';

	/// zh-CN: '删除失败，请稍后重试'
	String get groupFileDeleteFailed => '删除失败，请稍后重试';

	/// zh-CN: '上传文件'
	String get groupFileUploadTooltip => '上传文件';

	/// zh-CN: '搜索群文件'
	String get groupFileSearch => '搜索群文件';

	/// zh-CN: '文件读取失败，请重试'
	String get groupFileReadFailed => '文件读取失败，请重试';

	/// zh-CN: '删除群文件'
	String get groupFileDeleteTitle => '删除群文件';

	/// zh-CN: '确定删除文件「$name」吗？'
	String groupFileDeleteConfirm({required Object name}) => '确定删除文件「${name}」吗？';

	/// zh-CN: '图片加载失败'
	String get groupFileImageLoadFailed => '图片加载失败';

	/// zh-CN: '无法打开文件链接'
	String get groupFileOpenFailed => '无法打开文件链接';

	/// zh-CN: '全部'
	String get groupFileCategoryAll => '全部';

	/// zh-CN: '未找到匹配文件'
	String get groupFileSearchEmpty => '未找到匹配文件';

	/// zh-CN: '音频加载失败'
	String get groupFileAudioLoadFailed => '音频加载失败';

	/// zh-CN: '音频加载中...'
	String get groupFileAudioLoading => '音频加载中...';

	/// zh-CN: '该二维码$days天内（$date前）有效，重新进入将更新'
	String groupQrcodeTips({required Object days, required Object date}) => '该二维码${days}天内（${date}前）有效，重新进入将更新';

	/// zh-CN: '帮助文档'
	String get helpDocument => '帮助文档';

	/// zh-CN: '$param呼入'
	String incomingCall({required Object param}) => '${param}呼入';

	/// zh-CN: '立即安装'
	String get installNow => '立即安装';

	/// zh-CN: 'AppStore未上架或AppID[$param]不存在'
	String iosAppIdUnknown({required Object param}) => 'AppStore未上架或AppID[${param}]不存在';

	/// zh-CN: '韩语（韩国）'
	String get koKr => '韩语（韩国）';

	/// zh-CN: '语言设置'
	String get languageSetting => '语言设置';

	/// zh-CN: '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。'
	String get lastActiveTips => '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。';

	/// zh-CN: '刚刚上线'
	String get lastSeenJustNow => '刚刚上线';

	/// zh-CN: '很久以前上线'
	String get lastSeenLongTimeAgo => '很久以前上线';

	/// zh-CN: '$param个月前'
	String lastSeenMonthsAgo({required Object param}) => '${param}个月前';

	/// zh-CN: '加载失败，请重试'
	String get loadError => '加载失败，请重试';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '加载中'
	String get loading => '加载中';

	/// zh-CN: '位置消息'
	String get locationMessage => '位置消息';

	/// zh-CN: '你的账号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。'
	String get loginDeviceManagementTips => '你的账号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。';

	/// zh-CN: '退出登录失败'
	String get logoutFailed => '退出登录失败';

	/// zh-CN: '发消息'
	String get messageCall => '发消息';

	/// zh-CN: '消息内容'
	String get messageContent => '消息内容';

	/// zh-CN: '消息已撤回'
	String get messageRevoked => '消息已撤回';

	/// zh-CN: '引用的消息不可用'
	String get quoteMessageNotAvailable => '引用的消息不可用';

	/// zh-CN: '无法获取这条引用消息，可能已过期或不在当前可访问的历史中，请重试或向发送者确认'
	String get quoteMessageUnavailable => '无法获取这条引用消息，可能已过期或不在当前可访问的历史中，请重试或向发送者确认';

	/// zh-CN: '暂时无法确认这条历史消息的访问权限，请稍后重试或联系会话管理员'
	String get quoteMessageAuthorizationUnavailable => '暂时无法确认这条历史消息的访问权限，请稍后重试或联系会话管理员';

	/// zh-CN: '引用的消息已过期，无法恢复；请向发送者确认内容'
	String get quoteMessageExpired => '引用的消息已过期，无法恢复；请向发送者确认内容';

	/// zh-CN: '你没有权限查看这条引用消息，请联系会话管理员确认权限'
	String get quoteMessageForbidden => '你没有权限查看这条引用消息，请联系会话管理员确认权限';

	/// zh-CN: '引用消息加载失败，请检查网络后重新点击重试'
	String get quoteMessageLoadFailed => '引用消息加载失败，请检查网络后重新点击重试';

	/// zh-CN: '本设备无法解密这条引用消息，请重试或请发送者重新发送'
	String get quoteMessageUndecryptable => '本设备无法解密这条引用消息，请重试或请发送者重新发送';

	/// zh-CN: '麦克风'
	String get microphone => '麦克风';

	/// zh-CN: '未获取到麦克风权限'
	String get microphonePermissionNotObtained => '未获取到麦克风权限';

	/// zh-CN: '更多信息'
	String get moreInfo => '更多信息';

	/// zh-CN: '与附近的人交换联系方式，结交新朋友'
	String get nearbyPeopleTips => '与附近的人交换联系方式，结交新朋友';

	/// zh-CN: '需要继续加油'
	String get needContinueWorkHard => '需要继续加油';

	/// zh-CN: '$param失败，请检查网络连接'
	String networkErrorWithAction({required Object param}) => '${param}失败，请检查网络连接';

	/// zh-CN: '网络连接异常'
	String get networkException => '网络连接异常';

	/// zh-CN: '网络错误'
	String get errorNetwork => '网络错误';

	/// zh-CN: '网络状态异常，需要打开网络才能够查看数据'
	String get networkExceptionPlaseNeedNetworkToViewData => '网络状态异常，需要打开网络才能够查看数据';

	/// zh-CN: '检测到新版本'
	String get newVersionDetected => '检测到新版本';

	/// zh-CN: '检测到新版本 $param'
	String newVersionDetectedWithVersion({required Object param}) => '检测到新版本 ${param}';

	/// zh-CN: '下一步'
	String get nextStep => '下一步';

	/// zh-CN: '昵称不能仅包含表情符号'
	String get nicknameEmojiOnlyError => '昵称不能仅包含表情符号';

	/// zh-CN: '昵称不能为空'
	String get nicknameEmptyError => '昵称不能为空';

	/// zh-CN: '昵称长度应在2-24个字符之间'
	String get nicknameLengthError => '昵称长度应在2-24个字符之间';

	/// zh-CN: '昵称包含敏感词，请重新输入'
	String get nicknameSensitiveWordError => '昵称包含敏感词，请重新输入';

	/// zh-CN: '昵称修改失败，请重试'
	String get nicknameUpdateFailed => '昵称修改失败，请重试';

	/// zh-CN: '昵称不能仅包含空白字符'
	String get nicknameWhitespaceError => '昵称不能仅包含空白字符';

	/// zh-CN: '无头像'
	String get noAvatar => '无头像';

	/// zh-CN: '未识别到二维码'
	String get noBarcodeFound => '未识别到二维码';

	/// zh-CN: '无联系人'
	String get noContacts => '无联系人';

	/// zh-CN: '无会话消息'
	String get noConversationMessages => '无会话消息';

	/// zh-CN: '暂无数据'
	String get noData => '暂无数据';

	/// zh-CN: '当前标签无成员'
	String get noMembersInCurrentTag => '当前标签无成员';

	/// zh-CN: '没有新的好友'
	String get noNewFriends => '没有新的好友';

	/// zh-CN: '没有权限'
	String get noPermission => '没有权限';

	/// zh-CN: '暂无回复'
	String get noReply => '暂无回复';

	/// zh-CN: '无更新说明'
	String get noUpdateDescription => '无更新说明';

	/// zh-CN: '你还没有授权获取经纬度'
	String get notAuthorizedLatLong => '你还没有授权获取经纬度';

	/// zh-CN: '未登录'
	String get notLoggedIn => '未登录';

	/// zh-CN: '还不错'
	String get notBad => '还不错';

	/// zh-CN: '未绑定'
	String get notBound => '未绑定';

	/// zh-CN: '未填写'
	String get notFilled => '未填写';

	/// zh-CN: '你没有安装任何地图APP哦'
	String get notInstallAnyMapApp => '你没有安装任何地图APP哦';

	/// zh-CN: '没有收到验证码？'
	String get notReceiveCoeQ => '没有收到验证码？';

	/// zh-CN: '未设置'
	String get notSet => '未设置';

	/// zh-CN: '你还没有打开位置信息服务'
	String get notTurnedLocationService => '你还没有打开位置信息服务';

	/// zh-CN: '未检测到新版本'
	String get nowNewVersion => '未检测到新版本';

	/// zh-CN: '下线通知'
	String get offlineNotification => '下线通知';

	/// zh-CN: '操作失败，请稍后重试'
	String get operationFailedAgainLater => '操作失败，请稍后重试';

	/// zh-CN: '暂停下载'
	String get pauseDownloading => '暂停下载';

	/// zh-CN: '对方无应答...'
	String get peerNoResponse => '对方无应答...';

	/// zh-CN: '权限获取失败'
	String get permissionAcquisitionFailed => '权限获取失败';

	/// zh-CN: '个人名片'
	String get personalCard => '个人名片';

	/// zh-CN: '个人信息'
	String get personalInformation => '个人信息';

	/// zh-CN: '请把方格填满'
	String get pinCodeFillTips => '请把方格填满';

	/// zh-CN: '资料设置'
	String get profileSettings => '资料设置';

	/// zh-CN: '重新编辑'
	String get reEdit => '重新编辑';

	/// zh-CN: '按地区名称搜索'
	String get regionSearchHint => '按地区名称搜索';

	/// zh-CN: '已选 $region（第 $level 级）：可直接点右上角完成，也可继续选择下一级'
	String regionSelectedLevelHint({required Object region, required Object level}) => '已选 ${region}（第 ${level} 级）：可直接点右上角完成，也可继续选择下一级';

	/// zh-CN: '松开手指，取消发送'
	String get releaseFingerCancelSending => '松开手指，取消发送';

	/// zh-CN: '从标签中移除联系人'
	String get removeContactFromTag => '从标签中移除联系人';

	/// zh-CN: '移出成员'
	String get removeMember => '移出成员';

	/// zh-CN: '[@你]'
	String get atMentionYouTag => '[@你]';

	/// zh-CN: '@已退群成员'
	String get atMentionLeftMember => '@已退群成员';

	/// zh-CN: '消息免打扰'
	String get muteNotifications => '消息免打扰';

	/// zh-CN: '开启后不会收到新消息提醒，但仍可在会话列表看到未读'
	String get muteNotificationsHint => '开启后不会收到新消息提醒，但仍可在会话列表看到未读';

	/// zh-CN: '超过 2 分钟，无法撤回'
	String get revokeExpired => '超过 2 分钟，无法撤回';

	/// zh-CN: '新增快捷回复'
	String get quickReplyAddTitle => '新增快捷回复';

	/// zh-CN: '编辑快捷回复'
	String get quickReplyEditTitle => '编辑快捷回复';

	/// zh-CN: '取消管理员'
	String get removeAdmin => '取消管理员';

	/// zh-CN: '确定将此成员设为管理员吗？'
	String get setAdminConfirm => '确定将此成员设为管理员吗？';

	/// zh-CN: '确定取消此成员的管理员身份吗？'
	String get removeAdminConfirm => '确定取消此成员的管理员身份吗？';

	/// zh-CN: '确定取消禁言此成员吗？'
	String get unmuteMemberConfirm => '确定取消禁言此成员吗？';

	/// zh-CN: '确定将此成员移出群聊吗？'
	String get kickMemberConfirm => '确定将此成员移出群聊吗？';

	/// zh-CN: '已设为管理员'
	String get setAdminSuccess => '已设为管理员';

	/// zh-CN: '设置管理员失败'
	String get setAdminFailed => '设置管理员失败';

	/// zh-CN: '已取消管理员'
	String get removeAdminSuccess => '已取消管理员';

	/// zh-CN: '取消管理员失败'
	String get removeAdminFailed => '取消管理员失败';

	/// zh-CN: '已禁言'
	String get muteMemberSuccess => '已禁言';

	/// zh-CN: '禁言失败'
	String get muteMemberFailed => '禁言失败';

	/// zh-CN: '已取消禁言'
	String get unmuteMemberSuccess => '已取消禁言';

	/// zh-CN: '取消禁言失败'
	String get unmuteMemberFailed => '取消禁言失败';

	/// zh-CN: '已移出群聊'
	String get kickMemberSuccess => '已移出群聊';

	/// zh-CN: '移出群聊失败'
	String get kickMemberFailed => '移出群聊失败';

	/// zh-CN: '未禁言'
	String get notMuted => '未禁言';

	/// zh-CN: '禁言时长'
	String get muteDuration => '禁言时长';

	/// zh-CN: '1小时'
	String get muteDuration1hour => '1小时';

	/// zh-CN: '1天'
	String get muteDuration1day => '1天';

	/// zh-CN: '7天'
	String get muteDuration7days => '7天';

	/// zh-CN: '5分钟'
	String get muteDuration5min => '5分钟';

	/// zh-CN: '10分钟'
	String get muteDuration10min => '10分钟';

	/// zh-CN: '30分钟'
	String get muteDuration30min => '30分钟';

	/// zh-CN: '30天'
	String get muteDuration30days => '30天';

	/// zh-CN: '$count 秒'
	String muteUnitSeconds({required Object count}) => '${count} 秒';

	/// zh-CN: '操作频率过高，请稍后再试'
	String get throttleWarning => '操作频率过高，请稍后再试';

	/// zh-CN: '操作频率过高，请 $seconds 秒后再试'
	String throttleRetryAfter({required Object seconds}) => '操作频率过高，请 ${seconds} 秒后再试';

	/// zh-CN: '禁言期间无法发送消息'
	String get mutedCannotSend => '禁言期间无法发送消息';

	/// zh-CN: '重置筛选'
	String get resetFilters => '重置筛选';

	/// zh-CN: '保存二维码'
	String get saveQrCode => '保存二维码';

	/// zh-CN: '保存成功'
	String get saveSuccess => '保存成功';

	/// zh-CN: '扫一扫上面的二维码图案，加我为朋友'
	String get scanQrcodeAddFriend => '扫一扫上面的二维码图案，加我为朋友';

	/// zh-CN: '搜索'
	String get search => '搜索';

	/// zh-CN: '搜索范围'
	String get searchScope => '搜索范围';

	/// zh-CN: '全部消息'
	String get searchAll => '全部消息';

	/// zh-CN: '查找聊天内容'
	String get searchChatContent => '查找聊天内容';

	/// zh-CN: '查找聊天记录'
	String get searchChatRecord => '查找聊天记录';

	/// zh-CN: '搜索错误'
	String get searchError => '搜索错误';

	/// zh-CN: '输入关键词搜索消息'
	String get searchHint => '输入关键词搜索消息';

	/// zh-CN: '搜索历史'
	String get searchHistory => '搜索历史';

	/// zh-CN: '搜索地点'
	String get searchLocation => '搜索地点';

	/// zh-CN: '搜索聊天内容'
	String get searchMessagesHint => '搜索聊天内容';

	/// zh-CN: '搜索结果为空 :('
	String get searchNoFound => '搜索结果为空 :(';

	/// zh-CN: '无搜索结果'
	String get searchNoResults => '无搜索结果';

	/// zh-CN: '暂无搜索历史'
	String get noSearchHistory => '暂无搜索历史';

	/// zh-CN: '搜索结果'
	String get searchResults => '搜索结果';

	/// zh-CN: '全选'
	String get selectAll => '全选';

	/// zh-CN: '选择联系人'
	String get selectContacts => '选择联系人';

	/// zh-CN: '已选地区'
	String get selectedRegion => '已选地区';

	/// zh-CN: '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。'
	String get sendMsgNotFriendTips => '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '手指上滑，取消发送'
	String get slideUpCancelSending => '手指上滑，取消发送';

	/// zh-CN: '未获取存储权限'
	String get storagePermissionNotObtained => '未获取存储权限';

	/// zh-CN: '提交于'
	String get submittedAt => '提交于';

	/// zh-CN: '确认删除吗？删除后不可恢复。'
	String get sureDeleteData => '确认删除吗？删除后不可恢复。';

	/// zh-CN: '确定删除群的聊天记录吗？'
	String get sureDeleteGroupChatRecord => '确定删除群的聊天记录吗？';

	/// zh-CN: '切换环境'
	String get switchEnvironment => '切换环境';

	/// zh-CN: '(other) {$n天前}'
	String timeDaysAgo({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(n,
		other: '${n}天前',
	);

	/// zh-CN: '(other) {$n小时前}'
	String timeHoursAgo({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(n,
		other: '${n}小时前',
	);

	/// zh-CN: '刚刚'
	String get timeJustNow => '刚刚';

	/// zh-CN: '(other) {$n分钟前}'
	String timeMinutesAgo({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(n,
		other: '${n}分钟前',
	);

	/// zh-CN: '无网络'
	String get tipConnectDesc => '无网络';

	/// zh-CN: '($param)'
	String tipConnectDescWithParen({required Object param}) => '(${param})';

	/// zh-CN: '将联系人"$param"删除，同时删除与该联系人的聊天记录'
	String tipDeleteContact({required Object param}) => '将联系人"${param}"删除，同时删除与该联系人的聊天记录';

	/// zh-CN: '占设备 $param1% 存储空间($param2)'
	String tipDeviceSpace({required Object param1, required Object param2}) => '占设备 ${param1}% 存储空间(${param2})';

	/// zh-CN: '草稿'
	String get tipDraft => '草稿';

	/// zh-CN: '操作失败！'
	String get tipFailed => '操作失败！';

	/// zh-CN: '操作成功！'
	String get tipSuccess => '操作成功！';

	/// zh-CN: '小贴士'
	String get tipTips => '小贴士';

	/// zh-CN: '联系人'
	String get titleContact => '联系人';

	/// zh-CN: '今天'
	String get today => '今天';

	/// zh-CN: '未知'
	String get unknown => '未知';

	/// zh-CN: '未知消息'
	String get unknownMessage => '未知消息';

	/// zh-CN: '更新日志'
	String get updateLog => '更新日志';

	/// zh-CN: '立即更新'
	String get updateNow => '立即更新';

	/// zh-CN: '上传中'
	String get uploading => '上传中';

	/// zh-CN: '上传成功'
	String get uploadSuccess => '上传成功';

	/// zh-CN: '上传失败'
	String get uploadFailed => '上传失败';

	/// zh-CN: '包含APP运行时必要的文件，以及聊天消息、好友关系等所有记录数据。'
	String get userDataTips => '包含APP运行时必要的文件，以及聊天消息、好友关系等所有记录数据。';

	/// zh-CN: '用户被禁用或已删除'
	String get userDisabledOrDeleted => '用户被禁用或已删除';

	/// zh-CN: '用户不存在'
	String get userNotExist => '用户不存在';

	/// zh-CN: '版本'
	String get version => '版本';

	/// zh-CN: '视频通话'
	String get videoCall => '视频通话';

	/// zh-CN: '查看全部群成员'
	String get viewAllGroupMember => '查看全部群成员';

	/// zh-CN: '语音通话'
	String get voiceCall => '语音通话';

	/// zh-CN: '群通话'
	String get groupCall => '群通话';

	/// zh-CN: '通话已断开'
	String get callDisconnected => '通话已断开';

	/// zh-CN: '连接中...'
	String get connecting => '连接中...';

	/// zh-CN: '语音输入功能暂无实现'
	String get voiceInputNotImplemented => '语音输入功能暂无实现';

	/// zh-CN: '等待下载'
	String get waitingDownload => '等待下载';

	/// zh-CN: '等待对方接受邀请...'
	String get waitingPeerAccept => '等待对方接受邀请...';

	/// zh-CN: '警告:'
	String get warning => '警告:';

	/// zh-CN: '网页加载中...'
	String get webpageLoading => '网页加载中...';

	/// zh-CN: '昨天'
	String get yesterday => '昨天';

	/// zh-CN: '确认将此用户移出黑名单？'
	String get confirmRemoveFromDenylist => '确认将此用户移出黑名单？';

	/// zh-CN: '移出'
	String get buttonRemove => '移出';

	/// zh-CN: '已移出黑名单'
	String get removedFromDenylist => '已移出黑名单';

	/// zh-CN: '新邮箱地址'
	String get newEmailAddress => '新邮箱地址';

	/// zh-CN: '邮箱地址'
	String get emailAddress => '邮箱地址';

	/// zh-CN: '请输入邮箱地址'
	String get enterEmailAddress => '请输入邮箱地址';

	/// zh-CN: '获取验证码'
	String get getVerificationCode => '获取验证码';

	/// zh-CN: '确认更换'
	String get confirmChange => '确认更换';

	/// zh-CN: '验证码将发送至该邮箱，请在有效期内完成验证'
	String get verificationCodeSentToEmail => '验证码将发送至该邮箱，请在有效期内完成验证';

	/// zh-CN: '验证码将发送至该手机，请在有效期内完成验证'
	String get verificationCodeSentToMobile => '验证码将发送至该手机，请在有效期内完成验证';

	/// zh-CN: '发送失败'
	String get sendFailed => '发送失败';

	/// zh-CN: '下线'
	String get forceOffline => '下线';

	/// zh-CN: '让该设备下线'
	String get forceDeviceOffline => '让该设备下线';

	/// zh-CN: '将向该设备发送下线指令，确认继续？'
	String get forceDeviceOfflineConfirm => '将向该设备发送下线指令，确认继续？';

	/// zh-CN: '确认下线'
	String get confirmForceOffline => '确认下线';

	/// zh-CN: '已发送下线指令'
	String get forceOfflineCommandSent => '已发送下线指令';

	/// zh-CN: '你的建议是我们改进的动力'
	String get feedbackSlogan => '你的建议是我们改进的动力';

	/// zh-CN: '新建反馈'
	String get newFeedback => '新建反馈';

	/// zh-CN: '反馈历史'
	String get feedbackHistory => '反馈历史';

	/// zh-CN: '确认删除'
	String get confirmDelete => '确认删除';

	/// zh-CN: '验证码'
	String get verificationCode => '验证码';

	/// zh-CN: '反馈内容'
	String get feedbackContent => '反馈内容';

	/// zh-CN: '官方回复'
	String get officialReply => '官方回复';

	/// zh-CN: '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。'
	String get setPasswordSecurityTips => '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。';

	/// zh-CN: '已隐藏你的位置'
	String get locationHidden => '已隐藏你的位置';

	/// zh-CN: '已显示你的位置'
	String get locationVisible => '已显示你的位置';

	/// zh-CN: '暂无附近的人'
	String get noNearbyPeople => '暂无附近的人';

	/// zh-CN: '点击上方的搜索按钮查找附近的人'
	String get clickSearchButtonToFind => '点击上方的搜索按钮查找附近的人';

	/// zh-CN: '错误'
	String get operationFailed => _root.common.error;

	/// zh-CN: '功能开发中...'
	String get featureInDevelopment => '功能开发中...';

	/// zh-CN: '已加入黑名单'
	String get addedToDenylist => '已加入黑名单';

	/// zh-CN: '发布公告'
	String get groupAnnouncementPublish => '发布公告';

	/// zh-CN: '请输入公告内容'
	String get pleaseEnterAnnouncementContent => '请输入公告内容';

	/// zh-CN: '选择有效期（可选）'
	String get selectExpirationDateOptional => '选择有效期（可选）';

	/// zh-CN: '确定要删除这条公告吗？'
	String get groupAnnouncementDeleteConfirm => '确定要删除这条公告吗？';

	/// zh-CN: '删除'
	String get groupAnnouncementDelete => '删除';

	/// zh-CN: '公告加载失败，请稍后重试'
	String get groupAnnouncementLoadFailed => '公告加载失败，请稍后重试';

	/// zh-CN: '公告发布失败'
	String get groupAnnouncementPublishFailed => '公告发布失败';

	/// zh-CN: '公告已发布'
	String get groupAnnouncementPublishSuccess => '公告已发布';

	/// zh-CN: '公告删除失败'
	String get groupAnnouncementDeleteFailed => '公告删除失败';

	/// zh-CN: '公告已删除'
	String get groupAnnouncementDeleteSuccess => '公告已删除';

	/// zh-CN: '清除聊天记录'
	String get privacyClearChatHistory => '清除聊天记录';

	/// zh-CN: '确定要清除所有聊天记录吗？此操作不可恢复。'
	String get privacyClearChatHistoryConfirm => '确定要清除所有聊天记录吗？此操作不可恢复。';

	/// zh-CN: '确定要注销账号吗？此操作将永久删除你的账号和所有数据，且不可恢复。'
	String get privacyLogoutAccountConfirm => '确定要注销账号吗？此操作将永久删除你的账号和所有数据，且不可恢复。';

	/// zh-CN: '隐私设置'
	String get privacySettings => '隐私设置';

	/// zh-CN: '搜索设置'
	String get searchSettings => '搜索设置';

	/// zh-CN: '允许通过账号搜索'
	String get allowSearchByAccount => '允许通过账号搜索';

	/// zh-CN: '其他用户可以通过你的账号找到你'
	String get allowSearchByAccountDesc => '其他用户可以通过你的账号找到你';

	/// zh-CN: '允许通过手机号添加'
	String get allowAddByPhone => '允许通过手机号添加';

	/// zh-CN: '其他用户可以通过你的手机号添加你为好友'
	String get allowAddByPhoneDesc => '其他用户可以通过你的手机号添加你为好友';

	/// zh-CN: '允许通过二维码添加'
	String get allowAddByQR => '允许通过二维码添加';

	/// zh-CN: '其他用户可以通过扫描你的二维码添加你为好友'
	String get allowAddByQRDesc => '其他用户可以通过扫描你的二维码添加你为好友';

	/// zh-CN: '状态设置'
	String get statusSettings => '状态设置';

	/// zh-CN: '显示在线状态'
	String get showOnlineStatus => '显示在线状态';

	/// zh-CN: '关闭后，好友看不到你的在线状态和最后上线时间；消息投递不受影响'
	String get showOnlineStatusDesc => '关闭后，好友看不到你的在线状态和最后上线时间；消息投递不受影响';

	/// zh-CN: '附近的人可见'
	String get allowNearbyVisible => '附近的人可见';

	/// zh-CN: '数据设置'
	String get dataSettings => '数据设置';

	/// zh-CN: '清除聊天记录'
	String get clearChatRecords => '清除聊天记录';

	/// zh-CN: '清除所有聊天记录，此操作不可恢复'
	String get clearChatRecordsDesc => '清除所有聊天记录，此操作不可恢复';

	/// zh-CN: '注销账号'
	String get deleteAccountAction => '注销账号';

	/// zh-CN: '永久删除账号和所有数据，此操作不可恢复'
	String get deleteAccountActionDesc => '永久删除账号和所有数据，此操作不可恢复';

	/// zh-CN: '聊天记录已清除'
	String get chatHistoryCleared => '聊天记录已清除';

	/// zh-CN: '删除消息'
	String get chatDeleteMessage => '删除消息';

	/// zh-CN: '复制'
	String get chatCopy => '复制';

	/// zh-CN: '保存图片'
	String get chatSaveImage => '保存图片';

	/// zh-CN: '仅删除本地'
	String get chatDeleteLocalOnly => '仅删除本地';

	/// zh-CN: '删除失败'
	String get chatDeleteFailed => '删除失败';

	/// zh-CN: '网络连接失败，是否仅删除本地消息？'
	String get chatNetworkErrorDeleteLocal => '网络连接失败，是否仅删除本地消息？';

	/// zh-CN: '确定要删除这条消息吗？此操作无法撤销。'
	String get chatDeleteConfirm => '确定要删除这条消息吗？此操作无法撤销。';

	/// zh-CN: '仅在你这里删除，对方仍可见'
	String get chatDeleteOnlyLocal => '仅在你这里删除，对方仍可见';

	/// zh-CN: '从所有人的聊天中删除，无法撤销'
	String get chatDeleteAll => '从所有人的聊天中删除，无法撤销';

	/// zh-CN: '聊天初始化失败'
	String get chatInitFailed => '聊天初始化失败';

	/// zh-CN: '拍摄失败'
	String get cameraShootFailed => '拍摄失败';

	/// zh-CN: '拍摄'
	String get cameraCapture => '拍摄';

	/// zh-CN: '照片'
	String get cameraModePhoto => '照片';

	/// zh-CN: '视频'
	String get cameraModeVideo => '视频';

	/// zh-CN: '重拍'
	String get cameraRetake => '重拍';

	/// zh-CN: '使用'
	String get cameraUse => '使用';

	/// zh-CN: '未检测到可用的摄像头'
	String get cameraNoDevice => '未检测到可用的摄像头';

	/// zh-CN: '编辑头像'
	String get avatarEditAvatar => '编辑头像';

	/// zh-CN: '使用自定义颜色'
	String get backgroundUseCustomColor => '使用自定义颜色';

	/// zh-CN: '仅适用于纯色背景'
	String get backgroundOnlySolidColor => '仅适用于纯色背景';

	/// zh-CN: '选择颜色'
	String get backgroundSelectColor => '选择颜色';

	/// zh-CN: '分享资料'
	String get profileShareProfile => '分享资料';

	/// zh-CN: '确定要清空所有标签吗？'
	String get tagClearAllConfirm => '确定要清空所有标签吗？';

	/// zh-CN: '确认清空'
	String get tagClearAll => '确认清空';

	/// zh-CN: '播放失败'
	String get audioPlayFailed => '播放失败';

	/// zh-CN: '你已被设备【$device】强制下线'
	String forcedOfflineByDevice({required Object device}) => '你已被设备【${device}】强制下线';

	/// zh-CN: '加载标签数据失败'
	String get loadingTagDataFailed => '加载标签数据失败';

	/// zh-CN: '请输入内容'
	String get pleaseEnterContent => '请输入内容';

	/// zh-CN: '敬请期待'
	String get comingSoon => '敬请期待';

	/// zh-CN: '背景透明度'
	String get backgroundTransparency => '背景透明度';

	/// zh-CN: '默认背景'
	String get defaultBackground => '默认背景';

	/// zh-CN: '纯色背景'
	String get solidColorBackground => '纯色背景';

	/// zh-CN: '选择图片失败'
	String get selectImageFailed => '选择图片失败';

	/// zh-CN: '位置选择功能暂未实现'
	String get locationSelectNotImplemented => '位置选择功能暂未实现';

	/// zh-CN: '选择位置失败'
	String get selectLocationFailed => '选择位置失败';

	/// zh-CN: '名片发送功能暂未实现'
	String get sendCardNotImplemented => '名片发送功能暂未实现';

	/// zh-CN: '语音发送失败'
	String get voiceSendFailed => '语音发送失败';

	/// zh-CN: '功能暂未实现'
	String get featureNotImplemented => '功能暂未实现';

	/// zh-CN: '收藏发送功能暂未实现'
	String get sendCollectionNotImplemented => '收藏发送功能暂未实现';

	/// zh-CN: '文件打开功能暂未实现'
	String get fileOpenNotImplemented => '文件打开功能暂未实现';

	/// zh-CN: '文件分享功能暂未实现'
	String get fileShareNotImplemented => '文件分享功能暂未实现';

	/// zh-CN: '重试成功'
	String get retrySuccess => '重试成功';

	/// zh-CN: '删除成功'
	String get deleteSuccess => '删除成功';

	/// zh-CN: '本地删除成功'
	String get localDeleteSuccess => '本地删除成功';

	/// zh-CN: '本地删除失败'
	String get localDeleteFailed => '本地删除失败';

	/// zh-CN: '撤回成功'
	String get revokeSuccess => '撤回成功';

	/// zh-CN: '编辑内容不能为空'
	String get editContentCannotBeEmpty => '编辑内容不能为空';

	/// zh-CN: '编辑成功'
	String get editSuccess => '编辑成功';

	/// zh-CN: '已开启'
	String get enabled => '已开启';

	/// zh-CN: '已关闭'
	String get disabled => '已关闭';

	/// zh-CN: '字体大小设置已更新'
	String get fontSizeSettingUpdated => '字体大小设置已更新';

	/// zh-CN: '字体大小设置'
	String get fontSizeSetting => '字体大小设置';

	/// zh-CN: '字体偏小，可能影响阅读'
	String get fontTooSmallMayAffect => '字体偏小，可能影响阅读';

	/// zh-CN: '拖动滑块调整字体大小'
	String get dragSliderAdjustFontSize => '拖动滑块调整字体大小';

	/// zh-CN: '个人信息'
	String get personalInfo => '个人信息';

	/// zh-CN: '未设置昵称'
	String get nicknameNotSet => '未设置昵称';

	/// zh-CN: '基本信息'
	String get basicInfo => '基本信息';

	/// zh-CN: '联系信息'
	String get contactInfo => '联系信息';

	/// zh-CN: '编辑标签'
	String get editTags => '编辑标签';

	/// zh-CN: '快捷操作'
	String get quickActions => '快捷操作';

	/// zh-CN: '暂时没有新的好友申请'
	String get noNewFriendRequests => '暂时没有新的好友申请';

	/// zh-CN: '请输入验证消息'
	String get pleaseEnterVerificationMessage => '请输入验证消息';

	/// zh-CN: '未知地区'
	String get unknownRegion => '未知地区';

	/// zh-CN: '暂无共同群组'
	String get noCommonGroups => '暂无共同群组';

	/// zh-CN: '暂无更多信息'
	String get noMoreInfo => '暂无更多信息';

	/// zh-CN: '验证消息'
	String get verificationMessage => '验证消息';

	/// zh-CN: '开启后：消息在被阅读后 $duration 自动销毁'
	String burnEnabledMessage({required Object duration}) => '开启后：消息在被阅读后 ${duration} 自动销毁';

	/// zh-CN: '关闭后：消息不会自动销毁'
	String get burnDisabledMessage => '关闭后：消息不会自动销毁';

	/// zh-CN: '暂无群公告'
	String get noGroupAnnouncement => '暂无群公告';

	/// zh-CN: '功能暂未实现'
	String get featureComingSoon => '功能暂未实现';

	/// zh-CN: '明白了'
	String get understood => '明白了';

	/// zh-CN: '没问题'
	String get noProblem => '没问题';

	/// zh-CN: '马上到'
	String get onMyWay => '马上到';

	/// zh-CN: '操作选项'
	String get operationOptions => '操作选项';

	/// zh-CN: '复制文本内容'
	String get copyTextContent => '复制文本内容';

	/// zh-CN: '分享给其他好友'
	String get shareWithOtherFriends => '分享给其他好友';

	/// zh-CN: '为收藏添加标签'
	String get addTagsToFavorites => '为收藏添加标签';

	/// zh-CN: '为收藏添加备注'
	String get addRemarkToFavorites => '为收藏添加备注';

	/// zh-CN: '删除此收藏'
	String get deleteThisCollection => '删除此收藏';

	/// zh-CN: '修改成功'
	String get changeSuccess => '修改成功';

	/// zh-CN: '长度符合'
	String get lengthOk => '长度符合';

	/// zh-CN: '确认新密码'
	String get confirmNewPassword => '确认新密码';

	/// zh-CN: '验证通过'
	String get validationPassed => '验证通过';

	/// zh-CN: '写点什么...'
	String get momentsContentHint => '写点什么...';

	/// zh-CN: '添加媒体'
	String get momentsAddMedia => '添加媒体';

	/// zh-CN: '允许可见 UID 列表（逗号分隔）'
	String get momentsAllowUidsLabel => '允许可见 UID 列表（逗号分隔）';

	/// zh-CN: '暂无动态'
	String get momentsNoData => '暂无动态';

	/// zh-CN: '确定删除这条动态吗？'
	String get momentsDeleteConfirm => '确定删除这条动态吗？';

	/// zh-CN: '确定删除这条评论吗？'
	String get momentsDeleteCommentConfirm => '确定删除这条评论吗？';

	/// zh-CN: '动态不存在或无权限查看'
	String get momentsNotFound => '动态不存在或无权限查看';

	/// zh-CN: '内容或媒体至少填写一项'
	String get momentsContentOrMediaRequired => '内容或媒体至少填写一项';

	/// zh-CN: '发布失败'
	String get momentsPublishFailed => '发布失败';

	/// zh-CN: '允许评论'
	String get momentsAllowComment => '允许评论';

	/// zh-CN: '暂无评论'
	String get momentsNoComments => '暂无评论';

	/// zh-CN: '评论失败，请稍后重试'
	String get momentsCommentFailed => '评论失败，请稍后重试';

	/// zh-CN: '删除失败，请稍后重试'
	String get momentsDeleteFailed => '删除失败，请稍后重试';

	/// zh-CN: '举报已提交'
	String get momentsReportSubmitted => '举报已提交';

	/// zh-CN: '举报失败，请稍后重试'
	String get momentsReportFailed => '举报失败，请稍后重试';

	/// zh-CN: '垃圾广告'
	String get momentReportReasonSpam => '垃圾广告';

	/// zh-CN: '骚扰霸凌'
	String get momentReportReasonHarassment => '骚扰霸凌';

	/// zh-CN: '色情低俗'
	String get momentReportReasonPorn => '色情低俗';

	/// zh-CN: '欺诈诈骗'
	String get momentReportReasonFraud => '欺诈诈骗';

	/// zh-CN: '侵权抄袭'
	String get momentReportReasonInfringement => '侵权抄袭';

	/// zh-CN: '其他'
	String get momentReportReasonOther => '其他';

	/// zh-CN: '请选择举报原因'
	String get momentReportReasonPrompt => '请选择举报原因';

	/// zh-CN: '加载更多评论'
	String get momentsLoadMoreComments => '加载更多评论';

	/// zh-CN: '媒体上传失败，请稍后重试'
	String get momentsUploadFailed => '媒体上传失败，请稍后重试';

	/// zh-CN: '有媒体上传失败，请重试或移除后再发布'
	String get momentsHasFailedUploads => '有媒体上传失败，请重试或移除后再发布';

	/// zh-CN: '$count 项上传失败'
	String uploadPartialFailed({required Object count}) => '${count} 项上传失败';

	/// zh-CN: '保存失败'
	String get saveFailed => '保存失败';

	/// zh-CN: '确认'
	String get confirm => '确认';

	/// zh-CN: '成功'
	String get success => '成功';

	/// zh-CN: '个人展示'
	String get personalDisplay => '个人展示';

	/// zh-CN: '个性签名'
	String get personalSignature => '个性签名';

	/// zh-CN: '个人背景'
	String get personalBackground => '个人背景';

	/// zh-CN: '表情'
	String get expression => '表情';

	/// zh-CN: '扩展信息'
	String get extendedInfo => '扩展信息';

	/// zh-CN: '职业'
	String get profession => '职业';

	/// zh-CN: '分享失败'
	String get shareFailed => '分享失败';

	/// zh-CN: '$param 格式资料已导出并复制到剪贴板'
	String exportSuccessThenCopiedToClipboard({required Object param}) => '${param} 格式资料已导出并复制到剪贴板';

	/// zh-CN: '设置地区'
	String get setRegion => '设置地区';

	/// zh-CN: '删除操作异常，请重试'
	String get deleteOperationAbnormal => '删除操作异常，请重试';

	/// zh-CN: '正在撤回...'
	String get revoking => '正在撤回...';

	/// zh-CN: '正在编辑...'
	String get editing => '正在编辑...';

	/// zh-CN: '消息ID为空，无法操作'
	String get messageIdCannotBeEmpty => '消息ID为空，无法操作';

	/// zh-CN: '开始撤回消息流程'
	String get startRevokeMessageFlow => '开始撤回消息流程';

	/// zh-CN: '撤回消息追踪'
	String get revokeMessageTracking => '撤回消息追踪';

	/// zh-CN: '使用新的action机制'
	String get useNewActionMechanism => '使用新的action机制';

	/// zh-CN: '撤回消息发送结果'
	String get revokeMessageSendResult => '撤回消息发送结果';

	/// zh-CN: '撤回请求发送完成'
	String get revokeRequestSendComplete => '撤回请求发送完成';

	/// zh-CN: '撤回失败'
	String get revokeFailed => '撤回失败';

	/// zh-CN: '撤回消息异常'
	String get revokeMessageException => '撤回消息异常';

	/// zh-CN: '撤回操作异常'
	String get revokeOperationAbnormal => '撤回操作异常';

	/// zh-CN: '开始编辑消息流程'
	String get startEditMessageFlow => '开始编辑消息流程';

	/// zh-CN: '编辑消息追踪'
	String get editMessageTracking => '编辑消息追踪';

	/// zh-CN: '新内容'
	String get newContent => '新内容';

	/// zh-CN: '编辑消息发送结果'
	String get editMessageSendResult => '编辑消息发送结果';

	/// zh-CN: '编辑请求发送完成'
	String get editRequestSendComplete => '编辑请求发送完成';

	/// zh-CN: '编辑失败'
	String get editFailed => '编辑失败';

	/// zh-CN: '编辑消息异常'
	String get editMessageException => '编辑消息异常';

	/// zh-CN: '编辑操作异常'
	String get editOperationAbnormal => '编辑操作异常';

	/// zh-CN: '错误'
	String get error => '错误';

	/// zh-CN: '无法打开网页'
	String get cannotOpenWebpage => '无法打开网页';

	/// zh-CN: '选择图片失败'
	String get selectImageFailedWithError => '选择图片失败';

	/// zh-CN: '已添加反应'
	String get reactionAdded => '已添加反应';

	/// zh-CN: '已取消反应'
	String get reactionCancelled => '已取消反应';

	/// zh-CN: '重试失败，请检查网络连接'
	String get retryFailedPleaseCheckNetwork => '重试失败，请检查网络连接';

	/// zh-CN: '重试异常'
	String get retryAbnormal => '重试异常';

	/// zh-CN: '删除失败，请重试'
	String get deleteFailedPleaseTryAgain => '删除失败，请重试';

	/// zh-CN: '删除失败，请检查网络连接'
	String get deleteFailedPleaseCheckNetwork => '删除失败，请检查网络连接';

	/// zh-CN: '秒'
	String get seconds => '秒';

	/// zh-CN: '设置失败，请重试'
	String get settingFailedPleaseTryAgain => '设置失败，请重试';

	/// zh-CN: '部分删除成功：$success 成功，$fail 失败'
	String partialDeleteSuccess({required Object success, required Object fail}) => '部分删除成功：${success} 成功，${fail} 失败';

	/// zh-CN: '录音已取消'
	String get recordingCancelled => '录音已取消';

	/// zh-CN: '语音转文字预览'
	String get voiceSttPreviewTitle => '语音转文字预览';

	/// zh-CN: '正在识别中...'
	String get voiceSttConverting => '正在识别中...';

	/// zh-CN: '转文字功能暂未配置'
	String get voiceSttNotConfigured => '转文字功能暂未配置';

	/// zh-CN: '拉取离线消息失败'
	String get pullOfflineMessagesFailed => '拉取离线消息失败';

	/// zh-CN: '拉取离线消息异常'
	String get pullOfflineMessagesAbnormal => '拉取离线消息异常';

	/// zh-CN: '退出登录请求失败，请检查网络连接'
	String get logoutRequestFailedPleaseCheckNetwork => '退出登录请求失败，请检查网络连接';

	/// zh-CN: 'Permission 只支持 Android 和 IOS'
	String get permissionOnlySupportAndroidAndIos => 'Permission 只支持 Android 和 IOS';

	/// zh-CN: '正在重试发送...'
	String get retryingSend => '正在重试发送...';

	/// zh-CN: '好的'
	String get quickReplyOk => '好的';

	/// zh-CN: '好的，谢谢'
	String get quickReplyOkThanks => '好的，谢谢';

	/// zh-CN: '该用户还没有设置个人签名等详细信息'
	String get noDetailedInfo => '该用户还没有设置个人签名等详细信息';

	/// zh-CN: '暂无新注册用户'
	String get noNewRegisteredUsersTitle => '暂无新注册用户';

	/// zh-CN: '当前没有新注册的用户 请稍后再来查看'
	String get noNewRegisteredUsers => '当前没有新注册的用户 请稍后再来查看';

	/// zh-CN: '这里显示最近注册的用户，你可以主动添加他们为好友'
	String get newRegisteredUsersTip => '这里显示最近注册的用户，你可以主动添加他们为好友';

	/// zh-CN: '好友请求'
	String get notificationFriendRequest => '好友请求';

	/// zh-CN: '$requesterName 请求添加你为好友'
	String notificationFriendRequestBody({required Object requesterName}) => '${requesterName} 请求添加你为好友';

	/// zh-CN: '群邀请'
	String get notificationGroupInvite => '群邀请';

	/// zh-CN: '$inviterName 邀请你加入群组 $groupName'
	String notificationGroupInviteBody({required Object inviterName, required Object groupName}) => '${inviterName} 邀请你加入群组 ${groupName}';

	/// zh-CN: '你撤回了一条消息'
	String get youRevokedMessage => '你撤回了一条消息';

	/// zh-CN: '对方撤回了一条消息'
	String get otherRevokedMessage => '对方撤回了一条消息';

	/// zh-CN: '网络故障，请重试！'
	String get networkFailureTryAgain => '网络故障，请重试！';

	/// zh-CN: '当前网络不可用。'
	String get networkNotAvailable => '当前网络不可用。';

	/// zh-CN: '请检查你的网络连接。'
	String get pleaseCheckNetworkConnection => '请检查你的网络连接。';

	/// zh-CN: '(other) {$n分钟前}'
	String lastSeenMinutesAgo({required num n}) => _root.common.timeMinutesAgo(n: n);

	/// zh-CN: '(other) {$n小时前}'
	String lastSeenHoursAgo({required num n}) => _root.common.timeHoursAgo(n: n);

	/// zh-CN: '(other) {$n天前}'
	String lastSeenDaysAgo({required num n}) => _root.common.timeDaysAgo(n: n);

	/// zh-CN: '字体大小设置'
	String get fontSettings => _root.common.fontSizeSetting;

	/// zh-CN: '暂无收藏内容，快去收藏一些有趣的消息吧'
	String get noFavoritesYet => '暂无收藏内容，快去收藏一些有趣的消息吧';

	/// zh-CN: '这是正文内容，你可以在这里看到不同字体大小的显示效果。'
	String get fontPreviewText => '这是正文内容，你可以在这里看到不同字体大小的显示效果。';

	/// zh-CN: '更小'
	String get smaller => '更小';

	/// zh-CN: '当前：$param1 $param2%'
	String currentFontScale({required Object param1, required Object param2}) => '当前：${param1} ${param2}%';

	/// zh-CN: '有效期至: $time'
	String groupAnnouncementExpiry({required Object time}) => '有效期至: ${time}';

	/// zh-CN: '创建失败，请稍后重试'
	String get groupAlbumCreateFailed => '创建失败，请稍后重试';

	/// zh-CN: '删除群相册'
	String get groupAlbumDeleteTitle => '删除群相册';

	/// zh-CN: '确定删除相册「$name」吗？'
	String groupAlbumDeleteConfirm({required Object name}) => '确定删除相册「${name}」吗？';

	/// zh-CN: '相册已删除'
	String get groupAlbumDeleted => '相册已删除';

	/// zh-CN: '删除失败，请稍后重试'
	String get groupAlbumDeleteFailed => '删除失败，请稍后重试';

	/// zh-CN: '更新失败，请稍后重试'
	String get groupAlbumRenameFailed => '更新失败，请稍后重试';

	/// zh-CN: '上传图片'
	String get groupAlbumUploadTooltip => '上传图片';

	/// zh-CN: '删除相册'
	String get groupAlbumDeleteTooltip => '删除相册';

	/// zh-CN: '暂无群相册'
	String get groupAlbumNoAlbum => '暂无群相册';

	/// zh-CN: '图片读取失败，请重试'
	String get groupAlbumPhotoReadFailed => '图片读取失败，请重试';

	/// zh-CN: '图片上传成功'
	String get groupAlbumPhotoUploaded => '图片上传成功';

	/// zh-CN: '图片上传失败，请稍后重试'
	String get groupAlbumPhotoUploadFailed => '图片上传失败，请稍后重试';

	/// zh-CN: '新建相册'
	String get groupAlbumCreateTooltip => '新建相册';

	/// zh-CN: '批量删除图片'
	String get groupAlbumPhotoBatchDeleteTitle => '批量删除图片';

	/// zh-CN: '确定删除选中的 $count 张图片吗？'
	String groupAlbumPhotoBatchDeleteConfirm({required Object count}) => '确定删除选中的 ${count} 张图片吗？';

	/// zh-CN: '删除失败，请稍后重试'
	String get groupAlbumPhotoDeleteFailed => '删除失败，请稍后重试';

	/// zh-CN: '已删除$count张图片'
	String groupAlbumPhotoDeletedAll({required Object count}) => '已删除${count}张图片';

	/// zh-CN: '已删除$success张，$fail张删除失败'
	String groupAlbumPhotoDeletedPartial({required Object success, required Object fail}) => '已删除${success}张，${fail}张删除失败';

	/// zh-CN: '删除图片'
	String get groupAlbumPhotoDeleteTitle => '删除图片';

	/// zh-CN: '确定删除这张图片吗？'
	String get groupAlbumPhotoDeleteConfirm => '确定删除这张图片吗？';

	/// zh-CN: '图片已删除'
	String get groupAlbumPhotoDeleted => '图片已删除';

	/// zh-CN: '批量删除'
	String get groupAlbumPhotoBatchDeleteTooltip => '批量删除';

	/// zh-CN: '退出选择'
	String get groupAlbumPhotoExitSelection => '退出选择';

	/// zh-CN: '无法打开图片链接'
	String get groupAlbumPhotoOpenFailed => '无法打开图片链接';

	/// zh-CN: '图片不存在或已删除'
	String get groupAlbumPhotoNotFound => '图片不存在或已删除';

	/// zh-CN: '应用内打开'
	String get groupAlbumPhotoOpenExternal => '应用内打开';

	/// zh-CN: '已设为相册封面'
	String get groupAlbumPhotoCoverUpdated => '已设为相册封面';

	/// zh-CN: '设置封面失败，请稍后重试'
	String get groupAlbumPhotoCoverFailed => '设置封面失败，请稍后重试';

	/// zh-CN: '下一张'
	String get groupAlbumPhotoNext => '下一张';

	/// zh-CN: '分辨率'
	String get groupAlbumPhotoResolution => '分辨率';

	/// zh-CN: '上传者'
	String get groupAlbumPhotoUploader => '上传者';

	/// zh-CN: '显示'
	String get sectionDisplay => '显示';

	/// zh-CN: '主题'
	String get sectionTheme => '主题';

	/// zh-CN: '选择语言'
	String get selectLanguage => '选择语言';

	/// zh-CN: '完善建议：'
	String get completionSuggestions => '完善建议：';

	/// zh-CN: '通用'
	String get sectionGeneral => '通用';

	/// zh-CN: '隐私与安全'
	String get sectionPrivacySecurity => '隐私与安全';

	/// zh-CN: '帮助与关于'
	String get sectionHelpAbout => '帮助与关于';

	/// zh-CN: '消息仅收发双方可读'
	String get msgOnlyVisibleToParties => '消息仅收发双方可读';

	/// zh-CN: '消息未加密传输'
	String get msgNotEncrypted => '消息未加密传输';

	/// zh-CN: '${count} 条未读'
	String unreadCount({required Object count}) => '${count} 条未读';

	/// zh-CN: '${count}分钟'
	String durationMinutes({required Object count}) => '${count}分钟';

	/// zh-CN: '${count}秒'
	String durationSeconds({required Object count}) => '${count}秒';

	/// zh-CN: '请输入0.01元到10000元之间的金额'
	String get rechargeAmountError => '请输入0.01元到10000元之间的金额';

	/// zh-CN: '充值成功'
	String get rechargeSuccess => '充值成功';

	/// zh-CN: '确认充值'
	String get rechargeConfirm => '确认充值';

	/// zh-CN: '流水记录'
	String get transactionHistory2 => '流水记录';

	/// zh-CN: '暂无流水记录'
	String get noTransactionHistory => '暂无流水记录';

	/// zh-CN: '充值'
	String get transactionTypeIncome => '充值';

	/// zh-CN: '消费'
	String get transactionTypeExpense => '消费';

	/// zh-CN: '登录凭证'
	String get sectionLoginCredentials => '登录凭证';

	/// zh-CN: '频道邀请'
	String get channelInvitations => '频道邀请';

	/// zh-CN: '接受邀请失败'
	String get acceptInvitationFailed => '接受邀请失败';

	/// zh-CN: '拒绝邀请失败'
	String get rejectInvitationFailed => '拒绝邀请失败';

	/// zh-CN: '已接受邀请'
	String get invitationAccepted => '已接受邀请';

	/// zh-CN: '已拒绝邀请'
	String get invitationRejected => '已拒绝邀请';

	/// zh-CN: '待处理'
	String get invitationStatusPending => '待处理';

	/// zh-CN: '已接受'
	String get invitationStatusAccepted => '已接受';

	/// zh-CN: '已拒绝'
	String get invitationStatusRejected => '已拒绝';

	/// zh-CN: '已过期'
	String get invitationStatusExpired => '已过期';

	/// zh-CN: '已取消'
	String get invitationStatusCancelled => '已取消';

	/// zh-CN: '未知'
	String get invitationStatusUnknown => '未知';

	/// zh-CN: '暂无收到的邀请'
	String get noReceivedInvitations => '暂无收到的邀请';

	/// zh-CN: '暂无发出的邀请'
	String get noSentInvitations => '暂无发出的邀请';

	/// zh-CN: '处理中...'
	String get processingDots => '处理中...';

	/// zh-CN: '购买失败，请稍后重试'
	String get purchaseFailed => '购买失败，请稍后重试';

	/// zh-CN: '购买成功'
	String get purchaseSuccess => '购买成功';

	/// zh-CN: '余额不足'
	String get insufficientBalanceTitle => '余额不足';

	/// zh-CN: '当前余额 $currency $balance，需支付 $currency $price。请先充值后再购买。'
	String insufficientBalanceContent({required Object currency, required Object balance, required Object price}) => '当前余额 ${currency} ${balance}，需支付 ${currency} ${price}。请先充值后再购买。';

	/// zh-CN: '去充值'
	String get goRecharge => '去充值';

	/// zh-CN: '暂无订单'
	String get noOrders => '暂无订单';

	/// zh-CN: '订单详情加载失败'
	String get orderDetailLoadFailed => '订单详情加载失败';

	/// zh-CN: '订单号: $no'
	String orderNoLabel({required Object no}) => '订单号: ${no}';

	/// zh-CN: '已取消'
	String get orderStatusCancelled => '已取消';

	/// zh-CN: '未知'
	String get orderStatusUnknown => '未知';

	/// zh-CN: '无法打开该文件'
	String get fileOpenFailed => '无法打开该文件';

	/// zh-CN: '本地备份'
	String get e2eeLocalBackup => '本地备份';

	/// zh-CN: '导出加密备份文件到本地或云端'
	String get e2eeLocalBackupDesc => '导出加密备份文件到本地或云端';

	/// zh-CN: '删除密钥'
	String get e2eeDeleteKey => '删除密钥';

	/// zh-CN: '删除本地存储的密钥（无法恢复）'
	String get e2eeDeleteKeyDesc => '删除本地存储的密钥（无法恢复）';

	/// zh-CN: '当前密钥信息'
	String get e2eeCurrentKeyInfo => '当前密钥信息';

	/// zh-CN: '端到端加密已启用'
	String get e2eeE2EEEnabled => '端到端加密已启用';

	/// zh-CN: '未检测到 E2EE 密钥'
	String get e2eeNoKeyDetected => '未检测到 E2EE 密钥';

	/// zh-CN: '你需要先生成密钥对或从备份中恢复'
	String get e2eeNoKeyDesc => '你需要先生成密钥对或从备份中恢复';

	/// zh-CN: '关于端到端加密'
	String get e2eeAboutTitle => '关于端到端加密';

	/// zh-CN: '• 你的消息在发送前已加密，服务器无法查看内容'
	String get e2eeInfoPoint1 => '• 你的消息在发送前已加密，服务器无法查看内容';

	/// zh-CN: '• 更换设备或删除密钥后，旧消息可能无法解密'
	String get e2eeInfoPoint2 => '• 更换设备或删除密钥后，旧消息可能无法解密';

	/// zh-CN: '• 请定期备份密钥以防数据丢失'
	String get e2eeInfoPoint3 => '• 请定期备份密钥以防数据丢失';

	/// zh-CN: '导出备份'
	String get e2eeExportBackup => '导出备份';

	/// zh-CN: '生成加密备份文件'
	String get e2eeExportBackupDesc => '生成加密备份文件';

	/// zh-CN: '导入备份'
	String get e2eeImportBackup => '导入备份';

	/// zh-CN: '从备份文件恢复密钥'
	String get e2eeImportBackupDesc => '从备份文件恢复密钥';

	/// zh-CN: '确定要生成新的 E2EE 密钥对吗？'
	String get e2eeGenerateKeyConfirm => '确定要生成新的 E2EE 密钥对吗？';

	/// zh-CN: '• 旧消息将无法解密'
	String get e2eeWarnOldMessagesLost => '• 旧消息将无法解密';

	/// zh-CN: '• 需要重新生成备份文件'
	String get e2eeWarnNeedNewBackup => '• 需要重新生成备份文件';

	/// zh-CN: '确认生成'
	String get e2eeConfirmGenerate => '确认生成';

	/// zh-CN: '与 AI 助手的明文会话'
	String get aiPlaintextConfirmTitle => '与 AI 助手的明文会话';

	/// zh-CN: '本会话消息和附件不是端到端加密，服务端可以看到内容。'
	String get aiPlaintextConfirmBody => '本会话消息和附件不是端到端加密，服务端可以看到内容。';

	/// zh-CN: '确认后本设备将记住本次确认；对方身份或密钥变更后会再次询问。'
	String get aiPlaintextConfirmNote => '确认后本设备将记住本次确认；对方身份或密钥变更后会再次询问。';

	/// zh-CN: '已知晓，继续发送'
	String get aiPlaintextConfirmOk => '已知晓，继续发送';

	/// zh-CN: '取消'
	String get aiPlaintextConfirmCancel => '取消';

	/// zh-CN: '确定要删除当前密钥吗？'
	String get e2eeDeleteKeyConfirm => '确定要删除当前密钥吗？';

	/// zh-CN: '• 删除后无法恢复'
	String get e2eeWarnCannotRestore => '• 删除后无法恢复';

	/// zh-CN: '• 所有 E2EE 消息将无法解密'
	String get e2eeWarnAllMsgsLost => '• 所有 E2EE 消息将无法解密';

	/// zh-CN: '确认删除'
	String get e2eeConfirmDelete => '确认删除';

	/// zh-CN: '密钥生成成功'
	String get e2eeKeyGeneratedSuccess => '密钥生成成功';

	/// zh-CN: '设备 ID: $id'
	String e2eeDeviceIdInfo({required Object id}) => '设备 ID: ${id}';

	/// zh-CN: '密钥 ID: $id'
	String e2eeKeyIdInfo({required Object id}) => '密钥 ID: ${id}';

	/// zh-CN: '创建时间: $time'
	String e2eeCreatedAtInfo({required Object time}) => '创建时间: ${time}';

	/// zh-CN: '重要提示'
	String get e2eeImportantNote => '重要提示';

	/// zh-CN: '• 旧消息可能无法解密'
	String get e2eeWarnOldMayNotDecrypt => '• 旧消息可能无法解密';

	/// zh-CN: '• 建议立即导出备份'
	String get e2eeSuggestBackupNow => '• 建议立即导出备份';

	/// zh-CN: '去备份'
	String get e2eeGoBackup => '去备份';

	/// zh-CN: '密钥生成失败，请重试'
	String get e2eeKeyGenerateFailed => '密钥生成失败，请重试';

	/// zh-CN: '密钥已删除'
	String get e2eeKeyDeleted => '密钥已删除';

	/// zh-CN: '删除失败，请重试'
	String get e2eeDeleteFailed => '删除失败，请重试';

	/// zh-CN: '桌面通知'
	String get webFeatureNotification => '桌面通知';

	/// zh-CN: '即使不在页面也能收到新消息提醒'
	String get webFeatureNotificationDesc => '即使不在页面也能收到新消息提醒';

	/// zh-CN: '请在手机上确认登录'
	String get webQRConfirmOnPhone => '请在手机上确认登录';

	/// zh-CN: '登录失败'
	String get webQRLoginFailed => '登录失败';

	/// zh-CN: '登录成功'
	String get webQRLoginSuccess => '登录成功';

	/// zh-CN: '$seconds 秒后过期'
	String webQRExpiresIn({required Object seconds}) => '${seconds} 秒后过期';

	/// zh-CN: '登录失败，请重试'
	String get webQRStatusFailed => '登录失败，请重试';

	/// zh-CN: '正在跳转...'
	String get webQRStatusSuccess => '正在跳转...';

	/// zh-CN: '请输入账号和密码'
	String get webLoginEmptyError => '请输入账号和密码';

	/// zh-CN: '生成二维码失败'
	String get webQRGenerateFailed => '生成二维码失败';

	/// zh-CN: '登录令牌无效'
	String get webQRTokenInvalid => '登录令牌无效';

	/// zh-CN: '无法获取对方设备密钥，消息未发送'
	String get e2eeErrNoRecipientKey => '无法获取对方设备密钥，消息未发送';

	/// zh-CN: '对方还没有在任何设备上登录过，暂时无法加密发送；请等对方登录后再试'
	String get e2eeErrPeerNotOnboarded => '对方还没有在任何设备上登录过，暂时无法加密发送；请等对方登录后再试';

	/// zh-CN: '消息无法解密'
	String get e2eeDecryptFailed => '消息无法解密';

	/// zh-CN: '此消息无法解密，可能原因是：'
	String get e2eeDecryptFailedReasons => '此消息无法解密，可能原因是：';

	/// zh-CN: '• 你在其他设备上登录'
	String get e2eeDecryptReasonOtherDevice => '• 你在其他设备上登录';

	/// zh-CN: '• 设备密钥已过期'
	String get e2eeDecryptReasonKeyExpired => '• 设备密钥已过期';

	/// zh-CN: '• 应用数据损坏'
	String get e2eeDecryptReasonDataCorrupt => '• 应用数据损坏';

	/// zh-CN: '请选择解决方案：'
	String get e2eeDecryptChooseSolution => '请选择解决方案：';

	/// zh-CN: '提示：重建后，对方需重新获取你的新密钥；重建期间未送达的加密消息可能不会自动重发。历史消息不受影响。'
	String get e2eeDecryptRecreateHint => '提示：重建后，对方需重新获取你的新密钥；重建期间未送达的加密消息可能不会自动重发。历史消息不受影响。';

	/// zh-CN: '对方的安全码已变更（可能因对方重装应用或更换设备）。若你重视安全，请通过其他渠道与对方核实身份。'
	String get e2eePeerKeyChanged => '对方的安全码已变更（可能因对方重装应用或更换设备）。若你重视安全，请通过其他渠道与对方核实身份。';

	/// zh-CN: '合规审计密钥已变更'
	String get complianceKeyChangedTitle => '合规审计密钥已变更';

	/// zh-CN: '服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。'
	String get complianceKeyChangedBody => '服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。';

	/// zh-CN: '确认轮换'
	String get complianceKeyChangedActionConfirm => '确认轮换';

	/// zh-CN: '暂不确认'
	String get complianceKeyChangedActionKeep => '暂不确认';

	/// zh-CN: '重新创建密钥（推荐）'
	String get e2eeDecryptActionRecreateKey => '重新创建密钥（推荐）';

	/// zh-CN: '重新登录'
	String get e2eeDecryptActionRelogin => '重新登录';

	/// zh-CN: '稍后提醒我'
	String get e2eeDecryptActionRemindLater => '稍后提醒我';

	/// zh-CN: '导出 E2EE 备份'
	String get e2eeBackupExportTitle => '导出 E2EE 备份';

	/// zh-CN: '• 备份密码无法找回，请务必牢记！'
	String get e2eeBackupPwdCantRecover => '• 备份密码无法找回，请务必牢记！';

	/// zh-CN: '• 建议将备份文件存储到多个安全位置（邮件、云盘、U盘）'
	String get e2eeBackupStoreMultipleNote => '• 建议将备份文件存储到多个安全位置（邮件、云盘、U盘）';

	/// zh-CN: '生成恢复密钥（忘记口令的备用凭据）'
	String get e2eeUseRecoveryKey => '生成恢复密钥（忘记口令的备用凭据）';

	/// zh-CN: '恢复密钥'
	String get e2eeRecoveryKeyTitle => '恢复密钥';

	/// zh-CN: '请立即保存这串恢复密钥（截图或存入密码管理器）。忘记口令时，它是解密备份的唯一凭据；一旦丢失，备份将永久无法恢复。'
	String get e2eeRecoveryKeySaveNote => '请立即保存这串恢复密钥（截图或存入密码管理器）。忘记口令时，它是解密备份的唯一凭据；一旦丢失，备份将永久无法恢复。';

	/// zh-CN: '恢复密钥已复制，$seconds 秒后将自动清除剪贴板，请尽快保存'
	String e2eeRecoveryKeyCopiedAutoClear({required Object seconds}) => '恢复密钥已复制，${seconds} 秒后将自动清除剪贴板，请尽快保存';

	/// zh-CN: '加密附件封装失败，文件未上传；请稍后重试'
	String get e2eeErrAttachmentSeal => '加密附件封装失败，文件未上传；请稍后重试';

	/// zh-CN: '目标会话不是端到端加密，无法转发加密附件'
	String get e2eeErrForwardPlaintextTarget => '目标会话不是端到端加密，无法转发加密附件';

	/// zh-CN: '原加密附件无法在本机解密，转发失败'
	String get e2eeErrForwardUndecryptable => '原加密附件无法在本机解密，转发失败';

	/// zh-CN: '重试解密失败的消息'
	String get e2eeRetryFailedMessages => '重试解密失败的消息';

	/// zh-CN: '已重试 $count 条解密失败的消息'
	String e2eeRetryFailedDone({required Object count}) => '已重试 ${count} 条解密失败的消息';

	/// zh-CN: '没有需要重试的解密失败消息'
	String get e2eeRetryFailedNone => '没有需要重试的解密失败消息';

	/// zh-CN: '标准模式'
	String get e2eeModeStandard => '标准模式';

	/// zh-CN: '合规加密'
	String get e2eeModeCompliance => '合规加密';

	/// zh-CN: '端到端加密'
	String get e2eeModeStrict => '端到端加密';

	/// zh-CN: '备份密码 *'
	String get e2eeBackupPwdLabel => '备份密码 *';

	/// zh-CN: '至少 12 位，包含大小写字母、数字和特殊符号'
	String get e2eeBackupPwdHint => '至少 12 位，包含大小写字母、数字和特殊符号';

	/// zh-CN: '确认密码 *'
	String get e2eeBackupConfirmPwdLabel => '确认密码 *';

	/// zh-CN: '再次输入密码'
	String get e2eeBackupConfirmPwdHint => '再次输入密码';

	/// zh-CN: '备注（可选）'
	String get e2eeBackupNoteLabel => '备注（可选）';

	/// zh-CN: '例如：主手机备份 - 2026年1月'
	String get e2eeBackupNoteHint => '例如：主手机备份 - 2026年1月';

	/// zh-CN: '密码强度'
	String get e2eeBackupPwdStrengthLabel => '密码强度';

	/// zh-CN: '弱 - 建议增加复杂度'
	String get e2eeBackupPwdWeak => '弱 - 建议增加复杂度';

	/// zh-CN: '中等 - 建议增加长度或复杂度'
	String get e2eeBackupPwdMedium => '中等 - 建议增加长度或复杂度';

	/// zh-CN: '强 - 可以使用'
	String get e2eeBackupPwdStrong => '强 - 可以使用';

	/// zh-CN: '非常强 - 安全'
	String get e2eeBackupPwdVeryStrong => '非常强 - 安全';

	/// zh-CN: '生成备份文件'
	String get e2eeBackupGenerateBtn => '生成备份文件';

	/// zh-CN: '备份文件已生成！'
	String get e2eeBackupFileGenerated => '备份文件已生成！';

	/// zh-CN: '通过邮件/云盘分享'
	String get e2eeBackupShareBtn => '通过邮件/云盘分享';

	/// zh-CN: '这是我的 Imboy E2EE 密钥备份文件，请妥善保管，切勿泄露给他人。'
	String get e2eeBackupShareContent => '这是我的 Imboy E2EE 密钥备份文件，请妥善保管，切勿泄露给他人。';

	/// zh-CN: '两次输入的密码不一致'
	String get e2eeBackupErrPwdMismatch => '两次输入的密码不一致';

	/// zh-CN: '无法获取密钥数据'
	String get e2eeBackupErrNoKeyData => '无法获取密钥数据';

	/// zh-CN: '导出失败，请重试'
	String get e2eeBackupErrExportFailed => '导出失败，请重试';

	/// zh-CN: '分享失败，请重试'
	String get e2eeBackupErrShareFailed => '分享失败，请重试';

	/// zh-CN: '备份导出成功'
	String get e2eeBackupExportSuccessTitle => '备份导出成功';

	/// zh-CN: '你的 E2EE 密钥备份已成功生成。'
	String get e2eeBackupExportSuccessBody => '你的 E2EE 密钥备份已成功生成。';

	/// zh-CN: '重要提示：'
	String get e2eeBackupImportantNoteColon => '重要提示：';

	/// zh-CN: '• 请妥善保管备份文件和密码'
	String get e2eeBackupKeepSafe => '• 请妥善保管备份文件和密码';

	/// zh-CN: '• 建议将文件存储到多个安全位置'
	String get e2eeBackupStoreMultipleLoc => '• 建议将文件存储到多个安全位置';

	/// zh-CN: '• 密码无法找回，请务必牢记'
	String get e2eeBackupPwdCantRecoverNote => '• 密码无法找回，请务必牢记';

	/// zh-CN: '导入 E2EE 备份'
	String get e2eeBackupImportTitle => '导入 E2EE 备份';

	/// zh-CN: '导入说明'
	String get e2eeBackupImportGuide => '导入说明';

	/// zh-CN: '• 导入后，当前的 E2EE 密钥将被替换'
	String get e2eeBackupImportReplaceKey => '• 导入后，当前的 E2EE 密钥将被替换';

	/// zh-CN: '• 请确保备份文件来自可信任的来源'
	String get e2eeBackupImportTrustedSource => '• 请确保备份文件来自可信任的来源';

	/// zh-CN: '选择备份文件'
	String get e2eeBackupSelectFile => '选择备份文件';

	/// zh-CN: '点击选择备份文件 (.enc)'
	String get e2eeBackupSelectFileHint => '点击选择备份文件 (.enc)';

	/// zh-CN: '备份信息'
	String get e2eeBackupInfoTitle => '备份信息';

	/// zh-CN: '版本号'
	String get e2eeBackupVersionLabel => '版本号';

	/// zh-CN: '算法'
	String get e2eeBackupAlgorithmLabel => '算法';

	/// zh-CN: '文件大小'
	String get e2eeBackupFileSizeLabel => '文件大小';

	/// zh-CN: '$bytes 字节'
	String e2eeBackupFileBytes({required Object bytes}) => '${bytes} 字节';

	/// zh-CN: '文件：$name'
	String e2eeBackupGeneratedFile({required Object name}) => '文件：${name}';

	/// zh-CN: '✓ 文件格式有效'
	String get e2eeBackupFileValid => '✓ 文件格式有效';

	/// zh-CN: '请输入备份时设置的密码'
	String get e2eeBackupImportPwdHint => '请输入备份时设置的密码';

	/// zh-CN: '导入密钥'
	String get e2eeBackupImportBtn => '导入密钥';

	/// zh-CN: '选择文件失败，请重试'
	String get e2eeBackupErrSelectFile => '选择文件失败，请重试';

	/// zh-CN: '文件验证失败，请检查文件格式'
	String get e2eeBackupErrValidateFailed => '文件验证失败，请检查文件格式';

	/// zh-CN: '导入失败，请检查密码是否正确'
	String get e2eeBackupErrImportFailed => '导入失败，请检查密码是否正确';

	/// zh-CN: '导入成功'
	String get e2eeBackupImportSuccessTitle => '导入成功';

	/// zh-CN: 'E2EE 密钥已成功恢复！'
	String get e2eeBackupImportSuccessBody => 'E2EE 密钥已成功恢复！';

	/// zh-CN: '注意：仅备份中包含且成功写入的群聊会话可用于读取对应历史；单聊历史无法恢复，因为单聊密钥不跨设备备份'
	String get e2eeBackupImportSuccessNote => '注意：仅备份中包含且成功写入的群聊会话可用于读取对应历史；单聊历史无法恢复，因为单聊密钥不跨设备备份';

	/// zh-CN: '恢复历史群密钥'
	String get e2eeBackupHistoryGrantTitle => '恢复历史群密钥';

	/// zh-CN: '此操作将授权本设备恢复 $count 个群密钥，并仅按各自的入群世代和消息序号范围解密历史。身份密钥已单独恢复；取消不会恢复这些群密钥。'
	String e2eeBackupHistoryGrantBody({required Object count}) => '此操作将授权本设备恢复 ${count} 个群密钥，并仅按各自的入群世代和消息序号范围解密历史。身份密钥已单独恢复；取消不会恢复这些群密钥。';

	/// zh-CN: '历史群密钥：已授权恢复 $restored 个，已省略 $omitted 个'
	String e2eeBackupHistoryRestoreResult({required Object restored, required Object omitted}) => '历史群密钥：已授权恢复 ${restored} 个，已省略 ${omitted} 个';

	/// zh-CN: '提示：设备身份同步暂未完成，本设备可能暂时无法解密新消息；重新登录后将自动完成同步'
	String get e2eeBackupDeviceKeySyncPending => '提示：设备身份同步暂未完成，本设备可能暂时无法解密新消息；重新登录后将自动完成同步';

	/// zh-CN: '备份属于其他账号，已拒绝恢复'
	String get e2eeBackupErrAccountMismatch => '备份属于其他账号，已拒绝恢复';

	/// zh-CN: '该备份早于本机最近一次成功恢复（疑似旧版本重放），已拒绝'
	String get e2eeBackupErrStaleBackup => '该备份早于本机最近一次成功恢复（疑似旧版本重放），已拒绝';

	/// zh-CN: '部分完成'
	String get e2eeBackupRestorePartialTitle => '部分完成';

	/// zh-CN: 'E2EE 密钥已恢复；群密钥写入中断（已写入 $written/$total 条）。请重新导入同一备份以补完剩余部分（重复写入安全）'
	String e2eeBackupRestorePartialBody({required Object written, required Object total}) => 'E2EE 密钥已恢复；群密钥写入中断（已写入 ${written}/${total} 条）。请重新导入同一备份以补完剩余部分（重复写入安全）';

	/// zh-CN: '本机身份密钥已更换，与联系人的安全码将发生变化，请重新核验'
	String get e2eeBackupSafetyNumberChangedNote => '本机身份密钥已更换，与联系人的安全码将发生变化，请重新核验';

	/// zh-CN: '创建时间'
	String get e2eeBackupCreatedAtRow => '创建时间';

	/// zh-CN: '备份到云端'
	String get e2eeBackupCloudUploadBtn => '备份到云端';

	/// zh-CN: '已备份到云端（版本 $version）'
	String e2eeBackupCloudUploadSuccess({required Object version}) => '已备份到云端（版本 ${version}）';

	/// zh-CN: '云端备份失败，请重试'
	String get e2eeBackupErrCloudUploadFailed => '云端备份失败，请重试';

	/// zh-CN: '保护你的加密历史'
	String get e2eeBackupSetupTitle => '保护你的加密历史';

	/// zh-CN: '设置恢复口令并上传云端备份后，换机或重装才能找回加密聊天历史；没有备份，历史消息在新设备上将无法解密。'
	String get e2eeBackupSetupBody => '设置恢复口令并上传云端备份后，换机或重装才能找回加密聊天历史；没有备份，历史消息在新设备上将无法解密。';

	/// zh-CN: '自选恢复口令，或点击下方生成随机恢复密钥'
	String get e2eeBackupSetupPwdHint => '自选恢复口令，或点击下方生成随机恢复密钥';

	/// zh-CN: '口令偏短，建议 12 位以上，或点击下方「生成恢复密钥」改用随机密钥'
	String get e2eeBackupSetupWeakHint => '口令偏短，建议 12 位以上，或点击下方「生成恢复密钥」改用随机密钥';

	/// zh-CN: '完成并上传云端备份'
	String get e2eeBackupSetupSubmit => '完成并上传云端备份';

	/// zh-CN: '稍后再说（下次启动仍会提醒）'
	String get e2eeBackupSetupLater => '稍后再说（下次启动仍会提醒）';

	/// zh-CN: '请先完成密钥备份设置'
	String get e2eeBackupSetupBlockedToast => '请先完成密钥备份设置';

	/// zh-CN: '已稍后，下次启动会再次提醒'
	String get e2eeBackupSetupPostponedToast => '已稍后，下次启动会再次提醒';

	/// zh-CN: '口令至少 8 位'
	String get e2eeBackupSetupPwdTooShort => '口令至少 8 位';

	/// zh-CN: '正在上传…'
	String get e2eeBackupSetupUploading => '正在上传…';

	/// zh-CN: '正在本机加密并上传到云端，请稍候；网络不佳时可以点下方「稍后再说」先跳过'
	String get e2eeBackupSetupBusyHint => '正在本机加密并上传到云端，请稍候；网络不佳时可以点下方「稍后再说」先跳过';

	/// zh-CN: '上传超时，请检查网络后重试，或稍后再设置'
	String get e2eeBackupSetupTimeoutToast => '上传超时，请检查网络后重试，或稍后再设置';

	/// zh-CN: '暂不设置备份？'
	String get e2eeBackupSetupLaterConfirmTitle => '暂不设置备份？';

	/// zh-CN: '暂不设置的话，换设备或重装后这些加密聊天记录将无法解密，也无法找回。下次启动仍会提醒你。'
	String get e2eeBackupSetupLaterConfirmBody => '暂不设置的话，换设备或重装后这些加密聊天记录将无法解密，也无法找回。下次启动仍会提醒你。';

	/// zh-CN: '继续设置'
	String get e2eeBackupSetupLaterConfirmStay => '继续设置';

	/// zh-CN: '暂不设置'
	String get e2eeBackupSetupLaterConfirmLeave => '暂不设置';

	/// zh-CN: '恢复口令已存入本机安全存储；今后密钥变化时会自动用它重新上传备份，无需再次输入。'
	String get e2eeBackupSetupSavedNote => '恢复口令已存入本机安全存储；今后密钥变化时会自动用它重新上传备份，无需再次输入。';

	/// zh-CN: '从云端备份恢复'
	String get e2eeBackupCloudRestoreTitle => '从云端备份恢复';

	/// zh-CN: '检测到云端备份（版本 $version）'
	String e2eeBackupCloudRestoreHint({required Object version}) => '检测到云端备份（版本 ${version}）';

	/// zh-CN: '从云端恢复'
	String get e2eeBackupCloudRestoreBtn => '从云端恢复';

	/// zh-CN: '恢复后将覆盖本设备当前的 E2EE 密钥'
	String get e2eeBackupCloudRestoreConfirmNote => '恢复后将覆盖本设备当前的 E2EE 密钥';

	/// zh-CN: '请输入备份口令'
	String get e2eeBackupCloudPwdHint => '请输入备份口令';

	/// zh-CN: '云端暂无备份'
	String get e2eeBackupErrNoCloudBackup => '云端暂无备份';

	/// zh-CN: '口令错误或备份损坏'
	String get e2eeBackupErrCloudPwd => '口令错误或备份损坏';

	/// zh-CN: '云端恢复失败，请重试'
	String get e2eeBackupErrCloudRestoreFailed => '云端恢复失败，请重试';

	/// zh-CN: '或从链接导入'
	String get e2eeBackupUrlImportTitle => '或从链接导入';

	/// zh-CN: '粘贴备份文件所在链接（仅支持 HTTPS），下载后自动校验'
	String get e2eeBackupUrlImportHint => '粘贴备份文件所在链接（仅支持 HTTPS），下载后自动校验';

	/// zh-CN: '备份文件链接'
	String get e2eeBackupUrlFieldLabel => '备份文件链接';

	/// zh-CN: 'https://...'
	String get e2eeBackupUrlFieldHint => 'https://...';

	/// zh-CN: '下载并校验'
	String get e2eeBackupUrlImportBtn => '下载并校验';

	/// zh-CN: '正在下载...'
	String get e2eeBackupUrlDownloading => '正在下载...';

	/// zh-CN: '链接无效，仅支持 HTTPS'
	String get e2eeBackupErrUrlInvalid => '链接无效，仅支持 HTTPS';

	/// zh-CN: '下载失败，请检查链接与网络'
	String get e2eeBackupErrUrlDownload => '下载失败，请检查链接与网络';

	/// zh-CN: '下载超时，请重试'
	String get e2eeBackupErrUrlTimeout => '下载超时，请重试';

	/// zh-CN: '安全连接失败，无法验证服务器证书'
	String get e2eeBackupErrUrlTls => '安全连接失败，无法验证服务器证书';

	/// zh-CN: '服务器返回错误'
	String get e2eeBackupErrUrlHttp => '服务器返回错误';

	/// zh-CN: '服务器返回的内容为空'
	String get e2eeBackupErrUrlEmpty => '服务器返回的内容为空';

	/// zh-CN: '文件过大（超过 10MB 上限）'
	String get e2eeBackupErrUrlTooLarge => '文件过大（超过 10MB 上限）';

	/// zh-CN: '密码加密失败'
	String get passwordEncryptFailed => '密码加密失败';

	/// zh-CN: '配置获取超时：请检查网络连接或服务端状态'
	String get initConfigTimeout => '配置获取超时：请检查网络连接或服务端状态';

	/// zh-CN: '网络故障或服务故障 (HTTP $code)'
	String initConfigNetworkError({required Object code}) => '网络故障或服务故障 (HTTP ${code})';

	/// zh-CN: '服务故障协议有误'
	String get initConfigProtocolError => '服务故障协议有误';

	/// zh-CN: '配置获取失败，请检查网络连接'
	String get initConfigFetchFailed => '配置获取失败，请检查网络连接';

	/// zh-CN: '配置解密失败：应用与服务端安全密钥不一致，请更新应用版本或联系管理员'
	String get initConfigDecryptFailed => '配置解密失败：应用与服务端安全密钥不一致，请更新应用版本或联系管理员';

	/// zh-CN: '保存失败，请重试'
	String get saveFailedRetry => '保存失败，请重试';

	/// zh-CN: '下载文件不存在，请重试'
	String get downloadFileNotFound => '下载文件不存在，请重试';

	/// zh-CN: '文件校验失败，正在重新下载 ($retry/$max)'
	String downloadHashRetrying({required Object retry, required Object max}) => '文件校验失败，正在重新下载 (${retry}/${max})';

	/// zh-CN: '文件多次校验失败，请检查网络后重试'
	String get downloadHashFailed => '文件多次校验失败，请检查网络后重试';

	/// zh-CN: '返回首页'
	String get buttonBackHome => '返回首页';

	/// zh-CN: '当前功能未启用'
	String get featureNotEnabled => '当前功能未启用';

	/// zh-CN: '$name 功能未启用，暂时无法访问'
	String featureDisabledName({required Object name}) => '${name} 功能未启用，暂时无法访问';

	/// zh-CN: '加载失败'
	String get imageLoadFailed => '加载失败';

	/// zh-CN: '加载失败: $error'
	String loadFailedWithError({required Object error}) => '加载失败: ${error}';

	/// zh-CN: 'Web 平台暂不支持语音消息播放'
	String get webAudioNotSupported => 'Web 平台暂不支持语音消息播放';

	/// zh-CN: '密钥创建失败: $error'
	String e2eeKeyRecreationFailed({required Object error}) => '密钥创建失败: ${error}';

	/// zh-CN: '红包'
	String get redPacket => '红包';

	/// zh-CN: '转账'
	String get transfer => '转账';

	/// zh-CN: '提现'
	String get withdraw => '提现';

	/// zh-CN: '发红包'
	String get redPacketSend => '发红包';

	/// zh-CN: '红包详情'
	String get redPacketDetail => '红包详情';

	/// zh-CN: '发起转账'
	String get transferSend => '发起转账';

	/// zh-CN: '恭喜发财，大吉大利'
	String get greetingDefault => '恭喜发财，大吉大利';

	/// zh-CN: '查看红包'
	String get redPacketView => '查看红包';

	/// zh-CN: 'IMBoy 红包'
	String get redPacketBrand => 'IMBoy 红包';

	/// zh-CN: '送你一个红包'
	String get redPacketDialogTitle => '送你一个红包';

	/// zh-CN: '大吉大利，恭喜发财'
	String get redPacketDialogSubtitle => '大吉大利，恭喜发财';

	/// zh-CN: '转账金额：$amount 元'
	String transferAmountYuan({required Object amount}) => '转账金额：${amount} 元';

	/// zh-CN: '余额不足'
	String get insufficientBalance => '余额不足';

	/// zh-CN: '提现成功'
	String get withdrawSuccess => '提现成功';

	/// zh-CN: '确认提现'
	String get withdrawConfirm => '确认提现';

	/// zh-CN: '手续费与到账时间以实际结算为准'
	String get withdrawFeeNotice => '手续费与到账时间以实际结算为准';

	/// zh-CN: '请输入不低于0.01元的金额'
	String get withdrawAmountError => '请输入不低于0.01元的金额';

	/// zh-CN: '请输入提现账号'
	String get withdrawAccountEmpty => '请输入提现账号';

	/// zh-CN: '提现方式'
	String get withdrawMethod => '提现方式';

	/// zh-CN: '提现金额'
	String get withdrawAmountLabel => '提现金额';

	/// zh-CN: '支付宝'
	String get withdrawAlipay => '支付宝';

	/// zh-CN: '微信'
	String get withdrawWechat => '微信';

	/// zh-CN: '提现账号（邮箱或手机号）'
	String get withdrawAccountHintAlipay => '提现账号（邮箱或手机号）';

	/// zh-CN: '提现账号（微信号）'
	String get withdrawAccountHintWechat => '提现账号（微信号）';

	/// zh-CN: '请输入正确的支付宝邮箱或手机号'
	String get withdrawAlipayFormatError => '请输入正确的支付宝邮箱或手机号';

	/// zh-CN: '请输入正确的微信号（6-20位，字母开头）'
	String get withdrawWechatFormatError => '请输入正确的微信号（6-20位，字母开头）';

	/// zh-CN: '提现金额：￥$amount'
	String withdrawConfirmAmount({required Object amount}) => '提现金额：￥${amount}';

	/// zh-CN: '提现方式：$method'
	String withdrawConfirmMethod({required Object method}) => '提现方式：${method}';

	/// zh-CN: '提现账号：$account'
	String withdrawConfirmAccount({required Object account}) => '提现账号：${account}';

	/// zh-CN: '暂无历史记录'
	String get noHistory => '暂无历史记录';

	/// zh-CN: '请输入金额'
	String get enterAmount => '请输入金额';

	/// zh-CN: '转账给好友'
	String get transferDefaultRemark => '转账给好友';

	/// zh-CN: '转账最低金额为 0.01 元'
	String get transferMinAmountError => '转账最低金额为 0.01 元';

	/// zh-CN: '当前为：拼手气红包'
	String get redPacketCurrentLucky => '当前为：拼手气红包';

	/// zh-CN: '当前为：普通红包'
	String get redPacketCurrentNormal => '当前为：普通红包';

	/// zh-CN: '改为普通红包'
	String get redPacketSwitchToNormal => '改为普通红包';

	/// zh-CN: '改为拼手气红包'
	String get redPacketSwitchToLucky => '改为拼手气红包';

	/// zh-CN: '红包个数'
	String get redPacketCount => '红包个数';

	/// zh-CN: '个'
	String get redPacketCountUnit => '个';

	/// zh-CN: '请输入红包个数'
	String get redPacketCountEmpty => '请输入红包个数';

	/// zh-CN: '红包个数需大于等于 1'
	String get redPacketCountMin => '红包个数需大于等于 1';

	/// zh-CN: '总金额'
	String get redPacketTotalAmount => '总金额';

	/// zh-CN: '单个金额'
	String get redPacketSingleAmount => '单个金额';

	/// zh-CN: '留言 / 祝福语'
	String get redPacketGreetingLabel => '留言 / 祝福语';

	/// zh-CN: '塞钱发红包'
	String get redPacketStuffLucky => '塞钱发红包';

	/// zh-CN: '放入钱包发送'
	String get redPacketStuffNormal => '放入钱包发送';

	/// zh-CN: '金额必须大于 0'
	String get amountMustPositive => '金额必须大于 0';

	/// zh-CN: '钱包余额 ￥$balance'
	String walletBalanceLabel({required Object balance}) => '钱包余额 ￥${balance}';

	/// zh-CN: '转账金额'
	String get transferAmountLabel => '转账金额';

	/// zh-CN: '转账备注'
	String get transferRemarkLabel => '转账备注';

	/// zh-CN: '确认转账'
	String get transferConfirm => '确认转账';

	/// zh-CN: '正在收款...'
	String get transferReceiving => '正在收款...';

	/// zh-CN: '已收取'
	String get transferAccepted => '已收取';

	/// zh-CN: '已退回'
	String get transferRefunded => '已退回';

	/// zh-CN: '等待对方确认'
	String get transferPending => '等待对方确认';

	/// zh-CN: '点击收款'
	String get transferTapToReceive => '点击收款';

	/// zh-CN: '用户：$uid'
	String redPacketReceiverLabel({required Object uid}) => '用户：${uid}';

	/// zh-CN: '红包不存在或已被删除'
	String get redPacketNotFound => '红包不存在或已被删除';

	/// zh-CN: '获取红包详情失败'
	String get redPacketFetchFailed => '获取红包详情失败';

	/// zh-CN: '获取红包详情异常'
	String get redPacketFetchError => '获取红包详情异常';

	/// zh-CN: '总金额至少为份数 × 0.01 元'
	String get redPacketAmountTooSmall => '总金额至少为份数 × 0.01 元';

	/// zh-CN: '支付确认中，请稍后查看订单状态'
	String get purchaseConfirming => '支付确认中，请稍后查看订单状态';

	/// zh-CN: '收款成功！'
	String get payReceiveSuccess => '收款成功！';

	/// zh-CN: 'now'
	String get timeNowShort => 'now';

	/// zh-CN: '${count}d'
	String timeDaysShort({required Object count}) => '${count}d';

	/// zh-CN: '${count}h'
	String timeHoursShort({required Object count}) => '${count}h';

	/// zh-CN: '${count}m'
	String timeMinutesShort({required Object count}) => '${count}m';

	/// zh-CN: '显示密码'
	String get showPassword => '显示密码';

	/// zh-CN: '隐藏密码'
	String get hidePassword => '隐藏密码';

	/// zh-CN: '打开闪光灯'
	String get turnOnFlashlight => '打开闪光灯';

	/// zh-CN: '关闭闪光灯'
	String get turnOffFlashlight => '关闭闪光灯';

	/// zh-CN: '暂停扫描'
	String get pauseScan => '暂停扫描';

	/// zh-CN: '继续扫描'
	String get resumeScan => '继续扫描';

	/// zh-CN: '进入全屏'
	String get enterFullscreen => '进入全屏';

	/// zh-CN: '退出全屏'
	String get exitFullscreen => '退出全屏';

	/// zh-CN: '我'
	String get me => '我';

	/// zh-CN: '刚刚'
	String get justNow => '刚刚';

	/// zh-CN: '分钟前'
	String get minutesAgo => '分钟前';

	/// zh-CN: '小时前'
	String get hoursAgo => '小时前';

	/// zh-CN: '收起'
	String get collapse => '收起';

	/// zh-CN: '展开'
	String get expandFull => '展开';

	/// zh-CN: '小'
	String get fontSizeOptionSmall => '小';

	/// zh-CN: '标准'
	String get fontSizeOptionNormal => '标准';

	/// zh-CN: '中'
	String get fontSizeOptionMedium => '中';

	/// zh-CN: '大'
	String get fontSizeOptionLarge => '大';

	/// zh-CN: '特大'
	String get fontSizeOptionExtraLarge => '特大';

	/// zh-CN: '超大'
	String get fontSizeOptionHuge => '超大';

	/// zh-CN: '开发者'
	String get developer => '开发者';

	/// zh-CN: '搜索失败，请重试'
	String get searchFailedRetry => '搜索失败，请重试';

	/// zh-CN: '消息搜索未启用'
	String get searchDisabledTitle => '消息搜索未启用';

	/// zh-CN: '端到端加密已开启，服务器无法读取消息内容，因此不提供全文搜索'
	String get searchDisabledByEncryption => '端到端加密已开启，服务器无法读取消息内容，因此不提供全文搜索';

	/// zh-CN: '视频格式暂不支持，无法找到对应视频'
	String get collectedVideoFormatIncorrectCannotFindVideoUri => '视频格式暂不支持，无法找到对应视频';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '重试中…'
	String get retrying => '重试中…';
}

// Path: complaint
class Translations$complaint$zh_CN {
	Translations$complaint$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '投诉'
	String get complaint => '投诉';

	/// zh-CN: '提交加密消息证据'
	String get e2eeConsentTitle => '提交加密消息证据';

	/// zh-CN: '该消息为端到端加密消息，服务器无法查看其内容。提交内容摘录会将你选择的消息明文随工单披露给审核员用于核实举报。是否同意提交？'
	String get e2eeConsentBody => '该消息为端到端加密消息，服务器无法查看其内容。提交内容摘录会将你选择的消息明文随工单披露给审核员用于核实举报。是否同意提交？';

	/// zh-CN: '同意并提交证据'
	String get e2eeConsentSubmit => '同意并提交证据';

	/// zh-CN: '仅举报（不提交内容）'
	String get e2eeConsentDecline => '仅举报（不提交内容）';
}

// Path: complaintReason
class Translations$complaintReason$zh_CN {
	Translations$complaintReason$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '垃圾信息'
	String get spam => '垃圾信息';

	/// zh-CN: '骚扰'
	String get harassment => '骚扰';

	/// zh-CN: '不当内容'
	String get inappropriate => '不当内容';

	/// zh-CN: '其他'
	String get other => '其他';
}

// Path: contact
class Translations$contact$zh_CN {
	Translations$contact$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '已拉黑'
	String get blocked => '已拉黑';

	/// zh-CN: '请重启应用以应用更改'
	String get applyChanges => '请重启应用以应用更改';

	/// zh-CN: '输入新标签...'
	String get inputNewTag => '输入新标签...';

	/// zh-CN: '黑名单'
	String get denylist => '黑名单';

	/// zh-CN: '黑名单为空'
	String get denylistEmpty => '黑名单为空';

	/// zh-CN: '收藏、人名、群名、标签等'
	String get favoriteGroupTagsEtc => '收藏、人名、群名、标签等';

	/// zh-CN: '新的朋友'
	String get newFriend => '新的朋友';

	/// zh-CN: '把他推荐给朋友'
	String get recommendToFriend => '把他推荐给朋友';

	/// zh-CN: '备注'
	String get remark => '备注';

	/// zh-CN: '备注和标签'
	String get remarksTags => '备注和标签';

	/// zh-CN: '选择一个群'
	String get selectAGroup => '选择一个群';

	/// zh-CN: '选择朋友'
	String get selectFriends => '选择朋友';

	/// zh-CN: '标签'
	String get tags => '标签';

	/// zh-CN: '建议标签'
	String get suggestedTags => '建议标签';

	/// zh-CN: '请输入备注名'
	String get pleaseEnterRemark => '请输入备注名';

	/// zh-CN: '请输入备注名'
	String get enterRemark => '请输入备注名';

	/// zh-CN: '请输入标签'
	String get pleaseEnterTags => '请输入标签';

	/// zh-CN: '仅好友'
	String get momentsVisibilityFriends => '仅好友';

	/// zh-CN: '标签长度不能超过 $param 个字符'
	String tagLengthExceeded({required Object param}) => '标签长度不能超过 ${param} 个字符';

	/// zh-CN: '最多只能添加 $param 个标签'
	String maxTagsExceeded({required Object param}) => '最多只能添加 ${param} 个标签';

	/// zh-CN: '已选标签 ($param/$max)'
	String selectedTags({required Object param, required Object max}) => '已选标签 (${param}/${max})';

	/// zh-CN: '已发送'
	String get friendRequestSent => '已发送';

	/// zh-CN: '最多可添加 8 个标签'
	String get channelMaxTagsCount => '最多可添加 8 个标签';

	/// zh-CN: '输入标签...'
	String get tagInputHint => '输入标签...';
}

// Path: customerService
class Translations$customerService$zh_CN {
	Translations$customerService$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '客服工作台'
	String get entryTitle => '客服工作台';

	/// zh-CN: '接单并处理排队中的客户会话'
	String get entrySubtitle => '接单并处理排队中的客户会话';

	/// zh-CN: '客服工作台'
	String get title => '客服工作台';

	/// zh-CN: '待接'
	String get tabQueued => '待接';

	/// zh-CN: '处理中'
	String get tabActive => '处理中';

	/// zh-CN: '已关闭'
	String get tabClosed => '已关闭';

	/// zh-CN: '--'
	String get countUnavailable => '--';

	/// zh-CN: '企业'
	String get orgSelectorLabel => '企业';

	/// zh-CN: '暂无可用坐席席位'
	String get noSeatTitle => '暂无可用坐席席位';

	/// zh-CN: '你还没有启用中的客服坐席席位，请联系企业管理员开通'
	String get noSeatHint => '你还没有启用中的客服坐席席位，请联系企业管理员开通';

	/// zh-CN: '刚刚'
	String get waitingJustNow => '刚刚';

	/// zh-CN: '$n 分钟'
	String waitingMinutes({required Object n}) => '${n} 分钟';

	/// zh-CN: '$h 小时 $m 分'
	String waitingHoursMinutes({required Object h, required Object m}) => '${h} 小时 ${m} 分';

	/// zh-CN: '$d 天 $h 小时'
	String waitingDaysHours({required Object d, required Object h}) => '${d} 天 ${h} 小时';

	/// zh-CN: '网页'
	String get sourceWidget => '网页';

	/// zh-CN: '来源'
	String get sourceLabel => '来源';

	/// zh-CN: '暂无待接会话'
	String get queuedEmptyTitle => '暂无待接会话';

	/// zh-CN: '下拉刷新，新会话会出现在这里'
	String get queuedEmptyHint => '下拉刷新，新会话会出现在这里';

	/// zh-CN: '正在加载更多…'
	String get loadingMore => '正在加载更多…';

	/// zh-CN: '加载更多失败，上滑重试'
	String get loadMoreFailed => '加载更多失败，上滑重试';

	/// zh-CN: '没有更多了'
	String get noMore => '没有更多了';

	/// zh-CN: '接单'
	String get claimAction => '接单';

	/// zh-CN: '接单成功'
	String get claimSuccess => '接单成功';

	/// zh-CN: '该会话已被其他坐席接单或状态已变化，已为你刷新最新队列'
	String get claimConflict => '该会话已被其他坐席接单或状态已变化，已为你刷新最新队列';

	/// zh-CN: '当前处于离职交接，暂时不能接单'
	String get claimOffboardingRequired => '当前处于离职交接，暂时不能接单';

	/// zh-CN: '坐席已被暂停，暂不能接单'
	String get claimForbidden => '坐席已被暂停，暂不能接单';

	/// zh-CN: '接单失败，请稍后重试'
	String get claimFailed => '接单失败，请稍后重试';

	/// zh-CN: '席位并发已满（处理中会话达上限），请先关闭处理中的会话或联系管理员调整容量'
	String get seatAtCapacity => '席位并发已满（处理中会话达上限），请先关闭处理中的会话或联系管理员调整容量';

	/// zh-CN: '暂无处理中会话'
	String get activeEmptyTitle => '暂无处理中会话';

	/// zh-CN: '从待接列表接单后，会话会显示在这里'
	String get activeEmptyHint => '从待接列表接单后，会话会显示在这里';

	/// zh-CN: '暂无已关闭会话'
	String get closedEmptyTitle => '暂无已关闭会话';

	/// zh-CN: '已关闭的会话会归档显示在这里'
	String get closedEmptyHint => '已关闭的会话会归档显示在这里';

	/// zh-CN: '加载失败'
	String get loadFailedTitle => '加载失败';

	/// zh-CN: '网络不可用，请检查网络后重试'
	String get offlineHint => '网络不可用，请检查网络后重试';

	/// zh-CN: '坐席已被暂停，队列仅可查看'
	String get seatSuspendedNotice => '坐席已被暂停，队列仅可查看';

	/// zh-CN: '客服会话'
	String get sessionTitle => '客服会话';

	/// zh-CN: '消息通道暂不可用，等待服务端补齐会话绑定'
	String get channelUnavailable => '消息通道暂不可用，等待服务端补齐会话绑定';

	/// zh-CN: '客户'
	String get visitorLabel => '客户';

	/// zh-CN: '坐席'
	String get seatLabel => '坐席';

	/// zh-CN: '输入回复内容…'
	String get inputHint => '输入回复内容…';

	/// zh-CN: '附件'
	String get attachAction => '附件';

	/// zh-CN: '附件已上传'
	String get attachUploaded => '附件已上传';

	/// zh-CN: '附件预览（企业安全通道）'
	String get attachPreviewTitle => '附件预览（企业安全通道）';

	/// zh-CN: '附件'
	String get attachUnnamedFile => '附件';

	/// zh-CN: '暂不可用 · $size'
	String attachStatusUnavailable({required Object size}) => '暂不可用 · ${size}';

	/// zh-CN: '暂不支持该文件类型，请更换文件'
	String get attachUnsupportedType => '暂不支持该文件类型，请更换文件';

	/// zh-CN: '二进制内容，暂不支持预览'
	String get attachBinaryNoPreview => '二进制内容，暂不支持预览';

	/// zh-CN: '转接'
	String get transferAction => '转接';

	/// zh-CN: '转接给同企业坐席'
	String get transferTitle => '转接给同企业坐席';

	/// zh-CN: '暂无可转接的同企业客服坐席'
	String get transferEmpty => '暂无可转接的同企业客服坐席';

	/// zh-CN: '可转接'
	String get targetAvailable => '可转接';

	/// zh-CN: '繁忙'
	String get targetBusy => '繁忙';

	/// zh-CN: '确认转接'
	String get transferConfirmTitle => '确认转接';

	/// zh-CN: '将当前会话转交给 $name？转接后你将不再经办此会话。'
	String transferConfirmBody({required Object name}) => '将当前会话转交给 ${name}？转接后你将不再经办此会话。';

	/// zh-CN: '转接成功'
	String get transferSuccess => '转接成功';

	/// zh-CN: '会话状态已变化，请刷新并核对后重新确认。'
	String get transferConflict => '会话状态已变化，请刷新并核对后重新确认。';

	/// zh-CN: '转接失败，请稍后重试'
	String get transferFailed => '转接失败，请稍后重试';

	/// zh-CN: '关闭会话'
	String get closeAction => '关闭会话';

	/// zh-CN: '确认关闭会话'
	String get closeTitle => '确认关闭会话';

	/// zh-CN: '关闭后客户将进入评分环节，会话进入只读。'
	String get closeBody => '关闭后客户将进入评分环节，会话进入只读。';

	/// zh-CN: '关闭原因（可选）'
	String get closeReasonLabel => '关闭原因（可选）';

	/// zh-CN: '关闭原因不能超过 $max 字'
	String closeReasonTooLong({required Object max}) => '关闭原因不能超过 ${max} 字';

	/// zh-CN: '会话已关闭'
	String get closeSuccess => '会话已关闭';

	/// zh-CN: '会话状态已变化，请刷新并核对后重新确认。'
	String get closeConflict => '会话状态已变化，请刷新并核对后重新确认。';

	/// zh-CN: '关闭失败，请稍后重试'
	String get closeFailed => '关闭失败，请稍后重试';

	/// zh-CN: '会话已关闭，等待客户评分'
	String get waitingRatingTitle => '会话已关闭，等待客户评分';

	/// zh-CN: '客户已完成评分'
	String get ratedTitle => '客户已完成评分';

	/// zh-CN: '客户评分：$score 星'
	String ratingScoreLabel({required Object score}) => '客户评分：${score} 星';

	/// zh-CN: '坐席已被暂停（suspend），消息通道已切换为只读，后台收发已停止'
	String get readOnlySuspended => '坐席已被暂停（suspend），消息通道已切换为只读，后台收发已停止';

	/// zh-CN: '当前处于离职交接，会话经办权已移交，此会话已只读'
	String get offboardingRequired => '当前处于离职交接，会话经办权已移交，此会话已只读';

	/// zh-CN: '会话已关闭，内容仅供查看'
	String get closedReadonly => '会话已关闭，内容仅供查看';

	/// zh-CN: '会话已评分结束，内容仅供查看'
	String get ratedReadonly => '会话已评分结束，内容仅供查看';

	/// zh-CN: '发送失败，请稍后重试'
	String get sendFailed => '发送失败，请稍后重试';

	/// zh-CN: '会话状态已变化，已为你刷新最新状态'
	String get sendConflict => '会话状态已变化，已为你刷新最新状态';

	/// zh-CN: '附件上传失败，请重试'
	String get attachUploadFailed => '附件上传失败，请重试';

	/// zh-CN: '会话已转交给其他坐席，此会话对你只读'
	String get transferredAway => '会话已转交给其他坐席，此会话对你只读';

	/// zh-CN: '坐席状态'
	String get presenceMenuLabel => '坐席状态';

	/// zh-CN: '状态不可用'
	String get presenceUnavailable => '状态不可用';

	/// zh-CN: '席位已停用'
	String get seatDisabledNotice => '席位已停用';

	/// zh-CN: '在线'
	String get presenceStatusOnline => '在线';

	/// zh-CN: '离开'
	String get presenceStatusAway => '离开';

	/// zh-CN: '繁忙'
	String get presenceStatusBusy => '繁忙';

	/// zh-CN: '离线'
	String get presenceStatusOffline => '离线';

	/// zh-CN: '设为离开'
	String get presenceAwayAction => '设为离开';

	/// zh-CN: '恢复自动'
	String get presenceResumeAction => '恢复自动';

	/// zh-CN: '$active/$max 会话'
	String presenceCapacityLabel({required Object active, required Object max}) => '${active}/${max} 会话';

	/// zh-CN: '未读 $n 条'
	String unreadBadgeLabel({required Object n}) => '未读 ${n} 条';

	late final Translations$customerService$governance$zh_CN governance = Translations$customerService$governance$zh_CN.internal(_root);

	/// zh-CN: '当前有未发送草稿；确认此操作不会发送草稿。'
	String get actionDraftWarning => '当前有未发送草稿；确认此操作不会发送草稿。';

	/// zh-CN: '消息正在发送；请等待终态并核对后确认。'
	String get actionSendingWarning => '消息正在发送；请等待终态并核对后确认。';

	/// zh-CN: '附件正在上传；请等待终态并核对后确认。'
	String get actionUploadingWarning => '附件正在上传；请等待终态并核对后确认。';

	/// zh-CN: '仍有消息尚未确认；请先核对结果，当前不能提交会话操作。'
	String get actionUnconfirmedWarning => '仍有消息尚未确认；请先核对结果，当前不能提交会话操作。';

	/// zh-CN: '评价状态未知'
	String get ratingUnknownTitle => '评价状态未知';

	/// zh-CN: '评分时间：$time'
	String ratingTimeLabel({required Object time}) => '评分时间：${time}';

	/// zh-CN: '保存文件'
	String get attachSave => '保存文件';

	/// zh-CN: '文件已保存'
	String get attachSaved => '文件已保存';

	/// zh-CN: '保存失败，可以重试。'
	String get attachSaveFailed => '保存失败，可以重试。';

	/// zh-CN: '正在准备附件'
	String get attachPreparing => '正在准备附件';

	/// zh-CN: '正在申请上传权限'
	String get attachPresigning => '正在申请上传权限';

	/// zh-CN: '正在上传字节：$sent / $total'
	String attachUploading({required Object sent, required Object total}) => '正在上传字节：${sent} / ${total}';

	/// zh-CN: '正在确认已上传文件'
	String get attachConfirming => '正在确认已上传文件';

	/// zh-CN: '附件在上传开始前已取消'
	String get attachCancelled => '附件在上传开始前已取消';

	/// zh-CN: '上传结果尚未完整确认，未自动重试或发送消息。'
	String get attachUnknown => '上传结果尚未完整确认，未自动重试或发送消息。';

	/// zh-CN: '重试附件上传'
	String get attachRetry => '重试附件上传';

	/// zh-CN: '停止后续上传步骤'
	String get attachCancel => '停止后续上传步骤';

	/// zh-CN: '附件须非空且不超过 25 MiB。'
	String get attachTooLarge => '附件须非空且不超过 25 MiB。';

	/// zh-CN: '只显示部分文本；保存文件仍包含完整内容。'
	String get attachPreviewTruncated => '只显示部分文本；保存文件仍包含完整内容。';

	/// zh-CN: '附件已上传，但消息发送结果尚未确认。请核对发送结果，不要重新上传。'
	String get attachUploadedNotSent => '附件已上传，但消息发送结果尚未确认。请核对发送结果，不要重新上传。';

	/// zh-CN: '附件上传未完成，已停止后续操作。请核对权限和会话状态后重新选择文件。'
	String get attachUploadStopped => '附件上传未完成，已停止后续操作。请核对权限和会话状态后重新选择文件。';

	/// zh-CN: '有新消息 · 查看最新'
	String get newMessagesJump => '有新消息 · 查看最新';
}

// Path: discovery
class Translations$discovery$zh_CN {
	Translations$discovery$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '找附近的人'
	String get findNearbyPeople => '找附近的人';

	/// zh-CN: '朋友圈'
	String get moment => '朋友圈';

	/// zh-CN: '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。'
	String get nearbyPeopleExplain => '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。\n你的电话号码将会被隐藏。';

	/// zh-CN: '附近的人'
	String get peopleNearby => '附近的人';

	/// zh-CN: '扫描结果'
	String get scanResult => '扫描结果';

	/// zh-CN: '我的频道'
	String get myChannels => '我的频道';

	/// zh-CN: '其他用户可以通过搜索找到我'
	String get otherUsersCanFindMe => '其他用户可以通过搜索找到我';

	/// zh-CN: '不给谁看 UID 列表（逗号分隔）'
	String get momentsDenyUidsLabel => '不给谁看 UID 列表（逗号分隔）';

	/// zh-CN: '朋友圈'
	String get moments => '朋友圈';

	/// zh-CN: '写评论...'
	String get momentsWriteComment => '写评论...';

	/// zh-CN: '可见性'
	String get momentsVisibility => '可见性';

	/// zh-CN: '公开'
	String get momentsVisibilityPublic => '公开';

	/// zh-CN: '部分可见'
	String get momentsVisibilityPartial => '部分可见';

	/// zh-CN: '不给谁看'
	String get momentsVisibilityExclude => '不给谁看';

	/// zh-CN: '已恢复上次未发送的草稿'
	String get momentsDraftRestored => '已恢复上次未发送的草稿';

	/// zh-CN: '网络异常，显示的是缓存内容'
	String get momentsFeedStale => '网络异常，显示的是缓存内容';

	/// zh-CN: '赞'
	String get momentActionLike => '赞';

	/// zh-CN: '取消点赞'
	String get momentActionCancelLike => '取消点赞';

	/// zh-CN: '评论'
	String get momentActionComment => '评论';

	/// zh-CN: '更多操作'
	String get momentActionMore => '更多操作';

	/// zh-CN: '删除'
	String get momentActionDelete => '删除';

	/// zh-CN: '举报'
	String get momentActionReport => '举报';

	/// zh-CN: '取消'
	String get momentActionCancel => '取消';

	/// zh-CN: '${names} 赞了'
	String momentLikedBy({required Object names}) => '${names} 赞了';

	/// zh-CN: '${names} 等${count}人赞了'
	String momentAndOthersLiked({required Object names, required Object count}) => '${names} 等${count}人赞了';

	/// zh-CN: '这一刻的想法...'
	String get momentContentPlaceholder => '这一刻的想法...';

	/// zh-CN: '全文'
	String get momentShowFull => '全文';

	/// zh-CN: '收起'
	String get momentCollapse => '收起';

	/// zh-CN: '保留草稿？'
	String get momentsDraftKeepTitle => '保留草稿？';

	/// zh-CN: '保留后下次进入可继续编辑'
	String get momentsDraftKeepMessage => '保留后下次进入可继续编辑';

	/// zh-CN: '不保留'
	String get momentsDraftDiscard => '不保留';

	/// zh-CN: '保留'
	String get momentsDraftKeep => '保留';

	/// zh-CN: '打开频道'
	String get openChannel => '打开频道';

	/// zh-CN: '付费频道内容已锁定'
	String get paidChannelLocked => '付费频道内容已锁定';

	/// zh-CN: '已扫描'
	String get webQRScanned => '已扫描';

	/// zh-CN: '${count}人赞了'
	String momentLikesCountOnly({required Object count}) => '${count}人赞了';

	/// zh-CN: '所在位置'
	String get momentLocation => '所在位置';

	/// zh-CN: '不显示位置'
	String get momentLocationNone => '不显示位置';

	/// zh-CN: '提醒谁看'
	String get momentAtWho => '提醒谁看';

	/// zh-CN: '提醒了 ${name}'
	String momentAtReminded({required Object name}) => '提醒了 ${name}';

	/// zh-CN: '提醒了 ${name} 等${count}人'
	String momentAtRemindedMore({required Object name, required Object count}) => '提醒了 ${name} 等${count}人';

	/// zh-CN: '${count}人'
	String momentAtCount({required Object count}) => '${count}人';
}

// Path: enterpriseApp
class Translations$enterpriseApp$zh_CN {
	Translations$enterpriseApp$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '企业应用'
	String get title => '企业应用';

	/// zh-CN: '应用代发'
	String get badgeAppDelegated => '应用代发';

	/// zh-CN: '人工经应用'
	String get badgeHumanDelegated => '人工经应用';

	/// zh-CN: '消息来源'
	String get originTitle => '消息来源';

	/// zh-CN: '应用代发（Application）'
	String get originSenderApplication => '应用代发（Application）';

	/// zh-CN: '人工代发（Human sender）'
	String get originSenderHuman => '人工代发（Human sender）';

	/// zh-CN: '来源应用 $id'
	String originApplicationId({required Object id}) => '来源应用 ${id}';

	/// zh-CN: '企业托管（非个人会话）'
	String get originHosted => '企业托管（非个人会话）';

	/// zh-CN: '发送来源'
	String get originLabelSender => '发送来源';

	/// zh-CN: '加密状态'
	String get originLabelEncryption => '加密状态';

	/// zh-CN: '非端到端加密'
	String get originNonE2ee => '非端到端加密';

	/// zh-CN: '端到端加密（Human 直发）'
	String get originE2ee => '端到端加密（Human 直发）';

	/// zh-CN: '来源信息不一致'
	String get originMismatchTitle => '来源信息不一致';

	/// zh-CN: '消息同时带有企业应用来源与端到端加密载荷；已按非加密的企业来源展示，不视为 Human 直发的加密消息。'
	String get originMismatchHint => '消息同时带有企业应用来源与端到端加密载荷；已按非加密的企业来源展示，不视为 Human 直发的加密消息。';

	/// zh-CN: '来源标记无法识别，已按非加密展示'
	String get originUnrecognized => '来源标记无法识别，已按非加密展示';

	/// zh-CN: '详情'
	String get actionDetails => '详情';

	/// zh-CN: '企业群'
	String get groupTitle => '企业群';

	/// zh-CN: '已归档'
	String get groupArchivedBadge => '已归档';

	/// zh-CN: '归档'
	String get groupActionArchive => '归档';

	/// zh-CN: '归档企业群'
	String get groupArchiveTitle => '归档企业群';

	/// zh-CN: '归档是单向操作：归档后该群对全部企业接口不可见，且不可恢复。'
	String get groupArchiveHint => '归档是单向操作：归档后该群对全部企业接口不可见，且不可恢复。';

	/// zh-CN: '修改群名'
	String get groupActionRename => '修改群名';

	/// zh-CN: '新群名'
	String get groupRenameHint => '新群名';

	/// zh-CN: '成员与角色'
	String get groupMembersTitle => '成员与角色';

	/// zh-CN: '成员'
	String get groupRoleMember => '成员';

	/// zh-CN: '嘉宾'
	String get groupRoleGuest => '嘉宾';

	/// zh-CN: '管理员'
	String get groupRoleAdmin => '管理员';

	/// zh-CN: '群主'
	String get groupRoleOwner => '群主';

	/// zh-CN: '副群主'
	String get groupRoleViceOwner => '副群主';

	/// zh-CN: '群主角色不可变更，也不可经应用分配'
	String get groupRoleOwnerLocked => '群主角色不可变更，也不可经应用分配';

	/// zh-CN: '成员数超过单页上限，已停止加载'
	String get groupOverLimit => '成员数超过单页上限，已停止加载';

	/// zh-CN: '暂无企业群'
	String get groupEmpty => '暂无企业群';

	/// zh-CN: '成员检索'
	String get directoryTitle => '成员检索';

	/// zh-CN: '按姓名或工号检索'
	String get directoryHint => '按姓名或工号检索';

	/// zh-CN: '无匹配成员'
	String get directoryEmpty => '无匹配成员';

	/// zh-CN: '受限目录：按页返回，不提供全量导出'
	String get directoryBounded => '受限目录：按页返回，不提供全量导出';

	/// zh-CN: '加载更多'
	String get directoryLoadMore => '加载更多';

	/// zh-CN: '已到末页'
	String get directoryEnd => '已到末页';

	/// zh-CN: '附件留存治理'
	String get retentionTitle => '附件留存治理';

	/// zh-CN: '留存至 $time'
	String retentionUntil({required Object time}) => '留存至 ${time}';

	/// zh-CN: '未冻结'
	String get holdNone => '未冻结';

	/// zh-CN: '已冻结'
	String get holdHeld => '已冻结';

	/// zh-CN: '冻结原因：$reason'
	String holdReason({required Object reason}) => '冻结原因：${reason}';

	/// zh-CN: '未清除'
	String get purgeLive => '未清除';

	/// zh-CN: '已清除'
	String get purgePurged => '已清除';

	/// zh-CN: '治理记录不可删除'
	String get retentionNoDelete => '治理记录不可删除';

	/// zh-CN: '留存期只可延长，不可缩短'
	String get retentionExtendOnly => '留存期只可延长，不可缩短';

	/// zh-CN: '冻结生效中，不可清除'
	String get purgeBlockedHold => '冻结生效中，不可清除';

	/// zh-CN: '留存未到期，不可清除'
	String get purgeBlockedRetention => '留存未到期，不可清除';

	/// zh-CN: '已清除，不可回退'
	String get purgeBlockedPurged => '已清除，不可回退';

	/// zh-CN: '重试'
	String get actionRetry => '重试';

	/// zh-CN: '重新登录'
	String get actionSignIn => '重新登录';

	/// zh-CN: '请求不被接受'
	String get error400Title => '请求不被接受';

	/// zh-CN: '提交的内容不符合要求，请检查后重试。'
	String get error400Hint => '提交的内容不符合要求，请检查后重试。';

	/// zh-CN: '登录状态已失效'
	String get error401Title => '登录状态已失效';

	/// zh-CN: '请重新登录后再试。'
	String get error401Hint => '请重新登录后再试。';

	/// zh-CN: '企业应用已停用'
	String get error403Title => '企业应用已停用';

	/// zh-CN: '该应用或所属企业已停用，请联系企业管理员。'
	String get error403Hint => '该应用或所属企业已停用，请联系企业管理员。';

	/// zh-CN: '权限范围不足'
	String get error403ScopeTitle => '权限范围不足';

	/// zh-CN: '当前凭据未被授予该操作所需的权限范围。'
	String get error403ScopeHint => '当前凭据未被授予该操作所需的权限范围。';

	/// zh-CN: '超出企业边界'
	String get error403BoundaryTitle => '超出企业边界';

	/// zh-CN: '该资源不属于当前应用所在的企业或工作区。'
	String get error403BoundaryHint => '该资源不属于当前应用所在的企业或工作区。';

	/// zh-CN: '资源不存在'
	String get error404Title => '资源不存在';

	/// zh-CN: '资源不存在，或不在可访问的企业范围内。'
	String get error404Hint => '资源不存在，或不在可访问的企业范围内。';

	/// zh-CN: '操作冲突'
	String get error409Title => '操作冲突';

	/// zh-CN: '重复提交或状态已变化，请刷新后重试。'
	String get error409Hint => '重复提交或状态已变化，请刷新后重试。';

	/// zh-CN: '身份未映射'
	String get error422IdentityTitle => '身份未映射';

	/// zh-CN: '该成员尚未绑定企业外部身份，请先完成绑定。'
	String get error422IdentityHint => '该成员尚未绑定企业外部身份，请先完成绑定。';

	/// zh-CN: '请求过于频繁'
	String get error429Title => '请求过于频繁';

	/// zh-CN: '已触发企业接口限流，请稍后再试。'
	String get error429Hint => '已触发企业接口限流，请稍后再试。';

	/// zh-CN: '服务内部错误'
	String get error500Title => '服务内部错误';

	/// zh-CN: '服务暂时异常，请稍后重试。'
	String get error500Hint => '服务暂时异常，请稍后重试。';

	/// zh-CN: '服务暂不可用'
	String get error503Title => '服务暂不可用';

	/// zh-CN: '企业服务安全门已关闭，请稍后再试。'
	String get error503Hint => '企业服务安全门已关闭，请稍后再试。';

	/// zh-CN: '当前构建未绑定企业通道'
	String get errorUnboundTitle => '当前构建未绑定企业通道';

	/// zh-CN: '企业治理接口需要应用凭据，客户端不内置该凭据；请由部署方绑定通道后再使用。'
	String get errorUnboundHint => '企业治理接口需要应用凭据，客户端不内置该凭据；请由部署方绑定通道后再使用。';

	/// zh-CN: '网络不可用'
	String get errorNetworkTitle => '网络不可用';

	/// zh-CN: '请检查网络连接后重试。'
	String get errorNetworkHint => '请检查网络连接后重试。';

	/// zh-CN: '未知结果'
	String get errorUnknownTitle => '未知结果';

	/// zh-CN: '服务返回了未识别的结果，请稍后重试。'
	String get errorUnknownHint => '服务返回了未识别的结果，请稍后重试。';
}

// Path: enterpriseOa
class Translations$enterpriseOa$zh_CN {
	Translations$enterpriseOa$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: 'OA'
	String get title => 'OA';

	/// zh-CN: '正在连接企业办公…'
	String get statusLoading => '正在连接企业办公…';

	/// zh-CN: '无法加载 OA'
	String get statusErrorTitle => '无法加载 OA';

	/// zh-CN: '网络异常或服务暂不可用，请稍后重试'
	String get statusErrorHint => '网络异常或服务暂不可用，请稍后重试';

	/// zh-CN: '登录已过期'
	String get statusExpiredTitle => '登录已过期';

	/// zh-CN: 'OA 单点登录凭证已过期或已被使用，请重新登录'
	String get statusExpiredHint => 'OA 单点登录凭证已过期或已被使用，请重新登录';

	/// zh-CN: '已退出 OA'
	String get statusLoggedOutTitle => '已退出 OA';

	/// zh-CN: 'OA 会话已退出，需要重新单点登录'
	String get statusLoggedOutHint => 'OA 会话已退出，需要重新单点登录';

	/// zh-CN: '已阻止离开企业 OA'
	String get statusMismatchTitle => '已阻止离开企业 OA';

	/// zh-CN: '检测到跳转到未授权地址，已停止加载以保护你的账号'
	String get statusMismatchHint => '检测到跳转到未授权地址，已停止加载以保护你的账号';

	/// zh-CN: '已拦截：$host'
	String statusMismatchBlockedHost({required Object host}) => '已拦截：${host}';

	/// zh-CN: 'OA 登录态失效'
	String get statusOa401Title => 'OA 登录态失效';

	/// zh-CN: 'OA 服务返回未授权，请重新单点登录'
	String get statusOa401Hint => 'OA 服务返回未授权，请重新单点登录';

	/// zh-CN: '重试'
	String get actionRetry => '重试';

	/// zh-CN: '重新单点登录'
	String get actionRestartSso => '重新单点登录';

	/// zh-CN: 'OA 页面容器（集成于 W3 波次）'
	String get webviewSlotHint => 'OA 页面容器（集成于 W3 波次）';

	/// zh-CN: 'OA 代发'
	String get badgeDelegated => 'OA 代发';

	/// zh-CN: '企业托管 · 未端到端加密'
	String get markerNoE2ee => '企业托管 · 未端到端加密';

	/// zh-CN: '经 $origin 代发'
	String senderVia({required Object origin}) => '经 ${origin} 代发';

	/// zh-CN: '正在获取单点登录凭证…'
	String get ssoIssuing => '正在获取单点登录凭证…';

	/// zh-CN: '凭证 $seconds 秒内有效，请尽快完成登录'
	String ssoCountdown({required Object seconds}) => '凭证 ${seconds} 秒内有效，请尽快完成登录';

	/// zh-CN: '工作台'
	String get workbenchTitle => '工作台';

	/// zh-CN: '应用'
	String get apps => '应用';

	/// zh-CN: 'OA 身份登录'
	String get inboundTitle => 'OA 身份登录';

	/// zh-CN: '通过 OA 验证身份'
	String get startInbound => '通过 OA 验证身份';

	/// zh-CN: '请选择关联已有 IMBoy 账号，或明确创建新账号。'
	String get accountChoice => '请选择关联已有 IMBoy 账号，或明确创建新账号。';

	/// zh-CN: '确认关联当前账号'
	String get confirmLink => '确认关联当前账号';

	/// zh-CN: '登录已有 IMBoy 账号'
	String get useExistingAccount => '登录已有 IMBoy 账号';

	/// zh-CN: '确认创建新的 IMBoy 账号'
	String get confirmCreate => '确认创建新的 IMBoy 账号';
}

// Path: error
class Translations$error$zh_CN {
	Translations$error$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '需要重启应用'
	String get restartRequired => '需要重启应用';

	/// zh-CN: '请检查你的网络设置。'
	String get pleaseCheckNetwork => '请检查你的网络设置。';

	/// zh-CN: '1.打开手机设置并把Wi-Fi开关保持开启状态。'
	String get networkTroubleshootingStep1 => '1.打开手机设置并把Wi-Fi开关保持开启状态。';

	/// zh-CN: '2.打开手机设置-通用-蜂窝移动网络，并把蜂窝移动数据开关保持开启状态。'
	String get networkTroubleshootingStep2 => '2.打开手机设置-通用-蜂窝移动网络，并把蜂窝移动数据开关保持开启状态。';

	/// zh-CN: '3.如果仍无法连接网络，请检查手机接入的Wi-Fi是否已接入互联网或者咨询网络运营商。'
	String get networkTroubleshootingStep3 => '3.如果仍无法连接网络，请检查手机接入的Wi-Fi是否已接入互联网或者咨询网络运营商。';

	/// zh-CN: '建议检查网络设置。'
	String get suggestCheckNetwork => '建议检查网络设置。';

	/// zh-CN: '加密超时，请检查网络连接后重试'
	String get e2eeErrTimeout => '加密超时，请检查网络连接后重试';

	/// zh-CN: '网络错误，加密失败，消息未发送'
	String get e2eeErrNetwork => '网络错误，加密失败，消息未发送';

	/// zh-CN: '端到端加密策略尚未就绪，请稍后重试'
	String get e2eeErrPolicyNotReady => '端到端加密策略尚未就绪，请稍后重试';

	/// zh-CN: '标题不能为空'
	String get liveRoomTitleRequired => '标题不能为空';
}

// Path: group
class Translations$group$zh_CN {
	Translations$group$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '与身边的朋友进入同一个群聊'
	String get enterSameGroup => '与身边的朋友进入同一个群聊';

	/// zh-CN: '进入该群'
	String get enterTheGroup => '进入该群';

	/// zh-CN: '我在本群的昵称'
	String get groupAlias => '我在本群的昵称';

	/// zh-CN: '群相册'
	String get groupAlbum => '群相册';

	/// zh-CN: '解散群聊'
	String get groupDissolve => '解散群聊';

	/// zh-CN: '退出群聊'
	String get groupLeave => '退出群聊';

	/// zh-CN: '群成员'
	String get groupMembers => '群成员';

	/// zh-CN: '群聊名称'
	String get groupName => '群聊名称';

	/// zh-CN: '我和他的共同群聊'
	String get mutualGroupsWithHer => '我和他的共同群聊';

	/// zh-CN: '群主'
	String get groupOwner => '群主';

	/// zh-CN: '管理员'
	String get groupAdmin => '管理员';

	/// zh-CN: '嘉宾'
	String get groupGuest => '嘉宾';

	/// zh-CN: '群聊信息'
	String get groupInfo => '群聊信息';

	/// zh-CN: '成员'
	String get groupMemberRoleLabel => '成员';

	/// zh-CN: '暂无$roleName'
	String noMemberWithRole({required Object roleName}) => '暂无${roleName}';

	/// zh-CN: '更多操作'
	String get moreActions => '更多操作';

	/// zh-CN: '点击联系人添加为群成员'
	String get touchContactAddMember => '点击联系人添加为群成员';

	/// zh-CN: '群聊已创建'
	String get groupCreated => '群聊已创建';

	/// zh-CN: '群聊创建成功，邀请你完善群信息或直接进入群聊'
	String get groupCreatedSuccess => '群聊创建成功，邀请你完善群信息或直接进入群聊';

	/// zh-CN: '进入群聊'
	String get enterGroupChat => '进入群聊';

	/// zh-CN: '完善群信息'
	String get perfectionGroupInfo => '完善群信息';

	/// zh-CN: '设为管理员'
	String get setAdmin => '设为管理员';

	/// zh-CN: '选择群聊'
	String get selectGroup => '选择群聊';

	/// zh-CN: '确定要解散本群吗？'
	String get sureToDissolveGroup => '确定要解散本群吗？';

	/// zh-CN: '确定要退出本群吗？'
	String get sureToLeaveGroup => '确定要退出本群吗？';

	/// zh-CN: '请输入相册名称'
	String get groupAlbumNameHint => '请输入相册名称';

	/// zh-CN: '重命名相册'
	String get groupAlbumRenameTitle => '重命名相册';

	/// zh-CN: '相册名称已更新'
	String get groupAlbumRenamed => '相册名称已更新';

	/// zh-CN: '未命名相册'
	String get groupAlbumUnnamed => '未命名相册';

	/// zh-CN: '$count 张图片'
	String groupAlbumPhotoCount({required Object count}) => '${count} 张图片';

	/// zh-CN: '图片ID缺失，无法查看详情'
	String get groupAlbumPhotoIdMissing => '图片ID缺失，无法查看详情';

	/// zh-CN: '相册图片'
	String get groupAlbumPhotoListTitle => '相册图片';

	/// zh-CN: '已选择 $count 项'
	String groupAlbumPhotoSelectedCount({required Object count}) => '已选择 ${count} 项';

	/// zh-CN: '暂无图片'
	String get groupAlbumPhotoEmpty => '暂无图片';

	/// zh-CN: '图片地址缺失，无法打开'
	String get groupAlbumPhotoUrlMissing => '图片地址缺失，无法打开';

	/// zh-CN: '图片地址无效'
	String get groupAlbumPhotoUrlInvalid => '图片地址无效';

	/// zh-CN: '图片详情'
	String get groupAlbumPhotoDetailTitle => '图片详情';

	/// zh-CN: '设为封面'
	String get groupAlbumPhotoSetCover => '设为封面';

	/// zh-CN: '上一张'
	String get groupAlbumPhotoPrev => '上一张';

	/// zh-CN: '点赞数'
	String get groupAlbumPhotoLikeCount => '点赞数';

	/// zh-CN: '评论数'
	String get groupAlbumPhotoCommentCount => '评论数';

	/// zh-CN: '我的点赞'
	String get groupAlbumPhotoMyLike => '我的点赞';

	/// zh-CN: '图片ID'
	String get groupAlbumPhotoIdLabel => '图片ID';

	/// zh-CN: 'E2EE 密钥管理'
	String get e2eeKeyManagement => 'E2EE 密钥管理';

	/// zh-CN: '备份、恢复和管理端到端加密密钥'
	String get e2eeKeyManagementSubtitle => '备份、恢复和管理端到端加密密钥';

	/// zh-CN: '端到端加密'
	String get e2eeTitle => '端到端加密';

	/// zh-CN: '开启后，本群消息将端到端加密，仅群成员设备可解密。此操作不可撤销，确定开启？'
	String get e2eeEnableConfirm => '开启后，本群消息将端到端加密，仅群成员设备可解密。此操作不可撤销，确定开启？';

	/// zh-CN: '转让后退出'
	String get transferAndLeave => '转让后退出';

	/// zh-CN: '转让后你将退出本群并失去群主权限，确定继续吗？'
	String get sureToTransferAndLeave => '转让后你将退出本群并失去群主权限，确定继续吗？';

	/// zh-CN: '已转让群主，但退出失败，请重试退出'
	String get transferredButLeaveFailed => '已转让群主，但退出失败，请重试退出';

	/// zh-CN: '暂无可转让的成员'
	String get noEligibleSuccessor => '暂无可转让的成员';
}

// Path: groupCategory
class Translations$groupCategory$zh_CN {
	Translations$groupCategory$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '群分组'
	String get title => '群分组';

	/// zh-CN: '创建分组'
	String get createCategory => '创建分组';

	/// zh-CN: '分组名称'
	String get categoryName => '分组名称';

	/// zh-CN: '暂无分组'
	String get noCategory => '暂无分组';

	/// zh-CN: '删除分组'
	String get deleteCategory => '删除分组';

	/// zh-CN: '确定要删除该分组吗？群聊不会被删除。'
	String get deleteCategoryConfirm => '确定要删除该分组吗？群聊不会被删除。';

	/// zh-CN: '分组已删除'
	String get categoryDeleted => '分组已删除';

	/// zh-CN: '重命名分组'
	String get renameCategory => '重命名分组';

	/// zh-CN: '分组重命名成功'
	String get categoryRenamed => '分组重命名成功';

	/// zh-CN: '重命名失败，请重试'
	String get renameFailed => '重命名失败，请重试';

	/// zh-CN: '删除失败，请重试'
	String get deleteFailed => '删除失败，请重试';

	/// zh-CN: '该分组下的群聊可以在群组列表中通过「移入分组」进行管理'
	String get categoryDetailTip => '该分组下的群聊可以在群组列表中通过「移入分组」进行管理';
}

// Path: groupDiscovery
class Translations$groupDiscovery$zh_CN {
	Translations$groupDiscovery$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '发现群组'
	String get title => '发现群组';

	/// zh-CN: '搜索公开群'
	String get searchHint => '搜索公开群';

	/// zh-CN: '全部'
	String get allCategories => '全部';

	/// zh-CN: '热门'
	String get sortPopular => '热门';

	/// zh-CN: '最新'
	String get sortNewest => '最新';

	/// zh-CN: '暂无公开群，稍后再来看看'
	String get emptyTitle => '暂无公开群，稍后再来看看';

	/// zh-CN: '无匹配的公开群'
	String get searchEmpty => '无匹配的公开群';
}

// Path: groupList
class Translations$groupList$zh_CN {
	Translations$groupList$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '全部'
	String get attrAll => '全部';

	/// zh-CN: '我创建'
	String get attrOwner => '我创建';

	/// zh-CN: '我管理'
	String get attrManager => '我管理';

	/// zh-CN: '我加入'
	String get attrJoin => '我加入';

	/// zh-CN: '刷新'
	String get refresh => '刷新';
}

// Path: groupSchedule
class Translations$groupSchedule$zh_CN {
	Translations$groupSchedule$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '群日程'
	String get title => '群日程';

	/// zh-CN: '创建日程'
	String get createSchedule => '创建日程';

	/// zh-CN: '日程标题'
	String get scheduleTitle => '日程标题';

	/// zh-CN: '选择日期'
	String get selectDate => '选择日期';

	/// zh-CN: '选择时间'
	String get selectTime => '选择时间';

	/// zh-CN: '地点'
	String get location => '地点';

	/// zh-CN: '暂无日程'
	String get noSchedule => '暂无日程';

	/// zh-CN: '开始时间'
	String get startTime => '开始时间';

	/// zh-CN: '结束时间'
	String get endTime => '结束时间';

	/// zh-CN: '参与人数'
	String get participants => '参与人数';

	/// zh-CN: '已取消'
	String get statusCancelled => '已取消';

	/// zh-CN: '进行中'
	String get statusInProgress => '进行中';

	/// zh-CN: '未开始'
	String get statusNotStarted => '未开始';

	/// zh-CN: '已结束'
	String get statusEnded => '已结束';

	/// zh-CN: '日程已取消'
	String get cancelSuccess => '日程已取消';

	/// zh-CN: '取消失败，请稍后重试'
	String get cancelFailed => '取消失败，请稍后重试';

	/// zh-CN: '确认参加'
	String get confirmAttend => '确认参加';

	/// zh-CN: '不参加'
	String get declineAttend => '不参加';

	/// zh-CN: '取消日程'
	String get cancelSchedule => '取消日程';

	/// zh-CN: '日程ID缺失，无法查看详情'
	String get scheduleIdMissing => '日程ID缺失，无法查看详情';

	/// zh-CN: '未命名日程'
	String get untitledSchedule => '未命名日程';

	/// zh-CN: '查看详情并确认参加'
	String get cardViewAndAttend => '查看详情并确认参加';

	/// zh-CN: '查看详情'
	String get cardViewDetail => '查看详情';

	/// zh-CN: '发起人'
	String get organizer => '发起人';

	/// zh-CN: '已参加'
	String get participantAttending => '已参加';

	/// zh-CN: '已拒绝'
	String get participantDeclined => '已拒绝';

	/// zh-CN: '待回应'
	String get participantPending => '待回应';

	/// zh-CN: '$attending/$total 人参加'
	String attendSummary({required Object attending, required Object total}) => '${attending}/${total} 人参加';

	/// zh-CN: '开始前 $minutes 分钟提醒'
	String remindBefore({required Object minutes}) => '开始前 ${minutes} 分钟提醒';

	/// zh-CN: '预计 $minutes 分钟'
	String duration({required Object minutes}) => '预计 ${minutes} 分钟';

	/// zh-CN: '今天'
	String get hintToday => '今天';

	/// zh-CN: '明天'
	String get hintTomorrow => '明天';

	/// zh-CN: '$hint $time 开始'
	String startsHint({required Object hint, required Object time}) => '${hint} ${time} 开始';

	/// zh-CN: '今天'
	String get sectionToday => '今天';

	/// zh-CN: '本周'
	String get sectionThisWeek => '本周';

	/// zh-CN: '更晚'
	String get sectionLater => '更晚';

	/// zh-CN: '全部参与人（$count）'
	String allParticipants({required Object count}) => '全部参与人（${count}）';

	/// zh-CN: '收起'
	String get collapseParticipants => '收起';
}

// Path: groupTag
class Translations$groupTag$zh_CN {
	Translations$groupTag$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '群标签'
	String get title => '群标签';

	/// zh-CN: '添加标签'
	String get addTag => '添加标签';

	/// zh-CN: '标签名称'
	String get tagName => '标签名称';

	/// zh-CN: '暂无标签'
	String get noTag => '暂无标签';

	/// zh-CN: '移除标签'
	String get removeTitle => '移除标签';

	/// zh-CN: '确定要移除这个标签吗？'
	String get removeConfirm => '确定要移除这个标签吗？';
}

// Path: groupTask
class Translations$groupTask$zh_CN {
	Translations$groupTask$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '待办'
	String get title => '待办';

	/// zh-CN: '创建待办'
	String get createTask => '创建待办';

	/// zh-CN: '编辑待办'
	String get editTask => '编辑待办';

	/// zh-CN: '待办标题'
	String get taskTitle => '待办标题';

	/// zh-CN: '待办描述'
	String get taskDescription => '待办描述';

	/// zh-CN: '截止时间'
	String get deadline => '截止时间';

	/// zh-CN: '无截止时间'
	String get noDeadline => '无截止时间';

	/// zh-CN: '暂无待办'
	String get noTask => '暂无待办';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '待完成'
	String get pending => '待完成';

	/// zh-CN: '已完成'
	String get completed => '已完成';

	/// zh-CN: '待办已提交'
	String get taskSubmitted => '待办已提交';

	/// zh-CN: '提交待办'
	String get submitTask => '提交待办';

	/// zh-CN: '已过期'
	String get overdue => '已过期';

	/// zh-CN: '$days 天后截止'
	String daysLeft({required Object days}) => '${days} 天后截止';

	/// zh-CN: '$hours 小时后截止'
	String hoursLeft({required Object hours}) => '${hours} 小时后截止';

	/// zh-CN: '即将截止'
	String get dueSoon => '即将截止';

	/// zh-CN: '提交失败，请稍后重试'
	String get submitFailed => '提交失败，请稍后重试';

	/// zh-CN: '待审核'
	String get pendingReview => '待审核';

	/// zh-CN: '待办ID缺失，无法查看详情'
	String get taskIdMissing => '待办ID缺失，无法查看详情';

	/// zh-CN: '待办ID缺失，无法提交'
	String get taskIdMissingSubmit => '待办ID缺失，无法提交';

	/// zh-CN: '$time 发布'
	String publishedAt({required Object time}) => '${time} 发布';

	/// zh-CN: '完成于 $time'
	String completedAt({required Object time}) => '完成于 ${time}';
}

// Path: groupVote
class Translations$groupVote$zh_CN {
	Translations$groupVote$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '群投票'
	String get title => '群投票';

	/// zh-CN: '创建投票'
	String get createVote => '创建投票';

	/// zh-CN: '投票标题'
	String get voteTitle => '投票标题';

	/// zh-CN: '暂无投票'
	String get noVote => '暂无投票';

	/// zh-CN: '投票已结束'
	String get voteEnded => '投票已结束';

	/// zh-CN: '共 $count 票'
	String totalVotes({required Object count}) => '共 ${count} 票';

	/// zh-CN: '投票成功'
	String get voteSuccess => '投票成功';

	/// zh-CN: '已取消投票'
	String get cancelVoteSuccess => '已取消投票';

	/// zh-CN: '每行一个选项'
	String get eachOptionPerLine => '每行一个选项';

	/// zh-CN: '进行中'
	String get statusInProgress => '进行中';

	/// zh-CN: '更新投票'
	String get updateVote => '更新投票';

	/// zh-CN: '取消我的投票'
	String get cancelMyVote => '取消我的投票';

	/// zh-CN: '投票ID缺失，无法查看详情'
	String get voteIdMissing => '投票ID缺失，无法查看详情';

	/// zh-CN: '参与人数: $count'
	String participantCount({required Object count}) => '参与人数: ${count}';

	/// zh-CN: '单选'
	String get singleChoice => '单选';

	/// zh-CN: '多选'
	String get multipleChoice => '多选';

	/// zh-CN: '结束投票'
	String get endVote => '结束投票';

	/// zh-CN: '已投票'
	String get alreadyVoted => '已投票';

	/// zh-CN: '已选 $count 项'
	String selectedCount({required Object count}) => '已选 ${count} 项';

	/// zh-CN: '$count 票'
	String voteCount({required Object count}) => '${count} 票';
}

// Path: main
class Translations$main$zh_CN {
	Translations$main$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '总资产'
	String get totalAssets => '总资产';

	/// zh-CN: '照片'
	String get album => '照片';

	/// zh-CN: '应用大小'
	String get appSize => '应用大小';

	/// zh-CN: '阿拉伯语（沙特阿拉伯）'
	String get arSa => '阿拉伯语（沙特阿拉伯）';

	/// zh-CN: '音频'
	String get audio => '音频';

	/// zh-CN: '已识别二维码'
	String get barcodeFound => '已识别二维码';

	/// zh-CN: '千帆机器人'
	String get botQianFan => '千帆机器人';

	/// zh-CN: 'WHIP 推流地址'
	String get liveRoomWhipLabel => 'WHIP 推流地址';

	/// zh-CN: 'WHEP 拉流地址'
	String get liveRoomWhepLabel => 'WHEP 拉流地址';

	/// zh-CN: '缓存'
	String get cache => '缓存';

	/// zh-CN: '拍摄'
	String get camera => '拍摄';

	/// zh-CN: '修改$param'
	String changeParam({required Object param}) => '修改${param}';

	/// zh-CN: '从相册选择'
	String get chooseFromAlbum => '从相册选择';

	/// zh-CN: '清理'
	String get clean => '清理';

	/// zh-CN: '验证码已发送到$param'
	String codeSentToParam({required Object param}) => '验证码已发送到${param}';

	/// zh-CN: '已收藏'
	String get collected => '已收藏';

	/// zh-CN: '已完结'
	String get completed => '已完结';

	/// zh-CN: '已复制'
	String get copied => '已复制';

	/// zh-CN: '深色模式'
	String get darkModel => '深色模式';

	/// zh-CN: '德语（德国）'
	String get deDd => '德语（德国）';

	/// zh-CN: '禁用'
	String get disable => '禁用';

	/// zh-CN: '美国英语'
	String get enUs => '美国英语';

	/// zh-CN: '启用'
	String get enable => '启用';

	/// zh-CN: '已过期'
	String get expired => '已过期';

	/// zh-CN: '密钥轮换进行中，请稍后重试'
	String get e2eeCollectRotating => '密钥轮换进行中，请稍后重试';

	/// zh-CN: '服务器暂不支持端到端加密收藏，请先升级服务端'
	String get e2eeCollectUnsupported => '服务器暂不支持端到端加密收藏，请先升级服务端';

	/// zh-CN: '收藏'
	String get favorites => '收藏';

	/// zh-CN: '女'
	String get female => '女';

	/// zh-CN: '跟随系统'
	String get followSystem => '跟随系统';

	/// zh-CN: '法语（法国）'
	String get frFr => '法语（法国）';

	/// zh-CN: '来自'
	String get from => '来自';

	/// zh-CN: '很棒'
	String get good => '很棒';

	/// zh-CN: '挂断'
	String get hangup => '挂断';

	/// zh-CN: '我是'
	String get iAm => '我是';

	/// zh-CN: '意大利语（意大利）'
	String get itIt => '意大利语（意大利）';

	/// zh-CN: '日语（日本）'
	String get jaJp => '日语（日本）';

	/// zh-CN: '保密'
	String get keepSecret => '保密';

	/// zh-CN: '最近活跃时间'
	String get lastActiveTime => '最近活跃时间';

	/// zh-CN: '隐藏在线状态'
	String get lastSeenHide => '隐藏在线状态';

	/// zh-CN: '从未上线'
	String get lastSeenNever => '从未上线';

	/// zh-CN: '$param周前'
	String lastSeenWeeksAgo({required Object param}) => '${param}周前';

	/// zh-CN: '上次在线 $param'
	String lastSeenExactTime({required Object param}) => '上次在线 ${param}';

	/// zh-CN: '《软件许可及服务协议》'
	String get licenseAgreement => '《软件许可及服务协议》';

	/// zh-CN: '扩音器'
	String get loudspeaker => '扩音器';

	/// zh-CN: '让自己不可见'
	String get makeYourselfInvisible => '让自己不可见';

	/// zh-CN: '让自己可见'
	String get makeYourselfVisible => '让自己可见';

	/// zh-CN: '男'
	String get male => '男';

	/// zh-CN: '管理'
	String get manage => '管理';

	/// zh-CN: '收藏'
	String get markStar => '收藏';

	/// zh-CN: '多选'
	String get multiSelect => '多选';

	/// zh-CN: '我的收藏'
	String get myFavorites => '我的收藏';

	/// zh-CN: '我的直播'
	String get myLive => '我的直播';

	/// zh-CN: '名称'
	String get name => '名称';

	/// zh-CN: '$param个'
	String numUnit({required Object param}) => '${param}个';

	/// zh-CN: '在浏览器中打开'
	String get openInBrowser => '在浏览器中打开';

	/// zh-CN: '或者'
	String get or => '或者';

	/// zh-CN: '对方'
	String get otherParty => '对方';

	/// zh-CN: '包大小'
	String get packageSize => '包大小';

	/// zh-CN: '对方已挂断'
	String get peerHasHungUp => '对方已挂断';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '请输入$param'
	String pleaseInputParam({required Object param}) => '请输入${param}';

	/// zh-CN: '请选择'
	String get pleaseSelect => '请选择';

	/// zh-CN: '引用'
	String get quote => '引用';

	/// zh-CN: '最近使用'
	String get recentlyUsed => '最近使用';

	/// zh-CN: '松开结束'
	String get releaseEnd => '松开结束';

	/// zh-CN: '成员详情'
	String get memberDetail => '成员详情';

	/// zh-CN: '已回复'
	String get replied => '已回复';

	/// zh-CN: '已响铃...'
	String get ringing => '已响铃...';

	/// zh-CN: '俄罗斯俄语'
	String get ruRu => '俄罗斯俄语';

	/// zh-CN: '已选 ($count)'
	String selectedCount({required Object count}) => '已选 (${count})';

	/// zh-CN: '已选'
	String get selected => '已选';

	/// zh-CN: '已发送'
	String get sent => '已发送';

	/// zh-CN: '我发送的'
	String get sentByMe => '我发送的';

	/// zh-CN: '设置$param'
	String setParam({required Object param}) => '设置${param}';

	/// zh-CN: '设置'
	String get setting => '设置';

	/// zh-CN: '已经有账号了？'
	String get siginQ => '已经有账号了？';

	/// zh-CN: '来源'
	String get source => '来源';

	/// zh-CN: '说话时间太短'
	String get speakingTooShort => '说话时间太短';

	/// zh-CN: '速度'
	String get speed => '速度';

	/// zh-CN: '还需'
	String get stillNeeded => '还需';

	/// zh-CN: '存储空间'
	String get storageSpace => '存储空间';

	/// zh-CN: '文本'
	String get text => '文本';

	/// zh-CN: '本周'
	String get thisWeek => '本周';

	/// zh-CN: '我的'
	String get titleMine => '我的';

	/// zh-CN: '太差了'
	String get tooBad => '太差了';

	/// zh-CN: '想再试一次吗？'
	String get tryAgainQ => '想再试一次吗？';

	/// zh-CN: '类型'
	String get type => '类型';

	/// zh-CN: '未应答'
	String get unanswered => '未应答';

	/// zh-CN: '未命名'
	String get unnamed => '未命名';

	/// zh-CN: '已使用空间'
	String get usedSpace => '已使用空间';

	/// zh-CN: '你'
	String get you => '你';

	/// zh-CN: '简体中文'
	String get zhCn => '简体中文';

	/// zh-CN: '繁体中文'
	String get zhHant => '繁体中文';

	/// zh-CN: '已绑定'
	String get bound => '已绑定';

	/// zh-CN: '正确'
	String get correct => '正确';

	/// zh-CN: '待输入'
	String get pendingInput => '待输入';

	/// zh-CN: '长度检查'
	String get lengthCheck => '长度检查';

	/// zh-CN: '错误报告'
	String get bugReport => '错误报告';

	/// zh-CN: '删除中...'
	String get deleting => '删除中...';

	/// zh-CN: '发布'
	String get publish => '发布';

	/// zh-CN: '隐私政策'
	String get privacyPolicy => '隐私政策';

	/// zh-CN: '服务条款'
	String get termsOfService => '服务条款';

	/// zh-CN: '加载中'
	String get saving => _root.common.loading;

	/// zh-CN: '系统默认'
	String get systemDefault => '系统默认';

	/// zh-CN: '渐变蓝'
	String get gradientBlue => '渐变蓝';

	/// zh-CN: '渐变紫'
	String get gradientPurple => '渐变紫';

	/// zh-CN: '已复制到剪贴板'
	String get copiedToClipboard => '已复制到剪贴板';

	/// zh-CN: '销毁时间'
	String get destroyTime => '销毁时间';

	/// zh-CN: '预览效果'
	String get previewEffect => '预览效果';

	/// zh-CN: '这是标题文本'
	String get thisIsTitleText => '这是标题文本';

	/// zh-CN: '这是辅助说明文字'
	String get thisIsAuxiliaryText => '这是辅助说明文字';

	/// zh-CN: '待完善'
	String get toBeCompleted => '待完善';

	/// zh-CN: '可选择'
	String get availableCount => '可选择';

	/// zh-CN: '最常用'
	String get mostUsed => '最常用';

	/// zh-CN: '学校'
	String get school => '学校';

	/// zh-CN: '兴趣爱好'
	String get hobbiesAndInterests => '兴趣爱好';

	/// zh-CN: '兴趣爱好'
	String get interests => '兴趣爱好';

	/// zh-CN: '从相册选择'
	String get selectFromAlbum => '从相册选择';

	/// zh-CN: '音量增加'
	String get volumeUp => '音量增加';

	/// zh-CN: '音量减少'
	String get volumeDown => '音量减少';

	/// zh-CN: '快退 $seconds秒'
	String fastRewind({required Object seconds}) => '快退 ${seconds}秒';

	/// zh-CN: '请重试'
	String get pleaseTryAgain => '请重试';

	/// zh-CN: '保密'
	String get secret => '保密';

	/// zh-CN: '拍照'
	String get takePhoto => '拍照';

	/// zh-CN: '正在删除中，请稍候...'
	String get deletingInProgressPleaseWait => '正在删除中，请稍候...';

	/// zh-CN: '收藏中...'
	String get collecting => '收藏中...';

	/// zh-CN: '用户'
	String get user => '用户';

	/// zh-CN: '推荐'
	String get recommended => '推荐';

	/// zh-CN: '更大'
	String get larger => '更大';

	/// zh-CN: '填入'
	String get fillIn => '填入';

	/// zh-CN: '消息受合规密钥保护'
	String get msgProtectedByComplianceKey => '消息受合规密钥保护';

	/// zh-CN: '邀请人: $uid'
	String inviterLabel({required Object uid}) => '邀请人: ${uid}';

	/// zh-CN: '被邀请人: $uid'
	String inviteeLabel({required Object uid}) => '被邀请人: ${uid}';

	/// zh-CN: '我发出的'
	String get mySentTab => '我发出的';

	/// zh-CN: '拒绝'
	String get reject => '拒绝';

	/// zh-CN: '我的订单'
	String get myOrders => '我的订单';

	/// zh-CN: '购买后可解锁频道历史消息与后续更新内容。'
	String get purchaseUnlockHint => '购买后可解锁频道历史消息与后续更新内容。';

	/// zh-CN: '支付中...'
	String get payingDots => '支付中...';

	/// zh-CN: '立即购买并解锁'
	String get purchaseAndUnlock => '立即购买并解锁';

	/// zh-CN: '订单详情'
	String get orderDetail => '订单详情';

	/// zh-CN: '金额: $currency $amount'
	String orderAmountLabel({required Object currency, required Object amount}) => '金额: ${currency} ${amount}';

	/// zh-CN: '价格：$currency $amount'
	String channelPriceLabel({required Object currency, required Object amount}) => '价格：${currency} ${amount}';

	/// zh-CN: '端到端加密密钥管理'
	String get e2eeKeyRecoveryTitle => '端到端加密密钥管理';

	/// zh-CN: '密钥恢复方法'
	String get e2eeRecoveryMethods => '密钥恢复方法';

	/// zh-CN: '危险操作'
	String get e2eeDangerousOps => '危险操作';

	/// zh-CN: '密钥 ID'
	String get e2eeKeyIdLabel => '密钥 ID';

	/// zh-CN: '• 此操作不可撤销'
	String get e2eeWarnIrreversible => '• 此操作不可撤销';

	/// zh-CN: '• 需要从备份恢复或生成新密钥'
	String get e2eeWarnNeedRestoreOrNew => '• 需要从备份恢复或生成新密钥';

	/// zh-CN: '我知道了'
	String get gotIt => '我知道了';

	/// zh-CN: '登录中...'
	String get webQRLoggingIn => '登录中...';

	/// zh-CN: '二维码已过期'
	String get webQRExpired => '二维码已过期';

	/// zh-CN: '刷新二维码'
	String get webQRRefresh => '刷新二维码';

	/// zh-CN: '使用 QR 码登录'
	String get webSwitchToQR => '使用 QR 码登录';

	/// zh-CN: '端到端加密失败，消息未发送'
	String get e2eeErrDefault => '端到端加密失败，消息未发送';

	/// zh-CN: '有成员的设备尚未完成安全设置，消息未发送；请稍后重试'
	String get e2eeErrPeerDeviceNotReady => '有成员的设备尚未完成安全设置，消息未发送；请稍后重试';

	/// zh-CN: '合规审计密钥已变更，消息未发送，请确认轮换后重试'
	String get e2eeErrComplianceChanged => '合规审计密钥已变更，消息未发送，请确认轮换后重试';

	/// zh-CN: '合规密钥暂不可用，消息未发送，请稍后重试'
	String get e2eeErrComplianceUnavailable => '合规密钥暂不可用，消息未发送，请稍后重试';

	/// zh-CN: '合规密钥已过期，请联系管理员'
	String get e2eeErrComplianceExpired => '合规密钥已过期，请联系管理员';

	/// zh-CN: '合规密钥轮换已确认，可重新发送消息'
	String get complianceKeyRotationConfirmed => '合规密钥轮换已确认，可重新发送消息';

	/// zh-CN: '没有待确认的密钥变更'
	String get complianceKeyRotationNoPending => '没有待确认的密钥变更';

	/// zh-CN: '当前设备未完成安全初始化，请退出重新登录后重试'
	String get e2eeErrDeviceNotReady => '当前设备未完成安全初始化，请退出重新登录后重试';

	/// zh-CN: '群会话密钥生成失败，请稍后重试'
	String get e2eeErrSessionExportFailed => '群会话密钥生成失败，请稍后重试';

	/// zh-CN: '加密协议配置异常，请更新应用后重试'
	String get e2eeErrProtocolMismatch => '加密协议配置异常，请更新应用后重试';

	/// zh-CN: '对方设备不支持要求的加密套件，消息未发送；请让对方更新应用后重试'
	String get e2eeErrPeerSuiteUnsupported => '对方设备不支持要求的加密套件，消息未发送；请让对方更新应用后重试';

	/// zh-CN: '合规审计密钥'
	String get complianceKeyInfoTitle => '合规审计密钥';

	/// zh-CN: '服务端下发的公钥'
	String get complianceKeyInfoServerKey => '服务端下发的公钥';

	/// zh-CN: '本地固定（TOFU）'
	String get complianceKeyInfoLocalPin => '本地固定（TOFU）';

	/// zh-CN: '密钥 ID'
	String get complianceKeyInfoKeyId => '密钥 ID';

	/// zh-CN: '算法'
	String get complianceKeyInfoAlgorithm => '算法';

	/// zh-CN: '公钥指纹'
	String get complianceKeyInfoFingerprint => '公钥指纹';

	/// zh-CN: '获取时间'
	String get complianceKeyInfoFetchedAt => '获取时间';

	/// zh-CN: '固定时间'
	String get complianceKeyInfoPinnedAt => '固定时间';

	/// zh-CN: '尚未固定（下次获取时自动固定）'
	String get complianceKeyInfoPinnedNone => '尚未固定（下次获取时自动固定）';

	/// zh-CN: '⚠️ 服务端下发的合规公钥与本地固定不一致！若这不是管理员有意的轮换，请立即联系管理员，并停止发送加密消息。'
	String get complianceKeyInfoChangedWarning => '⚠️ 服务端下发的合规公钥与本地固定不一致！若这不是管理员有意的轮换，请立即联系管理员，并停止发送加密消息。';

	/// zh-CN: '获取失败，请检查网络后重试'
	String get complianceKeyInfoRefreshFailed => '获取失败，请检查网络后重试';

	/// zh-CN: '合规审计密钥用于 compliance_e2ee 模式的双重加密。若上方指纹与管理员公布的指纹不一致，说明服务端可能被篡改。'
	String get complianceKeyInfoHint => '合规审计密钥用于 compliance_e2ee 模式的双重加密。若上方指纹与管理员公布的指纹不一致，说明服务端可能被篡改。';

	/// zh-CN: '安全码验证'
	String get safetyNumberTitle => '安全码验证';

	/// zh-CN: '请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。'
	String get safetyNumberHint => '请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。';

	/// zh-CN: '复制'
	String get safetyNumberCopy => '复制';

	/// zh-CN: '已复制'
	String get safetyNumberCopied => '已复制';

	/// zh-CN: '标记为已验证'
	String get safetyNumberMarkVerified => '标记为已验证';

	/// zh-CN: '已标记为已验证'
	String get safetyNumberMarkedVerified => '已标记为已验证';

	/// zh-CN: '对方设备'
	String get safetyNumberPeerDevice => '对方设备';

	/// zh-CN: '对方尚未启用端到端加密'
	String get safetyNumberNoDevices => '对方尚未启用端到端加密';

	/// zh-CN: '获取安全码失败，请稍后重试'
	String get safetyNumberVerifyFailed => '获取安全码失败，请稍后重试';

	/// zh-CN: '正在上报验证结果...'
	String get safetyNumberReporting => '正在上报验证结果...';

	/// zh-CN: '服务端拒绝了该验证事件（签名/时效不符），未标记'
	String get safetyNumberReportRejected => '服务端拒绝了该验证事件（签名/时效不符），未标记';

	/// zh-CN: '无法获取设备信息，未上报'
	String get safetyNumberReportUnavailable => '无法获取设备信息，未上报';

	/// zh-CN: '✓ 已验证'
	String get safetyNumberVerified => '✓ 已验证';

	/// zh-CN: '未验证'
	String get safetyNumberNotVerified => '未验证';

	/// zh-CN: '$count 台设备'
	String safetyNumberDeviceCount({required Object count}) => '${count} 台设备';

	/// zh-CN: '直播间标题'
	String get liveRoomTitleLabel => '直播间标题';

	/// zh-CN: '请输入直播间标题'
	String get liveRoomTitleHint => '请输入直播间标题';

	/// zh-CN: '浅色模式'
	String get lightModel => '浅色模式';

	/// zh-CN: '当前部署未配置合规审计密钥'
	String get complianceKeyNotConfigured => '当前部署未配置合规审计密钥';

	/// zh-CN: '我的内容'
	String get mineContent => '我的内容';

	/// zh-CN: '常用入口'
	String get mineCommonEntries => '常用入口';

	/// zh-CN: '管理与支持'
	String get mineManagementSupport => '管理与支持';

	/// zh-CN: '设置与支持'
	String get mineSettingsSupport => '设置与支持';

	/// zh-CN: '管理占用'
	String get mineStorageUsage => '管理占用';
}

// Path: mention
class Translations$mention$zh_CN {
	Translations$mention$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '所有人'
	String get mentionAll => '所有人';

	/// zh-CN: '通知所有群成员'
	String get mentionAllHint => '通知所有群成员';

	/// zh-CN: '没有匹配的成员'
	String get noMatchedMember => '没有匹配的成员';

	/// zh-CN: '@提及'
	String get title => '@提及';

	/// zh-CN: '暂无@提及'
	String get noMention => '暂无@提及';

	/// zh-CN: '全部已读'
	String get allRead => '全部已读';

	/// zh-CN: '仅管理员可以 @所有人'
	String get mentionAllDenied => '仅管理员可以 @所有人';

	/// zh-CN: '消息定位信息缺失，无法跳转'
	String get navInfoMissing => '消息定位信息缺失，无法跳转';

	/// zh-CN: '@提及成员'
	String get pickButtonTooltip => '@提及成员';
}

// Path: momentFriendPicker
class Translations$momentFriendPicker$zh_CN {
	Translations$momentFriendPicker$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '确定'
	String get confirm => '确定';

	/// zh-CN: '确定($count)'
	String confirmWithCount({required Object count}) => '确定(${count})';

	/// zh-CN: '已选 $count 人'
	String selectedCount({required Object count}) => '已选 ${count} 人';

	/// zh-CN: '暂无好友'
	String get emptyFriends => '暂无好友';

	/// zh-CN: '标签加载失败'
	String get tagLoadFailed => '标签加载失败';

	/// zh-CN: '搜索好友'
	String get searchHint => '搜索好友';
}

// Path: momentNotify
class Translations$momentNotify$zh_CN {
	Translations$momentNotify$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '互动消息'
	String get title => '互动消息';

	/// zh-CN: '暂无新消息'
	String get emptyTitle => '暂无新消息';

	/// zh-CN: '好友点赞或评论你的朋友圈后，会出现在这里'
	String get emptyHint => '好友点赞或评论你的朋友圈后，会出现在这里';

	/// zh-CN: '赞了你的朋友圈'
	String get actionLike => '赞了你的朋友圈';

	/// zh-CN: '评论了你'
	String get actionComment => '评论了你';

	/// zh-CN: '全部已读'
	String get markAllRead => '全部已读';

	/// zh-CN: '清空全部'
	String get clearAll => '清空全部';

	/// zh-CN: '清空所有通知？'
	String get clearConfirmTitle => '清空所有通知？';

	/// zh-CN: '清空后无法恢复'
	String get clearConfirmMessage => '清空后无法恢复';

	/// zh-CN: '确定'
	String get confirm => '确定';

	/// zh-CN: '取消'
	String get cancel => '取消';

	/// zh-CN: '删除'
	String get delete => '删除';

	/// zh-CN: '加载失败，请稍后重试'
	String get loadFailed => '加载失败，请稍后重试';
}

// Path: organization
class Translations$organization$zh_CN {
	Translations$organization$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$organization$common$zh_CN common = Translations$organization$common$zh_CN.internal(_root);
	late final Translations$organization$home$zh_CN home = Translations$organization$home$zh_CN.internal(_root);
	late final Translations$organization$detail$zh_CN detail = Translations$organization$detail$zh_CN.internal(_root);
	late final Translations$organization$members$zh_CN members = Translations$organization$members$zh_CN.internal(_root);
	late final Translations$organization$invitations$zh_CN invitations = Translations$organization$invitations$zh_CN.internal(_root);
	late final Translations$organization$departments$zh_CN departments = Translations$organization$departments$zh_CN.internal(_root);
	late final Translations$organization$picker$zh_CN picker = Translations$organization$picker$zh_CN.internal(_root);
	late final Translations$organization$inviteColleagues$zh_CN inviteColleagues = Translations$organization$inviteColleagues$zh_CN.internal(_root);
	late final Translations$organization$inviteQr$zh_CN inviteQr = Translations$organization$inviteQr$zh_CN.internal(_root);
	late final Translations$organization$directory$zh_CN directory = Translations$organization$directory$zh_CN.internal(_root);
	late final Translations$organization$memberDetail$zh_CN memberDetail = Translations$organization$memberDetail$zh_CN.internal(_root);
	late final Translations$organization$manage$zh_CN manage = Translations$organization$manage$zh_CN.internal(_root);
	late final Translations$organization$contactEntry$zh_CN contactEntry = Translations$organization$contactEntry$zh_CN.internal(_root);
	late final Translations$organization$hub$zh_CN hub = Translations$organization$hub$zh_CN.internal(_root);
	late final Translations$organization$wsMembers$zh_CN wsMembers = Translations$organization$wsMembers$zh_CN.internal(_root);
	late final Translations$organization$tools$zh_CN tools = Translations$organization$tools$zh_CN.internal(_root);
	late final Translations$organization$chart$zh_CN chart = Translations$organization$chart$zh_CN.internal(_root);
	late final Translations$organization$experienceUi$zh_CN experienceUi = Translations$organization$experienceUi$zh_CN.internal(_root);
}

// Path: passport
class Translations$passport$zh_CN {
	Translations$passport$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '展开历史登录记录'
	String get loginHistoryToggle => '展开历史登录记录';

	/// zh-CN: '请输入邮箱'
	String get hintEmail => '请输入邮箱';

	/// zh-CN: '请输入手机号'
	String get hintMobile => '请输入手机号';

	/// zh-CN: '请输入密码'
	String get hintPassword => '请输入密码';

	/// zh-CN: '请输入验证码'
	String get hintVerifyCode => '请输入验证码';

	/// zh-CN: '获取验证码'
	String get getVerifyCode => '获取验证码';

	/// zh-CN: '一键登录'
	String get oneKeyLogin => '一键登录';

	/// zh-CN: '二维码已过期，请重新扫码'
	String get qrCodeExpired => '二维码已过期，请重新扫码';

	/// zh-CN: '此二维码已使用'
	String get qrCodeUsed => '此二维码已使用';

	/// zh-CN: '登录已取消'
	String get qrLoginCancelled => '登录已取消';

	/// zh-CN: '正在登录...'
	String get qrLoginConfirming => '正在登录...';

	/// zh-CN: '已取消登录'
	String get qrLoginCancelledByMe => '已取消登录';

	/// zh-CN: '正在连接...'
	String get qrConnecting => '正在连接...';

	/// zh-CN: 'Web 端登录确认'
	String get qrWebLoginTitle => 'Web 端登录确认';

	/// zh-CN: '请确认是否在 Web 端登录此账号'
	String get qrWebLoginDesc => '请确认是否在 Web 端登录此账号';

	/// zh-CN: '确认登录'
	String get qrLoginAction => '确认登录';

	/// zh-CN: '登录成功'
	String get qrLoginSuccess => '登录成功';

	/// zh-CN: 'Web 平台不支持支付宝登录'
	String get alipayNotSupportedWeb => 'Web 平台不支持支付宝登录';

	/// zh-CN: 'Web 平台不支持一键登录功能'
	String get oneKeyNotSupportedWeb => 'Web 平台不支持一键登录功能';

	/// zh-CN: '一键登录服务初始化失败，请稍后重试'
	String get oneKeyInitFailed => '一键登录服务初始化失败，请稍后重试';

	/// zh-CN: '当前网络环境不支持，或者手机没有绑定电话卡'
	String get oneKeyNoSimCard => '当前网络环境不支持，或者手机没有绑定电话卡';

	/// zh-CN: '无法获取屏幕尺寸'
	String get cannotGetScreenSize => '无法获取屏幕尺寸';

	/// zh-CN: '一键登录失败，请检查网络后重试'
	String get oneKeyFailedRetry => '一键登录失败，请检查网络后重试';
}

// Path: splash
class Translations$splash$zh_CN {
	Translations$splash$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '畅所欲言，自在沟通'
	String get slogan => '畅所欲言，自在沟通';
}

// Path: talkRecord
class Translations$talkRecord$zh_CN {
	Translations$talkRecord$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '面聊记录'
	String get entryTitle => '面聊记录';

	/// zh-CN: '面对面沟通的录音与转写记录'
	String get entrySubtitlePersonal => '面对面沟通的录音与转写记录';

	/// zh-CN: '会议与面谈的团队协作记录'
	String get entrySubtitleOrg => '会议与面谈的团队协作记录';

	/// zh-CN: '面聊记录'
	String get listTitle => '面聊记录';

	/// zh-CN: '当前空间'
	String get contextSectionTitle => '当前空间';

	/// zh-CN: '个人空间'
	String get contextPersonal => '个人空间';

	/// zh-CN: '当前企业'
	String get contextOrgFallback => '当前企业';

	/// zh-CN: '全部'
	String get filterAll => '全部';

	/// zh-CN: '我创建'
	String get filterOwned => '我创建';

	/// zh-CN: '共享给我'
	String get filterShared => '共享给我';

	/// zh-CN: '搜索面聊记录'
	String get searchHint => '搜索面聊记录';

	/// zh-CN: '未命名记录'
	String get untitledRecord => '未命名记录';

	/// zh-CN: '仅自己可见'
	String get visibilityOwnerOnly => '仅自己可见';

	/// zh-CN: '已共享'
	String get visibilityShared => '已共享';

	/// zh-CN: '本机草稿'
	String get localDraftBadge => '本机草稿';

	/// zh-CN: '录音中'
	String get statusRecording => '录音中';

	/// zh-CN: '上传中'
	String get statusUploading => '上传中';

	/// zh-CN: '上传校验中'
	String get statusVerifying => '上传校验中';

	/// zh-CN: '音频合成中'
	String get statusAssembling => '音频合成中';

	/// zh-CN: '上传失败，可重试'
	String get statusUploadFailed => '上传失败，可重试';

	/// zh-CN: '转写排队中'
	String get statusTranscribeQueued => '转写排队中';

	/// zh-CN: '转写中'
	String get statusTranscribeRunning => '转写中';

	/// zh-CN: '已转写'
	String get statusTranscribeReady => '已转写';

	/// zh-CN: '转写失败，录音仍可回听'
	String get statusTranscribeFailed => '转写失败，录音仍可回听';

	/// zh-CN: '未检测到可转写语音'
	String get statusNoSpeech => '未检测到可转写语音';

	/// zh-CN: '仅录音'
	String get statusRecordOnly => '仅录音';

	/// zh-CN: '还没有面聊记录'
	String get emptyNeverCreatedTitle => '还没有面聊记录';

	/// zh-CN: '面对面沟通后，在这里保存录音与转写'
	String get emptyNeverCreatedSubtitle => '面对面沟通后，在这里保存录音与转写';

	/// zh-CN: '没有匹配的记录'
	String get emptyNoMatchTitle => '没有匹配的记录';

	/// zh-CN: '当前筛选或搜索词下没有结果，可调整后重试'
	String get emptyNoMatchSubtitle => '当前筛选或搜索词下没有结果，可调整后重试';

	/// zh-CN: '新建记录'
	String get createRecord => '新建记录';

	/// zh-CN: '记录加载失败'
	String get loadFailedTitle => '记录加载失败';

	/// zh-CN: '重试'
	String get loadFailedAction => '重试';

	/// zh-CN: '新建面聊记录'
	String get prepareTitle => '新建面聊记录';

	/// zh-CN: '标题'
	String get fieldTitleLabel => '标题';

	/// zh-CN: '选填，方便日后查找'
	String get fieldTitlePlaceholder => '选填，方便日后查找';

	/// zh-CN: '保存到'
	String get saveToSectionTitle => '保存到';

	/// zh-CN: '更改'
	String get saveToChangeAction => '更改';

	/// zh-CN: '处理方式'
	String get processingSectionTitle => '处理方式';

	/// zh-CN: '仅录音'
	String get processingRecordOnly => '仅录音';

	/// zh-CN: '转写文字'
	String get processingTranscribe => '转写文字';

	/// zh-CN: '转写并摘要'
	String get processingSummarize => '转写并摘要';

	/// zh-CN: '仅保存录音，可随时回听；会后可在详情页升级转写。'
	String get processingRecordOnlyHint => '仅保存录音，可随时回听；会后可在详情页升级转写。';

	/// zh-CN: '当前实例未配置转写服务，本次仅保存录音。'
	String get processingReasonUnavailable => '当前实例未配置转写服务，本次仅保存录音。';

	/// zh-CN: '转写配额暂不可用，本次仅保存录音；录音不受影响。'
	String get processingReasonQuota => '转写配额暂不可用，本次仅保存录音；录音不受影响。';

	/// zh-CN: '未能获取处理能力，本次按仅录音处理。'
	String get processingReasonLoadFailed => '未能获取处理能力，本次按仅录音处理。';

	/// zh-CN: '单条录音最长 $minutes 分钟'
	String maxDurationHint({required Object minutes}) => '单条录音最长 ${minutes} 分钟';

	/// zh-CN: '协作信息'
	String get collabSectionTitle => '协作信息';

	/// zh-CN: '选填，仅对企业记录生效'
	String get collabSectionSubtitle => '选填，仅对企业记录生效';

	/// zh-CN: '参与者'
	String get collabParticipantsLabel => '参与者';

	/// zh-CN: '未选择参与者'
	String get collabParticipantsEmpty => '未选择参与者';

	/// zh-CN: '已选 $count 人'
	String collabParticipantsCount({required Object count}) => '已选 ${count} 人';

	/// zh-CN: '参与者目录待接入；可创建记录后再授权共享。'
	String get collabParticipantsUnavailable => '参与者目录待接入；可创建记录后再授权共享。';

	/// zh-CN: '我已告知现场参与者本次录音及其处理方式'
	String get noticeCheckbox => '我已告知现场参与者本次录音及其处理方式';

	/// zh-CN: '开始录音前需先确认已告知'
	String get noticeHint => '开始录音前需先确认已告知';

	/// zh-CN: '开始录音'
	String get startRecording => '开始录音';

	/// zh-CN: '需要麦克风权限'
	String get micDeniedTitle => '需要麦克风权限';

	/// zh-CN: '面聊记录需要使用麦克风录制现场声音。当前权限被拒绝，可重试或在系统设置中开启。'
	String get micDeniedMessage => '面聊记录需要使用麦克风录制现场声音。当前权限被拒绝，可重试或在系统设置中开启。';

	/// zh-CN: '重试'
	String get micRetry => '重试';

	/// zh-CN: '去设置'
	String get micOpenSettings => '去设置';

	/// zh-CN: '暂时无法开始录音'
	String get recordingUnavailableTitle => '暂时无法开始录音';

	/// zh-CN: '请检查是否有未结束的录音、麦克风权限和本机存储空间。草稿及已有分段已保留。'
	String get recordingUnavailableMessage => '请检查是否有未结束的录音、麦克风权限和本机存储空间。草稿及已有分段已保留。';

	/// zh-CN: '保存位置'
	String get saveLocationTitle => '保存位置';

	/// zh-CN: '个人'
	String get saveLocationPersonalSection => '个人';

	/// zh-CN: '有权企业'
	String get saveLocationOrgSection => '有权企业';

	/// zh-CN: '不指定工作区'
	String get saveLocationWorkspaceOptional => '不指定工作区';

	/// zh-CN: '保存期限'
	String get retentionPolicyLabel => '保存期限';

	/// zh-CN: '更改保存位置'
	String get changeConfirmTitle => '更改保存位置';

	/// zh-CN: '将保存到：$name'
	String changeConfirmTarget({required Object name}) => '将保存到：${name}';

	/// zh-CN: '已填写的标题与笔记会保留'
	String get changeConfirmKeepTitle => '已填写的标题与笔记会保留';

	/// zh-CN: '不适用于新位置的参与者选择将被清空'
	String get changeConfirmClearParticipants => '不适用于新位置的参与者选择将被清空';

	/// zh-CN: '处理方式将按新位置的能力重新校验'
	String get changeConfirmRecheck => '处理方式将按新位置的能力重新校验';

	/// zh-CN: '确认更改'
	String get changeConfirmAction => '确认更改';

	/// zh-CN: '正在录音 · 本机分段保存'
	String get barRecording => '正在录音 · 本机分段保存';

	/// zh-CN: '已暂停，不计入录音时长'
	String get barPaused => '已暂停，不计入录音时长';

	/// zh-CN: '录音已中断 · 恢复需手动继续'
	String get barInterrupted => '录音已中断 · 恢复需手动继续';

	/// zh-CN: '来自'
	String get barOriginPrefix => '来自';

	/// zh-CN: '查看录音状态'
	String get barExpandHint => '查看录音状态';

	/// zh-CN: '录音控制由录音模块提供，当前构建为占位展示'
	String get barControlsUnavailable => '录音控制由录音模块提供，当前构建为占位展示';

	/// zh-CN: '个人空间'
	String get barOriginPersonal => '个人空间';

	/// zh-CN: '企业空间'
	String get barOriginOrgFallback => '企业空间';

	/// zh-CN: '创建者'
	String get roleOwner => '创建者';

	/// zh-CN: '编辑者'
	String get roleEditor => '编辑者';

	/// zh-CN: '读者'
	String get roleViewer => '读者';

	/// zh-CN: '你可校对原文与发言人、编辑共享笔记；分享与删除由创建者管理。'
	String get roleEditorHint => '你可校对原文与发言人、编辑共享笔记；分享与删除由创建者管理。';

	/// zh-CN: '摘要'
	String get tabSummary => '摘要';

	/// zh-CN: '原文'
	String get tabTranscript => '原文';

	/// zh-CN: '发言人校对'
	String get speakersEntry => '发言人校对';

	/// zh-CN: '当前无回放权限'
	String get playbackUnavailable => '当前无回放权限';

	/// zh-CN: '播放会话不可用，可重试'
	String get playbackTicketFailed => '播放会话不可用，可重试';

	/// zh-CN: '播放'
	String get playbackPlayLabel => '播放';

	/// zh-CN: '暂停'
	String get playbackPauseLabel => '暂停';

	/// zh-CN: '播放进度 $position / $duration'
	String playbackProgressLabel({required Object position, required Object duration}) => '播放进度 ${position} / ${duration}';

	/// zh-CN: '回到播放位置'
	String get returnToPlayback => '回到播放位置';

	/// zh-CN: '搜索原文关键词'
	String get transcriptSearchHint => '搜索原文关键词';

	/// zh-CN: '命中 $count 处，点击时间点回听定位'
	String transcriptHitCount({required Object count}) => '命中 ${count} 处，点击时间点回听定位';

	/// zh-CN: '没有命中片段'
	String get transcriptNoHit => '没有命中片段';

	/// zh-CN: '暂无原文片段'
	String get transcriptEmpty => '暂无原文片段';

	/// zh-CN: '未知说话人'
	String get speakerUnknown => '未知说话人';

	/// zh-CN: '匿名'
	String get speakerAnonymousPill => '匿名';

	/// zh-CN: '人工标记'
	String get speakerManualPill => '人工标记';

	/// zh-CN: '本人认领'
	String get speakerSelfClaimPill => '本人认领';

	/// zh-CN: '重点'
	String get markPillPrefix => '重点';

	/// zh-CN: '手动重点'
	String get markDefaultText => '手动重点';

	/// zh-CN: '人工修订'
	String get segmentHumanEditedPill => '人工修订';

	/// zh-CN: '$speaker 于 $time 的发言'
	String segmentRowSemanticLabel({required Object speaker, required Object time}) => '${speaker} 于 ${time} 的发言';

	/// zh-CN: '回听 $time'
	String segmentListenLabel({required Object time}) => '回听 ${time}';

	/// zh-CN: '本次记录仅保存录音'
	String get detailRecordOnlyTitle => '本次记录仅保存录音';

	/// zh-CN: '未请求转写，暂无原文与摘要；录音可回听，会后可升级转写。'
	String get detailRecordOnlyBody => '未请求转写，暂无原文与摘要；录音可回听，会后可升级转写。';

	/// zh-CN: '未检测到可转写语音'
	String get detailNoSpeechTitle => '未检测到可转写语音';

	/// zh-CN: '录音已保留。本次录音中没有可转写的语音内容。'
	String get detailNoSpeechBody => '录音已保留。本次录音中没有可转写的语音内容。';

	/// zh-CN: '转写失败'
	String get detailTranscribeFailedTitle => '转写失败';

	/// zh-CN: '转写失败，录音仍可回听。你可重试转写。'
	String get detailTranscribeFailedBodyEditor => '转写失败，录音仍可回听。你可重试转写。';

	/// zh-CN: '转写失败，录音仍可回听。请联系创建者重试。'
	String get detailTranscribeFailedBodyViewer => '转写失败，录音仍可回听。请联系创建者重试。';

	/// zh-CN: '转写处理中'
	String get detailTranscribingTitle => '转写处理中';

	/// zh-CN: '原文生成后会在此展示；处理中不显示预计完成时间。'
	String get detailTranscribingBody => '原文生成后会在此展示；处理中不显示预计完成时间。';

	/// zh-CN: '重试转写'
	String get detailTranscribeRetry => '重试转写';

	/// zh-CN: '摘要'
	String get summarySectionTitle => '摘要';

	/// zh-CN: 'AI 整理草稿 · 使用前请核对'
	String get summaryDraftBadge => 'AI 整理草稿 · 使用前请核对';

	/// zh-CN: '原文或署名已更新，摘要可能过时'
	String get summaryStaleBanner => '原文或署名已更新，摘要可能过时';

	/// zh-CN: '讨论重点'
	String get summaryDecisionsTitle => '讨论重点';

	/// zh-CN: '待办草稿'
	String get summaryActionsTitle => '待办草稿';

	/// zh-CN: '负责人未定'
	String get summaryAssigneeUnset => '负责人未定';

	/// zh-CN: '查看原文出处'
	String get summaryJumpToSource => '查看原文出处';

	/// zh-CN: '摘要已排队，生成后展示。'
	String get summaryQueued => '摘要已排队，生成后展示。';

	/// zh-CN: '摘要整理中，生成后展示。'
	String get summaryRunning => '摘要整理中，生成后展示。';

	/// zh-CN: '已生成原文，尚未请求摘要。'
	String get summaryNotGenerated => '已生成原文，尚未请求摘要。';

	/// zh-CN: '尚无原文，暂不能生成摘要。'
	String get summaryNoSource => '尚无原文，暂不能生成摘要。';

	/// zh-CN: '当前实例未配置摘要服务。'
	String get summaryUnavailable => '当前实例未配置摘要服务。';

	/// zh-CN: '摘要生成失败，可稍后重试。'
	String get summaryFailed => '摘要生成失败，可稍后重试。';

	/// zh-CN: '共享补充笔记'
	String get notesTitle => '共享补充笔记';

	/// zh-CN: '随记录共享，所有可查看本记录的人可见。'
	String get notesSharedHint => '随记录共享，所有可查看本记录的人可见。';

	/// zh-CN: '随记录共享，当前为只读。'
	String get notesReadonlyHint => '随记录共享，当前为只读。';

	/// zh-CN: '编辑'
	String get notesEditAction => '编辑';

	/// zh-CN: '补充会议结论、背景信息等'
	String get notesPlaceholder => '补充会议结论、背景信息等';

	/// zh-CN: '暂无补充笔记'
	String get notesEmpty => '暂无补充笔记';

	/// zh-CN: '取消'
	String get notesCancel => '取消';

	/// zh-CN: '保存笔记'
	String get notesSave => '保存笔记';

	/// zh-CN: '笔记已保存'
	String get notesSavedHint => '笔记已保存';

	/// zh-CN: '笔记已被他人更新，请刷新后重试；当前输入已保留。'
	String get notesConflictHint => '笔记已被他人更新，请刷新后重试；当前输入已保留。';

	/// zh-CN: '保存失败，请稍后重试；当前输入已保留。'
	String get notesFailedHint => '保存失败，请稍后重试；当前输入已保留。';

	/// zh-CN: '更多操作'
	String get moreActionsTitle => '更多操作';

	/// zh-CN: '取消'
	String get moreActionsCancel => '取消';

	/// zh-CN: '分享管理'
	String get actionShare => '分享管理';

	/// zh-CN: '导出文字'
	String get actionExport => '导出文字';

	/// zh-CN: '删除记录'
	String get actionDelete => '删除记录';

	/// zh-CN: '该操作待后续版本接入（分享/导出/删除由对应模块联调后开放），当前构建仅提供入口。'
	String get actionPendingIntegration => '该操作待后续版本接入（分享/导出/删除由对应模块联调后开放），当前构建仅提供入口。';

	/// zh-CN: '片段校对'
	String get segmentEditTitle => '片段校对';

	/// zh-CN: '时间点 $time'
	String segmentTimeLabel({required Object time}) => '时间点 ${time}';

	/// zh-CN: '原稿'
	String get segmentOriginalLabel => '原稿';

	/// zh-CN: '校对文字'
	String get segmentEditLabel => '校对文字';

	/// zh-CN: '修改转写文字'
	String get segmentEditPlaceholder => '修改转写文字';

	/// zh-CN: '保存校对'
	String get segmentSave => '保存校对';

	/// zh-CN: '重新提交'
	String get segmentResubmit => '重新提交';

	/// zh-CN: '保存失败，请稍后重试；输入已保留。'
	String get segmentSaveFailed => '保存失败，请稍后重试；输入已保留。';

	/// zh-CN: '版本冲突：原文已被他人修改'
	String get segmentConflictTitle => '版本冲突：原文已被他人修改';

	/// zh-CN: '你的输入已保留，可与服务器最新稿对比后重新提交；保存以你的输入为准。'
	String get segmentConflictBody => '你的输入已保留，可与服务器最新稿对比后重新提交；保存以你的输入为准。';

	/// zh-CN: '采用服务器稿'
	String get segmentAdoptServer => '采用服务器稿';

	/// zh-CN: '发言人校对'
	String get speakersTitle => '发言人校对';

	/// zh-CN: '说话人设置只作用于本记录；人工标记不等于本人认证，也不会建立声纹档案。'
	String get speakersScopeHint => '说话人设置只作用于本记录；人工标记不等于本人认证，也不会建立声纹档案。';

	/// zh-CN: '设置显示名'
	String get speakerSetName => '设置显示名';

	/// zh-CN: '设置显示名'
	String get speakerSetNameTitle => '设置显示名';

	/// zh-CN: '保存'
	String get speakerSetNameConfirm => '保存';

	/// zh-CN: '认领是我'
	String get speakerClaimSelf => '认领是我';

	/// zh-CN: '该说话人已被他人认领，请创建者人工纠正。'
	String get speakerClaimConflict => '该说话人已被他人认领，请创建者人工纠正。';

	/// zh-CN: '试听片段'
	String get speakerAudition => '试听片段';

	/// zh-CN: '标记同事'
	String get speakerMarkColleague => '标记同事';

	/// zh-CN: '参与者目录待接入，暂不能选择同事；可先设置显示名。'
	String get speakerDirectoryUnavailable => '参与者目录待接入，暂不能选择同事；可先设置显示名。';

	/// zh-CN: '该署名为人工标记或本人认领，不构成身份认证。'
	String get speakerSourceHint => '该署名为人工标记或本人认领，不构成身份认证。';

	/// zh-CN: '分享管理'
	String get shareManageTitle => '分享管理';

	/// zh-CN: '当前可见范围'
	String get shareVisibilitySectionTitle => '当前可见范围';

	/// zh-CN: '仅自己可见'
	String get shareVisibilityOwnerOnly => '仅自己可见';

	/// zh-CN: '已共享给 $count 人查看'
	String shareVisibilityShared({required Object count}) => '已共享给 ${count} 人查看';

	/// zh-CN: '谁可以查看'
	String get shareRosterSectionTitle => '谁可以查看';

	/// zh-CN: '我 · 创建者'
	String get shareOwnerRowLabel => '我 · 创建者';

	/// zh-CN: '创建者始终可以查看与管理分享'
	String get shareOwnerRowHint => '创建者始终可以查看与管理分享';

	/// zh-CN: '可查看与回听'
	String get shareGrantRoleViewer => '可查看与回听';

	/// zh-CN: '可校对与编辑'
	String get shareGrantRoleEditor => '可校对与编辑';

	/// zh-CN: '可导出'
	String get shareAllowExportPill => '可导出';

	/// zh-CN: '有效期至 $date'
	String shareExpiresPill({required Object date}) => '有效期至 ${date}';

	/// zh-CN: '编辑'
	String get shareGrantEditAction => '编辑';

	/// zh-CN: '撤销'
	String get shareGrantRevokeAction => '撤销';

	/// zh-CN: '添加同事'
	String get shareAddEntryOrg => '添加同事';

	/// zh-CN: '添加联系人'
	String get shareAddEntryPersonal => '添加联系人';

	/// zh-CN: '可授权当前企业内符合工作区权限的同事'
	String get shareAddHintOrg => '可授权当前企业内符合工作区权限的同事';

	/// zh-CN: '可授权已有联系人'
	String get shareAddHintPersonal => '可授权已有联系人';

	/// zh-CN: '尚未授权任何人'
	String get shareEmptyTitle => '尚未授权任何人';

	/// zh-CN: '该记录默认仅自己可见；明确授权后，对方才能查看与回听。'
	String get shareEmptyBody => '该记录默认仅自己可见；明确授权后，对方才能查看与回听。';

	/// zh-CN: '我的权限'
	String get shareMyPermissionTitle => '我的权限';

	/// zh-CN: '你当前没有这条记录的授权信息；分享由创建者管理。'
	String get shareMyPermissionNone => '你当前没有这条记录的授权信息；分享由创建者管理。';

	/// zh-CN: '你可以查看与回听本记录；分享权限由创建者管理。'
	String get shareMyPermissionReadonly => '你可以查看与回听本记录；分享权限由创建者管理。';

	/// zh-CN: '当前记录可见范围：$visibility'
	String shareVisibilityOfRecord({required Object visibility}) => '当前记录可见范围：${visibility}';

	/// zh-CN: '编辑者不能管理分享权限或删除记录；如需调整，请联系创建者。'
	String get shareEditorCannotManageAcl => '编辑者不能管理分享权限或删除记录；如需调整，请联系创建者。';

	/// zh-CN: '权限已保存'
	String get shareSaveFeedback => '权限已保存';

	/// zh-CN: '授权已被他人更新，请刷新后重试。'
	String get shareConflictHint => '授权已被他人更新，请刷新后重试。';

	/// zh-CN: '发送卡片'
	String get shareSendCard => '发送卡片';

	/// zh-CN: '处理中…'
	String get shareCardSending => '处理中…';

	/// zh-CN: '生成面聊记录卡片发送给同事；对方打开时按其权限查看。'
	String get shareSendCardHint => '生成面聊记录卡片发送给同事；对方打开时按其权限查看。';

	/// zh-CN: '先添加授权，才能发送分享卡片。'
	String get shareSendNeedsGrant => '先添加授权，才能发送分享卡片。';

	/// zh-CN: '卡片已发送（示例）'
	String get shareCardSent => '卡片已发送（示例）';

	/// zh-CN: '发送失败，可重试'
	String get shareCardSendFailed => '发送失败，可重试';

	/// zh-CN: '暂时无法打开会话选择器，请返回后重试。'
	String get shareCardSenderUnavailable => '暂时无法打开会话选择器，请返回后重试。';

	/// zh-CN: '撤销 $name 的访问权限？'
	String shareRevokeConfirmTitle({required Object name}) => '撤销 ${name} 的访问权限？';

	/// zh-CN: '将无法继续访问原记录。已导出或保存的副本无法收回。'
	String get shareRevokeConfirmBody => '将无法继续访问原记录。已导出或保存的副本无法收回。';

	/// zh-CN: '撤销'
	String get shareRevokeConfirmAction => '撤销';

	/// zh-CN: '未能撤销'
	String get shareRevokeFailedTitle => '未能撤销';

	/// zh-CN: '撤销失败，请稍后重试。'
	String get shareRevokeFailedBody => '撤销失败，请稍后重试。';

	/// zh-CN: '编辑权限'
	String get grantEditTitle => '编辑权限';

	/// zh-CN: '添加授权'
	String get grantEditTitleNew => '添加授权';

	/// zh-CN: '选择要授权的人'
	String get grantEditCandidateSection => '选择要授权的人';

	/// zh-CN: '搜索姓名或账号'
	String get grantEditCandidateSearchHint => '搜索姓名或账号';

	/// zh-CN: '候选目录暂不可用，请稍后重试。'
	String get grantEditCandidatesUnavailable => '候选目录暂不可用，请稍后重试。';

	/// zh-CN: '没有可授权的候选人'
	String get grantEditCandidateEmpty => '没有可授权的候选人';

	/// zh-CN: '被授权人'
	String get grantEditGranteeLabel => '被授权人';

	/// zh-CN: '角色'
	String get grantEditRoleSectionTitle => '角色';

	/// zh-CN: '可查看记录与回听音频，不能修改内容。'
	String get grantEditRoleViewerHint => '可查看记录与回听音频，不能修改内容。';

	/// zh-CN: '可校对原文与发言人、编辑共享笔记；不能管理分享或删除。'
	String get grantEditRoleEditorHint => '可校对原文与发言人、编辑共享笔记；不能管理分享或删除。';

	/// zh-CN: '允许导出'
	String get grantEditExportSectionTitle => '允许导出';

	/// zh-CN: '导出已被企业策略禁用，不能在授权中开启。'
	String get grantEditExportBlockedOrg => '导出已被企业策略禁用，不能在授权中开启。';

	/// zh-CN: '未能确认当前导出策略，暂不能开启导出。'
	String get grantEditExportBlockedUnknown => '未能确认当前导出策略，暂不能开启导出。';

	/// zh-CN: '到期时间'
	String get grantEditExpiresSectionTitle => '到期时间';

	/// zh-CN: '$date 到期'
	String grantEditExpiresOn({required Object date}) => '${date} 到期';

	/// zh-CN: '可选；设置后对方到期自动失去访问。'
	String get grantEditExpiresHint => '可选；设置后对方到期自动失去访问。';

	/// zh-CN: '保存权限'
	String get grantEditSave => '保存权限';

	/// zh-CN: '处理中…'
	String get grantEditSaving => '处理中…';

	/// zh-CN: '授权已被他人更新，请返回刷新名单后重试；你的设置已保留。'
	String get grantEditConflict => '授权已被他人更新，请返回刷新名单后重试；你的设置已保留。';

	/// zh-CN: '保存失败，请稍后重试；你的设置已保留。'
	String get grantEditSaveFailed => '保存失败，请稍后重试；你的设置已保留。';

	/// zh-CN: '暂时无法查看'
	String get invalidTitle => '暂时无法查看';

	/// zh-CN: '该内容当前无法查看，可能不存在或你没有查看权限。'
	String get invalidBody => '该内容当前无法查看，可能不存在或你没有查看权限。';

	/// zh-CN: '返回'
	String get invalidBack => '返回';

	/// zh-CN: '返回'
	String get resultBack => '返回';

	/// zh-CN: '导出文字'
	String get exportTitle => '导出文字';

	/// zh-CN: '导出格式'
	String get exportFormatSectionTitle => '导出格式';

	/// zh-CN: '纯文本 .txt'
	String get exportFormatTxt => '纯文本 .txt';

	/// zh-CN: 'Markdown .md'
	String get exportFormatMd => 'Markdown .md';

	/// zh-CN: '导出仅包含文字内容，不包含音频与未授权参与者信息。'
	String get exportFormatHint => '导出仅包含文字内容，不包含音频与未授权参与者信息。';

	/// zh-CN: '导出能力'
	String get exportCapabilitySectionTitle => '导出能力';

	/// zh-CN: '你当前的角色没有被授予导出权限；导出需创建者授权或策略允许。'
	String get exportBlockedNoGrant => '你当前的角色没有被授予导出权限；导出需创建者授权或策略允许。';

	/// zh-CN: '导出已被企业策略禁用，暂不能导出。'
	String get exportBlockedOrgPolicy => '导出已被企业策略禁用，暂不能导出。';

	/// zh-CN: '当前实例未开启导出能力，暂不能导出。'
	String get exportBlockedInstancePolicy => '当前实例未开启导出能力，暂不能导出。';

	/// zh-CN: '未能确认当前导出策略，暂不能导出。'
	String get exportBlockedUnknown => '未能确认当前导出策略，暂不能导出。';

	/// zh-CN: '独立副本提示'
	String get exportIndependentCopyTitle => '独立副本提示';

	/// zh-CN: '导出生成的是独立副本；生成后无法通过删除记录或撤销权限收回。'
	String get exportIndependentCopyBody => '导出生成的是独立副本；生成后无法通过删除记录或撤销权限收回。';

	/// zh-CN: '我已了解导出的独立副本无法收回'
	String get exportIndependentCopyAck => '我已了解导出的独立副本无法收回';

	/// zh-CN: '生成导出'
	String get exportGenerate => '生成导出';

	/// zh-CN: '生成中…'
	String get exportGenerating => '生成中…';

	/// zh-CN: '导出排队中'
	String get exportQueuedTitle => '导出排队中';

	/// zh-CN: '已提交生成请求；排队不代表已生成完成，可稍后刷新状态。'
	String get exportQueuedBody => '已提交生成请求；排队不代表已生成完成，可稍后刷新状态。';

	/// zh-CN: '刷新状态'
	String get exportRefreshState => '刷新状态';

	/// zh-CN: '导出已就绪'
	String get exportReadyTitle => '导出已就绪';

	/// zh-CN: '可下载导出文件；下载链接短期有效，到期后需重新生成。'
	String get exportReadyBody => '可下载导出文件；下载链接短期有效，到期后需重新生成。';

	/// zh-CN: '有效期至 $date'
	String exportExpiresAt({required Object date}) => '有效期至 ${date}';

	/// zh-CN: '剩余约 $minutes 分钟'
	String exportRemaining({required Object minutes}) => '剩余约 ${minutes} 分钟';

	/// zh-CN: '保存导出文件'
	String get exportDownload => '保存导出文件';

	/// zh-CN: '正在下载并准备保存…'
	String get exportDownloading => '正在下载并准备保存…';

	/// zh-CN: '文件已保存；这是独立副本，撤销权限不会删除该副本。'
	String get exportDownloadReady => '文件已保存；这是独立副本，撤销权限不会删除该副本。';

	/// zh-CN: '下载或保存失败，可重试'
	String get exportDownloadFailed => '下载或保存失败，可重试';

	/// zh-CN: '导出已到期'
	String get exportExpiredTitle => '导出已到期';

	/// zh-CN: '下载链接已过期，请重新生成导出。'
	String get exportExpiredBody => '下载链接已过期，请重新生成导出。';

	/// zh-CN: '重新生成'
	String get exportRegenerate => '重新生成';

	/// zh-CN: '生成导出失败，可重试。'
	String get exportFailedBody => '生成导出失败，可重试。';

	/// zh-CN: '记录已被他人更新，请刷新后重试。'
	String get exportConflictHint => '记录已被他人更新，请刷新后重试。';

	/// zh-CN: '组件阶段：下载链接为 fixture 示例，不产生真实文件。'
	String get exportFixtureHint => '组件阶段：下载链接为 fixture 示例，不产生真实文件。';

	/// zh-CN: '移交管理责任'
	String get transferTitle => '移交管理责任';

	/// zh-CN: '移交仅变更管理责任人；记录归属（企业与工作区）保持不变。'
	String get transferScopeHint => '移交仅变更管理责任人；记录归属（企业与工作区）保持不变。';

	/// zh-CN: '创建者记录保持不变；此动作与分享权限相互独立。'
	String get transferCreatedByHint => '创建者记录保持不变；此动作与分享权限相互独立。';

	/// zh-CN: '选择新责任人'
	String get transferCandidateSectionTitle => '选择新责任人';

	/// zh-CN: '没有符合条件的候选同事'
	String get transferCandidateEmpty => '没有符合条件的候选同事';

	/// zh-CN: '候选为当前企业内符合工作区权限的同事；最终资格由服务端裁决。'
	String get transferCandidateHint => '候选为当前企业内符合工作区权限的同事；最终资格由服务端裁决。';

	/// zh-CN: '原责任人访问'
	String get transferKeepSectionTitle => '原责任人访问';

	/// zh-CN: '移交后保留我的查看权限'
	String get transferKeepViewer => '移交后保留我的查看权限';

	/// zh-CN: '默认不保留：移交后你将无法继续访问这条记录。'
	String get transferKeepDefaultHint => '默认不保留：移交后你将无法继续访问这条记录。';

	/// zh-CN: '保留后你仍可查看与回听，但分享与删除由新责任人管理。'
	String get transferKeepOnHint => '保留后你仍可查看与回听，但分享与删除由新责任人管理。';

	/// zh-CN: '移交管理责任'
	String get transferSubmit => '移交管理责任';

	/// zh-CN: '移交中…'
	String get transferSubmitting => '移交中…';

	/// zh-CN: '确认移交管理责任？'
	String get transferConfirmTitle => '确认移交管理责任？';

	/// zh-CN: '将把管理责任移交给：$name'
	String transferConfirmTarget({required Object name}) => '将把管理责任移交给：${name}';

	/// zh-CN: '移交后你将不再保留查看权限，也无法再管理这条记录。'
	String get transferConfirmKeepOff => '移交后你将不再保留查看权限，也无法再管理这条记录。';

	/// zh-CN: '移交后你保留查看权限，但管理权归新责任人。'
	String get transferConfirmKeepOn => '移交后你保留查看权限，但管理权归新责任人。';

	/// zh-CN: '确认移交'
	String get transferConfirmAction => '确认移交';

	/// zh-CN: '管理责任已移交'
	String get transferSuccessTitle => '管理责任已移交';

	/// zh-CN: '新责任人：$name'
	String transferSuccessOwner({required Object name}) => '新责任人：${name}';

	/// zh-CN: '你仍保留查看权限；分享管理由新责任人负责。'
	String get transferSuccessKeptAccess => '你仍保留查看权限；分享管理由新责任人负责。';

	/// zh-CN: '记录归属保持不变（企业与工作区不变）。'
	String get transferSuccessScopeUnchanged => '记录归属保持不变（企业与工作区不变）。';

	/// zh-CN: '移交失败，请稍后重试。'
	String get transferFailedBody => '移交失败，请稍后重试。';

	/// zh-CN: '记录已被他人更新，请刷新后重试。'
	String get transferConflictHint => '记录已被他人更新，请刷新后重试。';

	/// zh-CN: '个人记录暂不支持移交管理责任。'
	String get transferPersonalUnsupported => '个人记录暂不支持移交管理责任。';

	/// zh-CN: '只有当前管理责任人可以移交管理责任。'
	String get transferOnlyOwner => '只有当前管理责任人可以移交管理责任。';

	/// zh-CN: '返回详情'
	String get transferBackToDetail => '返回详情';

	/// zh-CN: '删除记录'
	String get deleteTitle => '删除记录';

	/// zh-CN: '确认删除这条记录？'
	String get deleteConfirmTitle => '确认删除这条记录？';

	/// zh-CN: '删除后不再展示正文；已导出或保存的副本无法收回。'
	String get deleteConfirmDialogContent => '删除后不再展示正文；已导出或保存的副本无法收回。';

	/// zh-CN: '删除后不再展示记录正文与摘要。'
	String get deleteConfirmBodyPoint1 => '删除后不再展示记录正文与摘要。';

	/// zh-CN: '删除会先撤销所有人的访问；已导出或保存的副本无法收回。'
	String get deleteConfirmBodyPoint2 => '删除会先撤销所有人的访问；已导出或保存的副本无法收回。';

	/// zh-CN: '附件按留存规则与引用情况清理；提交清理不代表字节已立即删除。'
	String get deleteConfirmBodyPoint3 => '附件按留存规则与引用情况清理；提交清理不代表字节已立即删除。';

	/// zh-CN: '删除'
	String get deleteConfirmAction => '删除';

	/// zh-CN: '删除中…'
	String get deleteDeleting => '删除中…';

	/// zh-CN: '只有创建者可以删除记录。'
	String get deleteOnlyOwner => '只有创建者可以删除记录。';

	/// zh-CN: '删除失败，请稍后重试。'
	String get deleteFailedBody => '删除失败，请稍后重试。';

	/// zh-CN: '记录已被他人更新，请刷新后重试。'
	String get deleteConflictHint => '记录已被他人更新，请刷新后重试。';

	/// zh-CN: '记录已删除'
	String get deleteStatusTitle => '记录已删除';

	/// zh-CN: '记录内容已不再展示。'
	String get deleteStatusNoContentHint => '记录内容已不再展示。';

	/// zh-CN: '附件清理状态'
	String get deleteCleanupSectionTitle => '附件清理状态';

	/// zh-CN: '清理进行中'
	String get cleanupPendingTitle => '清理进行中';

	/// zh-CN: '已提交清理队列；排队成功不代表附件字节已删除。'
	String get cleanupPendingBody => '已提交清理队列；排队成功不代表附件字节已删除。';

	/// zh-CN: '留存期未到'
	String get cleanupBlockedRetentionTitle => '留存期未到';

	/// zh-CN: '记录已删除，附件受留存规则保护；留存期结束后继续清理。'
	String get cleanupBlockedRetentionBody => '记录已删除，附件受留存规则保护；留存期结束后继续清理。';

	/// zh-CN: '受 Hold 保护'
	String get cleanupBlockedHoldTitle => '受 Hold 保护';

	/// zh-CN: '记录已删除，附件受合法保留（Hold）保护；Hold 解除后继续清理。'
	String get cleanupBlockedHoldBody => '记录已删除，附件受合法保留（Hold）保护；Hold 解除后继续清理。';

	/// zh-CN: '附件仍被其他业务引用'
	String get cleanupRetainedTitle => '附件仍被其他业务引用';

	/// zh-CN: '部分附件仍被其他合法业务引用，暂不物理删除。'
	String get cleanupRetainedBody => '部分附件仍被其他合法业务引用，暂不物理删除。';

	/// zh-CN: '清理失败'
	String get cleanupFailedTitle => '清理失败';

	/// zh-CN: '附件清理未完成。请刷新查看状态；符合条件时可重试清理。'
	String get cleanupFailedBody => '附件清理未完成。请刷新查看状态；符合条件时可重试清理。';

	/// zh-CN: '清理完成'
	String get cleanupCompleteTitle => '清理完成';

	/// zh-CN: '记录与附件均已清理完成。'
	String get cleanupCompleteBody => '记录与附件均已清理完成。';

	/// zh-CN: '未提交清理'
	String get cleanupNoneTitle => '未提交清理';

	/// zh-CN: '记录尚未进入清理流程。'
	String get cleanupNoneBody => '记录尚未进入清理流程。';

	/// zh-CN: '清理状态未知'
	String get cleanupUnknownTitle => '清理状态未知';

	/// zh-CN: '暂未能获取清理状态，可刷新重试。'
	String get cleanupUnknownBody => '暂未能获取清理状态，可刷新重试。';

	/// zh-CN: '重试清理'
	String get cleanupRetryAction => '重试清理';

	/// zh-CN: '重试中…'
	String get cleanupRetrying => '重试中…';

	/// zh-CN: '重试清理失败，请稍后再次重试。'
	String get cleanupRetryFailedBody => '重试清理失败，请稍后再次重试。';

	/// zh-CN: '刷新清理状态'
	String get deleteRefreshStatus => '刷新清理状态';

	/// zh-CN: '返回列表'
	String get deleteBackToList => '返回列表';

	/// zh-CN: '组件阶段：清理状态来自 fixture 示例，真实清理进度待联调。'
	String get deleteStatusFixtureHint => '组件阶段：清理状态来自 fixture 示例，真实清理进度待联调。';

	/// zh-CN: '录音停止尚未确认，请重试停止；若仍失败，请关闭应用并检查系统麦克风指示。'
	String get microphoneStopUnconfirmed => '录音停止尚未确认，请重试停止；若仍失败，请关闭应用并检查系统麦克风指示。';

	/// zh-CN: '附件写入结果尚未确认，清理暂未完成。系统会保留保护状态，由运维人员核查；可刷新查看进度。'
	String get cleanupWriteOutcomeUnknown => '附件写入结果尚未确认，清理暂未完成。系统会保留保护状态，由运维人员核查；可刷新查看进度。';

	/// zh-CN: '已取消保存，可再次保存。'
	String get exportDownloadCancelled => '已取消保存，可再次保存。';

	/// zh-CN: '已加入发送队列，尚未收到服务端确认；请在会话中查看，重试不会重复创建消息。'
	String get shareCardSendPending => '已加入发送队列，尚未收到服务端确认；请在会话中查看，重试不会重复创建消息。';

	/// zh-CN: '已取消发送，未发送新的卡片。'
	String get shareCardSendCancelled => '已取消发送，未发送新的卡片。';

	/// zh-CN: '参与者仅用于记录实际参加人员，不会自动共享记录，也不代表已核实发言人。'
	String get participantsInfoHint => '参与者仅用于记录实际参加人员，不会自动共享记录，也不代表已核实发言人。';

	/// zh-CN: '移除参与者'
	String get participantsRemove => '移除参与者';

	/// zh-CN: '来宾姓名或标签'
	String get participantsGuestLabel => '来宾姓名或标签';

	/// zh-CN: '添加来宾'
	String get participantsAddGuest => '添加来宾';

	/// zh-CN: '请选择最多100人；来宾标签须为1–120字且不重复。人员资格可能已变更，请检查名单。'
	String get participantsInvalid => '请选择最多100人；来宾标签须为1–120字且不重复。人员资格可能已变更，请检查名单。';

	/// zh-CN: '没有匹配的联系人或同事，请尝试搜索。'
	String get participantsNoResults => '没有匹配的联系人或同事，请尝试搜索。';

	/// zh-CN: '名单已更新，已刷新为最新内容。请检查后重新编辑。'
	String get participantsConflict => '名单已更新，已刷新为最新内容。请检查后重新编辑。';

	/// zh-CN: '未能确认保存结果，当前选择已保留；请重试或刷新。'
	String get participantsSaveFailed => '未能确认保存结果，当前选择已保留；请重试或刷新。';

	/// zh-CN: '处理任务仍在停止或核查，尚未确认临时音频副本已清理。请刷新查看进度。'
	String get cleanupProcessorUnconfirmed => '处理任务仍在停止或核查，尚未确认临时音频副本已清理。请刷新查看进度。';

	/// zh-CN: '上传前确认'
	String get uploadNoticeTitle => '上传前确认';

	/// zh-CN: '请确认当前录音告知。本次确认用于现在上传；不会改写录音开始时的历史确认，也不会更改保存空间。'
	String get uploadNoticeHint => '请确认当前录音告知。本次确认用于现在上传；不会改写录音开始时的历史确认，也不会更改保存空间。';

	/// zh-CN: '上传录音'
	String get uploadRecording => '上传录音';

	/// zh-CN: '重试上传'
	String get retryRecordingUpload => '重试上传';

	/// zh-CN: '开启录音通知'
	String get notificationRequiredTitle => '开启录音通知';

	/// zh-CN: '为保持后台录音可见，请允许应用通知，并在系统设置中开启录音通知通道。开启后返回此页重试；本次尚未开始录音。'
	String get notificationRequiredMessage => '为保持后台录音可见，请允许应用通知，并在系统设置中开启录音通知通道。开启后返回此页重试；本次尚未开始录音。';

	/// zh-CN: '去通知设置'
	String get openNotificationSettings => '去通知设置';

	/// zh-CN: '确认录音处理'
	String get processingRecoveryTitle => '确认录音处理';

	/// zh-CN: '处理告知或处理器配置已更新。确认后按下方当前版本上传并执行原先选择的处理方式；不改变录音时的历史告知。'
	String get processingRecoveryHint => '处理告知或处理器配置已更新。确认后按下方当前版本上传并执行原先选择的处理方式；不改变录音时的历史告知。';

	/// zh-CN: '当前处理器不可用。录音将保留在本机，恢复后可再次上传。'
	String get processingRecoveryUnavailable => '当前处理器不可用。录音将保留在本机，恢复后可再次上传。';

	/// zh-CN: '暂不处理，保留本机'
	String get keepRecordingLocal => '暂不处理，保留本机';

	/// zh-CN: '同意处理并上传'
	String get confirmProcessingUpload => '同意处理并上传';

	/// zh-CN: '未能读取最新状态，请刷新核对。'
	String get cleanupRetryRefreshFailed => '未能读取最新状态，请刷新核对。';

	/// zh-CN: '已提交重试，正在读取最新清理状态；排队不代表附件已删除。'
	String get cleanupRetryAccepted => '已提交重试，正在读取最新清理状态；排队不代表附件已删除。';

	/// zh-CN: '提交结果尚未确认。请先刷新核对；再次提交会复用同一请求。'
	String get cleanupRetryUnknown => '提交结果尚未确认。请先刷新核对；再次提交会复用同一请求。';

	/// zh-CN: '仅重试已耗尽且允许清理的附件；仍受保护的附件会继续保留。'
	String get cleanupRetryPartial => '仅重试已耗尽且允许清理的附件；仍受保护的附件会继续保留。';

	/// zh-CN: '附件仍受保全、留存或其他有效引用保护，无法强制清理。'
	String get cleanupRetryProtected => '附件仍受保全、留存或其他有效引用保护，无法强制清理。';

	/// zh-CN: '尚未达到可重试条件。上传能力或其他引用失效后，请刷新状态。'
	String get cleanupRetryWaiting => '尚未达到可重试条件。上传能力或其他引用失效后，请刷新状态。';

	/// zh-CN: '暂无法确认清理重试权限，请刷新状态。'
	String get cleanupRetryUnavailable => '暂无法确认清理重试权限，请刷新状态。';

	/// zh-CN: '核对同一重试请求'
	String get cleanupRetryReconcile => '核对同一重试请求';

	/// zh-CN: '准备上传'
	String get uploadProgressRegister => '准备上传';

	/// zh-CN: '上传音频'
	String get uploadProgressUpload => '上传音频';

	/// zh-CN: '确认音频'
	String get uploadProgressConfirm => '确认音频';

	/// zh-CN: '提交保存'
	String get uploadProgressSubmitting => '提交保存';

	/// zh-CN: '已提交，等待音频处理'
	String get uploadProgressCompleted => '已提交，等待音频处理';

	/// zh-CN: '上传未完成，可重试'
	String get uploadProgressFailed => '上传未完成，可重试';

	/// zh-CN: '已确认 $confirmed/$total 段'
	String uploadProgressParts({required Object confirmed, required Object total}) => '已确认 ${confirmed}/${total} 段';

	/// zh-CN: 'AI 服务'
	String get aiServicesTitle => 'AI 服务';

	/// zh-CN: '使用你自己的 API 账户，费用由供应商收取。'
	String get aiServicesSubtitle => '使用你自己的 API 账户，费用由供应商收取。';

	/// zh-CN: 'MiniMax'
	String get aiMinimaxTitle => 'MiniMax';

	/// zh-CN: '智谱 GLM-5.3-Flash'
	String get aiZhipuTitle => '智谱 GLM-5.3-Flash';

	/// zh-CN: '音频转文字与临时说话人标签'
	String get aiMinimaxPurpose => '音频转文字与临时说话人标签';

	/// zh-CN: '摘要草稿、决定与行动项'
	String get aiZhipuPurpose => '摘要草稿、决定与行动项';

	/// zh-CN: '本设备已配置'
	String get aiConfigured => '本设备已配置';

	/// zh-CN: '未配置'
	String get aiNotConfigured => '未配置';

	/// zh-CN: '正在读取本设备配置…'
	String get aiLoading => '正在读取本设备配置…';

	/// zh-CN: 'Key 仅加密保存在当前账号的本设备，不上传 IMBoy、不参与云备份或换机迁移。换设备需要重新填写。'
	String get aiDeviceOnlyNotice => 'Key 仅加密保存在当前账号的本设备，不上传 IMBoy、不参与云备份或换机迁移。换设备需要重新填写。';

	/// zh-CN: '配置 Key 不代表已授权外发。企业记录仍需企业策略允许，发送前还需本次处理同意。'
	String get aiEnterprisePolicyNotice => '配置 Key 不代表已授权外发。企业记录仍需企业策略允许，发送前还需本次处理同意。';

	/// zh-CN: '使用智谱开放平台通用 API，另行计费。Coding Plan 年度 Max 套餐不能默认抵扣此处费用；转写文本会发送至智谱。'
	String get aiMaxNotice => '使用智谱开放平台通用 API，另行计费。Coding Plan 年度 Max 套餐不能默认抵扣此处费用；转写文本会发送至智谱。';

	/// zh-CN: '转写时音频会发送至 MiniMax，并可能产生费用。单次音频不超过 500 秒且不超过 50 MB，由处理流程检查和分块。'
	String get aiAudioExternalNotice => '转写时音频会发送至 MiniMax，并可能产生费用。单次音频不超过 500 秒且不超过 50 MB，由处理流程检查和分块。';

	/// zh-CN: '保存不会验证 Key，也不会发送音频或文本。真实验证可能计费，需另行确认后进行。'
	String get aiValidationNotice => '保存不会验证 Key，也不会发送音频或文本。真实验证可能计费，需另行确认后进行。';

	/// zh-CN: '账号或部署已变化，请返回后重新进入。本页输入已清空。'
	String get aiAccountChanged => '账号或部署已变化，请返回后重新进入。本页输入已清空。';

	/// zh-CN: '本设备配置已变化或尚未完成，请重新填写并保存，或返回后重试。'
	String get aiCredentialChanged => '本设备配置已变化或尚未完成，请重新填写并保存，或返回后重试。';

	/// zh-CN: 'Key 格式不正确：请输入 16～4096 个非空白 ASCII 字符，不包含换行或控制字符。'
	String get aiInvalidKey => 'Key 格式不正确：请输入 16～4096 个非空白 ASCII 字符，不包含换行或控制字符。';

	/// zh-CN: '无法读写本设备安全存储，配置尚未确认。请重试；不会改用明文保存。'
	String get aiStorageFailed => '无法读写本设备安全存储，配置尚未确认。请重试；不会改用明文保存。';

	/// zh-CN: '当前平台尚未验证本设备安全存储，暂不支持保存 Key。'
	String get aiUnsupportedPlatform => '当前平台尚未验证本设备安全存储，暂不支持保存 Key。';

	/// zh-CN: '输入 API Key'
	String get aiKeyPlaceholder => '输入 API Key';

	/// zh-CN: '输入新的 API Key，不回填已有密钥'
	String get aiReplacePlaceholder => '输入新的 API Key，不回填已有密钥';

	/// zh-CN: '保存在本设备'
	String get aiSaveAction => '保存在本设备';

	/// zh-CN: '替换本设备密钥'
	String get aiReplaceAction => '替换本设备密钥';

	/// zh-CN: '删除本设备密钥'
	String get aiDeleteAction => '删除本设备密钥';

	/// zh-CN: '正在保存…'
	String get aiSaving => '正在保存…';

	/// zh-CN: '已保存在本设备，尚未验证 Key。'
	String get aiSaved => '已保存在本设备，尚未验证 Key。';

	/// zh-CN: '已删除本设备配置，录音与已有结果保留。'
	String get aiDeleted => '已删除本设备配置，录音与已有结果保留。';

	/// zh-CN: '替换本设备密钥？'
	String get aiReplaceTitle => '替换本设备密钥？';

	/// zh-CN: '仅替换当前账号在本设备的该服务配置，不影响其他账号或已保存记录。'
	String get aiReplaceNotice => '仅替换当前账号在本设备的该服务配置，不影响其他账号或已保存记录。';

	/// zh-CN: '删除本设备密钥？'
	String get aiDeleteTitle => '删除本设备密钥？';

	/// zh-CN: '停止该服务的新请求。已有录音和结果保留；已发给供应商的请求无法撤回。'
	String get aiDeleteNotice => '停止该服务的新请求。已有录音和结果保留；已发给供应商的请求无法撤回。';

	/// zh-CN: '取消'
	String get aiCancel => '取消';

	/// zh-CN: 'App 仅在前台继续提交和查询。供应商受理后可能在离开 App 后继续处理并计费。每步重验权限和本次同意。已有供应商任务 ID 时只查询；无 ID 且结果未知时停止，不自动重新提交。本机提示不能保证账户费用上限。'
	String get aiProcessingConsent => 'App 仅在前台继续提交和查询。供应商受理后可能在离开 App 后继续处理并计费。每步重验权限和本次同意。已有供应商任务 ID 时只查询；无 ID 且结果未知时停止，不自动重新提交。本机提示不能保证账户费用上限。';

	/// zh-CN: '本设备转写 / 继续'
	String get aiProcessTranscribe => '本设备转写 / 继续';

	/// zh-CN: '本设备整理摘要 / 继续'
	String get aiProcessSummarize => '本设备整理摘要 / 继续';

	/// zh-CN: '正在本设备处理，请保持此页打开。'
	String get aiProcessingRunning => '正在本设备处理，请保持此页打开。';

	/// zh-CN: '处理结果已提交，请核对原文与摘要草稿。'
	String get aiProcessingComplete => '处理结果已提交，请核对原文与摘要草稿。';

	/// zh-CN: '供应商拒绝 Key。请在设置 → AI 服务核对本设备配置；已停止，不自动重发。'
	String get aiProcessingKeyInvalid => '供应商拒绝 Key。请在设置 → AI 服务核对本设备配置；已停止，不自动重发。';

	/// zh-CN: '供应商余额不足。已保留进度并停止，不自动重发。'
	String get aiProcessingBalance => '供应商余额不足。已保留进度并停止，不自动重发。';

	/// zh-CN: '供应商结果未知，可能已计费。已停止外发；需人工核对费用与原执行，不能直接重发。'
	String get aiProcessingUnknown => '供应商结果未知，可能已计费。已停止外发；需人工核对费用与原执行，不能直接重发。';

	/// zh-CN: '处理已停止，录音保留。请核对本设备 Key、权限、配置和输入；若已外发但结果未确认，不会自动重复调用。'
	String get aiProcessingStopped => '处理已停止，录音保留。请核对本设备 Key、权限、配置和输入；若已外发但结果未确认，不会自动重复调用。';

	/// zh-CN: '豆包语音 2.0'
	String get aiDoubaoTitle => '豆包语音 2.0';

	/// zh-CN: '录音转写与临时说话人标签'
	String get aiDoubaoPurpose => '录音转写与临时说话人标签';

	/// zh-CN: '转写时音频会发送至火山引擎豆包语音，费用由供应商收取。仅配置本设备 API Key；不会沿用 MiniMax 密钥。'
	String get aiDoubaoExternalNotice => '转写时音频会发送至火山引擎豆包语音，费用由供应商收取。仅配置本设备 API Key；不会沿用 MiniMax 密钥。';

	/// zh-CN: '豆包转写流程尚未接通，目前仅可保存设备配置。保存不代表连接已验证或可以开始转写。'
	String get aiDoubaoPendingNotice => '豆包转写流程尚未接通，目前仅可保存设备配置。保存不代表连接已验证或可以开始转写。';

	/// zh-CN: '供应商仍在处理，进度已保存。稍后点击继续查询，不会重新提交录音。'
	String get aiProviderPending => '供应商仍在处理，进度已保存。稍后点击继续查询，不会重新提交录音。';

	/// zh-CN: '停止此转写'
	String get aiProviderCancel => '停止此转写';

	/// zh-CN: '停止后将撤销 IMBoy 的来源与操作授权；不能保证供应商停止处理或退款。'
	String get aiProviderCancelNotice => '停止后将撤销 IMBoy 的来源与操作授权；不能保证供应商停止处理或退款。';

	/// zh-CN: '重新提交录音'
	String get aiProviderResubmit => '重新提交录音';

	/// zh-CN: '此操作会新建一次转写，可能重复计费。原请求不会被替换。确认重新提交并同意本次处理？'
	String get aiProviderResubmitNotice => '此操作会新建一次转写，可能重复计费。原请求不会被替换。确认重新提交并同意本次处理？';

	/// zh-CN: '本次转写已停止，已有录音保留。'
	String get aiProviderCancelled => '本次转写已停止，已有录音保留。';

	/// zh-CN: '继续准备转写'
	String get aiProviderResumePreparation => '继续准备转写';

	/// zh-CN: '原任务尚未向供应商提交。本次将重新准备音频来源；确认后按当前权限和处理同意继续。'
	String get aiProviderResumeNotice => '原任务尚未向供应商提交。本次将重新准备音频来源；确认后按当前权限和处理同意继续。';

	/// zh-CN: '转写服务'
	String get aiAsrProvider => '转写服务';

	/// zh-CN: 'AI 转写为可选功能，目前可使用已配置的 MiniMax。仅录音无需任何 AI Key。'
	String get aiAsrOptionalNotice => 'AI 转写为可选功能，目前可使用已配置的 MiniMax。仅录音无需任何 AI Key。';

	/// zh-CN: '核对未知执行并重新请求'
	String get aiUnknownRecoveryTitle => '核对未知执行并重新请求';

	/// zh-CN: '无法核实下列旧请求的结果与费用，可能已经扣费。确认后为同一任务创建新执行，仅重新请求未确认块，可能重复扣费；旧未知事实与结果会保留。取消不会发送恢复请求。'
	String get aiUnknownRecoveryNotice => '无法核实下列旧请求的结果与费用，可能已经扣费。确认后为同一任务创建新执行，仅重新请求未确认块，可能重复扣费；旧未知事实与结果会保留。取消不会发送恢复请求。';

	/// zh-CN: '原执行'
	String get aiUnknownRecoveryRun => '原执行';

	/// zh-CN: '块序号 / 未知请求编号'
	String get aiUnknownRecoveryIntents => '块序号 / 未知请求编号';

	/// zh-CN: '已核对，接受可能重复扣费'
	String get aiUnknownRecoveryConfirm => '已核对，接受可能重复扣费';
}

// Path: welcome
class Translations$welcome$zh_CN {
	Translations$welcome$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '简单连接'
	String get step1Title => '简单连接';

	/// zh-CN: '体验无缝沟通的乐趣。 随时随地，畅所欲言。'
	String get step1Desc => '体验无缝沟通的乐趣。 随时随地，畅所欲言。';

	/// zh-CN: '安全私密'
	String get step2Title => '安全私密';

	/// zh-CN: '端到端加密 保护你的个人时刻只属于你自己。'
	String get step2Desc => '端到端加密 保护你的个人时刻只属于你自己。';

	/// zh-CN: '准备探索？'
	String get step3Title => '准备探索？';

	/// zh-CN: '加入一个充满活力的社区。 让对话开始吧！'
	String get step3Desc => '加入一个充满活力的社区。 让对话开始吧！';

	/// zh-CN: '下一步'
	String get next => '下一步';

	/// zh-CN: '开始使用'
	String get getStarted => '开始使用';

	/// zh-CN: '跳过'
	String get skip => '跳过';
}

// Path: workspace
class Translations$workspace$zh_CN {
	Translations$workspace$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '概览'
	String get navOverview => '概览';

	/// zh-CN: '项目'
	String get navProjects => '项目';

	/// zh-CN: '频道'
	String get navChannels => '频道';

	/// zh-CN: '群组'
	String get navGroups => '群组';

	/// zh-CN: '我的工作区'
	String get pickerTitle => '我的工作区';

	/// zh-CN: '切换工作区'
	String get switchWorkspace => '切换工作区';

	/// zh-CN: '还没有工作区'
	String get pickerEmptyTitle => '还没有工作区';

	/// zh-CN: '创建一个工作区，3 分钟开启团队协作（自动创建 Announcements 频道与 General 群）'
	String get pickerEmptySubtitle => '创建一个工作区，3 分钟开启团队协作（自动创建 Announcements 频道与 General 群）';

	/// zh-CN: '已归档'
	String get archivedBadge => '已归档';

	/// zh-CN: '请先选择或创建一个工作区'
	String get emptyNoWorkspace => '请先选择或创建一个工作区';

	/// zh-CN: '日程'
	String get tabSchedule => '日程';

	/// zh-CN: '待办'
	String get tabTodo => '待办';

	/// zh-CN: '即将上线'
	String get comingSoon => '即将上线';

	/// zh-CN: '智能助理'
	String get assistantEntry => '智能助理';

	/// zh-CN: '未认证'
	String get orgUnverified => '未认证';

	/// zh-CN: '我的名片'
	String get myCard => '我的名片';

	/// zh-CN: '高级功能'
	String get advancedFeatures => '高级功能';

	/// zh-CN: '创建 / 加入企业'
	String get createOrJoinEnterprise => '创建 / 加入企业';

	/// zh-CN: '未读'
	String get filterUnread => '未读';

	/// zh-CN: '@我'
	String get filterMentions => '@我';

	/// zh-CN: '单聊'
	String get filterDm => '单聊';

	/// zh-CN: '内部聊天'
	String get filterInternalChat => '内部聊天';

	/// zh-CN: '外部聊天'
	String get filterExternalChat => '外部聊天';

	/// zh-CN: '标记'
	String get filterFlagged => '标记';

	/// zh-CN: '编辑'
	String get filterEdit => '编辑';

	/// zh-CN: '暂无符合条件的会话'
	String get filterEmptyTitle => '暂无符合条件的会话';

	/// zh-CN: '暂无未读会话'
	String get filterUnreadEmptyTitle => '暂无未读会话';

	/// zh-CN: '暂无待办'
	String get todoEmptyTitle => '暂无待办';

	/// zh-CN: '功能开发中'
	String get featureComingSoon => '功能开发中';

	/// zh-CN: '记录面聊'
	String get recordFaceChat => '记录面聊';

	/// zh-CN: '智能总结'
	String get smartSummary => '智能总结';

	/// zh-CN: '休息一下'
	String get takeABreak => '休息一下';

	/// zh-CN: '个人'
	String get experienceModePersonal => '个人';

	/// zh-CN: '切换到个人'
	String get switchToPersonal => '切换到个人';

	/// zh-CN: '创建工作区'
	String get createTitle => '创建工作区';

	/// zh-CN: '一次创建，自动完成：工作区、你（Owner 工作区成员身份）、Announcements 频道与 General 群。全部成功或全部回滚。'
	String get createDesc => '一次创建，自动完成：工作区、你（Owner 工作区成员身份）、Announcements 频道与 General 群。全部成功或全部回滚。';

	/// zh-CN: '工作区名称'
	String get createNameLabel => '工作区名称';

	/// zh-CN: '例如：官网改版项目组'
	String get createNameHint => '例如：官网改版项目组';

	/// zh-CN: '工作区名称不能为空'
	String get createNameRequired => '工作区名称不能为空';

	/// zh-CN: '创建'
	String get createSubmit => '创建';

	/// zh-CN: '创建工作区'
	String get createEntry => '创建工作区';

	/// zh-CN: '工作区创建成功'
	String get createSuccess => '工作区创建成功';

	/// zh-CN: '已存在同名工作区，直接进入'
	String get createIdempotentHit => '已存在同名工作区，直接进入';

	/// zh-CN: '将自动初始化'
	String get createTemplateTitle => '将自动初始化';

	/// zh-CN: 'Announcements 频道（你成为频道发布者与订阅者）'
	String get createTemplateChannel => 'Announcements 频道（你成为频道发布者与订阅者）';

	/// zh-CN: 'General 群（你成为群成员）'
	String get createTemplateGroup => 'General 群（你成为群成员）';

	/// zh-CN: '你成为工作区 Owner（工作区成员）'
	String get createTemplateOwner => '你成为工作区 Owner（工作区成员）';

	/// zh-CN: '概览'
	String get overviewTitle => '概览';

	/// zh-CN: '资源摘要'
	String get overviewResources => '资源摘要';

	/// zh-CN: '频道置顶内容'
	String get overviewPinnedContent => '频道置顶内容';

	/// zh-CN: '频道暂无置顶内容；群公告不在此聚合（群公告属于各个群）'
	String get overviewPinnedEmpty => '频道暂无置顶内容；群公告不在此聚合（群公告属于各个群）';

	/// zh-CN: '最近文件'
	String get overviewRecentFiles => '最近文件';

	/// zh-CN: '最近上传的文件将在此展示；也可在各频道内查看附件'
	String get overviewRecentFilesEmpty => '最近上传的文件将在此展示；也可在各频道内查看附件';

	/// zh-CN: '工作区成员'
	String get membersTitle => '工作区成员';

	/// zh-CN: '$count 位成员'
	String membersCountLabel({required Object count}) => '${count} 位成员';

	/// zh-CN: '暂无工作区成员'
	String get membersEmpty => '暂无工作区成员';

	/// zh-CN: '邀请已注册用户成为工作区成员（Owner / Member / Guest）'
	String get membersEmptySubtitle => '邀请已注册用户成为工作区成员（Owner / Member / Guest）';

	/// zh-CN: '查看全部'
	String get membersViewAll => '查看全部';

	/// zh-CN: '还没有项目'
	String get projectsEmptyTitle => '还没有项目';

	/// zh-CN: '项目用于跟踪明确的交付目标；只有频道和群的社区型工作区同样成立'
	String get projectsEmptySubtitle => '项目用于跟踪明确的交付目标；只有频道和群的社区型工作区同样成立';

	/// zh-CN: '还没有工作区频道'
	String get channelsEmptyTitle => '还没有工作区频道';

	/// zh-CN: '频道用于持续发布内容（公告/资料），讨论请去群组'
	String get channelsEmptySubtitle => '频道用于持续发布内容（公告/资料），讨论请去群组';

	/// zh-CN: '$count 位订阅者'
	String channelTileSubtitle({required Object count}) => '${count} 位订阅者';

	/// zh-CN: '频道'
	String get channelDetailTitle => '频道';

	/// zh-CN: '还没有工作区群组'
	String get groupsEmptyTitle => '还没有工作区群组';

	/// zh-CN: '群组是工作区里的实时讨论空间（聊天唯一入口）'
	String get groupsEmptySubtitle => '群组是工作区里的实时讨论空间（聊天唯一入口）';

	/// zh-CN: '$count 位群成员'
	String groupTileSubtitle({required Object count}) => '${count} 位群成员';

	/// zh-CN: '邀请工作区成员'
	String get inviteTitle => '邀请工作区成员';

	/// zh-CN: '仅支持邀请已注册用户；加入工作区不自动入群或订阅频道——可同时加入 General 群，并发送 Announcements 频道邀请'
	String get inviteDesc => '仅支持邀请已注册用户；加入工作区不自动入群或订阅频道——可同时加入 General 群，并发送 Announcements 频道邀请';

	/// zh-CN: '按用户名 / 用户 ID 搜索'
	String get inviteSearchHint => '按用户名 / 用户 ID 搜索';

	/// zh-CN: '邀请工作区成员'
	String get inviteEntry => '邀请工作区成员';

	/// zh-CN: '同时加入 General 群（成为群成员）'
	String get inviteJoinGroupOption => '同时加入 General 群（成为群成员）';

	/// zh-CN: '同时发送 Announcements 频道邀请'
	String get inviteSubscribeChannelOption => '同时发送 Announcements 频道邀请';

	/// zh-CN: '未找到对应资源，该选项不可用'
	String get inviteOptionUnavailable => '未找到对应资源，该选项不可用';

	/// zh-CN: '发送邀请'
	String get inviteSubmit => '发送邀请';

	/// zh-CN: '结果（三条独立）'
	String get inviteResultsTitle => '结果（三条独立）';

	/// zh-CN: '加入工作区（成为工作区成员）'
	String get inviteResultWorkspace => '加入工作区（成为工作区成员）';

	/// zh-CN: '加入 General 群（成为群成员）'
	String get inviteResultGroup => '加入 General 群（成为群成员）';

	/// zh-CN: '发送 Announcements 频道邀请（对方接受后成为订阅者）'
	String get inviteResultChannel => '发送 Announcements 频道邀请（对方接受后成为订阅者）';

	/// zh-CN: '未执行'
	String get resultIdle => '未执行';

	/// zh-CN: '进行中'
	String get resultRunning => '进行中';

	/// zh-CN: '成功'
	String get resultSuccess => '成功';

	/// zh-CN: '失败'
	String get resultFailed => '失败';

	/// zh-CN: '加入工作区'
	String get joinEntry => '加入工作区';

	/// zh-CN: '用团队码加入工作区'
	String get joinByTeamCode => '用团队码加入工作区';

	/// zh-CN: '加入工作区'
	String get joinTitle => '加入工作区';

	/// zh-CN: '输入团队码即可加入工作区'
	String get joinDesc => '输入团队码即可加入工作区';

	/// zh-CN: '团队码'
	String get joinCodeLabel => '团队码';

	/// zh-CN: '8 位大写字母或数字'
	String get joinCodeHint => '8 位大写字母或数字';

	/// zh-CN: '加入'
	String get joinSubmit => '加入';

	/// zh-CN: '已加入「$name」'
	String joinSuccess({required Object name}) => '已加入「${name}」';

	/// zh-CN: '你已在该工作区中'
	String get joinAlreadyMember => '你已在该工作区中';

	/// zh-CN: '团队码无效或已失效'
	String get joinInvalidCode => '团队码无效或已失效';

	/// zh-CN: '团队码已过期'
	String get joinExpiredCode => '团队码已过期';

	/// zh-CN: '团队码邀请'
	String get inviteCodeSectionTitle => '团队码邀请';

	/// zh-CN: '生成团队码'
	String get inviteCodeGenerate => '生成团队码';

	/// zh-CN: '复制'
	String get inviteCodeCopy => '复制';

	/// zh-CN: '撤销'
	String get inviteCodeRevoke => '撤销';

	/// zh-CN: '有效期至 $expiresAt'
	String inviteCodeExpiresAt({required Object expiresAt}) => '有效期至 ${expiresAt}';

	/// zh-CN: 'Owner'
	String get roleOwner => 'Owner';

	/// zh-CN: 'Member'
	String get roleMember => 'Member';

	/// zh-CN: 'Guest'
	String get roleGuest => 'Guest';

	/// zh-CN: '移除工作区成员 $name'
	String removeMemberTitle({required Object name}) => '移除工作区成员 ${name}';

	/// zh-CN: '移除后其工作区访问即失效；若其仍有未完成任务或负责的项目，服务端会返回冲突清单并取消本次移除'
	String get removeMemberDesc => '移除后其工作区访问即失效；若其仍有未完成任务或负责的项目，服务端会返回冲突清单并取消本次移除';

	/// zh-CN: '确认移除'
	String get removeMemberConfirm => '确认移除';

	/// zh-CN: '修改 $name 的工作区角色'
	String changeRoleTitle({required Object name}) => '修改 ${name} 的工作区角色';

	/// zh-CN: '转移主 Owner 给 $name'
	String transferTitle({required Object name}) => '转移主 Owner 给 ${name}';

	/// zh-CN: '转移后你成为普通工作区成员（Member），对方获得全部治理权'
	String get transferDesc => '转移后你成为普通工作区成员（Member），对方获得全部治理权';

	/// zh-CN: '确认转移'
	String get transferConfirm => '确认转移';

	/// zh-CN: '工作区治理'
	String get governanceTitle => '工作区治理';

	/// zh-CN: '品牌设置（名称 / Logo / 主色）'
	String get brandingEntry => '品牌设置（名称 / Logo / 主色）';

	/// zh-CN: '归档工作区'
	String get archiveEntry => '归档工作区';

	/// zh-CN: '恢复工作区'
	String get restoreEntry => '恢复工作区';

	/// zh-CN: '归档工作区'
	String get archiveTitle => '归档工作区';

	/// zh-CN: '归档后全员只读（写操作被服务端拒绝），可随时恢复'
	String get archiveDesc => '归档后全员只读（写操作被服务端拒绝），可随时恢复';

	/// zh-CN: '确认归档'
	String get archiveConfirm => '确认归档';

	/// zh-CN: '恢复工作区'
	String get restoreTitle => '恢复工作区';

	/// zh-CN: '恢复后工作区恢复读写'
	String get restoreDesc => '恢复后工作区恢复读写';

	/// zh-CN: '确认恢复'
	String get restoreConfirm => '确认恢复';

	/// zh-CN: '工作区已归档：内容可查看，写操作已禁用；Owner 可在成员页恢复'
	String get archivedBanner => '工作区已归档：内容可查看，写操作已禁用；Owner 可在成员页恢复';

	/// zh-CN: '工作区品牌'
	String get brandingTitle => '工作区品牌';

	/// zh-CN: '品牌名称'
	String get brandingNameLabel => '品牌名称';

	/// zh-CN: 'Logo 地址'
	String get brandingLogoLabel => 'Logo 地址';

	/// zh-CN: 'https://...（工作区 Logo 图片地址）'
	String get brandingLogoHint => 'https://...（工作区 Logo 图片地址）';

	/// zh-CN: '主色 primaryColor'
	String get brandingColorLabel => '主色 primaryColor';

	/// zh-CN: '#2474E5'
	String get brandingColorHint => '#2474E5';

	/// zh-CN: '仅支持 #RRGGBB / #AARRGGBB；非法值回落默认主题色'
	String get brandingColorHelper => '仅支持 #RRGGBB / #AARRGGBB；非法值回落默认主题色';

	/// zh-CN: '主色格式不正确，仅支持 #RRGGBB / #AARRGGBB'
	String get brandingColorInvalid => '主色格式不正确，仅支持 #RRGGBB / #AARRGGBB';

	/// zh-CN: '品牌设置已保存'
	String get brandingSaved => '品牌设置已保存';

	/// zh-CN: '主色预览'
	String get brandingPreview => '主色预览';

	/// zh-CN: '当前主色将在工作区内生效'
	String get brandingPreviewApplied => '当前主色将在工作区内生效';

	/// zh-CN: '未设置或非法值，使用默认主题色'
	String get brandingPreviewFallback => '未设置或非法值，使用默认主题色';

	/// zh-CN: '新建项目'
	String get projectCreateEntry => '新建项目';

	/// zh-CN: '新建项目'
	String get projectCreateTitle => '新建项目';

	/// zh-CN: '项目名称'
	String get projectNameLabel => '项目名称';

	/// zh-CN: '例如：官网改版'
	String get projectNameHint => '例如：官网改版';

	/// zh-CN: '项目名称不能为空'
	String get projectNameRequired => '项目名称不能为空';

	/// zh-CN: '项目描述（可选）'
	String get projectDescLabel => '项目描述（可选）';

	/// zh-CN: '这个项目要交付什么？'
	String get projectDescHint => '这个项目要交付什么？';

	/// zh-CN: '创建'
	String get projectSubmit => '创建';

	/// zh-CN: '项目创建成功'
	String get projectCreateSuccess => '项目创建成功';

	/// zh-CN: '项目详情'
	String get projectDetailTitle => '项目详情';

	/// zh-CN: '负责人'
	String get projectOwnerLabel => '负责人';

	/// zh-CN: '状态'
	String get projectStatusLabel => '状态';

	/// zh-CN: '进行中'
	String get projectStatusActive => '进行中';

	/// zh-CN: '已完成'
	String get projectStatusDone => '已完成';

	/// zh-CN: '标记为已完成'
	String get projectMarkDone => '标记为已完成';

	/// zh-CN: '重新开启项目'
	String get projectReopen => '重新开启项目';

	/// zh-CN: '项目状态已更新'
	String get projectStatusChanged => '项目状态已更新';

	/// zh-CN: '任务'
	String get projectTasksSection => '任务';

	/// zh-CN: '新建任务'
	String get taskNewEntry => '新建任务';

	/// zh-CN: '新建任务'
	String get taskFormCreateTitle => '新建任务';

	/// zh-CN: '编辑任务'
	String get taskFormEditTitle => '编辑任务';

	/// zh-CN: '任务标题'
	String get taskTitleLabel => '任务标题';

	/// zh-CN: '任务标题不能为空'
	String get taskTitleRequired => '任务标题不能为空';

	/// zh-CN: '负责人（工作区成员）'
	String get taskAssigneeLabel => '负责人（工作区成员）';

	/// zh-CN: '暂不指派'
	String get taskAssigneeNone => '暂不指派';

	/// zh-CN: '刷新负责人候选'
	String get taskAssigneeRefresh => '刷新负责人候选';

	/// zh-CN: '创建任务'
	String get taskSubmitCreate => '创建任务';

	/// zh-CN: '保存'
	String get taskSubmitSave => '保存';

	/// zh-CN: '任务已创建'
	String get taskCreatedToast => '任务已创建';

	/// zh-CN: '相同标题的任务已存在，直接使用既有任务'
	String get taskExistingToast => '相同标题的任务已存在，直接使用既有任务';

	/// zh-CN: '任务已保存'
	String get taskUpdatedToast => '任务已保存';

	/// zh-CN: '全部'
	String get taskFilterAll => '全部';

	/// zh-CN: '待办'
	String get taskStatusTodo => '待办';

	/// zh-CN: '进行中'
	String get taskStatusDoing => '进行中';

	/// zh-CN: '评审中'
	String get taskStatusReview => '评审中';

	/// zh-CN: '已完成'
	String get taskStatusDone => '已完成';

	/// zh-CN: '推进到「$status」'
	String taskAdvanceTo({required Object status}) => '推进到「${status}」';

	/// zh-CN: '回退 $title 到...'
	String taskFallbackMenuTitle({required Object title}) => '回退 ${title} 到...';

	/// zh-CN: '已流转到「$status」'
	String taskStatusMovedToast({required Object status}) => '已流转到「${status}」';

	/// zh-CN: '还没有任务'
	String get taskEmptyTitle => '还没有任务';

	/// zh-CN: '用四态跟踪执行：待办 → 进行中 → 评审中 → 已完成'
	String get taskEmptySubtitle => '用四态跟踪执行：待办 → 进行中 → 评审中 → 已完成';

	/// zh-CN: '加载更多'
	String get projectsLoadMore => '加载更多';

	/// zh-CN: '项目协作'
	String get projectW2SectionTitle => '项目协作';

	/// zh-CN: '成员'
	String get projectMembersEntry => '成员';

	/// zh-CN: '里程碑'
	String get projectMilestonesEntry => '里程碑';

	/// zh-CN: '项目频道'
	String get projectChannelsEntry => '项目频道';

	/// zh-CN: '内容聚合'
	String get projectInsightsEntry => '内容聚合';

	/// zh-CN: '无权限：仅项目成员、项目负责人或工作区 Owner 可查看'
	String get projectNoPermission => '无权限：仅项目成员、项目负责人或工作区 Owner 可查看';

	/// zh-CN: '访客（Guest）身份对项目只读'
	String get projectGuestReadonly => '访客（Guest）身份对项目只读';

	/// zh-CN: '加载更多'
	String get projectLoadMore => '加载更多';

	/// zh-CN: '项目成员'
	String get projectMembersTitle => '项目成员';

	/// zh-CN: '还没有项目成员'
	String get projectMemberEmptyTitle => '还没有项目成员';

	/// zh-CN: '项目负责人可邀请已注册用户加入此项目'
	String get projectMemberEmptySubtitle => '项目负责人可邀请已注册用户加入此项目';

	/// zh-CN: '邀请项目成员'
	String get projectMemberInviteTitle => '邀请项目成员';

	/// zh-CN: '要邀请的已注册用户 ID'
	String get projectMemberInviteFieldHint => '要邀请的已注册用户 ID';

	/// zh-CN: '请输入有效的用户 ID'
	String get projectMemberInviteInvalidUid => '请输入有效的用户 ID';

	/// zh-CN: '邀请'
	String get projectMemberInviteSubmit => '邀请';

	/// zh-CN: '已加入项目成员'
	String get projectMemberInviteSuccess => '已加入项目成员';

	/// zh-CN: '该用户已是项目成员'
	String get projectMemberInviteExisting => '该用户已是项目成员';

	/// zh-CN: '移除项目成员 $name'
	String projectMemberRemoveConfirmTitle({required Object name}) => '移除项目成员 ${name}';

	/// zh-CN: '移除后该用户将失去此项目内容的访问（可重新邀请）'
	String get projectMemberRemoveConfirmDesc => '移除后该用户将失去此项目内容的访问（可重新邀请）';

	/// zh-CN: '移除'
	String get projectMemberRemoveSubmit => '移除';

	/// zh-CN: '已移除'
	String get projectMemberRemovedToast => '已移除';

	/// zh-CN: '该用户已不在项目成员中'
	String get projectMemberAlreadyRemovedToast => '该用户已不在项目成员中';

	/// zh-CN: '转移项目负责人给 $name'
	String projectMemberTransferTitle({required Object name}) => '转移项目负责人给 ${name}';

	/// zh-CN: '转移后对方获得此项目的完全管理权'
	String get projectMemberTransferDesc => '转移后对方获得此项目的完全管理权';

	/// zh-CN: '确认转移'
	String get projectMemberTransferConfirm => '确认转移';

	/// zh-CN: '项目负责人已转移'
	String get projectMemberTransferDoneToast => '项目负责人已转移';

	/// zh-CN: '里程碑'
	String get projectMilestonesTitle => '里程碑';

	/// zh-CN: '还没有里程碑'
	String get projectMilestoneEmptyTitle => '还没有里程碑';

	/// zh-CN: '用里程碑标记项目的关键节点（计划中 → 已达成，单向）'
	String get projectMilestoneEmptySubtitle => '用里程碑标记项目的关键节点（计划中 → 已达成，单向）';

	/// zh-CN: '新建里程碑'
	String get projectMilestoneCreateTitle => '新建里程碑';

	/// zh-CN: '名称'
	String get projectMilestoneNameLabel => '名称';

	/// zh-CN: '里程碑名称不能为空'
	String get projectMilestoneNameRequired => '里程碑名称不能为空';

	/// zh-CN: '截止日期（YYYY-MM-DD，可选）'
	String get projectMilestoneDueDateLabel => '截止日期（YYYY-MM-DD，可选）';

	/// zh-CN: '日期格式应为 YYYY-MM-DD'
	String get projectMilestoneDueDateInvalid => '日期格式应为 YYYY-MM-DD';

	/// zh-CN: '创建'
	String get projectMilestoneCreateSubmit => '创建';

	/// zh-CN: '里程碑已创建'
	String get projectMilestoneCreatedToast => '里程碑已创建';

	/// zh-CN: '全部'
	String get projectMilestoneFilterAll => '全部';

	/// zh-CN: '计划中'
	String get projectMilestoneFilterPlanned => '计划中';

	/// zh-CN: '已达成'
	String get projectMilestoneFilterReached => '已达成';

	/// zh-CN: '标记达成'
	String get projectMilestoneReach => '标记达成';

	/// zh-CN: '里程碑已达成'
	String get projectMilestoneReachedToast => '里程碑已达成';

	/// zh-CN: '该里程碑已达成'
	String get projectMilestoneAlreadyReachedToast => '该里程碑已达成';

	/// zh-CN: '已达成（不可回退）'
	String get projectMilestoneReachedHint => '已达成（不可回退）';

	/// zh-CN: '截止'
	String get projectMilestoneDueLabel => '截止';

	/// zh-CN: '项目频道'
	String get projectChannelsTitle => '项目频道';

	/// zh-CN: '还没有关联频道'
	String get projectChannelEmptyTitle => '还没有关联频道';

	/// zh-CN: '关联工作区频道后，其置顶内容与最近帖子会聚合进本项目'
	String get projectChannelEmptySubtitle => '关联工作区频道后，其置顶内容与最近帖子会聚合进本项目';

	/// zh-CN: '选择要关联的频道'
	String get projectChannelLinkTitle => '选择要关联的频道';

	/// zh-CN: '没有可关联的候选频道'
	String get projectChannelNoCandidate => '没有可关联的候选频道';

	/// zh-CN: '频道已关联'
	String get projectChannelLinkedToast => '频道已关联';

	/// zh-CN: '该频道已关联'
	String get projectChannelLinkExistingToast => '该频道已关联';

	/// zh-CN: '解除关联 $name'
	String projectChannelUnlinkTitle({required Object name}) => '解除关联 ${name}';

	/// zh-CN: '解除后该频道内容不再聚合进本项目'
	String get projectChannelUnlinkDesc => '解除后该频道内容不再聚合进本项目';

	/// zh-CN: '解除关联'
	String get projectChannelUnlinkSubmit => '解除关联';

	/// zh-CN: '已解除关联'
	String get projectChannelUnlinkedToast => '已解除关联';

	/// zh-CN: '置顶消息'
	String get projectInsightsTabPinned => '置顶消息';

	/// zh-CN: '资源链接'
	String get projectInsightsTabResources => '资源链接';

	/// zh-CN: '项目动态'
	String get projectInsightsTabActivity => '项目动态';

	/// zh-CN: '相关帖子'
	String get projectInsightsTabPosts => '相关帖子';

	/// zh-CN: '关联频道暂无置顶内容'
	String get projectInsightsPinnedEmpty => '关联频道暂无置顶内容';

	/// zh-CN: '项目暂无资源链接'
	String get projectInsightsResourcesEmpty => '项目暂无资源链接';

	/// zh-CN: '项目暂无动态'
	String get projectInsightsActivityEmpty => '项目暂无动态';

	/// zh-CN: '关联频道暂无帖子'
	String get projectInsightsPostsEmpty => '关联频道暂无帖子';

	/// zh-CN: '$name 发布'
	String projectInsightsPostAuthor({required Object name}) => '${name} 发布';

	/// zh-CN: '内容已暂时隐藏，等待重新授权'
	String get contentProtectedPending => '内容已暂时隐藏，等待重新授权';

	/// zh-CN: '重新验证'
	String get contentProtectedRetry => '重新验证';

	/// zh-CN: '你已无权查看此工作区内容'
	String get contentRevoked => '你已无权查看此工作区内容';
}

// Path: account.alipaySim
class Translations$account$alipaySim$zh_CN {
	Translations$account$alipaySim$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '选择支付方式'
	String get selectMethod => '选择支付方式';

	/// zh-CN: '确认付款'
	String get confirmPay => '确认付款';

	/// zh-CN: '请输入支付密码'
	String get enterPassword => '请输入支付密码';

	/// zh-CN: '支付成功'
	String get alipaySuccess => '支付成功';

	/// zh-CN: '花呗分期'
	String get huabei => '花呗分期';

	/// zh-CN: '支付成功得绿色能量 5g'
	String get energy => '支付成功得绿色能量 5g';

	/// zh-CN: '信息科技旗舰店'
	String get storeName => '信息科技旗舰店';

	/// zh-CN: '金额：'
	String get paymentAmount => '金额：';

	/// zh-CN: '账户余额'
	String get balanceSource => '账户余额';
}

// Path: customerService.governance
class Translations$customerService$governance$zh_CN {
	Translations$customerService$governance$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '客服治理'
	String get title => '客服治理';

	/// zh-CN: '本页为企业治理面（owner/admin）；服务端 403 是最终权限裁决。'
	String get scopeNote => '本页为企业治理面（owner/admin）；服务端 403 是最终权限裁决。';

	/// zh-CN: '席位额度'
	String get limitCardTitle => '席位额度';

	/// zh-CN: '不限'
	String get limitUnlimited => '不限';

	/// zh-CN: '${used}/${limit} 席位'
	String limitValueLabel({required Object used, required Object limit}) => '${used}/${limit} 席位';

	/// zh-CN: '已达上限'
	String get limitAtCapacity => '已达上限';

	/// zh-CN: '调整额度'
	String get limitAdjustAction => '调整额度';

	/// zh-CN: '调整席位额度'
	String get limitAdjustTitle => '调整席位额度';

	/// zh-CN: '席位上限（正整数，留空 = 不限）'
	String get limitInputLabel => '席位上限（正整数，留空 = 不限）';

	/// zh-CN: '清除限制（不限）'
	String get limitClearAction => '清除限制（不限）';

	/// zh-CN: '请输入正整数'
	String get limitInvalidInput => '请输入正整数';

	/// zh-CN: '额度已更新'
	String get limitSaved => '额度已更新';

	/// zh-CN: '坐席席位'
	String get seatsSectionTitle => '坐席席位';

	/// zh-CN: '暂无坐席席位'
	String get seatsEmpty => '暂无坐席席位';

	/// zh-CN: '启用'
	String get seatEnabledBadge => '启用';

	/// zh-CN: '已停用'
	String get seatSuspendedBadge => '已停用';

	/// zh-CN: '坐席 ${identity}'
	String seatIdentityLabel({required Object identity}) => '坐席 ${identity}';

	/// zh-CN: '${active}/${max} 会话'
	String seatCapacityLabel({required Object active, required Object max}) => '${active}/${max} 会话';

	/// zh-CN: '加载更多'
	String get seatLoadMore => '加载更多';

	/// zh-CN: '停用坐席'
	String get suspendAction => '停用坐席';

	/// zh-CN: '启用坐席'
	String get resumeAction => '启用坐席';

	/// zh-CN: '停用该坐席？'
	String get suspendConfirmTitle => '停用该坐席？';

	/// zh-CN: '停用后不能再接新会话；进行中的会话不受影响，可随时再启用。'
	String get suspendConfirmBody => '停用后不能再接新会话；进行中的会话不受影响，可随时再启用。';

	/// zh-CN: '操作已生效'
	String get actionDone => '操作已生效';

	/// zh-CN: '操作失败，请稍后重试'
	String get actionFailed => '操作失败，请稍后重试';

	/// zh-CN: '无治理权限：客服治理仅对企业 owner/admin 开放'
	String get errorForbidden => '无治理权限：客服治理仅对企业 owner/admin 开放';

	/// zh-CN: '企业未设置默认工作区，无法确定客服治理作用域'
	String get errorNoDefaultWorkspace => '企业未设置默认工作区，无法确定客服治理作用域';

	/// zh-CN: '加载失败'
	String get errorLoadFailed => '加载失败';

	/// zh-CN: '${msg}（${code}）'
	String errorWithCode({required Object msg, required Object code}) => '${msg}（${code}）';

	/// zh-CN: '席位额度已满：已用 ${used}/${limit}，无法新增坐席（seat_limit_exceeded）'
	String seatLimitExceededHint({required Object used, required Object limit}) => '席位额度已满：已用 ${used}/${limit}，无法新增坐席（seat_limit_exceeded）';

	/// zh-CN: '重试'
	String get retry => '重试';
}

// Path: organization.common
class Translations$organization$common$zh_CN {
	Translations$organization$common$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '更多操作'
	String get moreActions => '更多操作';

	/// zh-CN: '重命名'
	String get rename => '重命名';

	/// zh-CN: '关闭'
	String get close => '关闭';

	/// zh-CN: '重新加载'
	String get reload => '重新加载';

	/// zh-CN: '创建失败'
	String get createFailed => '创建失败';

	/// zh-CN: '添加失败'
	String get addFailed => '添加失败';

	/// zh-CN: '确认归档'
	String get confirmArchive => '确认归档';

	/// zh-CN: '无权执行该操作（403）'
	String get forbidden403 => '无权执行该操作（403）';

	/// zh-CN: '暂无成员'
	String get noMembers => '暂无成员';

	/// zh-CN: '对方用户 UID（数字）'
	String get targetUidHint => '对方用户 UID（数字）';

	/// zh-CN: '用户 UID 必须是正整数'
	String get uidMustBePositive => '用户 UID 必须是正整数';

	/// zh-CN: '加载中…'
	String get loading => '加载中…';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '审核中'
	String get orgStatusPending => '审核中';

	/// zh-CN: '未通过审核'
	String get orgStatusRejected => '未通过审核';
}

// Path: organization.home
class Translations$organization$home$zh_CN {
	Translations$organization$home$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '创建企业'
	String get createOrg => '创建企业';

	/// zh-CN: '企业名称（1-200 字符）'
	String get orgNameLabel => '企业名称（1-200 字符）';

	/// zh-CN: '创建失败：${msg} (${code})'
	String createFailedWith({required Object msg, required Object code}) => '创建失败：${msg} (${code})';

	/// zh-CN: '已提交，等待运营审核，审核通过后企业可正常使用'
	String get createSubmittedPendingReview => '已提交，等待运营审核，审核通过后企业可正常使用';

	/// zh-CN: '企业'
	String get tabOrg => '企业';

	/// zh-CN: '我的邀请'
	String get myInvitations => '我的邀请';

	/// zh-CN: '尚未加入任何企业 下拉刷新或点击右上角创建'
	String get emptyHint => '尚未加入任何企业\n下拉刷新或点击右上角创建';
}

// Path: organization.detail
class Translations$organization$detail$zh_CN {
	Translations$organization$detail$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '退出企业'
	String get leaveOrg => '退出企业';

	/// zh-CN: '退出后将失去本企业的通讯录、群、频道和资料访问资格；企业资料会保留。重新加入需要邀请。'
	String get leaveOrgBody => '退出后将失去本企业的通讯录、群、频道和资料访问资格；企业资料会保留。重新加入需要邀请。';

	/// zh-CN: '退出失败'
	String get leaveFailed => '退出失败';

	/// zh-CN: '请先移交企业负责人，再退出企业'
	String get leaveOwnerHint => '请先移交企业负责人，再退出企业';

	/// zh-CN: '已退出企业，但本地偏好清理失败，请重启后重新确认空间'
	String get leaveCleanupFailed => '已退出企业，但本地偏好清理失败，请重启后重新确认空间';

	/// zh-CN: '企业详情'
	String get title => '企业详情';

	/// zh-CN: '企业不存在'
	String get notFound => '企业不存在';

	/// zh-CN: '归档企业'
	String get archiveOrg => '归档企业';

	/// zh-CN: '归档后企业进入只读态，全部写操作 fail-closed，仅恢复（restore）可解锁。成员与数据不会被删除。'
	String get archiveConfirmBody => '归档后企业进入只读态，全部写操作 fail-closed，仅恢复（restore）可解锁。成员与数据不会被删除。';

	/// zh-CN: '恢复企业'
	String get restoreOrg => '恢复企业';

	/// zh-CN: '恢复后企业回到 active 态，写入口重新开放。'
	String get restoreConfirmBody => '恢复后企业回到 active 态，写入口重新开放。';

	/// zh-CN: '确认恢复'
	String get confirmRestore => '确认恢复';

	/// zh-CN: '恢复失败'
	String get restoreFailed => '恢复失败';

	/// zh-CN: '归档失败'
	String get archiveFailed => '归档失败';

	/// zh-CN: '修改企业名称'
	String get renameOrgTitle => '修改企业名称';

	/// zh-CN: '企业名称（1-200 字符）'
	String get renameOrgLabel => '企业名称（1-200 字符）';

	/// zh-CN: '修改名称'
	String get renameAction => '修改名称';

	/// zh-CN: '改名失败'
	String get renameFailed => '改名失败';

	/// zh-CN: '账号删除预检'
	String get deletionPreflight => '账号删除预检';

	/// zh-CN: '查看本账号被哪些依赖域阻塞删除'
	String get deletionPreflightDesc => '查看本账号被哪些依赖域阻塞删除';

	/// zh-CN: '观察时刻：${ts}'
	String observedAt({required Object ts}) => '观察时刻：${ts}';

	/// zh-CN: '覆盖依赖域：${domains}'
	String factDomains({required Object domains}) => '覆盖依赖域：${domains}';

	/// zh-CN: '无阻塞项'
	String get noBlockers => '无阻塞项';

	/// zh-CN: '阻塞项：'
	String get blockers => '阻塞项：';

	/// zh-CN: '依赖域事实不可用，删除预检被拒绝（fail-closed）'
	String get factUnavailable => '依赖域事实不可用，删除预检被拒绝（fail-closed）';

	/// zh-CN: '预检失败：${msg} (${code})'
	String preflightFailed({required Object msg, required Object code}) => '预检失败：${msg} (${code})';

	/// zh-CN: '我的角色：${role} · 状态：${status}'
	String myRoleAndStatus({required Object role, required Object status}) => '我的角色：${role} · 状态：${status}';

	/// zh-CN: '企业已归档（只读）'
	String get archivedBadge => '企业已归档（只读）';

	/// zh-CN: '归档期间全部写操作被拒绝，仅恢复操作可用'
	String get archivedHint => '归档期间全部写操作被拒绝，仅恢复操作可用';

	/// zh-CN: '默认 Workspace：${id}'
	String defaultWsSet({required Object id}) => '默认 Workspace：${id}';

	/// zh-CN: '默认 Workspace：未设置'
	String get defaultWsUnset => '默认 Workspace：未设置';

	/// zh-CN: '指向事实，不代表任何 workspace 成员身份'
	String get defaultWsNote => '指向事实，不代表任何 workspace 成员身份';

	/// zh-CN: '成员列表'
	String get memberList => '成员列表';

	/// zh-CN: '成员列表（仅 owner/admin 可查看）'
	String get memberListRestricted => '成员列表（仅 owner/admin 可查看）';

	/// zh-CN: '邀请管理'
	String get invitationManage => '邀请管理';

	/// zh-CN: '邀请管理（仅 owner/admin 可管理）'
	String get invitationManageRestricted => '邀请管理（仅 owner/admin 可管理）';

	/// zh-CN: '部门目录'
	String get deptEntry => '部门目录';

	/// zh-CN: '部门目录（管理操作仅限授权者）'
	String get deptEntryRestricted => '部门目录（管理操作仅限授权者）';

	/// zh-CN: '更多'
	String get more => '更多';

	/// zh-CN: '进入只读态；可随时恢复'
	String get archiveEntrySubtitle => '进入只读态；可随时恢复';

	/// zh-CN: '回到 active 态'
	String get restoreEntrySubtitle => '回到 active 态';
}

// Path: organization.members
class Translations$organization$members$zh_CN {
	Translations$organization$members$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '成员'
	String get title => '成员';

	/// zh-CN: '加载更多失败：${err}'
	String loadMoreFailed({required Object err}) => '加载更多失败：${err}';

	/// zh-CN: '变更角色'
	String get changeRole => '变更角色';

	/// zh-CN: '将「${name}」的角色由 ${from} 调整为 ${to}。'
	String changeRoleBody({required Object name, required Object from, required Object to}) => '将「${name}」的角色由 ${from} 调整为 ${to}。';

	/// zh-CN: '确认变更'
	String get confirmChange => '确认变更';

	/// zh-CN: '角色变更失败'
	String get changeRoleFailed => '角色变更失败';

	/// zh-CN: '移除成员'
	String get removeMember => '移除成员';

	/// zh-CN: '将「${name}」移出本企业。该操作不会删除其账号。'
	String removeMemberBody({required Object name}) => '将「${name}」移出本企业。该操作不会删除其账号。';

	/// zh-CN: '确认移除'
	String get confirmRemove => '确认移除';

	/// zh-CN: '移除失败'
	String get removeFailed => '移除失败';

	/// zh-CN: '转移所有者'
	String get transferOwner => '转移所有者';

	/// zh-CN: '企业有且仅有一个 owner（C04）：确认将「${name}」设为所有者， 你将降级为普通管理员/成员。该操作直接影响企业控制权。'
	String transferOwnerBody({required Object name}) => '企业有且仅有一个 owner（C04）：确认将「${name}」设为所有者，\n你将降级为普通管理员/成员。该操作直接影响企业控制权。';

	/// zh-CN: '确认转移'
	String get confirmTransfer => '确认转移';

	/// zh-CN: '转移失败'
	String get transferFailed => '转移失败';

	/// zh-CN: '降级为成员'
	String get demoteToMember => '降级为成员';

	/// zh-CN: '升级为管理员'
	String get promoteToAdmin => '升级为管理员';

	/// zh-CN: '转移所有者给「${name}」'
	String transferOwnerTo({required Object name}) => '转移所有者给「${name}」';

	/// zh-CN: 'Owner 不可在此变更；请使用「转移所有者」'
	String get ownerCannotChangeHere => 'Owner 不可在此变更；请使用「转移所有者」';

	/// zh-CN: '查看详情'
	String get viewDetail => '查看详情';

	/// zh-CN: '暂停成员'
	String get suspendMember => '暂停成员';

	/// zh-CN: '暂停「${name}」在本企业的访问权限（即时生效；不影响其个人账号与其他企业）。可随时恢复。'
	String suspendBody({required Object name}) => '暂停「${name}」在本企业的访问权限（即时生效；不影响其个人账号与其他企业）。可随时恢复。';

	/// zh-CN: '确认暂停'
	String get confirmSuspend => '确认暂停';

	/// zh-CN: '暂停失败'
	String get suspendFailed => '暂停失败';

	/// zh-CN: '恢复成员'
	String get restoreMember => '恢复成员';

	/// zh-CN: '恢复「${name}」在本企业的访问权限。'
	String restoreBody({required Object name}) => '恢复「${name}」在本企业的访问权限。';

	/// zh-CN: '确认恢复'
	String get confirmRestoreMember => '确认恢复';

	/// zh-CN: '恢复失败'
	String get restoreFailed => '恢复失败';

	/// zh-CN: '离场（终态）'
	String get offboardMember => '离场（终态）';

	/// zh-CN: '「${name}」将离场本企业：removed 终态、不可恢复，如需再次加入须重新邀请。'
	String offboardBody({required Object name}) => '「${name}」将离场本企业：removed 终态、不可恢复，如需再次加入须重新邀请。';

	/// zh-CN: '确认离场'
	String get confirmOffboard => '确认离场';

	/// zh-CN: '离场失败'
	String get offboardFailed => '离场失败';

	/// zh-CN: '暂无成员'
	String get empty => '暂无成员';
}

// Path: organization.invitations
class Translations$organization$invitations$zh_CN {
	Translations$organization$invitations$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '邀请成员'
	String get inviteMember => '邀请成员';

	/// zh-CN: '邀请已创建'
	String get invitationCreated => '邀请已创建';

	/// zh-CN: '领取口令（token）只显示这一次，请立即复制并线下转交对方：'
	String get tokenOnceNotice => '领取口令（token）只显示这一次，请立即复制并线下转交对方：';

	/// zh-CN: '已复制口令'
	String get tokenCopied => '已复制口令';

	/// zh-CN: '复制口令'
	String get copyToken => '复制口令';

	/// zh-CN: '邀请失败：${msg} (${code})'
	String inviteFailed({required Object msg, required Object code}) => '邀请失败：${msg} (${code})';

	/// zh-CN: '接受邀请'
	String get acceptTitle => '接受邀请';

	/// zh-CN: '接受后你将加入企业 ${orgId}； 该邀请一次性生效，成员资格以服务端为准。'
	String acceptBody({required Object orgId}) => '接受后你将加入企业 ${orgId}；\n该邀请一次性生效，成员资格以服务端为准。';

	/// zh-CN: '确认接受'
	String get confirmAccept => '确认接受';

	/// zh-CN: '接受失败'
	String get acceptFailed => '接受失败';

	/// zh-CN: '拒绝邀请'
	String get rejectTitle => '拒绝邀请';

	/// zh-CN: '拒绝后该邀请进入终态，不可再接受。'
	String get rejectBody => '拒绝后该邀请进入终态，不可再接受。';

	/// zh-CN: '确认拒绝'
	String get confirmReject => '确认拒绝';

	/// zh-CN: '拒绝失败'
	String get rejectFailed => '拒绝失败';

	/// zh-CN: '撤销邀请'
	String get revokeTitle => '撤销邀请';

	/// zh-CN: '撤销后该邀请进入终态，目标用户无法再凭口令接受。'
	String get revokeBody => '撤销后该邀请进入终态，目标用户无法再凭口令接受。';

	/// zh-CN: '确认撤销'
	String get confirmRevoke => '确认撤销';

	/// zh-CN: '撤销失败'
	String get revokeFailed => '撤销失败';

	/// zh-CN: '我的邀请'
	String get myInvitations => '我的邀请';

	/// zh-CN: '邀请管理'
	String get manageInvitations => '邀请管理';

	/// zh-CN: '创建邀请'
	String get createInvitation => '创建邀请';

	/// zh-CN: '暂无邀请'
	String get empty => '暂无邀请';

	/// zh-CN: '暂无邀请记录'
	String get emptyRecord => '暂无邀请记录';

	/// zh-CN: '企业 ${orgId}'
	String orgLine({required Object orgId}) => '企业 ${orgId}';

	/// zh-CN: '邀请 ${invitationId}'
	String invitationLine({required Object invitationId}) => '邀请 ${invitationId}';

	/// zh-CN: '目标 ${targetUserId} · ${subtitle}'
	String targetLine({required Object targetUserId, required Object subtitle}) => '目标 ${targetUserId} · ${subtitle}';

	/// zh-CN: '点击邀请即可直接接受（无需口令）； 接受成功后成员资格以服务端为准。'
	String get acceptNotice => '点击邀请即可直接接受（无需口令）；\n接受成功后成员资格以服务端为准。';

	/// zh-CN: '撤销'
	String get revokeAction => '撤销';

	/// zh-CN: '接受邀请'
	String get acceptAction => '接受邀请';

	/// zh-CN: '拒绝'
	String get rejectAction => '拒绝';
}

// Path: organization.departments
class Translations$organization$departments$zh_CN {
	Translations$organization$departments$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '部门管理'
	String get title => '部门管理';

	/// zh-CN: '状态：${status}'
	String statusLine({required Object status}) => '状态：${status}';

	/// zh-CN: '成员 ${userId}'
	String memberUidLine({required Object userId}) => '成员 ${userId}';

	/// zh-CN: '无权查看该部门（仅限本企业在职成员）'
	String get viewForbiddenDetail => '无权查看该部门（仅限本企业在职成员）';

	/// zh-CN: '无权查看（仅限本企业在职成员）'
	String get viewForbidden => '无权查看（仅限本企业在职成员）';

	/// zh-CN: '加载部门失败：${msg} (${code})'
	String loadFailedWith({required Object msg, required Object code}) => '加载部门失败：${msg} (${code})';

	/// zh-CN: '加载部门失败：${err}'
	String loadFailed({required Object err}) => '加载部门失败：${err}';

	/// zh-CN: '在其下新建子部门'
	String get createSubHere => '在其下新建子部门';

	/// zh-CN: '移动（选择新父部门）'
	String get movePickParent => '移动（选择新父部门）';

	/// zh-CN: '添加成员（按 UID）'
	String get addMemberByUid => '添加成员（按 UID）';

	/// zh-CN: '归档部门'
	String get archiveDept => '归档部门';

	/// zh-CN: '新建根部门'
	String get createRootDept => '新建根部门';

	/// zh-CN: '部门名称'
	String get deptNameLabel => '部门名称';

	/// zh-CN: '在「${parent}」下新建'
	String createUnder({required Object parent}) => '在「${parent}」下新建';

	/// zh-CN: '重命名部门'
	String get renameDept => '重命名部门';

	/// zh-CN: '新名称'
	String get newNameLabel => '新名称';

	/// zh-CN: '重命名失败'
	String get renameFailed => '重命名失败';

	/// zh-CN: '移动部门'
	String get moveDept => '移动部门';

	/// zh-CN: '企业根目录'
	String get rootLevel => '企业根目录';

	/// zh-CN: '移动失败'
	String get moveFailed => '移动失败';

	/// zh-CN: '添加部门成员'
	String get addDeptMember => '添加部门成员';

	/// zh-CN: '归档「${name}」后该部门进入只读态（成员关系保留）。'
	String archiveConfirmBody({required Object name}) => '归档「${name}」后该部门进入只读态（成员关系保留）。';

	/// zh-CN: '归档失败'
	String get archiveFailed => '归档失败';

	/// zh-CN: '暂无部门，点击右上角新建'
	String get emptyWithHint => '暂无部门，点击右上角新建';

	/// zh-CN: '暂无部门'
	String get empty => '暂无部门';

	/// zh-CN: '兼职模型：同一成员可属多个部门；部门成员须先是本企业成员。'
	String get emptySubtitle => '兼职模型：同一成员可属多个部门；部门成员须先是本企业成员。';

	/// zh-CN: '部门已被并发修改，已刷新为最新部门树，请重试操作'
	String get casConflictHint => '部门已被并发修改，已刷新为最新部门树，请重试操作';

	/// zh-CN: '展开「${name}」'
	String expandNode({required Object name}) => '展开「${name}」';

	/// zh-CN: '收起「${name}」'
	String collapseNode({required Object name}) => '收起「${name}」';

	/// zh-CN: '移除成员 ${userId}'
	String removeMemberUid({required Object userId}) => '移除成员 ${userId}';

	/// zh-CN: '将把成员 ${userId} 移出「${name}」。其企业成员资格与在其他部门的身份不受影响（兼职模型）。'
	String removeMemberConfirm({required Object userId, required Object name}) => '将把成员 ${userId} 移出「${name}」。其企业成员资格与在其他部门的身份不受影响（兼职模型）。';

	/// zh-CN: '移除部门成员失败'
	String get removeMemberFailed => '移除部门成员失败';

	/// zh-CN: '确认移除'
	String get confirmRemoveMember => '确认移除';

	/// zh-CN: '设 ${userId} 为部门管理员'
	String setDeptAdmin({required Object userId}) => '设 ${userId} 为部门管理员';

	/// zh-CN: '取消 ${userId} 的部门管理员'
	String unsetDeptAdmin({required Object userId}) => '取消 ${userId} 的部门管理员';

	/// zh-CN: '设置部门管理员失败'
	String get setAdminFailed => '设置部门管理员失败';

	/// zh-CN: '成员治理操作'
	String get memberGovernActions => '成员治理操作';
}

// Path: organization.picker
class Translations$organization$picker$zh_CN {
	Translations$organization$picker$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '切换企业'
	String get title => '切换企业';

	/// zh-CN: '切换企业'
	String get switchEnterprise => '切换企业';

	/// zh-CN: '切换失败'
	String get switchFailed => '切换失败';

	/// zh-CN: '切换失败，已恢复原选择'
	String get switchFailedRecovered => '切换失败，已恢复原选择';

	/// zh-CN: '未选择企业'
	String get noneSelected => '未选择企业';

	/// zh-CN: '尚未加入任何企业 点击下方「加入企业」输入企业邀请码'
	String get emptyHint => '尚未加入任何企业\n点击下方「加入企业」输入企业邀请码';

	/// zh-CN: '加入企业'
	String get joinEnterprise => '加入企业';

	/// zh-CN: '企业 ID'
	String get joinOrgIdLabel => '企业 ID';

	/// zh-CN: '向企业管理员获取（数字 ID）'
	String get joinOrgIdHint => '向企业管理员获取（数字 ID）';

	/// zh-CN: '请输入有效的企业 ID（数字）'
	String get joinOrgIdInvalid => '请输入有效的企业 ID（数字）';

	/// zh-CN: '企业邀请码'
	String get joinCodeLabel => '企业邀请码';

	/// zh-CN: '加入'
	String get joinSubmit => '加入';

	/// zh-CN: '企业邀请码无效或已失效'
	String get joinInvalidCode => '企业邀请码无效或已失效';

	/// zh-CN: '企业邀请码已过期'
	String get joinExpiredCode => '企业邀请码已过期';

	/// zh-CN: '加入失败：${msg}'
	String joinFailed({required Object msg}) => '加入失败：${msg}';

	/// zh-CN: '扫码加入'
	String get joinScanQr => '扫码加入';

	/// zh-CN: '输入 8 位企业邀请码'
	String get joinCodeOnlyHint => '输入 8 位企业邀请码';

	/// zh-CN: '确认加入企业'
	String get joinConfirmTitle => '确认加入企业';

	/// zh-CN: '将加入企业「${name}」'
	String joinConfirmWith({required Object name}) => '将加入企业「${name}」';

	/// zh-CN: '确认以 ${role} 身份加入「${name}」？'
	String joinConfirmWithRole({required Object role, required Object name}) => '确认以 ${role} 身份加入「${name}」？';

	/// zh-CN: '普通成员'
	String get joinRoleMember => '普通成员';

	/// zh-CN: '管理员'
	String get joinRoleAdmin => '管理员';

	/// zh-CN: '确认加入'
	String get joinConfirmSubmit => '确认加入';

	/// zh-CN: '返回修改'
	String get joinBack => '返回修改';

	/// zh-CN: '对准企业邀请二维码即可自动加入'
	String get joinQrHint => '对准企业邀请二维码即可自动加入';

	/// zh-CN: '不是有效的企业邀请二维码'
	String get joinQrInvalid => '不是有效的企业邀请二维码';
}

// Path: organization.inviteColleagues
class Translations$organization$inviteColleagues$zh_CN {
	Translations$organization$inviteColleagues$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '邀请同事'
	String get title => '邀请同事';

	/// zh-CN: '邀请同事'
	String get tabInvite => '邀请同事';

	/// zh-CN: '可能的同事'
	String get tabPossible => '可能的同事';

	/// zh-CN: '微信邀请同事'
	String get wechatInvite => '微信邀请同事';

	/// zh-CN: '把邀请码发给微信好友，对方打开 imboy 加入'
	String get wechatInviteHint => '把邀请码发给微信好友，对方打开 imboy 加入';

	/// zh-CN: '面对面邀请同事'
	String get faceToFace => '面对面邀请同事';

	/// zh-CN: '同事扫码或输入邀请码即可加入'
	String get faceToFaceHint => '同事扫码或输入邀请码即可加入';

	/// zh-CN: '从微信群中添加'
	String get fromWechatGroup => '从微信群中添加';

	/// zh-CN: '把邀请码发到微信群，同事复制后即可加入'
	String get fromWechatGroupHint => '把邀请码发到微信群，同事复制后即可加入';

	/// zh-CN: '【${orgName}】邀请你加入 imboy 邀请码：${code}（7 天内有效） 点击加入：${inviteUrl} 打开 imboy App，在「通讯录 → 加入企业」输入邀请码即可加入'
	String shareText({required Object orgName, required Object code, required Object inviteUrl}) => '【${orgName}】邀请你加入 imboy\n邀请码：${code}（7 天内有效）\n点击加入：${inviteUrl}\n打开 imboy App，在「通讯录 → 加入企业」输入邀请码即可加入';

	/// zh-CN: '分享邀请到微信'
	String get shareToWechat => '分享邀请到微信';

	/// zh-CN: '复制邀请码'
	String get copyInviteCode => '复制邀请码';

	/// zh-CN: '邀请码 7 天内有效；重新生成后旧码立即失效'
	String get codeValidityHint => '邀请码 7 天内有效；重新生成后旧码立即失效';

	/// zh-CN: '可能的同事加载失败，请重试'
	String get possibleLoadFailed => '可能的同事加载失败，请重试';

	/// zh-CN: '撤销失败，请稍后重试'
	String get revokeFailed => '撤销失败，请稍后重试';

	/// zh-CN: '暂无有效邀请码，请先联系企业管理员生成'
	String get guideCodeMissing => '暂无有效邀请码，请先联系企业管理员生成';

	/// zh-CN: '去邀请同事'
	String get possibleEmptyCta => '去邀请同事';

	/// zh-CN: '邀请码加载失败，请重试'
	String get codeLoadFailed => '邀请码加载失败，请重试';

	/// zh-CN: '暂无有效邀请码，生成后即可分享'
	String get codeMissingHint => '暂无有效邀请码，生成后即可分享';

	/// zh-CN: '生成邀请码'
	String get generateCode => '生成邀请码';

	/// zh-CN: '仅企业管理员可生成邀请码，请联系管理员'
	String get generateForbidden => '仅企业管理员可生成邀请码，请联系管理员';

	/// zh-CN: '暂无待加入的同事'
	String get possibleEmpty => '暂无待加入的同事';

	/// zh-CN: '去邀请你的同事加入吧'
	String get possibleEmptyHint => '去邀请你的同事加入吧';

	/// zh-CN: '${name} 邀请'
	String invitedBy({required Object name}) => '${name} 邀请';

	/// zh-CN: '邀请于 ${time}'
	String invitedAt({required Object time}) => '邀请于 ${time}';

	/// zh-CN: '撤销'
	String get revoke => '撤销';

	/// zh-CN: '撤销邀请'
	String get revokeTitle => '撤销邀请';

	/// zh-CN: '撤销对「${name}」的邀请？'
	String revokeBody({required Object name}) => '撤销对「${name}」的邀请？';

	/// zh-CN: '已撤销邀请'
	String get revoked => '已撤销邀请';

	/// zh-CN: '把邀请码分享到你的微信群'
	String get groupStep1 => '把邀请码分享到你的微信群';

	/// zh-CN: '同事复制邀请码，打开 imboy App'
	String get groupStep2 => '同事复制邀请码，打开 imboy App';

	/// zh-CN: '在「通讯录 → 加入企业」输入邀请码即可加入'
	String get groupStep3 => '在「通讯录 → 加入企业」输入邀请码即可加入';

	/// zh-CN: '邀请码：${code}'
	String codeLabelWith({required Object code}) => '邀请码：${code}';
}

// Path: organization.inviteQr
class Translations$organization$inviteQr$zh_CN {
	Translations$organization$inviteQr$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '企业二维码'
	String get orgQrcode => '企业二维码';

	/// zh-CN: '邀请成员'
	String get title => '邀请成员';

	/// zh-CN: '出示二维码或邀请码，对方扫码 / 输码即可加入'
	String get entryHint => '出示二维码或邀请码，对方扫码 / 输码即可加入';

	/// zh-CN: '对方用 imboy「扫一扫」扫描本码即可加入本企业'
	String get scanHint => '对方用 imboy「扫一扫」扫描本码即可加入本企业';

	/// zh-CN: '企业邀请码'
	String get codeLabel => '企业邀请码';

	/// zh-CN: '有效期至 ${date}'
	String expiresWith({required Object date}) => '有效期至 ${date}';

	/// zh-CN: '生成邀请码'
	String get generate => '生成邀请码';

	/// zh-CN: '尚无有效邀请码。生成后 7 天有效，对方扫码或输入邀请码即可加入。'
	String get generateFirst => '尚无有效邀请码。生成后 7 天有效，对方扫码或输入邀请码即可加入。';

	/// zh-CN: '重新生成'
	String get regenerate => '重新生成';

	/// zh-CN: '重新生成邀请码？'
	String get regenerateTitle => '重新生成邀请码？';

	/// zh-CN: '旧邀请码将立即失效，已分享的二维码与口令随之作废。'
	String get regenerateBody => '旧邀请码将立即失效，已分享的二维码与口令随之作废。';

	/// zh-CN: '生成邀请码失败，请稍后重试'
	String get generateFailed => '生成邀请码失败，请稍后重试';

	/// zh-CN: '邀请码加载失败'
	String get loadFailed => '邀请码加载失败';

	/// zh-CN: '仅企业 Owner/Admin 可管理邀请码'
	String get notAdmin => '仅企业 Owner/Admin 可管理邀请码';

	/// zh-CN: '复制邀请码'
	String get copyCode => '复制邀请码';

	/// zh-CN: '已复制邀请码'
	String get copied => '已复制邀请码';

	/// zh-CN: '企业待审核，审核通过后才能邀请成员'
	String get inviteDisabledPending => '企业待审核，审核通过后才能邀请成员';
}

// Path: organization.directory
class Translations$organization$directory$zh_CN {
	Translations$organization$directory$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '本级成员'
	String get currentMembersSection => '本级成员';

	/// zh-CN: '组织架构'
	String get structureSection => '组织架构';

	/// zh-CN: '通讯录'
	String get title => '通讯录';

	/// zh-CN: '部门'
	String get deptSection => '部门';

	/// zh-CN: '全部成员'
	String get allMembersSection => '全部成员';

	/// zh-CN: '全员名单仅企业管理员可见；可展开部门查看部门成员。'
	String get membersRestricted => '全员名单仅企业管理员可见；可展开部门查看部门成员。';

	/// zh-CN: '查看 IM 资料'
	String get imProfileEntry => '查看 IM 资料';

	/// zh-CN: '我的部门'
	String get myDepartmentsSection => '我的部门';

	/// zh-CN: '成员'
	String get membersSection => '成员';

	/// zh-CN: '${count} 人'
	String memberCountWith({required Object count}) => '${count} 人';

	/// zh-CN: '搜索部门或成员'
	String get searchHint => '搜索部门或成员';

	/// zh-CN: '暂无子部门'
	String get emptyDepartments => '暂无子部门';

	/// zh-CN: '暂无成员'
	String get emptyMembers => '暂无成员';

	/// zh-CN: '无匹配结果'
	String get emptySearch => '无匹配结果';

	/// zh-CN: '目标企业不可用或你已不是其成员'
	String get switchVerifyFailed => '目标企业不可用或你已不是其成员';

	/// zh-CN: '新企业工作区加载失败'
	String get switchShellFailed => '新企业工作区加载失败';

	/// zh-CN: '邀请同事...'
	String get inviteColleaguesRow => '邀请同事...';

	/// zh-CN: '共${count}人'
	String memberTotal({required Object count}) => '共${count}人';
}

// Path: organization.memberDetail
class Translations$organization$memberDetail$zh_CN {
	Translations$organization$memberDetail$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '企业角色'
	String get roleLabel => '企业角色';

	/// zh-CN: '仅企业管理员可查看'
	String get roleRestricted => '仅企业管理员可查看';

	/// zh-CN: '登录账号'
	String get accountLabel => '登录账号';

	/// zh-CN: '加入时间'
	String get joinedLabel => '加入时间';

	/// zh-CN: '有权工作区'
	String get workspacesTitle => '有权工作区';

	/// zh-CN: '该成员在本企业内暂无工作区'
	String get workspacesEmpty => '该成员在本企业内暂无工作区';

	/// zh-CN: '有权工作区加载失败'
	String get workspacesFailed => '有权工作区加载失败';
}

// Path: organization.manage
class Translations$organization$manage$zh_CN {
	Translations$organization$manage$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '重命名工作区'
	String get renameWorkspace => '重命名工作区';

	/// zh-CN: '重命名「${name}」'
	String renameWorkspaceTitle({required Object name}) => '重命名「${name}」';

	/// zh-CN: '成员治理'
	String get wsMembersEntry => '成员治理';

	/// zh-CN: '重命名'
	String get renameGroup => '重命名';

	/// zh-CN: '重命名「${name}」'
	String renameGroupTitle({required Object name}) => '重命名「${name}」';

	/// zh-CN: '成员与角色'
	String get groupGovernance => '成员与角色';

	/// zh-CN: '重命名'
	String get renameChannel => '重命名';

	/// zh-CN: '管理员'
	String get channelAdmins => '管理员';

	/// zh-CN: '订阅者'
	String get channelSubscribersEntry => '订阅者';

	/// zh-CN: '企业管理'
	String get entry => '企业管理';

	/// zh-CN: '企业管理（仅管理员）'
	String get entryRestricted => '企业管理（仅管理员）';

	/// zh-CN: '企业管理'
	String get title => '企业管理';

	/// zh-CN: '企业不存在或你无权查看'
	String get orgNotFound => '企业不存在或你无权查看';

	/// zh-CN: '我的角色：${role}'
	String roleLine({required Object role}) => '我的角色：${role}';

	/// zh-CN: '企业现状只读；管理动作仅企业所有者/管理员可用'
	String get readOnlyHint => '企业现状只读；管理动作仅企业所有者/管理员可用';

	/// zh-CN: '这里只显示你拥有的工作区；企业级动作（新建工作区、设默认）需企业所有者/管理员。'
	String get workspaceOwnerHint => '这里只显示你拥有的工作区；企业级动作（新建工作区、设默认）需企业所有者/管理员。';

	/// zh-CN: '无管理权限'
	String get forbiddenTitle => '无管理权限';

	/// zh-CN: '企业管理仅对企业所有者与管理员开放；需要时请联系管理员调整你的角色。'
	String get forbiddenBody => '企业管理仅对企业所有者与管理员开放；需要时请联系管理员调整你的角色。';

	/// zh-CN: '工作区'
	String get workspaceSection => '工作区';

	/// zh-CN: '新建工作区'
	String get createWorkspace => '新建工作区';

	/// zh-CN: '工作区名称'
	String get workspaceNameHint => '工作区名称';

	/// zh-CN: '暂无工作区'
	String get workspaceEmpty => '暂无工作区';

	/// zh-CN: '当前企业下还没有你加入的工作区，可用右上角新建。'
	String get workspaceEmptyHint => '当前企业下还没有你加入的工作区，可用右上角新建。';

	/// zh-CN: '这里只列出你已加入的工作区；同企业内你未加入的工作区不会出现。'
	String get workspaceScopeNote => '这里只列出你已加入的工作区；同企业内你未加入的工作区不会出现。';

	/// zh-CN: '默认工作区'
	String get defaultBadge => '默认工作区';

	/// zh-CN: '非默认'
	String get notDefaultBadge => '非默认';

	/// zh-CN: '已归档'
	String get archivedBadge => '已归档';

	/// zh-CN: '我是所有者'
	String get ownerBadge => '我是所有者';

	/// zh-CN: '我是成员'
	String get memberBadge => '我是成员';

	/// zh-CN: '设为默认工作区'
	String get setDefault => '设为默认工作区';

	/// zh-CN: '归档工作区'
	String get archiveWorkspace => '归档工作区';

	/// zh-CN: '归档「${name}」？'
	String archiveWorkspaceTitle({required Object name}) => '归档「${name}」？';

	/// zh-CN: '归档后该工作区进入只读，其群与频道一并停写；若它是企业默认工作区，请先指定替代工作区。归档可恢复。'
	String get archiveWorkspaceBody => '归档后该工作区进入只读，其群与频道一并停写；若它是企业默认工作区，请先指定替代工作区。归档可恢复。';

	/// zh-CN: '恢复工作区'
	String get restoreWorkspace => '恢复工作区';

	/// zh-CN: '群与频道'
	String get resourceSection => '群与频道';

	/// zh-CN: '需要先有工作区，才能治理群与频道。'
	String get resourceNeedsWorkspace => '需要先有工作区，才能治理群与频道。';

	/// zh-CN: '加载失败：${err}'
	String resourceLoadFailed({required Object err}) => '加载失败：${err}';

	/// zh-CN: '重试'
	String get retry => '重试';

	/// zh-CN: '企业群'
	String get groupSection => '企业群';

	/// zh-CN: '新建群'
	String get createGroup => '新建群';

	/// zh-CN: '创建结果未知，请稍后重试'
	String get creationRecoveryUnavailable => '创建结果未知，请稍后重试';

	/// zh-CN: '群已创建（ID：${gid}），名称未保存'
	String groupCreatedRenamePending({required Object gid}) => '群已创建（ID：${gid}），名称未保存';

	/// zh-CN: '群名称'
	String get groupNameHint => '群名称';

	/// zh-CN: '暂无企业群'
	String get groupEmpty => '暂无企业群';

	/// zh-CN: '成员 ${count}'
	String groupMembers({required Object count}) => '成员 ${count}';

	/// zh-CN: '解散群'
	String get dissolveGroup => '解散群';

	/// zh-CN: '解散「${name}」？'
	String dissolveGroupTitle({required Object name}) => '解散「${name}」？';

	/// zh-CN: '解散不可恢复；成员关系会终止，但历史消息与审计记录保留。'
	String get dissolveGroupBody => '解散不可恢复；成员关系会终止，但历史消息与审计记录保留。';

	/// zh-CN: '企业频道'
	String get channelSection => '企业频道';

	/// zh-CN: '新建频道'
	String get createChannel => '新建频道';

	/// zh-CN: '频道名称'
	String get channelNameHint => '频道名称';

	/// zh-CN: '企业频道固定为「免费 + 非公开」：不进入公开发现，成员经工作区订阅。'
	String get channelPolicyNote => '企业频道固定为「免费 + 非公开」：不进入公开发现，成员经工作区订阅。';

	/// zh-CN: '暂无企业频道'
	String get channelEmpty => '暂无企业频道';

	/// zh-CN: '订阅 ${count}'
	String channelSubscribers({required Object count}) => '订阅 ${count}';

	/// zh-CN: '频道创建失败'
	String get createChannelFailed => '频道创建失败';

	/// zh-CN: '归档频道'
	String get archiveChannel => '归档频道';

	/// zh-CN: '归档「${name}」？'
	String archiveChannelTitle({required Object name}) => '归档「${name}」？';

	/// zh-CN: '归档后频道退出公开面，成员不再看到；归档可恢复。'
	String get archiveChannelBody => '归档后频道退出公开面，成员不再看到；归档可恢复。';

	/// zh-CN: '恢复'
	String get restoreChannel => '恢复';

	/// zh-CN: '已归档频道'
	String get archivedChannelSection => '已归档频道';
}

// Path: organization.contactEntry
class Translations$organization$contactEntry$zh_CN {
	Translations$organization$contactEntry$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '进入通讯录'
	String get browserEntry => '进入通讯录';

	/// zh-CN: '企业信息加载失败'
	String get loadFailed => '企业信息加载失败';
}

// Path: organization.hub
class Translations$organization$hub$zh_CN {
	Translations$organization$hub$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '企业资源'
	String get sectionResources => '企业资源';

	/// zh-CN: '管理员区'
	String get sectionAdmin => '管理员区';

	/// zh-CN: '成员'
	String get zoneMembers => '成员';

	/// zh-CN: '企业通讯录 · 按部门浏览'
	String get zoneMembersDesc => '企业通讯录 · 按部门浏览';

	/// zh-CN: '部门'
	String get zoneDepartments => '部门';

	/// zh-CN: '部门目录与层级'
	String get zoneDepartmentsDesc => '部门目录与层级';

	/// zh-CN: '群'
	String get zoneGroups => '群';

	/// zh-CN: '企业群 · 经企业管理查看'
	String get zoneGroupsDesc => '企业群 · 经企业管理查看';

	/// zh-CN: '频道'
	String get zoneChannels => '频道';

	/// zh-CN: '企业频道 · 经企业管理查看'
	String get zoneChannelsDesc => '企业频道 · 经企业管理查看';

	/// zh-CN: '工具'
	String get zoneTools => '工具';

	/// zh-CN: '工作区 · 项目与协作'
	String get zoneToolsDesc => '工作区 · 项目与协作';

	/// zh-CN: '企业协作工具'
	String get zoneOrgTools => '企业协作工具';

	/// zh-CN: '本企业已授权的工作区项目与任务'
	String get zoneOrgToolsDesc => '本企业已授权的工作区项目与任务';

	/// zh-CN: '成员治理'
	String get adminMembers => '成员治理';

	/// zh-CN: '角色调整 · 移除成员'
	String get adminMembersDesc => '角色调整 · 移除成员';

	/// zh-CN: '邀请管理'
	String get adminInvitations => '邀请管理';

	/// zh-CN: '邀请创建与撤销'
	String get adminInvitationsDesc => '邀请创建与撤销';

	/// zh-CN: '企业管理'
	String get adminManage => '企业管理';

	/// zh-CN: '工作区 · 群 · 频道治理'
	String get adminManageDesc => '工作区 · 群 · 频道治理';

	/// zh-CN: '客服治理'
	String get adminCsGovernance => '客服治理';

	/// zh-CN: '席位额度 · 坐席启停'
	String get adminCsGovernanceDesc => '席位额度 · 坐席启停';
}

// Path: organization.wsMembers
class Translations$organization$wsMembers$zh_CN {
	Translations$organization$wsMembers$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '工作区成员 · ${ws}'
	String title({required Object ws}) => '工作区成员 · ${ws}';

	/// zh-CN: '邀请成员'
	String get invite => '邀请成员';

	/// zh-CN: '经既有向导选择联系人发出邀请（仅工作区所有者）'
	String get inviteHint => '经既有向导选择联系人发出邀请（仅工作区所有者）';

	/// zh-CN: '当前只读；写操作仅工作区所有者可用'
	String get readOnlyHint => '当前只读；写操作仅工作区所有者可用';

	/// zh-CN: '成员 ${count}'
	String memberCount({required Object count}) => '成员 ${count}';

	/// zh-CN: '工作区不存在或你无权查看'
	String get notFound => '工作区不存在或你无权查看';

	/// zh-CN: '所有者'
	String get roleOwner => '所有者';

	/// zh-CN: '成员'
	String get roleMember => '成员';

	/// zh-CN: '访客'
	String get roleGuest => '访客';

	/// zh-CN: '更改角色'
	String get changeRole => '更改角色';

	/// zh-CN: '设为成员'
	String get setRoleMember => '设为成员';

	/// zh-CN: '设为访客'
	String get setRoleGuest => '设为访客';

	/// zh-CN: '转让所有者'
	String get transferOwner => '转让所有者';

	/// zh-CN: '转让「${name}」的所有者？'
	String transferOwnerTitle({required Object name}) => '转让「${name}」的所有者？';

	/// zh-CN: '转让后你不再是该工作区所有者，写治理权限随之移交给对方；新所有者可再转回。'
	String get transferOwnerBody => '转让后你不再是该工作区所有者，写治理权限随之移交给对方；新所有者可再转回。';

	/// zh-CN: '移除成员'
	String get removeMember => '移除成员';

	/// zh-CN: '移除「${name}」？'
	String removeTitle({required Object name}) => '移除「${name}」？';

	/// zh-CN: '移除后对方退出该工作区；若对方仍是项目所有者或有未完成任务，服务端会拒绝并列出冲突。'
	String get removeBody => '移除后对方退出该工作区；若对方仍是项目所有者或有未完成任务，服务端会拒绝并列出冲突。';

	/// zh-CN: '工作区已归档：成员治理写操作已被服务端停用。'
	String get archivedReadOnly => '工作区已归档：成员治理写操作已被服务端停用。';
}

// Path: organization.tools
class Translations$organization$tools$zh_CN {
	Translations$organization$tools$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '企业工具'
	String get title => '企业工具';

	/// zh-CN: '${name} · 企业工具'
	String titleWithOrg({required Object name}) => '${name} · 企业工具';

	/// zh-CN: '这里只列出你已加入的本企业工作区与其项目；任务、里程碑等在项目详情内。'
	String get scopeNote => '这里只列出你已加入的本企业工作区与其项目；任务、里程碑等在项目详情内。';

	/// zh-CN: '企业已归档：工具区只读。'
	String get archivedNote => '企业已归档：工具区只读。';

	/// zh-CN: '暂无已加入的工作区'
	String get workspaceEmpty => '暂无已加入的工作区';

	/// zh-CN: '同企业内你未加入的工作区不会出现在这里。'
	String get workspaceEmptyHint => '同企业内你未加入的工作区不会出现在这里。';

	/// zh-CN: '项目 ${count}'
	String projectCount({required Object count}) => '项目 ${count}';

	/// zh-CN: '暂无项目'
	String get projectsEmpty => '暂无项目';

	/// zh-CN: '项目加载失败：${err}'
	String projectsError({required Object err}) => '项目加载失败：${err}';

	/// zh-CN: '浏览全部工作区'
	String get moreInWorkspaceShell => '浏览全部工作区';

	/// zh-CN: '打开全局工作区切换器（跨企业）。'
	String get moreInWorkspaceShellHint => '打开全局工作区切换器（跨企业）。';
}

// Path: organization.chart
class Translations$organization$chart$zh_CN {
	Translations$organization$chart$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '放大'
	String get zoomIn => '放大';

	/// zh-CN: '缩小'
	String get zoomOut => '缩小';

	/// zh-CN: '适应窗口'
	String get fit => '适应窗口';

	/// zh-CN: '展开下级部门'
	String get expand => '展开下级部门';

	/// zh-CN: '收起下级部门'
	String get collapse => '收起下级部门';

	/// zh-CN: '拖动查看 · 双指缩放'
	String get gestureHint => '拖动查看 · 双指缩放';

	/// zh-CN: '本级 ${count} 人'
	String directMembers({required Object count}) => '本级 ${count} 人';
}

// Path: organization.experienceUi
class Translations$organization$experienceUi$zh_CN {
	Translations$organization$experienceUi$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '切换空间'
	String get switchSpace => '切换空间';

	/// zh-CN: '个人空间'
	String get personalSpace => '个人空间';

	/// zh-CN: '企业空间'
	String get enterpriseSpaces => '企业空间';

	/// zh-CN: '当前空间'
	String get currentSpace => '当前空间';

	/// zh-CN: '企业资料'
	String get enterpriseInfo => '企业资料';

	/// zh-CN: '协作空间'
	String get collaborationSpace => '协作空间';

	/// zh-CN: '群内容'
	String get groupContent => '群内容';

	/// zh-CN: '群协作'
	String get groupCollaboration => '群协作';

	/// zh-CN: '默认工作区'
	String get defaultWorkspace => '默认工作区';

	/// zh-CN: '已设置'
	String get defaultAvailable => '已设置';

	/// zh-CN: '暂时无法获取'
	String get defaultUnknown => '暂时无法获取';

	/// zh-CN: '加入相应工作区后可进入，默认设置不会自动授予访问权限。'
	String get defaultHint => '加入相应工作区后可进入，默认设置不会自动授予访问权限。';

	/// zh-CN: '注销前检查'
	String get accountCheck => '注销前检查';

	/// zh-CN: '工作区：${name}'
	String workspaceContext({required Object name}) => '工作区：${name}';

	/// zh-CN: '暂无简介'
	String get noIntro => '暂无简介';

	/// zh-CN: '个人面聊记录待处理'
	String get talkRecordPersonalPendingTitle => '个人面聊记录待处理';

	/// zh-CN: '请先处理个人面聊记录，再重新检查注销条件。'
	String get talkRecordPersonalPendingBody => '请先处理个人面聊记录，再重新检查注销条件。';

	/// zh-CN: '录音文件仍在清理'
	String get talkRecordCleanupPendingTitle => '录音文件仍在清理';

	/// zh-CN: '记录已删除，文件清理尚未完成。可查看真实进度；保留规则或处理保护不能被手动跳过。'
	String get talkRecordCleanupPendingBody => '记录已删除，文件清理尚未完成。可查看真实进度；保留规则或处理保护不能被手动跳过。';

	/// zh-CN: '企业面聊记录尚未移交'
	String get talkRecordOrganizationOwnerPendingTitle => '企业面聊记录尚未移交';

	/// zh-CN: '请先移交企业面聊记录的管理责任。移交不会自动解除历史身份引用。'
	String get talkRecordOrganizationOwnerPendingBody => '请先移交企业面聊记录的管理责任。移交不会自动解除历史身份引用。';

	/// zh-CN: '历史身份引用待核查'
	String get talkRecordRetainedIdentityPendingTitle => '历史身份引用待核查';

	/// zh-CN: '历史记录仍引用此身份，当前无法完成注销。移交记录不保证解除这些引用。'
	String get talkRecordRetainedIdentityPendingBody => '历史记录仍引用此身份，当前无法完成注销。移交记录不保证解除这些引用。';

	/// zh-CN: '查看个人面聊记录'
	String get openPersonalTalkRecords => '查看个人面聊记录';

	/// zh-CN: '查看清理进度'
	String get viewTalkRecordCleanup => '查看清理进度';

	/// zh-CN: '记录'
	String get cleanupRecordLabel => '记录';

	/// zh-CN: '仅显示前 20 条，处理后请刷新检查剩余项。'
	String get cleanupResourcesTruncated => '仅显示前 20 条，处理后请刷新检查剩余项。';

	/// zh-CN: '还有待处理事项'
	String get unknownBlockerTitle => '还有待处理事项';
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'account.account' => '账号',
			'account.accountSecurity' => '账号安全',
			'account.avatar' => '头像',
			'account.accountSecurityEnhance' => '提升账户安全',
			'account.bindMobile' => '绑定手机号',
			'account.bindMobileFor' => '用于登录、找回密码和接收重要通知',
			'account.linkEmail' => '关联邮箱',
			'account.linkEmailFor' => '用于登录、身份验证和接收账单',
			'account.codeSentToEmail' => '验证码已发送到邮箱',
			'account.codeSentToMobile' => '验证码已发送到手机',
			'account.currentDevice' => '当前设备',
			'account.deviceAvailableSpace' => '设备可用空间',
			'account.deviceList' => '设备列表',
			'account.deviceName' => '设备名称',
			'account.deviceType' => '设备类型',
			'account.deviceUsedSpace' => '设备已使用空间',
			'account.email' => '邮箱',
			'account.forgotPassword' => '忘记密码？',
			'account.gender' => '性别',
			'account.groupQrcode' => '群二维码',
			'account.hintLoginAccount' => '账号/邮箱',
			'account.logOut' => '退出登录',
			'account.areYouSureLogOut' => '确定要退出登录吗？',
			'account.login' => '登录',
			'account.loginDeviceManagement' => '登录设备管理',
			'account.loginEmail' => '登录邮箱',
			'account.logoutAccount' => '注销账号',
			'account.logoutPendingBanner' => ({required Object date}) => '注销申请已提交，预计 ${date} 完成',
			'account.logoutPendingHeader' => '注销申请状态',
			'account.logoutCancelRequest' => '撤销注销申请',
			'account.logoutCancelledNote' => '注销申请已撤销',
			'account.logoutRetainedHeader' => '数据留存说明',
			'account.logoutRetainedNote' => '删除完成后：审计日志与财务记录依法留存并匿名化；你拥有的群/工作区/频道将优先转移给继任成员',
			'account.mobile' => '手机',
			'account.mobileQuickLogin' => '一键登录',
			'account.myAccount' => '我的账号',
			'account.myQrcode' => '我的二维码',
			'account.newPassword' => '新的密码',
			'account.newlyRegisteredPeople' => '新注册的人',
			'account.nickname' => '昵称',
			'account.nicknameHint' => '请输入昵称',
			'account.password' => '密码',
			'account.recoverPassword' => '找回密码',
			'account.birthday' => '生日',
			'account.region' => '地区',
			'account.retypePassword' => '重新输入密码',
			'account.scanQrCode' => '扫描二维码',
			'account.setNickname' => '设置昵称',
			'account.signature' => '个性签名',
			'account.signup' => '注册',
			'account.sourceQrcode' => '通过扫一扫添加',
			'account.changeEmail' => '修改邮箱',
			'account.bindEmail' => '绑定邮箱',
			'account.currentEmail' => '当前邮箱',
			'account.setPassword' => '设置密码',
			'account.setLoginPassword' => '设置登录密码',
			'account.enhanceAccountSecurity' => '提升账号安全性',
			'account.passwordLengthRequirement' => '密码长度为4-32的任意字符',
			'account.passwordMinLength' => ({required Object min}) => '密码至少需要${min}个字符',
			'account.pleaseEnterPassword' => '请输入密码',
			'account.changeMobile' => '更换手机号',
			'account.currentMobile' => '当前手机号',
			'account.newMobile' => '新手机号',
			'account.enterMobileHint' => '请输入手机号',
			'account.privacyLogoutAccount' => '注销账号',
			'account.wallet' => '钱包',
			'account.changeLoginPassword' => '修改登录密码',
			'account.otherDevice' => '其他设备',
			'account.loginPassword' => '登录密码',
			'account.loginPasswordDesc' => '用于登录IMBoy账号',
			'account.oldPassword' => '旧密码',
			'account.enterOldPassword' => '请输入旧密码',
			'account.enterNewPassword' => '请输入新密码',
			'account.enterNewPasswordAgain' => '请再次输入新密码',
			'account.myQRCode' => '我的二维码',
			'account.profile' => '个人资料',
			'account.setGender' => '设置性别',
			'account.setBirthday' => '设置生日',
			'account.nicknameRules' => '• 昵称长度为2-24个字符 • 不能仅包含空白字符或表情符号 • 不能包含敏感词汇 • 修改后将在所有聊天中显示',
			'account.refreshDeviceKey' => '刷新设备密钥',
			'account.refreshDeviceKeyHint' => '如果消息无法解密，点击此按钮刷新密钥',
			'account.refreshingDeviceKey' => '正在刷新设备密钥...',
			'account.deviceKeyRefreshed' => '设备密钥已刷新',
			'account.rechargeTitle' => '充值',
			'account.rechargeAmountHint' => '请输入充值金额（元），0.01元～10000元',
			'account.rechargeAmountExample' => '例如：100',
			'account.payMethodTitle' => '选择支付方式',
			'account.payMethodWallet' => '钱包余额',
			'account.payMethodMock' => '模拟支付（开发环境）',
			'account.payMethodAlipay' => '支付宝',
			'account.payMethodWechat' => '微信支付',
			'account.payMethodComingSoon' => '该支付方式即将开通，敬请期待',
			'account.payCancelled' => '支付已取消',
			'account.e2eeDeviceIdLabel' => '设备 ID',
			'account.webQRLoginTitle' => '扫码登录',
			'account.webQRLoginHint' => '使用 ImBoy 手机版扫描二维码',
			'account.webSwitchToPassword' => '使用账号密码登录',
			'account.webPasswordLoginTitle' => '账号登录',
			'account.webAccountHint' => '请输入账号/手机号/邮箱',
			'account.webPasswordHint' => '请输入密码',
			'account.pleaseRelogin' => '请重新登录',
			'account.otherLoginMethods' => '其他登录方式',
			'account.alipaySim.selectMethod' => '选择支付方式',
			'account.alipaySim.confirmPay' => '确认付款',
			'account.alipaySim.enterPassword' => '请输入支付密码',
			'account.alipaySim.alipaySuccess' => '支付成功',
			'account.alipaySim.huabei' => '花呗分期',
			'account.alipaySim.energy' => '支付成功得绿色能量 5g',
			'account.alipaySim.storeName' => '信息科技旗舰店',
			'account.alipaySim.paymentAmount' => '金额：',
			'account.alipaySim.balanceSource' => '账户余额',
			'account.bindAlipay' => '绑定支付宝',
			'account.unbindAlipay' => '解除绑定',
			'account.confirmUnbindAlipay' => '确认解除绑定',
			'agent.plazaTitle' => 'AI 助手广场',
			'agent.transparencyBanner' => '这里的成员都是 AI 助手，身份会明确标注；加密聊天里，只有真人。',
			'agent.searchHint' => '搜索助手',
			'agent.emptyTitle' => '暂无 AI 助手，稍后再来看看',
			'agent.searchEmpty' => '无匹配的助手',
			'agent.sendMessage' => '发消息',
			'agent.badgeAi' => 'AI',
			'agent.badgeOfficial' => '官方',
			'agent.badgeAiA11y' => 'AI 助手',
			'agent.badgeOfficialA11y' => '官方账号',
			'agent.legacyBotMigrated' => '此机器人入口已升级，请到 AI 助手广场与助手对话',
			'agent.legacyBotGoPlaza' => '去助手广场',
			'agentTask.title' => 'AI 任务',
			'agentTask.working' => '执行中',
			'agentTask.submitted' => '已提交',
			'agentTask.progress' => '进行中',
			'agentTask.completed' => '已完成',
			'agentTask.failed' => '执行失败',
			'agentTask.cancelled' => '已取消',
			'agentTask.awaitingApproval' => '待审批',
			'agentTask.approve' => '批准',
			'agentTask.reject' => '拒绝',
			'appeal.title' => '处置与申诉',
			'appeal.actionsSection' => '针对我的处置',
			'appeal.actionsEmpty' => '暂无处置记录',
			'appeal.appealsSection' => '我的申诉',
			'appeal.appealsEmpty' => '暂无申诉记录',
			'appeal.dialogTitle' => '发起申诉',
			'appeal.reasonPlaceholder' => '请说明申诉理由（必填）',
			'appeal.submit' => '提交申诉',
			'appeal.submitFailed' => '申诉提交失败',
			'appeal.appealedTag' => '已申诉',
			'appeal.appealableTag' => '可申诉',
			'appeal.actionWarning' => '警告',
			'appeal.actionGroupMute' => '群禁言',
			'appeal.actionGroupKick' => '移出群聊',
			'appeal.actionReject' => '驳回内容',
			'appeal.actionAccountRestrict' => '账号受限',
			'appeal.actionContentRemoval' => '内容删除',
			'appeal.statusPending' => '待复审',
			'appeal.statusAccepted' => '已翻案',
			'appeal.statusRejected' => '已维持',
			'appeal.allClearTitle' => '一切正常',
			'appeal.allClearSubtitle' => '没有针对你的处置，也不需要申诉。',
			'attachmentManager.title' => '附件',
			'attachmentManager.centerHint' => '检索当前工作区内有权查看的群组、频道和面聊附件。',
			'attachmentManager.allGroups' => '全部群组',
			'attachmentManager.allChannels' => '全部频道',
			'attachmentManager.allPeople' => '全部上传人',
			'attachmentManager.personSearch' => '上传人姓名、账号或编号',
			'attachmentManager.dateRange' => '时间范围',
			'attachmentManager.clearFilters' => '清除筛选',
			'attachmentManager.personalTitle' => '本机附件',
			'attachmentManager.enterpriseTitle' => '企业附件',
			'attachmentManager.personalHint' => '按本机聊天记录查找附件，点按文件返回来源消息。',
			'attachmentManager.personalBoundary' => '本机可见不代表云端备份。清缓存保留消息索引；删除聊天记录后不会自动恢复。加密内容仍需要可用密钥。',
			'attachmentManager.groupSource' => '群组附件',
			'attachmentManager.enterpriseHint' => '选择当前工作区内的群组查看云端文件。',
			'attachmentManager.enterpriseBoundary' => '已标记“企业留存”的附件由企业云端保留，不随本机缓存或聊天记录清理而删除；查看权限仍按来源群组、频道或面聊记录的权限控制。',
			'attachmentManager.searchHint' => '搜索附件名称',
			'attachmentManager.searchGroupsHint' => '搜索群组',
			'attachmentManager.emptyLocal' => '暂无本机可查看附件',
			'attachmentManager.emptySearch' => '未找到匹配附件',
			'attachmentManager.openSource' => '查看来源消息',
			'attachmentManager.loadMore' => '加载更多',
			'attachmentManager.localOnly' => '本机消息索引',
			'attachmentManager.cacheConfirmTitle' => '清理临时缓存？',
			'attachmentManager.cacheConfirmBody' => '将清理临时下载和预览缓存，不删除聊天记录、加密密钥或企业云端附件。部分内容再次查看时需要下载。',
			'attachmentManager.cacheFailed' => '缓存清理失败，请稍后重试',
			'attachmentManager.cacheAction' => '清理临时缓存',
			'attachmentManager.storageHint' => '此处管理设备占用；查找和查看附件请使用本机附件。',
			'attachmentManager.unavailableSource' => '来源会话已不存在，无法安全打开附件',
			'attachmentManager.moreFailed' => '加载更多失败，请重试。',
			'attachmentManager.loadFailed' => '附件加载失败，请重试',
			'attachmentManager.resultCount' => ({required Object count}) => '共 ${count} 个附件',
			'attachmentManager.emptyHint' => '试试调整关键词或筛选条件',
			'attachmentManager.clearFiltersAction' => '清除筛选',
			'attachmentManager.retryAction' => '重试',
			'attachmentManager.selectGroupTitle' => '选择群组',
			'attachmentManager.selectChannelTitle' => '选择频道',
			'attachmentManager.enterpriseRetained' => '企业留存',
			'attachmentManager.enterpriseUnmanaged' => '未纳入留存',
			'attachmentManager.sourceAll' => '全部来源',
			'attachmentManager.sourceGroups' => '群组',
			'attachmentManager.sourceChannels' => '频道',
			'attachmentManager.sourceTalkRecords' => '面聊记录',
			'attachmentManager.talkRecordSourceHint' => '查看面聊记录；播放与导出仍按记录权限控制。',
			'attachmentManager.organizationCenterHint' => '检索本企业内有权查看的附件，包含未归入工作区的面聊记录。',
			'attachmentManager.governanceAction' => '附件治理',
			'attachmentManager.governancePurgeApproved' => '已批准清理',
			'attachmentManager.governancePhysicalPending' => '批准清理不代表文件已删除，实际进度以清理状态为准。',
			'attachmentManager.governanceRefreshConflict' => '记录版本已变化，请刷新后核对再提交。',
			'attachmentManager.governanceHoldReason' => '保全原因（最多 200 字）',
			'attachmentManager.governanceExtendUntil' => '延长留存至',
			'attachmentManager.governancePurgeConfirm' => '批准此附件清理？批准后不能恢复治理状态；仍须满足所有引用、上传及处理保护条件，才会进入清理。',
			'attachmentManager.governanceHoldAction' => '设置保全',
			'attachmentManager.governanceReleaseHoldAction' => '解除保全',
			'attachmentManager.governanceExtendAction' => '延长留存',
			'attachmentManager.governancePurgeAction' => '批准清理',
			'billing.title' => '套餐订阅',
			'billing.planPeriodMonthly' => '月付',
			'billing.planPeriodYearly' => '年付',
			'billing.subscribe' => '立即订阅',
			'billing.currentPlan' => '当前套餐',
			'billing.noPlans' => '暂无可售套餐，敬请期待',
			'billing.loadFailed' => '加载失败，请下拉重试',
			'billing.retry' => '重试',
			'billing.paySuccess' => '订阅成功',
			'billing.payFailed' => '支付失败',
			'billing.payCancelled' => '支付已取消',
			'billing.payMethodTitle' => '选择支付方式',
			'billing.payMethodMock' => '模拟支付（开发环境）',
			'billing.payMethodAlipay' => '支付宝',
			'billing.payMethodWechat' => '微信支付',
			'billing.payMethodComingSoon' => '该支付方式即将开通，敬请期待',
			'billing.quotaUnlimited' => '不限',
			'channel.composeLeaveImagesLost' => '已选图片不会保存，确定离开？',
			'channel.title' => '频道',
			'channel.loading' => '加载中...',
			'channel.subscribed' => '已订阅',
			'channel.managed' => '管理中',
			'channel.discover' => '发现频道',
			'channel.create' => '创建频道',
			'channel.creationRecoveryUnavailable' => '创建结果未知，请稍后重试',
			'channel.searchHint' => '搜索频道名称或ID',
			'channel.noResults' => '未找到相关频道',
			'channel.noRecommendedChannels' => '暂无推荐频道 稍后再来看看吧',
			'channel.noSubscribedChannels' => '暂无订阅的频道 去发现更多精彩频道吧',
			'channel.noManagedChannels' => '暂无管理的频道 创建一个频道开始你的创作',
			'channel.subscribers' => '订阅者',
			'channel.subscribe' => '订阅',
			'channel.subscribeSuccess' => '订阅成功',
			'channel.subscribeFailed' => '订阅失败',
			'channel.unsubscribe' => '取消订阅',
			'channel.unsubscribeConfirm' => '取消订阅',
			'channel.unsubscribeConfirmDesc' => '确定要取消订阅该频道吗？取消后将不再收到频道消息。',
			'channel.share' => '分享',
			'channel.shareNotImplemented' => '分享功能即将上线',
			'channel.nameLabel' => '频道名称',
			'channel.nameHint' => '请输入频道名称',
			'channel.nameRequired' => '频道名称不能为空',
			'channel.nameTooLong' => '频道名称不能超过50个字符',
			'channel.descriptionLabel' => '频道描述',
			'channel.descriptionHint' => '介绍一下你的频道（选填）',
			'channel.customIdLabel' => '自定义ID（选填）',
			'channel.customIdHint' => '例如：my_channel',
			'channel.customIdHelper' => '设置后可通过ID直接搜索到频道',
			'channel.customIdInvalid' => '只能包含字母、数字和下划线',
			'channel.customIdLength' => '长度需要在4-30个字符之间',
			'channel.typePublic' => '公开',
			'channel.typePrivate' => '私有',
			'channel.typePublicDesc' => '任何人都可以搜索到并订阅你的频道',
			'channel.typePrivateDesc' => '只有通过邀请链接才能订阅你的频道',
			'channel.createTips' => '创建频道后，你可以发布消息给所有订阅者。频道消息只有管理员可以发布。',
			'channel.today' => '今天',
			'channel.yesterday' => '昨天',
			'channel.daysAgo' => '天前',
			'channel.messages' => '消息',
			'channel.views' => '阅读',
			'channel.editChannel' => '编辑频道',
			'channel.editChannelNotImplemented' => '编辑频道功能即将上线',
			'channel.manageAdmins' => '管理管理员',
			'channel.manageAdminsNotImplemented' => '管理管理员功能即将上线',
			'channel.manageSubscribers' => '管理订阅者',
			'channel.manageSubscribersNotImplemented' => '管理订阅者功能即将上线',
			'channel.deleteChannel' => '删除频道',
			'channel.deleteChannelConfirm' => '确定要删除该频道吗？此操作不可恢复。',
			'channel.deleteChannelNotImplemented' => '删除频道功能即将上线',
			'channel.channelNotFound' => '频道不存在',
			'channel.channelDeleted' => '频道已删除',
			'channel.deleteChannelFailed' => '删除频道失败',
			'channel.writeMessage' => '发布消息...',
			'channel.publishFailed' => '发布失败',
			'channel.writeArticle' => '撰写图文',
			'channel.publish' => '发布',
			'channel.preview' => '预览',
			'channel.addImage' => '添加图片',
			'channel.titleOptional' => '标题（选填）',
			'channel.articleBodyHint' => '写点什么...支持加粗、斜体、标题、列表等格式',
			'channel.coverLabel' => '封面',
			'channel.coverSet' => '已设为封面',
			'channel.formatBold' => '加粗',
			'channel.formatItalic' => '斜体',
			'channel.formatStrikethrough' => '删除线',
			'channel.formatHeading' => '标题',
			'channel.formatList' => '列表',
			'channel.formatQuote' => '引用',
			'channel.formatLink' => '链接',
			'channel.linkTextPlaceholder' => '链接文字',
			'channel.pinMessage' => '置顶消息',
			'channel.unpinMessage' => '取消置顶',
			'channel.pinMessageNotImplemented' => '置顶功能即将上线',
			'channel.unpinMessageNotImplemented' => '取消置顶功能即将上线',
			'channel.messagePinned' => '消息已置顶',
			'channel.messageUnpinned' => '已取消置顶',
			'channel.deleteMessage' => '删除消息',
			'channel.deleteMessageConfirm' => '确定要删除这条消息吗？',
			'channel.messageDeleted' => '消息已删除',
			'channel.addAdmin' => '添加管理员',
			'channel.addAdminSuccess' => '管理员添加成功',
			'channel.addAdminFailed' => '添加管理员失败',
			'channel.removeAdmin' => '移除管理员',
			'channel.removeAdminConfirm' => '确定要移除该管理员吗？',
			'channel.removeAdminSuccess' => '管理员已移除',
			'channel.removeAdminFailed' => '移除管理员失败',
			'channel.changeRole' => '更改角色',
			'channel.updateRoleSuccess' => '角色更新成功',
			'channel.updateRoleFailed' => '角色更新失败',
			'channel.selectFromContacts' => '从联系人选择',
			'channel.searchContactsHint' => '搜索昵称或账号',
			'channel.noContactsToAdd' => '所有好友都已是管理员',
			'channel.selectRole' => '选择角色',
			'channel.noAdmins' => '暂无管理员',
			'channel.roleCreator' => '创建者',
			'channel.roleAdmin' => '管理员',
			'channel.roleAdminDesc' => '可管理频道',
			'channel.roleEditor' => '编辑',
			'channel.roleEditorDesc' => '可发布消息',
			'channel.searchSubscribers' => '搜索订阅者',
			'channel.subscriberSearchHint' => '输入昵称或ID搜索',
			'channel.noSearchResults' => '未找到匹配的订阅者',
			'channel.noSubscribers' => '暂无订阅者',
			'channel.removeSubscriber' => '移除订阅者',
			'channel.removeSubscriberConfirm' => '确定要移除该订阅者吗？',
			'channel.removeSubscriberSuccess' => '订阅者已移除',
			'channel.removeSubscriberFailed' => '移除订阅者失败',
			'channel.subscribedAt' => '订阅于',
			'channel.viewProfile' => '查看资料',
			'channel.inviteFromContacts' => '邀请好友',
			'channel.inviteSearchHint' => '搜索昵称或账号',
			'channel.noContactsToInvite' => '所有好友都已被邀请或已订阅',
			'channel.inviteSuccess' => '邀请已发送',
			'channel.inviteFailed' => '邀请发送失败',
			'channel.updateSuccess' => '频道更新成功',
			'channel.updateFailed' => '频道更新失败',
			'channel.typeCannotChange' => '创建后不可更改',
			'channel.stats' => '统计信息',
			'channel.shareToChat' => '发送给好友',
			'channel.qrcode' => '频道二维码',
			'channel.qrcodeTips' => ({required Object days, required Object date}) => '二维码${days}天内（${date}前）有效',
			'channel.defaultName' => '未命名频道',
			'channel.myOrders' => '我的订单',
			'channel.noOrders' => '暂无订单记录',
			'channel.orderValidUntil' => '有效期至',
			'channel.orderStatusPending' => '待支付',
			'channel.orderStatusPaid' => '已支付',
			'channel.orderStatusRefunded' => '已退款',
			'channel.orderStatusCancelled' => '已取消',
			'channel.orderStatusRefunding' => '退款中',
			'channel.orderStatusExpired' => '已过期',
			'channel.orderDetail' => '订单详情',
			'channel.orderNo' => '订单号',
			'channel.orderChannel' => '频道',
			'channel.orderAmount' => '金额',
			'channel.orderStatusLabel' => '状态',
			'channel.orderPaymentMethod' => '支付方式',
			'channel.orderCreatedAt' => '下单时间',
			'channel.orderPaidAt' => '支付时间',
			'channel.orderSubscriptionPeriod' => '订阅周期',
			'channel.payWallet' => '钱包余额',
			'channel.payAlipay' => '支付宝',
			'channel.payWechat' => '微信支付',
			'channel.refundApply' => '申请退款',
			'channel.refundConfirmTitle' => '确认退款',
			'channel.refundConfirmMessage' => '确定要对该订单申请退款吗？退款后将取消订阅。',
			'channel.refundSuccess' => '退款申请已提交',
			'channel.cancelOrder' => '取消订单',
			'channel.cancelOrderConfirmTitle' => '确认取消订单',
			'channel.cancelOrderConfirmMessage' => '确定要取消该待支付订单吗？取消后不能继续支付。',
			'channel.cancelOrderSuccess' => '订单已取消',
			'channel.orderContinuePay' => '继续支付',
			'channel.comment' => '评论',
			'channel.readFull' => '阅读全文',
			'channel.noComments' => '暂无评论',
			'channel.writeComment' => '写评论...',
			'channel.reply' => '回复',
			'channel.replyTo' => '回复',
			'channel.like' => '点赞',
			'channel.commentFailed' => '评论失败',
			'channel.deleteComment' => '删除评论',
			'channel.deleteCommentConfirm' => '确定删除这条评论吗？',
			'channel.commentDeleteNoPermission' => '无权删除该评论',
			'channel.noMessagesManaged' => '频道还没有发布任何内容',
			'channel.noMessagesManagedDesc' => '作为频道主，你可以点击下方按钮发布第一条内容',
			'channel.noMessagesVisitor' => '订阅后查看频道内容',
			'channel.noMessagesVisitorDesc' => '本频道发布的精彩内容将在订阅后呈现',
			'channel.noMessagesSubscribed' => '频道还没有发布内容',
			'channel.noMessagesSubscribedDesc' => '订阅成功！请耐心等待作者发布新内容',
			'channel.continueEditing' => '继续编辑',
			'channel.publishFirstContent' => '发布第一条内容',
			'channel.noSubscribersDesc' => '还没有订阅者，分享给好友吧',
			'channel.allCategories' => '全部',
			'channel.sortPopular' => '热门',
			'channel.sortNewest' => '最新',
			'channel.emoji' => '表情',
			'channel.justNow' => '刚刚',
			'channel.minutesAgo' => '分钟前',
			'channel.hoursAgo' => '小时前',
			'channel.weeksAgo' => '周前',
			'channel.visibilityLabel' => '可见性',
			'channel.accessTypeLabel' => '付费属性',
			'channel.accessTypeFree' => '免费',
			'channel.accessTypePaid' => '付费',
			'channel.typePublicPaidDesc' => '任何人都可以发现频道，购买后即可订阅',
			'channel.typePrivatePaidDesc' => '仅受邀用户可进入购买流程，付款后即可订阅',
			'channel.info' => '频道信息',
			'channel.settings' => '频道设置',
			'channel.inviteAdmins' => '邀请管理员',
			'channel.shareToMyStatus' => '分享至我的动态',
			'channel.creator' => '创建者',
			'channel.admin' => '管理员',
			'channel.editor' => '编辑',
			'channel.privacyTitle' => '公开频道与隐私保护',
			'channel.privacyDesc' => '任何人都可查找并关注此频道。你的电话号码对其他订阅者或频道管理员完全保密。',
			'channel.aboutThisChannel' => '关于此频道',
			'channel.changePhoto' => '修改照片',
			'channel.addPhoto' => '添加照片',
			'channel.addDescription' => '添加描述',
			'channel.channelCreated' => ({required Object name}) => '频道 “${name}” 已创建',
			'channel.startGrowing' => ({required Object name}) => '开始发展壮大 “${name}”',
			'channel.shareInviteText' => ({required Object name, required Object url}) => '大家快来关注我的频道【${name}】吧！${url}',
			'channel.discussion' => '讨论区',
			'channel.joinDiscussion' => '加入讨论',
			'channel.discussionIneligible' => '订阅该频道后才能加入其讨论群',
			'channel.essence' => '精华',
			'channel.allPosts' => '全部内容',
			'channel.editPostTags' => '编辑标签',
			'channel.linkTitle' => '频道链接',
			'channel.copyLink' => '复制链接',
			'channel.shareLink' => '分享链接',
			'channel.linkAccessHint' => '链接用于打开频道，访问和订阅仍需符合频道权限。企业频道仅限有权限的成员访问。',
			'channel.personalChannelLabel' => '个人频道',
			'channel.enterpriseChannelLabel' => '企业内部频道',
			'channel.subscribePending' => '已订阅，正在刷新',
			'channel.subscribeRefresh' => '刷新订阅状态',
			'channel.unseenUpdatesBanner' => ({required Object count}) => '有 ${count} 条新更新',
			'chat.bankCard' => '银行卡',
			'chat.messageInputHint' => '说点什么...',
			'chat.receivePayment' => '收付款',
			'chat.alreadyMember' => '已是成员',
			'chat.awaitingReply' => '待回复',
			'chat.businessCard' => '名片',
			'chat.busyTryAgainLater' => '对方正忙，请稍后重试',
			'chat.later' => '以后再说',
			'chat.peerIsTyping' => ({required Object name}) => '${name} 正在输入...',
			'chat.chatHoldDownTalk' => '按住说话',
			'chat.chatMessage' => '聊天消息',
			'chat.chatSettingMute' => '消息免打扰',
			'chat.chatSettingMuted' => '已开启免打扰',
			'chat.chatSettingUnmuted' => '已关闭免打扰',
			'chat.chatStatusSending' => '发送中',
			'chat.chatStatusSent' => '已发送',
			'chat.chatStatusDelivered' => '已送达',
			'chat.chatStatusSeen' => '已读',
			'chat.createGroupF2f' => '面对面建群',
			'chat.displayProfile' => '显示你的资料',
			'chat.file' => '文件',
			'chat.unknownFile' => '未知文件',
			'chat.fileSize' => '文件大小',
			'chat.forward' => '转发',
			'chat.forwardTo' => '转发给',
			'chat.forwardToFriend' => '转发给朋友',
			'chat.forwardedToChats' => ({required Object count}) => '已转发给 ${count} 个会话',
			'chat.great' => '非常棒',
			'chat.groupFile' => '群文件',
			'chat.groupFileImagePreview' => '图片预览',
			'chat.groupFileVideoPreview' => '视频预览',
			'chat.groupFileAudioPreview' => '音频预览',
			'chat.groupFileMediaPause' => '暂停',
			'chat.groupFileMediaPlay' => '播放',
			'chat.groupFileUrlMissing' => '文件地址缺失，无法打开',
			'chat.groupFileUrlInvalid' => '文件地址无效',
			'chat.groupFilePreview' => '文件预览',
			'chat.groupFileUnnamed' => '未命名文件',
			'chat.groupFileCategoryEmpty' => ({required Object category}) => '${category}暂无文件',
			'chat.groupFileEmpty' => '暂无群文件',
			'chat.groupFileCategoryDoc' => '文档',
			'chat.groupFileCategoryImage' => '图片',
			'chat.groupFileCategoryVideo' => '视频',
			'chat.groupFileCategoryAudio' => '音频',
			'chat.groupFileCategoryOther' => '其他',
			'chat.groupChat' => '群聊',
			'chat.image' => '图片',
			'chat.imageMessage' => '[图片]',
			'chat.initiateChat' => '发起群聊',
			'chat.exportMyData' => '导出我的数据',
			'chat.exportDataDesc' => '导出你的个人信息、联系人和聊天记录',
			'chat.customMessage' => '自定义消息',
			'chat.card' => '名片',
			'chat.messageWasWithdrawn' => '撤回了一条消息',
			'chat.messageWasWithdrawnWithTitle' => ({required Object param}) => '${param}撤回了一条消息',
			'chat.offline' => '离线',
			'chat.online' => '在线',
			'chat.paramAlreadyExist' => ({required Object param}) => '${param}已存在',
			'chat.pin' => '置顶',
			'chat.pinned' => '已置顶',
			'chat.rating' => '评级',
			'chat.readAgreeParam' => ({required Object param}) => '已经阅读并同意${param}',
			_ => null,
		} ?? switch (path) {
			'chat.remindMeLater' => '下次再说',
			'chat.quickReplyManage' => '管理快捷回复',
			'chat.quickReplyEmpty' => '暂无快捷回复，点击右下角添加',
			'chat.quickReplyDuplicate' => '内容已存在',
			'chat.quickReplyMaxReached' => ({required Object max}) => '最多 ${max} 条',
			'chat.quickReplyHint' => '输入内容...',
			'chat.muteMember' => '禁言成员',
			'chat.unmuteMember' => '取消禁言',
			'chat.muted' => '已禁言',
			'chat.mutedFor' => ({required Object label}) => '禁言 ${label}',
			'chat.muteUnitMinutes' => ({required Object count}) => '${count} 分钟',
			'chat.muteUnitHours' => ({required Object count}) => '${count} 小时',
			'chat.muteUnitDays' => ({required Object count}) => '${count} 天',
			'chat.youAreMuted' => '你已被禁言',
			'chat.youAreMutedWithTime' => ({required Object minutes}) => '你已被禁言，剩余 ${minutes} 分钟',
			'chat.repliedAt' => '回复于',
			'chat.reply' => '回复',
			'chat.resendCode' => '重发验证码',
			'chat.revoke' => '撤回',
			'chat.scanQrCodeBusinessCard' => '扫描二维码名片',
			'chat.privateChat' => '私聊',
			'chat.sendFriendRequest' => '发送添加朋友申请',
			'chat.sendMsgRejected' => '消息已发出，但被对方拒收了。',
			'chat.sendMessage' => '发消息',
			'chat.sendTo' => '发送给',
			'chat.send' => _root.common.buttonSend,
			'chat.releaseConvertToText' => '松开 转文字',
			'chat.voiceReleaseCancelSend' => '松开 取消发送',
			'chat.voiceReleaseCancel' => '松开 取消',
			'chat.voiceSlideHint' => '上滑 取消 / 转文字',
			'chat.convertToText' => '转文字',
			'chat.sending' => '正在发送...',
			'chat.socialProfile' => '社交资料',
			'chat.sureOpenTheFile' => '确定要打开文件吗？',
			'chat.titleMessage' => '消息',
			'chat.unpin' => '取消置顶',
			'chat.userData' => '用户数据',
			'chat.video' => '视频',
			'chat.videoMessage' => '[视频]',
			'chat.viewAttachments' => '浏览附件',
			'chat.viewLargeImage' => '查看大图',
			'chat.voice' => '语音',
			'chat.voiceMessage' => '语音消息',
			'chat.youWithdrewAMessage' => '你撤回了一条消息',
			'chat.formatCheck' => '格式检查',
			'chat.featureRequest' => '功能请求',
			'chat.chatResend' => '重新发送',
			'chat.profileExportProfile' => '导出资料',
			'chat.momentsSend' => '发送',
			'chat.loginExpiredMessage' => '登录过期，请重新登录',
			'chat.alipayLoginInterrupted' => '支付宝登录流程被系统中断，请重试',
			'chat.customImage' => '自定义图片',
			'chat.burnAfterReading' => '阅后即焚',
			'chat.burnReadBadge' => '阅后',
			'chat.goodReadability' => '可读性良好',
			'chat.profileCompleteness' => '资料完善度',
			'chat.tagStatistics' => '标签统计',
			'chat.unsupportedMessageType' => '不支持的消息类型',
			'chat.passwordMismatch' => '两次密码不一致',
			'chat.pleaseTryAgainLater' => '请稍后重试',
			'chat.historyUnavailable' => '历史消息暂不可用',
			'chat.historyUnavailableHint' => '服务端历史归档未开启或暂不可用，点击重试重新同步',
			'chat.momentsRecordVideo' => '拍摄视频',
			'chat.momentsVisibilityPrivate' => '仅自己',
			'chat.momentsMediaTooManyImages' => '最多只能选择 9 张图片',
			'chat.momentsMediaTooManyVideos' => '最多只能选择 1 个视频',
			'chat.momentsMediaMixedImageAndVideo' => '图片和视频不能同时发布',
			'chat.momentsReplyPrefix' => '回复 @',
			'chat.momentsReplySeparator' => '：',
			'chat.momentsReplyingTo' => '正在回复 @{name}',
			'chat.sendNewMessage' => '发送新消息',
			'chat.markRead' => '标记已读',
			'chat.markUnread' => '标记未读',
			'chat.manualPendingBadge' => '待处理',
			'chat.cancelManualPending' => '取消待处理',
			'chat.manualPendingOff' => '非待处理',
			'chat.manualPendingConflict' => ({required Object param}) => '服务端当前状态：${param}',
			'chat.pleaseEnterSignature' => '请输入个性签名',
			'chat.exportProfile' => '导出资料',
			'chat.setSignature' => '设置个性签名',
			'chat.setAvatar' => '设置头像',
			'chat.fastForward' => ({required Object seconds}) => '快进 ${seconds}秒',
			'chat.messageId' => '消息ID',
			'chat.chatType' => '聊天类型',
			'chat.deletingMessage' => '正在删除...',
			'chat.deletingLocalMessage' => '正在删除本地消息...',
			'chat.quickReplyReceived' => '收到',
			'chat.quickReplyThanks' => '谢谢',
			'chat.quickReplyWait' => '稍等',
			'chat.groupCategoryGroupCount' => ({required Object count}) => '${count} 个群聊',
			'chat.groupAlbumCreateTitle' => '新建群相册',
			'chat.groupAlbumCreated' => '相册已创建',
			'chat.profileCompleted' => '资料已完善！',
			'chat.profileProgress' => ({required Object percent}) => '${percent}% 完成',
			'chat.createdAtLabel' => ({required Object time}) => '创建时间: ${time}',
			'chat.expiredAtLabel' => ({required Object time}) => '过期时间: ${time}',
			'chat.myReceivedTab' => '我收到的',
			'chat.orderStatusLabel' => ({required Object status}) => '状态: ${status}',
			'chat.orderCreatedAtLabel' => ({required Object time}) => '创建时间: ${time}',
			'chat.orderPaymentAtLabel' => ({required Object time}) => '支付时间: ${time}',
			'chat.orderStatusPending' => '待支付',
			'chat.orderStatusPaid' => '已支付',
			'chat.orderStatusRefunded' => '已退款',
			'chat.orderStatusExpired' => '已过期',
			'chat.defaultFileName' => '文件',
			'chat.fileUrlInvalid' => '文件链接无效',
			'chat.e2eeStatusAvailable' => '可用',
			'chat.e2eeGenerateNewKey' => '生成新密钥',
			'chat.e2eeGenerateNewKeyDesc' => '生成新的 E2EE 密钥对（旧消息将无法解密）',
			'chat.e2eeActivated' => '已激活',
			'chat.e2eeCreatedAtLabel' => '创建时间',
			'chat.e2eeGeneratingKey' => '正在生成密钥，请稍候...',
			'chat.e2eeNewKeyGenerated' => '新的 E2EE 密钥对已生成！',
			'chat.webFeatureMultiDevice' => '多设备同步',
			'chat.webFeatureMultiDeviceDesc' => '在手机和电脑之间无缝切换，消息实时同步',
			'chat.webFeatureE2EE' => '端到端加密',
			'chat.webFeatureE2EEDesc' => '所有消息都经过端到端加密，确保隐私安全',
			'chat.webFeatureFileTransfer' => '文件传输',
			'chat.webFeatureFileTransferDesc' => '拖拽即可发送文件，支持各种格式',
			'chat.webQRStatusWaiting' => '打开 ImBoy 手机版 > 设置 > 扫一扫',
			'chat.webQRStatusScanned' => '请在手机上点击"确认登录"',
			'chat.webQRStatusVerifying' => '正在验证...',
			'chat.webQRStatusExpired' => '请点击刷新重新扫码',
			'chat.e2eeErrInvalidFormat' => '消息格式错误，加密失败',
			'chat.e2eeRecreatingKey' => '正在重新创建密钥...',
			'chat.e2eeKeyRecreated' => '密钥已重新创建',
			'chat.e2eeRecoveryNewDeviceTitle' => '检测到新设备登录',
			'chat.e2eeRecoveryNewDeviceBody' => '为保护消息安全，本设备已生成新的端到端加密密钥。\n历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「本地备份导入」恢复。',
			'chat.e2eeRecoveryDecryptFailedTitle' => '无法解密此消息',
			'chat.e2eeRecoveryDecryptFailedBody' => '此消息由其他设备的密钥加密。\n\n若你更换了设备或重新安装了应用，请恢复加密密钥后再查看历史消息。',
			'chat.e2eeRecoveryLater' => '稍后',
			'chat.e2eeRecoveryGoRecover' => '去恢复',
			'chat.e2eeRecoveryBannerText' => '部分加密聊天记录暂时无法显示，恢复密钥后即可查看，点此恢复',
			'chat.e2eeMsgBeforeDevice' => '此消息发送于本设备加入之前，无法在本设备显示',
			'chat.e2eeMsgBeforeDeviceTapHint' => '该消息加密时未包含本设备（如换设备前的历史消息），无法在此解密；不影响本设备收发的新消息',
			'chat.liveRoomCreateTitle' => '创建直播间',
			'chat.liveRoomCreating' => '创建中...',
			'chat.liveRoomWatch' => '观看直播',
			'chat.switchToVoiceInput' => '切换到语音输入',
			'chat.switchToKeyboardInput' => '切换到键盘输入',
			'chat.extraItems' => '附加项',
			'chat.invalidMessageType' => '[不支持的消息]',
			'chat.encryptedMessagePlaceholder' => '[加密消息]',
			'chat.e2eeDecryptStoreUnavailable' => '暂时无法访问加密存储，未能解密此消息；请重启应用后重试',
			'chat.invalidMessagePlaceholder' => '[无效消息]',
			'chat.videoCallPlaceholder' => '[视频通话]',
			'chat.voiceCallPlaceholder' => '[语音通话]',
			'chat.notFriendCannotSend' => '非好友关系，无法发送消息',
			'common.about' => '关于',
			'common.aboutApp' => '关于应用',
			'common.accept' => '接受',
			'common.acceptFriendRequest' => '通过好友验证',
			'common.answer' => '接听',
			'common.dataNotFound' => '页面数据不存在或已失效',
			'common.declineCall' => '拒绝',
			'common.reconnecting' => '网络不佳，正在重连...',
			'common.minimize' => '最小化',
			'common.switchCamera' => '切换摄像头',
			'common.addFriend' => '添加朋友',
			'common.smallChange' => '零钱',
			'common.addTag' => '添加标签',
			'common.addToContacts' => '添加到通讯录',
			'common.addToDenylist' => '加入黑名单',
			'common.added' => '已添加',
			'common.addedToDenylistTips' => '已添加至黑名单，你将不再收到对方的消息',
			'common.all' => '全部',
			'common.allTime' => '所有时间',
			'common.allTypes' => '所有类型',
			'common.allowSearchMe' => '允许搜索我',
			'common.allowedBeSearched' => '最近新注册的并且允许被搜索到的朋友',
			'common.appSizeTips' => '包含APP运行的必要文件，包括 APK 文件、优化的编译器输出和解压的原生库。',
			'common.applyAddFriend' => '申请添加朋友',
			'common.awaitingVerification' => '等待验证',
			'common.buttonAccomplish' => '完成',
			'common.buttonAdd' => '添加',
			'common.buttonBack' => '返回',
			'common.bindMobileAndEmailTips' => '绑定手机号和邮箱，让你的账户更安全',
			'common.bindNow' => '立即绑定',
			'common.buttonCancel' => '取消',
			'common.buttonCreate' => '创建',
			'common.phoneInputHint' => '请输入手机号',
			'common.buttonMore' => '更多',
			'common.buttonRefresh' => '刷新',
			'common.buttonClose' => '关闭',
			'common.buttonConfirm' => '确认',
			'common.buttonContinue' => '继续',
			'common.buttonCopy' => '复制',
			'common.buttonDelete' => '删除',
			'common.buttonLogout' => '退出登录',
			'common.buttonOk' => '确定',
			'common.buttonRetry' => '重试',
			'common.buttonSave' => '保存',
			'common.buttonSelectFromAlbum' => '从相册选择',
			'common.buttonSend' => '发送',
			'common.buttonTakingPictures' => '拍照',
			'common.cacheTips' => '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。',
			'common.callDuration' => '通话时长',
			'common.callEnded' => '通话已结束',
			'common.calling' => '正在通话',
			'common.cancel' => _root.common.buttonCancel,
			'common.ok' => _root.common.buttonOk,
			'common.operationSuccessful' => '操作成功',
			'common.save' => _root.common.buttonSave,
			'common.reset' => '重置',
			'common.clear' => '清空',
			'common.saveTag' => ({required Object count}) => '保存标签 (${count})',
			'common.cancelLogoutBody' => '此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。',
			'common.cancelLogoutTitle' => '是否终止注销流程？',
			'common.cancelled' => '已取消',
			'common.chatSettingBackground' => '聊天背景',
			'common.chatSettingPinnedSuccess' => '置顶成功',
			'common.chatSettingUnpinnedSuccess' => '取消置顶',
			'common.chatSettings' => '聊天设置',
			'common.chatStatusFailed' => '发送失败',
			'common.chatErrorInDenylist' => '对方已将你加入黑名单',
			'common.checkForUpdates' => '检查更新',
			'common.clearAll' => '清除全部',
			'common.clearChatRecord' => '清空聊天记录',
			'common.complaintSuccess' => '投诉已提交',
			'common.complaintFailed' => '投诉失败，请稍后再试',
			'common.confirmDeleteChatRecord' => '确定删除聊天记录吗？',
			'common.confirmRecoverSuccess' => '密码修改成功。',
			'common.contactSetting' => '联系人设置',
			'common.contactTags' => '联系人标签',
			'common.contactInfoNotSynced' => '联系人信息未同步',
			'common.continueDownloading' => '继续下载',
			'common.copy' => '复制',
			'common.createGroupF2fConfirmTips' => '这些朋友也将进入群聊',
			'common.createGroupF2fTips' => '和身边的朋友输入同样的四个数字，进入同一个群聊',
			'common.f2fSecretCode' => '暗号',
			'common.f2fEnteringGroup' => ({required Object count}) => '${count} 人即将进入群聊',
			'common.delete' => _root.common.buttonDelete,
			'common.deleteCollectConfirmDesc' => '删除后无法恢复，确定要删除这条收藏吗？',
			'common.deleteContact' => '删除联系人',
			'common.deleteForEveryone' => '删除所有人的消息',
			'common.deleteForMe' => '删除我的消息',
			'common.deleteTagTips' => '删除标签后，标签中的联系人不会被删除',
			'common.deleteThisDevice' => '删除该设备',
			'common.deleteThisDeviceTips' => '删除后，下次在该设备登录时需要进行安全验证。',
			'common.denylistNoteDesc' => '被拉黑的用户无法给你发送消息，也无法查看你的动态。点击用户可以查看详情。',
			'common.denylistNoteTitle' => '黑名单说明',
			'common.details' => '详情',
			'common.deviceDetails' => '设备详情',
			'common.downloaded' => '已下载',
			'common.edit' => '编辑',
			'common.editTag' => '编辑标签',
			'common.errorEmptyDirectory' => ({required Object param}) => '${param} 是空的',
			'common.errorFailedConnectServer' => _root.common.error,
			'common.errorHttpNotSupported' => _root.common.error,
			'common.errorInternalServer' => _root.common.error,
			'common.errorInvalid' => ({required Object param}) => '${param} 是无效的',
			'common.errorInvalidRequest' => _root.common.error,
			'common.errorLengthBetween' => ({required Object param, required Object min, required Object max}) => '${param} 长度必须在 ${min} 和 ${max} 之间',
			'common.errorManyRequest' => '请求过于频繁',
			'common.errorPassword' => '密码错误',
			'common.errorRequestForbidden' => _root.common.error,
			'common.errorRequestSyntax' => _root.common.error,
			'common.errorRequired' => ({required Object param}) => '${param} 是必须的',
			'common.errorRetypePassword' => _root.common.error,
			'common.errorServerDown' => _root.common.error,
			'common.errorServerRefused' => _root.common.error,
			'common.errorUnexpected' => _root.common.error,
			'common.failedGetLatLong' => _root.common.errorNetwork,
			'common.failedGetMapTryAgain' => _root.common.errorNetwork,
			'common.failedRequestPleaseCheckNetwork' => _root.common.errorNetwork,
			'common.feedback' => '反馈建议',
			'common.feedbackContentRequired' => '反馈内容不能为空',
			'common.feedbackDetails' => '反馈建议明细',
			'common.feedbackSuccessMsg' => '你的反馈问题我们已经收到了，会尽快处理！',
			'common.followSystemTips' => '开启后，将跟随系统打开或关闭深色模式',
			'common.genderUpdateFailed' => '性别设置失败，请重试',
			'common.groupAnnouncement' => '群公告',
			'common.groupFileUploadSuccess' => '文件上传成功',
			'common.groupFileUploadFailed' => '文件上传失败，请稍后重试',
			'common.groupFileDeleteSuccess' => '文件已删除',
			'common.groupFileDeleteFailed' => '删除失败，请稍后重试',
			'common.groupFileUploadTooltip' => '上传文件',
			'common.groupFileSearch' => '搜索群文件',
			'common.groupFileReadFailed' => '文件读取失败，请重试',
			'common.groupFileDeleteTitle' => '删除群文件',
			'common.groupFileDeleteConfirm' => ({required Object name}) => '确定删除文件「${name}」吗？',
			'common.groupFileImageLoadFailed' => '图片加载失败',
			'common.groupFileOpenFailed' => '无法打开文件链接',
			'common.groupFileCategoryAll' => '全部',
			'common.groupFileSearchEmpty' => '未找到匹配文件',
			'common.groupFileAudioLoadFailed' => '音频加载失败',
			'common.groupFileAudioLoading' => '音频加载中...',
			'common.groupQrcodeTips' => ({required Object days, required Object date}) => '该二维码${days}天内（${date}前）有效，重新进入将更新',
			'common.helpDocument' => '帮助文档',
			'common.incomingCall' => ({required Object param}) => '${param}呼入',
			'common.installNow' => '立即安装',
			'common.iosAppIdUnknown' => ({required Object param}) => 'AppStore未上架或AppID[${param}]不存在',
			'common.koKr' => '韩语（韩国）',
			'common.languageSetting' => '语言设置',
			'common.lastActiveTips' => '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。',
			'common.lastSeenJustNow' => '刚刚上线',
			'common.lastSeenLongTimeAgo' => '很久以前上线',
			'common.lastSeenMonthsAgo' => ({required Object param}) => '${param}个月前',
			'common.loadError' => '加载失败，请重试',
			'common.loadMore' => '加载更多',
			'common.loading' => '加载中',
			'common.locationMessage' => '位置消息',
			'common.loginDeviceManagementTips' => '你的账号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。',
			'common.logoutFailed' => '退出登录失败',
			'common.messageCall' => '发消息',
			'common.messageContent' => '消息内容',
			'common.messageRevoked' => '消息已撤回',
			'common.quoteMessageNotAvailable' => '引用的消息不可用',
			'common.quoteMessageUnavailable' => '无法获取这条引用消息，可能已过期或不在当前可访问的历史中，请重试或向发送者确认',
			'common.quoteMessageAuthorizationUnavailable' => '暂时无法确认这条历史消息的访问权限，请稍后重试或联系会话管理员',
			'common.quoteMessageExpired' => '引用的消息已过期，无法恢复；请向发送者确认内容',
			'common.quoteMessageForbidden' => '你没有权限查看这条引用消息，请联系会话管理员确认权限',
			'common.quoteMessageLoadFailed' => '引用消息加载失败，请检查网络后重新点击重试',
			'common.quoteMessageUndecryptable' => '本设备无法解密这条引用消息，请重试或请发送者重新发送',
			'common.microphone' => '麦克风',
			'common.microphonePermissionNotObtained' => '未获取到麦克风权限',
			'common.moreInfo' => '更多信息',
			'common.nearbyPeopleTips' => '与附近的人交换联系方式，结交新朋友',
			'common.needContinueWorkHard' => '需要继续加油',
			'common.networkErrorWithAction' => ({required Object param}) => '${param}失败，请检查网络连接',
			'common.networkException' => '网络连接异常',
			'common.errorNetwork' => '网络错误',
			'common.networkExceptionPlaseNeedNetworkToViewData' => '网络状态异常，需要打开网络才能够查看数据',
			'common.newVersionDetected' => '检测到新版本',
			'common.newVersionDetectedWithVersion' => ({required Object param}) => '检测到新版本 ${param}',
			'common.nextStep' => '下一步',
			'common.nicknameEmojiOnlyError' => '昵称不能仅包含表情符号',
			'common.nicknameEmptyError' => '昵称不能为空',
			'common.nicknameLengthError' => '昵称长度应在2-24个字符之间',
			'common.nicknameSensitiveWordError' => '昵称包含敏感词，请重新输入',
			'common.nicknameUpdateFailed' => '昵称修改失败，请重试',
			'common.nicknameWhitespaceError' => '昵称不能仅包含空白字符',
			'common.noAvatar' => '无头像',
			'common.noBarcodeFound' => '未识别到二维码',
			'common.noContacts' => '无联系人',
			'common.noConversationMessages' => '无会话消息',
			'common.noData' => '暂无数据',
			'common.noMembersInCurrentTag' => '当前标签无成员',
			'common.noNewFriends' => '没有新的好友',
			'common.noPermission' => '没有权限',
			'common.noReply' => '暂无回复',
			'common.noUpdateDescription' => '无更新说明',
			'common.notAuthorizedLatLong' => '你还没有授权获取经纬度',
			'common.notLoggedIn' => '未登录',
			'common.notBad' => '还不错',
			'common.notBound' => '未绑定',
			'common.notFilled' => '未填写',
			'common.notInstallAnyMapApp' => '你没有安装任何地图APP哦',
			'common.notReceiveCoeQ' => '没有收到验证码？',
			'common.notSet' => '未设置',
			'common.notTurnedLocationService' => '你还没有打开位置信息服务',
			'common.nowNewVersion' => '未检测到新版本',
			'common.offlineNotification' => '下线通知',
			'common.operationFailedAgainLater' => '操作失败，请稍后重试',
			'common.pauseDownloading' => '暂停下载',
			'common.peerNoResponse' => '对方无应答...',
			'common.permissionAcquisitionFailed' => '权限获取失败',
			'common.personalCard' => '个人名片',
			'common.personalInformation' => '个人信息',
			'common.pinCodeFillTips' => '请把方格填满',
			'common.profileSettings' => '资料设置',
			'common.reEdit' => '重新编辑',
			'common.regionSearchHint' => '按地区名称搜索',
			'common.regionSelectedLevelHint' => ({required Object region, required Object level}) => '已选 ${region}（第 ${level} 级）：可直接点右上角完成，也可继续选择下一级',
			'common.releaseFingerCancelSending' => '松开手指，取消发送',
			'common.removeContactFromTag' => '从标签中移除联系人',
			'common.removeMember' => '移出成员',
			'common.atMentionYouTag' => '[@你]',
			'common.atMentionLeftMember' => '@已退群成员',
			'common.muteNotifications' => '消息免打扰',
			'common.muteNotificationsHint' => '开启后不会收到新消息提醒，但仍可在会话列表看到未读',
			'common.revokeExpired' => '超过 2 分钟，无法撤回',
			'common.quickReplyAddTitle' => '新增快捷回复',
			'common.quickReplyEditTitle' => '编辑快捷回复',
			'common.removeAdmin' => '取消管理员',
			'common.setAdminConfirm' => '确定将此成员设为管理员吗？',
			'common.removeAdminConfirm' => '确定取消此成员的管理员身份吗？',
			'common.unmuteMemberConfirm' => '确定取消禁言此成员吗？',
			'common.kickMemberConfirm' => '确定将此成员移出群聊吗？',
			'common.setAdminSuccess' => '已设为管理员',
			'common.setAdminFailed' => '设置管理员失败',
			'common.removeAdminSuccess' => '已取消管理员',
			'common.removeAdminFailed' => '取消管理员失败',
			'common.muteMemberSuccess' => '已禁言',
			'common.muteMemberFailed' => '禁言失败',
			'common.unmuteMemberSuccess' => '已取消禁言',
			'common.unmuteMemberFailed' => '取消禁言失败',
			'common.kickMemberSuccess' => '已移出群聊',
			'common.kickMemberFailed' => '移出群聊失败',
			'common.notMuted' => '未禁言',
			'common.muteDuration' => '禁言时长',
			'common.muteDuration1hour' => '1小时',
			'common.muteDuration1day' => '1天',
			'common.muteDuration7days' => '7天',
			'common.muteDuration5min' => '5分钟',
			'common.muteDuration10min' => '10分钟',
			'common.muteDuration30min' => '30分钟',
			'common.muteDuration30days' => '30天',
			'common.muteUnitSeconds' => ({required Object count}) => '${count} 秒',
			'common.throttleWarning' => '操作频率过高，请稍后再试',
			'common.throttleRetryAfter' => ({required Object seconds}) => '操作频率过高，请 ${seconds} 秒后再试',
			'common.mutedCannotSend' => '禁言期间无法发送消息',
			'common.resetFilters' => '重置筛选',
			'common.saveQrCode' => '保存二维码',
			'common.saveSuccess' => '保存成功',
			'common.scanQrcodeAddFriend' => '扫一扫上面的二维码图案，加我为朋友',
			'common.search' => '搜索',
			'common.searchScope' => '搜索范围',
			'common.searchAll' => '全部消息',
			'common.searchChatContent' => '查找聊天内容',
			'common.searchChatRecord' => '查找聊天记录',
			'common.searchError' => '搜索错误',
			'common.searchHint' => '输入关键词搜索消息',
			'common.searchHistory' => '搜索历史',
			'common.searchLocation' => '搜索地点',
			'common.searchMessagesHint' => '搜索聊天内容',
			'common.searchNoFound' => '搜索结果为空 :(',
			'common.searchNoResults' => '无搜索结果',
			'common.noSearchHistory' => '暂无搜索历史',
			'common.searchResults' => '搜索结果',
			'common.selectAll' => '全选',
			'common.selectContacts' => '选择联系人',
			'common.selectedRegion' => '已选地区',
			'common.sendMsgNotFriendTips' => '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。',
			'common.share' => '分享',
			'common.slideUpCancelSending' => '手指上滑，取消发送',
			'common.storagePermissionNotObtained' => '未获取存储权限',
			'common.submittedAt' => '提交于',
			'common.sureDeleteData' => '确认删除吗？删除后不可恢复。',
			'common.sureDeleteGroupChatRecord' => '确定删除群的聊天记录吗？',
			'common.switchEnvironment' => '切换环境',
			'common.timeDaysAgo' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(n, other: '${n}天前', ), 
			'common.timeHoursAgo' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(n, other: '${n}小时前', ), 
			'common.timeJustNow' => '刚刚',
			'common.timeMinutesAgo' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(n, other: '${n}分钟前', ), 
			'common.tipConnectDesc' => '无网络',
			'common.tipConnectDescWithParen' => ({required Object param}) => '(${param})',
			'common.tipDeleteContact' => ({required Object param}) => '将联系人"${param}"删除，同时删除与该联系人的聊天记录',
			'common.tipDeviceSpace' => ({required Object param1, required Object param2}) => '占设备 ${param1}% 存储空间(${param2})',
			'common.tipDraft' => '草稿',
			'common.tipFailed' => '操作失败！',
			'common.tipSuccess' => '操作成功！',
			'common.tipTips' => '小贴士',
			'common.titleContact' => '联系人',
			'common.today' => '今天',
			'common.unknown' => '未知',
			'common.unknownMessage' => '未知消息',
			'common.updateLog' => '更新日志',
			'common.updateNow' => '立即更新',
			'common.uploading' => '上传中',
			'common.uploadSuccess' => '上传成功',
			'common.uploadFailed' => '上传失败',
			'common.userDataTips' => '包含APP运行时必要的文件，以及聊天消息、好友关系等所有记录数据。',
			'common.userDisabledOrDeleted' => '用户被禁用或已删除',
			'common.userNotExist' => '用户不存在',
			'common.version' => '版本',
			'common.videoCall' => '视频通话',
			'common.viewAllGroupMember' => '查看全部群成员',
			'common.voiceCall' => '语音通话',
			'common.groupCall' => '群通话',
			'common.callDisconnected' => '通话已断开',
			'common.connecting' => '连接中...',
			'common.voiceInputNotImplemented' => '语音输入功能暂无实现',
			'common.waitingDownload' => '等待下载',
			'common.waitingPeerAccept' => '等待对方接受邀请...',
			'common.warning' => '警告:',
			'common.webpageLoading' => '网页加载中...',
			'common.yesterday' => '昨天',
			'common.confirmRemoveFromDenylist' => '确认将此用户移出黑名单？',
			'common.buttonRemove' => '移出',
			'common.removedFromDenylist' => '已移出黑名单',
			'common.newEmailAddress' => '新邮箱地址',
			'common.emailAddress' => '邮箱地址',
			'common.enterEmailAddress' => '请输入邮箱地址',
			'common.getVerificationCode' => '获取验证码',
			'common.confirmChange' => '确认更换',
			'common.verificationCodeSentToEmail' => '验证码将发送至该邮箱，请在有效期内完成验证',
			'common.verificationCodeSentToMobile' => '验证码将发送至该手机，请在有效期内完成验证',
			'common.sendFailed' => '发送失败',
			'common.forceOffline' => '下线',
			'common.forceDeviceOffline' => '让该设备下线',
			'common.forceDeviceOfflineConfirm' => '将向该设备发送下线指令，确认继续？',
			'common.confirmForceOffline' => '确认下线',
			'common.forceOfflineCommandSent' => '已发送下线指令',
			'common.feedbackSlogan' => '你的建议是我们改进的动力',
			'common.newFeedback' => '新建反馈',
			'common.feedbackHistory' => '反馈历史',
			'common.confirmDelete' => '确认删除',
			'common.verificationCode' => '验证码',
			'common.feedbackContent' => '反馈内容',
			'common.officialReply' => '官方回复',
			'common.setPasswordSecurityTips' => '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。',
			'common.locationHidden' => '已隐藏你的位置',
			'common.locationVisible' => '已显示你的位置',
			'common.noNearbyPeople' => '暂无附近的人',
			'common.clickSearchButtonToFind' => '点击上方的搜索按钮查找附近的人',
			'common.operationFailed' => _root.common.error,
			'common.featureInDevelopment' => '功能开发中...',
			'common.addedToDenylist' => '已加入黑名单',
			'common.groupAnnouncementPublish' => '发布公告',
			'common.pleaseEnterAnnouncementContent' => '请输入公告内容',
			'common.selectExpirationDateOptional' => '选择有效期（可选）',
			'common.groupAnnouncementDeleteConfirm' => '确定要删除这条公告吗？',
			'common.groupAnnouncementDelete' => '删除',
			'common.groupAnnouncementLoadFailed' => '公告加载失败，请稍后重试',
			'common.groupAnnouncementPublishFailed' => '公告发布失败',
			'common.groupAnnouncementPublishSuccess' => '公告已发布',
			'common.groupAnnouncementDeleteFailed' => '公告删除失败',
			'common.groupAnnouncementDeleteSuccess' => '公告已删除',
			'common.privacyClearChatHistory' => '清除聊天记录',
			'common.privacyClearChatHistoryConfirm' => '确定要清除所有聊天记录吗？此操作不可恢复。',
			'common.privacyLogoutAccountConfirm' => '确定要注销账号吗？此操作将永久删除你的账号和所有数据，且不可恢复。',
			_ => null,
		} ?? switch (path) {
			'common.privacySettings' => '隐私设置',
			'common.searchSettings' => '搜索设置',
			'common.allowSearchByAccount' => '允许通过账号搜索',
			'common.allowSearchByAccountDesc' => '其他用户可以通过你的账号找到你',
			'common.allowAddByPhone' => '允许通过手机号添加',
			'common.allowAddByPhoneDesc' => '其他用户可以通过你的手机号添加你为好友',
			'common.allowAddByQR' => '允许通过二维码添加',
			'common.allowAddByQRDesc' => '其他用户可以通过扫描你的二维码添加你为好友',
			'common.statusSettings' => '状态设置',
			'common.showOnlineStatus' => '显示在线状态',
			'common.showOnlineStatusDesc' => '关闭后，好友看不到你的在线状态和最后上线时间；消息投递不受影响',
			'common.allowNearbyVisible' => '附近的人可见',
			'common.dataSettings' => '数据设置',
			'common.clearChatRecords' => '清除聊天记录',
			'common.clearChatRecordsDesc' => '清除所有聊天记录，此操作不可恢复',
			'common.deleteAccountAction' => '注销账号',
			'common.deleteAccountActionDesc' => '永久删除账号和所有数据，此操作不可恢复',
			'common.chatHistoryCleared' => '聊天记录已清除',
			'common.chatDeleteMessage' => '删除消息',
			'common.chatCopy' => '复制',
			'common.chatSaveImage' => '保存图片',
			'common.chatDeleteLocalOnly' => '仅删除本地',
			'common.chatDeleteFailed' => '删除失败',
			'common.chatNetworkErrorDeleteLocal' => '网络连接失败，是否仅删除本地消息？',
			'common.chatDeleteConfirm' => '确定要删除这条消息吗？此操作无法撤销。',
			'common.chatDeleteOnlyLocal' => '仅在你这里删除，对方仍可见',
			'common.chatDeleteAll' => '从所有人的聊天中删除，无法撤销',
			'common.chatInitFailed' => '聊天初始化失败',
			'common.cameraShootFailed' => '拍摄失败',
			'common.cameraCapture' => '拍摄',
			'common.cameraModePhoto' => '照片',
			'common.cameraModeVideo' => '视频',
			'common.cameraRetake' => '重拍',
			'common.cameraUse' => '使用',
			'common.cameraNoDevice' => '未检测到可用的摄像头',
			'common.avatarEditAvatar' => '编辑头像',
			'common.backgroundUseCustomColor' => '使用自定义颜色',
			'common.backgroundOnlySolidColor' => '仅适用于纯色背景',
			'common.backgroundSelectColor' => '选择颜色',
			'common.profileShareProfile' => '分享资料',
			'common.tagClearAllConfirm' => '确定要清空所有标签吗？',
			'common.tagClearAll' => '确认清空',
			'common.audioPlayFailed' => '播放失败',
			'common.forcedOfflineByDevice' => ({required Object device}) => '你已被设备【${device}】强制下线',
			'common.loadingTagDataFailed' => '加载标签数据失败',
			'common.pleaseEnterContent' => '请输入内容',
			'common.comingSoon' => '敬请期待',
			'common.backgroundTransparency' => '背景透明度',
			'common.defaultBackground' => '默认背景',
			'common.solidColorBackground' => '纯色背景',
			'common.selectImageFailed' => '选择图片失败',
			'common.locationSelectNotImplemented' => '位置选择功能暂未实现',
			'common.selectLocationFailed' => '选择位置失败',
			'common.sendCardNotImplemented' => '名片发送功能暂未实现',
			'common.voiceSendFailed' => '语音发送失败',
			'common.featureNotImplemented' => '功能暂未实现',
			'common.sendCollectionNotImplemented' => '收藏发送功能暂未实现',
			'common.fileOpenNotImplemented' => '文件打开功能暂未实现',
			'common.fileShareNotImplemented' => '文件分享功能暂未实现',
			'common.retrySuccess' => '重试成功',
			'common.deleteSuccess' => '删除成功',
			'common.localDeleteSuccess' => '本地删除成功',
			'common.localDeleteFailed' => '本地删除失败',
			'common.revokeSuccess' => '撤回成功',
			'common.editContentCannotBeEmpty' => '编辑内容不能为空',
			'common.editSuccess' => '编辑成功',
			'common.enabled' => '已开启',
			'common.disabled' => '已关闭',
			'common.fontSizeSettingUpdated' => '字体大小设置已更新',
			'common.fontSizeSetting' => '字体大小设置',
			'common.fontTooSmallMayAffect' => '字体偏小，可能影响阅读',
			'common.dragSliderAdjustFontSize' => '拖动滑块调整字体大小',
			'common.personalInfo' => '个人信息',
			'common.nicknameNotSet' => '未设置昵称',
			'common.basicInfo' => '基本信息',
			'common.contactInfo' => '联系信息',
			'common.editTags' => '编辑标签',
			'common.quickActions' => '快捷操作',
			'common.noNewFriendRequests' => '暂时没有新的好友申请',
			'common.pleaseEnterVerificationMessage' => '请输入验证消息',
			'common.unknownRegion' => '未知地区',
			'common.noCommonGroups' => '暂无共同群组',
			'common.noMoreInfo' => '暂无更多信息',
			'common.verificationMessage' => '验证消息',
			'common.burnEnabledMessage' => ({required Object duration}) => '开启后：消息在被阅读后 ${duration} 自动销毁',
			'common.burnDisabledMessage' => '关闭后：消息不会自动销毁',
			'common.noGroupAnnouncement' => '暂无群公告',
			'common.featureComingSoon' => '功能暂未实现',
			'common.understood' => '明白了',
			'common.noProblem' => '没问题',
			'common.onMyWay' => '马上到',
			'common.operationOptions' => '操作选项',
			'common.copyTextContent' => '复制文本内容',
			'common.shareWithOtherFriends' => '分享给其他好友',
			'common.addTagsToFavorites' => '为收藏添加标签',
			'common.addRemarkToFavorites' => '为收藏添加备注',
			'common.deleteThisCollection' => '删除此收藏',
			'common.changeSuccess' => '修改成功',
			'common.lengthOk' => '长度符合',
			'common.confirmNewPassword' => '确认新密码',
			'common.validationPassed' => '验证通过',
			'common.momentsContentHint' => '写点什么...',
			'common.momentsAddMedia' => '添加媒体',
			'common.momentsAllowUidsLabel' => '允许可见 UID 列表（逗号分隔）',
			'common.momentsNoData' => '暂无动态',
			'common.momentsDeleteConfirm' => '确定删除这条动态吗？',
			'common.momentsDeleteCommentConfirm' => '确定删除这条评论吗？',
			'common.momentsNotFound' => '动态不存在或无权限查看',
			'common.momentsContentOrMediaRequired' => '内容或媒体至少填写一项',
			'common.momentsPublishFailed' => '发布失败',
			'common.momentsAllowComment' => '允许评论',
			'common.momentsNoComments' => '暂无评论',
			'common.momentsCommentFailed' => '评论失败，请稍后重试',
			'common.momentsDeleteFailed' => '删除失败，请稍后重试',
			'common.momentsReportSubmitted' => '举报已提交',
			'common.momentsReportFailed' => '举报失败，请稍后重试',
			'common.momentReportReasonSpam' => '垃圾广告',
			'common.momentReportReasonHarassment' => '骚扰霸凌',
			'common.momentReportReasonPorn' => '色情低俗',
			'common.momentReportReasonFraud' => '欺诈诈骗',
			'common.momentReportReasonInfringement' => '侵权抄袭',
			'common.momentReportReasonOther' => '其他',
			'common.momentReportReasonPrompt' => '请选择举报原因',
			'common.momentsLoadMoreComments' => '加载更多评论',
			'common.momentsUploadFailed' => '媒体上传失败，请稍后重试',
			'common.momentsHasFailedUploads' => '有媒体上传失败，请重试或移除后再发布',
			'common.uploadPartialFailed' => ({required Object count}) => '${count} 项上传失败',
			'common.saveFailed' => '保存失败',
			'common.confirm' => '确认',
			'common.success' => '成功',
			'common.personalDisplay' => '个人展示',
			'common.personalSignature' => '个性签名',
			'common.personalBackground' => '个人背景',
			'common.expression' => '表情',
			'common.extendedInfo' => '扩展信息',
			'common.profession' => '职业',
			'common.shareFailed' => '分享失败',
			'common.exportSuccessThenCopiedToClipboard' => ({required Object param}) => '${param} 格式资料已导出并复制到剪贴板',
			'common.setRegion' => '设置地区',
			'common.deleteOperationAbnormal' => '删除操作异常，请重试',
			'common.revoking' => '正在撤回...',
			'common.editing' => '正在编辑...',
			'common.messageIdCannotBeEmpty' => '消息ID为空，无法操作',
			'common.startRevokeMessageFlow' => '开始撤回消息流程',
			'common.revokeMessageTracking' => '撤回消息追踪',
			'common.useNewActionMechanism' => '使用新的action机制',
			'common.revokeMessageSendResult' => '撤回消息发送结果',
			'common.revokeRequestSendComplete' => '撤回请求发送完成',
			'common.revokeFailed' => '撤回失败',
			'common.revokeMessageException' => '撤回消息异常',
			'common.revokeOperationAbnormal' => '撤回操作异常',
			'common.startEditMessageFlow' => '开始编辑消息流程',
			'common.editMessageTracking' => '编辑消息追踪',
			'common.newContent' => '新内容',
			'common.editMessageSendResult' => '编辑消息发送结果',
			'common.editRequestSendComplete' => '编辑请求发送完成',
			'common.editFailed' => '编辑失败',
			'common.editMessageException' => '编辑消息异常',
			'common.editOperationAbnormal' => '编辑操作异常',
			'common.error' => '错误',
			'common.cannotOpenWebpage' => '无法打开网页',
			'common.selectImageFailedWithError' => '选择图片失败',
			'common.reactionAdded' => '已添加反应',
			'common.reactionCancelled' => '已取消反应',
			'common.retryFailedPleaseCheckNetwork' => '重试失败，请检查网络连接',
			'common.retryAbnormal' => '重试异常',
			'common.deleteFailedPleaseTryAgain' => '删除失败，请重试',
			'common.deleteFailedPleaseCheckNetwork' => '删除失败，请检查网络连接',
			'common.seconds' => '秒',
			'common.settingFailedPleaseTryAgain' => '设置失败，请重试',
			'common.partialDeleteSuccess' => ({required Object success, required Object fail}) => '部分删除成功：${success} 成功，${fail} 失败',
			'common.recordingCancelled' => '录音已取消',
			'common.voiceSttPreviewTitle' => '语音转文字预览',
			'common.voiceSttConverting' => '正在识别中...',
			'common.voiceSttNotConfigured' => '转文字功能暂未配置',
			'common.pullOfflineMessagesFailed' => '拉取离线消息失败',
			'common.pullOfflineMessagesAbnormal' => '拉取离线消息异常',
			'common.logoutRequestFailedPleaseCheckNetwork' => '退出登录请求失败，请检查网络连接',
			'common.permissionOnlySupportAndroidAndIos' => 'Permission 只支持 Android 和 IOS',
			'common.retryingSend' => '正在重试发送...',
			'common.quickReplyOk' => '好的',
			'common.quickReplyOkThanks' => '好的，谢谢',
			'common.noDetailedInfo' => '该用户还没有设置个人签名等详细信息',
			'common.noNewRegisteredUsersTitle' => '暂无新注册用户',
			'common.noNewRegisteredUsers' => '当前没有新注册的用户 请稍后再来查看',
			'common.newRegisteredUsersTip' => '这里显示最近注册的用户，你可以主动添加他们为好友',
			'common.notificationFriendRequest' => '好友请求',
			'common.notificationFriendRequestBody' => ({required Object requesterName}) => '${requesterName} 请求添加你为好友',
			'common.notificationGroupInvite' => '群邀请',
			'common.notificationGroupInviteBody' => ({required Object inviterName, required Object groupName}) => '${inviterName} 邀请你加入群组 ${groupName}',
			'common.youRevokedMessage' => '你撤回了一条消息',
			'common.otherRevokedMessage' => '对方撤回了一条消息',
			'common.networkFailureTryAgain' => '网络故障，请重试！',
			'common.networkNotAvailable' => '当前网络不可用。',
			'common.pleaseCheckNetworkConnection' => '请检查你的网络连接。',
			'common.lastSeenMinutesAgo' => ({required num n}) => _root.common.timeMinutesAgo(n: n),
			'common.lastSeenHoursAgo' => ({required num n}) => _root.common.timeHoursAgo(n: n),
			'common.lastSeenDaysAgo' => ({required num n}) => _root.common.timeDaysAgo(n: n),
			'common.fontSettings' => _root.common.fontSizeSetting,
			'common.noFavoritesYet' => '暂无收藏内容，快去收藏一些有趣的消息吧',
			'common.fontPreviewText' => '这是正文内容，你可以在这里看到不同字体大小的显示效果。',
			'common.smaller' => '更小',
			'common.currentFontScale' => ({required Object param1, required Object param2}) => '当前：${param1} ${param2}%',
			'common.groupAnnouncementExpiry' => ({required Object time}) => '有效期至: ${time}',
			'common.groupAlbumCreateFailed' => '创建失败，请稍后重试',
			'common.groupAlbumDeleteTitle' => '删除群相册',
			'common.groupAlbumDeleteConfirm' => ({required Object name}) => '确定删除相册「${name}」吗？',
			'common.groupAlbumDeleted' => '相册已删除',
			'common.groupAlbumDeleteFailed' => '删除失败，请稍后重试',
			'common.groupAlbumRenameFailed' => '更新失败，请稍后重试',
			'common.groupAlbumUploadTooltip' => '上传图片',
			'common.groupAlbumDeleteTooltip' => '删除相册',
			'common.groupAlbumNoAlbum' => '暂无群相册',
			'common.groupAlbumPhotoReadFailed' => '图片读取失败，请重试',
			'common.groupAlbumPhotoUploaded' => '图片上传成功',
			'common.groupAlbumPhotoUploadFailed' => '图片上传失败，请稍后重试',
			'common.groupAlbumCreateTooltip' => '新建相册',
			'common.groupAlbumPhotoBatchDeleteTitle' => '批量删除图片',
			'common.groupAlbumPhotoBatchDeleteConfirm' => ({required Object count}) => '确定删除选中的 ${count} 张图片吗？',
			'common.groupAlbumPhotoDeleteFailed' => '删除失败，请稍后重试',
			'common.groupAlbumPhotoDeletedAll' => ({required Object count}) => '已删除${count}张图片',
			'common.groupAlbumPhotoDeletedPartial' => ({required Object success, required Object fail}) => '已删除${success}张，${fail}张删除失败',
			'common.groupAlbumPhotoDeleteTitle' => '删除图片',
			'common.groupAlbumPhotoDeleteConfirm' => '确定删除这张图片吗？',
			'common.groupAlbumPhotoDeleted' => '图片已删除',
			'common.groupAlbumPhotoBatchDeleteTooltip' => '批量删除',
			'common.groupAlbumPhotoExitSelection' => '退出选择',
			'common.groupAlbumPhotoOpenFailed' => '无法打开图片链接',
			'common.groupAlbumPhotoNotFound' => '图片不存在或已删除',
			'common.groupAlbumPhotoOpenExternal' => '应用内打开',
			'common.groupAlbumPhotoCoverUpdated' => '已设为相册封面',
			'common.groupAlbumPhotoCoverFailed' => '设置封面失败，请稍后重试',
			'common.groupAlbumPhotoNext' => '下一张',
			'common.groupAlbumPhotoResolution' => '分辨率',
			'common.groupAlbumPhotoUploader' => '上传者',
			'common.sectionDisplay' => '显示',
			'common.sectionTheme' => '主题',
			'common.selectLanguage' => '选择语言',
			'common.completionSuggestions' => '完善建议：',
			'common.sectionGeneral' => '通用',
			'common.sectionPrivacySecurity' => '隐私与安全',
			'common.sectionHelpAbout' => '帮助与关于',
			'common.msgOnlyVisibleToParties' => '消息仅收发双方可读',
			'common.msgNotEncrypted' => '消息未加密传输',
			'common.unreadCount' => ({required Object count}) => '${count} 条未读',
			'common.durationMinutes' => ({required Object count}) => '${count}分钟',
			'common.durationSeconds' => ({required Object count}) => '${count}秒',
			'common.rechargeAmountError' => '请输入0.01元到10000元之间的金额',
			'common.rechargeSuccess' => '充值成功',
			'common.rechargeConfirm' => '确认充值',
			'common.transactionHistory2' => '流水记录',
			'common.noTransactionHistory' => '暂无流水记录',
			'common.transactionTypeIncome' => '充值',
			'common.transactionTypeExpense' => '消费',
			'common.sectionLoginCredentials' => '登录凭证',
			'common.channelInvitations' => '频道邀请',
			'common.acceptInvitationFailed' => '接受邀请失败',
			'common.rejectInvitationFailed' => '拒绝邀请失败',
			'common.invitationAccepted' => '已接受邀请',
			'common.invitationRejected' => '已拒绝邀请',
			'common.invitationStatusPending' => '待处理',
			'common.invitationStatusAccepted' => '已接受',
			'common.invitationStatusRejected' => '已拒绝',
			'common.invitationStatusExpired' => '已过期',
			'common.invitationStatusCancelled' => '已取消',
			'common.invitationStatusUnknown' => '未知',
			'common.noReceivedInvitations' => '暂无收到的邀请',
			'common.noSentInvitations' => '暂无发出的邀请',
			'common.processingDots' => '处理中...',
			'common.purchaseFailed' => '购买失败，请稍后重试',
			'common.purchaseSuccess' => '购买成功',
			'common.insufficientBalanceTitle' => '余额不足',
			'common.insufficientBalanceContent' => ({required Object currency, required Object balance, required Object price}) => '当前余额 ${currency} ${balance}，需支付 ${currency} ${price}。请先充值后再购买。',
			'common.goRecharge' => '去充值',
			'common.noOrders' => '暂无订单',
			'common.orderDetailLoadFailed' => '订单详情加载失败',
			'common.orderNoLabel' => ({required Object no}) => '订单号: ${no}',
			'common.orderStatusCancelled' => '已取消',
			'common.orderStatusUnknown' => '未知',
			'common.fileOpenFailed' => '无法打开该文件',
			'common.e2eeLocalBackup' => '本地备份',
			'common.e2eeLocalBackupDesc' => '导出加密备份文件到本地或云端',
			'common.e2eeDeleteKey' => '删除密钥',
			'common.e2eeDeleteKeyDesc' => '删除本地存储的密钥（无法恢复）',
			'common.e2eeCurrentKeyInfo' => '当前密钥信息',
			'common.e2eeE2EEEnabled' => '端到端加密已启用',
			'common.e2eeNoKeyDetected' => '未检测到 E2EE 密钥',
			'common.e2eeNoKeyDesc' => '你需要先生成密钥对或从备份中恢复',
			'common.e2eeAboutTitle' => '关于端到端加密',
			'common.e2eeInfoPoint1' => '• 你的消息在发送前已加密，服务器无法查看内容',
			'common.e2eeInfoPoint2' => '• 更换设备或删除密钥后，旧消息可能无法解密',
			'common.e2eeInfoPoint3' => '• 请定期备份密钥以防数据丢失',
			'common.e2eeExportBackup' => '导出备份',
			'common.e2eeExportBackupDesc' => '生成加密备份文件',
			'common.e2eeImportBackup' => '导入备份',
			'common.e2eeImportBackupDesc' => '从备份文件恢复密钥',
			'common.e2eeGenerateKeyConfirm' => '确定要生成新的 E2EE 密钥对吗？',
			'common.e2eeWarnOldMessagesLost' => '• 旧消息将无法解密',
			'common.e2eeWarnNeedNewBackup' => '• 需要重新生成备份文件',
			'common.e2eeConfirmGenerate' => '确认生成',
			'common.aiPlaintextConfirmTitle' => '与 AI 助手的明文会话',
			'common.aiPlaintextConfirmBody' => '本会话消息和附件不是端到端加密，服务端可以看到内容。',
			'common.aiPlaintextConfirmNote' => '确认后本设备将记住本次确认；对方身份或密钥变更后会再次询问。',
			'common.aiPlaintextConfirmOk' => '已知晓，继续发送',
			'common.aiPlaintextConfirmCancel' => '取消',
			'common.e2eeDeleteKeyConfirm' => '确定要删除当前密钥吗？',
			'common.e2eeWarnCannotRestore' => '• 删除后无法恢复',
			'common.e2eeWarnAllMsgsLost' => '• 所有 E2EE 消息将无法解密',
			'common.e2eeConfirmDelete' => '确认删除',
			'common.e2eeKeyGeneratedSuccess' => '密钥生成成功',
			'common.e2eeDeviceIdInfo' => ({required Object id}) => '设备 ID: ${id}',
			'common.e2eeKeyIdInfo' => ({required Object id}) => '密钥 ID: ${id}',
			'common.e2eeCreatedAtInfo' => ({required Object time}) => '创建时间: ${time}',
			'common.e2eeImportantNote' => '重要提示',
			'common.e2eeWarnOldMayNotDecrypt' => '• 旧消息可能无法解密',
			'common.e2eeSuggestBackupNow' => '• 建议立即导出备份',
			'common.e2eeGoBackup' => '去备份',
			'common.e2eeKeyGenerateFailed' => '密钥生成失败，请重试',
			'common.e2eeKeyDeleted' => '密钥已删除',
			'common.e2eeDeleteFailed' => '删除失败，请重试',
			'common.webFeatureNotification' => '桌面通知',
			'common.webFeatureNotificationDesc' => '即使不在页面也能收到新消息提醒',
			'common.webQRConfirmOnPhone' => '请在手机上确认登录',
			'common.webQRLoginFailed' => '登录失败',
			'common.webQRLoginSuccess' => '登录成功',
			'common.webQRExpiresIn' => ({required Object seconds}) => '${seconds} 秒后过期',
			'common.webQRStatusFailed' => '登录失败，请重试',
			'common.webQRStatusSuccess' => '正在跳转...',
			'common.webLoginEmptyError' => '请输入账号和密码',
			'common.webQRGenerateFailed' => '生成二维码失败',
			'common.webQRTokenInvalid' => '登录令牌无效',
			'common.e2eeErrNoRecipientKey' => '无法获取对方设备密钥，消息未发送',
			'common.e2eeErrPeerNotOnboarded' => '对方还没有在任何设备上登录过，暂时无法加密发送；请等对方登录后再试',
			'common.e2eeDecryptFailed' => '消息无法解密',
			'common.e2eeDecryptFailedReasons' => '此消息无法解密，可能原因是：',
			'common.e2eeDecryptReasonOtherDevice' => '• 你在其他设备上登录',
			'common.e2eeDecryptReasonKeyExpired' => '• 设备密钥已过期',
			'common.e2eeDecryptReasonDataCorrupt' => '• 应用数据损坏',
			'common.e2eeDecryptChooseSolution' => '请选择解决方案：',
			'common.e2eeDecryptRecreateHint' => '提示：重建后，对方需重新获取你的新密钥；重建期间未送达的加密消息可能不会自动重发。历史消息不受影响。',
			'common.e2eePeerKeyChanged' => '对方的安全码已变更（可能因对方重装应用或更换设备）。若你重视安全，请通过其他渠道与对方核实身份。',
			'common.complianceKeyChangedTitle' => '合规审计密钥已变更',
			'common.complianceKeyChangedBody' => '服务端下发的合规审计公钥与本地固定值不一致。若这是管理员有意的密钥轮换，请点击"确认轮换"；否则请勿继续发送加密消息，并联系管理员核查。',
			'common.complianceKeyChangedActionConfirm' => '确认轮换',
			'common.complianceKeyChangedActionKeep' => '暂不确认',
			'common.e2eeDecryptActionRecreateKey' => '重新创建密钥（推荐）',
			'common.e2eeDecryptActionRelogin' => '重新登录',
			'common.e2eeDecryptActionRemindLater' => '稍后提醒我',
			'common.e2eeBackupExportTitle' => '导出 E2EE 备份',
			'common.e2eeBackupPwdCantRecover' => '• 备份密码无法找回，请务必牢记！',
			'common.e2eeBackupStoreMultipleNote' => '• 建议将备份文件存储到多个安全位置（邮件、云盘、U盘）',
			'common.e2eeUseRecoveryKey' => '生成恢复密钥（忘记口令的备用凭据）',
			'common.e2eeRecoveryKeyTitle' => '恢复密钥',
			'common.e2eeRecoveryKeySaveNote' => '请立即保存这串恢复密钥（截图或存入密码管理器）。忘记口令时，它是解密备份的唯一凭据；一旦丢失，备份将永久无法恢复。',
			'common.e2eeRecoveryKeyCopiedAutoClear' => ({required Object seconds}) => '恢复密钥已复制，${seconds} 秒后将自动清除剪贴板，请尽快保存',
			'common.e2eeErrAttachmentSeal' => '加密附件封装失败，文件未上传；请稍后重试',
			'common.e2eeErrForwardPlaintextTarget' => '目标会话不是端到端加密，无法转发加密附件',
			'common.e2eeErrForwardUndecryptable' => '原加密附件无法在本机解密，转发失败',
			'common.e2eeRetryFailedMessages' => '重试解密失败的消息',
			'common.e2eeRetryFailedDone' => ({required Object count}) => '已重试 ${count} 条解密失败的消息',
			'common.e2eeRetryFailedNone' => '没有需要重试的解密失败消息',
			'common.e2eeModeStandard' => '标准模式',
			'common.e2eeModeCompliance' => '合规加密',
			'common.e2eeModeStrict' => '端到端加密',
			'common.e2eeBackupPwdLabel' => '备份密码 *',
			'common.e2eeBackupPwdHint' => '至少 12 位，包含大小写字母、数字和特殊符号',
			'common.e2eeBackupConfirmPwdLabel' => '确认密码 *',
			'common.e2eeBackupConfirmPwdHint' => '再次输入密码',
			'common.e2eeBackupNoteLabel' => '备注（可选）',
			'common.e2eeBackupNoteHint' => '例如：主手机备份 - 2026年1月',
			'common.e2eeBackupPwdStrengthLabel' => '密码强度',
			'common.e2eeBackupPwdWeak' => '弱 - 建议增加复杂度',
			'common.e2eeBackupPwdMedium' => '中等 - 建议增加长度或复杂度',
			'common.e2eeBackupPwdStrong' => '强 - 可以使用',
			'common.e2eeBackupPwdVeryStrong' => '非常强 - 安全',
			'common.e2eeBackupGenerateBtn' => '生成备份文件',
			'common.e2eeBackupFileGenerated' => '备份文件已生成！',
			'common.e2eeBackupShareBtn' => '通过邮件/云盘分享',
			'common.e2eeBackupShareContent' => '这是我的 Imboy E2EE 密钥备份文件，请妥善保管，切勿泄露给他人。',
			'common.e2eeBackupErrPwdMismatch' => '两次输入的密码不一致',
			'common.e2eeBackupErrNoKeyData' => '无法获取密钥数据',
			'common.e2eeBackupErrExportFailed' => '导出失败，请重试',
			'common.e2eeBackupErrShareFailed' => '分享失败，请重试',
			'common.e2eeBackupExportSuccessTitle' => '备份导出成功',
			'common.e2eeBackupExportSuccessBody' => '你的 E2EE 密钥备份已成功生成。',
			'common.e2eeBackupImportantNoteColon' => '重要提示：',
			'common.e2eeBackupKeepSafe' => '• 请妥善保管备份文件和密码',
			'common.e2eeBackupStoreMultipleLoc' => '• 建议将文件存储到多个安全位置',
			'common.e2eeBackupPwdCantRecoverNote' => '• 密码无法找回，请务必牢记',
			'common.e2eeBackupImportTitle' => '导入 E2EE 备份',
			'common.e2eeBackupImportGuide' => '导入说明',
			'common.e2eeBackupImportReplaceKey' => '• 导入后，当前的 E2EE 密钥将被替换',
			'common.e2eeBackupImportTrustedSource' => '• 请确保备份文件来自可信任的来源',
			'common.e2eeBackupSelectFile' => '选择备份文件',
			'common.e2eeBackupSelectFileHint' => '点击选择备份文件 (.enc)',
			'common.e2eeBackupInfoTitle' => '备份信息',
			'common.e2eeBackupVersionLabel' => '版本号',
			'common.e2eeBackupAlgorithmLabel' => '算法',
			'common.e2eeBackupFileSizeLabel' => '文件大小',
			'common.e2eeBackupFileBytes' => ({required Object bytes}) => '${bytes} 字节',
			'common.e2eeBackupGeneratedFile' => ({required Object name}) => '文件：${name}',
			'common.e2eeBackupFileValid' => '✓ 文件格式有效',
			'common.e2eeBackupImportPwdHint' => '请输入备份时设置的密码',
			'common.e2eeBackupImportBtn' => '导入密钥',
			'common.e2eeBackupErrSelectFile' => '选择文件失败，请重试',
			'common.e2eeBackupErrValidateFailed' => '文件验证失败，请检查文件格式',
			'common.e2eeBackupErrImportFailed' => '导入失败，请检查密码是否正确',
			'common.e2eeBackupImportSuccessTitle' => '导入成功',
			'common.e2eeBackupImportSuccessBody' => 'E2EE 密钥已成功恢复！',
			'common.e2eeBackupImportSuccessNote' => '注意：仅备份中包含且成功写入的群聊会话可用于读取对应历史；单聊历史无法恢复，因为单聊密钥不跨设备备份',
			'common.e2eeBackupHistoryGrantTitle' => '恢复历史群密钥',
			'common.e2eeBackupHistoryGrantBody' => ({required Object count}) => '此操作将授权本设备恢复 ${count} 个群密钥，并仅按各自的入群世代和消息序号范围解密历史。身份密钥已单独恢复；取消不会恢复这些群密钥。',
			'common.e2eeBackupHistoryRestoreResult' => ({required Object restored, required Object omitted}) => '历史群密钥：已授权恢复 ${restored} 个，已省略 ${omitted} 个',
			'common.e2eeBackupDeviceKeySyncPending' => '提示：设备身份同步暂未完成，本设备可能暂时无法解密新消息；重新登录后将自动完成同步',
			'common.e2eeBackupErrAccountMismatch' => '备份属于其他账号，已拒绝恢复',
			'common.e2eeBackupErrStaleBackup' => '该备份早于本机最近一次成功恢复（疑似旧版本重放），已拒绝',
			'common.e2eeBackupRestorePartialTitle' => '部分完成',
			'common.e2eeBackupRestorePartialBody' => ({required Object written, required Object total}) => 'E2EE 密钥已恢复；群密钥写入中断（已写入 ${written}/${total} 条）。请重新导入同一备份以补完剩余部分（重复写入安全）',
			'common.e2eeBackupSafetyNumberChangedNote' => '本机身份密钥已更换，与联系人的安全码将发生变化，请重新核验',
			'common.e2eeBackupCreatedAtRow' => '创建时间',
			'common.e2eeBackupCloudUploadBtn' => '备份到云端',
			'common.e2eeBackupCloudUploadSuccess' => ({required Object version}) => '已备份到云端（版本 ${version}）',
			'common.e2eeBackupErrCloudUploadFailed' => '云端备份失败，请重试',
			'common.e2eeBackupSetupTitle' => '保护你的加密历史',
			'common.e2eeBackupSetupBody' => '设置恢复口令并上传云端备份后，换机或重装才能找回加密聊天历史；没有备份，历史消息在新设备上将无法解密。',
			'common.e2eeBackupSetupPwdHint' => '自选恢复口令，或点击下方生成随机恢复密钥',
			'common.e2eeBackupSetupWeakHint' => '口令偏短，建议 12 位以上，或点击下方「生成恢复密钥」改用随机密钥',
			'common.e2eeBackupSetupSubmit' => '完成并上传云端备份',
			'common.e2eeBackupSetupLater' => '稍后再说（下次启动仍会提醒）',
			'common.e2eeBackupSetupBlockedToast' => '请先完成密钥备份设置',
			'common.e2eeBackupSetupPostponedToast' => '已稍后，下次启动会再次提醒',
			'common.e2eeBackupSetupPwdTooShort' => '口令至少 8 位',
			'common.e2eeBackupSetupUploading' => '正在上传…',
			'common.e2eeBackupSetupBusyHint' => '正在本机加密并上传到云端，请稍候；网络不佳时可以点下方「稍后再说」先跳过',
			'common.e2eeBackupSetupTimeoutToast' => '上传超时，请检查网络后重试，或稍后再设置',
			'common.e2eeBackupSetupLaterConfirmTitle' => '暂不设置备份？',
			'common.e2eeBackupSetupLaterConfirmBody' => '暂不设置的话，换设备或重装后这些加密聊天记录将无法解密，也无法找回。下次启动仍会提醒你。',
			'common.e2eeBackupSetupLaterConfirmStay' => '继续设置',
			'common.e2eeBackupSetupLaterConfirmLeave' => '暂不设置',
			'common.e2eeBackupSetupSavedNote' => '恢复口令已存入本机安全存储；今后密钥变化时会自动用它重新上传备份，无需再次输入。',
			'common.e2eeBackupCloudRestoreTitle' => '从云端备份恢复',
			'common.e2eeBackupCloudRestoreHint' => ({required Object version}) => '检测到云端备份（版本 ${version}）',
			'common.e2eeBackupCloudRestoreBtn' => '从云端恢复',
			'common.e2eeBackupCloudRestoreConfirmNote' => '恢复后将覆盖本设备当前的 E2EE 密钥',
			'common.e2eeBackupCloudPwdHint' => '请输入备份口令',
			'common.e2eeBackupErrNoCloudBackup' => '云端暂无备份',
			'common.e2eeBackupErrCloudPwd' => '口令错误或备份损坏',
			'common.e2eeBackupErrCloudRestoreFailed' => '云端恢复失败，请重试',
			'common.e2eeBackupUrlImportTitle' => '或从链接导入',
			'common.e2eeBackupUrlImportHint' => '粘贴备份文件所在链接（仅支持 HTTPS），下载后自动校验',
			'common.e2eeBackupUrlFieldLabel' => '备份文件链接',
			'common.e2eeBackupUrlFieldHint' => 'https://...',
			'common.e2eeBackupUrlImportBtn' => '下载并校验',
			'common.e2eeBackupUrlDownloading' => '正在下载...',
			'common.e2eeBackupErrUrlInvalid' => '链接无效，仅支持 HTTPS',
			'common.e2eeBackupErrUrlDownload' => '下载失败，请检查链接与网络',
			'common.e2eeBackupErrUrlTimeout' => '下载超时，请重试',
			'common.e2eeBackupErrUrlTls' => '安全连接失败，无法验证服务器证书',
			'common.e2eeBackupErrUrlHttp' => '服务器返回错误',
			'common.e2eeBackupErrUrlEmpty' => '服务器返回的内容为空',
			'common.e2eeBackupErrUrlTooLarge' => '文件过大（超过 10MB 上限）',
			'common.passwordEncryptFailed' => '密码加密失败',
			'common.initConfigTimeout' => '配置获取超时：请检查网络连接或服务端状态',
			'common.initConfigNetworkError' => ({required Object code}) => '网络故障或服务故障 (HTTP ${code})',
			'common.initConfigProtocolError' => '服务故障协议有误',
			'common.initConfigFetchFailed' => '配置获取失败，请检查网络连接',
			'common.initConfigDecryptFailed' => '配置解密失败：应用与服务端安全密钥不一致，请更新应用版本或联系管理员',
			'common.saveFailedRetry' => '保存失败，请重试',
			'common.downloadFileNotFound' => '下载文件不存在，请重试',
			'common.downloadHashRetrying' => ({required Object retry, required Object max}) => '文件校验失败，正在重新下载 (${retry}/${max})',
			'common.downloadHashFailed' => '文件多次校验失败，请检查网络后重试',
			'common.buttonBackHome' => '返回首页',
			'common.featureNotEnabled' => '当前功能未启用',
			'common.featureDisabledName' => ({required Object name}) => '${name} 功能未启用，暂时无法访问',
			'common.imageLoadFailed' => '加载失败',
			'common.loadFailedWithError' => ({required Object error}) => '加载失败: ${error}',
			'common.webAudioNotSupported' => 'Web 平台暂不支持语音消息播放',
			'common.e2eeKeyRecreationFailed' => ({required Object error}) => '密钥创建失败: ${error}',
			'common.redPacket' => '红包',
			'common.transfer' => '转账',
			'common.withdraw' => '提现',
			'common.redPacketSend' => '发红包',
			'common.redPacketDetail' => '红包详情',
			'common.transferSend' => '发起转账',
			'common.greetingDefault' => '恭喜发财，大吉大利',
			'common.redPacketView' => '查看红包',
			'common.redPacketBrand' => 'IMBoy 红包',
			'common.redPacketDialogTitle' => '送你一个红包',
			'common.redPacketDialogSubtitle' => '大吉大利，恭喜发财',
			'common.transferAmountYuan' => ({required Object amount}) => '转账金额：${amount} 元',
			'common.insufficientBalance' => '余额不足',
			'common.withdrawSuccess' => '提现成功',
			'common.withdrawConfirm' => '确认提现',
			'common.withdrawFeeNotice' => '手续费与到账时间以实际结算为准',
			'common.withdrawAmountError' => '请输入不低于0.01元的金额',
			'common.withdrawAccountEmpty' => '请输入提现账号',
			'common.withdrawMethod' => '提现方式',
			'common.withdrawAmountLabel' => '提现金额',
			'common.withdrawAlipay' => '支付宝',
			'common.withdrawWechat' => '微信',
			'common.withdrawAccountHintAlipay' => '提现账号（邮箱或手机号）',
			'common.withdrawAccountHintWechat' => '提现账号（微信号）',
			'common.withdrawAlipayFormatError' => '请输入正确的支付宝邮箱或手机号',
			'common.withdrawWechatFormatError' => '请输入正确的微信号（6-20位，字母开头）',
			'common.withdrawConfirmAmount' => ({required Object amount}) => '提现金额：￥${amount}',
			'common.withdrawConfirmMethod' => ({required Object method}) => '提现方式：${method}',
			'common.withdrawConfirmAccount' => ({required Object account}) => '提现账号：${account}',
			'common.noHistory' => '暂无历史记录',
			'common.enterAmount' => '请输入金额',
			'common.transferDefaultRemark' => '转账给好友',
			'common.transferMinAmountError' => '转账最低金额为 0.01 元',
			'common.redPacketCurrentLucky' => '当前为：拼手气红包',
			_ => null,
		} ?? switch (path) {
			'common.redPacketCurrentNormal' => '当前为：普通红包',
			'common.redPacketSwitchToNormal' => '改为普通红包',
			'common.redPacketSwitchToLucky' => '改为拼手气红包',
			'common.redPacketCount' => '红包个数',
			'common.redPacketCountUnit' => '个',
			'common.redPacketCountEmpty' => '请输入红包个数',
			'common.redPacketCountMin' => '红包个数需大于等于 1',
			'common.redPacketTotalAmount' => '总金额',
			'common.redPacketSingleAmount' => '单个金额',
			'common.redPacketGreetingLabel' => '留言 / 祝福语',
			'common.redPacketStuffLucky' => '塞钱发红包',
			'common.redPacketStuffNormal' => '放入钱包发送',
			'common.amountMustPositive' => '金额必须大于 0',
			'common.walletBalanceLabel' => ({required Object balance}) => '钱包余额 ￥${balance}',
			'common.transferAmountLabel' => '转账金额',
			'common.transferRemarkLabel' => '转账备注',
			'common.transferConfirm' => '确认转账',
			'common.transferReceiving' => '正在收款...',
			'common.transferAccepted' => '已收取',
			'common.transferRefunded' => '已退回',
			'common.transferPending' => '等待对方确认',
			'common.transferTapToReceive' => '点击收款',
			'common.redPacketReceiverLabel' => ({required Object uid}) => '用户：${uid}',
			'common.redPacketNotFound' => '红包不存在或已被删除',
			'common.redPacketFetchFailed' => '获取红包详情失败',
			'common.redPacketFetchError' => '获取红包详情异常',
			'common.redPacketAmountTooSmall' => '总金额至少为份数 × 0.01 元',
			'common.purchaseConfirming' => '支付确认中，请稍后查看订单状态',
			'common.payReceiveSuccess' => '收款成功！',
			'common.timeNowShort' => 'now',
			'common.timeDaysShort' => ({required Object count}) => '${count}d',
			'common.timeHoursShort' => ({required Object count}) => '${count}h',
			'common.timeMinutesShort' => ({required Object count}) => '${count}m',
			'common.showPassword' => '显示密码',
			'common.hidePassword' => '隐藏密码',
			'common.turnOnFlashlight' => '打开闪光灯',
			'common.turnOffFlashlight' => '关闭闪光灯',
			'common.pauseScan' => '暂停扫描',
			'common.resumeScan' => '继续扫描',
			'common.enterFullscreen' => '进入全屏',
			'common.exitFullscreen' => '退出全屏',
			'common.me' => '我',
			'common.justNow' => '刚刚',
			'common.minutesAgo' => '分钟前',
			'common.hoursAgo' => '小时前',
			'common.collapse' => '收起',
			'common.expandFull' => '展开',
			'common.fontSizeOptionSmall' => '小',
			'common.fontSizeOptionNormal' => '标准',
			'common.fontSizeOptionMedium' => '中',
			'common.fontSizeOptionLarge' => '大',
			'common.fontSizeOptionExtraLarge' => '特大',
			'common.fontSizeOptionHuge' => '超大',
			'common.developer' => '开发者',
			'common.searchFailedRetry' => '搜索失败，请重试',
			'common.searchDisabledTitle' => '消息搜索未启用',
			'common.searchDisabledByEncryption' => '端到端加密已开启，服务器无法读取消息内容，因此不提供全文搜索',
			'common.collectedVideoFormatIncorrectCannotFindVideoUri' => '视频格式暂不支持，无法找到对应视频',
			'common.retry' => '重试',
			'common.retrying' => '重试中…',
			'complaint.complaint' => '投诉',
			'complaint.e2eeConsentTitle' => '提交加密消息证据',
			'complaint.e2eeConsentBody' => '该消息为端到端加密消息，服务器无法查看其内容。提交内容摘录会将你选择的消息明文随工单披露给审核员用于核实举报。是否同意提交？',
			'complaint.e2eeConsentSubmit' => '同意并提交证据',
			'complaint.e2eeConsentDecline' => '仅举报（不提交内容）',
			'complaintReason.spam' => '垃圾信息',
			'complaintReason.harassment' => '骚扰',
			'complaintReason.inappropriate' => '不当内容',
			'complaintReason.other' => '其他',
			'contact.blocked' => '已拉黑',
			'contact.applyChanges' => '请重启应用以应用更改',
			'contact.inputNewTag' => '输入新标签...',
			'contact.denylist' => '黑名单',
			'contact.denylistEmpty' => '黑名单为空',
			'contact.favoriteGroupTagsEtc' => '收藏、人名、群名、标签等',
			'contact.newFriend' => '新的朋友',
			'contact.recommendToFriend' => '把他推荐给朋友',
			'contact.remark' => '备注',
			'contact.remarksTags' => '备注和标签',
			'contact.selectAGroup' => '选择一个群',
			'contact.selectFriends' => '选择朋友',
			'contact.tags' => '标签',
			'contact.suggestedTags' => '建议标签',
			'contact.pleaseEnterRemark' => '请输入备注名',
			'contact.enterRemark' => '请输入备注名',
			'contact.pleaseEnterTags' => '请输入标签',
			'contact.momentsVisibilityFriends' => '仅好友',
			'contact.tagLengthExceeded' => ({required Object param}) => '标签长度不能超过 ${param} 个字符',
			'contact.maxTagsExceeded' => ({required Object param}) => '最多只能添加 ${param} 个标签',
			'contact.selectedTags' => ({required Object param, required Object max}) => '已选标签 (${param}/${max})',
			'contact.friendRequestSent' => '已发送',
			'contact.channelMaxTagsCount' => '最多可添加 8 个标签',
			'contact.tagInputHint' => '输入标签...',
			'customerService.entryTitle' => '客服工作台',
			'customerService.entrySubtitle' => '接单并处理排队中的客户会话',
			'customerService.title' => '客服工作台',
			'customerService.tabQueued' => '待接',
			'customerService.tabActive' => '处理中',
			'customerService.tabClosed' => '已关闭',
			'customerService.countUnavailable' => '--',
			'customerService.orgSelectorLabel' => '企业',
			'customerService.noSeatTitle' => '暂无可用坐席席位',
			'customerService.noSeatHint' => '你还没有启用中的客服坐席席位，请联系企业管理员开通',
			'customerService.waitingJustNow' => '刚刚',
			'customerService.waitingMinutes' => ({required Object n}) => '${n} 分钟',
			'customerService.waitingHoursMinutes' => ({required Object h, required Object m}) => '${h} 小时 ${m} 分',
			'customerService.waitingDaysHours' => ({required Object d, required Object h}) => '${d} 天 ${h} 小时',
			'customerService.sourceWidget' => '网页',
			'customerService.sourceLabel' => '来源',
			'customerService.queuedEmptyTitle' => '暂无待接会话',
			'customerService.queuedEmptyHint' => '下拉刷新，新会话会出现在这里',
			'customerService.loadingMore' => '正在加载更多…',
			'customerService.loadMoreFailed' => '加载更多失败，上滑重试',
			'customerService.noMore' => '没有更多了',
			'customerService.claimAction' => '接单',
			'customerService.claimSuccess' => '接单成功',
			'customerService.claimConflict' => '该会话已被其他坐席接单或状态已变化，已为你刷新最新队列',
			'customerService.claimOffboardingRequired' => '当前处于离职交接，暂时不能接单',
			'customerService.claimForbidden' => '坐席已被暂停，暂不能接单',
			'customerService.claimFailed' => '接单失败，请稍后重试',
			'customerService.seatAtCapacity' => '席位并发已满（处理中会话达上限），请先关闭处理中的会话或联系管理员调整容量',
			'customerService.activeEmptyTitle' => '暂无处理中会话',
			'customerService.activeEmptyHint' => '从待接列表接单后，会话会显示在这里',
			'customerService.closedEmptyTitle' => '暂无已关闭会话',
			'customerService.closedEmptyHint' => '已关闭的会话会归档显示在这里',
			'customerService.loadFailedTitle' => '加载失败',
			'customerService.offlineHint' => '网络不可用，请检查网络后重试',
			'customerService.seatSuspendedNotice' => '坐席已被暂停，队列仅可查看',
			'customerService.sessionTitle' => '客服会话',
			'customerService.channelUnavailable' => '消息通道暂不可用，等待服务端补齐会话绑定',
			'customerService.visitorLabel' => '客户',
			'customerService.seatLabel' => '坐席',
			'customerService.inputHint' => '输入回复内容…',
			'customerService.attachAction' => '附件',
			'customerService.attachUploaded' => '附件已上传',
			'customerService.attachPreviewTitle' => '附件预览（企业安全通道）',
			'customerService.attachUnnamedFile' => '附件',
			'customerService.attachStatusUnavailable' => ({required Object size}) => '暂不可用 · ${size}',
			'customerService.attachUnsupportedType' => '暂不支持该文件类型，请更换文件',
			'customerService.attachBinaryNoPreview' => '二进制内容，暂不支持预览',
			'customerService.transferAction' => '转接',
			'customerService.transferTitle' => '转接给同企业坐席',
			'customerService.transferEmpty' => '暂无可转接的同企业客服坐席',
			'customerService.targetAvailable' => '可转接',
			'customerService.targetBusy' => '繁忙',
			'customerService.transferConfirmTitle' => '确认转接',
			'customerService.transferConfirmBody' => ({required Object name}) => '将当前会话转交给 ${name}？转接后你将不再经办此会话。',
			'customerService.transferSuccess' => '转接成功',
			'customerService.transferConflict' => '会话状态已变化，请刷新并核对后重新确认。',
			'customerService.transferFailed' => '转接失败，请稍后重试',
			'customerService.closeAction' => '关闭会话',
			'customerService.closeTitle' => '确认关闭会话',
			'customerService.closeBody' => '关闭后客户将进入评分环节，会话进入只读。',
			'customerService.closeReasonLabel' => '关闭原因（可选）',
			'customerService.closeReasonTooLong' => ({required Object max}) => '关闭原因不能超过 ${max} 字',
			'customerService.closeSuccess' => '会话已关闭',
			'customerService.closeConflict' => '会话状态已变化，请刷新并核对后重新确认。',
			'customerService.closeFailed' => '关闭失败，请稍后重试',
			'customerService.waitingRatingTitle' => '会话已关闭，等待客户评分',
			'customerService.ratedTitle' => '客户已完成评分',
			'customerService.ratingScoreLabel' => ({required Object score}) => '客户评分：${score} 星',
			'customerService.readOnlySuspended' => '坐席已被暂停（suspend），消息通道已切换为只读，后台收发已停止',
			'customerService.offboardingRequired' => '当前处于离职交接，会话经办权已移交，此会话已只读',
			'customerService.closedReadonly' => '会话已关闭，内容仅供查看',
			'customerService.ratedReadonly' => '会话已评分结束，内容仅供查看',
			'customerService.sendFailed' => '发送失败，请稍后重试',
			'customerService.sendConflict' => '会话状态已变化，已为你刷新最新状态',
			'customerService.attachUploadFailed' => '附件上传失败，请重试',
			'customerService.transferredAway' => '会话已转交给其他坐席，此会话对你只读',
			'customerService.presenceMenuLabel' => '坐席状态',
			'customerService.presenceUnavailable' => '状态不可用',
			'customerService.seatDisabledNotice' => '席位已停用',
			'customerService.presenceStatusOnline' => '在线',
			'customerService.presenceStatusAway' => '离开',
			'customerService.presenceStatusBusy' => '繁忙',
			'customerService.presenceStatusOffline' => '离线',
			'customerService.presenceAwayAction' => '设为离开',
			'customerService.presenceResumeAction' => '恢复自动',
			'customerService.presenceCapacityLabel' => ({required Object active, required Object max}) => '${active}/${max} 会话',
			'customerService.unreadBadgeLabel' => ({required Object n}) => '未读 ${n} 条',
			'customerService.governance.title' => '客服治理',
			'customerService.governance.scopeNote' => '本页为企业治理面（owner/admin）；服务端 403 是最终权限裁决。',
			'customerService.governance.limitCardTitle' => '席位额度',
			'customerService.governance.limitUnlimited' => '不限',
			'customerService.governance.limitValueLabel' => ({required Object used, required Object limit}) => '${used}/${limit} 席位',
			'customerService.governance.limitAtCapacity' => '已达上限',
			'customerService.governance.limitAdjustAction' => '调整额度',
			'customerService.governance.limitAdjustTitle' => '调整席位额度',
			'customerService.governance.limitInputLabel' => '席位上限（正整数，留空 = 不限）',
			'customerService.governance.limitClearAction' => '清除限制（不限）',
			'customerService.governance.limitInvalidInput' => '请输入正整数',
			'customerService.governance.limitSaved' => '额度已更新',
			'customerService.governance.seatsSectionTitle' => '坐席席位',
			'customerService.governance.seatsEmpty' => '暂无坐席席位',
			'customerService.governance.seatEnabledBadge' => '启用',
			'customerService.governance.seatSuspendedBadge' => '已停用',
			'customerService.governance.seatIdentityLabel' => ({required Object identity}) => '坐席 ${identity}',
			'customerService.governance.seatCapacityLabel' => ({required Object active, required Object max}) => '${active}/${max} 会话',
			'customerService.governance.seatLoadMore' => '加载更多',
			'customerService.governance.suspendAction' => '停用坐席',
			'customerService.governance.resumeAction' => '启用坐席',
			'customerService.governance.suspendConfirmTitle' => '停用该坐席？',
			'customerService.governance.suspendConfirmBody' => '停用后不能再接新会话；进行中的会话不受影响，可随时再启用。',
			'customerService.governance.actionDone' => '操作已生效',
			'customerService.governance.actionFailed' => '操作失败，请稍后重试',
			'customerService.governance.errorForbidden' => '无治理权限：客服治理仅对企业 owner/admin 开放',
			'customerService.governance.errorNoDefaultWorkspace' => '企业未设置默认工作区，无法确定客服治理作用域',
			'customerService.governance.errorLoadFailed' => '加载失败',
			'customerService.governance.errorWithCode' => ({required Object msg, required Object code}) => '${msg}（${code}）',
			'customerService.governance.seatLimitExceededHint' => ({required Object used, required Object limit}) => '席位额度已满：已用 ${used}/${limit}，无法新增坐席（seat_limit_exceeded）',
			'customerService.governance.retry' => '重试',
			'customerService.actionDraftWarning' => '当前有未发送草稿；确认此操作不会发送草稿。',
			'customerService.actionSendingWarning' => '消息正在发送；请等待终态并核对后确认。',
			'customerService.actionUploadingWarning' => '附件正在上传；请等待终态并核对后确认。',
			'customerService.actionUnconfirmedWarning' => '仍有消息尚未确认；请先核对结果，当前不能提交会话操作。',
			'customerService.ratingUnknownTitle' => '评价状态未知',
			'customerService.ratingTimeLabel' => ({required Object time}) => '评分时间：${time}',
			'customerService.attachSave' => '保存文件',
			'customerService.attachSaved' => '文件已保存',
			'customerService.attachSaveFailed' => '保存失败，可以重试。',
			'customerService.attachPreparing' => '正在准备附件',
			'customerService.attachPresigning' => '正在申请上传权限',
			'customerService.attachUploading' => ({required Object sent, required Object total}) => '正在上传字节：${sent} / ${total}',
			'customerService.attachConfirming' => '正在确认已上传文件',
			'customerService.attachCancelled' => '附件在上传开始前已取消',
			'customerService.attachUnknown' => '上传结果尚未完整确认，未自动重试或发送消息。',
			'customerService.attachRetry' => '重试附件上传',
			'customerService.attachCancel' => '停止后续上传步骤',
			'customerService.attachTooLarge' => '附件须非空且不超过 25 MiB。',
			'customerService.attachPreviewTruncated' => '只显示部分文本；保存文件仍包含完整内容。',
			'customerService.attachUploadedNotSent' => '附件已上传，但消息发送结果尚未确认。请核对发送结果，不要重新上传。',
			'customerService.attachUploadStopped' => '附件上传未完成，已停止后续操作。请核对权限和会话状态后重新选择文件。',
			'customerService.newMessagesJump' => '有新消息 · 查看最新',
			'discovery.findNearbyPeople' => '找附近的人',
			'discovery.moment' => '朋友圈',
			'discovery.nearbyPeopleExplain' => '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。\n你的电话号码将会被隐藏。',
			'discovery.peopleNearby' => '附近的人',
			'discovery.scanResult' => '扫描结果',
			'discovery.myChannels' => '我的频道',
			'discovery.otherUsersCanFindMe' => '其他用户可以通过搜索找到我',
			'discovery.momentsDenyUidsLabel' => '不给谁看 UID 列表（逗号分隔）',
			'discovery.moments' => '朋友圈',
			'discovery.momentsWriteComment' => '写评论...',
			'discovery.momentsVisibility' => '可见性',
			'discovery.momentsVisibilityPublic' => '公开',
			'discovery.momentsVisibilityPartial' => '部分可见',
			'discovery.momentsVisibilityExclude' => '不给谁看',
			'discovery.momentsDraftRestored' => '已恢复上次未发送的草稿',
			'discovery.momentsFeedStale' => '网络异常，显示的是缓存内容',
			'discovery.momentActionLike' => '赞',
			'discovery.momentActionCancelLike' => '取消点赞',
			'discovery.momentActionComment' => '评论',
			'discovery.momentActionMore' => '更多操作',
			'discovery.momentActionDelete' => '删除',
			'discovery.momentActionReport' => '举报',
			'discovery.momentActionCancel' => '取消',
			'discovery.momentLikedBy' => ({required Object names}) => '${names} 赞了',
			'discovery.momentAndOthersLiked' => ({required Object names, required Object count}) => '${names} 等${count}人赞了',
			'discovery.momentContentPlaceholder' => '这一刻的想法...',
			'discovery.momentShowFull' => '全文',
			'discovery.momentCollapse' => '收起',
			'discovery.momentsDraftKeepTitle' => '保留草稿？',
			'discovery.momentsDraftKeepMessage' => '保留后下次进入可继续编辑',
			'discovery.momentsDraftDiscard' => '不保留',
			'discovery.momentsDraftKeep' => '保留',
			'discovery.openChannel' => '打开频道',
			'discovery.paidChannelLocked' => '付费频道内容已锁定',
			'discovery.webQRScanned' => '已扫描',
			'discovery.momentLikesCountOnly' => ({required Object count}) => '${count}人赞了',
			'discovery.momentLocation' => '所在位置',
			'discovery.momentLocationNone' => '不显示位置',
			'discovery.momentAtWho' => '提醒谁看',
			'discovery.momentAtReminded' => ({required Object name}) => '提醒了 ${name}',
			'discovery.momentAtRemindedMore' => ({required Object name, required Object count}) => '提醒了 ${name} 等${count}人',
			'discovery.momentAtCount' => ({required Object count}) => '${count}人',
			'enterpriseApp.title' => '企业应用',
			'enterpriseApp.badgeAppDelegated' => '应用代发',
			'enterpriseApp.badgeHumanDelegated' => '人工经应用',
			'enterpriseApp.originTitle' => '消息来源',
			'enterpriseApp.originSenderApplication' => '应用代发（Application）',
			'enterpriseApp.originSenderHuman' => '人工代发（Human sender）',
			'enterpriseApp.originApplicationId' => ({required Object id}) => '来源应用 ${id}',
			'enterpriseApp.originHosted' => '企业托管（非个人会话）',
			'enterpriseApp.originLabelSender' => '发送来源',
			'enterpriseApp.originLabelEncryption' => '加密状态',
			'enterpriseApp.originNonE2ee' => '非端到端加密',
			'enterpriseApp.originE2ee' => '端到端加密（Human 直发）',
			'enterpriseApp.originMismatchTitle' => '来源信息不一致',
			'enterpriseApp.originMismatchHint' => '消息同时带有企业应用来源与端到端加密载荷；已按非加密的企业来源展示，不视为 Human 直发的加密消息。',
			'enterpriseApp.originUnrecognized' => '来源标记无法识别，已按非加密展示',
			'enterpriseApp.actionDetails' => '详情',
			'enterpriseApp.groupTitle' => '企业群',
			'enterpriseApp.groupArchivedBadge' => '已归档',
			'enterpriseApp.groupActionArchive' => '归档',
			'enterpriseApp.groupArchiveTitle' => '归档企业群',
			'enterpriseApp.groupArchiveHint' => '归档是单向操作：归档后该群对全部企业接口不可见，且不可恢复。',
			'enterpriseApp.groupActionRename' => '修改群名',
			'enterpriseApp.groupRenameHint' => '新群名',
			'enterpriseApp.groupMembersTitle' => '成员与角色',
			'enterpriseApp.groupRoleMember' => '成员',
			'enterpriseApp.groupRoleGuest' => '嘉宾',
			'enterpriseApp.groupRoleAdmin' => '管理员',
			'enterpriseApp.groupRoleOwner' => '群主',
			'enterpriseApp.groupRoleViceOwner' => '副群主',
			'enterpriseApp.groupRoleOwnerLocked' => '群主角色不可变更，也不可经应用分配',
			'enterpriseApp.groupOverLimit' => '成员数超过单页上限，已停止加载',
			'enterpriseApp.groupEmpty' => '暂无企业群',
			'enterpriseApp.directoryTitle' => '成员检索',
			'enterpriseApp.directoryHint' => '按姓名或工号检索',
			'enterpriseApp.directoryEmpty' => '无匹配成员',
			'enterpriseApp.directoryBounded' => '受限目录：按页返回，不提供全量导出',
			'enterpriseApp.directoryLoadMore' => '加载更多',
			'enterpriseApp.directoryEnd' => '已到末页',
			'enterpriseApp.retentionTitle' => '附件留存治理',
			'enterpriseApp.retentionUntil' => ({required Object time}) => '留存至 ${time}',
			'enterpriseApp.holdNone' => '未冻结',
			'enterpriseApp.holdHeld' => '已冻结',
			'enterpriseApp.holdReason' => ({required Object reason}) => '冻结原因：${reason}',
			'enterpriseApp.purgeLive' => '未清除',
			'enterpriseApp.purgePurged' => '已清除',
			'enterpriseApp.retentionNoDelete' => '治理记录不可删除',
			'enterpriseApp.retentionExtendOnly' => '留存期只可延长，不可缩短',
			'enterpriseApp.purgeBlockedHold' => '冻结生效中，不可清除',
			'enterpriseApp.purgeBlockedRetention' => '留存未到期，不可清除',
			'enterpriseApp.purgeBlockedPurged' => '已清除，不可回退',
			'enterpriseApp.actionRetry' => '重试',
			'enterpriseApp.actionSignIn' => '重新登录',
			'enterpriseApp.error400Title' => '请求不被接受',
			'enterpriseApp.error400Hint' => '提交的内容不符合要求，请检查后重试。',
			'enterpriseApp.error401Title' => '登录状态已失效',
			'enterpriseApp.error401Hint' => '请重新登录后再试。',
			'enterpriseApp.error403Title' => '企业应用已停用',
			'enterpriseApp.error403Hint' => '该应用或所属企业已停用，请联系企业管理员。',
			'enterpriseApp.error403ScopeTitle' => '权限范围不足',
			'enterpriseApp.error403ScopeHint' => '当前凭据未被授予该操作所需的权限范围。',
			'enterpriseApp.error403BoundaryTitle' => '超出企业边界',
			'enterpriseApp.error403BoundaryHint' => '该资源不属于当前应用所在的企业或工作区。',
			'enterpriseApp.error404Title' => '资源不存在',
			'enterpriseApp.error404Hint' => '资源不存在，或不在可访问的企业范围内。',
			'enterpriseApp.error409Title' => '操作冲突',
			'enterpriseApp.error409Hint' => '重复提交或状态已变化，请刷新后重试。',
			'enterpriseApp.error422IdentityTitle' => '身份未映射',
			'enterpriseApp.error422IdentityHint' => '该成员尚未绑定企业外部身份，请先完成绑定。',
			'enterpriseApp.error429Title' => '请求过于频繁',
			'enterpriseApp.error429Hint' => '已触发企业接口限流，请稍后再试。',
			'enterpriseApp.error500Title' => '服务内部错误',
			'enterpriseApp.error500Hint' => '服务暂时异常，请稍后重试。',
			'enterpriseApp.error503Title' => '服务暂不可用',
			'enterpriseApp.error503Hint' => '企业服务安全门已关闭，请稍后再试。',
			'enterpriseApp.errorUnboundTitle' => '当前构建未绑定企业通道',
			'enterpriseApp.errorUnboundHint' => '企业治理接口需要应用凭据，客户端不内置该凭据；请由部署方绑定通道后再使用。',
			'enterpriseApp.errorNetworkTitle' => '网络不可用',
			'enterpriseApp.errorNetworkHint' => '请检查网络连接后重试。',
			'enterpriseApp.errorUnknownTitle' => '未知结果',
			'enterpriseApp.errorUnknownHint' => '服务返回了未识别的结果，请稍后重试。',
			'enterpriseOa.title' => 'OA',
			'enterpriseOa.statusLoading' => '正在连接企业办公…',
			'enterpriseOa.statusErrorTitle' => '无法加载 OA',
			'enterpriseOa.statusErrorHint' => '网络异常或服务暂不可用，请稍后重试',
			'enterpriseOa.statusExpiredTitle' => '登录已过期',
			'enterpriseOa.statusExpiredHint' => 'OA 单点登录凭证已过期或已被使用，请重新登录',
			'enterpriseOa.statusLoggedOutTitle' => '已退出 OA',
			'enterpriseOa.statusLoggedOutHint' => 'OA 会话已退出，需要重新单点登录',
			'enterpriseOa.statusMismatchTitle' => '已阻止离开企业 OA',
			'enterpriseOa.statusMismatchHint' => '检测到跳转到未授权地址，已停止加载以保护你的账号',
			'enterpriseOa.statusMismatchBlockedHost' => ({required Object host}) => '已拦截：${host}',
			'enterpriseOa.statusOa401Title' => 'OA 登录态失效',
			'enterpriseOa.statusOa401Hint' => 'OA 服务返回未授权，请重新单点登录',
			'enterpriseOa.actionRetry' => '重试',
			'enterpriseOa.actionRestartSso' => '重新单点登录',
			'enterpriseOa.webviewSlotHint' => 'OA 页面容器（集成于 W3 波次）',
			'enterpriseOa.badgeDelegated' => 'OA 代发',
			'enterpriseOa.markerNoE2ee' => '企业托管 · 未端到端加密',
			'enterpriseOa.senderVia' => ({required Object origin}) => '经 ${origin} 代发',
			'enterpriseOa.ssoIssuing' => '正在获取单点登录凭证…',
			'enterpriseOa.ssoCountdown' => ({required Object seconds}) => '凭证 ${seconds} 秒内有效，请尽快完成登录',
			'enterpriseOa.workbenchTitle' => '工作台',
			'enterpriseOa.apps' => '应用',
			'enterpriseOa.inboundTitle' => 'OA 身份登录',
			'enterpriseOa.startInbound' => '通过 OA 验证身份',
			'enterpriseOa.accountChoice' => '请选择关联已有 IMBoy 账号，或明确创建新账号。',
			'enterpriseOa.confirmLink' => '确认关联当前账号',
			'enterpriseOa.useExistingAccount' => '登录已有 IMBoy 账号',
			'enterpriseOa.confirmCreate' => '确认创建新的 IMBoy 账号',
			'error.restartRequired' => '需要重启应用',
			'error.pleaseCheckNetwork' => '请检查你的网络设置。',
			'error.networkTroubleshootingStep1' => '1.打开手机设置并把Wi-Fi开关保持开启状态。',
			'error.networkTroubleshootingStep2' => '2.打开手机设置-通用-蜂窝移动网络，并把蜂窝移动数据开关保持开启状态。',
			'error.networkTroubleshootingStep3' => '3.如果仍无法连接网络，请检查手机接入的Wi-Fi是否已接入互联网或者咨询网络运营商。',
			'error.suggestCheckNetwork' => '建议检查网络设置。',
			'error.e2eeErrTimeout' => '加密超时，请检查网络连接后重试',
			'error.e2eeErrNetwork' => '网络错误，加密失败，消息未发送',
			'error.e2eeErrPolicyNotReady' => '端到端加密策略尚未就绪，请稍后重试',
			'error.liveRoomTitleRequired' => '标题不能为空',
			'group.enterSameGroup' => '与身边的朋友进入同一个群聊',
			'group.enterTheGroup' => '进入该群',
			'group.groupAlias' => '我在本群的昵称',
			'group.groupAlbum' => '群相册',
			'group.groupDissolve' => '解散群聊',
			'group.groupLeave' => '退出群聊',
			'group.groupMembers' => '群成员',
			'group.groupName' => '群聊名称',
			'group.mutualGroupsWithHer' => '我和他的共同群聊',
			'group.groupOwner' => '群主',
			'group.groupAdmin' => '管理员',
			'group.groupGuest' => '嘉宾',
			'group.groupInfo' => '群聊信息',
			'group.groupMemberRoleLabel' => '成员',
			'group.noMemberWithRole' => ({required Object roleName}) => '暂无${roleName}',
			'group.moreActions' => '更多操作',
			'group.touchContactAddMember' => '点击联系人添加为群成员',
			'group.groupCreated' => '群聊已创建',
			'group.groupCreatedSuccess' => '群聊创建成功，邀请你完善群信息或直接进入群聊',
			'group.enterGroupChat' => '进入群聊',
			'group.perfectionGroupInfo' => '完善群信息',
			'group.setAdmin' => '设为管理员',
			'group.selectGroup' => '选择群聊',
			'group.sureToDissolveGroup' => '确定要解散本群吗？',
			'group.sureToLeaveGroup' => '确定要退出本群吗？',
			'group.groupAlbumNameHint' => '请输入相册名称',
			'group.groupAlbumRenameTitle' => '重命名相册',
			'group.groupAlbumRenamed' => '相册名称已更新',
			'group.groupAlbumUnnamed' => '未命名相册',
			'group.groupAlbumPhotoCount' => ({required Object count}) => '${count} 张图片',
			'group.groupAlbumPhotoIdMissing' => '图片ID缺失，无法查看详情',
			'group.groupAlbumPhotoListTitle' => '相册图片',
			'group.groupAlbumPhotoSelectedCount' => ({required Object count}) => '已选择 ${count} 项',
			'group.groupAlbumPhotoEmpty' => '暂无图片',
			'group.groupAlbumPhotoUrlMissing' => '图片地址缺失，无法打开',
			'group.groupAlbumPhotoUrlInvalid' => '图片地址无效',
			'group.groupAlbumPhotoDetailTitle' => '图片详情',
			'group.groupAlbumPhotoSetCover' => '设为封面',
			'group.groupAlbumPhotoPrev' => '上一张',
			'group.groupAlbumPhotoLikeCount' => '点赞数',
			'group.groupAlbumPhotoCommentCount' => '评论数',
			'group.groupAlbumPhotoMyLike' => '我的点赞',
			'group.groupAlbumPhotoIdLabel' => '图片ID',
			'group.e2eeKeyManagement' => 'E2EE 密钥管理',
			'group.e2eeKeyManagementSubtitle' => '备份、恢复和管理端到端加密密钥',
			'group.e2eeTitle' => '端到端加密',
			'group.e2eeEnableConfirm' => '开启后，本群消息将端到端加密，仅群成员设备可解密。此操作不可撤销，确定开启？',
			'group.transferAndLeave' => '转让后退出',
			'group.sureToTransferAndLeave' => '转让后你将退出本群并失去群主权限，确定继续吗？',
			'group.transferredButLeaveFailed' => '已转让群主，但退出失败，请重试退出',
			'group.noEligibleSuccessor' => '暂无可转让的成员',
			'groupCategory.title' => '群分组',
			'groupCategory.createCategory' => '创建分组',
			'groupCategory.categoryName' => '分组名称',
			'groupCategory.noCategory' => '暂无分组',
			'groupCategory.deleteCategory' => '删除分组',
			'groupCategory.deleteCategoryConfirm' => '确定要删除该分组吗？群聊不会被删除。',
			'groupCategory.categoryDeleted' => '分组已删除',
			'groupCategory.renameCategory' => '重命名分组',
			'groupCategory.categoryRenamed' => '分组重命名成功',
			'groupCategory.renameFailed' => '重命名失败，请重试',
			'groupCategory.deleteFailed' => '删除失败，请重试',
			'groupCategory.categoryDetailTip' => '该分组下的群聊可以在群组列表中通过「移入分组」进行管理',
			'groupDiscovery.title' => '发现群组',
			'groupDiscovery.searchHint' => '搜索公开群',
			'groupDiscovery.allCategories' => '全部',
			'groupDiscovery.sortPopular' => '热门',
			'groupDiscovery.sortNewest' => '最新',
			'groupDiscovery.emptyTitle' => '暂无公开群，稍后再来看看',
			'groupDiscovery.searchEmpty' => '无匹配的公开群',
			'groupList.attrAll' => '全部',
			'groupList.attrOwner' => '我创建',
			'groupList.attrManager' => '我管理',
			'groupList.attrJoin' => '我加入',
			'groupList.refresh' => '刷新',
			'groupSchedule.title' => '群日程',
			'groupSchedule.createSchedule' => '创建日程',
			'groupSchedule.scheduleTitle' => '日程标题',
			'groupSchedule.selectDate' => '选择日期',
			'groupSchedule.selectTime' => '选择时间',
			'groupSchedule.location' => '地点',
			'groupSchedule.noSchedule' => '暂无日程',
			'groupSchedule.startTime' => '开始时间',
			'groupSchedule.endTime' => '结束时间',
			'groupSchedule.participants' => '参与人数',
			'groupSchedule.statusCancelled' => '已取消',
			'groupSchedule.statusInProgress' => '进行中',
			'groupSchedule.statusNotStarted' => '未开始',
			'groupSchedule.statusEnded' => '已结束',
			'groupSchedule.cancelSuccess' => '日程已取消',
			'groupSchedule.cancelFailed' => '取消失败，请稍后重试',
			'groupSchedule.confirmAttend' => '确认参加',
			'groupSchedule.declineAttend' => '不参加',
			'groupSchedule.cancelSchedule' => '取消日程',
			'groupSchedule.scheduleIdMissing' => '日程ID缺失，无法查看详情',
			'groupSchedule.untitledSchedule' => '未命名日程',
			'groupSchedule.cardViewAndAttend' => '查看详情并确认参加',
			'groupSchedule.cardViewDetail' => '查看详情',
			'groupSchedule.organizer' => '发起人',
			'groupSchedule.participantAttending' => '已参加',
			'groupSchedule.participantDeclined' => '已拒绝',
			'groupSchedule.participantPending' => '待回应',
			'groupSchedule.attendSummary' => ({required Object attending, required Object total}) => '${attending}/${total} 人参加',
			'groupSchedule.remindBefore' => ({required Object minutes}) => '开始前 ${minutes} 分钟提醒',
			'groupSchedule.duration' => ({required Object minutes}) => '预计 ${minutes} 分钟',
			'groupSchedule.hintToday' => '今天',
			'groupSchedule.hintTomorrow' => '明天',
			'groupSchedule.startsHint' => ({required Object hint, required Object time}) => '${hint} ${time} 开始',
			'groupSchedule.sectionToday' => '今天',
			'groupSchedule.sectionThisWeek' => '本周',
			'groupSchedule.sectionLater' => '更晚',
			'groupSchedule.allParticipants' => ({required Object count}) => '全部参与人（${count}）',
			'groupSchedule.collapseParticipants' => '收起',
			'groupTag.title' => '群标签',
			'groupTag.addTag' => '添加标签',
			'groupTag.tagName' => '标签名称',
			'groupTag.noTag' => '暂无标签',
			'groupTag.removeTitle' => '移除标签',
			_ => null,
		} ?? switch (path) {
			'groupTag.removeConfirm' => '确定要移除这个标签吗？',
			'groupTask.title' => '待办',
			'groupTask.createTask' => '创建待办',
			'groupTask.editTask' => '编辑待办',
			'groupTask.taskTitle' => '待办标题',
			'groupTask.taskDescription' => '待办描述',
			'groupTask.deadline' => '截止时间',
			'groupTask.noDeadline' => '无截止时间',
			'groupTask.noTask' => '暂无待办',
			'groupTask.all' => '全部',
			'groupTask.pending' => '待完成',
			'groupTask.completed' => '已完成',
			'groupTask.taskSubmitted' => '待办已提交',
			'groupTask.submitTask' => '提交待办',
			'groupTask.overdue' => '已过期',
			'groupTask.daysLeft' => ({required Object days}) => '${days} 天后截止',
			'groupTask.hoursLeft' => ({required Object hours}) => '${hours} 小时后截止',
			'groupTask.dueSoon' => '即将截止',
			'groupTask.submitFailed' => '提交失败，请稍后重试',
			'groupTask.pendingReview' => '待审核',
			'groupTask.taskIdMissing' => '待办ID缺失，无法查看详情',
			'groupTask.taskIdMissingSubmit' => '待办ID缺失，无法提交',
			'groupTask.publishedAt' => ({required Object time}) => '${time} 发布',
			'groupTask.completedAt' => ({required Object time}) => '完成于 ${time}',
			'groupVote.title' => '群投票',
			'groupVote.createVote' => '创建投票',
			'groupVote.voteTitle' => '投票标题',
			'groupVote.noVote' => '暂无投票',
			'groupVote.voteEnded' => '投票已结束',
			'groupVote.totalVotes' => ({required Object count}) => '共 ${count} 票',
			'groupVote.voteSuccess' => '投票成功',
			'groupVote.cancelVoteSuccess' => '已取消投票',
			'groupVote.eachOptionPerLine' => '每行一个选项',
			'groupVote.statusInProgress' => '进行中',
			'groupVote.updateVote' => '更新投票',
			'groupVote.cancelMyVote' => '取消我的投票',
			'groupVote.voteIdMissing' => '投票ID缺失，无法查看详情',
			'groupVote.participantCount' => ({required Object count}) => '参与人数: ${count}',
			'groupVote.singleChoice' => '单选',
			'groupVote.multipleChoice' => '多选',
			'groupVote.endVote' => '结束投票',
			'groupVote.alreadyVoted' => '已投票',
			'groupVote.selectedCount' => ({required Object count}) => '已选 ${count} 项',
			'groupVote.voteCount' => ({required Object count}) => '${count} 票',
			'main.totalAssets' => '总资产',
			'main.album' => '照片',
			'main.appSize' => '应用大小',
			'main.arSa' => '阿拉伯语（沙特阿拉伯）',
			'main.audio' => '音频',
			'main.barcodeFound' => '已识别二维码',
			'main.botQianFan' => '千帆机器人',
			'main.liveRoomWhipLabel' => 'WHIP 推流地址',
			'main.liveRoomWhepLabel' => 'WHEP 拉流地址',
			'main.cache' => '缓存',
			'main.camera' => '拍摄',
			'main.changeParam' => ({required Object param}) => '修改${param}',
			'main.chooseFromAlbum' => '从相册选择',
			'main.clean' => '清理',
			'main.codeSentToParam' => ({required Object param}) => '验证码已发送到${param}',
			'main.collected' => '已收藏',
			'main.completed' => '已完结',
			'main.copied' => '已复制',
			'main.darkModel' => '深色模式',
			'main.deDd' => '德语（德国）',
			'main.disable' => '禁用',
			'main.enUs' => '美国英语',
			'main.enable' => '启用',
			'main.expired' => '已过期',
			'main.e2eeCollectRotating' => '密钥轮换进行中，请稍后重试',
			'main.e2eeCollectUnsupported' => '服务器暂不支持端到端加密收藏，请先升级服务端',
			'main.favorites' => '收藏',
			'main.female' => '女',
			'main.followSystem' => '跟随系统',
			'main.frFr' => '法语（法国）',
			'main.from' => '来自',
			'main.good' => '很棒',
			'main.hangup' => '挂断',
			'main.iAm' => '我是',
			'main.itIt' => '意大利语（意大利）',
			'main.jaJp' => '日语（日本）',
			'main.keepSecret' => '保密',
			'main.lastActiveTime' => '最近活跃时间',
			'main.lastSeenHide' => '隐藏在线状态',
			'main.lastSeenNever' => '从未上线',
			'main.lastSeenWeeksAgo' => ({required Object param}) => '${param}周前',
			'main.lastSeenExactTime' => ({required Object param}) => '上次在线 ${param}',
			'main.licenseAgreement' => '《软件许可及服务协议》',
			'main.loudspeaker' => '扩音器',
			'main.makeYourselfInvisible' => '让自己不可见',
			'main.makeYourselfVisible' => '让自己可见',
			'main.male' => '男',
			'main.manage' => '管理',
			'main.markStar' => '收藏',
			'main.multiSelect' => '多选',
			'main.myFavorites' => '我的收藏',
			'main.myLive' => '我的直播',
			'main.name' => '名称',
			'main.numUnit' => ({required Object param}) => '${param}个',
			'main.openInBrowser' => '在浏览器中打开',
			'main.or' => '或者',
			'main.otherParty' => '对方',
			'main.packageSize' => '包大小',
			'main.peerHasHungUp' => '对方已挂断',
			'main.play' => '播放',
			'main.pleaseInputParam' => ({required Object param}) => '请输入${param}',
			'main.pleaseSelect' => '请选择',
			'main.quote' => '引用',
			'main.recentlyUsed' => '最近使用',
			'main.releaseEnd' => '松开结束',
			'main.memberDetail' => '成员详情',
			'main.replied' => '已回复',
			'main.ringing' => '已响铃...',
			'main.ruRu' => '俄罗斯俄语',
			'main.selectedCount' => ({required Object count}) => '已选 (${count})',
			'main.selected' => '已选',
			'main.sent' => '已发送',
			'main.sentByMe' => '我发送的',
			'main.setParam' => ({required Object param}) => '设置${param}',
			'main.setting' => '设置',
			'main.siginQ' => '已经有账号了？',
			'main.source' => '来源',
			'main.speakingTooShort' => '说话时间太短',
			'main.speed' => '速度',
			'main.stillNeeded' => '还需',
			'main.storageSpace' => '存储空间',
			'main.text' => '文本',
			'main.thisWeek' => '本周',
			'main.titleMine' => '我的',
			'main.tooBad' => '太差了',
			'main.tryAgainQ' => '想再试一次吗？',
			'main.type' => '类型',
			'main.unanswered' => '未应答',
			'main.unnamed' => '未命名',
			'main.usedSpace' => '已使用空间',
			'main.you' => '你',
			'main.zhCn' => '简体中文',
			'main.zhHant' => '繁体中文',
			'main.bound' => '已绑定',
			'main.correct' => '正确',
			'main.pendingInput' => '待输入',
			'main.lengthCheck' => '长度检查',
			'main.bugReport' => '错误报告',
			'main.deleting' => '删除中...',
			'main.publish' => '发布',
			'main.privacyPolicy' => '隐私政策',
			'main.termsOfService' => '服务条款',
			'main.saving' => _root.common.loading,
			'main.systemDefault' => '系统默认',
			'main.gradientBlue' => '渐变蓝',
			'main.gradientPurple' => '渐变紫',
			'main.copiedToClipboard' => '已复制到剪贴板',
			'main.destroyTime' => '销毁时间',
			'main.previewEffect' => '预览效果',
			'main.thisIsTitleText' => '这是标题文本',
			'main.thisIsAuxiliaryText' => '这是辅助说明文字',
			'main.toBeCompleted' => '待完善',
			'main.availableCount' => '可选择',
			'main.mostUsed' => '最常用',
			'main.school' => '学校',
			'main.hobbiesAndInterests' => '兴趣爱好',
			'main.interests' => '兴趣爱好',
			'main.selectFromAlbum' => '从相册选择',
			'main.volumeUp' => '音量增加',
			'main.volumeDown' => '音量减少',
			'main.fastRewind' => ({required Object seconds}) => '快退 ${seconds}秒',
			'main.pleaseTryAgain' => '请重试',
			'main.secret' => '保密',
			'main.takePhoto' => '拍照',
			'main.deletingInProgressPleaseWait' => '正在删除中，请稍候...',
			'main.collecting' => '收藏中...',
			'main.user' => '用户',
			'main.recommended' => '推荐',
			'main.larger' => '更大',
			'main.fillIn' => '填入',
			'main.msgProtectedByComplianceKey' => '消息受合规密钥保护',
			'main.inviterLabel' => ({required Object uid}) => '邀请人: ${uid}',
			'main.inviteeLabel' => ({required Object uid}) => '被邀请人: ${uid}',
			'main.mySentTab' => '我发出的',
			'main.reject' => '拒绝',
			'main.myOrders' => '我的订单',
			'main.purchaseUnlockHint' => '购买后可解锁频道历史消息与后续更新内容。',
			'main.payingDots' => '支付中...',
			'main.purchaseAndUnlock' => '立即购买并解锁',
			'main.orderDetail' => '订单详情',
			'main.orderAmountLabel' => ({required Object currency, required Object amount}) => '金额: ${currency} ${amount}',
			'main.channelPriceLabel' => ({required Object currency, required Object amount}) => '价格：${currency} ${amount}',
			'main.e2eeKeyRecoveryTitle' => '端到端加密密钥管理',
			'main.e2eeRecoveryMethods' => '密钥恢复方法',
			'main.e2eeDangerousOps' => '危险操作',
			'main.e2eeKeyIdLabel' => '密钥 ID',
			'main.e2eeWarnIrreversible' => '• 此操作不可撤销',
			'main.e2eeWarnNeedRestoreOrNew' => '• 需要从备份恢复或生成新密钥',
			'main.gotIt' => '我知道了',
			'main.webQRLoggingIn' => '登录中...',
			'main.webQRExpired' => '二维码已过期',
			'main.webQRRefresh' => '刷新二维码',
			'main.webSwitchToQR' => '使用 QR 码登录',
			'main.e2eeErrDefault' => '端到端加密失败，消息未发送',
			'main.e2eeErrPeerDeviceNotReady' => '有成员的设备尚未完成安全设置，消息未发送；请稍后重试',
			'main.e2eeErrComplianceChanged' => '合规审计密钥已变更，消息未发送，请确认轮换后重试',
			'main.e2eeErrComplianceUnavailable' => '合规密钥暂不可用，消息未发送，请稍后重试',
			'main.e2eeErrComplianceExpired' => '合规密钥已过期，请联系管理员',
			'main.complianceKeyRotationConfirmed' => '合规密钥轮换已确认，可重新发送消息',
			'main.complianceKeyRotationNoPending' => '没有待确认的密钥变更',
			'main.e2eeErrDeviceNotReady' => '当前设备未完成安全初始化，请退出重新登录后重试',
			'main.e2eeErrSessionExportFailed' => '群会话密钥生成失败，请稍后重试',
			'main.e2eeErrProtocolMismatch' => '加密协议配置异常，请更新应用后重试',
			'main.e2eeErrPeerSuiteUnsupported' => '对方设备不支持要求的加密套件，消息未发送；请让对方更新应用后重试',
			'main.complianceKeyInfoTitle' => '合规审计密钥',
			'main.complianceKeyInfoServerKey' => '服务端下发的公钥',
			'main.complianceKeyInfoLocalPin' => '本地固定（TOFU）',
			'main.complianceKeyInfoKeyId' => '密钥 ID',
			'main.complianceKeyInfoAlgorithm' => '算法',
			'main.complianceKeyInfoFingerprint' => '公钥指纹',
			'main.complianceKeyInfoFetchedAt' => '获取时间',
			'main.complianceKeyInfoPinnedAt' => '固定时间',
			'main.complianceKeyInfoPinnedNone' => '尚未固定（下次获取时自动固定）',
			'main.complianceKeyInfoChangedWarning' => '⚠️ 服务端下发的合规公钥与本地固定不一致！若这不是管理员有意的轮换，请立即联系管理员，并停止发送加密消息。',
			'main.complianceKeyInfoRefreshFailed' => '获取失败，请检查网络后重试',
			'main.complianceKeyInfoHint' => '合规审计密钥用于 compliance_e2ee 模式的双重加密。若上方指纹与管理员公布的指纹不一致，说明服务端可能被篡改。',
			'main.safetyNumberTitle' => '安全码验证',
			'main.safetyNumberHint' => '请通过面对面或电话与对方比对安全码。若一致，说明你们的通信没有被中间人监听；若不一致，请立即停止对话并通过其他渠道核实对方身份。验证状态仅保存在本机。',
			'main.safetyNumberCopy' => '复制',
			'main.safetyNumberCopied' => '已复制',
			'main.safetyNumberMarkVerified' => '标记为已验证',
			'main.safetyNumberMarkedVerified' => '已标记为已验证',
			'main.safetyNumberPeerDevice' => '对方设备',
			'main.safetyNumberNoDevices' => '对方尚未启用端到端加密',
			'main.safetyNumberVerifyFailed' => '获取安全码失败，请稍后重试',
			'main.safetyNumberReporting' => '正在上报验证结果...',
			'main.safetyNumberReportRejected' => '服务端拒绝了该验证事件（签名/时效不符），未标记',
			'main.safetyNumberReportUnavailable' => '无法获取设备信息，未上报',
			'main.safetyNumberVerified' => '✓ 已验证',
			'main.safetyNumberNotVerified' => '未验证',
			'main.safetyNumberDeviceCount' => ({required Object count}) => '${count} 台设备',
			'main.liveRoomTitleLabel' => '直播间标题',
			'main.liveRoomTitleHint' => '请输入直播间标题',
			'main.lightModel' => '浅色模式',
			'main.complianceKeyNotConfigured' => '当前部署未配置合规审计密钥',
			'main.mineContent' => '我的内容',
			'main.mineCommonEntries' => '常用入口',
			'main.mineManagementSupport' => '管理与支持',
			'main.mineSettingsSupport' => '设置与支持',
			'main.mineStorageUsage' => '管理占用',
			'mention.mentionAll' => '所有人',
			'mention.mentionAllHint' => '通知所有群成员',
			'mention.noMatchedMember' => '没有匹配的成员',
			'mention.title' => '@提及',
			'mention.noMention' => '暂无@提及',
			'mention.allRead' => '全部已读',
			'mention.mentionAllDenied' => '仅管理员可以 @所有人',
			'mention.navInfoMissing' => '消息定位信息缺失，无法跳转',
			'mention.pickButtonTooltip' => '@提及成员',
			'momentFriendPicker.confirm' => '确定',
			'momentFriendPicker.confirmWithCount' => ({required Object count}) => '确定(${count})',
			'momentFriendPicker.selectedCount' => ({required Object count}) => '已选 ${count} 人',
			'momentFriendPicker.emptyFriends' => '暂无好友',
			'momentFriendPicker.tagLoadFailed' => '标签加载失败',
			'momentFriendPicker.searchHint' => '搜索好友',
			'momentNotify.title' => '互动消息',
			'momentNotify.emptyTitle' => '暂无新消息',
			'momentNotify.emptyHint' => '好友点赞或评论你的朋友圈后，会出现在这里',
			'momentNotify.actionLike' => '赞了你的朋友圈',
			'momentNotify.actionComment' => '评论了你',
			'momentNotify.markAllRead' => '全部已读',
			'momentNotify.clearAll' => '清空全部',
			'momentNotify.clearConfirmTitle' => '清空所有通知？',
			'momentNotify.clearConfirmMessage' => '清空后无法恢复',
			'momentNotify.confirm' => '确定',
			'momentNotify.cancel' => '取消',
			'momentNotify.delete' => '删除',
			'momentNotify.loadFailed' => '加载失败，请稍后重试',
			'organization.common.moreActions' => '更多操作',
			'organization.common.rename' => '重命名',
			'organization.common.close' => '关闭',
			'organization.common.reload' => '重新加载',
			'organization.common.createFailed' => '创建失败',
			'organization.common.addFailed' => '添加失败',
			'organization.common.confirmArchive' => '确认归档',
			'organization.common.forbidden403' => '无权执行该操作（403）',
			'organization.common.noMembers' => '暂无成员',
			'organization.common.targetUidHint' => '对方用户 UID（数字）',
			'organization.common.uidMustBePositive' => '用户 UID 必须是正整数',
			'organization.common.loading' => '加载中…',
			'organization.common.loadMore' => '加载更多',
			'organization.common.orgStatusPending' => '审核中',
			'organization.common.orgStatusRejected' => '未通过审核',
			'organization.home.createOrg' => '创建企业',
			'organization.home.orgNameLabel' => '企业名称（1-200 字符）',
			'organization.home.createFailedWith' => ({required Object msg, required Object code}) => '创建失败：${msg} (${code})',
			'organization.home.createSubmittedPendingReview' => '已提交，等待运营审核，审核通过后企业可正常使用',
			'organization.home.tabOrg' => '企业',
			'organization.home.myInvitations' => '我的邀请',
			'organization.home.emptyHint' => '尚未加入任何企业\n下拉刷新或点击右上角创建',
			'organization.detail.leaveOrg' => '退出企业',
			'organization.detail.leaveOrgBody' => '退出后将失去本企业的通讯录、群、频道和资料访问资格；企业资料会保留。重新加入需要邀请。',
			'organization.detail.leaveFailed' => '退出失败',
			'organization.detail.leaveOwnerHint' => '请先移交企业负责人，再退出企业',
			'organization.detail.leaveCleanupFailed' => '已退出企业，但本地偏好清理失败，请重启后重新确认空间',
			'organization.detail.title' => '企业详情',
			'organization.detail.notFound' => '企业不存在',
			'organization.detail.archiveOrg' => '归档企业',
			'organization.detail.archiveConfirmBody' => '归档后企业进入只读态，全部写操作 fail-closed，仅恢复（restore）可解锁。成员与数据不会被删除。',
			'organization.detail.restoreOrg' => '恢复企业',
			'organization.detail.restoreConfirmBody' => '恢复后企业回到 active 态，写入口重新开放。',
			'organization.detail.confirmRestore' => '确认恢复',
			'organization.detail.restoreFailed' => '恢复失败',
			'organization.detail.archiveFailed' => '归档失败',
			'organization.detail.renameOrgTitle' => '修改企业名称',
			'organization.detail.renameOrgLabel' => '企业名称（1-200 字符）',
			'organization.detail.renameAction' => '修改名称',
			'organization.detail.renameFailed' => '改名失败',
			'organization.detail.deletionPreflight' => '账号删除预检',
			'organization.detail.deletionPreflightDesc' => '查看本账号被哪些依赖域阻塞删除',
			'organization.detail.observedAt' => ({required Object ts}) => '观察时刻：${ts}',
			'organization.detail.factDomains' => ({required Object domains}) => '覆盖依赖域：${domains}',
			'organization.detail.noBlockers' => '无阻塞项',
			'organization.detail.blockers' => '阻塞项：',
			'organization.detail.factUnavailable' => '依赖域事实不可用，删除预检被拒绝（fail-closed）',
			'organization.detail.preflightFailed' => ({required Object msg, required Object code}) => '预检失败：${msg} (${code})',
			'organization.detail.myRoleAndStatus' => ({required Object role, required Object status}) => '我的角色：${role} · 状态：${status}',
			'organization.detail.archivedBadge' => '企业已归档（只读）',
			'organization.detail.archivedHint' => '归档期间全部写操作被拒绝，仅恢复操作可用',
			'organization.detail.defaultWsSet' => ({required Object id}) => '默认 Workspace：${id}',
			'organization.detail.defaultWsUnset' => '默认 Workspace：未设置',
			'organization.detail.defaultWsNote' => '指向事实，不代表任何 workspace 成员身份',
			'organization.detail.memberList' => '成员列表',
			'organization.detail.memberListRestricted' => '成员列表（仅 owner/admin 可查看）',
			'organization.detail.invitationManage' => '邀请管理',
			'organization.detail.invitationManageRestricted' => '邀请管理（仅 owner/admin 可管理）',
			'organization.detail.deptEntry' => '部门目录',
			'organization.detail.deptEntryRestricted' => '部门目录（管理操作仅限授权者）',
			'organization.detail.more' => '更多',
			'organization.detail.archiveEntrySubtitle' => '进入只读态；可随时恢复',
			'organization.detail.restoreEntrySubtitle' => '回到 active 态',
			'organization.members.title' => '成员',
			'organization.members.loadMoreFailed' => ({required Object err}) => '加载更多失败：${err}',
			'organization.members.changeRole' => '变更角色',
			'organization.members.changeRoleBody' => ({required Object name, required Object from, required Object to}) => '将「${name}」的角色由 ${from} 调整为 ${to}。',
			'organization.members.confirmChange' => '确认变更',
			'organization.members.changeRoleFailed' => '角色变更失败',
			'organization.members.removeMember' => '移除成员',
			'organization.members.removeMemberBody' => ({required Object name}) => '将「${name}」移出本企业。该操作不会删除其账号。',
			'organization.members.confirmRemove' => '确认移除',
			'organization.members.removeFailed' => '移除失败',
			'organization.members.transferOwner' => '转移所有者',
			'organization.members.transferOwnerBody' => ({required Object name}) => '企业有且仅有一个 owner（C04）：确认将「${name}」设为所有者，\n你将降级为普通管理员/成员。该操作直接影响企业控制权。',
			'organization.members.confirmTransfer' => '确认转移',
			'organization.members.transferFailed' => '转移失败',
			'organization.members.demoteToMember' => '降级为成员',
			'organization.members.promoteToAdmin' => '升级为管理员',
			'organization.members.transferOwnerTo' => ({required Object name}) => '转移所有者给「${name}」',
			'organization.members.ownerCannotChangeHere' => 'Owner 不可在此变更；请使用「转移所有者」',
			'organization.members.viewDetail' => '查看详情',
			'organization.members.suspendMember' => '暂停成员',
			'organization.members.suspendBody' => ({required Object name}) => '暂停「${name}」在本企业的访问权限（即时生效；不影响其个人账号与其他企业）。可随时恢复。',
			'organization.members.confirmSuspend' => '确认暂停',
			'organization.members.suspendFailed' => '暂停失败',
			'organization.members.restoreMember' => '恢复成员',
			'organization.members.restoreBody' => ({required Object name}) => '恢复「${name}」在本企业的访问权限。',
			'organization.members.confirmRestoreMember' => '确认恢复',
			'organization.members.restoreFailed' => '恢复失败',
			'organization.members.offboardMember' => '离场（终态）',
			'organization.members.offboardBody' => ({required Object name}) => '「${name}」将离场本企业：removed 终态、不可恢复，如需再次加入须重新邀请。',
			'organization.members.confirmOffboard' => '确认离场',
			'organization.members.offboardFailed' => '离场失败',
			'organization.members.empty' => '暂无成员',
			'organization.invitations.inviteMember' => '邀请成员',
			'organization.invitations.invitationCreated' => '邀请已创建',
			'organization.invitations.tokenOnceNotice' => '领取口令（token）只显示这一次，请立即复制并线下转交对方：',
			'organization.invitations.tokenCopied' => '已复制口令',
			'organization.invitations.copyToken' => '复制口令',
			'organization.invitations.inviteFailed' => ({required Object msg, required Object code}) => '邀请失败：${msg} (${code})',
			'organization.invitations.acceptTitle' => '接受邀请',
			'organization.invitations.acceptBody' => ({required Object orgId}) => '接受后你将加入企业 ${orgId}；\n该邀请一次性生效，成员资格以服务端为准。',
			'organization.invitations.confirmAccept' => '确认接受',
			'organization.invitations.acceptFailed' => '接受失败',
			'organization.invitations.rejectTitle' => '拒绝邀请',
			'organization.invitations.rejectBody' => '拒绝后该邀请进入终态，不可再接受。',
			'organization.invitations.confirmReject' => '确认拒绝',
			'organization.invitations.rejectFailed' => '拒绝失败',
			'organization.invitations.revokeTitle' => '撤销邀请',
			'organization.invitations.revokeBody' => '撤销后该邀请进入终态，目标用户无法再凭口令接受。',
			'organization.invitations.confirmRevoke' => '确认撤销',
			'organization.invitations.revokeFailed' => '撤销失败',
			'organization.invitations.myInvitations' => '我的邀请',
			'organization.invitations.manageInvitations' => '邀请管理',
			'organization.invitations.createInvitation' => '创建邀请',
			'organization.invitations.empty' => '暂无邀请',
			'organization.invitations.emptyRecord' => '暂无邀请记录',
			'organization.invitations.orgLine' => ({required Object orgId}) => '企业 ${orgId}',
			'organization.invitations.invitationLine' => ({required Object invitationId}) => '邀请 ${invitationId}',
			'organization.invitations.targetLine' => ({required Object targetUserId, required Object subtitle}) => '目标 ${targetUserId} · ${subtitle}',
			'organization.invitations.acceptNotice' => '点击邀请即可直接接受（无需口令）；\n接受成功后成员资格以服务端为准。',
			'organization.invitations.revokeAction' => '撤销',
			'organization.invitations.acceptAction' => '接受邀请',
			'organization.invitations.rejectAction' => '拒绝',
			'organization.departments.title' => '部门管理',
			'organization.departments.statusLine' => ({required Object status}) => '状态：${status}',
			'organization.departments.memberUidLine' => ({required Object userId}) => '成员 ${userId}',
			'organization.departments.viewForbiddenDetail' => '无权查看该部门（仅限本企业在职成员）',
			'organization.departments.viewForbidden' => '无权查看（仅限本企业在职成员）',
			'organization.departments.loadFailedWith' => ({required Object msg, required Object code}) => '加载部门失败：${msg} (${code})',
			'organization.departments.loadFailed' => ({required Object err}) => '加载部门失败：${err}',
			'organization.departments.createSubHere' => '在其下新建子部门',
			'organization.departments.movePickParent' => '移动（选择新父部门）',
			'organization.departments.addMemberByUid' => '添加成员（按 UID）',
			'organization.departments.archiveDept' => '归档部门',
			'organization.departments.createRootDept' => '新建根部门',
			'organization.departments.deptNameLabel' => '部门名称',
			'organization.departments.createUnder' => ({required Object parent}) => '在「${parent}」下新建',
			'organization.departments.renameDept' => '重命名部门',
			'organization.departments.newNameLabel' => '新名称',
			'organization.departments.renameFailed' => '重命名失败',
			'organization.departments.moveDept' => '移动部门',
			'organization.departments.rootLevel' => '企业根目录',
			'organization.departments.moveFailed' => '移动失败',
			'organization.departments.addDeptMember' => '添加部门成员',
			'organization.departments.archiveConfirmBody' => ({required Object name}) => '归档「${name}」后该部门进入只读态（成员关系保留）。',
			'organization.departments.archiveFailed' => '归档失败',
			'organization.departments.emptyWithHint' => '暂无部门，点击右上角新建',
			'organization.departments.empty' => '暂无部门',
			'organization.departments.emptySubtitle' => '兼职模型：同一成员可属多个部门；部门成员须先是本企业成员。',
			'organization.departments.casConflictHint' => '部门已被并发修改，已刷新为最新部门树，请重试操作',
			'organization.departments.expandNode' => ({required Object name}) => '展开「${name}」',
			'organization.departments.collapseNode' => ({required Object name}) => '收起「${name}」',
			'organization.departments.removeMemberUid' => ({required Object userId}) => '移除成员 ${userId}',
			'organization.departments.removeMemberConfirm' => ({required Object userId, required Object name}) => '将把成员 ${userId} 移出「${name}」。其企业成员资格与在其他部门的身份不受影响（兼职模型）。',
			'organization.departments.removeMemberFailed' => '移除部门成员失败',
			'organization.departments.confirmRemoveMember' => '确认移除',
			'organization.departments.setDeptAdmin' => ({required Object userId}) => '设 ${userId} 为部门管理员',
			'organization.departments.unsetDeptAdmin' => ({required Object userId}) => '取消 ${userId} 的部门管理员',
			'organization.departments.setAdminFailed' => '设置部门管理员失败',
			'organization.departments.memberGovernActions' => '成员治理操作',
			'organization.picker.title' => '切换企业',
			'organization.picker.switchEnterprise' => '切换企业',
			'organization.picker.switchFailed' => '切换失败',
			'organization.picker.switchFailedRecovered' => '切换失败，已恢复原选择',
			'organization.picker.noneSelected' => '未选择企业',
			'organization.picker.emptyHint' => '尚未加入任何企业\n点击下方「加入企业」输入企业邀请码',
			'organization.picker.joinEnterprise' => '加入企业',
			'organization.picker.joinOrgIdLabel' => '企业 ID',
			'organization.picker.joinOrgIdHint' => '向企业管理员获取（数字 ID）',
			'organization.picker.joinOrgIdInvalid' => '请输入有效的企业 ID（数字）',
			'organization.picker.joinCodeLabel' => '企业邀请码',
			'organization.picker.joinSubmit' => '加入',
			'organization.picker.joinInvalidCode' => '企业邀请码无效或已失效',
			'organization.picker.joinExpiredCode' => '企业邀请码已过期',
			'organization.picker.joinFailed' => ({required Object msg}) => '加入失败：${msg}',
			'organization.picker.joinScanQr' => '扫码加入',
			'organization.picker.joinCodeOnlyHint' => '输入 8 位企业邀请码',
			'organization.picker.joinConfirmTitle' => '确认加入企业',
			'organization.picker.joinConfirmWith' => ({required Object name}) => '将加入企业「${name}」',
			'organization.picker.joinConfirmWithRole' => ({required Object role, required Object name}) => '确认以 ${role} 身份加入「${name}」？',
			'organization.picker.joinRoleMember' => '普通成员',
			'organization.picker.joinRoleAdmin' => '管理员',
			'organization.picker.joinConfirmSubmit' => '确认加入',
			'organization.picker.joinBack' => '返回修改',
			'organization.picker.joinQrHint' => '对准企业邀请二维码即可自动加入',
			'organization.picker.joinQrInvalid' => '不是有效的企业邀请二维码',
			'organization.inviteColleagues.title' => '邀请同事',
			'organization.inviteColleagues.tabInvite' => '邀请同事',
			'organization.inviteColleagues.tabPossible' => '可能的同事',
			'organization.inviteColleagues.wechatInvite' => '微信邀请同事',
			'organization.inviteColleagues.wechatInviteHint' => '把邀请码发给微信好友，对方打开 imboy 加入',
			'organization.inviteColleagues.faceToFace' => '面对面邀请同事',
			'organization.inviteColleagues.faceToFaceHint' => '同事扫码或输入邀请码即可加入',
			'organization.inviteColleagues.fromWechatGroup' => '从微信群中添加',
			'organization.inviteColleagues.fromWechatGroupHint' => '把邀请码发到微信群，同事复制后即可加入',
			'organization.inviteColleagues.shareText' => ({required Object orgName, required Object code, required Object inviteUrl}) => '【${orgName}】邀请你加入 imboy\n邀请码：${code}（7 天内有效）\n点击加入：${inviteUrl}\n打开 imboy App，在「通讯录 → 加入企业」输入邀请码即可加入',
			'organization.inviteColleagues.shareToWechat' => '分享邀请到微信',
			'organization.inviteColleagues.copyInviteCode' => '复制邀请码',
			'organization.inviteColleagues.codeValidityHint' => '邀请码 7 天内有效；重新生成后旧码立即失效',
			'organization.inviteColleagues.possibleLoadFailed' => '可能的同事加载失败，请重试',
			'organization.inviteColleagues.revokeFailed' => '撤销失败，请稍后重试',
			'organization.inviteColleagues.guideCodeMissing' => '暂无有效邀请码，请先联系企业管理员生成',
			'organization.inviteColleagues.possibleEmptyCta' => '去邀请同事',
			'organization.inviteColleagues.codeLoadFailed' => '邀请码加载失败，请重试',
			'organization.inviteColleagues.codeMissingHint' => '暂无有效邀请码，生成后即可分享',
			'organization.inviteColleagues.generateCode' => '生成邀请码',
			'organization.inviteColleagues.generateForbidden' => '仅企业管理员可生成邀请码，请联系管理员',
			'organization.inviteColleagues.possibleEmpty' => '暂无待加入的同事',
			'organization.inviteColleagues.possibleEmptyHint' => '去邀请你的同事加入吧',
			'organization.inviteColleagues.invitedBy' => ({required Object name}) => '${name} 邀请',
			'organization.inviteColleagues.invitedAt' => ({required Object time}) => '邀请于 ${time}',
			'organization.inviteColleagues.revoke' => '撤销',
			'organization.inviteColleagues.revokeTitle' => '撤销邀请',
			'organization.inviteColleagues.revokeBody' => ({required Object name}) => '撤销对「${name}」的邀请？',
			'organization.inviteColleagues.revoked' => '已撤销邀请',
			'organization.inviteColleagues.groupStep1' => '把邀请码分享到你的微信群',
			'organization.inviteColleagues.groupStep2' => '同事复制邀请码，打开 imboy App',
			'organization.inviteColleagues.groupStep3' => '在「通讯录 → 加入企业」输入邀请码即可加入',
			'organization.inviteColleagues.codeLabelWith' => ({required Object code}) => '邀请码：${code}',
			'organization.inviteQr.orgQrcode' => '企业二维码',
			'organization.inviteQr.title' => '邀请成员',
			'organization.inviteQr.entryHint' => '出示二维码或邀请码，对方扫码 / 输码即可加入',
			'organization.inviteQr.scanHint' => '对方用 imboy「扫一扫」扫描本码即可加入本企业',
			'organization.inviteQr.codeLabel' => '企业邀请码',
			'organization.inviteQr.expiresWith' => ({required Object date}) => '有效期至 ${date}',
			'organization.inviteQr.generate' => '生成邀请码',
			'organization.inviteQr.generateFirst' => '尚无有效邀请码。生成后 7 天有效，对方扫码或输入邀请码即可加入。',
			'organization.inviteQr.regenerate' => '重新生成',
			'organization.inviteQr.regenerateTitle' => '重新生成邀请码？',
			'organization.inviteQr.regenerateBody' => '旧邀请码将立即失效，已分享的二维码与口令随之作废。',
			'organization.inviteQr.generateFailed' => '生成邀请码失败，请稍后重试',
			'organization.inviteQr.loadFailed' => '邀请码加载失败',
			'organization.inviteQr.notAdmin' => '仅企业 Owner/Admin 可管理邀请码',
			'organization.inviteQr.copyCode' => '复制邀请码',
			'organization.inviteQr.copied' => '已复制邀请码',
			'organization.inviteQr.inviteDisabledPending' => '企业待审核，审核通过后才能邀请成员',
			'organization.directory.currentMembersSection' => '本级成员',
			'organization.directory.structureSection' => '组织架构',
			_ => null,
		} ?? switch (path) {
			'organization.directory.title' => '通讯录',
			'organization.directory.deptSection' => '部门',
			'organization.directory.allMembersSection' => '全部成员',
			'organization.directory.membersRestricted' => '全员名单仅企业管理员可见；可展开部门查看部门成员。',
			'organization.directory.imProfileEntry' => '查看 IM 资料',
			'organization.directory.myDepartmentsSection' => '我的部门',
			'organization.directory.membersSection' => '成员',
			'organization.directory.memberCountWith' => ({required Object count}) => '${count} 人',
			'organization.directory.searchHint' => '搜索部门或成员',
			'organization.directory.emptyDepartments' => '暂无子部门',
			'organization.directory.emptyMembers' => '暂无成员',
			'organization.directory.emptySearch' => '无匹配结果',
			'organization.directory.switchVerifyFailed' => '目标企业不可用或你已不是其成员',
			'organization.directory.switchShellFailed' => '新企业工作区加载失败',
			'organization.directory.inviteColleaguesRow' => '邀请同事...',
			'organization.directory.memberTotal' => ({required Object count}) => '共${count}人',
			'organization.memberDetail.roleLabel' => '企业角色',
			'organization.memberDetail.roleRestricted' => '仅企业管理员可查看',
			'organization.memberDetail.accountLabel' => '登录账号',
			'organization.memberDetail.joinedLabel' => '加入时间',
			'organization.memberDetail.workspacesTitle' => '有权工作区',
			'organization.memberDetail.workspacesEmpty' => '该成员在本企业内暂无工作区',
			'organization.memberDetail.workspacesFailed' => '有权工作区加载失败',
			'organization.manage.renameWorkspace' => '重命名工作区',
			'organization.manage.renameWorkspaceTitle' => ({required Object name}) => '重命名「${name}」',
			'organization.manage.wsMembersEntry' => '成员治理',
			'organization.manage.renameGroup' => '重命名',
			'organization.manage.renameGroupTitle' => ({required Object name}) => '重命名「${name}」',
			'organization.manage.groupGovernance' => '成员与角色',
			'organization.manage.renameChannel' => '重命名',
			'organization.manage.channelAdmins' => '管理员',
			'organization.manage.channelSubscribersEntry' => '订阅者',
			'organization.manage.entry' => '企业管理',
			'organization.manage.entryRestricted' => '企业管理（仅管理员）',
			'organization.manage.title' => '企业管理',
			'organization.manage.orgNotFound' => '企业不存在或你无权查看',
			'organization.manage.roleLine' => ({required Object role}) => '我的角色：${role}',
			'organization.manage.readOnlyHint' => '企业现状只读；管理动作仅企业所有者/管理员可用',
			'organization.manage.workspaceOwnerHint' => '这里只显示你拥有的工作区；企业级动作（新建工作区、设默认）需企业所有者/管理员。',
			'organization.manage.forbiddenTitle' => '无管理权限',
			'organization.manage.forbiddenBody' => '企业管理仅对企业所有者与管理员开放；需要时请联系管理员调整你的角色。',
			'organization.manage.workspaceSection' => '工作区',
			'organization.manage.createWorkspace' => '新建工作区',
			'organization.manage.workspaceNameHint' => '工作区名称',
			'organization.manage.workspaceEmpty' => '暂无工作区',
			'organization.manage.workspaceEmptyHint' => '当前企业下还没有你加入的工作区，可用右上角新建。',
			'organization.manage.workspaceScopeNote' => '这里只列出你已加入的工作区；同企业内你未加入的工作区不会出现。',
			'organization.manage.defaultBadge' => '默认工作区',
			'organization.manage.notDefaultBadge' => '非默认',
			'organization.manage.archivedBadge' => '已归档',
			'organization.manage.ownerBadge' => '我是所有者',
			'organization.manage.memberBadge' => '我是成员',
			'organization.manage.setDefault' => '设为默认工作区',
			'organization.manage.archiveWorkspace' => '归档工作区',
			'organization.manage.archiveWorkspaceTitle' => ({required Object name}) => '归档「${name}」？',
			'organization.manage.archiveWorkspaceBody' => '归档后该工作区进入只读，其群与频道一并停写；若它是企业默认工作区，请先指定替代工作区。归档可恢复。',
			'organization.manage.restoreWorkspace' => '恢复工作区',
			'organization.manage.resourceSection' => '群与频道',
			'organization.manage.resourceNeedsWorkspace' => '需要先有工作区，才能治理群与频道。',
			'organization.manage.resourceLoadFailed' => ({required Object err}) => '加载失败：${err}',
			'organization.manage.retry' => '重试',
			'organization.manage.groupSection' => '企业群',
			'organization.manage.createGroup' => '新建群',
			'organization.manage.creationRecoveryUnavailable' => '创建结果未知，请稍后重试',
			'organization.manage.groupCreatedRenamePending' => ({required Object gid}) => '群已创建（ID：${gid}），名称未保存',
			'organization.manage.groupNameHint' => '群名称',
			'organization.manage.groupEmpty' => '暂无企业群',
			'organization.manage.groupMembers' => ({required Object count}) => '成员 ${count}',
			'organization.manage.dissolveGroup' => '解散群',
			'organization.manage.dissolveGroupTitle' => ({required Object name}) => '解散「${name}」？',
			'organization.manage.dissolveGroupBody' => '解散不可恢复；成员关系会终止，但历史消息与审计记录保留。',
			'organization.manage.channelSection' => '企业频道',
			'organization.manage.createChannel' => '新建频道',
			'organization.manage.channelNameHint' => '频道名称',
			'organization.manage.channelPolicyNote' => '企业频道固定为「免费 + 非公开」：不进入公开发现，成员经工作区订阅。',
			'organization.manage.channelEmpty' => '暂无企业频道',
			'organization.manage.channelSubscribers' => ({required Object count}) => '订阅 ${count}',
			'organization.manage.createChannelFailed' => '频道创建失败',
			'organization.manage.archiveChannel' => '归档频道',
			'organization.manage.archiveChannelTitle' => ({required Object name}) => '归档「${name}」？',
			'organization.manage.archiveChannelBody' => '归档后频道退出公开面，成员不再看到；归档可恢复。',
			'organization.manage.restoreChannel' => '恢复',
			'organization.manage.archivedChannelSection' => '已归档频道',
			'organization.contactEntry.browserEntry' => '进入通讯录',
			'organization.contactEntry.loadFailed' => '企业信息加载失败',
			'organization.hub.sectionResources' => '企业资源',
			'organization.hub.sectionAdmin' => '管理员区',
			'organization.hub.zoneMembers' => '成员',
			'organization.hub.zoneMembersDesc' => '企业通讯录 · 按部门浏览',
			'organization.hub.zoneDepartments' => '部门',
			'organization.hub.zoneDepartmentsDesc' => '部门目录与层级',
			'organization.hub.zoneGroups' => '群',
			'organization.hub.zoneGroupsDesc' => '企业群 · 经企业管理查看',
			'organization.hub.zoneChannels' => '频道',
			'organization.hub.zoneChannelsDesc' => '企业频道 · 经企业管理查看',
			'organization.hub.zoneTools' => '工具',
			'organization.hub.zoneToolsDesc' => '工作区 · 项目与协作',
			'organization.hub.zoneOrgTools' => '企业协作工具',
			'organization.hub.zoneOrgToolsDesc' => '本企业已授权的工作区项目与任务',
			'organization.hub.adminMembers' => '成员治理',
			'organization.hub.adminMembersDesc' => '角色调整 · 移除成员',
			'organization.hub.adminInvitations' => '邀请管理',
			'organization.hub.adminInvitationsDesc' => '邀请创建与撤销',
			'organization.hub.adminManage' => '企业管理',
			'organization.hub.adminManageDesc' => '工作区 · 群 · 频道治理',
			'organization.hub.adminCsGovernance' => '客服治理',
			'organization.hub.adminCsGovernanceDesc' => '席位额度 · 坐席启停',
			'organization.wsMembers.title' => ({required Object ws}) => '工作区成员 · ${ws}',
			'organization.wsMembers.invite' => '邀请成员',
			'organization.wsMembers.inviteHint' => '经既有向导选择联系人发出邀请（仅工作区所有者）',
			'organization.wsMembers.readOnlyHint' => '当前只读；写操作仅工作区所有者可用',
			'organization.wsMembers.memberCount' => ({required Object count}) => '成员 ${count}',
			'organization.wsMembers.notFound' => '工作区不存在或你无权查看',
			'organization.wsMembers.roleOwner' => '所有者',
			'organization.wsMembers.roleMember' => '成员',
			'organization.wsMembers.roleGuest' => '访客',
			'organization.wsMembers.changeRole' => '更改角色',
			'organization.wsMembers.setRoleMember' => '设为成员',
			'organization.wsMembers.setRoleGuest' => '设为访客',
			'organization.wsMembers.transferOwner' => '转让所有者',
			'organization.wsMembers.transferOwnerTitle' => ({required Object name}) => '转让「${name}」的所有者？',
			'organization.wsMembers.transferOwnerBody' => '转让后你不再是该工作区所有者，写治理权限随之移交给对方；新所有者可再转回。',
			'organization.wsMembers.removeMember' => '移除成员',
			'organization.wsMembers.removeTitle' => ({required Object name}) => '移除「${name}」？',
			'organization.wsMembers.removeBody' => '移除后对方退出该工作区；若对方仍是项目所有者或有未完成任务，服务端会拒绝并列出冲突。',
			'organization.wsMembers.archivedReadOnly' => '工作区已归档：成员治理写操作已被服务端停用。',
			'organization.tools.title' => '企业工具',
			'organization.tools.titleWithOrg' => ({required Object name}) => '${name} · 企业工具',
			'organization.tools.scopeNote' => '这里只列出你已加入的本企业工作区与其项目；任务、里程碑等在项目详情内。',
			'organization.tools.archivedNote' => '企业已归档：工具区只读。',
			'organization.tools.workspaceEmpty' => '暂无已加入的工作区',
			'organization.tools.workspaceEmptyHint' => '同企业内你未加入的工作区不会出现在这里。',
			'organization.tools.projectCount' => ({required Object count}) => '项目 ${count}',
			'organization.tools.projectsEmpty' => '暂无项目',
			'organization.tools.projectsError' => ({required Object err}) => '项目加载失败：${err}',
			'organization.tools.moreInWorkspaceShell' => '浏览全部工作区',
			'organization.tools.moreInWorkspaceShellHint' => '打开全局工作区切换器（跨企业）。',
			'organization.chart.zoomIn' => '放大',
			'organization.chart.zoomOut' => '缩小',
			'organization.chart.fit' => '适应窗口',
			'organization.chart.expand' => '展开下级部门',
			'organization.chart.collapse' => '收起下级部门',
			'organization.chart.gestureHint' => '拖动查看 · 双指缩放',
			'organization.chart.directMembers' => ({required Object count}) => '本级 ${count} 人',
			'organization.experienceUi.switchSpace' => '切换空间',
			'organization.experienceUi.personalSpace' => '个人空间',
			'organization.experienceUi.enterpriseSpaces' => '企业空间',
			'organization.experienceUi.currentSpace' => '当前空间',
			'organization.experienceUi.enterpriseInfo' => '企业资料',
			'organization.experienceUi.collaborationSpace' => '协作空间',
			'organization.experienceUi.groupContent' => '群内容',
			'organization.experienceUi.groupCollaboration' => '群协作',
			'organization.experienceUi.defaultWorkspace' => '默认工作区',
			'organization.experienceUi.defaultAvailable' => '已设置',
			'organization.experienceUi.defaultUnknown' => '暂时无法获取',
			'organization.experienceUi.defaultHint' => '加入相应工作区后可进入，默认设置不会自动授予访问权限。',
			'organization.experienceUi.accountCheck' => '注销前检查',
			'organization.experienceUi.workspaceContext' => ({required Object name}) => '工作区：${name}',
			'organization.experienceUi.noIntro' => '暂无简介',
			'organization.experienceUi.talkRecordPersonalPendingTitle' => '个人面聊记录待处理',
			'organization.experienceUi.talkRecordPersonalPendingBody' => '请先处理个人面聊记录，再重新检查注销条件。',
			'organization.experienceUi.talkRecordCleanupPendingTitle' => '录音文件仍在清理',
			'organization.experienceUi.talkRecordCleanupPendingBody' => '记录已删除，文件清理尚未完成。可查看真实进度；保留规则或处理保护不能被手动跳过。',
			'organization.experienceUi.talkRecordOrganizationOwnerPendingTitle' => '企业面聊记录尚未移交',
			'organization.experienceUi.talkRecordOrganizationOwnerPendingBody' => '请先移交企业面聊记录的管理责任。移交不会自动解除历史身份引用。',
			'organization.experienceUi.talkRecordRetainedIdentityPendingTitle' => '历史身份引用待核查',
			'organization.experienceUi.talkRecordRetainedIdentityPendingBody' => '历史记录仍引用此身份，当前无法完成注销。移交记录不保证解除这些引用。',
			'organization.experienceUi.openPersonalTalkRecords' => '查看个人面聊记录',
			'organization.experienceUi.viewTalkRecordCleanup' => '查看清理进度',
			'organization.experienceUi.cleanupRecordLabel' => '记录',
			'organization.experienceUi.cleanupResourcesTruncated' => '仅显示前 20 条，处理后请刷新检查剩余项。',
			'organization.experienceUi.unknownBlockerTitle' => '还有待处理事项',
			'passport.loginHistoryToggle' => '展开历史登录记录',
			'passport.hintEmail' => '请输入邮箱',
			'passport.hintMobile' => '请输入手机号',
			'passport.hintPassword' => '请输入密码',
			'passport.hintVerifyCode' => '请输入验证码',
			'passport.getVerifyCode' => '获取验证码',
			'passport.oneKeyLogin' => '一键登录',
			'passport.qrCodeExpired' => '二维码已过期，请重新扫码',
			'passport.qrCodeUsed' => '此二维码已使用',
			'passport.qrLoginCancelled' => '登录已取消',
			'passport.qrLoginConfirming' => '正在登录...',
			'passport.qrLoginCancelledByMe' => '已取消登录',
			'passport.qrConnecting' => '正在连接...',
			'passport.qrWebLoginTitle' => 'Web 端登录确认',
			'passport.qrWebLoginDesc' => '请确认是否在 Web 端登录此账号',
			'passport.qrLoginAction' => '确认登录',
			'passport.qrLoginSuccess' => '登录成功',
			'passport.alipayNotSupportedWeb' => 'Web 平台不支持支付宝登录',
			'passport.oneKeyNotSupportedWeb' => 'Web 平台不支持一键登录功能',
			'passport.oneKeyInitFailed' => '一键登录服务初始化失败，请稍后重试',
			'passport.oneKeyNoSimCard' => '当前网络环境不支持，或者手机没有绑定电话卡',
			'passport.cannotGetScreenSize' => '无法获取屏幕尺寸',
			'passport.oneKeyFailedRetry' => '一键登录失败，请检查网络后重试',
			'splash.slogan' => '畅所欲言，自在沟通',
			'talkRecord.entryTitle' => '面聊记录',
			'talkRecord.entrySubtitlePersonal' => '面对面沟通的录音与转写记录',
			'talkRecord.entrySubtitleOrg' => '会议与面谈的团队协作记录',
			'talkRecord.listTitle' => '面聊记录',
			'talkRecord.contextSectionTitle' => '当前空间',
			'talkRecord.contextPersonal' => '个人空间',
			'talkRecord.contextOrgFallback' => '当前企业',
			'talkRecord.filterAll' => '全部',
			'talkRecord.filterOwned' => '我创建',
			'talkRecord.filterShared' => '共享给我',
			'talkRecord.searchHint' => '搜索面聊记录',
			'talkRecord.untitledRecord' => '未命名记录',
			'talkRecord.visibilityOwnerOnly' => '仅自己可见',
			'talkRecord.visibilityShared' => '已共享',
			'talkRecord.localDraftBadge' => '本机草稿',
			'talkRecord.statusRecording' => '录音中',
			'talkRecord.statusUploading' => '上传中',
			'talkRecord.statusVerifying' => '上传校验中',
			'talkRecord.statusAssembling' => '音频合成中',
			'talkRecord.statusUploadFailed' => '上传失败，可重试',
			'talkRecord.statusTranscribeQueued' => '转写排队中',
			'talkRecord.statusTranscribeRunning' => '转写中',
			'talkRecord.statusTranscribeReady' => '已转写',
			'talkRecord.statusTranscribeFailed' => '转写失败，录音仍可回听',
			'talkRecord.statusNoSpeech' => '未检测到可转写语音',
			'talkRecord.statusRecordOnly' => '仅录音',
			'talkRecord.emptyNeverCreatedTitle' => '还没有面聊记录',
			'talkRecord.emptyNeverCreatedSubtitle' => '面对面沟通后，在这里保存录音与转写',
			'talkRecord.emptyNoMatchTitle' => '没有匹配的记录',
			'talkRecord.emptyNoMatchSubtitle' => '当前筛选或搜索词下没有结果，可调整后重试',
			'talkRecord.createRecord' => '新建记录',
			'talkRecord.loadFailedTitle' => '记录加载失败',
			'talkRecord.loadFailedAction' => '重试',
			'talkRecord.prepareTitle' => '新建面聊记录',
			'talkRecord.fieldTitleLabel' => '标题',
			'talkRecord.fieldTitlePlaceholder' => '选填，方便日后查找',
			'talkRecord.saveToSectionTitle' => '保存到',
			'talkRecord.saveToChangeAction' => '更改',
			'talkRecord.processingSectionTitle' => '处理方式',
			'talkRecord.processingRecordOnly' => '仅录音',
			'talkRecord.processingTranscribe' => '转写文字',
			'talkRecord.processingSummarize' => '转写并摘要',
			'talkRecord.processingRecordOnlyHint' => '仅保存录音，可随时回听；会后可在详情页升级转写。',
			'talkRecord.processingReasonUnavailable' => '当前实例未配置转写服务，本次仅保存录音。',
			'talkRecord.processingReasonQuota' => '转写配额暂不可用，本次仅保存录音；录音不受影响。',
			'talkRecord.processingReasonLoadFailed' => '未能获取处理能力，本次按仅录音处理。',
			'talkRecord.maxDurationHint' => ({required Object minutes}) => '单条录音最长 ${minutes} 分钟',
			'talkRecord.collabSectionTitle' => '协作信息',
			'talkRecord.collabSectionSubtitle' => '选填，仅对企业记录生效',
			'talkRecord.collabParticipantsLabel' => '参与者',
			'talkRecord.collabParticipantsEmpty' => '未选择参与者',
			'talkRecord.collabParticipantsCount' => ({required Object count}) => '已选 ${count} 人',
			'talkRecord.collabParticipantsUnavailable' => '参与者目录待接入；可创建记录后再授权共享。',
			'talkRecord.noticeCheckbox' => '我已告知现场参与者本次录音及其处理方式',
			'talkRecord.noticeHint' => '开始录音前需先确认已告知',
			'talkRecord.startRecording' => '开始录音',
			'talkRecord.micDeniedTitle' => '需要麦克风权限',
			'talkRecord.micDeniedMessage' => '面聊记录需要使用麦克风录制现场声音。当前权限被拒绝，可重试或在系统设置中开启。',
			'talkRecord.micRetry' => '重试',
			'talkRecord.micOpenSettings' => '去设置',
			'talkRecord.recordingUnavailableTitle' => '暂时无法开始录音',
			'talkRecord.recordingUnavailableMessage' => '请检查是否有未结束的录音、麦克风权限和本机存储空间。草稿及已有分段已保留。',
			'talkRecord.saveLocationTitle' => '保存位置',
			'talkRecord.saveLocationPersonalSection' => '个人',
			'talkRecord.saveLocationOrgSection' => '有权企业',
			'talkRecord.saveLocationWorkspaceOptional' => '不指定工作区',
			'talkRecord.retentionPolicyLabel' => '保存期限',
			'talkRecord.changeConfirmTitle' => '更改保存位置',
			'talkRecord.changeConfirmTarget' => ({required Object name}) => '将保存到：${name}',
			'talkRecord.changeConfirmKeepTitle' => '已填写的标题与笔记会保留',
			'talkRecord.changeConfirmClearParticipants' => '不适用于新位置的参与者选择将被清空',
			'talkRecord.changeConfirmRecheck' => '处理方式将按新位置的能力重新校验',
			'talkRecord.changeConfirmAction' => '确认更改',
			'talkRecord.barRecording' => '正在录音 · 本机分段保存',
			'talkRecord.barPaused' => '已暂停，不计入录音时长',
			'talkRecord.barInterrupted' => '录音已中断 · 恢复需手动继续',
			'talkRecord.barOriginPrefix' => '来自',
			'talkRecord.barExpandHint' => '查看录音状态',
			'talkRecord.barControlsUnavailable' => '录音控制由录音模块提供，当前构建为占位展示',
			'talkRecord.barOriginPersonal' => '个人空间',
			'talkRecord.barOriginOrgFallback' => '企业空间',
			'talkRecord.roleOwner' => '创建者',
			'talkRecord.roleEditor' => '编辑者',
			'talkRecord.roleViewer' => '读者',
			'talkRecord.roleEditorHint' => '你可校对原文与发言人、编辑共享笔记；分享与删除由创建者管理。',
			'talkRecord.tabSummary' => '摘要',
			'talkRecord.tabTranscript' => '原文',
			'talkRecord.speakersEntry' => '发言人校对',
			'talkRecord.playbackUnavailable' => '当前无回放权限',
			'talkRecord.playbackTicketFailed' => '播放会话不可用，可重试',
			'talkRecord.playbackPlayLabel' => '播放',
			'talkRecord.playbackPauseLabel' => '暂停',
			'talkRecord.playbackProgressLabel' => ({required Object position, required Object duration}) => '播放进度 ${position} / ${duration}',
			'talkRecord.returnToPlayback' => '回到播放位置',
			'talkRecord.transcriptSearchHint' => '搜索原文关键词',
			'talkRecord.transcriptHitCount' => ({required Object count}) => '命中 ${count} 处，点击时间点回听定位',
			'talkRecord.transcriptNoHit' => '没有命中片段',
			'talkRecord.transcriptEmpty' => '暂无原文片段',
			'talkRecord.speakerUnknown' => '未知说话人',
			'talkRecord.speakerAnonymousPill' => '匿名',
			'talkRecord.speakerManualPill' => '人工标记',
			'talkRecord.speakerSelfClaimPill' => '本人认领',
			'talkRecord.markPillPrefix' => '重点',
			'talkRecord.markDefaultText' => '手动重点',
			'talkRecord.segmentHumanEditedPill' => '人工修订',
			'talkRecord.segmentRowSemanticLabel' => ({required Object speaker, required Object time}) => '${speaker} 于 ${time} 的发言',
			'talkRecord.segmentListenLabel' => ({required Object time}) => '回听 ${time}',
			'talkRecord.detailRecordOnlyTitle' => '本次记录仅保存录音',
			'talkRecord.detailRecordOnlyBody' => '未请求转写，暂无原文与摘要；录音可回听，会后可升级转写。',
			'talkRecord.detailNoSpeechTitle' => '未检测到可转写语音',
			'talkRecord.detailNoSpeechBody' => '录音已保留。本次录音中没有可转写的语音内容。',
			'talkRecord.detailTranscribeFailedTitle' => '转写失败',
			'talkRecord.detailTranscribeFailedBodyEditor' => '转写失败，录音仍可回听。你可重试转写。',
			'talkRecord.detailTranscribeFailedBodyViewer' => '转写失败，录音仍可回听。请联系创建者重试。',
			'talkRecord.detailTranscribingTitle' => '转写处理中',
			'talkRecord.detailTranscribingBody' => '原文生成后会在此展示；处理中不显示预计完成时间。',
			'talkRecord.detailTranscribeRetry' => '重试转写',
			'talkRecord.summarySectionTitle' => '摘要',
			'talkRecord.summaryDraftBadge' => 'AI 整理草稿 · 使用前请核对',
			'talkRecord.summaryStaleBanner' => '原文或署名已更新，摘要可能过时',
			'talkRecord.summaryDecisionsTitle' => '讨论重点',
			'talkRecord.summaryActionsTitle' => '待办草稿',
			'talkRecord.summaryAssigneeUnset' => '负责人未定',
			'talkRecord.summaryJumpToSource' => '查看原文出处',
			'talkRecord.summaryQueued' => '摘要已排队，生成后展示。',
			'talkRecord.summaryRunning' => '摘要整理中，生成后展示。',
			'talkRecord.summaryNotGenerated' => '已生成原文，尚未请求摘要。',
			'talkRecord.summaryNoSource' => '尚无原文，暂不能生成摘要。',
			'talkRecord.summaryUnavailable' => '当前实例未配置摘要服务。',
			'talkRecord.summaryFailed' => '摘要生成失败，可稍后重试。',
			'talkRecord.notesTitle' => '共享补充笔记',
			'talkRecord.notesSharedHint' => '随记录共享，所有可查看本记录的人可见。',
			'talkRecord.notesReadonlyHint' => '随记录共享，当前为只读。',
			'talkRecord.notesEditAction' => '编辑',
			'talkRecord.notesPlaceholder' => '补充会议结论、背景信息等',
			'talkRecord.notesEmpty' => '暂无补充笔记',
			'talkRecord.notesCancel' => '取消',
			'talkRecord.notesSave' => '保存笔记',
			'talkRecord.notesSavedHint' => '笔记已保存',
			'talkRecord.notesConflictHint' => '笔记已被他人更新，请刷新后重试；当前输入已保留。',
			'talkRecord.notesFailedHint' => '保存失败，请稍后重试；当前输入已保留。',
			'talkRecord.moreActionsTitle' => '更多操作',
			'talkRecord.moreActionsCancel' => '取消',
			'talkRecord.actionShare' => '分享管理',
			'talkRecord.actionExport' => '导出文字',
			'talkRecord.actionDelete' => '删除记录',
			'talkRecord.actionPendingIntegration' => '该操作待后续版本接入（分享/导出/删除由对应模块联调后开放），当前构建仅提供入口。',
			'talkRecord.segmentEditTitle' => '片段校对',
			'talkRecord.segmentTimeLabel' => ({required Object time}) => '时间点 ${time}',
			'talkRecord.segmentOriginalLabel' => '原稿',
			'talkRecord.segmentEditLabel' => '校对文字',
			'talkRecord.segmentEditPlaceholder' => '修改转写文字',
			'talkRecord.segmentSave' => '保存校对',
			'talkRecord.segmentResubmit' => '重新提交',
			'talkRecord.segmentSaveFailed' => '保存失败，请稍后重试；输入已保留。',
			'talkRecord.segmentConflictTitle' => '版本冲突：原文已被他人修改',
			'talkRecord.segmentConflictBody' => '你的输入已保留，可与服务器最新稿对比后重新提交；保存以你的输入为准。',
			'talkRecord.segmentAdoptServer' => '采用服务器稿',
			'talkRecord.speakersTitle' => '发言人校对',
			'talkRecord.speakersScopeHint' => '说话人设置只作用于本记录；人工标记不等于本人认证，也不会建立声纹档案。',
			'talkRecord.speakerSetName' => '设置显示名',
			'talkRecord.speakerSetNameTitle' => '设置显示名',
			'talkRecord.speakerSetNameConfirm' => '保存',
			'talkRecord.speakerClaimSelf' => '认领是我',
			'talkRecord.speakerClaimConflict' => '该说话人已被他人认领，请创建者人工纠正。',
			'talkRecord.speakerAudition' => '试听片段',
			'talkRecord.speakerMarkColleague' => '标记同事',
			'talkRecord.speakerDirectoryUnavailable' => '参与者目录待接入，暂不能选择同事；可先设置显示名。',
			'talkRecord.speakerSourceHint' => '该署名为人工标记或本人认领，不构成身份认证。',
			'talkRecord.shareManageTitle' => '分享管理',
			'talkRecord.shareVisibilitySectionTitle' => '当前可见范围',
			'talkRecord.shareVisibilityOwnerOnly' => '仅自己可见',
			'talkRecord.shareVisibilityShared' => ({required Object count}) => '已共享给 ${count} 人查看',
			'talkRecord.shareRosterSectionTitle' => '谁可以查看',
			'talkRecord.shareOwnerRowLabel' => '我 · 创建者',
			'talkRecord.shareOwnerRowHint' => '创建者始终可以查看与管理分享',
			'talkRecord.shareGrantRoleViewer' => '可查看与回听',
			'talkRecord.shareGrantRoleEditor' => '可校对与编辑',
			'talkRecord.shareAllowExportPill' => '可导出',
			'talkRecord.shareExpiresPill' => ({required Object date}) => '有效期至 ${date}',
			'talkRecord.shareGrantEditAction' => '编辑',
			'talkRecord.shareGrantRevokeAction' => '撤销',
			'talkRecord.shareAddEntryOrg' => '添加同事',
			'talkRecord.shareAddEntryPersonal' => '添加联系人',
			'talkRecord.shareAddHintOrg' => '可授权当前企业内符合工作区权限的同事',
			'talkRecord.shareAddHintPersonal' => '可授权已有联系人',
			'talkRecord.shareEmptyTitle' => '尚未授权任何人',
			'talkRecord.shareEmptyBody' => '该记录默认仅自己可见；明确授权后，对方才能查看与回听。',
			'talkRecord.shareMyPermissionTitle' => '我的权限',
			'talkRecord.shareMyPermissionNone' => '你当前没有这条记录的授权信息；分享由创建者管理。',
			'talkRecord.shareMyPermissionReadonly' => '你可以查看与回听本记录；分享权限由创建者管理。',
			'talkRecord.shareVisibilityOfRecord' => ({required Object visibility}) => '当前记录可见范围：${visibility}',
			'talkRecord.shareEditorCannotManageAcl' => '编辑者不能管理分享权限或删除记录；如需调整，请联系创建者。',
			'talkRecord.shareSaveFeedback' => '权限已保存',
			'talkRecord.shareConflictHint' => '授权已被他人更新，请刷新后重试。',
			'talkRecord.shareSendCard' => '发送卡片',
			'talkRecord.shareCardSending' => '处理中…',
			'talkRecord.shareSendCardHint' => '生成面聊记录卡片发送给同事；对方打开时按其权限查看。',
			'talkRecord.shareSendNeedsGrant' => '先添加授权，才能发送分享卡片。',
			'talkRecord.shareCardSent' => '卡片已发送（示例）',
			'talkRecord.shareCardSendFailed' => '发送失败，可重试',
			'talkRecord.shareCardSenderUnavailable' => '暂时无法打开会话选择器，请返回后重试。',
			'talkRecord.shareRevokeConfirmTitle' => ({required Object name}) => '撤销 ${name} 的访问权限？',
			'talkRecord.shareRevokeConfirmBody' => '将无法继续访问原记录。已导出或保存的副本无法收回。',
			'talkRecord.shareRevokeConfirmAction' => '撤销',
			'talkRecord.shareRevokeFailedTitle' => '未能撤销',
			'talkRecord.shareRevokeFailedBody' => '撤销失败，请稍后重试。',
			'talkRecord.grantEditTitle' => '编辑权限',
			'talkRecord.grantEditTitleNew' => '添加授权',
			'talkRecord.grantEditCandidateSection' => '选择要授权的人',
			'talkRecord.grantEditCandidateSearchHint' => '搜索姓名或账号',
			'talkRecord.grantEditCandidatesUnavailable' => '候选目录暂不可用，请稍后重试。',
			'talkRecord.grantEditCandidateEmpty' => '没有可授权的候选人',
			'talkRecord.grantEditGranteeLabel' => '被授权人',
			'talkRecord.grantEditRoleSectionTitle' => '角色',
			'talkRecord.grantEditRoleViewerHint' => '可查看记录与回听音频，不能修改内容。',
			'talkRecord.grantEditRoleEditorHint' => '可校对原文与发言人、编辑共享笔记；不能管理分享或删除。',
			'talkRecord.grantEditExportSectionTitle' => '允许导出',
			'talkRecord.grantEditExportBlockedOrg' => '导出已被企业策略禁用，不能在授权中开启。',
			'talkRecord.grantEditExportBlockedUnknown' => '未能确认当前导出策略，暂不能开启导出。',
			'talkRecord.grantEditExpiresSectionTitle' => '到期时间',
			'talkRecord.grantEditExpiresOn' => ({required Object date}) => '${date} 到期',
			'talkRecord.grantEditExpiresHint' => '可选；设置后对方到期自动失去访问。',
			'talkRecord.grantEditSave' => '保存权限',
			'talkRecord.grantEditSaving' => '处理中…',
			'talkRecord.grantEditConflict' => '授权已被他人更新，请返回刷新名单后重试；你的设置已保留。',
			'talkRecord.grantEditSaveFailed' => '保存失败，请稍后重试；你的设置已保留。',
			'talkRecord.invalidTitle' => '暂时无法查看',
			'talkRecord.invalidBody' => '该内容当前无法查看，可能不存在或你没有查看权限。',
			'talkRecord.invalidBack' => '返回',
			'talkRecord.resultBack' => '返回',
			'talkRecord.exportTitle' => '导出文字',
			'talkRecord.exportFormatSectionTitle' => '导出格式',
			'talkRecord.exportFormatTxt' => '纯文本 .txt',
			'talkRecord.exportFormatMd' => 'Markdown .md',
			'talkRecord.exportFormatHint' => '导出仅包含文字内容，不包含音频与未授权参与者信息。',
			'talkRecord.exportCapabilitySectionTitle' => '导出能力',
			'talkRecord.exportBlockedNoGrant' => '你当前的角色没有被授予导出权限；导出需创建者授权或策略允许。',
			'talkRecord.exportBlockedOrgPolicy' => '导出已被企业策略禁用，暂不能导出。',
			'talkRecord.exportBlockedInstancePolicy' => '当前实例未开启导出能力，暂不能导出。',
			'talkRecord.exportBlockedUnknown' => '未能确认当前导出策略，暂不能导出。',
			'talkRecord.exportIndependentCopyTitle' => '独立副本提示',
			'talkRecord.exportIndependentCopyBody' => '导出生成的是独立副本；生成后无法通过删除记录或撤销权限收回。',
			'talkRecord.exportIndependentCopyAck' => '我已了解导出的独立副本无法收回',
			'talkRecord.exportGenerate' => '生成导出',
			'talkRecord.exportGenerating' => '生成中…',
			'talkRecord.exportQueuedTitle' => '导出排队中',
			'talkRecord.exportQueuedBody' => '已提交生成请求；排队不代表已生成完成，可稍后刷新状态。',
			'talkRecord.exportRefreshState' => '刷新状态',
			'talkRecord.exportReadyTitle' => '导出已就绪',
			'talkRecord.exportReadyBody' => '可下载导出文件；下载链接短期有效，到期后需重新生成。',
			'talkRecord.exportExpiresAt' => ({required Object date}) => '有效期至 ${date}',
			'talkRecord.exportRemaining' => ({required Object minutes}) => '剩余约 ${minutes} 分钟',
			'talkRecord.exportDownload' => '保存导出文件',
			'talkRecord.exportDownloading' => '正在下载并准备保存…',
			'talkRecord.exportDownloadReady' => '文件已保存；这是独立副本，撤销权限不会删除该副本。',
			'talkRecord.exportDownloadFailed' => '下载或保存失败，可重试',
			'talkRecord.exportExpiredTitle' => '导出已到期',
			'talkRecord.exportExpiredBody' => '下载链接已过期，请重新生成导出。',
			'talkRecord.exportRegenerate' => '重新生成',
			'talkRecord.exportFailedBody' => '生成导出失败，可重试。',
			'talkRecord.exportConflictHint' => '记录已被他人更新，请刷新后重试。',
			'talkRecord.exportFixtureHint' => '组件阶段：下载链接为 fixture 示例，不产生真实文件。',
			'talkRecord.transferTitle' => '移交管理责任',
			'talkRecord.transferScopeHint' => '移交仅变更管理责任人；记录归属（企业与工作区）保持不变。',
			'talkRecord.transferCreatedByHint' => '创建者记录保持不变；此动作与分享权限相互独立。',
			'talkRecord.transferCandidateSectionTitle' => '选择新责任人',
			'talkRecord.transferCandidateEmpty' => '没有符合条件的候选同事',
			'talkRecord.transferCandidateHint' => '候选为当前企业内符合工作区权限的同事；最终资格由服务端裁决。',
			'talkRecord.transferKeepSectionTitle' => '原责任人访问',
			'talkRecord.transferKeepViewer' => '移交后保留我的查看权限',
			'talkRecord.transferKeepDefaultHint' => '默认不保留：移交后你将无法继续访问这条记录。',
			'talkRecord.transferKeepOnHint' => '保留后你仍可查看与回听，但分享与删除由新责任人管理。',
			'talkRecord.transferSubmit' => '移交管理责任',
			'talkRecord.transferSubmitting' => '移交中…',
			'talkRecord.transferConfirmTitle' => '确认移交管理责任？',
			'talkRecord.transferConfirmTarget' => ({required Object name}) => '将把管理责任移交给：${name}',
			'talkRecord.transferConfirmKeepOff' => '移交后你将不再保留查看权限，也无法再管理这条记录。',
			'talkRecord.transferConfirmKeepOn' => '移交后你保留查看权限，但管理权归新责任人。',
			'talkRecord.transferConfirmAction' => '确认移交',
			'talkRecord.transferSuccessTitle' => '管理责任已移交',
			'talkRecord.transferSuccessOwner' => ({required Object name}) => '新责任人：${name}',
			'talkRecord.transferSuccessKeptAccess' => '你仍保留查看权限；分享管理由新责任人负责。',
			'talkRecord.transferSuccessScopeUnchanged' => '记录归属保持不变（企业与工作区不变）。',
			'talkRecord.transferFailedBody' => '移交失败，请稍后重试。',
			'talkRecord.transferConflictHint' => '记录已被他人更新，请刷新后重试。',
			'talkRecord.transferPersonalUnsupported' => '个人记录暂不支持移交管理责任。',
			'talkRecord.transferOnlyOwner' => '只有当前管理责任人可以移交管理责任。',
			'talkRecord.transferBackToDetail' => '返回详情',
			'talkRecord.deleteTitle' => '删除记录',
			'talkRecord.deleteConfirmTitle' => '确认删除这条记录？',
			'talkRecord.deleteConfirmDialogContent' => '删除后不再展示正文；已导出或保存的副本无法收回。',
			'talkRecord.deleteConfirmBodyPoint1' => '删除后不再展示记录正文与摘要。',
			'talkRecord.deleteConfirmBodyPoint2' => '删除会先撤销所有人的访问；已导出或保存的副本无法收回。',
			'talkRecord.deleteConfirmBodyPoint3' => '附件按留存规则与引用情况清理；提交清理不代表字节已立即删除。',
			'talkRecord.deleteConfirmAction' => '删除',
			'talkRecord.deleteDeleting' => '删除中…',
			'talkRecord.deleteOnlyOwner' => '只有创建者可以删除记录。',
			'talkRecord.deleteFailedBody' => '删除失败，请稍后重试。',
			'talkRecord.deleteConflictHint' => '记录已被他人更新，请刷新后重试。',
			'talkRecord.deleteStatusTitle' => '记录已删除',
			'talkRecord.deleteStatusNoContentHint' => '记录内容已不再展示。',
			'talkRecord.deleteCleanupSectionTitle' => '附件清理状态',
			'talkRecord.cleanupPendingTitle' => '清理进行中',
			'talkRecord.cleanupPendingBody' => '已提交清理队列；排队成功不代表附件字节已删除。',
			'talkRecord.cleanupBlockedRetentionTitle' => '留存期未到',
			'talkRecord.cleanupBlockedRetentionBody' => '记录已删除，附件受留存规则保护；留存期结束后继续清理。',
			'talkRecord.cleanupBlockedHoldTitle' => '受 Hold 保护',
			'talkRecord.cleanupBlockedHoldBody' => '记录已删除，附件受合法保留（Hold）保护；Hold 解除后继续清理。',
			'talkRecord.cleanupRetainedTitle' => '附件仍被其他业务引用',
			'talkRecord.cleanupRetainedBody' => '部分附件仍被其他合法业务引用，暂不物理删除。',
			'talkRecord.cleanupFailedTitle' => '清理失败',
			'talkRecord.cleanupFailedBody' => '附件清理未完成。请刷新查看状态；符合条件时可重试清理。',
			'talkRecord.cleanupCompleteTitle' => '清理完成',
			'talkRecord.cleanupCompleteBody' => '记录与附件均已清理完成。',
			'talkRecord.cleanupNoneTitle' => '未提交清理',
			_ => null,
		} ?? switch (path) {
			'talkRecord.cleanupNoneBody' => '记录尚未进入清理流程。',
			'talkRecord.cleanupUnknownTitle' => '清理状态未知',
			'talkRecord.cleanupUnknownBody' => '暂未能获取清理状态，可刷新重试。',
			'talkRecord.cleanupRetryAction' => '重试清理',
			'talkRecord.cleanupRetrying' => '重试中…',
			'talkRecord.cleanupRetryFailedBody' => '重试清理失败，请稍后再次重试。',
			'talkRecord.deleteRefreshStatus' => '刷新清理状态',
			'talkRecord.deleteBackToList' => '返回列表',
			'talkRecord.deleteStatusFixtureHint' => '组件阶段：清理状态来自 fixture 示例，真实清理进度待联调。',
			'talkRecord.microphoneStopUnconfirmed' => '录音停止尚未确认，请重试停止；若仍失败，请关闭应用并检查系统麦克风指示。',
			'talkRecord.cleanupWriteOutcomeUnknown' => '附件写入结果尚未确认，清理暂未完成。系统会保留保护状态，由运维人员核查；可刷新查看进度。',
			'talkRecord.exportDownloadCancelled' => '已取消保存，可再次保存。',
			'talkRecord.shareCardSendPending' => '已加入发送队列，尚未收到服务端确认；请在会话中查看，重试不会重复创建消息。',
			'talkRecord.shareCardSendCancelled' => '已取消发送，未发送新的卡片。',
			'talkRecord.participantsInfoHint' => '参与者仅用于记录实际参加人员，不会自动共享记录，也不代表已核实发言人。',
			'talkRecord.participantsRemove' => '移除参与者',
			'talkRecord.participantsGuestLabel' => '来宾姓名或标签',
			'talkRecord.participantsAddGuest' => '添加来宾',
			'talkRecord.participantsInvalid' => '请选择最多100人；来宾标签须为1–120字且不重复。人员资格可能已变更，请检查名单。',
			'talkRecord.participantsNoResults' => '没有匹配的联系人或同事，请尝试搜索。',
			'talkRecord.participantsConflict' => '名单已更新，已刷新为最新内容。请检查后重新编辑。',
			'talkRecord.participantsSaveFailed' => '未能确认保存结果，当前选择已保留；请重试或刷新。',
			'talkRecord.cleanupProcessorUnconfirmed' => '处理任务仍在停止或核查，尚未确认临时音频副本已清理。请刷新查看进度。',
			'talkRecord.uploadNoticeTitle' => '上传前确认',
			'talkRecord.uploadNoticeHint' => '请确认当前录音告知。本次确认用于现在上传；不会改写录音开始时的历史确认，也不会更改保存空间。',
			'talkRecord.uploadRecording' => '上传录音',
			'talkRecord.retryRecordingUpload' => '重试上传',
			'talkRecord.notificationRequiredTitle' => '开启录音通知',
			'talkRecord.notificationRequiredMessage' => '为保持后台录音可见，请允许应用通知，并在系统设置中开启录音通知通道。开启后返回此页重试；本次尚未开始录音。',
			'talkRecord.openNotificationSettings' => '去通知设置',
			'talkRecord.processingRecoveryTitle' => '确认录音处理',
			'talkRecord.processingRecoveryHint' => '处理告知或处理器配置已更新。确认后按下方当前版本上传并执行原先选择的处理方式；不改变录音时的历史告知。',
			'talkRecord.processingRecoveryUnavailable' => '当前处理器不可用。录音将保留在本机，恢复后可再次上传。',
			'talkRecord.keepRecordingLocal' => '暂不处理，保留本机',
			'talkRecord.confirmProcessingUpload' => '同意处理并上传',
			'talkRecord.cleanupRetryRefreshFailed' => '未能读取最新状态，请刷新核对。',
			'talkRecord.cleanupRetryAccepted' => '已提交重试，正在读取最新清理状态；排队不代表附件已删除。',
			'talkRecord.cleanupRetryUnknown' => '提交结果尚未确认。请先刷新核对；再次提交会复用同一请求。',
			'talkRecord.cleanupRetryPartial' => '仅重试已耗尽且允许清理的附件；仍受保护的附件会继续保留。',
			'talkRecord.cleanupRetryProtected' => '附件仍受保全、留存或其他有效引用保护，无法强制清理。',
			'talkRecord.cleanupRetryWaiting' => '尚未达到可重试条件。上传能力或其他引用失效后，请刷新状态。',
			'talkRecord.cleanupRetryUnavailable' => '暂无法确认清理重试权限，请刷新状态。',
			'talkRecord.cleanupRetryReconcile' => '核对同一重试请求',
			'talkRecord.uploadProgressRegister' => '准备上传',
			'talkRecord.uploadProgressUpload' => '上传音频',
			'talkRecord.uploadProgressConfirm' => '确认音频',
			'talkRecord.uploadProgressSubmitting' => '提交保存',
			'talkRecord.uploadProgressCompleted' => '已提交，等待音频处理',
			'talkRecord.uploadProgressFailed' => '上传未完成，可重试',
			'talkRecord.uploadProgressParts' => ({required Object confirmed, required Object total}) => '已确认 ${confirmed}/${total} 段',
			'talkRecord.aiServicesTitle' => 'AI 服务',
			'talkRecord.aiServicesSubtitle' => '使用你自己的 API 账户，费用由供应商收取。',
			'talkRecord.aiMinimaxTitle' => 'MiniMax',
			'talkRecord.aiZhipuTitle' => '智谱 GLM-5.3-Flash',
			'talkRecord.aiMinimaxPurpose' => '音频转文字与临时说话人标签',
			'talkRecord.aiZhipuPurpose' => '摘要草稿、决定与行动项',
			'talkRecord.aiConfigured' => '本设备已配置',
			'talkRecord.aiNotConfigured' => '未配置',
			'talkRecord.aiLoading' => '正在读取本设备配置…',
			'talkRecord.aiDeviceOnlyNotice' => 'Key 仅加密保存在当前账号的本设备，不上传 IMBoy、不参与云备份或换机迁移。换设备需要重新填写。',
			'talkRecord.aiEnterprisePolicyNotice' => '配置 Key 不代表已授权外发。企业记录仍需企业策略允许，发送前还需本次处理同意。',
			'talkRecord.aiMaxNotice' => '使用智谱开放平台通用 API，另行计费。Coding Plan 年度 Max 套餐不能默认抵扣此处费用；转写文本会发送至智谱。',
			'talkRecord.aiAudioExternalNotice' => '转写时音频会发送至 MiniMax，并可能产生费用。单次音频不超过 500 秒且不超过 50 MB，由处理流程检查和分块。',
			'talkRecord.aiValidationNotice' => '保存不会验证 Key，也不会发送音频或文本。真实验证可能计费，需另行确认后进行。',
			'talkRecord.aiAccountChanged' => '账号或部署已变化，请返回后重新进入。本页输入已清空。',
			'talkRecord.aiCredentialChanged' => '本设备配置已变化或尚未完成，请重新填写并保存，或返回后重试。',
			'talkRecord.aiInvalidKey' => 'Key 格式不正确：请输入 16～4096 个非空白 ASCII 字符，不包含换行或控制字符。',
			'talkRecord.aiStorageFailed' => '无法读写本设备安全存储，配置尚未确认。请重试；不会改用明文保存。',
			'talkRecord.aiUnsupportedPlatform' => '当前平台尚未验证本设备安全存储，暂不支持保存 Key。',
			'talkRecord.aiKeyPlaceholder' => '输入 API Key',
			'talkRecord.aiReplacePlaceholder' => '输入新的 API Key，不回填已有密钥',
			'talkRecord.aiSaveAction' => '保存在本设备',
			'talkRecord.aiReplaceAction' => '替换本设备密钥',
			'talkRecord.aiDeleteAction' => '删除本设备密钥',
			'talkRecord.aiSaving' => '正在保存…',
			'talkRecord.aiSaved' => '已保存在本设备，尚未验证 Key。',
			'talkRecord.aiDeleted' => '已删除本设备配置，录音与已有结果保留。',
			'talkRecord.aiReplaceTitle' => '替换本设备密钥？',
			'talkRecord.aiReplaceNotice' => '仅替换当前账号在本设备的该服务配置，不影响其他账号或已保存记录。',
			'talkRecord.aiDeleteTitle' => '删除本设备密钥？',
			'talkRecord.aiDeleteNotice' => '停止该服务的新请求。已有录音和结果保留；已发给供应商的请求无法撤回。',
			'talkRecord.aiCancel' => '取消',
			'talkRecord.aiProcessingConsent' => 'App 仅在前台继续提交和查询。供应商受理后可能在离开 App 后继续处理并计费。每步重验权限和本次同意。已有供应商任务 ID 时只查询；无 ID 且结果未知时停止，不自动重新提交。本机提示不能保证账户费用上限。',
			'talkRecord.aiProcessTranscribe' => '本设备转写 / 继续',
			'talkRecord.aiProcessSummarize' => '本设备整理摘要 / 继续',
			'talkRecord.aiProcessingRunning' => '正在本设备处理，请保持此页打开。',
			'talkRecord.aiProcessingComplete' => '处理结果已提交，请核对原文与摘要草稿。',
			'talkRecord.aiProcessingKeyInvalid' => '供应商拒绝 Key。请在设置 → AI 服务核对本设备配置；已停止，不自动重发。',
			'talkRecord.aiProcessingBalance' => '供应商余额不足。已保留进度并停止，不自动重发。',
			'talkRecord.aiProcessingUnknown' => '供应商结果未知，可能已计费。已停止外发；需人工核对费用与原执行，不能直接重发。',
			'talkRecord.aiProcessingStopped' => '处理已停止，录音保留。请核对本设备 Key、权限、配置和输入；若已外发但结果未确认，不会自动重复调用。',
			'talkRecord.aiDoubaoTitle' => '豆包语音 2.0',
			'talkRecord.aiDoubaoPurpose' => '录音转写与临时说话人标签',
			'talkRecord.aiDoubaoExternalNotice' => '转写时音频会发送至火山引擎豆包语音，费用由供应商收取。仅配置本设备 API Key；不会沿用 MiniMax 密钥。',
			'talkRecord.aiDoubaoPendingNotice' => '豆包转写流程尚未接通，目前仅可保存设备配置。保存不代表连接已验证或可以开始转写。',
			'talkRecord.aiProviderPending' => '供应商仍在处理，进度已保存。稍后点击继续查询，不会重新提交录音。',
			'talkRecord.aiProviderCancel' => '停止此转写',
			'talkRecord.aiProviderCancelNotice' => '停止后将撤销 IMBoy 的来源与操作授权；不能保证供应商停止处理或退款。',
			'talkRecord.aiProviderResubmit' => '重新提交录音',
			'talkRecord.aiProviderResubmitNotice' => '此操作会新建一次转写，可能重复计费。原请求不会被替换。确认重新提交并同意本次处理？',
			'talkRecord.aiProviderCancelled' => '本次转写已停止，已有录音保留。',
			'talkRecord.aiProviderResumePreparation' => '继续准备转写',
			'talkRecord.aiProviderResumeNotice' => '原任务尚未向供应商提交。本次将重新准备音频来源；确认后按当前权限和处理同意继续。',
			'talkRecord.aiAsrProvider' => '转写服务',
			'talkRecord.aiAsrOptionalNotice' => 'AI 转写为可选功能，目前可使用已配置的 MiniMax。仅录音无需任何 AI Key。',
			'talkRecord.aiUnknownRecoveryTitle' => '核对未知执行并重新请求',
			'talkRecord.aiUnknownRecoveryNotice' => '无法核实下列旧请求的结果与费用，可能已经扣费。确认后为同一任务创建新执行，仅重新请求未确认块，可能重复扣费；旧未知事实与结果会保留。取消不会发送恢复请求。',
			'talkRecord.aiUnknownRecoveryRun' => '原执行',
			'talkRecord.aiUnknownRecoveryIntents' => '块序号 / 未知请求编号',
			'talkRecord.aiUnknownRecoveryConfirm' => '已核对，接受可能重复扣费',
			'welcome.step1Title' => '简单连接',
			'welcome.step1Desc' => '体验无缝沟通的乐趣。 随时随地，畅所欲言。',
			'welcome.step2Title' => '安全私密',
			'welcome.step2Desc' => '端到端加密 保护你的个人时刻只属于你自己。',
			'welcome.step3Title' => '准备探索？',
			'welcome.step3Desc' => '加入一个充满活力的社区。 让对话开始吧！',
			'welcome.next' => '下一步',
			'welcome.getStarted' => '开始使用',
			'welcome.skip' => '跳过',
			'workspace.navOverview' => '概览',
			'workspace.navProjects' => '项目',
			'workspace.navChannels' => '频道',
			'workspace.navGroups' => '群组',
			'workspace.pickerTitle' => '我的工作区',
			'workspace.switchWorkspace' => '切换工作区',
			'workspace.pickerEmptyTitle' => '还没有工作区',
			'workspace.pickerEmptySubtitle' => '创建一个工作区，3 分钟开启团队协作（自动创建 Announcements 频道与 General 群）',
			'workspace.archivedBadge' => '已归档',
			'workspace.emptyNoWorkspace' => '请先选择或创建一个工作区',
			'workspace.tabSchedule' => '日程',
			'workspace.tabTodo' => '待办',
			'workspace.comingSoon' => '即将上线',
			'workspace.assistantEntry' => '智能助理',
			'workspace.orgUnverified' => '未认证',
			'workspace.myCard' => '我的名片',
			'workspace.advancedFeatures' => '高级功能',
			'workspace.createOrJoinEnterprise' => '创建 / 加入企业',
			'workspace.filterUnread' => '未读',
			'workspace.filterMentions' => '@我',
			'workspace.filterDm' => '单聊',
			'workspace.filterInternalChat' => '内部聊天',
			'workspace.filterExternalChat' => '外部聊天',
			'workspace.filterFlagged' => '标记',
			'workspace.filterEdit' => '编辑',
			'workspace.filterEmptyTitle' => '暂无符合条件的会话',
			'workspace.filterUnreadEmptyTitle' => '暂无未读会话',
			'workspace.todoEmptyTitle' => '暂无待办',
			'workspace.featureComingSoon' => '功能开发中',
			'workspace.recordFaceChat' => '记录面聊',
			'workspace.smartSummary' => '智能总结',
			'workspace.takeABreak' => '休息一下',
			'workspace.experienceModePersonal' => '个人',
			'workspace.switchToPersonal' => '切换到个人',
			'workspace.createTitle' => '创建工作区',
			'workspace.createDesc' => '一次创建，自动完成：工作区、你（Owner 工作区成员身份）、Announcements 频道与 General 群。全部成功或全部回滚。',
			'workspace.createNameLabel' => '工作区名称',
			'workspace.createNameHint' => '例如：官网改版项目组',
			'workspace.createNameRequired' => '工作区名称不能为空',
			'workspace.createSubmit' => '创建',
			'workspace.createEntry' => '创建工作区',
			'workspace.createSuccess' => '工作区创建成功',
			'workspace.createIdempotentHit' => '已存在同名工作区，直接进入',
			'workspace.createTemplateTitle' => '将自动初始化',
			'workspace.createTemplateChannel' => 'Announcements 频道（你成为频道发布者与订阅者）',
			'workspace.createTemplateGroup' => 'General 群（你成为群成员）',
			'workspace.createTemplateOwner' => '你成为工作区 Owner（工作区成员）',
			'workspace.overviewTitle' => '概览',
			'workspace.overviewResources' => '资源摘要',
			'workspace.overviewPinnedContent' => '频道置顶内容',
			'workspace.overviewPinnedEmpty' => '频道暂无置顶内容；群公告不在此聚合（群公告属于各个群）',
			'workspace.overviewRecentFiles' => '最近文件',
			'workspace.overviewRecentFilesEmpty' => '最近上传的文件将在此展示；也可在各频道内查看附件',
			'workspace.membersTitle' => '工作区成员',
			'workspace.membersCountLabel' => ({required Object count}) => '${count} 位成员',
			'workspace.membersEmpty' => '暂无工作区成员',
			'workspace.membersEmptySubtitle' => '邀请已注册用户成为工作区成员（Owner / Member / Guest）',
			'workspace.membersViewAll' => '查看全部',
			'workspace.projectsEmptyTitle' => '还没有项目',
			'workspace.projectsEmptySubtitle' => '项目用于跟踪明确的交付目标；只有频道和群的社区型工作区同样成立',
			'workspace.channelsEmptyTitle' => '还没有工作区频道',
			'workspace.channelsEmptySubtitle' => '频道用于持续发布内容（公告/资料），讨论请去群组',
			'workspace.channelTileSubtitle' => ({required Object count}) => '${count} 位订阅者',
			'workspace.channelDetailTitle' => '频道',
			'workspace.groupsEmptyTitle' => '还没有工作区群组',
			'workspace.groupsEmptySubtitle' => '群组是工作区里的实时讨论空间（聊天唯一入口）',
			'workspace.groupTileSubtitle' => ({required Object count}) => '${count} 位群成员',
			'workspace.inviteTitle' => '邀请工作区成员',
			'workspace.inviteDesc' => '仅支持邀请已注册用户；加入工作区不自动入群或订阅频道——可同时加入 General 群，并发送 Announcements 频道邀请',
			'workspace.inviteSearchHint' => '按用户名 / 用户 ID 搜索',
			'workspace.inviteEntry' => '邀请工作区成员',
			'workspace.inviteJoinGroupOption' => '同时加入 General 群（成为群成员）',
			'workspace.inviteSubscribeChannelOption' => '同时发送 Announcements 频道邀请',
			'workspace.inviteOptionUnavailable' => '未找到对应资源，该选项不可用',
			'workspace.inviteSubmit' => '发送邀请',
			'workspace.inviteResultsTitle' => '结果（三条独立）',
			'workspace.inviteResultWorkspace' => '加入工作区（成为工作区成员）',
			'workspace.inviteResultGroup' => '加入 General 群（成为群成员）',
			'workspace.inviteResultChannel' => '发送 Announcements 频道邀请（对方接受后成为订阅者）',
			'workspace.resultIdle' => '未执行',
			'workspace.resultRunning' => '进行中',
			'workspace.resultSuccess' => '成功',
			'workspace.resultFailed' => '失败',
			'workspace.joinEntry' => '加入工作区',
			'workspace.joinByTeamCode' => '用团队码加入工作区',
			'workspace.joinTitle' => '加入工作区',
			'workspace.joinDesc' => '输入团队码即可加入工作区',
			'workspace.joinCodeLabel' => '团队码',
			'workspace.joinCodeHint' => '8 位大写字母或数字',
			'workspace.joinSubmit' => '加入',
			'workspace.joinSuccess' => ({required Object name}) => '已加入「${name}」',
			'workspace.joinAlreadyMember' => '你已在该工作区中',
			'workspace.joinInvalidCode' => '团队码无效或已失效',
			'workspace.joinExpiredCode' => '团队码已过期',
			'workspace.inviteCodeSectionTitle' => '团队码邀请',
			'workspace.inviteCodeGenerate' => '生成团队码',
			'workspace.inviteCodeCopy' => '复制',
			'workspace.inviteCodeRevoke' => '撤销',
			'workspace.inviteCodeExpiresAt' => ({required Object expiresAt}) => '有效期至 ${expiresAt}',
			'workspace.roleOwner' => 'Owner',
			'workspace.roleMember' => 'Member',
			'workspace.roleGuest' => 'Guest',
			'workspace.removeMemberTitle' => ({required Object name}) => '移除工作区成员 ${name}',
			'workspace.removeMemberDesc' => '移除后其工作区访问即失效；若其仍有未完成任务或负责的项目，服务端会返回冲突清单并取消本次移除',
			'workspace.removeMemberConfirm' => '确认移除',
			'workspace.changeRoleTitle' => ({required Object name}) => '修改 ${name} 的工作区角色',
			'workspace.transferTitle' => ({required Object name}) => '转移主 Owner 给 ${name}',
			'workspace.transferDesc' => '转移后你成为普通工作区成员（Member），对方获得全部治理权',
			'workspace.transferConfirm' => '确认转移',
			'workspace.governanceTitle' => '工作区治理',
			'workspace.brandingEntry' => '品牌设置（名称 / Logo / 主色）',
			'workspace.archiveEntry' => '归档工作区',
			'workspace.restoreEntry' => '恢复工作区',
			'workspace.archiveTitle' => '归档工作区',
			'workspace.archiveDesc' => '归档后全员只读（写操作被服务端拒绝），可随时恢复',
			'workspace.archiveConfirm' => '确认归档',
			'workspace.restoreTitle' => '恢复工作区',
			'workspace.restoreDesc' => '恢复后工作区恢复读写',
			'workspace.restoreConfirm' => '确认恢复',
			'workspace.archivedBanner' => '工作区已归档：内容可查看，写操作已禁用；Owner 可在成员页恢复',
			'workspace.brandingTitle' => '工作区品牌',
			'workspace.brandingNameLabel' => '品牌名称',
			'workspace.brandingLogoLabel' => 'Logo 地址',
			'workspace.brandingLogoHint' => 'https://...（工作区 Logo 图片地址）',
			'workspace.brandingColorLabel' => '主色 primaryColor',
			'workspace.brandingColorHint' => '#2474E5',
			'workspace.brandingColorHelper' => '仅支持 #RRGGBB / #AARRGGBB；非法值回落默认主题色',
			'workspace.brandingColorInvalid' => '主色格式不正确，仅支持 #RRGGBB / #AARRGGBB',
			'workspace.brandingSaved' => '品牌设置已保存',
			'workspace.brandingPreview' => '主色预览',
			'workspace.brandingPreviewApplied' => '当前主色将在工作区内生效',
			'workspace.brandingPreviewFallback' => '未设置或非法值，使用默认主题色',
			'workspace.projectCreateEntry' => '新建项目',
			'workspace.projectCreateTitle' => '新建项目',
			'workspace.projectNameLabel' => '项目名称',
			'workspace.projectNameHint' => '例如：官网改版',
			'workspace.projectNameRequired' => '项目名称不能为空',
			'workspace.projectDescLabel' => '项目描述（可选）',
			'workspace.projectDescHint' => '这个项目要交付什么？',
			'workspace.projectSubmit' => '创建',
			'workspace.projectCreateSuccess' => '项目创建成功',
			'workspace.projectDetailTitle' => '项目详情',
			'workspace.projectOwnerLabel' => '负责人',
			'workspace.projectStatusLabel' => '状态',
			'workspace.projectStatusActive' => '进行中',
			'workspace.projectStatusDone' => '已完成',
			'workspace.projectMarkDone' => '标记为已完成',
			'workspace.projectReopen' => '重新开启项目',
			'workspace.projectStatusChanged' => '项目状态已更新',
			'workspace.projectTasksSection' => '任务',
			'workspace.taskNewEntry' => '新建任务',
			'workspace.taskFormCreateTitle' => '新建任务',
			'workspace.taskFormEditTitle' => '编辑任务',
			'workspace.taskTitleLabel' => '任务标题',
			'workspace.taskTitleRequired' => '任务标题不能为空',
			'workspace.taskAssigneeLabel' => '负责人（工作区成员）',
			'workspace.taskAssigneeNone' => '暂不指派',
			'workspace.taskAssigneeRefresh' => '刷新负责人候选',
			'workspace.taskSubmitCreate' => '创建任务',
			'workspace.taskSubmitSave' => '保存',
			'workspace.taskCreatedToast' => '任务已创建',
			'workspace.taskExistingToast' => '相同标题的任务已存在，直接使用既有任务',
			'workspace.taskUpdatedToast' => '任务已保存',
			'workspace.taskFilterAll' => '全部',
			'workspace.taskStatusTodo' => '待办',
			'workspace.taskStatusDoing' => '进行中',
			'workspace.taskStatusReview' => '评审中',
			'workspace.taskStatusDone' => '已完成',
			'workspace.taskAdvanceTo' => ({required Object status}) => '推进到「${status}」',
			'workspace.taskFallbackMenuTitle' => ({required Object title}) => '回退 ${title} 到...',
			'workspace.taskStatusMovedToast' => ({required Object status}) => '已流转到「${status}」',
			'workspace.taskEmptyTitle' => '还没有任务',
			'workspace.taskEmptySubtitle' => '用四态跟踪执行：待办 → 进行中 → 评审中 → 已完成',
			'workspace.projectsLoadMore' => '加载更多',
			'workspace.projectW2SectionTitle' => '项目协作',
			'workspace.projectMembersEntry' => '成员',
			'workspace.projectMilestonesEntry' => '里程碑',
			'workspace.projectChannelsEntry' => '项目频道',
			'workspace.projectInsightsEntry' => '内容聚合',
			'workspace.projectNoPermission' => '无权限：仅项目成员、项目负责人或工作区 Owner 可查看',
			'workspace.projectGuestReadonly' => '访客（Guest）身份对项目只读',
			'workspace.projectLoadMore' => '加载更多',
			'workspace.projectMembersTitle' => '项目成员',
			'workspace.projectMemberEmptyTitle' => '还没有项目成员',
			'workspace.projectMemberEmptySubtitle' => '项目负责人可邀请已注册用户加入此项目',
			'workspace.projectMemberInviteTitle' => '邀请项目成员',
			'workspace.projectMemberInviteFieldHint' => '要邀请的已注册用户 ID',
			'workspace.projectMemberInviteInvalidUid' => '请输入有效的用户 ID',
			'workspace.projectMemberInviteSubmit' => '邀请',
			'workspace.projectMemberInviteSuccess' => '已加入项目成员',
			'workspace.projectMemberInviteExisting' => '该用户已是项目成员',
			'workspace.projectMemberRemoveConfirmTitle' => ({required Object name}) => '移除项目成员 ${name}',
			'workspace.projectMemberRemoveConfirmDesc' => '移除后该用户将失去此项目内容的访问（可重新邀请）',
			'workspace.projectMemberRemoveSubmit' => '移除',
			'workspace.projectMemberRemovedToast' => '已移除',
			'workspace.projectMemberAlreadyRemovedToast' => '该用户已不在项目成员中',
			'workspace.projectMemberTransferTitle' => ({required Object name}) => '转移项目负责人给 ${name}',
			'workspace.projectMemberTransferDesc' => '转移后对方获得此项目的完全管理权',
			'workspace.projectMemberTransferConfirm' => '确认转移',
			'workspace.projectMemberTransferDoneToast' => '项目负责人已转移',
			'workspace.projectMilestonesTitle' => '里程碑',
			'workspace.projectMilestoneEmptyTitle' => '还没有里程碑',
			'workspace.projectMilestoneEmptySubtitle' => '用里程碑标记项目的关键节点（计划中 → 已达成，单向）',
			'workspace.projectMilestoneCreateTitle' => '新建里程碑',
			'workspace.projectMilestoneNameLabel' => '名称',
			'workspace.projectMilestoneNameRequired' => '里程碑名称不能为空',
			'workspace.projectMilestoneDueDateLabel' => '截止日期（YYYY-MM-DD，可选）',
			'workspace.projectMilestoneDueDateInvalid' => '日期格式应为 YYYY-MM-DD',
			'workspace.projectMilestoneCreateSubmit' => '创建',
			'workspace.projectMilestoneCreatedToast' => '里程碑已创建',
			'workspace.projectMilestoneFilterAll' => '全部',
			'workspace.projectMilestoneFilterPlanned' => '计划中',
			'workspace.projectMilestoneFilterReached' => '已达成',
			'workspace.projectMilestoneReach' => '标记达成',
			'workspace.projectMilestoneReachedToast' => '里程碑已达成',
			'workspace.projectMilestoneAlreadyReachedToast' => '该里程碑已达成',
			'workspace.projectMilestoneReachedHint' => '已达成（不可回退）',
			'workspace.projectMilestoneDueLabel' => '截止',
			'workspace.projectChannelsTitle' => '项目频道',
			'workspace.projectChannelEmptyTitle' => '还没有关联频道',
			'workspace.projectChannelEmptySubtitle' => '关联工作区频道后，其置顶内容与最近帖子会聚合进本项目',
			'workspace.projectChannelLinkTitle' => '选择要关联的频道',
			'workspace.projectChannelNoCandidate' => '没有可关联的候选频道',
			'workspace.projectChannelLinkedToast' => '频道已关联',
			'workspace.projectChannelLinkExistingToast' => '该频道已关联',
			'workspace.projectChannelUnlinkTitle' => ({required Object name}) => '解除关联 ${name}',
			'workspace.projectChannelUnlinkDesc' => '解除后该频道内容不再聚合进本项目',
			'workspace.projectChannelUnlinkSubmit' => '解除关联',
			'workspace.projectChannelUnlinkedToast' => '已解除关联',
			'workspace.projectInsightsTabPinned' => '置顶消息',
			'workspace.projectInsightsTabResources' => '资源链接',
			'workspace.projectInsightsTabActivity' => '项目动态',
			'workspace.projectInsightsTabPosts' => '相关帖子',
			'workspace.projectInsightsPinnedEmpty' => '关联频道暂无置顶内容',
			'workspace.projectInsightsResourcesEmpty' => '项目暂无资源链接',
			'workspace.projectInsightsActivityEmpty' => '项目暂无动态',
			'workspace.projectInsightsPostsEmpty' => '关联频道暂无帖子',
			'workspace.projectInsightsPostAuthor' => ({required Object name}) => '${name} 发布',
			'workspace.contentProtectedPending' => '内容已暂时隐藏，等待重新授权',
			'workspace.contentProtectedRetry' => '重新验证',
			'workspace.contentRevoked' => '你已无权查看此工作区内容',
			_ => null,
		};
	}
}
