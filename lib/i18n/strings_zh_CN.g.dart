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
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-CN>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$account$zh_CN account = Translations$account$zh_CN.internal(_root);
	late final Translations$channel$zh_CN channel = Translations$channel$zh_CN.internal(_root);
	late final Translations$chat$zh_CN chat = Translations$chat$zh_CN.internal(_root);
	late final Translations$common$zh_CN common = Translations$common$zh_CN.internal(_root);
	late final Translations$complaint$zh_CN complaint = Translations$complaint$zh_CN.internal(_root);
	late final Translations$complaintReason$zh_CN complaintReason = Translations$complaintReason$zh_CN.internal(_root);
	late final Translations$contact$zh_CN contact = Translations$contact$zh_CN.internal(_root);
	late final Translations$discovery$zh_CN discovery = Translations$discovery$zh_CN.internal(_root);
	late final Translations$error$zh_CN error = Translations$error$zh_CN.internal(_root);
	late final Translations$group$zh_CN group = Translations$group$zh_CN.internal(_root);
	late final Translations$groupCategory$zh_CN groupCategory = Translations$groupCategory$zh_CN.internal(_root);
	late final Translations$groupList$zh_CN groupList = Translations$groupList$zh_CN.internal(_root);
	late final Translations$groupSchedule$zh_CN groupSchedule = Translations$groupSchedule$zh_CN.internal(_root);
	late final Translations$groupTag$zh_CN groupTag = Translations$groupTag$zh_CN.internal(_root);
	late final Translations$groupTask$zh_CN groupTask = Translations$groupTask$zh_CN.internal(_root);
	late final Translations$groupVote$zh_CN groupVote = Translations$groupVote$zh_CN.internal(_root);
	late final Translations$main$zh_CN main = Translations$main$zh_CN.internal(_root);
	late final Translations$mention$zh_CN mention = Translations$mention$zh_CN.internal(_root);
	late final Translations$momentFriendPicker$zh_CN momentFriendPicker = Translations$momentFriendPicker$zh_CN.internal(_root);
	late final Translations$momentNotify$zh_CN momentNotify = Translations$momentNotify$zh_CN.internal(_root);
	late final Translations$passport$zh_CN passport = Translations$passport$zh_CN.internal(_root);
	late final Translations$splash$zh_CN splash = Translations$splash$zh_CN.internal(_root);
	late final Translations$welcome$zh_CN welcome = Translations$welcome$zh_CN.internal(_root);
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

	/// zh-CN: '手机充值'
	String get mobileRecharge => '手机充值';

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

	/// zh-CN: '现有密码'
	String get existingPassword => '现有密码';

	/// zh-CN: '忘记密码？'
	String get forgotPassword => '忘记密码？';

	/// zh-CN: '性别'
	String get gender => '性别';

	/// zh-CN: '保存中...'
	String get genderSaving => '保存中...';

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

	/// zh-CN: '昵称修改后，只会在此群内显示，群内成员都可以看见。'
	String get nicknameChangeVisibility => '昵称修改后，只会在此群内显示，群内成员都可以看见。';

	/// zh-CN: '还可输入$param个字符'
	String nicknameCharsRemaining({required Object param}) => '还可输入${param}个字符';

	/// zh-CN: '请输入昵称'
	String get nicknameHint => '请输入昵称';

	/// zh-CN: '保存中...'
	String get nicknameSaving => '保存中...';

	/// zh-CN: '$param登录'
	String paramLogin({required Object param}) => '${param}登录';

	/// zh-CN: '密码'
	String get password => '密码';

	/// zh-CN: '最近注册用户'
	String get recentlyRegisteredUser => '最近注册用户';

	/// zh-CN: '我们会将密码恢复码发送到您的邮箱。'
	String get recoverCodePasswordDesc => '我们会将密码恢复码发送到您的邮箱。';

	/// zh-CN: '找回密码'
	String get recoverPassword => '找回密码';

	/// zh-CN: '请输入您的邮箱地址，我们将把密码重置码发送给您。'
	String get recoverPasswordDesc => '请输入您的邮箱地址，我们将把密码重置码发送给您。';

	/// zh-CN: '不要感觉不好，这是常有的事。'
	String get recoverPasswordIntro => '不要感觉不好，这是常有的事。';

	/// zh-CN: '生日'
	String get birthday => '生日';

	/// zh-CN: '地区'
	String get region => '地区';

	/// zh-CN: '重新输入密码'
	String get retypePassword => '重新输入密码';

	/// zh-CN: '扫描二维码'
	String get scanQrCode => '扫描二维码';

	/// zh-CN: '安全中心'
	String get securityCenter => '安全中心';

	/// zh-CN: '设置昵称'
	String get setNickname => '设置昵称';

	/// zh-CN: '个性签名'
	String get signature => '个性签名';

	/// zh-CN: '注册'
	String get signup => '注册';

	/// zh-CN: '请填写此表格以完成注册'
	String get signupFormDesc => '请填写此表格以完成注册';

	/// zh-CN: '通过扫一扫添加'
	String get sourceQrcode => '通过扫一扫添加';

	/// zh-CN: '切换账号'
	String get switchAccount => '切换账号';

	/// zh-CN: '修改邮箱'
	String get changeEmail => '修改邮箱';

	/// zh-CN: '绑定邮箱'
	String get bindEmail => '绑定邮箱';

	/// zh-CN: '当前邮箱'
	String get currentEmail => '当前邮箱';

	/// zh-CN: '新邮箱与当前绑定一致'
	String get newEmailSameAsCurrent => '新邮箱与当前绑定一致';

	/// zh-CN: '新手机号与当前绑定一致'
	String get newMobileSameAsCurrent => '新手机号与当前绑定一致';

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

	/// zh-CN: '已发送至 $param'
	String codeSentToMobileParam({required Object param}) => '已发送至 ${param}';

	/// zh-CN: '注销账号'
	String get privacyLogoutAccount => '注销账号';

	/// zh-CN: '钱包'
	String get wallet => '钱包';

	/// zh-CN: '修改登录密码'
	String get changeLoginPassword => '修改登录密码';

	/// zh-CN: '提示'
	String get loginExpiredTitle => '提示';

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

	/// zh-CN: '余额'
	String get balance => '余额';

	/// zh-CN: '充值'
	String get recharge => '充值';

	/// zh-CN: '提现'
	String get withdraw => '提现';

	/// zh-CN: '支付密码'
	String get paymentPassword => '支付密码';

	/// zh-CN: '设置支付密码'
	String get setPaymentPassword => '设置支付密码';

	/// zh-CN: '请输入支付密码'
	String get enterPaymentPassword => '请输入支付密码';

	/// zh-CN: '我的二维码'
	String get myQRCode => '我的二维码';

	/// zh-CN: '个人资料'
	String get profile => '个人资料';

	/// zh-CN: '设置性别'
	String get setGender => '设置性别';

	/// zh-CN: '设置生日'
	String get setBirthday => '设置生日';

	/// zh-CN: '已发送至 $param'
	String sentToEmail({required Object param}) => '已发送至 ${param}';

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

	/// zh-CN: '请输入充值金额（元），1元～10000元'
	String get rechargeAmountHint => '请输入充值金额（元），1元～10000元';

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

	/// zh-CN: '设备间传输'
	String get e2eeDeviceTransfer => '设备间传输';

	/// zh-CN: '通过二维码直接传输密钥到新设备'
	String get e2eeDeviceTransferDesc => '通过二维码直接传输密钥到新设备';

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

	/// zh-CN: '从旧设备接收密钥'
	String get e2eeTransferFromOldDevice => '从旧设备接收密钥';

	/// zh-CN: '请重新登录'
	String get pleaseRelogin => '请重新登录';
}

// Path: channel
class Translations$channel$zh_CN {
	Translations$channel$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

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

	/// zh-CN: '搜索频道'
	String get search => '搜索频道';

	/// zh-CN: '创建频道'
	String get create => '创建频道';

	/// zh-CN: '搜索频道名称或ID'
	String get searchHint => '搜索频道名称或ID';

	/// zh-CN: '输入关键词搜索频道'
	String get searchTip => '输入关键词搜索频道';

	/// zh-CN: '未找到相关频道'
	String get noResults => '未找到相关频道';

	/// zh-CN: '暂无推荐频道 稍后再来看看吧'
	String get noRecommendedChannels => '暂无推荐频道 稍后再来看看吧';

	/// zh-CN: '暂无订阅的频道 去发现更多精彩频道吧'
	String get noSubscribedChannels => '暂无订阅的频道 去发现更多精彩频道吧';

	/// zh-CN: '暂无管理的频道 创建一个频道开始你的创作'
	String get noManagedChannels => '暂无管理的频道 创建一个频道开始你的创作';

	/// zh-CN: '暂无消息'
	String get noMessages => '暂无消息';

	/// zh-CN: '订阅者'
	String get subscribers => '订阅者';

	/// zh-CN: '置顶'
	String get pinned => '置顶';

	/// zh-CN: '查看'
	String get view => '查看';

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

	/// zh-CN: '频道类型'
	String get typeLabel => '频道类型';

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

	/// zh-CN: '互动'
	String get reactions => '互动';

	/// zh-CN: '选择表情'
	String get selectReaction => '选择表情';

	/// zh-CN: '互动'
	String get react => '互动';

	/// zh-CN: '管理'
	String get admin => '管理';

	/// zh-CN: '设置'
	String get settings => '设置';

	/// zh-CN: '编辑频道'
	String get editChannel => '编辑频道';

	/// zh-CN: '修改频道名称、描述等信息'
	String get editChannelDesc => '修改频道名称、描述等信息';

	/// zh-CN: '编辑频道功能即将上线'
	String get editChannelNotImplemented => '编辑频道功能即将上线';

	/// zh-CN: '管理管理员'
	String get manageAdmins => '管理管理员';

	/// zh-CN: '添加或移除频道管理员'
	String get manageAdminsDesc => '添加或移除频道管理员';

	/// zh-CN: '管理管理员功能即将上线'
	String get manageAdminsNotImplemented => '管理管理员功能即将上线';

	/// zh-CN: '管理订阅者'
	String get manageSubscribers => '管理订阅者';

	/// zh-CN: '查看和管理频道订阅者'
	String get manageSubscribersDesc => '查看和管理频道订阅者';

	/// zh-CN: '管理订阅者功能即将上线'
	String get manageSubscribersNotImplemented => '管理订阅者功能即将上线';

	/// zh-CN: '删除频道'
	String get deleteChannel => '删除频道';

	/// zh-CN: '删除后将无法恢复'
	String get deleteChannelDesc => '删除后将无法恢复';

	/// zh-CN: '确定要删除该频道吗？此操作不可恢复。'
	String get deleteChannelConfirm => '确定要删除该频道吗？此操作不可恢复。';

	/// zh-CN: '删除频道功能即将上线'
	String get deleteChannelNotImplemented => '删除频道功能即将上线';

	/// zh-CN: '频道已删除'
	String get channelDeleted => '频道已删除';

	/// zh-CN: '删除频道失败'
	String get deleteChannelFailed => '删除频道失败';

	/// zh-CN: '发布消息...'
	String get writeMessage => '发布消息...';

	/// zh-CN: '发布失败'
	String get publishFailed => '发布失败';

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

	/// zh-CN: '用户ID'
	String get userId => '用户ID';

	/// zh-CN: '请输入用户ID'
	String get userIdHint => '请输入用户ID';

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

	/// zh-CN: '未知'
	String get roleUnknown => '未知';

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
}

// Path: chat
class Translations$chat$zh_CN {
	Translations$chat$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '银行卡'
	String get bankCard => '银行卡';

	/// zh-CN: '张'
	String get cards => '张';

	/// zh-CN: '京东购物'
	String get jdShopping => '京东购物';

	/// zh-CN: '收付款'
	String get receivePayment => '收付款';

	/// zh-CN: '你已经输入过了'
	String get alreadyEntered => '你已经输入过了';

	/// zh-CN: '已是成员'
	String get alreadyMember => '已是成员';

	/// zh-CN: '当前账号本地生成的sqlite文件大小；可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。'
	String get appSqliteFileSizeExplain => '当前账号本地生成的sqlite文件大小；可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。';

	/// zh-CN: '附件提供者'
	String get attachmentProvider => '附件提供者';

	/// zh-CN: '语音消息'
	String get audioMessage => '语音消息';

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

	/// zh-CN: '修改群聊名称后，将在群内通知其他成员。'
	String get changeGroupChatName => '修改群聊名称后，将在群内通知其他成员。';

	/// zh-CN: '聊天记录'
	String get chatHistory => '聊天记录';

	/// zh-CN: '按住说话'
	String get chatHoldDownTalk => '按住说话';

	/// zh-CN: '聊天消息'
	String get chatMessage => '聊天消息';

	/// zh-CN: '聊天、朋友圈、运动数据等'
	String get chatMomentSportDataEtc => '聊天、朋友圈、运动数据等';

	/// zh-CN: '消息免打扰'
	String get chatSettingMute => '消息免打扰';

	/// zh-CN: '关闭此聊天的消息通知'
	String get chatSettingMuteDesc => '关闭此聊天的消息通知';

	/// zh-CN: '已开启免打扰'
	String get chatSettingMuted => '已开启免打扰';

	/// zh-CN: '置顶聊天'
	String get chatSettingPin => '置顶聊天';

	/// zh-CN: '将此聊天置顶到列表顶部'
	String get chatSettingPinDesc => '将此聊天置顶到列表顶部';

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

	/// zh-CN: '消息正在发送...'
	String get chatStatusSendingDesc => '消息正在发送...';

	/// zh-CN: '消息已发送'
	String get chatStatusSentDesc => '消息已发送';

	/// zh-CN: '消息已送达'
	String get chatStatusDeliveredDesc => '消息已送达';

	/// zh-CN: '消息已读'
	String get chatStatusSeenDesc => '消息已读';

	/// zh-CN: '面对面建群'
	String get createGroupF2f => '面对面建群';

	/// zh-CN: '显示你的资料'
	String get displayProfile => '显示你的资料';

	/// zh-CN: '文件'
	String get file => '文件';

	/// zh-CN: '[文件]'
	String get fileMessage => '[文件]';

	/// zh-CN: '文件大小'
	String get fileSize => '文件大小';

	/// zh-CN: '忘记密码验证码视图'
	String get forgotPasswordPinCodeView => '忘记密码验证码视图';

	/// zh-CN: '转发'
	String get forward => '转发';

	/// zh-CN: '转发回复'
	String get forwardReply => '转发回复';

	/// zh-CN: '转发给'
	String get forwardTo => '转发给';

	/// zh-CN: '转发给朋友'
	String get forwardToFriend => '转发给朋友';

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

	/// zh-CN: '仅聊天'
	String get justChat => '仅聊天';

	/// zh-CN: '位置'
	String get location => '位置';

	/// zh-CN: '导出我的数据'
	String get exportMyData => '导出我的数据';

	/// zh-CN: '导出你的个人信息、联系人和聊天记录'
	String get exportDataDesc => '导出你的个人信息、联系人和聊天记录';

	/// zh-CN: '消息'
	String get message => '消息';

	/// zh-CN: '消息处理混入'
	String get messageHandlingMixin => '消息处理混入';

	/// zh-CN: '消息标记'
	String get messageMarkTitle => '消息标记';

	/// zh-CN: '自定义消息'
	String get customMessage => '自定义消息';

	/// zh-CN: '名片'
	String get card => '名片';

	/// zh-CN: '消息类型'
	String get messageType => '消息类型';

	/// zh-CN: '消息名片构建器'
	String get messageVisitCardBuilder => '消息名片构建器';

	/// zh-CN: '撤回了一条消息'
	String get messageWasWithdrawn => '撤回了一条消息';

	/// zh-CN: '$param撤回了一条消息'
	String messageWasWithdrawnWithTitle({required Object param}) => '${param}撤回了一条消息';

	/// zh-CN: '音视频消息构建器'
	String get messageWebrtcBuilder => '音视频消息构建器';

	/// zh-CN: '朋友圈和状态'
	String get momentStatus => '朋友圈和状态';

	/// zh-CN: '离线'
	String get offline => '离线';

	/// zh-CN: '在线'
	String get online => '在线';

	/// zh-CN: '$param已存在'
	String paramAlreadyExist({required Object param}) => '${param}已存在';

	/// zh-CN: '置顶'
	String get pin => '置顶';

	/// zh-CN: '置顶聊天'
	String get pinChat => '置顶聊天';

	/// zh-CN: '已置顶'
	String get pinned => '已置顶';

	/// zh-CN: '私聊回复'
	String get privateReply => '私聊回复';

	/// zh-CN: '二维码名片'
	String get qrCodeBusinessCard => '二维码名片';

	/// zh-CN: '引用回复'
	String get quoteReply => '引用回复';

	/// zh-CN: '评级'
	String get rating => '评级';

	/// zh-CN: '已经阅读并同意$param'
	String readAgreeParam({required Object param}) => '已经阅读并同意${param}';

	/// zh-CN: '最近聊天'
	String get recentChats => '最近聊天';

	/// zh-CN: '最近转发'
	String get recentForwards => '最近转发';

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

	/// zh-CN: '禁言至'
	String get muteUntil => '禁言至';

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

	/// zh-CN: '回复'
	String get replyTo => '回复';

	/// zh-CN: '重发验证码'
	String get resendCode => '重发验证码';

	/// zh-CN: '撤回'
	String get revoke => '撤回';

	/// zh-CN: '扫描二维码名片'
	String get scanQrCodeBusinessCard => '扫描二维码名片';

	/// zh-CN: '单聊'
	String get singleChat => '单聊';

	/// zh-CN: '私聊'
	String get privateChat => '私聊';

	/// zh-CN: '群消息'
	String get groupMessage => '群消息';

	/// zh-CN: '发送添加朋友申请'
	String get sendFriendRequest => '发送添加朋友申请';

	/// zh-CN: '消息已发出，但被对方拒收了。'
	String get sendMsgRejected => '消息已发出，但被对方拒收了。';

	/// zh-CN: '发消息'
	String get sendMessage => '发消息';

	/// zh-CN: '分别发送给'
	String get sendSeparatelyTo => '分别发送给';

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

	/// zh-CN: '发送者'
	String get sender => '发送者';

	/// zh-CN: '正在发送...'
	String get sending => '正在发送...';

	/// zh-CN: '签名输入提示'
	String get signatureInputHint => '签名输入提示';

	/// zh-CN: '签名占位符'
	String get signaturePlaceholder => '签名占位符';

	/// zh-CN: '确认码已发送到您的邮箱， 请输入确认码确认您的帐户。'
	String get signupIntro => '确认码已发送到您的邮箱， 请输入确认码确认您的帐户。';

	/// zh-CN: '社交资料'
	String get socialProfile => '社交资料';

	/// zh-CN: '状态'
	String get status => '状态';

	/// zh-CN: '存储空间和数据'
	String get storageSpaceData => '存储空间和数据';

	/// zh-CN: '确定要打开文件吗？'
	String get sureOpenTheFile => '确定要打开文件吗？';

	/// zh-CN: '文本消息'
	String get textMessage => '文本消息';

	/// zh-CN: '消息'
	String get titleMessage => '消息';

	/// zh-CN: '置顶聊天'
	String get topChat => '置顶聊天';

	/// zh-CN: '取消置顶'
	String get unpin => '取消置顶';

	/// zh-CN: '不支持的文件类型'
	String get unsupportedFileType => '不支持的文件类型';

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

	/// zh-CN: '语音输入'
	String get voiceInput => '语音输入';

	/// zh-CN: '语音消息'
	String get voiceMessage => '语音消息';

	/// zh-CN: '你撤回了一条消息'
	String get youWithdrewAMessage => '你撤回了一条消息';

	/// zh-CN: '格式检查'
	String get formatCheck => '格式检查';

	/// zh-CN: '功能请求'
	String get featureRequest => '功能请求';

	/// zh-CN: '重新发送（$count秒）'
	String resendCodeWithCount({required Object count}) => '重新发送（${count}秒）';

	/// zh-CN: '重新发送'
	String get chatResend => '重新发送';

	/// zh-CN: '回复'
	String get chatReply => '回复';

	/// zh-CN: '打开文件'
	String get chatOpenFile => '打开文件';

	/// zh-CN: '打开链接'
	String get chatOpenLink => '打开链接';

	/// zh-CN: '选择照片'
	String get avatarSelectPhoto => '选择照片';

	/// zh-CN: '拍照'
	String get avatarTakePhoto => '拍照';

	/// zh-CN: '从相册选择'
	String get avatarSelectFromAlbum => '从相册选择';

	/// zh-CN: '导出资料'
	String get profileExportProfile => '导出资料';

	/// zh-CN: '发送'
	String get momentsSend => '发送';

	/// zh-CN: '已有压缩任务在进行中'
	String get videoCompressInProgress => '已有压缩任务在进行中';

	/// zh-CN: '正在压缩视频...'
	String get videoCompressing => '正在压缩视频...';

	/// zh-CN: '登录过期,请重新登录'
	String get loginExpiredMessage => '登录过期,请重新登录';

	/// zh-CN: '几何图案'
	String get geometricPattern => '几何图案';

	/// zh-CN: '波纹图案'
	String get ripplePattern => '波纹图案';

	/// zh-CN: '自定义图片'
	String get customImage => '自定义图片';

	/// zh-CN: '语音录制结果为空'
	String get voiceRecordResultEmpty => '语音录制结果为空';

	/// zh-CN: '语音文件无效'
	String get voiceFileInvalid => '语音文件无效';

	/// zh-CN: '阅后即焚'
	String get burnAfterReading => '阅后即焚';

	/// zh-CN: '阅后'
	String get burnReadBadge => '阅后';

	/// zh-CN: '可视阈值已读'
	String get visibleThresholdRead => '可视阈值已读';

	/// zh-CN: '已读阈值与延时'
	String get readThresholdDelay => '已读阈值与延时';

	/// zh-CN: '可读性良好'
	String get goodReadability => '可读性良好';

	/// zh-CN: '资料完善度'
	String get profileCompleteness => '资料完善度';

	/// zh-CN: '标签统计'
	String get tagStatistics => '标签统计';

	/// zh-CN: '已发送'
	String get alreadySent => '已发送';

	/// zh-CN: '可见比例 (0.1~1.0)'
	String get visibleRatioLabel => '可见比例 (0.1~1.0)';

	/// zh-CN: '不支持的消息类型'
	String get unsupportedMessageType => '不支持的消息类型';

	/// zh-CN: '两次密码不一致'
	String get passwordMismatch => '两次密码不一致';

	/// zh-CN: '请稍后重试'
	String get pleaseTryAgainLater => '请稍后重试';

	/// zh-CN: '选择视频'
	String get momentsSelectVideo => '选择视频';

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

	/// zh-CN: '语音文件为空，请重试'
	String get voiceFileEmptyPleaseTryAgain => '语音文件为空，请重试';

	/// zh-CN: '正在发送语音...'
	String get sendingVoice => '正在发送语音...';

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

	/// zh-CN: '消息免打扰'
	String get messageMute => _root.chat.chatSettingMute;

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

	/// zh-CN: '准备就绪'
	String get e2eeReady => '准备就绪';

	/// zh-CN: '准备就绪（$count 个分片）'
	String e2eeReadyWithShards({required Object count}) => '准备就绪（${count} 个分片）';

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

	/// zh-CN: '创建恢复分片'
	String get e2eeSocialCreateTitle => '创建恢复分片';

	/// zh-CN: '创建分片'
	String get e2eeSocialCreateBtn => '创建分片';

	/// zh-CN: '创建失败'
	String get e2eeSocialCreateFailTitle => '创建失败';

	/// zh-CN: '创建分片失败，请重试'
	String get e2eeSocialCreateFailBody => '创建分片失败，请重试';

	/// zh-CN: '创建分片后才能看到内容'
	String get e2eeSocialCreateFirst => '创建分片后才能看到内容';

	/// zh-CN: '使用时间'
	String get e2eeSocialUsedAtLabel => '使用时间';

	/// zh-CN: '发送密钥到新设备'
	String get e2eeTransferSendTitle => '发送密钥到新设备';

	/// zh-CN: '创建'
	String get e2eeTransferCreateBtn => '创建';

	/// zh-CN: '从旧设备接收密钥'
	String get e2eeTransferReceiveTitle => '从旧设备接收密钥';

	/// zh-CN: '通过二维码将密钥传输到新设备'
	String get e2eeTransferSendDesc => '通过二维码将密钥传输到新设备';

	/// zh-CN: '扫描旧设备二维码接收密钥'
	String get e2eeTransferReceiveDesc => '扫描旧设备二维码接收密钥';

	/// zh-CN: '状态: $status'
	String e2eeSocialStatus({required Object status}) => '状态: ${status}';

	/// zh-CN: '创建恢复分片'
	String get e2eeSocialCreateShardsTitle => '创建恢复分片';

	/// zh-CN: '将密钥分割成多个分片，存储到代理设备（服务端不保存）'
	String get e2eeSocialCreateShardsDesc => '将密钥分割成多个分片，存储到代理设备（服务端不保存）';

	/// zh-CN: '请选择至少 $count 个代理'
	String e2eeProxyNeedAtLeast({required Object count}) => '请选择至少 ${count} 个代理';

	/// zh-CN: '正在重新创建密钥...'
	String get e2eeRecreatingKey => '正在重新创建密钥...';

	/// zh-CN: '密钥已重新创建'
	String get e2eeKeyRecreated => '密钥已重新创建';

	/// zh-CN: '检测到新设备登录'
	String get e2eeRecoveryNewDeviceTitle => '检测到新设备登录';

	/// zh-CN: '为保护消息安全，本设备已生成新的端对端加密密钥。 历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「设备转移」「社交恢复」或「本地备份导入」恢复。'
	String get e2eeRecoveryNewDeviceBody => '为保护消息安全，本设备已生成新的端对端加密密钥。\n\n历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「设备转移」「社交恢复」或「本地备份导入」恢复。';

	/// zh-CN: '无法解密此消息'
	String get e2eeRecoveryDecryptFailedTitle => '无法解密此消息';

	/// zh-CN: '此消息由其他设备的密钥加密。 若你更换了设备或重新安装了应用，请恢复加密密钥后再查看历史消息。'
	String get e2eeRecoveryDecryptFailedBody => '此消息由其他设备的密钥加密。\n\n若你更换了设备或重新安装了应用，请恢复加密密钥后再查看历史消息。';

	/// zh-CN: '稍后'
	String get e2eeRecoveryLater => '稍后';

	/// zh-CN: '去恢复'
	String get e2eeRecoveryGoRecover => '去恢复';

	/// zh-CN: '检测到加密历史消息，需恢复密钥后才能查看，点击前往恢复'
	String get e2eeRecoveryBannerText => '检测到加密历史消息，需恢复密钥后才能查看，点击前往恢复';

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

	/// zh-CN: '拒绝'
	String get declineCall => '拒绝';

	/// zh-CN: '网络不佳，正在重连…'
	String get reconnecting => '网络不佳，正在重连…';

	/// zh-CN: '最小化'
	String get minimize => '最小化';

	/// zh-CN: '切换摄像头'
	String get switchCamera => '切换摄像头';

	/// zh-CN: '添加朋友'
	String get addFriend => '添加朋友';

	/// zh-CN: '添加手机联系人'
	String get addPhoneContact => '添加手机联系人';

	/// zh-CN: '信用卡还款'
	String get creditCardRepayment => '信用卡还款';

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

	/// zh-CN: '同意并继续'
	String get agreeContinue => '同意并继续';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '所有发送者'
	String get allSenders => '所有发送者';

	/// zh-CN: '全部标签'
	String get allTags => '全部标签';

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

	/// zh-CN: '绑定'
	String get buttonBind => '绑定';

	/// zh-CN: '绑定手机号和邮箱，让您的账户更安全'
	String get bindMobileAndEmailTips => '绑定手机号和邮箱，让您的账户更安全';

	/// zh-CN: '立即绑定'
	String get bindNow => '立即绑定';

	/// zh-CN: '取消'
	String get buttonCancel => '取消';

	/// zh-CN: '创建'
	String get buttonCreate => '创建';

	/// zh-CN: '修改密码'
	String get buttonChangePassword => '修改密码';

	/// zh-CN: '请输入手机号'
	String get phoneInputHint => '请输入手机号';

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

	/// zh-CN: '注销账户'
	String get buttonDeleteAccount => '注销账户';

	/// zh-CN: '邀请码'
	String get buttonInviteCode => '邀请码';

	/// zh-CN: '登录'
	String get buttonLogin => '登录';

	/// zh-CN: '退出登录'
	String get buttonLogout => '退出登录';

	/// zh-CN: '下一步'
	String get buttonNextStep => '下一步';

	/// zh-CN: '确定'
	String get buttonOk => '确定';

	/// zh-CN: '注册'
	String get buttonRegister => '注册';

	/// zh-CN: '重置密码'
	String get buttonResetPassword => '重置密码';

	/// zh-CN: '重试'
	String get buttonRetry => '重试';

	/// zh-CN: '保存'
	String get buttonSave => '保存';

	/// zh-CN: '从相册选择'
	String get buttonSelectFromAlbum => '从相册选择';

	/// zh-CN: '发送'
	String get buttonSend => '发送';

	/// zh-CN: '置空'
	String get buttonSetEmpty => '置空';

	/// zh-CN: '提交'
	String get buttonSubmit => '提交';

	/// zh-CN: '拍照'
	String get buttonTakingPictures => '拍照';

	/// zh-CN: '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。'
	String get cacheTips => '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。';

	/// zh-CN: '通话时长'
	String get callDuration => '通话时长';

	/// zh-CN: '正在通话'
	String get calling => '正在通话';

	/// zh-CN: '你不能添加自己为好友'
	String get canNotAddYourselfFriend => '你不能添加自己为好友';

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

	/// zh-CN: '已设置自定义背景'
	String get chatSettingBackgroundCustom => '已设置自定义背景';

	/// zh-CN: '默认背景'
	String get chatSettingBackgroundDefault => '默认背景';

	/// zh-CN: '背景选择功能开发中'
	String get chatSettingBackgroundSelectorTip => '背景选择功能开发中';

	/// zh-CN: '背景设置成功'
	String get chatSettingBackgroundSuccess => '背景设置成功';

	/// zh-CN: '清空聊天记录'
	String get chatSettingClearHistory => '清空聊天记录';

	/// zh-CN: '确定要清空所有聊天记录吗？此操作不可恢复。'
	String get chatSettingClearHistoryConfirm => '确定要清空所有聊天记录吗？此操作不可恢复。';

	/// zh-CN: '删除所有消息，此操作不可恢复'
	String get chatSettingClearHistoryDesc => '删除所有消息，此操作不可恢复';

	/// zh-CN: '清空成功'
	String get chatSettingClearedSuccess => '清空成功';

	/// zh-CN: '置顶成功'
	String get chatSettingPinnedSuccess => '置顶成功';

	/// zh-CN: '取消置顶'
	String get chatSettingUnpinnedSuccess => '取消置顶';

	/// zh-CN: '聊天设置'
	String get chatSettings => '聊天设置';

	/// zh-CN: '发送失败'
	String get chatStatusFailed => '发送失败';

	/// zh-CN: '发送失败，点击重试'
	String get chatStatusFailedDesc => '发送失败，点击重试';

	/// zh-CN: '对方已将您加入黑名单'
	String get chatErrorInDenylist => '对方已将您加入黑名单';

	/// zh-CN: '消息无法发送，对方已将您加入黑名单'
	String get chatErrorInDenylistDesc => '消息无法发送，对方已将您加入黑名单';

	/// zh-CN: '对方不是您的好友'
	String get chatErrorNotAFriend => '对方不是您的好友';

	/// zh-CN: '消息无法发送，请先添加对方为好友'
	String get chatErrorNotAFriendDesc => '消息无法发送，请先添加对方为好友';

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

	/// zh-CN: '确认码'
	String get confirmCode => '确认码';

	/// zh-CN: '确认码为空'
	String get confirmCodeError => '确认码为空';

	/// zh-CN: '账户已确认。'
	String get confirmCodeSuccess => '账户已确认。';

	/// zh-CN: '确定删除聊天记录吗？'
	String get confirmDeleteChatRecord => '确定删除聊天记录吗？';

	/// zh-CN: '确认新好友'
	String get confirmNewFriend => '确认新好友';

	/// zh-CN: '确认新好友逻辑'
	String get confirmNewFriendLogic => '确认新好友逻辑';

	/// zh-CN: '密码修改成功。'
	String get confirmRecoverSuccess => '密码修改成功。';

	/// zh-CN: '联系人设置'
	String get contactSetting => '联系人设置';

	/// zh-CN: '联系人设置标签'
	String get contactSettingTag => '联系人设置标签';

	/// zh-CN: '联系人标签列表逻辑'
	String get contactTagListLogic => '联系人标签列表逻辑';

	/// zh-CN: '联系人标签'
	String get contactTags => '联系人标签';

	/// zh-CN: '联系人信息未同步'
	String get contactInfoNotSynced => '联系人信息未同步';

	/// zh-CN: '继续下载'
	String get continueDownloading => '继续下载';

	/// zh-CN: '复制'
	String get copy => '复制';

	/// zh-CN: '卡券'
	String get coupon => '卡券';

	/// zh-CN: '这些朋友也将进入群聊'
	String get createGroupF2fConfirmTips => '这些朋友也将进入群聊';

	/// zh-CN: '和身边的朋友输入同样的四个数字，进入同一个群聊'
	String get createGroupF2fTips => '和身边的朋友输入同样的四个数字，进入同一个群聊';

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

	/// zh-CN: '对 $param 的访问被拒绝'
	String errorAccessDenied({required Object param}) => '对 ${param} 的访问被拒绝';

	/// zh-CN: '错误'
	String get errorCliVersionNotFound => _root.common.error;

	/// zh-CN: '$param 是空的'
	String errorEmptyDirectory({required Object param}) => '${param} 是空的';

	/// zh-CN: '错误'
	String get errorFailedConnectServer => _root.common.error;

	/// zh-CN: '错误'
	String get errorFailedToConnect => _root.common.error;

	/// zh-CN: '在 $param 中没有找到文件'
	String errorFileNotFound({required Object param}) => '在 ${param} 中没有找到文件';

	/// zh-CN: '文件夹 $param 未找到'
	String errorFolderNotFound({required Object param}) => '文件夹 ${param} 未找到';

	/// zh-CN: '错误'
	String get errorHttpNotSupported => _root.common.error;

	/// zh-CN: '错误'
	String get errorInternalServer => _root.common.error;

	/// zh-CN: '$param 是无效的'
	String errorInvalid({required Object param}) => '${param} 是无效的';

	/// zh-CN: '错误'
	String get errorInvalidDart => _root.common.error;

	/// zh-CN: '错误'
	String get errorInvalidFileOrDirectory => _root.common.error;

	/// zh-CN: '错误'
	String get errorInvalidJson => _root.common.error;

	/// zh-CN: '错误'
	String get errorInvalidRequest => _root.common.error;

	/// zh-CN: '$param 长度必须在 $min 和 $max 之间'
	String errorLengthBetween({required Object param, required Object min, required Object max}) => '${param} 长度必须在 ${min} 和 ${max} 之间';

	/// zh-CN: '请求过于频繁'
	String get errorManyRequest => '请求过于频繁';

	/// zh-CN: '错误'
	String get errorNoPackageToRemove => _root.common.error;

	/// zh-CN: '错误'
	String get errorNoValidFileOrUrl => _root.common.error;

	/// zh-CN: '错误'
	String get errorNonexistentDirectory => _root.common.error;

	/// zh-CN: '错误'
	String get errorPackageNotFound => _root.common.error;

	/// zh-CN: '密码错误'
	String get errorPassword => '密码错误';

	/// zh-CN: '错误'
	String get errorRequestForbidden => _root.common.error;

	/// zh-CN: '错误'
	String get errorRequestSyntax => _root.common.error;

	/// zh-CN: '$param 是必须的'
	String errorRequired({required Object param}) => '${param} 是必须的';

	/// zh-CN: '错误'
	String get errorRequiredPath => _root.common.error;

	/// zh-CN: '错误'
	String get errorRetypePassword => _root.common.error;

	/// zh-CN: '$param1 和 $param2 必须相同'
	String errorSame({required Object param1, required Object param2}) => '${param1} 和 ${param2} 必须相同';

	/// zh-CN: '错误'
	String get errorServerDown => _root.common.error;

	/// zh-CN: '错误'
	String get errorServerRefused => _root.common.error;

	/// zh-CN: '错误'
	String get errorSpecialCharactersInKey => _root.common.error;

	/// zh-CN: '错误'
	String get errorUnexpected => _root.common.error;

	/// zh-CN: '错误'
	String get errorUnnecessaryParameter => _root.common.error;

	/// zh-CN: '错误'
	String get errorUnnecessaryParameterPlural => _root.common.error;

	/// zh-CN: '错误'
	String get errorUpdateCli => _root.common.error;

	/// zh-CN: '网络错误'
	String get failedGetLatLong => _root.common.errorNetwork;

	/// zh-CN: '网络错误'
	String get failedGetMapTryAgain => _root.common.errorNetwork;

	/// zh-CN: '网络错误'
	String get failedRequestPleaseCheckNetwork => _root.common.errorNetwork;

	/// zh-CN: '反馈建议'
	String get feedback => '反馈建议';

	/// zh-CN: '反馈构建器'
	String get feedbackBuilder => '反馈构建器';

	/// zh-CN: '反馈内容不能为空'
	String get feedbackContentRequired => '反馈内容不能为空';

	/// zh-CN: '反馈建议明细'
	String get feedbackDetails => '反馈建议明细';

	/// zh-CN: '反馈模型'
	String get feedbackModel => '反馈模型';

	/// zh-CN: '反馈回复模型'
	String get feedbackReplyModel => '反馈回复模型';

	/// zh-CN: '你的反馈问题我们已经收到了，会尽快处理！'
	String get feedbackSuccessMsg => '你的反馈问题我们已经收到了，会尽快处理！';

	/// zh-CN: '开启后,将跟随系统打开或关闭深色模式'
	String get followSystemTips => '开启后,将跟随系统打开或关闭深色模式';

	/// zh-CN: '您已被设备【$param】强制下线'
	String forceLogoutNotification({required Object param}) => '您已被设备【${param}】强制下线';

	/// zh-CN: '朋友权限'
	String get friendPermissions => '朋友权限';

	/// zh-CN: '好友权限视图'
	String get friendsPermissionsView => '好友权限视图';

	/// zh-CN: '性别设置冲突，请重试'
	String get genderConflictError => '性别设置冲突，请重试';

	/// zh-CN: '网络异常，请检查网络连接'
	String get genderNetworkError => '网络异常，请检查网络连接';

	/// zh-CN: '性别设置失败，请重试'
	String get genderUpdateFailed => '性别设置失败，请重试';

	/// zh-CN: '性别设置成功'
	String get genderUpdateSuccess => '性别设置成功';

	/// zh-CN: '保存到通讯录'
	String get groupAddLocal => '保存到通讯录';

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

	/// zh-CN: '关闭预览'
	String get groupFileClosePreview => '关闭预览';

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

	/// zh-CN: '清空'
	String get groupFileSearchClear => '清空';

	/// zh-CN: '搜索'
	String get groupFileSearchAction => '搜索';

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

	/// zh-CN: '群名称和群简介'
	String get groupSearchTips => '群名称和群简介';

	/// zh-CN: '帮助文档'
	String get helpDocument => '帮助文档';

	/// zh-CN: '编辑群公告'
	String get hintEditGroupAnnouncement => '编辑群公告';

	/// zh-CN: 'HTTP响应'
	String get httpResponse => 'HTTP响应';

	/// zh-CN: '$param呼入'
	String incomingCall({required Object param}) => '${param}呼入';

	/// zh-CN: '信息'
	String get info => '信息';

	/// zh-CN: '你的账号已于$param在其他设备登录'
	String infoLoggedInOnAnotherDevice({required Object param}) => '你的账号已于${param}在其他设备登录';

	/// zh-CN: '立即安装'
	String get installNow => '立即安装';

	/// zh-CN: 'AppStore未上架或AppID[$param]不存在'
	String iosAppIdUnknown({required Object param}) => 'AppStore未上架或AppID[${param}]不存在';

	/// zh-CN: '韩语（韩国）'
	String get koKr => '韩语（韩国）';

	/// zh-CN: '语言设置'
	String get languageSetting => '语言设置';

	/// zh-CN: '语言状态'
	String get languageState => '语言状态';

	/// zh-CN: '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。'
	String get lastActiveTips => '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。';

	/// zh-CN: '刚刚上线'
	String get lastSeenJustNow => '刚刚上线';

	/// zh-CN: '很久以前上线'
	String get lastSeenLongTimeAgo => '很久以前上线';

	/// zh-CN: '$param个月前'
	String lastSeenMonthsAgo({required Object param}) => '${param}个月前';

	/// zh-CN: '请留下您宝贵的意见和建议'
	String get leaveYourSuggestions => '请留下您宝贵的意见和建议';

	/// zh-CN: '加载失败，请重试'
	String get loadError => '加载失败，请重试';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '加载中'
	String get loading => '加载中';

	/// zh-CN: '位置消息'
	String get locationMessage => '位置消息';

	/// zh-CN: '你的帐号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。'
	String get loginDeviceManagementTips => '你的帐号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。';

	/// zh-CN: '退出登录失败'
	String get logoutFailed => '退出登录失败';

	/// zh-CN: '《注销须知》'
	String get logoutNotice => '《注销须知》';

	/// zh-CN: '数据已导出'
	String get exportDataSuccess => '数据已导出';

	/// zh-CN: '手动选择'
	String get manually => '手动选择';

	/// zh-CN: '发消息'
	String get messageCall => '发消息';

	/// zh-CN: '消息内容'
	String get messageContent => '消息内容';

	/// zh-CN: '消息位置构建器'
	String get messageLocationBuilder => '消息位置构建器';

	/// zh-CN: '消息通知'
	String get messageNotification => '消息通知';

	/// zh-CN: '消息已撤回'
	String get messageRevoked => '消息已撤回';

	/// zh-CN: '引用的消息不可用'
	String get quoteMessageNotAvailable => '引用的消息不可用';

	/// zh-CN: '消息撤回构建器'
	String get messageRevokedBuilder => '消息撤回构建器';

	/// zh-CN: '麦克风'
	String get microphone => '麦克风';

	/// zh-CN: '未获取到麦克风权限'
	String get microphonePermissionNotObtained => '未获取到麦克风权限';

	/// zh-CN: '更多信息'
	String get moreInfo => '更多信息';

	/// zh-CN: '我的地址'
	String get myAddress => '我的地址';

	/// zh-CN: '与附近的人交换联系方式，结交新朋友'
	String get nearbyPeopleTips => '与附近的人交换联系方式，结交新朋友';

	/// zh-CN: '需要继续加油'
	String get needContinueWorkHard => '需要继续加油';

	/// zh-CN: '需要确认提交，该操作才生效'
	String get needSubmitEffect => '需要确认提交，该操作才生效';

	/// zh-CN: '$param失败，请检查网络连接'
	String networkErrorWithAction({required Object param}) => '${param}失败，请检查网络连接';

	/// zh-CN: '网络连接异常'
	String get networkException => '网络连接异常';

	/// zh-CN: '网络错误'
	String get errorNetwork => '网络错误';

	/// zh-CN: '网络状态异常，需要打开网络才能够查看数据'
	String get networkExceptionPlaseNeedNetworkToViewData => '网络状态异常，需要打开网络才能够查看数据';

	/// zh-CN: '网络失败提示'
	String get networkFailureTips => '网络失败提示';

	/// zh-CN: '检测到新版本'
	String get newVersionDetected => '检测到新版本';

	/// zh-CN: '检测到新版本 $param'
	String newVersionDetectedWithVersion({required Object param}) => '检测到新版本 ${param}';

	/// zh-CN: '下一步'
	String get nextStep => '下一步';

	/// zh-CN: '昵称已被使用，请选择其他昵称'
	String get nicknameConflictError => '昵称已被使用，请选择其他昵称';

	/// zh-CN: '昵称不能仅包含表情符号'
	String get nicknameEmojiOnlyError => '昵称不能仅包含表情符号';

	/// zh-CN: '昵称不能为空'
	String get nicknameEmptyError => '昵称不能为空';

	/// zh-CN: '昵称长度应在2-24个字符之间'
	String get nicknameLengthError => '昵称长度应在2-24个字符之间';

	/// zh-CN: '网络异常，请检查网络连接'
	String get nicknameNetworkError => '网络异常，请检查网络连接';

	/// zh-CN: '昵称包含敏感词，请重新输入'
	String get nicknameSensitiveWordError => '昵称包含敏感词，请重新输入';

	/// zh-CN: '服务器错误，请稍后重试'
	String get nicknameServerError => '服务器错误，请稍后重试';

	/// zh-CN: '昵称修改失败，请重试'
	String get nicknameUpdateFailed => '昵称修改失败，请重试';

	/// zh-CN: '昵称修改成功'
	String get nicknameUpdateSuccess => '昵称修改成功';

	/// zh-CN: '昵称不能仅包含空白字符'
	String get nicknameWhitespaceError => '昵称不能仅包含空白字符';

	/// zh-CN: '无头像'
	String get noAvatar => '无头像';

	/// zh-CN: '未找到条形码！'
	String get noBarcodeFound => '未找到条形码！';

	/// zh-CN: '无联系人'
	String get noContacts => '无联系人';

	/// zh-CN: '无会话消息'
	String get noConversationMessages => '无会话消息';

	/// zh-CN: '暂无数据'
	String get noData => '暂无数据';

	/// zh-CN: '当前标签无成员'
	String get noMembersInCurrentTag => '当前标签无成员';

	/// zh-CN: '没有更多数据了'
	String get noMoreData => '没有更多数据了';

	/// zh-CN: '没有新的好友'
	String get noNewFriends => '没有新的好友';

	/// zh-CN: '没有权限'
	String get noPermission => '没有权限';

	/// zh-CN: '暂无回复'
	String get noReply => '暂无回复';

	/// zh-CN: '还没有账号？'
	String get noSiginQ => '还没有账号？';

	/// zh-CN: '无更新说明'
	String get noUpdateDescription => '无更新说明';

	/// zh-CN: '普通模式'
	String get normalModel => '普通模式';

	/// zh-CN: '您还没有授权获取经纬度'
	String get notAuthorizedLatLong => '您还没有授权获取经纬度';

	/// zh-CN: '未登录'
	String get notLoggedIn => '未登录';

	/// zh-CN: '还不错'
	String get notBad => '还不错';

	/// zh-CN: '未绑定'
	String get notBound => '未绑定';

	/// zh-CN: '未填写'
	String get notFilled => '未填写';

	/// zh-CN: '您没有安装任何地图APP哦'
	String get notInstallAnyMapApp => '您没有安装任何地图APP哦';

	/// zh-CN: '不让TA看'
	String get notLetHimSee => '不让TA看';

	/// zh-CN: '没有收到验证码？'
	String get notReceiveCoeQ => '没有收到验证码？';

	/// zh-CN: '不看TA'
	String get notSeeHim => '不看TA';

	/// zh-CN: '未设置'
	String get notSet => '未设置';

	/// zh-CN: '不显示'
	String get notShow => '不显示';

	/// zh-CN: '您还没有打开位置信息服务'
	String get notTurnedLocationService => '您还没有打开位置信息服务';

	/// zh-CN: '未检测到新版本'
	String get nowNewVersion => '未检测到新版本';

	/// zh-CN: '已关闭'
	String get off => _root.common.disabled;

	/// zh-CN: '下线通知'
	String get offlineNotification => '下线通知';

	/// zh-CN: '已开启'
	String get on => _root.common.enabled;

	/// zh-CN: '操作失败，请稍后重试'
	String get operationFailedAgainLater => '操作失败，请稍后重试';

	/// zh-CN: '不'
	String get optionsNo => '不';

	/// zh-CN: '我想重命名'
	String get optionsRename => '我想重命名';

	/// zh-CN: '是的!'
	String get optionsYes => '是的!';

	/// zh-CN: 'p2pCallScreenLogic'
	String get p2pCallScreenLogic => 'p2pCallScreenLogic';

	/// zh-CN: 'p2pCallScreenView'
	String get p2pCallScreenView => 'p2pCallScreenView';

	/// zh-CN: '$param格式有误'
	String paramFormatError({required Object param}) => '${param}格式有误';

	/// zh-CN: '暂停下载'
	String get pauseDownloading => '暂停下载';

	/// zh-CN: '对方无应答...'
	String get peerNoResponse => '对方无应答...';

	/// zh-CN: '用户信息更多逻辑'
	String get peopleInfoMoreLogic => '用户信息更多逻辑';

	/// zh-CN: '同群用户视图'
	String get peopleInfoSameGroupView => '同群用户视图';

	/// zh-CN: '每分钟只能请求一次'
	String get perMinuteOnce => '每分钟只能请求一次';

	/// zh-CN: '权限'
	String get permission => '权限';

	/// zh-CN: '权限获取失败'
	String get permissionAcquisitionFailed => '权限获取失败';

	/// zh-CN: '个人名片'
	String get personalCard => '个人名片';

	/// zh-CN: '个人信息描述'
	String get personalInfoDesc => '个人信息描述';

	/// zh-CN: '个人信息提示'
	String get personalInfoTip => '个人信息提示';

	/// zh-CN: '个人信息'
	String get personalInformation => '个人信息';

	/// zh-CN: '请把方格填满'
	String get pinCodeFillTips => '请把方格填满';

	/// zh-CN: '请选择要添加的成员'
	String get pleaseSelectMembersForAdd => '请选择要添加的成员';

	/// zh-CN: '资料设置'
	String get profileSettings => '资料设置';

	/// zh-CN: '重新编辑'
	String get reEdit => '重新编辑';

	/// zh-CN: '验证码发送成功'
	String get recoverPasswordSuccess => '验证码发送成功';

	/// zh-CN: '取消'
	String get regionCancel => '取消';

	/// zh-CN: '确定'
	String get regionConfirm => '确定';

	/// zh-CN: '暂无结果'
	String get regionNoResult => '暂无结果';

	/// zh-CN: '按地区名称搜索'
	String get regionSearchHint => '按地区名称搜索';

	/// zh-CN: '按地区名称或区域编码搜索'
	String get regionSearchTips => '按地区名称或区域编码搜索';

	/// zh-CN: '选择地区'
	String get regionSelectTitle => '选择地区';

	/// zh-CN: '松开手指,取消发送'
	String get releaseFingerCancelSending => '松开手指,取消发送';

	/// zh-CN: '从标签中移除联系人'
	String get removeContactFromTag => '从标签中移除联系人';

	/// zh-CN: '移出成员'
	String get removeMember => '移出成员';

	/// zh-CN: '[@你] '
	String get atMentionYouTag => '[@你] ';

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

	/// zh-CN: '确定禁言此成员吗？'
	String get muteMemberConfirm => '确定禁言此成员吗？';

	/// zh-CN: '确定取消禁言此成员吗？'
	String get unmuteMemberConfirm => '确定取消禁言此成员吗？';

	/// zh-CN: '确定将此成员移出群聊吗？'
	String get kickMemberConfirm => '确定将此成员移出群聊吗？';

	/// zh-CN: '确定将群主身份转让给此成员吗？转让后你将变为管理员。'
	String get transferGroupConfirm => '确定将群主身份转让给此成员吗？转让后你将变为管理员。';

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

	/// zh-CN: '群主已转让'
	String get transferGroupSuccess => '群主已转让';

	/// zh-CN: '转让群主失败'
	String get transferGroupFailed => '转让群主失败';

	/// zh-CN: '未禁言'
	String get notMuted => '未禁言';

	/// zh-CN: '禁言时长'
	String get muteDuration => '禁言时长';

	/// zh-CN: '1小时'
	String get muteDuration1hour => '1小时';

	/// zh-CN: '6小时'
	String get muteDuration6hours => '6小时';

	/// zh-CN: '12小时'
	String get muteDuration12hours => '12小时';

	/// zh-CN: '1天'
	String get muteDuration1day => '1天';

	/// zh-CN: '3天'
	String get muteDuration3days => '3天';

	/// zh-CN: '7天'
	String get muteDuration7days => '7天';

	/// zh-CN: '永久'
	String get muteDurationPermanent => '永久';

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

	/// zh-CN: '已发送新邮件。'
	String get resendCodeSuccess => '已发送新邮件。';

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

	/// zh-CN: '全部筛选'
	String get searchFilterAll => '全部筛选';

	/// zh-CN: '图片筛选'
	String get searchFilterImage => '图片筛选';

	/// zh-CN: '文本筛选'
	String get searchFilterText => '文本筛选';

	/// zh-CN: '今日筛选'
	String get searchFilterToday => '今日筛选';

	/// zh-CN: '搜索筛选'
	String get searchFilters => '搜索筛选';

	/// zh-CN: '通过好友昵称、备注搜索好友'
	String get searchFriendsTips => '通过好友昵称、备注搜索好友';

	/// zh-CN: '输入关键词搜索消息'
	String get searchHint => '输入关键词搜索消息';

	/// zh-CN: '搜索历史'
	String get searchHistory => '搜索历史';

	/// zh-CN: '搜索地点'
	String get searchLocation => '搜索地点';

	/// zh-CN: '搜索消息提示'
	String get searchMessagesHint => '搜索消息提示';

	/// zh-CN: '搜索结果为空 :('
	String get searchNoFound => '搜索结果为空 :(';

	/// zh-CN: '无搜索结果'
	String get searchNoResults => '无搜索结果';

	/// zh-CN: '暂无搜索历史'
	String get noSearchHistory => '暂无搜索历史';

	/// zh-CN: '搜索地区'
	String get searchRegion => '搜索地区';

	/// zh-CN: '搜索结果'
	String get searchResults => '搜索结果';

	/// zh-CN: '第 $current 个，共 $total 个结果'
	String searchResultsCount({required Object current, required Object total}) => '第 ${current} 个，共 ${total} 个结果';

	/// zh-CN: '搜索建议'
	String get searchSuggestions => '搜索建议';

	/// zh-CN: '全选'
	String get selectAll => '全选';

	/// zh-CN: '选择联系人'
	String get selectContacts => '选择联系人';

	/// zh-CN: '选择地区视图'
	String get selectRegionView => '选择地区视图';

	/// zh-CN: '$param 个选定项目'
	String selectedItems({required Object param}) => '${param} 个选定项目';

	/// zh-CN: '已选地区'
	String get selectedRegion => '已选地区';

	/// zh-CN: '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。'
	String get sendMsgNotFriendTips => '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。';

	/// zh-CN: '设置当前聊天背景'
	String get setChatBackground => '设置当前聊天背景';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '签名提示'
	String get signatureTips => '签名提示';

	/// zh-CN: '手指上滑,取消发送'
	String get slideUpCancelSending => '手指上滑,取消发送';

	/// zh-CN: '未获取存储权限'
	String get storagePermissionNotObtained => '未获取存储权限';

	/// zh-CN: '强提醒'
	String get strongReminder => '强提醒';

	/// zh-CN: '提交于'
	String get submittedAt => '提交于';

	/// zh-CN: '确认删除吗？删除后不可恢复。'
	String get sureDeleteData => '确认删除吗？删除后不可恢复。';

	/// zh-CN: '确定删除群的聊天记录吗？'
	String get sureDeleteGroupChatRecord => '确定删除群的聊天记录吗？';

	/// zh-CN: '切换环境'
	String get switchEnvironment => '切换环境';

	/// zh-CN: '本月'
	String get thisMonth => '本月';

	/// zh-CN: '$param天前'
	String timeDaysAgo({required Object param}) => '${param}天前';

	/// zh-CN: '$param小时前'
	String timeHoursAgo({required Object param}) => '${param}小时前';

	/// zh-CN: '刚刚'
	String get timeJustNow => '刚刚';

	/// zh-CN: '$param分钟前'
	String timeMinutesAgo({required Object param}) => '${param}分钟前';

	/// zh-CN: '今天'
	String get timeToday => '今天';

	/// zh-CN: '昨天'
	String get timeYesterday => '昨天';

	/// zh-CN: '无网络'
	String get tipConnectDesc => '无网络';

	/// zh-CN: '($param)'
	String tipConnectDescWithParen({required Object param}) => '(${param})';

	/// zh-CN: '将联系人"$param"删除，同时删除与该联系人的聊天记录'
	String tipDeleteContact({required Object param}) => '将联系人"${param}"删除，同时删除与该联系人的聊天记录';

	/// zh-CN: '占设备 $param1‰ 存储空间($param2)'
	String tipDeviceSpace({required Object param1, required Object param2}) => '占设备 ${param1}‰ 存储空间(${param2})';

	/// zh-CN: '草稿'
	String get tipDraft => '草稿';

	/// zh-CN: '这里还没有消息'
	String get tipEmptyChatPlaceholder => '这里还没有消息';

	/// zh-CN: '操作失败！'
	String get tipFailed => '操作失败！';

	/// zh-CN: '欢迎使用'
	String get tipGreeting => '欢迎使用';

	/// zh-CN: '或用以下账号登录'
	String get tipProvidersTitleFirst => '或用以下账号登录';

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

	/// zh-CN: '用户在线状态组件'
	String get userOnlineStatusWidget => '用户在线状态组件';

	/// zh-CN: '用户标签关系视图'
	String get userTagRelationView => '用户标签关系视图';

	/// zh-CN: '用户标签保存视图'
	String get userTagSaveView => '用户标签保存视图';

	/// zh-CN: '对方发来的验证消息为：$param'
	String verificationMessageSentByPeerIs({required Object param}) => '对方发来的验证消息为：${param}';

	/// zh-CN: '版本'
	String get version => '版本';

	/// zh-CN: '视频通话'
	String get videoCall => '视频通话';

	/// zh-CN: '查看全部群成员'
	String get viewAllGroupMember => '查看全部群成员';

	/// zh-CN: '语音通话'
	String get voiceCall => '语音通话';

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

	/// zh-CN: '你的反馈是什么?'
	String get whatYourFeedback => '你的反馈是什么?';

	/// zh-CN: '昨天'
	String get yesterday => '昨天';

	/// zh-CN: '你的联系方式'
	String get yourContactInformation => '你的联系方式';

	/// zh-CN: '确认移出'
	String get confirmRemove => '确认移出';

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

	/// zh-CN: '请输入正确的邮箱地址'
	String get pleaseEnterCorrectEmailAddress => '请输入正确的邮箱地址';

	/// zh-CN: '请输入 6 位验证码'
	String get pleaseEnter6DigitVerificationCode => '请输入 6 位验证码';

	/// zh-CN: '验证码已发送'
	String get verificationCodeSent => '验证码已发送';

	/// zh-CN: '发送失败'
	String get sendFailed => '发送失败';

	/// zh-CN: '无需修改'
	String get noChangeNeeded => '无需修改';

	/// zh-CN: '提交失败'
	String get submissionFailed => '提交失败';

	/// zh-CN: '请检查验证码或稍后重试'
	String get checkVerificationCodeOrRetry => '请检查验证码或稍后重试';

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

	/// zh-CN: '您的建议是我们改进的动力'
	String get feedbackSlogan => '您的建议是我们改进的动力';

	/// zh-CN: '新建反馈'
	String get newFeedback => '新建反馈';

	/// zh-CN: '反馈历史'
	String get feedbackHistory => '反馈历史';

	/// zh-CN: '确认删除'
	String get confirmDelete => '确认删除';

	/// zh-CN: '加载中'
	String get processing => _root.common.loading;

	/// zh-CN: '验证码'
	String get verificationCode => '验证码';

	/// zh-CN: '反馈内容'
	String get feedbackContent => '反馈内容';

	/// zh-CN: '官方回复'
	String get officialReply => '官方回复';

	/// zh-CN: '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。'
	String get setPasswordSecurityTips => '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。';

	/// zh-CN: '已隐藏您的位置'
	String get locationHidden => '已隐藏您的位置';

	/// zh-CN: '已显示您的位置'
	String get locationVisible => '已显示您的位置';

	/// zh-CN: '暂无附近的人'
	String get noNearbyPeople => '暂无附近的人';

	/// zh-CN: '点击上方的搜索按钮查找附近的人'
	String get clickSearchButtonToFind => '点击上方的搜索按钮查找附近的人';

	/// zh-CN: '成功'
	String get operationSuccess => _root.common.success;

	/// zh-CN: '错误'
	String get operationFailed => _root.common.error;

	/// zh-CN: '功能开发中...'
	String get featureInDevelopment => '功能开发中...';

	/// zh-CN: '已加入黑名单'
	String get addedToDenylist => '已加入黑名单';

	/// zh-CN: '绑定成功'
	String get bindSuccess => '绑定成功';

	/// zh-CN: '手机号已更新为 $param'
	String mobileUpdatedToParam({required Object param}) => '手机号已更新为 ${param}';

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

	/// zh-CN: '好友可以看到你的在线状态'
	String get showOnlineStatusDesc => '好友可以看到你的在线状态';

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

	/// zh-CN: '账号注销功能暂未开放'
	String get accountDeletionNotAvailable => '账号注销功能暂未开放';

	/// zh-CN: '删除消息'
	String get chatDeleteMessage => '删除消息';

	/// zh-CN: '复制'
	String get chatCopy => '复制';

	/// zh-CN: '保存图片'
	String get chatSaveImage => '保存图片';

	/// zh-CN: '仅删除本地'
	String get chatDeleteLocalOnly => '仅删除本地';

	/// zh-CN: '下载文件'
	String get chatDownloadFile => '下载文件';

	/// zh-CN: '分享文件'
	String get chatShareFile => '分享文件';

	/// zh-CN: '复制链接'
	String get chatCopyLink => '复制链接';

	/// zh-CN: '分享链接'
	String get chatShareLink => '分享链接';

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

	/// zh-CN: '保存'
	String get avatarSave => '保存';

	/// zh-CN: '删除头像'
	String get avatarDeleteAvatar => '删除头像';

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

	/// zh-CN: '输入文件不存在'
	String get videoFileNotFound => '输入文件不存在';

	/// zh-CN: '压缩失败，返回结果为空'
	String get videoCompressFailed => '压缩失败，返回结果为空';

	/// zh-CN: '进一步压缩失败'
	String get videoFurtherCompressFailed => '进一步压缩失败';

	/// zh-CN: '您已被设备【$device】强制下线'
	String forcedOfflineByDevice({required Object device}) => '您已被设备【${device}】强制下线';

	/// zh-CN: '小程序、公众号、文章、朋友圈、和表情等'
	String get searchDescription => '小程序、公众号、文章、朋友圈、和表情等';

	/// zh-CN: '测试直接跳转'
	String get testDirectNavigation => '测试直接跳转';

	/// zh-CN: '标签名称不能超过14个字符'
	String get tagNameTooLong => '标签名称不能超过14个字符';

	/// zh-CN: '标签名称不能包含逗号'
	String get tagNameNoComma => '标签名称不能包含逗号';

	/// zh-CN: '标签名称不能包含前后空格'
	String get tagNameNoLeadingTrailingSpaces => '标签名称不能包含前后空格';

	/// zh-CN: '标签名称不能包含特殊字符'
	String get tagNameNoSpecialChars => '标签名称不能包含特殊字符';

	/// zh-CN: '常用标签'
	String get commonTags => '常用标签';

	/// zh-CN: '加载标签数据失败'
	String get loadingTagDataFailed => '加载标签数据失败';

	/// zh-CN: '请输入内容'
	String get pleaseEnterContent => '请输入内容';

	/// zh-CN: '敬请期待'
	String get comingSoon => '敬请期待';

	/// zh-CN: '聊天背景'
	String get chatBackground => '聊天背景';

	/// zh-CN: '使用系统默认背景'
	String get useSystemDefaultBackground => '使用系统默认背景';

	/// zh-CN: '选择自定义背景图片'
	String get selectCustomBackgroundImage => '选择自定义背景图片';

	/// zh-CN: '当前背景'
	String get currentBackground => '当前背景';

	/// zh-CN: '背景透明度'
	String get backgroundTransparency => '背景透明度';

	/// zh-CN: '默认背景'
	String get defaultBackground => '默认背景';

	/// zh-CN: '纯色背景'
	String get solidColorBackground => '纯色背景';

	/// zh-CN: '选择图片失败'
	String get selectImageFailed => '选择图片失败';

	/// zh-CN: '拍照失败'
	String get takePhotoFailed => '拍照失败';

	/// zh-CN: '选择视频失败'
	String get selectVideoFailed => '选择视频失败';

	/// zh-CN: '录制视频失败'
	String get recordVideoFailed => '录制视频失败';

	/// zh-CN: '选择文件失败'
	String get selectFileFailed => '选择文件失败';

	/// zh-CN: '位置选择功能暂未实现'
	String get locationSelectNotImplemented => '位置选择功能暂未实现';

	/// zh-CN: '选择位置失败'
	String get selectLocationFailed => '选择位置失败';

	/// zh-CN: '名片发送功能暂未实现'
	String get sendCardNotImplemented => '名片发送功能暂未实现';

	/// zh-CN: '发送名片失败'
	String get sendCardFailed => '发送名片失败';

	/// zh-CN: '上传响应数据无效'
	String get uploadResponseInvalid => '上传响应数据无效';

	/// zh-CN: '语音发送成功'
	String get voiceSendSuccess => '语音发送成功';

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

	/// zh-CN: '未找到该消息'
	String get messageNotFound => '未找到该消息';

	/// zh-CN: '未找到会话'
	String get conversationNotFound => '未找到会话';

	/// zh-CN: '已开启'
	String get enabled => '已开启';

	/// zh-CN: '已关闭'
	String get disabled => '已关闭';

	/// zh-CN: '配置可视阈值'
	String get configureVisibleThreshold => '配置可视阈值';

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

	/// zh-CN: '该用户还没有设置个人签名等详细信息'
	String get userNotSetSignature => '该用户还没有设置个人签名等详细信息';

	/// zh-CN: '验证消息'
	String get verificationMessage => '验证消息';

	/// zh-CN: '开启后：消息在被阅读后 $duration 自动销毁'
	String burnEnabledMessage({required Object duration}) => '开启后：消息在被阅读后 ${duration} 自动销毁';

	/// zh-CN: '关闭后：消息不会自动销毁'
	String get burnDisabledMessage => '关闭后：消息不会自动销毁';

	/// zh-CN: '开启后：可见比例≥$percentage%，持续≥$delayms'
	String visibleEnabledMessage({required Object percentage, required Object delayms}) => '开启后：可见比例≥${percentage}%，持续≥${delayms}';

	/// zh-CN: '关闭后：不会基于可视自动已读'
	String get visibleDisabledMessage => '关闭后：不会基于可视自动已读';

	/// zh-CN: '可见比例: $percentage% | 延时: $delayms'
	String visibleThresholdInfo({required Object percentage, required Object delayms}) => '可见比例: ${percentage}% | 延时: ${delayms}';

	/// zh-CN: '暂无群公告'
	String get noGroupAnnouncement => '暂无群公告';

	/// zh-CN: '公告内容不能为空'
	String get announcementContentCannotBeEmpty => '公告内容不能为空';

	/// zh-CN: '公告发布成功'
	String get announcementPublishSuccess => '公告发布成功';

	/// zh-CN: '提示'
	String get tips => '提示';

	/// zh-CN: '功能暂未实现'
	String get featureComingSoon => '功能暂未实现';

	/// zh-CN: '明白了'
	String get understood => '明白了';

	/// zh-CN: '没问题'
	String get noProblem => '没问题';

	/// zh-CN: '马上到'
	String get onMyWay => '马上到';

	/// zh-CN: '强制下线'
	String get sendOfflineCommand => '强制下线';

	/// zh-CN: '已发送下线指令'
	String get offlineCommandSent => '已发送下线指令';

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

	/// zh-CN: '上拉加载更多'
	String get pullUpLoadMore => '上拉加载更多';

	/// zh-CN: '修改成功'
	String get changeSuccess => '修改成功';

	/// zh-CN: '登录密码已更新'
	String get loginPasswordUpdated => '登录密码已更新';

	/// zh-CN: '长度符合'
	String get lengthOk => '长度符合';

	/// zh-CN: '确认新密码'
	String get confirmNewPassword => '确认新密码';

	/// zh-CN: '验证通过'
	String get validationPassed => '验证通过';

	/// zh-CN: '修改失败'
	String get changeFailed => '修改失败';

	/// zh-CN: '已提交'
	String get submitted => '已提交';

	/// zh-CN: '查看安全帮助'
	String get viewSecurityHelp => '查看安全帮助';

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

	/// zh-CN: '举报原因'
	String get momentsReportReason => '举报原因';

	/// zh-CN: '暂无评论'
	String get momentsNoComments => '暂无评论';

	/// zh-CN: '写点什么...'
	String get momentsContentHint => '写点什么...';

	/// zh-CN: '添加媒体'
	String get momentsAddMedia => '添加媒体';

	/// zh-CN: '允许可见 UID 列表（逗号分隔）'
	String get momentsAllowUidsLabel => '允许可见 UID 列表（逗号分隔）';

	/// zh-CN: '评论失败，请稍后重试'
	String get momentsCommentFailed => '评论失败，请稍后重试';

	/// zh-CN: '删除失败，请稍后重试'
	String get momentsDeleteFailed => '删除失败，请稍后重试';

	/// zh-CN: '举报已提交'
	String get momentsReportSubmitted => '举报已提交';

	/// zh-CN: '举报失败，请稍后重试'
	String get momentsReportFailed => '举报失败，请稍后重试';

	/// zh-CN: '加载更多评论'
	String get momentsLoadMoreComments => '加载更多评论';

	/// zh-CN: '媒体上传失败，请稍后重试'
	String get momentsUploadFailed => '媒体上传失败，请稍后重试';

	/// zh-CN: '交易记录'
	String get transactionHistory => '交易记录';

	/// zh-CN: '支付密码设置成功'
	String get paymentPasswordSetSuccess => '支付密码设置成功';

	/// zh-CN: '支付密码设置失败'
	String get paymentPasswordSetFailed => '支付密码设置失败';

	/// zh-CN: '没有找到下一条语音消息'
	String get nextVoiceMessageNotFound => '没有找到下一条语音消息';

	/// zh-CN: '没有下一条语音消息可播放'
	String get noNextVoiceMessage => '没有下一条语音消息可播放';

	/// zh-CN: '下一条语音消息没有音频文件路径'
	String get nextVoiceMessageNoPath => '下一条语音消息没有音频文件路径';

	/// zh-CN: '保存失败'
	String get saveFailed => '保存失败';

	/// zh-CN: '提示'
	String get tip => '提示';

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

	/// zh-CN: '设置背景图片'
	String get setBackgroundImage => '设置背景图片';

	/// zh-CN: '表情'
	String get expression => '表情';

	/// zh-CN: '扩展信息'
	String get extendedInfo => '扩展信息';

	/// zh-CN: '职业'
	String get profession => '职业';

	/// zh-CN: '请输入职业'
	String get pleaseEnterProfession => '请输入职业';

	/// zh-CN: '功能设置'
	String get functionSettings => '功能设置';

	/// zh-CN: '分享资料'
	String get shareProfile => '分享资料';

	/// zh-CN: '将个人资料分享给好友'
	String get shareWithFriends => '将个人资料分享给好友';

	/// zh-CN: '分享二维码'
	String get shareQRCode => '分享二维码';

	/// zh-CN: '复制链接'
	String get copyLink => '复制链接';

	/// zh-CN: '分享到'
	String get shareTo => '分享到';

	/// zh-CN: '分享失败'
	String get shareFailed => '分享失败';

	/// zh-CN: '导出为 JSON 格式'
	String get exportAsJson => '导出为 JSON 格式';

	/// zh-CN: '$param 格式资料已导出并复制到剪贴板'
	String exportSuccessThenCopiedToClipboard({required Object param}) => '${param} 格式资料已导出并复制到剪贴板';

	/// zh-CN: '导出失败'
	String get exportFailed => '导出失败';

	/// zh-CN: '设置地区'
	String get setRegion => '设置地区';

	/// zh-CN: '头像更新成功'
	String get avatarUpdateSuccess => '头像更新成功';

	/// zh-CN: '头像更新失败'
	String get avatarUpdateFailed => '头像更新失败';

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

	/// zh-CN: '上传头像失败'
	String get uploadAvatarFailed => '上传头像失败';

	/// zh-CN: '错误'
	String get error => '错误';

	/// zh-CN: '无法打开网页'
	String get cannotOpenWebpage => '无法打开网页';

	/// zh-CN: '群组ID不能为空'
	String get groupIdCannotBeEmpty => '群组ID不能为空';

	/// zh-CN: '选择图片失败'
	String get selectImageFailedWithError => '选择图片失败';

	/// zh-CN: '上传头像失败'
	String get uploadAvatarFailedWithError => '上传头像失败';

	/// zh-CN: '头像选择成功，上传功能待实现'
	String get avatarSelectedUploadPending => '头像选择成功，上传功能待实现';

	/// zh-CN: '邮箱编辑功能开发中...'
	String get emailEditFeaturePending => '邮箱编辑功能开发中...';

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

	/// zh-CN: '语音录制失败，请重试'
	String get voiceRecordFailedPleaseTryAgain => '语音录制失败，请重试';

	/// zh-CN: '语音文件不存在，请重试'
	String get voiceFileNotFoundPleaseTryAgain => '语音文件不存在，请重试';

	/// zh-CN: '语音文件无法读取，请重试'
	String get voiceFileCannotReadPleaseTryAgain => '语音文件无法读取，请重试';

	/// zh-CN: '语音文件读取失败，请重试'
	String get voiceFileReadFailedPleaseTryAgain => '语音文件读取失败，请重试';

	/// zh-CN: '语音处理异常'
	String get voiceProcessingAbnormal => '语音处理异常';

	/// zh-CN: '语音上传失败，请检查网络连接'
	String get voiceUploadFailedPleaseCheckNetwork => '语音上传失败，请检查网络连接';

	/// zh-CN: '语音发送异常'
	String get voiceSendAbnormal => '语音发送异常';

	/// zh-CN: '语音时长'
	String get voiceDuration => '语音时长';

	/// zh-CN: '播放失败'
	String get playbackFailed => '播放失败';

	/// zh-CN: '撤回操作异常，请重试'
	String get revokeOperationAbnormalPleaseTryAgain => '撤回操作异常，请重试';

	/// zh-CN: '收藏失败，请重试'
	String get collectionFailedPleaseTryAgain => '收藏失败，请重试';

	/// zh-CN: '已发送反应'
	String get reactionSent => '已发送反应';

	/// zh-CN: '秒'
	String get seconds => '秒';

	/// zh-CN: '未能定位到该消息，可能已被删除'
	String get messageCannotLocatedMayBeDeleted => '未能定位到该消息，可能已被删除';

	/// zh-CN: '设置失败，请重试'
	String get settingFailedPleaseTryAgain => '设置失败，请重试';

	/// zh-CN: '部分删除成功：$success 成功，$fail 失败'
	String partialDeleteSuccess({required Object success, required Object fail}) => '部分删除成功：${success} 成功，${fail} 失败';

	/// zh-CN: '收藏的视频消息格式有误，找不到 video uri'
	String get collectedVideoFormatIncorrectCannotFindVideoUri => '收藏的视频消息格式有误，找不到 video uri';

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

	/// zh-CN: '消息发送失败，请检查网络连接'
	String get messageSendFailedPleaseCheckNetwork => '消息发送失败，请检查网络连接';

	/// zh-CN: '正在重试发送...'
	String get retryingSend => '正在重试发送...';

	/// zh-CN: '好的'
	String get quickReplyOk => '好的';

	/// zh-CN: '好的，谢谢'
	String get quickReplyOkThanks => '好的，谢谢';

	/// zh-CN: '灵感'
	String get tagInspiration => '灵感';

	/// zh-CN: '该用户还没有设置个人签名等详细信息'
	String get noDetailedInfo => '该用户还没有设置个人签名等详细信息';

	/// zh-CN: '当前没有新注册的用户 请稍后再来查看'
	String get noNewRegisteredUsers => '当前没有新注册的用户 请稍后再来查看';

	/// zh-CN: '这里显示最近注册的用户，你可以主动添加他们为好友'
	String get newRegisteredUsersTip => '这里显示最近注册的用户，你可以主动添加他们为好友';

	/// zh-CN: '好友请求'
	String get notificationFriendRequest => '好友请求';

	/// zh-CN: '$requesterName 请求添加您为好友'
	String notificationFriendRequestBody({required Object requesterName}) => '${requesterName} 请求添加您为好友';

	/// zh-CN: '群邀请'
	String get notificationGroupInvite => '群邀请';

	/// zh-CN: '$inviterName 邀请您加入群组 $groupName'
	String notificationGroupInviteBody({required Object inviterName, required Object groupName}) => '${inviterName} 邀请您加入群组 ${groupName}';

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

	/// zh-CN: '$param分钟前'
	String lastSeenMinutesAgo({required Object param}) => _root.common.timeMinutesAgo(param: param);

	/// zh-CN: '$param小时前'
	String lastSeenHoursAgo({required Object param}) => _root.common.timeHoursAgo(param: param);

	/// zh-CN: '$param天前'
	String lastSeenDaysAgo({required Object param}) => _root.common.timeDaysAgo(param: param);

	/// zh-CN: '字体大小设置'
	String get fontSettings => _root.common.fontSizeSetting;

	/// zh-CN: '错误'
	String get failed => _root.common.error;

	/// zh-CN: '暂无个人签名'
	String get lazyUserNoSignature => '暂无个人签名';

	/// zh-CN: '暂无收藏内容，快去收藏一些有趣的消息吧'
	String get noFavoritesYet => '暂无收藏内容，快去收藏一些有趣的消息吧';

	/// zh-CN: '这是正文内容，您可以在这里看到不同字体大小的显示效果。'
	String get fontPreviewText => '这是正文内容，您可以在这里看到不同字体大小的显示效果。';

	/// zh-CN: '更小'
	String get smaller => '更小';

	/// zh-CN: '当前：$param1 $param2%'
	String currentFontScale({required Object param1, required Object param2}) => '当前：${param1} ${param2}%';

	/// zh-CN: '邮箱已更新为 $param'
	String emailUpdatedTo({required Object param}) => '邮箱已更新为 ${param}';

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

	/// zh-CN: '外部打开'
	String get groupAlbumPhotoOpenExternal => '外部打开';

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

	/// zh-CN: '${count}分钟'
	String durationMinutes({required Object count}) => '${count}分钟';

	/// zh-CN: '${count}秒'
	String durationSeconds({required Object count}) => '${count}秒';

	/// zh-CN: '请输入1元到10000元之间的金额'
	String get rechargeAmountError => '请输入1元到10000元之间的金额';

	/// zh-CN: '充值成功'
	String get rechargeSuccess => '充值成功';

	/// zh-CN: '确认充值'
	String get rechargeConfirm => '确认充值';

	/// zh-CN: '流水记录'
	String get transactionHistory2 => '流水记录';

	/// zh-CN: '暂无流水记录'
	String get noTransactionHistory => '暂无流水记录';

	/// zh-CN: '— 已全部加载 —'
	String get allLoaded => '— 已全部加载 —';

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

	/// zh-CN: '移除反应'
	String get removeReaction => '移除反应';

	/// zh-CN: '确定要移除 $emoji 反应吗？'
	String removeReactionConfirm({required Object emoji}) => '确定要移除 ${emoji} 反应吗？';

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

	/// zh-CN: '您需要先生成密钥对或从备份中恢复'
	String get e2eeNoKeyDesc => '您需要先生成密钥对或从备份中恢复';

	/// zh-CN: '关于端到端加密'
	String get e2eeAboutTitle => '关于端到端加密';

	/// zh-CN: '• 您的消息在发送前已加密，服务器无法查看内容'
	String get e2eeInfoPoint1 => '• 您的消息在发送前已加密，服务器无法查看内容';

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

	/// zh-CN: '备份管理'
	String get e2eeBackupManage => '备份管理';

	/// zh-CN: '查看备份历史记录'
	String get e2eeBackupManageDesc => '查看备份历史记录';

	/// zh-CN: '确定要生成新的 E2EE 密钥对吗？'
	String get e2eeGenerateKeyConfirm => '确定要生成新的 E2EE 密钥对吗？';

	/// zh-CN: '• 旧消息将无法解密'
	String get e2eeWarnOldMessagesLost => '• 旧消息将无法解密';

	/// zh-CN: '• 需要重新生成备份文件'
	String get e2eeWarnNeedNewBackup => '• 需要重新生成备份文件';

	/// zh-CN: '确认生成'
	String get e2eeConfirmGenerate => '确认生成';

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

	/// zh-CN: '可用分片: $available 个，需要 $required 个代理协助'
	String e2eeShardAvailableInfo({required Object available, required Object required}) => '可用分片: ${available} 个，需要 ${required} 个代理协助';

	/// zh-CN: '没有可用的恢复分片'
	String get e2eeNoRecoveryShards => '没有可用的恢复分片';

	/// zh-CN: '恢复成功'
	String get e2eeRecoverSuccess => '恢复成功';

	/// zh-CN: '恢复失败'
	String get e2eeRecoverFailed => '恢复失败';

	/// zh-CN: '恢复密钥失败，请重试'
	String get e2eeRecoverKeyFailed => '恢复密钥失败，请重试';

	/// zh-CN: '加载分片信息...'
	String get e2eeLoadingShards => '加载分片信息...';

	/// zh-CN: '没有可用的分片'
	String get e2eeNoShards => '没有可用的分片';

	/// zh-CN: '加载失败，请重试'
	String get e2eeLoadFailed => '加载失败，请重试';

	/// zh-CN: '正在联系: $name'
	String e2eeContactingProxy({required Object name}) => '正在联系: ${name}';

	/// zh-CN: '恢复失败，请重试'
	String get e2eeRecoveryFailed => '恢复失败，请重试';

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

	/// zh-CN: '消息无法解密'
	String get e2eeDecryptFailed => '消息无法解密';

	/// zh-CN: '此消息无法解密，可能原因是：'
	String get e2eeDecryptFailedReasons => '此消息无法解密，可能原因是：';

	/// zh-CN: '• 您在其他设备上登录'
	String get e2eeDecryptReasonOtherDevice => '• 您在其他设备上登录';

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

	/// zh-CN: '您的 E2EE 密钥备份已成功生成。'
	String get e2eeBackupExportSuccessBody => '您的 E2EE 密钥备份已成功生成。';

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

	/// zh-CN: '注意：旧消息可能无法访问，这是 E2EE 的正常行为'
	String get e2eeBackupImportSuccessNote => '注意：旧消息可能无法访问，这是 E2EE 的正常行为';

	/// zh-CN: '暂无备份记录'
	String get e2eeBackupNoRecords => '暂无备份记录';

	/// zh-CN: '导出备份后将在此显示历史记录'
	String get e2eeBackupNoRecordsHint => '导出备份后将在此显示历史记录';

	/// zh-CN: '设备 $id'
	String e2eeBackupDeviceLabel({required Object id}) => '设备 ${id}';

	/// zh-CN: '创建于 $time'
	String e2eeBackupCreatedAtLabel({required Object time}) => '创建于 ${time}';

	/// zh-CN: '备份详情'
	String get e2eeBackupDetailTitle => '备份详情';

	/// zh-CN: '设备 ID'
	String get e2eeBackupDeviceIdLabel => '设备 ID';

	/// zh-CN: '备份版本'
	String get e2eeBackupVersionNum => '备份版本';

	/// zh-CN: '创建时间'
	String get e2eeBackupCreatedAtRow => '创建时间';

	/// zh-CN: '文件大小'
	String get e2eeBackupFileSizeRow => '文件大小';

	/// zh-CN: '备注'
	String get e2eeBackupNoteRow => '备注';

	/// zh-CN: '删除备份记录'
	String get e2eeBackupDeleteTitle => '删除备份记录';

	/// zh-CN: '确定要删除此备份记录吗？'
	String get e2eeBackupDeleteConfirm => '确定要删除此备份记录吗？';

	/// zh-CN: '备份记录已删除'
	String get e2eeBackupDeleteSuccess => '备份记录已删除';

	/// zh-CN: '分片设置'
	String get e2eeSocialShardSettings => '分片设置';

	/// zh-CN: '说明：分片将存储在代理设备上，服务端不保存任何分片'
	String get e2eeSocialShardStoredNote => '说明：分片将存储在代理设备上，服务端不保存任何分片';

	/// zh-CN: '添加代理'
	String get e2eeSocialAddProxy => '添加代理';

	/// zh-CN: '请添加代理联系人'
	String get e2eeSocialAddProxyHint => '请添加代理联系人';

	/// zh-CN: '请先添加 $count 个代理'
	String e2eeSocialCreateNeedMore({required Object count}) => '请先添加 ${count} 个代理';

	/// zh-CN: '分片创建成功'
	String get e2eeSocialCreateSuccessTitle => '分片创建成功';

	/// zh-CN: '密钥已分割成 $count 个分片'
	String e2eeSocialTotalShardsInfo({required Object count}) => '密钥已分割成 ${count} 个分片';

	/// zh-CN: '需要 $count 个代理协助即可恢复密钥'
	String e2eeSocialThresholdInfo({required Object count}) => '需要 ${count} 个代理协助即可恢复密钥';

	/// zh-CN: '零信任架构：服务端不保存任何分片'
	String get e2eeSocialZeroTrustNote => '零信任架构：服务端不保存任何分片';

	/// zh-CN: '您还没有创建任何恢复分片'
	String get e2eeSocialNoShards => '您还没有创建任何恢复分片';

	/// zh-CN: '没有代理分片'
	String get e2eeSocialNoProxyShards => '没有代理分片';

	/// zh-CN: '密钥版本'
	String get e2eeSocialKeyVersionLabel => '密钥版本';

	/// zh-CN: '请先生成密钥对'
	String get e2eeTransferErrNoKey => '请先生成密钥对';

	/// zh-CN: '初始化失败，请重试'
	String get e2eeTransferErrInitFailed => '初始化失败，请重试';

	/// zh-CN: '接收方没有可用的公钥'
	String get e2eeTransferErrNoRecipientKey => '接收方没有可用的公钥';

	/// zh-CN: '密钥未找到'
	String get e2eeTransferErrKeyNotFound => '密钥未找到';

	/// zh-CN: '创建传输会话失败，请重试'
	String get e2eeTransferErrCreateFailed => '创建传输会话失败，请重试';

	/// zh-CN: '创建传输会话'
	String get e2eeTransferCreateSessionBtn => '创建传输会话';

	/// zh-CN: '传输会话已创建'
	String get e2eeTransferSessionCreated => '传输会话已创建';

	/// zh-CN: '请输入有效的用户 ID'
	String get e2eeTransferUidEmptyError => '请输入有效的用户 ID';

	/// zh-CN: '传输成功！'
	String get e2eeTransferSuccess => '传输成功！';

	/// zh-CN: '传输失败，请重试'
	String get e2eeTransferFailed => '传输失败，请重试';

	/// zh-CN: '处理中...'
	String get e2eeTransferProcessingMsg => '处理中...';

	/// zh-CN: '传输成功'
	String get e2eeTransferSuccessTitle => '传输成功';

	/// zh-CN: '密钥已成功传输到当前设备'
	String get e2eeTransferSuccessBody => '密钥已成功传输到当前设备';

	/// zh-CN: '扫描错误: $error'
	String e2eeTransferScanError({required Object error}) => '扫描错误: ${error}';

	/// zh-CN: '无法获取设备 ID'
	String get e2eeTransferErrNoDeviceId => '无法获取设备 ID';

	/// zh-CN: '密码加密失败'
	String get passwordEncryptFailed => '密码加密失败';

	/// zh-CN: '配置获取超时: 请检查网络连接或服务端状态'
	String get initConfigTimeout => '配置获取超时: 请检查网络连接或服务端状态';

	/// zh-CN: '网络故障或服务故障 (HTTP $code)'
	String initConfigNetworkError({required Object code}) => '网络故障或服务故障 (HTTP ${code})';

	/// zh-CN: '服务故障协议有误'
	String get initConfigProtocolError => '服务故障协议有误';

	/// zh-CN: '配置获取失败，请检查网络连接'
	String get initConfigFetchFailed => '配置获取失败，请检查网络连接';

	/// zh-CN: '无法获取文件，请重试或使用相册选择'
	String get attachmentGetFileFailed => '无法获取文件，请重试或使用相册选择';

	/// zh-CN: '文件获取失败，Android 9 可能存在兼容性问题'
	String get attachmentGetFileFailedAndroid9 => '文件获取失败，Android 9 可能存在兼容性问题';

	/// zh-CN: '无法获取图片数据，请重试'
	String get attachmentGetImageDataFailed => '无法获取图片数据，请重试';

	/// zh-CN: '无法获取原始图片数据'
	String get attachmentGetOriginalImageFailed => '无法获取原始图片数据';

	/// zh-CN: '保存失败，请重试'
	String get saveFailedRetry => '保存失败，请重试';

	/// zh-CN: '下载文件不存在，请重试'
	String get downloadFileNotFound => '下载文件不存在，请重试';

	/// zh-CN: '文件校验失败，正在重新下载 ($retry/$max)'
	String downloadHashRetrying({required Object retry, required Object max}) => '文件校验失败，正在重新下载 (${retry}/${max})';

	/// zh-CN: '文件多次校验失败，请检查网络后重试'
	String get downloadHashFailed => '文件多次校验失败，请检查网络后重试';

	/// zh-CN: '传输到新设备'
	String get e2eeTransferToNewDevice => '传输到新设备';

	/// zh-CN: '待处理的传输'
	String get e2eeTransferPendingSection => '待处理的传输';

	/// zh-CN: '加载失败'
	String get e2eeTransferLoadFailed => '加载失败';

	/// zh-CN: '无法加载待处理的传输，请重试'
	String get e2eeTransferLoadFailedDesc => '无法加载待处理的传输，请重试';

	/// zh-CN: '暂无待处理的传输'
	String get e2eeTransferNoPending => '暂无待处理的传输';

	/// zh-CN: '当有设备向您发送密钥时，会显示在这里'
	String get e2eeTransferNoPendingDesc => '当有设备向您发送密钥时，会显示在这里';

	/// zh-CN: '您已有足够的分片可以恢复密钥'
	String get e2eeSocialEnoughShards => '您已有足够的分片可以恢复密钥';

	/// zh-CN: '还有 $count 个分片...'
	String e2eeSocialMoreShards({required Object count}) => '还有 ${count} 个分片...';

	/// zh-CN: '加载好友列表失败，请重试'
	String get e2eeProxyLoadFriendsFailed => '加载好友列表失败，请重试';

	/// zh-CN: '该好友没有可用的公钥'
	String get e2eeProxyNoPublicKey => '该好友没有可用的公钥';

	/// zh-CN: '获取 $name 的公钥失败'
	String e2eeProxyGetKeyFailed({required Object name}) => '获取 ${name} 的公钥失败';

	/// zh-CN: '选择代理失败，请重试'
	String get e2eeProxySelectFailed => '选择代理失败，请重试';

	/// zh-CN: '暂无好友'
	String get e2eeProxyNoFriends => '暂无好友';

	/// zh-CN: '请先添加好友后再设置恢复代理'
	String get e2eeProxyNoFriendsHint => '请先添加好友后再设置恢复代理';

	/// zh-CN: '至少需要 $count 个信任的联系人，已选择 $selected 个'
	String e2eeProxyNeedMore({required Object count, required Object selected}) => '至少需要 ${count} 个信任的联系人，已选择 ${selected} 个';

	/// zh-CN: '确认选择 ($count 个代理)'
	String e2eeProxyConfirmCount({required Object count}) => '确认选择 (${count} 个代理)';

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

	/// zh-CN: '抢红包'
	String get redPacketOpen => '抢红包';

	/// zh-CN: '红包详情'
	String get redPacketDetail => '红包详情';

	/// zh-CN: '发起转账'
	String get transferSend => '发起转账';

	/// zh-CN: '确认收钱'
	String get transferAccept => '确认收钱';

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

	/// zh-CN: '领到金额：$amount 元'
	String grabAmountYuan({required Object amount}) => '领到金额：${amount} 元';

	/// zh-CN: '转账金额：$amount 元'
	String transferAmountYuan({required Object amount}) => '转账金额：${amount} 元';

	/// zh-CN: '余额不足'
	String get insufficientBalance => '余额不足';

	/// zh-CN: '去充值'
	String get goToRecharge => '去充值';

	/// zh-CN: '提现成功'
	String get withdrawSuccess => '提现成功';

	/// zh-CN: '确认提现'
	String get withdrawConfirm => '确认提现';

	/// zh-CN: '请输入不低于1元的金额'
	String get withdrawAmountError => '请输入不低于1元的金额';

	/// zh-CN: '请输入提现账号'
	String get withdrawAccountEmpty => '请输入提现账号';

	/// zh-CN: '提现方式'
	String get withdrawMethod => '提现方式';

	/// zh-CN: '提现账号'
	String get withdrawAccount => '提现账号';

	/// zh-CN: '暂无历史记录'
	String get noHistory => '暂无历史记录';

	/// zh-CN: '请输入金额'
	String get enterAmount => '请输入金额';

	/// zh-CN: '转账给好友'
	String get transferDefaultRemark => '转账给好友';

	/// zh-CN: '转账最低金额为 0.1 元'
	String get transferMinAmountError => '转账最低金额为 0.1 元';

	/// zh-CN: '当前为：拼手气红包'
	String get redPacketCurrentLucky => '当前为：拼手气红包';

	/// zh-CN: '当前为：普通红包'
	String get redPacketCurrentNormal => '当前为：普通红包';

	/// zh-CN: '改为普通红包'
	String get redPacketSwitchToNormal => '改为普通红包';

	/// zh-CN: '改为拼手气红包'
	String get redPacketSwitchToLucky => '改为拼手气红包';

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
}

// Path: complaint
class Translations$complaint$zh_CN {
	Translations$complaint$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '投诉'
	String get complaint => '投诉';
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

	/// zh-CN: '申请好友'
	String get applyFriend => '申请好友';

	/// zh-CN: '申请好友逻辑'
	String get applyFriendLogic => '申请好友逻辑';

	/// zh-CN: '申请$param'
	String applyParam({required Object param}) => '申请${param}';

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

	/// zh-CN: '你还没有拉黑任何用户 被拉黑的用户将无法给你发送消息'
	String get denylistEmptyDesc => '你还没有拉黑任何用户 被拉黑的用户将无法给你发送消息';

	/// zh-CN: '收藏、人名、群名、标签等'
	String get favoriteGroupTagsEtc => '收藏、人名、群名、标签等';

	/// zh-CN: '群组备注视图'
	String get groupRemarkView => '群组备注视图';

	/// zh-CN: '群聊的备注仅自己可见'
	String get groupRemarkVisibility => '群聊的备注仅自己可见';

	/// zh-CN: '新的朋友'
	String get newFriend => '新的朋友';

	/// zh-CN: '把他推荐给朋友'
	String get recommendToFriend => '把他推荐给朋友';

	/// zh-CN: '备注'
	String get remark => '备注';

	/// zh-CN: '备注和标签'
	String get remarksTags => '备注和标签';

	/// zh-CN: '应用筛选'
	String get applyFilters => '应用筛选';

	/// zh-CN: '选择一个群'
	String get selectAGroup => '选择一个群';

	/// zh-CN: '选择好友'
	String get selectFriend => '选择好友';

	/// zh-CN: '选择朋友'
	String get selectFriends => '选择朋友';

	/// zh-CN: '选择或输入标签'
	String get selectOrEnterTag => '选择或输入标签';

	/// zh-CN: '标签'
	String get tags => '标签';

	/// zh-CN: '告诉朋友'
	String get tellFriend => '告诉朋友';

	/// zh-CN: '标签名称不能为空'
	String get tagNameRequired => '标签名称不能为空';

	/// zh-CN: '建议标签'
	String get suggestedTags => '建议标签';

	/// zh-CN: '标签管理'
	String get tagManagement => '标签管理';

	/// zh-CN: '当前标签 ($param)'
	String currentTags({required Object param}) => '当前标签 (${param})';

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

	/// zh-CN: '重要'
	String get tagImportant => '重要';

	/// zh-CN: '紧急'
	String get tagUrgent => '紧急';

	/// zh-CN: '工作'
	String get tagWork => '工作';

	/// zh-CN: '生活'
	String get tagLife => '生活';

	/// zh-CN: '学习'
	String get tagStudy => '学习';

	/// zh-CN: '娱乐'
	String get tagEntertainment => '娱乐';

	/// zh-CN: '旅行'
	String get tagTravel => '旅行';

	/// zh-CN: '美食'
	String get tagFood => '美食';

	/// zh-CN: '健康'
	String get tagHealth => '健康';

	/// zh-CN: '家庭'
	String get tagFamily => '家庭';

	/// zh-CN: '朋友'
	String get tagFriends => '朋友';

	/// zh-CN: '项目'
	String get tagProject => '项目';

	/// zh-CN: '想法'
	String get tagIdeas => '想法';

	/// zh-CN: '备忘'
	String get tagMemo => '备忘';

	/// zh-CN: '已发送'
	String get friendRequestSent => '已发送';

	/// zh-CN: '最多可添加 8 个标签'
	String get channelMaxTagsCount => '最多可添加 8 个标签';

	/// zh-CN: '输入标签...'
	String get tagInputHint => '输入标签...';
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

	/// zh-CN: '附近的人逻辑'
	String get peopleNearbyLogic => '附近的人逻辑';

	/// zh-CN: '扫一扫'
	String get scan => '扫一扫';

	/// zh-CN: '扫描结果'
	String get scanResult => '扫描结果';

	/// zh-CN: '扫描结果'
	String get scannerResult => '扫描结果';

	/// zh-CN: '发现'
	String get titleDiscover => '发现';

	/// zh-CN: '我的频道'
	String get myChannels => '我的频道';

	/// zh-CN: '频道广场'
	String get channelSquare => '频道广场';

	/// zh-CN: '其他用户可以通过搜索找到我'
	String get otherUsersCanFindMe => '其他用户可以通过搜索找到我';

	/// zh-CN: '朋友圈'
	String get moments => '朋友圈';

	/// zh-CN: '举报动态'
	String get momentsReport => '举报动态';

	/// zh-CN: '补充说明'
	String get momentsReportDesc => '补充说明';

	/// zh-CN: '评论'
	String get momentsComments => '评论';

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

	/// zh-CN: '不给谁看 UID 列表（逗号分隔）'
	String get momentsDenyUidsLabel => '不给谁看 UID 列表（逗号分隔）';

	/// zh-CN: '已恢复上次未发送的草稿'
	String get momentsDraftRestored => '已恢复上次未发送的草稿';

	/// zh-CN: '网络异常，显示的是缓存内容'
	String get momentsFeedStale => '网络异常，显示的是缓存内容';

	/// zh-CN: '发现'
	String get discover => '发现';

	/// zh-CN: '摇一摇'
	String get shake => '摇一摇';

	/// zh-CN: '打开频道'
	String get openChannel => '打开频道';

	/// zh-CN: '付费频道内容已锁定'
	String get paidChannelLocked => '付费频道内容已锁定';

	/// zh-CN: '已扫描'
	String get webQRScanned => '已扫描';
}

// Path: error
class Translations$error$zh_CN {
	Translations$error$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '需要重启应用'
	String get restartRequired => '需要重启应用';

	/// zh-CN: '网络失败指引'
	String get networkFailureGuidance => '网络失败指引';

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

	/// zh-CN: '开始恢复密钥（需要 $required 个代理协助）'
	String e2eeStartRecoveryBtn({required Object required}) => '开始恢复密钥（需要 ${required} 个代理协助）';

	/// zh-CN: '分片不足（需要 $required 个，当前 $current 个）'
	String e2eeInsufficientShardBtn({required Object required, required Object current}) => '分片不足（需要 ${required} 个，当前 ${current} 个）';

	/// zh-CN: '加密超时，请检查网络连接后重试'
	String get e2eeErrTimeout => '加密超时，请检查网络连接后重试';

	/// zh-CN: '网络错误，加密失败，消息未发送'
	String get e2eeErrNetwork => '网络错误，加密失败，消息未发送';

	/// zh-CN: '标题不能为空'
	String get liveRoomTitleRequired => '标题不能为空';
}

// Path: group
class Translations$group$zh_CN {
	Translations$group$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '理财通'
	String get financialManagement => '理财通';

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

	/// zh-CN: '加入群聊'
	String get groupJoin => '加入群聊';

	/// zh-CN: '退出群聊'
	String get groupLeave => '退出群聊';

	/// zh-CN: '群管理'
	String get groupManagement => '群管理';

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

	/// zh-CN: '普通成员'
	String get groupMember => '普通成员';

	/// zh-CN: '设为管理员'
	String get setAdmin => '设为管理员';

	/// zh-CN: '转让群主'
	String get transferGroup => '转让群主';

	/// zh-CN: '加入时间'
	String get joinTime => '加入时间';

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

	/// zh-CN: '分组描述（可选）'
	String get categoryDesc => '分组描述（可选）';

	/// zh-CN: '暂无分组'
	String get noCategory => '暂无分组';

	/// zh-CN: '创建第一个分组吧'
	String get createFirst => '创建第一个分组吧';

	/// zh-CN: '添加群聊到分组'
	String get addGroup => '添加群聊到分组';

	/// zh-CN: '从分组移除'
	String get removeGroup => '从分组移除';

	/// zh-CN: '删除分组'
	String get deleteCategory => '删除分组';

	/// zh-CN: '确定要删除该分组吗？群聊不会被删除。'
	String get deleteCategoryConfirm => '确定要删除该分组吗？群聊不会被删除。';

	/// zh-CN: '分组创建成功'
	String get categoryCreated => '分组创建成功';

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

	/// zh-CN: '提醒'
	String get reminder => '提醒';

	/// zh-CN: '不提醒'
	String get noReminder => '不提醒';

	/// zh-CN: '暂无日程'
	String get noSchedule => '暂无日程';

	/// zh-CN: '日程创建成功'
	String get scheduleCreated => '日程创建成功';

	/// zh-CN: '日程更新成功'
	String get scheduleUpdated => '日程更新成功';

	/// zh-CN: '提前15分钟'
	String get reminder15min => '提前15分钟';

	/// zh-CN: '提前1小时'
	String get reminder1hour => '提前1小时';

	/// zh-CN: '提前1天'
	String get reminder1day => '提前1天';

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

	/// zh-CN: '标签颜色'
	String get tagColor => '标签颜色';

	/// zh-CN: '暂无标签'
	String get noTag => '暂无标签';

	/// zh-CN: '标签添加成功'
	String get tagAdded => '标签添加成功';

	/// zh-CN: '标签已移除'
	String get tagRemoved => '标签已移除';

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

	/// zh-CN: '群作业'
	String get title => '群作业';

	/// zh-CN: '创建任务'
	String get createTask => '创建任务';

	/// zh-CN: '任务标题'
	String get taskTitle => '任务标题';

	/// zh-CN: '任务描述'
	String get taskDescription => '任务描述';

	/// zh-CN: '指派给'
	String get assignTo => '指派给';

	/// zh-CN: '截止时间'
	String get deadline => '截止时间';

	/// zh-CN: '无截止时间'
	String get noDeadline => '无截止时间';

	/// zh-CN: '暂无任务'
	String get noTask => '暂无任务';

	/// zh-CN: '全部'
	String get all => '全部';

	/// zh-CN: '待完成'
	String get pending => '待完成';

	/// zh-CN: '已完成'
	String get completed => '已完成';

	/// zh-CN: '任务创建成功'
	String get taskCreated => '任务创建成功';

	/// zh-CN: '任务已提交'
	String get taskSubmitted => '任务已提交';

	/// zh-CN: '任务已完成'
	String get taskCompleted => '任务已完成';

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

	/// zh-CN: '任务ID'
	String get taskId => '任务ID';

	/// zh-CN: '待审核'
	String get pendingReview => '待审核';

	/// zh-CN: '任务ID缺失，无法查看详情'
	String get taskIdMissing => '任务ID缺失，无法查看详情';

	/// zh-CN: '任务ID缺失，无法提交'
	String get taskIdMissingSubmit => '任务ID缺失，无法提交';
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

	/// zh-CN: '投票选项'
	String get voteOptions => '投票选项';

	/// zh-CN: '添加选项'
	String get addOption => '添加选项';

	/// zh-CN: '允许多选'
	String get allowMultiple => '允许多选';

	/// zh-CN: '匿名投票'
	String get anonymous => '匿名投票';

	/// zh-CN: '截止时间'
	String get deadline => '截止时间';

	/// zh-CN: '无截止时间'
	String get noDeadline => '无截止时间';

	/// zh-CN: '暂无投票'
	String get noVote => '暂无投票';

	/// zh-CN: '投票已结束'
	String get voteEnded => '投票已结束';

	/// zh-CN: '共 $count 票'
	String totalVotes({required Object count}) => '共 ${count} 票';

	/// zh-CN: '投票成功'
	String get voteSuccess => '投票成功';

	/// zh-CN: '已投票'
	String get hasVoted => '已投票';

	/// zh-CN: '查看结果'
	String get viewResults => '查看结果';

	/// zh-CN: '已取消投票'
	String get cancelVoteSuccess => '已取消投票';

	/// zh-CN: '取消失败，请稍后重试'
	String get cancelVoteFailed => '取消失败，请稍后重试';

	/// zh-CN: '结束失败，请稍后重试'
	String get endVoteFailed => '结束失败，请稍后重试';

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
}

// Path: main
class Translations$main$zh_CN {
	Translations$main$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '修改'
	String get change => '修改';

	/// zh-CN: '电影演出'
	String get entertainment => '电影演出';

	/// zh-CN: '生活缴费'
	String get lifePayment => '生活缴费';

	/// zh-CN: '医疗健康'
	String get medicalHealth => '医疗健康';

	/// zh-CN: '美团外卖'
	String get meituanDelivery => '美团外卖';

	/// zh-CN: '腾讯服务'
	String get tencentService => '腾讯服务';

	/// zh-CN: '交通出行'
	String get traffic => '交通出行';

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

	/// zh-CN: '找到条形码！'
	String get barcodeFound => '找到条形码！';

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

	/// zh-CN: '修改名称视图'
	String get changeNameView => '修改名称视图';

	/// zh-CN: '修改$param'
	String changeParam({required Object param}) => '修改${param}';

	/// zh-CN: '从相册选择'
	String get chooseFromAlbum => '从相册选择';

	/// zh-CN: '清理'
	String get clean => '清理';

	/// zh-CN: '验证码已发送到$param'
	String codeSentToParam({required Object param}) => '验证码已发送到${param}';

	/// zh-CN: '验证码已发送到$param'
	String codeSentToType({required Object param}) => '验证码已发送到${param}';

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

	/// zh-CN: '更早'
	String get earlier => '更早';

	/// zh-CN: '英国英语'
	String get enGb => '英国英语';

	/// zh-CN: '美国英语'
	String get enUs => '美国英语';

	/// zh-CN: '启用'
	String get enable => '启用';

	/// zh-CN: '例:'
	String get example => '例:';

	/// zh-CN: '已过期'
	String get expired => '已过期';

	/// zh-CN: '额外项目'
	String get extraItem => '额外项目';

	/// zh-CN: '面对面建群逻辑'
	String get faceToFaceLogic => '面对面建群逻辑';

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

	/// zh-CN: '前往清理'
	String get goClean => '前往清理';

	/// zh-CN: '很棒'
	String get good => '很棒';

	/// zh-CN: '挂断'
	String get hangup => '挂断';

	/// zh-CN: '已设置'
	String get haveSet => '已设置';

	/// zh-CN: 'HTTP解析'
	String get httpParse => 'HTTP解析';

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

	/// zh-CN: '直播'
	String get liveBroadcast => '直播';

	/// zh-CN: '直播间列表视图'
	String get liveRoomListView => '直播间列表视图';

	/// zh-CN: '推流页面'
	String get publisherPage => '推流页面';

	/// zh-CN: '订阅者'
	String get subscriber => '订阅者';

	/// zh-CN: '正在退出登录...'
	String get loggingOut => '正在退出登录...';

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

	/// zh-CN: '重要'
	String get markImportant => '重要';

	/// zh-CN: '标记为重要消息'
	String get markImportantDesc => '标记为重要消息';

	/// zh-CN: '收藏'
	String get markStar => '收藏';

	/// zh-CN: '收藏此消息'
	String get markStarDesc => '收藏此消息';

	/// zh-CN: '待办'
	String get markTodo => '待办';

	/// zh-CN: '标记为待办事项'
	String get markTodoDesc => '标记为待办事项';

	/// zh-CN: '多选'
	String get multiSelect => '多选';

	/// zh-CN: '多选模式'
	String get multiSelectMode => '多选模式';

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

	/// zh-CN: '快速筛选'
	String get quickFilters => '快速筛选';

	/// zh-CN: '引用'
	String get quote => '引用';

	/// zh-CN: '最近使用'
	String get recentlyUsed => '最近使用';

	/// zh-CN: '松开结束'
	String get releaseEnd => '松开结束';

	/// zh-CN: '还可输入 $param 个字符'
	String remainingChars({required Object param}) => '还可输入 ${param} 个字符';

	/// zh-CN: '移出群聊'
	String get kickMember => '移出群聊';

	/// zh-CN: '成员详情'
	String get memberDetail => '成员详情';

	/// zh-CN: '成员角色'
	String get memberRole => '成员角色';

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

	/// zh-CN: '他人发送的'
	String get sentByOthers => '他人发送的';

	/// zh-CN: '设置$param'
	String setParam({required Object param}) => '设置${param}';

	/// zh-CN: '设置'
	String get setting => '设置';

	/// zh-CN: '已经有账号了？'
	String get siginQ => '已经有账号了？';

	/// zh-CN: '用$param登录'
	String signInWith({required Object param}) => '用${param}登录';

	/// zh-CN: '来源'
	String get source => '来源';

	/// zh-CN: '说话时间太短'
	String get speakingTooShort => '说话时间太短';

	/// zh-CN: '速度'
	String get speed => '速度';

	/// zh-CN: '收藏'
	String get star => _root.main.markStar;

	/// zh-CN: '还需'
	String get stillNeeded => '还需';

	/// zh-CN: '存储空间'
	String get storageSpace => '存储空间';

	/// zh-CN: '服务条款'
	String get termOfServices => '服务条款';

	/// zh-CN: '文本'
	String get text => '文本';

	/// zh-CN: '本周'
	String get thisWeek => '本周';

	/// zh-CN: '时间范围'
	String get timeRange => '时间范围';

	/// zh-CN: '星期一,星期二,星期三,星期四,星期五,星期六,星期日'
	String get timeWeekdays => '星期一,星期二,星期三,星期四,星期五,星期六,星期日';

	/// zh-CN: '我的'
	String get titleMine => '我的';

	/// zh-CN: '广场'
	String get titleSquare => '广场';

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

	/// zh-CN: '最多$param个字'
	String upToWords({required Object param}) => '最多${param}个字';

	/// zh-CN: '升级'
	String get upgrade => '升级';

	/// zh-CN: '已使用空间'
	String get usedSpace => '已使用空间';

	/// zh-CN: '网页视图'
	String get webView => '网页视图';

	/// zh-CN: '你'
	String get you => '你';

	/// zh-CN: '这让你感觉如何?'
	String get yourFeel => '这让你感觉如何?';

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

	/// zh-CN: '当前'
	String get current => '当前';

	/// zh-CN: '发布'
	String get publish => '发布';

	/// zh-CN: '隐私政策'
	String get privacyPolicy => '隐私政策';

	/// zh-CN: '服务条款'
	String get termsOfService => '服务条款';

	/// zh-CN: '加载中'
	String get saving => _root.common.loading;

	/// zh-CN: '看一看'
	String get topStories => '看一看';

	/// zh-CN: '系统默认'
	String get systemDefault => '系统默认';

	/// zh-CN: '自定义'
	String get custom => '自定义';

	/// zh-CN: '预览区域'
	String get previewArea => '预览区域';

	/// zh-CN: '简约纹理'
	String get simpleTexture => '简约纹理';

	/// zh-CN: '渐变蓝'
	String get gradientBlue => '渐变蓝';

	/// zh-CN: '渐变紫'
	String get gradientPurple => '渐变紫';

	/// zh-CN: '已复制到剪贴板'
	String get copiedToClipboard => '已复制到剪贴板';

	/// zh-CN: '已复制链接'
	String get copiedLink => '已复制链接';

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

	/// zh-CN: '评论...'
	String get commentPlaceholder => '评论...';

	/// zh-CN: '延时毫秒 (>=100)'
	String get delayMsLabel => '延时毫秒 (>=100)';

	/// zh-CN: '已处理'
	String get processed => '已处理';

	/// zh-CN: '导出'
	String get export => '导出';

	/// zh-CN: '学校'
	String get school => '学校';

	/// zh-CN: '兴趣爱好'
	String get hobbiesAndInterests => '兴趣爱好';

	/// zh-CN: '兴趣爱好'
	String get interests => '兴趣爱好';

	/// zh-CN: '请输入学校'
	String get pleaseEnterSchool => '请输入学校';

	/// zh-CN: '请输入兴趣爱好'
	String get pleaseEnterInterests => '请输入兴趣爱好';

	/// zh-CN: '管理个人信息的可见性'
	String get manageVisibility => '管理个人信息的可见性';

	/// zh-CN: '导出个人资料到本地'
	String get exportToLocal => '导出个人资料到本地';

	/// zh-CN: '导出为文本格式'
	String get exportAsText => '导出为文本格式';

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

	/// zh-CN: '发布中...'
	String get publishing => '发布中...';

	/// zh-CN: '正在删除中，请稍候...'
	String get deletingInProgressPleaseWait => '正在删除中，请稍候...';

	/// zh-CN: '用户1'
	String get testUser1 => '用户1';

	/// zh-CN: '用户2'
	String get testUser2 => '用户2';

	/// zh-CN: '用户3'
	String get testUser3 => '用户3';

	/// zh-CN: '用户4'
	String get testUser4 => '用户4';

	/// zh-CN: '用户5'
	String get testUser5 => '用户5';

	/// zh-CN: '收藏中...'
	String get collecting => '收藏中...';

	/// zh-CN: '用户'
	String get user => '用户';

	/// zh-CN: '推荐'
	String get recommended => '推荐';

	/// zh-CN: '更大'
	String get larger => '更大';

	/// zh-CN: '当前长度：$param1 / $param2'
	String currentLength({required Object param1, required Object param2}) => '当前长度：${param1} / ${param2}';

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

	/// zh-CN: '社交恢复'
	String get e2eeSocialRecovery => '社交恢复';

	/// zh-CN: '通过信任的联系人协助恢复密钥'
	String get e2eeSocialRecoveryDesc => '通过信任的联系人协助恢复密钥';

	/// zh-CN: '密钥 ID'
	String get e2eeKeyIdLabel => '密钥 ID';

	/// zh-CN: '• 此操作不可撤销'
	String get e2eeWarnIrreversible => '• 此操作不可撤销';

	/// zh-CN: '• 需要从备份恢复或生成新密钥'
	String get e2eeWarnNeedRestoreOrNew => '• 需要从备份恢复或生成新密钥';

	/// zh-CN: '我知道了'
	String get gotIt => '我知道了';

	/// zh-CN: '恢复密钥'
	String get e2eeRecoverKeyTitle => '恢复密钥';

	/// zh-CN: '可以恢复密钥'
	String get e2eeCanRecoverKey => '可以恢复密钥';

	/// zh-CN: '分片数量不足'
	String get e2eeInsufficientShards => '分片数量不足';

	/// zh-CN: '代理用户: $uid'
	String e2eeProxyUser({required Object uid}) => '代理用户: ${uid}';

	/// zh-CN: '分片 $index / $total'
	String e2eeShardLabel({required Object index, required Object total}) => '分片 ${index} / ${total}';

	/// zh-CN: '重新加载'
	String get e2eeReloadShards => '重新加载';

	/// zh-CN: '恢复中...'
	String get e2eeRecovering => '恢复中...';

	/// zh-CN: '密钥已成功恢复'
	String get e2eeKeyRestored => '密钥已成功恢复';

	/// zh-CN: '已使用 $count 个代理分片'
	String e2eeUsedShards({required Object count}) => '已使用 ${count} 个代理分片';

	/// zh-CN: '准备恢复...'
	String get e2eePreparing => '准备恢复...';

	/// zh-CN: '进度: $collected / $total 个分片'
	String e2eeRecoveryProgressLabel({required Object collected, required Object total}) => '进度: ${collected} / ${total} 个分片';

	/// zh-CN: '正在收集分片 ($collected/$total)...'
	String e2eeCollectingShards({required Object collected, required Object total}) => '正在收集分片 (${collected}/${total})...';

	/// zh-CN: '分片收集完成，正在重组密钥...'
	String get e2eeShardsCollected => '分片收集完成，正在重组密钥...';

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

	/// zh-CN: '总分片数'
	String get e2eeSocialTotalShards => '总分片数';

	/// zh-CN: '恢复阈值'
	String get e2eeSocialThreshold => '恢复阈值';

	/// zh-CN: '恢复密钥时需要 $count 个代理协助'
	String e2eeSocialThresholdHint({required Object count}) => '恢复密钥时需要 ${count} 个代理协助';

	/// zh-CN: '选择恢复代理'
	String get e2eeSocialSelectProxy => '选择恢复代理';

	/// zh-CN: '需要 $count 个信任的联系人作为代理'
	String e2eeSocialProxyNeeded({required Object count}) => '需要 ${count} 个信任的联系人作为代理';

	/// zh-CN: '用户 $uid'
	String e2eeSocialProxyDefaultName({required Object uid}) => '用户 ${uid}';

	/// zh-CN: '分片已通过 WebSocket 直接发送到代理设备存储'
	String get e2eeSocialShardSentViaWs => '分片已通过 WebSocket 直接发送到代理设备存储';

	/// zh-CN: '已发送到 $sent 个代理设备（共 $total 个）'
	String e2eeSocialSentCount({required Object sent, required Object total}) => '已发送到 ${sent} 个代理设备（共 ${total} 个）';

	/// zh-CN: '管理分片'
	String get e2eeSocialManageTitle => '管理分片';

	/// zh-CN: '我的分片'
	String get e2eeSocialMyShards => '我的分片';

	/// zh-CN: '代理分片'
	String get e2eeSocialProxyShards => '代理分片';

	/// zh-CN: '分片 $idx / $total'
	String e2eeSocialShardOf({required Object idx, required Object total}) => '分片 ${idx} / ${total}';

	/// zh-CN: '活跃'
	String get e2eeSocialShardActive => '活跃';

	/// zh-CN: '已使用'
	String get e2eeSocialShardUsed => '已使用';

	/// zh-CN: '分片有效'
	String get e2eeSocialShardValid => '分片有效';

	/// zh-CN: '用户 $uid 的密钥分片'
	String e2eeSocialUserShard({required Object uid}) => '用户 ${uid} 的密钥分片';

	/// zh-CN: '代理用户'
	String get e2eeSocialProxyUserLabel => '代理用户';

	/// zh-CN: '恢复阈值'
	String get e2eeSocialRecoveryThresholdLabel => '恢复阈值';

	/// zh-CN: '分片编号'
	String get e2eeSocialShardIndexLabel => '分片编号';

	/// zh-CN: '请在新设备上扫描此二维码'
	String get e2eeTransferQRHint => '请在新设备上扫描此二维码';

	/// zh-CN: '二维码将在 $time 过期'
	String e2eeTransferQRExpiry({required Object time}) => '二维码将在 ${time} 过期';

	/// zh-CN: '刷新二维码'
	String get e2eeTransferRefreshQR => '刷新二维码';

	/// zh-CN: '输入接收方用户 ID'
	String get e2eeTransferEnterUidTitle => '输入接收方用户 ID';

	/// zh-CN: '接收方用户 ID'
	String get e2eeTransferUidPlaceholder => '接收方用户 ID';

	/// zh-CN: '正在接受传输...'
	String get e2eeTransferReceiving => '正在接受传输...';

	/// zh-CN: '设备间传输'
	String get e2eeTransferPageTitle => '设备间传输';

	/// zh-CN: '待处理的密钥传输'
	String get e2eeTransferPendingItem => '待处理的密钥传输';

	/// zh-CN: '点击查看详情'
	String get e2eeTransferPendingItemDesc => '点击查看详情';

	/// zh-CN: '查看'
	String get e2eeTransferView => '查看';

	/// zh-CN: '社交恢复'
	String get e2eeSocialTitle => '社交恢复';

	/// zh-CN: '可以恢复密钥'
	String get e2eeSocialCanRecover => '可以恢复密钥';

	/// zh-CN: '设置恢复代理'
	String get e2eeSocialSetupProxy => '设置恢复代理';

	/// zh-CN: '选择信任的联系人作为恢复代理'
	String get e2eeSocialChooseProxy => '选择信任的联系人作为恢复代理';

	/// zh-CN: '现有恢复分片'
	String get e2eeSocialExistingShards => '现有恢复分片';

	/// zh-CN: '恢复密钥'
	String get e2eeSocialRecoverKeyTitle => '恢复密钥';

	/// zh-CN: '使用代理的分片恢复密钥'
	String get e2eeSocialRecoverKeyDesc => '使用代理的分片恢复密钥';

	/// zh-CN: '管理分片'
	String get e2eeSocialManageShardsTitle => '管理分片';

	/// zh-CN: '查看和管理所有恢复分片'
	String get e2eeSocialManageShardsDesc => '查看和管理所有恢复分片';

	/// zh-CN: '零信任架构：服务端不存储分片，直接联系代理'
	String get e2eeSocialZeroTrustHint1 => '零信任架构：服务端不存储分片，直接联系代理';

	/// zh-CN: '零信任架构：分片存储在代理设备'
	String get e2eeSocialZeroTrustHint2 => '零信任架构：分片存储在代理设备';

	/// zh-CN: '零信任架构：分片由代理设备存储，服务端不接触明文'
	String get e2eeSocialZeroTrustHint3 => '零信任架构：分片由代理设备存储，服务端不接触明文';

	/// zh-CN: '请至少选择 $count 个代理'
	String e2eeProxyMinCount({required Object count}) => '请至少选择 ${count} 个代理';

	/// zh-CN: '选择恢复代理'
	String get e2eeProxySelectTitle => '选择恢复代理';

	/// zh-CN: '已选 $selected / $total'
	String e2eeProxySelectedCount({required Object selected, required Object total}) => '已选 ${selected} / ${total}';

	/// zh-CN: '已达到最少代理数量'
	String get e2eeProxyReachedMin => '已达到最少代理数量';

	/// zh-CN: '直播间标题'
	String get liveRoomTitleLabel => '直播间标题';

	/// zh-CN: '请输入直播间标题'
	String get liveRoomTitleHint => '请输入直播间标题';
}

// Path: mention
class Translations$mention$zh_CN {
	Translations$mention$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '@提及'
	String get title => '@提及';

	/// zh-CN: '暂无@提及'
	String get noMention => '暂无@提及';

	/// zh-CN: '全部已读'
	String get allRead => '全部已读';

	/// zh-CN: '标记为已读'
	String get markAsRead => '标记为已读';

	/// zh-CN: '新的@提及'
	String get newMention => '新的@提及';

	/// zh-CN: '来自群聊'
	String get fromGroup => '来自群聊';

	/// zh-CN: '来自聊天'
	String get fromChat => '来自聊天';

	/// zh-CN: '查看上下文'
	String get viewContext => '查看上下文';

	/// zh-CN: '$count 条新提及'
	String mentionCount({required Object count}) => '${count} 条新提及';

	/// zh-CN: '仅管理员可以 @所有人'
	String get mentionAllDenied => '仅管理员可以 @所有人';

	/// zh-CN: '消息定位信息缺失，无法跳转'
	String get navInfoMissing => '消息定位信息缺失，无法跳转';
}

// Path: momentFriendPicker
class Translations$momentFriendPicker$zh_CN {
	Translations$momentFriendPicker$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '选择好友'
	String get title => '选择好友';

	/// zh-CN: '指定可见'
	String get titleAllow => '指定可见';

	/// zh-CN: '不给谁看'
	String get titleDeny => '不给谁看';

	/// zh-CN: '确定'
	String get confirm => '确定';

	/// zh-CN: '确定($count)'
	String confirmWithCount({required Object count}) => '确定(${count})';

	/// zh-CN: '已选 $count 人'
	String selectedCount({required Object count}) => '已选 ${count} 人';

	/// zh-CN: '暂无好友'
	String get emptyFriends => '暂无好友';

	/// zh-CN: '按标签选'
	String get tagsLabel => '按标签选';

	/// zh-CN: '暂无标签'
	String get emptyTags => '暂无标签';

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

	/// zh-CN: '消息通知'
	String get title => '消息通知';

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

	/// zh-CN: '清空所有通知?'
	String get clearConfirmTitle => '清空所有通知?';

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

// Path: passport
class Translations$passport$zh_CN {
	Translations$passport$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '找回密码'
	String get retrievePassword => '找回密码';

	/// zh-CN: '请输入邮箱'
	String get hintEmail => '请输入邮箱';

	/// zh-CN: '请输入手机号'
	String get hintMobile => '请输入手机号';

	/// zh-CN: '忘记密码？'
	String get forgetPassword => '忘记密码？';

	/// zh-CN: '注册账号'
	String get register => '注册账号';

	/// zh-CN: '请输入密码'
	String get hintPassword => '请输入密码';

	/// zh-CN: '请输入验证码'
	String get hintVerifyCode => '请输入验证码';

	/// zh-CN: '获取验证码'
	String get getVerifyCode => '获取验证码';

	/// zh-CN: '已有账号？'
	String get hasAccount => '已有账号？';

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
}

// Path: splash
class Translations$splash$zh_CN {
	Translations$splash$zh_CN.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh-CN: '畅所欲言，自在沟通'
	String get slogan => '畅所欲言，自在沟通';
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
			'account.mobileRecharge' => '手机充值',
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
			'account.existingPassword' => '现有密码',
			'account.forgotPassword' => '忘记密码？',
			'account.gender' => '性别',
			'account.genderSaving' => '保存中...',
			'account.groupQrcode' => '群二维码',
			'account.hintLoginAccount' => '账号/邮箱',
			'account.logOut' => '退出登录',
			'account.areYouSureLogOut' => '确定要退出登录吗？',
			'account.login' => '登录',
			'account.loginDeviceManagement' => '登录设备管理',
			'account.loginEmail' => '登录邮箱',
			'account.logoutAccount' => '注销账号',
			'account.mobile' => '手机',
			'account.mobileQuickLogin' => '一键登录',
			'account.myAccount' => '我的账号',
			'account.myQrcode' => '我的二维码',
			'account.newPassword' => '新的密码',
			'account.newlyRegisteredPeople' => '新注册的人',
			'account.nickname' => '昵称',
			'account.nicknameChangeVisibility' => '昵称修改后，只会在此群内显示，群内成员都可以看见。',
			'account.nicknameCharsRemaining' => ({required Object param}) => '还可输入${param}个字符',
			'account.nicknameHint' => '请输入昵称',
			'account.nicknameSaving' => '保存中...',
			'account.paramLogin' => ({required Object param}) => '${param}登录',
			'account.password' => '密码',
			'account.recentlyRegisteredUser' => '最近注册用户',
			'account.recoverCodePasswordDesc' => '我们会将密码恢复码发送到您的邮箱。',
			'account.recoverPassword' => '找回密码',
			'account.recoverPasswordDesc' => '请输入您的邮箱地址，我们将把密码重置码发送给您。',
			'account.recoverPasswordIntro' => '不要感觉不好，这是常有的事。',
			'account.birthday' => '生日',
			'account.region' => '地区',
			'account.retypePassword' => '重新输入密码',
			'account.scanQrCode' => '扫描二维码',
			'account.securityCenter' => '安全中心',
			'account.setNickname' => '设置昵称',
			'account.signature' => '个性签名',
			'account.signup' => '注册',
			'account.signupFormDesc' => '请填写此表格以完成注册',
			'account.sourceQrcode' => '通过扫一扫添加',
			'account.switchAccount' => '切换账号',
			'account.changeEmail' => '修改邮箱',
			'account.bindEmail' => '绑定邮箱',
			'account.currentEmail' => '当前邮箱',
			'account.newEmailSameAsCurrent' => '新邮箱与当前绑定一致',
			'account.newMobileSameAsCurrent' => '新手机号与当前绑定一致',
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
			'account.codeSentToMobileParam' => ({required Object param}) => '已发送至 ${param}',
			'account.privacyLogoutAccount' => '注销账号',
			'account.wallet' => '钱包',
			'account.changeLoginPassword' => '修改登录密码',
			'account.loginExpiredTitle' => '提示',
			'account.otherDevice' => '其他设备',
			'account.loginPassword' => '登录密码',
			'account.loginPasswordDesc' => '用于登录IMBoy账号',
			'account.oldPassword' => '旧密码',
			'account.enterOldPassword' => '请输入旧密码',
			'account.enterNewPassword' => '请输入新密码',
			'account.enterNewPasswordAgain' => '请再次输入新密码',
			'account.balance' => '余额',
			'account.recharge' => '充值',
			'account.withdraw' => '提现',
			'account.paymentPassword' => '支付密码',
			'account.setPaymentPassword' => '设置支付密码',
			'account.enterPaymentPassword' => '请输入支付密码',
			'account.myQRCode' => '我的二维码',
			'account.profile' => '个人资料',
			'account.setGender' => '设置性别',
			'account.setBirthday' => '设置生日',
			'account.sentToEmail' => ({required Object param}) => '已发送至 ${param}',
			'account.nicknameRules' => '• 昵称长度为2-24个字符 • 不能仅包含空白字符或表情符号 • 不能包含敏感词汇 • 修改后将在所有聊天中显示',
			'account.refreshDeviceKey' => '刷新设备密钥',
			'account.refreshDeviceKeyHint' => '如果消息无法解密，点击此按钮刷新密钥',
			'account.refreshingDeviceKey' => '正在刷新设备密钥...',
			'account.deviceKeyRefreshed' => '设备密钥已刷新',
			'account.rechargeTitle' => '充值',
			'account.rechargeAmountHint' => '请输入充值金额（元），1元～10000元',
			'account.rechargeAmountExample' => '例如：100',
			'account.payMethodTitle' => '选择支付方式',
			'account.payMethodWallet' => '钱包余额',
			'account.payMethodMock' => '模拟支付（开发环境）',
			'account.payMethodAlipay' => '支付宝',
			'account.payMethodWechat' => '微信支付',
			'account.payMethodComingSoon' => '该支付方式即将开通，敬请期待',
			'account.payCancelled' => '支付已取消',
			'account.e2eeDeviceTransfer' => '设备间传输',
			'account.e2eeDeviceTransferDesc' => '通过二维码直接传输密钥到新设备',
			'account.e2eeDeviceIdLabel' => '设备 ID',
			'account.webQRLoginTitle' => '扫码登录',
			'account.webQRLoginHint' => '使用 ImBoy 手机版扫描二维码',
			'account.webSwitchToPassword' => '使用账号密码登录',
			'account.webPasswordLoginTitle' => '账号登录',
			'account.webAccountHint' => '请输入账号/手机号/邮箱',
			'account.webPasswordHint' => '请输入密码',
			'account.e2eeTransferFromOldDevice' => '从旧设备接收密钥',
			'account.pleaseRelogin' => '请重新登录',
			'channel.title' => '频道',
			'channel.loading' => '加载中...',
			'channel.subscribed' => '已订阅',
			'channel.managed' => '管理中',
			'channel.discover' => '发现频道',
			'channel.search' => '搜索频道',
			'channel.create' => '创建频道',
			'channel.searchHint' => '搜索频道名称或ID',
			'channel.searchTip' => '输入关键词搜索频道',
			'channel.noResults' => '未找到相关频道',
			'channel.noRecommendedChannels' => '暂无推荐频道 稍后再来看看吧',
			'channel.noSubscribedChannels' => '暂无订阅的频道 去发现更多精彩频道吧',
			'channel.noManagedChannels' => '暂无管理的频道 创建一个频道开始你的创作',
			'channel.noMessages' => '暂无消息',
			'channel.subscribers' => '订阅者',
			'channel.pinned' => '置顶',
			'channel.view' => '查看',
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
			'channel.typeLabel' => '频道类型',
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
			'channel.reactions' => '互动',
			'channel.selectReaction' => '选择表情',
			'channel.react' => '互动',
			'channel.admin' => '管理',
			'channel.settings' => '设置',
			'channel.editChannel' => '编辑频道',
			'channel.editChannelDesc' => '修改频道名称、描述等信息',
			'channel.editChannelNotImplemented' => '编辑频道功能即将上线',
			'channel.manageAdmins' => '管理管理员',
			'channel.manageAdminsDesc' => '添加或移除频道管理员',
			'channel.manageAdminsNotImplemented' => '管理管理员功能即将上线',
			'channel.manageSubscribers' => '管理订阅者',
			'channel.manageSubscribersDesc' => '查看和管理频道订阅者',
			'channel.manageSubscribersNotImplemented' => '管理订阅者功能即将上线',
			'channel.deleteChannel' => '删除频道',
			'channel.deleteChannelDesc' => '删除后将无法恢复',
			'channel.deleteChannelConfirm' => '确定要删除该频道吗？此操作不可恢复。',
			'channel.deleteChannelNotImplemented' => '删除频道功能即将上线',
			'channel.channelDeleted' => '频道已删除',
			'channel.deleteChannelFailed' => '删除频道失败',
			'channel.writeMessage' => '发布消息...',
			'channel.publishFailed' => '发布失败',
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
			'channel.userId' => '用户ID',
			'channel.userIdHint' => '请输入用户ID',
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
			'channel.roleUnknown' => '未知',
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
			'chat.bankCard' => '银行卡',
			'chat.cards' => '张',
			'chat.jdShopping' => '京东购物',
			'chat.receivePayment' => '收付款',
			'chat.alreadyEntered' => '你已经输入过了',
			'chat.alreadyMember' => '已是成员',
			'chat.appSqliteFileSizeExplain' => '当前账号本地生成的sqlite文件大小；可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。',
			'chat.attachmentProvider' => '附件提供者',
			'chat.audioMessage' => '语音消息',
			'chat.awaitingReply' => '待回复',
			'chat.businessCard' => '名片',
			'chat.busyTryAgainLater' => '对方正忙，请稍后重试',
			'chat.later' => '以后再说',
			'chat.peerIsTyping' => ({required Object name}) => '${name} 正在输入...',
			'chat.changeGroupChatName' => '修改群聊名称后，将在群内通知其他成员。',
			'chat.chatHistory' => '聊天记录',
			'chat.chatHoldDownTalk' => '按住说话',
			'chat.chatMessage' => '聊天消息',
			'chat.chatMomentSportDataEtc' => '聊天、朋友圈、运动数据等',
			'chat.chatSettingMute' => '消息免打扰',
			'chat.chatSettingMuteDesc' => '关闭此聊天的消息通知',
			'chat.chatSettingMuted' => '已开启免打扰',
			'chat.chatSettingPin' => '置顶聊天',
			'chat.chatSettingPinDesc' => '将此聊天置顶到列表顶部',
			'chat.chatSettingUnmuted' => '已关闭免打扰',
			'chat.chatStatusSending' => '发送中',
			'chat.chatStatusSent' => '已发送',
			'chat.chatStatusDelivered' => '已送达',
			'chat.chatStatusSeen' => '已读',
			'chat.chatStatusSendingDesc' => '消息正在发送...',
			'chat.chatStatusSentDesc' => '消息已发送',
			'chat.chatStatusDeliveredDesc' => '消息已送达',
			'chat.chatStatusSeenDesc' => '消息已读',
			'chat.createGroupF2f' => '面对面建群',
			'chat.displayProfile' => '显示你的资料',
			'chat.file' => '文件',
			'chat.fileMessage' => '[文件]',
			'chat.fileSize' => '文件大小',
			'chat.forgotPasswordPinCodeView' => '忘记密码验证码视图',
			'chat.forward' => '转发',
			'chat.forwardReply' => '转发回复',
			'chat.forwardTo' => '转发给',
			'chat.forwardToFriend' => '转发给朋友',
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
			'chat.justChat' => '仅聊天',
			'chat.location' => '位置',
			'chat.exportMyData' => '导出我的数据',
			'chat.exportDataDesc' => '导出你的个人信息、联系人和聊天记录',
			'chat.message' => '消息',
			'chat.messageHandlingMixin' => '消息处理混入',
			'chat.messageMarkTitle' => '消息标记',
			'chat.customMessage' => '自定义消息',
			'chat.card' => '名片',
			'chat.messageType' => '消息类型',
			'chat.messageVisitCardBuilder' => '消息名片构建器',
			'chat.messageWasWithdrawn' => '撤回了一条消息',
			'chat.messageWasWithdrawnWithTitle' => ({required Object param}) => '${param}撤回了一条消息',
			'chat.messageWebrtcBuilder' => '音视频消息构建器',
			'chat.momentStatus' => '朋友圈和状态',
			'chat.offline' => '离线',
			'chat.online' => '在线',
			'chat.paramAlreadyExist' => ({required Object param}) => '${param}已存在',
			'chat.pin' => '置顶',
			'chat.pinChat' => '置顶聊天',
			'chat.pinned' => '已置顶',
			'chat.privateReply' => '私聊回复',
			'chat.qrCodeBusinessCard' => '二维码名片',
			'chat.quoteReply' => '引用回复',
			'chat.rating' => '评级',
			'chat.readAgreeParam' => ({required Object param}) => '已经阅读并同意${param}',
			'chat.recentChats' => '最近聊天',
			'chat.recentForwards' => '最近转发',
			'chat.remindMeLater' => '下次再说',
			'chat.quickReplyManage' => '管理快捷回复',
			'chat.quickReplyEmpty' => '暂无快捷回复，点击右下角添加',
			'chat.quickReplyDuplicate' => '内容已存在',
			'chat.quickReplyMaxReached' => ({required Object max}) => '最多 ${max} 条',
			'chat.quickReplyHint' => '输入内容...',
			'chat.muteMember' => '禁言成员',
			'chat.unmuteMember' => '取消禁言',
			'chat.muteUntil' => '禁言至',
			'chat.muted' => '已禁言',
			'chat.mutedFor' => ({required Object label}) => '禁言 ${label}',
			'chat.muteUnitMinutes' => ({required Object count}) => '${count} 分钟',
			'chat.muteUnitHours' => ({required Object count}) => '${count} 小时',
			'chat.muteUnitDays' => ({required Object count}) => '${count} 天',
			'chat.youAreMuted' => '你已被禁言',
			'chat.youAreMutedWithTime' => ({required Object minutes}) => '你已被禁言，剩余 ${minutes} 分钟',
			'chat.repliedAt' => '回复于',
			'chat.reply' => '回复',
			'chat.replyTo' => '回复',
			'chat.resendCode' => '重发验证码',
			'chat.revoke' => '撤回',
			'chat.scanQrCodeBusinessCard' => '扫描二维码名片',
			'chat.singleChat' => '单聊',
			'chat.privateChat' => '私聊',
			'chat.groupMessage' => '群消息',
			'chat.sendFriendRequest' => '发送添加朋友申请',
			'chat.sendMsgRejected' => '消息已发出，但被对方拒收了。',
			'chat.sendMessage' => '发消息',
			'chat.sendSeparatelyTo' => '分别发送给',
			'chat.sendTo' => '发送给',
			'chat.send' => _root.common.buttonSend,
			'chat.releaseConvertToText' => '松开 转文字',
			'chat.voiceReleaseCancelSend' => '松开 取消发送',
			'chat.voiceReleaseCancel' => '松开 取消',
			'chat.voiceSlideHint' => '上滑 取消 / 转文字',
			'chat.convertToText' => '转文字',
			'chat.sender' => '发送者',
			'chat.sending' => '正在发送...',
			'chat.signatureInputHint' => '签名输入提示',
			'chat.signaturePlaceholder' => '签名占位符',
			'chat.signupIntro' => '确认码已发送到您的邮箱， 请输入确认码确认您的帐户。',
			'chat.socialProfile' => '社交资料',
			'chat.status' => '状态',
			'chat.storageSpaceData' => '存储空间和数据',
			'chat.sureOpenTheFile' => '确定要打开文件吗？',
			'chat.textMessage' => '文本消息',
			'chat.titleMessage' => '消息',
			'chat.topChat' => '置顶聊天',
			'chat.unpin' => '取消置顶',
			'chat.unsupportedFileType' => '不支持的文件类型',
			'chat.userData' => '用户数据',
			'chat.video' => '视频',
			'chat.videoMessage' => '[视频]',
			'chat.viewAttachments' => '浏览附件',
			'chat.viewLargeImage' => '查看大图',
			'chat.voice' => '语音',
			'chat.voiceInput' => '语音输入',
			'chat.voiceMessage' => '语音消息',
			'chat.youWithdrewAMessage' => '你撤回了一条消息',
			'chat.formatCheck' => '格式检查',
			'chat.featureRequest' => '功能请求',
			'chat.resendCodeWithCount' => ({required Object count}) => '重新发送（${count}秒）',
			'chat.chatResend' => '重新发送',
			'chat.chatReply' => '回复',
			'chat.chatOpenFile' => '打开文件',
			'chat.chatOpenLink' => '打开链接',
			'chat.avatarSelectPhoto' => '选择照片',
			'chat.avatarTakePhoto' => '拍照',
			'chat.avatarSelectFromAlbum' => '从相册选择',
			'chat.profileExportProfile' => '导出资料',
			'chat.momentsSend' => '发送',
			'chat.videoCompressInProgress' => '已有压缩任务在进行中',
			'chat.videoCompressing' => '正在压缩视频...',
			'chat.loginExpiredMessage' => '登录过期,请重新登录',
			'chat.geometricPattern' => '几何图案',
			'chat.ripplePattern' => '波纹图案',
			'chat.customImage' => '自定义图片',
			'chat.voiceRecordResultEmpty' => '语音录制结果为空',
			'chat.voiceFileInvalid' => '语音文件无效',
			'chat.burnAfterReading' => '阅后即焚',
			'chat.burnReadBadge' => '阅后',
			'chat.visibleThresholdRead' => '可视阈值已读',
			'chat.readThresholdDelay' => '已读阈值与延时',
			'chat.goodReadability' => '可读性良好',
			'chat.profileCompleteness' => '资料完善度',
			'chat.tagStatistics' => '标签统计',
			'chat.alreadySent' => '已发送',
			'chat.visibleRatioLabel' => '可见比例 (0.1~1.0)',
			'chat.unsupportedMessageType' => '不支持的消息类型',
			'chat.passwordMismatch' => '两次密码不一致',
			'chat.pleaseTryAgainLater' => '请稍后重试',
			'chat.momentsSelectVideo' => '选择视频',
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
			'chat.pleaseEnterSignature' => '请输入个性签名',
			'chat.exportProfile' => '导出资料',
			'chat.setSignature' => '设置个性签名',
			'chat.setAvatar' => '设置头像',
			'chat.fastForward' => ({required Object seconds}) => '快进 ${seconds}秒',
			'chat.messageId' => '消息ID',
			'chat.chatType' => '聊天类型',
			'chat.voiceFileEmptyPleaseTryAgain' => '语音文件为空，请重试',
			'chat.sendingVoice' => '正在发送语音...',
			'chat.deletingMessage' => '正在删除...',
			'chat.deletingLocalMessage' => '正在删除本地消息...',
			'chat.quickReplyReceived' => '收到',
			'chat.quickReplyThanks' => '谢谢',
			'chat.quickReplyWait' => '稍等',
			'chat.messageMute' => _root.chat.chatSettingMute,
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
			'chat.e2eeReady' => '准备就绪',
			'chat.e2eeReadyWithShards' => ({required Object count}) => '准备就绪（${count} 个分片）',
			'chat.webFeatureMultiDevice' => '多设备同步',
			'chat.webFeatureMultiDeviceDesc' => '在手机和电脑之间无缝切换，消息实时同步',
			'chat.webFeatureE2EE' => '端到端加密',
			'chat.webFeatureE2EEDesc' => '所有消息都经过端到端加密，确保隐私安全',
			_ => null,
		} ?? switch (path) {
			'chat.webFeatureFileTransfer' => '文件传输',
			'chat.webFeatureFileTransferDesc' => '拖拽即可发送文件，支持各种格式',
			'chat.webQRStatusWaiting' => '打开 ImBoy 手机版 > 设置 > 扫一扫',
			'chat.webQRStatusScanned' => '请在手机上点击"确认登录"',
			'chat.webQRStatusVerifying' => '正在验证...',
			'chat.webQRStatusExpired' => '请点击刷新重新扫码',
			'chat.e2eeErrInvalidFormat' => '消息格式错误，加密失败',
			'chat.e2eeSocialCreateTitle' => '创建恢复分片',
			'chat.e2eeSocialCreateBtn' => '创建分片',
			'chat.e2eeSocialCreateFailTitle' => '创建失败',
			'chat.e2eeSocialCreateFailBody' => '创建分片失败，请重试',
			'chat.e2eeSocialCreateFirst' => '创建分片后才能看到内容',
			'chat.e2eeSocialUsedAtLabel' => '使用时间',
			'chat.e2eeTransferSendTitle' => '发送密钥到新设备',
			'chat.e2eeTransferCreateBtn' => '创建',
			'chat.e2eeTransferReceiveTitle' => '从旧设备接收密钥',
			'chat.e2eeTransferSendDesc' => '通过二维码将密钥传输到新设备',
			'chat.e2eeTransferReceiveDesc' => '扫描旧设备二维码接收密钥',
			'chat.e2eeSocialStatus' => ({required Object status}) => '状态: ${status}',
			'chat.e2eeSocialCreateShardsTitle' => '创建恢复分片',
			'chat.e2eeSocialCreateShardsDesc' => '将密钥分割成多个分片，存储到代理设备（服务端不保存）',
			'chat.e2eeProxyNeedAtLeast' => ({required Object count}) => '请选择至少 ${count} 个代理',
			'chat.e2eeRecreatingKey' => '正在重新创建密钥...',
			'chat.e2eeKeyRecreated' => '密钥已重新创建',
			'chat.e2eeRecoveryNewDeviceTitle' => '检测到新设备登录',
			'chat.e2eeRecoveryNewDeviceBody' => '为保护消息安全，本设备已生成新的端对端加密密钥。\n\n历史消息使用旧设备的密钥加密，需先恢复密钥才能查看。你可以通过「设备转移」「社交恢复」或「本地备份导入」恢复。',
			'chat.e2eeRecoveryDecryptFailedTitle' => '无法解密此消息',
			'chat.e2eeRecoveryDecryptFailedBody' => '此消息由其他设备的密钥加密。\n\n若你更换了设备或重新安装了应用，请恢复加密密钥后再查看历史消息。',
			'chat.e2eeRecoveryLater' => '稍后',
			'chat.e2eeRecoveryGoRecover' => '去恢复',
			'chat.e2eeRecoveryBannerText' => '检测到加密历史消息，需恢复密钥后才能查看，点击前往恢复',
			'chat.liveRoomCreateTitle' => '创建直播间',
			'chat.liveRoomCreating' => '创建中...',
			'chat.liveRoomWatch' => '观看直播',
			'chat.switchToVoiceInput' => '切换到语音输入',
			'chat.switchToKeyboardInput' => '切换到键盘输入',
			'common.about' => '关于',
			'common.aboutApp' => '关于应用',
			'common.accept' => '接受',
			'common.acceptFriendRequest' => '通过好友验证',
			'common.answer' => '接听',
			'common.declineCall' => '拒绝',
			'common.reconnecting' => '网络不佳，正在重连…',
			'common.minimize' => '最小化',
			'common.switchCamera' => '切换摄像头',
			'common.addFriend' => '添加朋友',
			'common.addPhoneContact' => '添加手机联系人',
			'common.creditCardRepayment' => '信用卡还款',
			'common.smallChange' => '零钱',
			'common.addTag' => '添加标签',
			'common.addToContacts' => '添加到通讯录',
			'common.addToDenylist' => '加入黑名单',
			'common.added' => '已添加',
			'common.addedToDenylistTips' => '已添加至黑名单，你将不再收到对方的消息',
			'common.agreeContinue' => '同意并继续',
			'common.all' => '全部',
			'common.allSenders' => '所有发送者',
			'common.allTags' => '全部标签',
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
			'common.buttonBind' => '绑定',
			'common.bindMobileAndEmailTips' => '绑定手机号和邮箱，让您的账户更安全',
			'common.bindNow' => '立即绑定',
			'common.buttonCancel' => '取消',
			'common.buttonCreate' => '创建',
			'common.buttonChangePassword' => '修改密码',
			'common.phoneInputHint' => '请输入手机号',
			'common.buttonClose' => '关闭',
			'common.buttonConfirm' => '确认',
			'common.buttonContinue' => '继续',
			'common.buttonCopy' => '复制',
			'common.buttonDelete' => '删除',
			'common.buttonDeleteAccount' => '注销账户',
			'common.buttonInviteCode' => '邀请码',
			'common.buttonLogin' => '登录',
			'common.buttonLogout' => '退出登录',
			'common.buttonNextStep' => '下一步',
			'common.buttonOk' => '确定',
			'common.buttonRegister' => '注册',
			'common.buttonResetPassword' => '重置密码',
			'common.buttonRetry' => '重试',
			'common.buttonSave' => '保存',
			'common.buttonSelectFromAlbum' => '从相册选择',
			'common.buttonSend' => '发送',
			'common.buttonSetEmpty' => '置空',
			'common.buttonSubmit' => '提交',
			'common.buttonTakingPictures' => '拍照',
			'common.cacheTips' => '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。',
			'common.callDuration' => '通话时长',
			'common.calling' => '正在通话',
			'common.canNotAddYourselfFriend' => '你不能添加自己为好友',
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
			'common.chatSettingBackgroundCustom' => '已设置自定义背景',
			'common.chatSettingBackgroundDefault' => '默认背景',
			'common.chatSettingBackgroundSelectorTip' => '背景选择功能开发中',
			'common.chatSettingBackgroundSuccess' => '背景设置成功',
			'common.chatSettingClearHistory' => '清空聊天记录',
			'common.chatSettingClearHistoryConfirm' => '确定要清空所有聊天记录吗？此操作不可恢复。',
			'common.chatSettingClearHistoryDesc' => '删除所有消息，此操作不可恢复',
			'common.chatSettingClearedSuccess' => '清空成功',
			'common.chatSettingPinnedSuccess' => '置顶成功',
			'common.chatSettingUnpinnedSuccess' => '取消置顶',
			'common.chatSettings' => '聊天设置',
			'common.chatStatusFailed' => '发送失败',
			'common.chatStatusFailedDesc' => '发送失败，点击重试',
			'common.chatErrorInDenylist' => '对方已将您加入黑名单',
			'common.chatErrorInDenylistDesc' => '消息无法发送，对方已将您加入黑名单',
			'common.chatErrorNotAFriend' => '对方不是您的好友',
			'common.chatErrorNotAFriendDesc' => '消息无法发送，请先添加对方为好友',
			'common.checkForUpdates' => '检查更新',
			'common.clearAll' => '清除全部',
			'common.clearChatRecord' => '清空聊天记录',
			'common.complaintSuccess' => '投诉已提交',
			'common.complaintFailed' => '投诉失败，请稍后再试',
			'common.confirmCode' => '确认码',
			'common.confirmCodeError' => '确认码为空',
			'common.confirmCodeSuccess' => '账户已确认。',
			'common.confirmDeleteChatRecord' => '确定删除聊天记录吗？',
			'common.confirmNewFriend' => '确认新好友',
			'common.confirmNewFriendLogic' => '确认新好友逻辑',
			'common.confirmRecoverSuccess' => '密码修改成功。',
			'common.contactSetting' => '联系人设置',
			'common.contactSettingTag' => '联系人设置标签',
			'common.contactTagListLogic' => '联系人标签列表逻辑',
			'common.contactTags' => '联系人标签',
			'common.contactInfoNotSynced' => '联系人信息未同步',
			'common.continueDownloading' => '继续下载',
			'common.copy' => '复制',
			'common.coupon' => '卡券',
			'common.createGroupF2fConfirmTips' => '这些朋友也将进入群聊',
			'common.createGroupF2fTips' => '和身边的朋友输入同样的四个数字，进入同一个群聊',
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
			'common.errorAccessDenied' => ({required Object param}) => '对 ${param} 的访问被拒绝',
			'common.errorCliVersionNotFound' => _root.common.error,
			'common.errorEmptyDirectory' => ({required Object param}) => '${param} 是空的',
			'common.errorFailedConnectServer' => _root.common.error,
			'common.errorFailedToConnect' => _root.common.error,
			'common.errorFileNotFound' => ({required Object param}) => '在 ${param} 中没有找到文件',
			'common.errorFolderNotFound' => ({required Object param}) => '文件夹 ${param} 未找到',
			'common.errorHttpNotSupported' => _root.common.error,
			'common.errorInternalServer' => _root.common.error,
			'common.errorInvalid' => ({required Object param}) => '${param} 是无效的',
			'common.errorInvalidDart' => _root.common.error,
			'common.errorInvalidFileOrDirectory' => _root.common.error,
			'common.errorInvalidJson' => _root.common.error,
			'common.errorInvalidRequest' => _root.common.error,
			'common.errorLengthBetween' => ({required Object param, required Object min, required Object max}) => '${param} 长度必须在 ${min} 和 ${max} 之间',
			'common.errorManyRequest' => '请求过于频繁',
			'common.errorNoPackageToRemove' => _root.common.error,
			'common.errorNoValidFileOrUrl' => _root.common.error,
			'common.errorNonexistentDirectory' => _root.common.error,
			'common.errorPackageNotFound' => _root.common.error,
			'common.errorPassword' => '密码错误',
			'common.errorRequestForbidden' => _root.common.error,
			'common.errorRequestSyntax' => _root.common.error,
			'common.errorRequired' => ({required Object param}) => '${param} 是必须的',
			'common.errorRequiredPath' => _root.common.error,
			'common.errorRetypePassword' => _root.common.error,
			'common.errorSame' => ({required Object param1, required Object param2}) => '${param1} 和 ${param2} 必须相同',
			'common.errorServerDown' => _root.common.error,
			'common.errorServerRefused' => _root.common.error,
			'common.errorSpecialCharactersInKey' => _root.common.error,
			'common.errorUnexpected' => _root.common.error,
			'common.errorUnnecessaryParameter' => _root.common.error,
			'common.errorUnnecessaryParameterPlural' => _root.common.error,
			'common.errorUpdateCli' => _root.common.error,
			'common.failedGetLatLong' => _root.common.errorNetwork,
			'common.failedGetMapTryAgain' => _root.common.errorNetwork,
			'common.failedRequestPleaseCheckNetwork' => _root.common.errorNetwork,
			'common.feedback' => '反馈建议',
			'common.feedbackBuilder' => '反馈构建器',
			'common.feedbackContentRequired' => '反馈内容不能为空',
			'common.feedbackDetails' => '反馈建议明细',
			'common.feedbackModel' => '反馈模型',
			'common.feedbackReplyModel' => '反馈回复模型',
			'common.feedbackSuccessMsg' => '你的反馈问题我们已经收到了，会尽快处理！',
			'common.followSystemTips' => '开启后,将跟随系统打开或关闭深色模式',
			'common.forceLogoutNotification' => ({required Object param}) => '您已被设备【${param}】强制下线',
			'common.friendPermissions' => '朋友权限',
			'common.friendsPermissionsView' => '好友权限视图',
			'common.genderConflictError' => '性别设置冲突，请重试',
			'common.genderNetworkError' => '网络异常，请检查网络连接',
			'common.genderUpdateFailed' => '性别设置失败，请重试',
			'common.genderUpdateSuccess' => '性别设置成功',
			'common.groupAddLocal' => '保存到通讯录',
			'common.groupAnnouncement' => '群公告',
			'common.groupFileUploadSuccess' => '文件上传成功',
			'common.groupFileUploadFailed' => '文件上传失败，请稍后重试',
			'common.groupFileDeleteSuccess' => '文件已删除',
			'common.groupFileDeleteFailed' => '删除失败，请稍后重试',
			'common.groupFileClosePreview' => '关闭预览',
			'common.groupFileUploadTooltip' => '上传文件',
			'common.groupFileSearch' => '搜索群文件',
			'common.groupFileReadFailed' => '文件读取失败，请重试',
			'common.groupFileDeleteTitle' => '删除群文件',
			'common.groupFileDeleteConfirm' => ({required Object name}) => '确定删除文件「${name}」吗？',
			'common.groupFileImageLoadFailed' => '图片加载失败',
			'common.groupFileOpenFailed' => '无法打开文件链接',
			'common.groupFileSearchClear' => '清空',
			'common.groupFileSearchAction' => '搜索',
			'common.groupFileCategoryAll' => '全部',
			'common.groupFileSearchEmpty' => '未找到匹配文件',
			'common.groupFileAudioLoadFailed' => '音频加载失败',
			'common.groupFileAudioLoading' => '音频加载中...',
			'common.groupQrcodeTips' => ({required Object days, required Object date}) => '该二维码${days}天内（${date}前）有效，重新进入将更新',
			'common.groupSearchTips' => '群名称和群简介',
			'common.helpDocument' => '帮助文档',
			'common.hintEditGroupAnnouncement' => '编辑群公告',
			'common.httpResponse' => 'HTTP响应',
			'common.incomingCall' => ({required Object param}) => '${param}呼入',
			'common.info' => '信息',
			'common.infoLoggedInOnAnotherDevice' => ({required Object param}) => '你的账号已于${param}在其他设备登录',
			'common.installNow' => '立即安装',
			'common.iosAppIdUnknown' => ({required Object param}) => 'AppStore未上架或AppID[${param}]不存在',
			'common.koKr' => '韩语（韩国）',
			'common.languageSetting' => '语言设置',
			'common.languageState' => '语言状态',
			'common.lastActiveTips' => '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。',
			'common.lastSeenJustNow' => '刚刚上线',
			'common.lastSeenLongTimeAgo' => '很久以前上线',
			'common.lastSeenMonthsAgo' => ({required Object param}) => '${param}个月前',
			'common.leaveYourSuggestions' => '请留下您宝贵的意见和建议',
			'common.loadError' => '加载失败，请重试',
			'common.loadMore' => '加载更多',
			'common.loading' => '加载中',
			'common.locationMessage' => '位置消息',
			'common.loginDeviceManagementTips' => '你的帐号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。',
			'common.logoutFailed' => '退出登录失败',
			'common.logoutNotice' => '《注销须知》',
			'common.exportDataSuccess' => '数据已导出',
			'common.manually' => '手动选择',
			'common.messageCall' => '发消息',
			'common.messageContent' => '消息内容',
			'common.messageLocationBuilder' => '消息位置构建器',
			'common.messageNotification' => '消息通知',
			'common.messageRevoked' => '消息已撤回',
			'common.quoteMessageNotAvailable' => '引用的消息不可用',
			'common.messageRevokedBuilder' => '消息撤回构建器',
			'common.microphone' => '麦克风',
			'common.microphonePermissionNotObtained' => '未获取到麦克风权限',
			'common.moreInfo' => '更多信息',
			'common.myAddress' => '我的地址',
			'common.nearbyPeopleTips' => '与附近的人交换联系方式，结交新朋友',
			'common.needContinueWorkHard' => '需要继续加油',
			'common.needSubmitEffect' => '需要确认提交，该操作才生效',
			'common.networkErrorWithAction' => ({required Object param}) => '${param}失败，请检查网络连接',
			'common.networkException' => '网络连接异常',
			'common.errorNetwork' => '网络错误',
			'common.networkExceptionPlaseNeedNetworkToViewData' => '网络状态异常，需要打开网络才能够查看数据',
			'common.networkFailureTips' => '网络失败提示',
			'common.newVersionDetected' => '检测到新版本',
			'common.newVersionDetectedWithVersion' => ({required Object param}) => '检测到新版本 ${param}',
			'common.nextStep' => '下一步',
			'common.nicknameConflictError' => '昵称已被使用，请选择其他昵称',
			'common.nicknameEmojiOnlyError' => '昵称不能仅包含表情符号',
			'common.nicknameEmptyError' => '昵称不能为空',
			'common.nicknameLengthError' => '昵称长度应在2-24个字符之间',
			'common.nicknameNetworkError' => '网络异常，请检查网络连接',
			'common.nicknameSensitiveWordError' => '昵称包含敏感词，请重新输入',
			'common.nicknameServerError' => '服务器错误，请稍后重试',
			'common.nicknameUpdateFailed' => '昵称修改失败，请重试',
			'common.nicknameUpdateSuccess' => '昵称修改成功',
			'common.nicknameWhitespaceError' => '昵称不能仅包含空白字符',
			'common.noAvatar' => '无头像',
			'common.noBarcodeFound' => '未找到条形码！',
			'common.noContacts' => '无联系人',
			'common.noConversationMessages' => '无会话消息',
			'common.noData' => '暂无数据',
			'common.noMembersInCurrentTag' => '当前标签无成员',
			'common.noMoreData' => '没有更多数据了',
			'common.noNewFriends' => '没有新的好友',
			'common.noPermission' => '没有权限',
			'common.noReply' => '暂无回复',
			'common.noSiginQ' => '还没有账号？',
			'common.noUpdateDescription' => '无更新说明',
			'common.normalModel' => '普通模式',
			'common.notAuthorizedLatLong' => '您还没有授权获取经纬度',
			'common.notLoggedIn' => '未登录',
			'common.notBad' => '还不错',
			'common.notBound' => '未绑定',
			'common.notFilled' => '未填写',
			'common.notInstallAnyMapApp' => '您没有安装任何地图APP哦',
			'common.notLetHimSee' => '不让TA看',
			'common.notReceiveCoeQ' => '没有收到验证码？',
			'common.notSeeHim' => '不看TA',
			'common.notSet' => '未设置',
			'common.notShow' => '不显示',
			'common.notTurnedLocationService' => '您还没有打开位置信息服务',
			'common.nowNewVersion' => '未检测到新版本',
			'common.off' => _root.common.disabled,
			'common.offlineNotification' => '下线通知',
			'common.on' => _root.common.enabled,
			'common.operationFailedAgainLater' => '操作失败，请稍后重试',
			'common.optionsNo' => '不',
			'common.optionsRename' => '我想重命名',
			'common.optionsYes' => '是的!',
			'common.p2pCallScreenLogic' => 'p2pCallScreenLogic',
			'common.p2pCallScreenView' => 'p2pCallScreenView',
			'common.paramFormatError' => ({required Object param}) => '${param}格式有误',
			'common.pauseDownloading' => '暂停下载',
			'common.peerNoResponse' => '对方无应答...',
			'common.peopleInfoMoreLogic' => '用户信息更多逻辑',
			'common.peopleInfoSameGroupView' => '同群用户视图',
			'common.perMinuteOnce' => '每分钟只能请求一次',
			'common.permission' => '权限',
			'common.permissionAcquisitionFailed' => '权限获取失败',
			'common.personalCard' => '个人名片',
			'common.personalInfoDesc' => '个人信息描述',
			'common.personalInfoTip' => '个人信息提示',
			'common.personalInformation' => '个人信息',
			'common.pinCodeFillTips' => '请把方格填满',
			'common.pleaseSelectMembersForAdd' => '请选择要添加的成员',
			'common.profileSettings' => '资料设置',
			'common.reEdit' => '重新编辑',
			'common.recoverPasswordSuccess' => '验证码发送成功',
			'common.regionCancel' => '取消',
			'common.regionConfirm' => '确定',
			'common.regionNoResult' => '暂无结果',
			'common.regionSearchHint' => '按地区名称搜索',
			'common.regionSearchTips' => '按地区名称或区域编码搜索',
			'common.regionSelectTitle' => '选择地区',
			'common.releaseFingerCancelSending' => '松开手指,取消发送',
			'common.removeContactFromTag' => '从标签中移除联系人',
			'common.removeMember' => '移出成员',
			'common.atMentionYouTag' => '[@你] ',
			'common.atMentionLeftMember' => '@已退群成员',
			'common.muteNotifications' => '消息免打扰',
			'common.muteNotificationsHint' => '开启后不会收到新消息提醒，但仍可在会话列表看到未读',
			'common.revokeExpired' => '超过 2 分钟，无法撤回',
			'common.quickReplyAddTitle' => '新增快捷回复',
			'common.quickReplyEditTitle' => '编辑快捷回复',
			'common.removeAdmin' => '取消管理员',
			'common.setAdminConfirm' => '确定将此成员设为管理员吗？',
			'common.removeAdminConfirm' => '确定取消此成员的管理员身份吗？',
			'common.muteMemberConfirm' => '确定禁言此成员吗？',
			'common.unmuteMemberConfirm' => '确定取消禁言此成员吗？',
			'common.kickMemberConfirm' => '确定将此成员移出群聊吗？',
			'common.transferGroupConfirm' => '确定将群主身份转让给此成员吗？转让后你将变为管理员。',
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
			'common.transferGroupSuccess' => '群主已转让',
			'common.transferGroupFailed' => '转让群主失败',
			'common.notMuted' => '未禁言',
			'common.muteDuration' => '禁言时长',
			'common.muteDuration1hour' => '1小时',
			'common.muteDuration6hours' => '6小时',
			'common.muteDuration12hours' => '12小时',
			'common.muteDuration1day' => '1天',
			'common.muteDuration3days' => '3天',
			'common.muteDuration7days' => '7天',
			'common.muteDurationPermanent' => '永久',
			'common.muteDuration5min' => '5分钟',
			'common.muteDuration10min' => '10分钟',
			'common.muteDuration30min' => '30分钟',
			'common.muteDuration30days' => '30天',
			'common.muteUnitSeconds' => ({required Object count}) => '${count} 秒',
			'common.throttleWarning' => '操作频率过高，请稍后再试',
			'common.throttleRetryAfter' => ({required Object seconds}) => '操作频率过高，请 ${seconds} 秒后再试',
			'common.mutedCannotSend' => '禁言期间无法发送消息',
			'common.resendCodeSuccess' => '已发送新邮件。',
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
			'common.searchFilterAll' => '全部筛选',
			'common.searchFilterImage' => '图片筛选',
			'common.searchFilterText' => '文本筛选',
			'common.searchFilterToday' => '今日筛选',
			'common.searchFilters' => '搜索筛选',
			'common.searchFriendsTips' => '通过好友昵称、备注搜索好友',
			'common.searchHint' => '输入关键词搜索消息',
			'common.searchHistory' => '搜索历史',
			'common.searchLocation' => '搜索地点',
			'common.searchMessagesHint' => '搜索消息提示',
			'common.searchNoFound' => '搜索结果为空 :(',
			'common.searchNoResults' => '无搜索结果',
			'common.noSearchHistory' => '暂无搜索历史',
			'common.searchRegion' => '搜索地区',
			'common.searchResults' => '搜索结果',
			'common.searchResultsCount' => ({required Object current, required Object total}) => '第 ${current} 个，共 ${total} 个结果',
			'common.searchSuggestions' => '搜索建议',
			'common.selectAll' => '全选',
			'common.selectContacts' => '选择联系人',
			'common.selectRegionView' => '选择地区视图',
			'common.selectedItems' => ({required Object param}) => '${param} 个选定项目',
			'common.selectedRegion' => '已选地区',
			'common.sendMsgNotFriendTips' => '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。',
			'common.setChatBackground' => '设置当前聊天背景',
			'common.share' => '分享',
			'common.signatureTips' => '签名提示',
			'common.slideUpCancelSending' => '手指上滑,取消发送',
			'common.storagePermissionNotObtained' => '未获取存储权限',
			'common.strongReminder' => '强提醒',
			'common.submittedAt' => '提交于',
			'common.sureDeleteData' => '确认删除吗？删除后不可恢复。',
			'common.sureDeleteGroupChatRecord' => '确定删除群的聊天记录吗？',
			'common.switchEnvironment' => '切换环境',
			'common.thisMonth' => '本月',
			'common.timeDaysAgo' => ({required Object param}) => '${param}天前',
			'common.timeHoursAgo' => ({required Object param}) => '${param}小时前',
			'common.timeJustNow' => '刚刚',
			'common.timeMinutesAgo' => ({required Object param}) => '${param}分钟前',
			'common.timeToday' => '今天',
			'common.timeYesterday' => '昨天',
			'common.tipConnectDesc' => '无网络',
			'common.tipConnectDescWithParen' => ({required Object param}) => '(${param})',
			'common.tipDeleteContact' => ({required Object param}) => '将联系人"${param}"删除，同时删除与该联系人的聊天记录',
			'common.tipDeviceSpace' => ({required Object param1, required Object param2}) => '占设备 ${param1}‰ 存储空间(${param2})',
			'common.tipDraft' => '草稿',
			'common.tipEmptyChatPlaceholder' => '这里还没有消息',
			'common.tipFailed' => '操作失败！',
			'common.tipGreeting' => '欢迎使用',
			'common.tipProvidersTitleFirst' => '或用以下账号登录',
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
			'common.userOnlineStatusWidget' => '用户在线状态组件',
			'common.userTagRelationView' => '用户标签关系视图',
			'common.userTagSaveView' => '用户标签保存视图',
			'common.verificationMessageSentByPeerIs' => ({required Object param}) => '对方发来的验证消息为：${param}',
			'common.version' => '版本',
			'common.videoCall' => '视频通话',
			'common.viewAllGroupMember' => '查看全部群成员',
			'common.voiceCall' => '语音通话',
			'common.voiceInputNotImplemented' => '语音输入功能暂无实现',
			'common.waitingDownload' => '等待下载',
			'common.waitingPeerAccept' => '等待对方接受邀请...',
			'common.warning' => '警告:',
			'common.webpageLoading' => '网页加载中...',
			'common.whatYourFeedback' => '你的反馈是什么?',
			'common.yesterday' => '昨天',
			'common.yourContactInformation' => '你的联系方式',
			'common.confirmRemove' => '确认移出',
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
			'common.pleaseEnterCorrectEmailAddress' => '请输入正确的邮箱地址',
			'common.pleaseEnter6DigitVerificationCode' => '请输入 6 位验证码',
			'common.verificationCodeSent' => '验证码已发送',
			'common.sendFailed' => '发送失败',
			'common.noChangeNeeded' => '无需修改',
			'common.submissionFailed' => '提交失败',
			'common.checkVerificationCodeOrRetry' => '请检查验证码或稍后重试',
			'common.forceOffline' => '下线',
			'common.forceDeviceOffline' => '让该设备下线',
			'common.forceDeviceOfflineConfirm' => '将向该设备发送下线指令，确认继续？',
			'common.confirmForceOffline' => '确认下线',
			'common.forceOfflineCommandSent' => '已发送下线指令',
			_ => null,
		} ?? switch (path) {
			'common.feedbackSlogan' => '您的建议是我们改进的动力',
			'common.newFeedback' => '新建反馈',
			'common.feedbackHistory' => '反馈历史',
			'common.confirmDelete' => '确认删除',
			'common.processing' => _root.common.loading,
			'common.verificationCode' => '验证码',
			'common.feedbackContent' => '反馈内容',
			'common.officialReply' => '官方回复',
			'common.setPasswordSecurityTips' => '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。',
			'common.locationHidden' => '已隐藏您的位置',
			'common.locationVisible' => '已显示您的位置',
			'common.noNearbyPeople' => '暂无附近的人',
			'common.clickSearchButtonToFind' => '点击上方的搜索按钮查找附近的人',
			'common.operationSuccess' => _root.common.success,
			'common.operationFailed' => _root.common.error,
			'common.featureInDevelopment' => '功能开发中...',
			'common.addedToDenylist' => '已加入黑名单',
			'common.bindSuccess' => '绑定成功',
			'common.mobileUpdatedToParam' => ({required Object param}) => '手机号已更新为 ${param}',
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
			'common.showOnlineStatusDesc' => '好友可以看到你的在线状态',
			'common.allowNearbyVisible' => '附近的人可见',
			'common.dataSettings' => '数据设置',
			'common.clearChatRecords' => '清除聊天记录',
			'common.clearChatRecordsDesc' => '清除所有聊天记录，此操作不可恢复',
			'common.deleteAccountAction' => '注销账号',
			'common.deleteAccountActionDesc' => '永久删除账号和所有数据，此操作不可恢复',
			'common.chatHistoryCleared' => '聊天记录已清除',
			'common.accountDeletionNotAvailable' => '账号注销功能暂未开放',
			'common.chatDeleteMessage' => '删除消息',
			'common.chatCopy' => '复制',
			'common.chatSaveImage' => '保存图片',
			'common.chatDeleteLocalOnly' => '仅删除本地',
			'common.chatDownloadFile' => '下载文件',
			'common.chatShareFile' => '分享文件',
			'common.chatCopyLink' => '复制链接',
			'common.chatShareLink' => '分享链接',
			'common.chatDeleteFailed' => '删除失败',
			'common.chatNetworkErrorDeleteLocal' => '网络连接失败，是否仅删除本地消息？',
			'common.chatDeleteConfirm' => '确定要删除这条消息吗？此操作无法撤销。',
			'common.chatDeleteOnlyLocal' => '仅在你这里删除，对方仍可见',
			'common.chatDeleteAll' => '从所有人的聊天中删除，无法撤销',
			'common.chatInitFailed' => '聊天初始化失败',
			'common.cameraShootFailed' => '拍摄失败',
			'common.avatarSave' => '保存',
			'common.avatarDeleteAvatar' => '删除头像',
			'common.avatarEditAvatar' => '编辑头像',
			'common.backgroundUseCustomColor' => '使用自定义颜色',
			'common.backgroundOnlySolidColor' => '仅适用于纯色背景',
			'common.backgroundSelectColor' => '选择颜色',
			'common.profileShareProfile' => '分享资料',
			'common.tagClearAllConfirm' => '确定要清空所有标签吗？',
			'common.tagClearAll' => '确认清空',
			'common.audioPlayFailed' => '播放失败',
			'common.videoFileNotFound' => '输入文件不存在',
			'common.videoCompressFailed' => '压缩失败，返回结果为空',
			'common.videoFurtherCompressFailed' => '进一步压缩失败',
			'common.forcedOfflineByDevice' => ({required Object device}) => '您已被设备【${device}】强制下线',
			'common.searchDescription' => '小程序、公众号、文章、朋友圈、和表情等',
			'common.testDirectNavigation' => '测试直接跳转',
			'common.tagNameTooLong' => '标签名称不能超过14个字符',
			'common.tagNameNoComma' => '标签名称不能包含逗号',
			'common.tagNameNoLeadingTrailingSpaces' => '标签名称不能包含前后空格',
			'common.tagNameNoSpecialChars' => '标签名称不能包含特殊字符',
			'common.commonTags' => '常用标签',
			'common.loadingTagDataFailed' => '加载标签数据失败',
			'common.pleaseEnterContent' => '请输入内容',
			'common.comingSoon' => '敬请期待',
			'common.chatBackground' => '聊天背景',
			'common.useSystemDefaultBackground' => '使用系统默认背景',
			'common.selectCustomBackgroundImage' => '选择自定义背景图片',
			'common.currentBackground' => '当前背景',
			'common.backgroundTransparency' => '背景透明度',
			'common.defaultBackground' => '默认背景',
			'common.solidColorBackground' => '纯色背景',
			'common.selectImageFailed' => '选择图片失败',
			'common.takePhotoFailed' => '拍照失败',
			'common.selectVideoFailed' => '选择视频失败',
			'common.recordVideoFailed' => '录制视频失败',
			'common.selectFileFailed' => '选择文件失败',
			'common.locationSelectNotImplemented' => '位置选择功能暂未实现',
			'common.selectLocationFailed' => '选择位置失败',
			'common.sendCardNotImplemented' => '名片发送功能暂未实现',
			'common.sendCardFailed' => '发送名片失败',
			'common.uploadResponseInvalid' => '上传响应数据无效',
			'common.voiceSendSuccess' => '语音发送成功',
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
			'common.messageNotFound' => '未找到该消息',
			'common.conversationNotFound' => '未找到会话',
			'common.enabled' => '已开启',
			'common.disabled' => '已关闭',
			'common.configureVisibleThreshold' => '配置可视阈值',
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
			'common.userNotSetSignature' => '该用户还没有设置个人签名等详细信息',
			'common.verificationMessage' => '验证消息',
			'common.burnEnabledMessage' => ({required Object duration}) => '开启后：消息在被阅读后 ${duration} 自动销毁',
			'common.burnDisabledMessage' => '关闭后：消息不会自动销毁',
			'common.visibleEnabledMessage' => ({required Object percentage, required Object delayms}) => '开启后：可见比例≥${percentage}%，持续≥${delayms}',
			'common.visibleDisabledMessage' => '关闭后：不会基于可视自动已读',
			'common.visibleThresholdInfo' => ({required Object percentage, required Object delayms}) => '可见比例: ${percentage}% | 延时: ${delayms}',
			'common.noGroupAnnouncement' => '暂无群公告',
			'common.announcementContentCannotBeEmpty' => '公告内容不能为空',
			'common.announcementPublishSuccess' => '公告发布成功',
			'common.tips' => '提示',
			'common.featureComingSoon' => '功能暂未实现',
			'common.understood' => '明白了',
			'common.noProblem' => '没问题',
			'common.onMyWay' => '马上到',
			'common.sendOfflineCommand' => '强制下线',
			'common.offlineCommandSent' => '已发送下线指令',
			'common.operationOptions' => '操作选项',
			'common.copyTextContent' => '复制文本内容',
			'common.shareWithOtherFriends' => '分享给其他好友',
			'common.addTagsToFavorites' => '为收藏添加标签',
			'common.addRemarkToFavorites' => '为收藏添加备注',
			'common.deleteThisCollection' => '删除此收藏',
			'common.pullUpLoadMore' => '上拉加载更多',
			'common.changeSuccess' => '修改成功',
			'common.loginPasswordUpdated' => '登录密码已更新',
			'common.lengthOk' => '长度符合',
			'common.confirmNewPassword' => '确认新密码',
			'common.validationPassed' => '验证通过',
			'common.changeFailed' => '修改失败',
			'common.submitted' => '已提交',
			'common.viewSecurityHelp' => '查看安全帮助',
			'common.momentsNoData' => '暂无动态',
			'common.momentsDeleteConfirm' => '确定删除这条动态吗？',
			'common.momentsDeleteCommentConfirm' => '确定删除这条评论吗？',
			'common.momentsNotFound' => '动态不存在或无权限查看',
			'common.momentsContentOrMediaRequired' => '内容或媒体至少填写一项',
			'common.momentsPublishFailed' => '发布失败',
			'common.momentsAllowComment' => '允许评论',
			'common.momentsReportReason' => '举报原因',
			'common.momentsNoComments' => '暂无评论',
			'common.momentsContentHint' => '写点什么...',
			'common.momentsAddMedia' => '添加媒体',
			'common.momentsAllowUidsLabel' => '允许可见 UID 列表（逗号分隔）',
			'common.momentsCommentFailed' => '评论失败，请稍后重试',
			'common.momentsDeleteFailed' => '删除失败，请稍后重试',
			'common.momentsReportSubmitted' => '举报已提交',
			'common.momentsReportFailed' => '举报失败，请稍后重试',
			'common.momentsLoadMoreComments' => '加载更多评论',
			'common.momentsUploadFailed' => '媒体上传失败，请稍后重试',
			'common.transactionHistory' => '交易记录',
			'common.paymentPasswordSetSuccess' => '支付密码设置成功',
			'common.paymentPasswordSetFailed' => '支付密码设置失败',
			'common.nextVoiceMessageNotFound' => '没有找到下一条语音消息',
			'common.noNextVoiceMessage' => '没有下一条语音消息可播放',
			'common.nextVoiceMessageNoPath' => '下一条语音消息没有音频文件路径',
			'common.saveFailed' => '保存失败',
			'common.tip' => '提示',
			'common.confirm' => '确认',
			'common.success' => '成功',
			'common.personalDisplay' => '个人展示',
			'common.personalSignature' => '个性签名',
			'common.personalBackground' => '个人背景',
			'common.setBackgroundImage' => '设置背景图片',
			'common.expression' => '表情',
			'common.extendedInfo' => '扩展信息',
			'common.profession' => '职业',
			'common.pleaseEnterProfession' => '请输入职业',
			'common.functionSettings' => '功能设置',
			'common.shareProfile' => '分享资料',
			'common.shareWithFriends' => '将个人资料分享给好友',
			'common.shareQRCode' => '分享二维码',
			'common.copyLink' => '复制链接',
			'common.shareTo' => '分享到',
			'common.shareFailed' => '分享失败',
			'common.exportAsJson' => '导出为 JSON 格式',
			'common.exportSuccessThenCopiedToClipboard' => ({required Object param}) => '${param} 格式资料已导出并复制到剪贴板',
			'common.exportFailed' => '导出失败',
			'common.setRegion' => '设置地区',
			'common.avatarUpdateSuccess' => '头像更新成功',
			'common.avatarUpdateFailed' => '头像更新失败',
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
			'common.uploadAvatarFailed' => '上传头像失败',
			'common.error' => '错误',
			'common.cannotOpenWebpage' => '无法打开网页',
			'common.groupIdCannotBeEmpty' => '群组ID不能为空',
			'common.selectImageFailedWithError' => '选择图片失败',
			'common.uploadAvatarFailedWithError' => '上传头像失败',
			'common.avatarSelectedUploadPending' => '头像选择成功，上传功能待实现',
			'common.emailEditFeaturePending' => '邮箱编辑功能开发中...',
			'common.reactionAdded' => '已添加反应',
			'common.reactionCancelled' => '已取消反应',
			'common.retryFailedPleaseCheckNetwork' => '重试失败，请检查网络连接',
			'common.retryAbnormal' => '重试异常',
			'common.deleteFailedPleaseTryAgain' => '删除失败，请重试',
			'common.deleteFailedPleaseCheckNetwork' => '删除失败，请检查网络连接',
			'common.voiceRecordFailedPleaseTryAgain' => '语音录制失败，请重试',
			'common.voiceFileNotFoundPleaseTryAgain' => '语音文件不存在，请重试',
			'common.voiceFileCannotReadPleaseTryAgain' => '语音文件无法读取，请重试',
			'common.voiceFileReadFailedPleaseTryAgain' => '语音文件读取失败，请重试',
			'common.voiceProcessingAbnormal' => '语音处理异常',
			'common.voiceUploadFailedPleaseCheckNetwork' => '语音上传失败，请检查网络连接',
			'common.voiceSendAbnormal' => '语音发送异常',
			'common.voiceDuration' => '语音时长',
			'common.playbackFailed' => '播放失败',
			'common.revokeOperationAbnormalPleaseTryAgain' => '撤回操作异常，请重试',
			'common.collectionFailedPleaseTryAgain' => '收藏失败，请重试',
			'common.reactionSent' => '已发送反应',
			'common.seconds' => '秒',
			'common.messageCannotLocatedMayBeDeleted' => '未能定位到该消息，可能已被删除',
			'common.settingFailedPleaseTryAgain' => '设置失败，请重试',
			'common.partialDeleteSuccess' => ({required Object success, required Object fail}) => '部分删除成功：${success} 成功，${fail} 失败',
			'common.collectedVideoFormatIncorrectCannotFindVideoUri' => '收藏的视频消息格式有误，找不到 video uri',
			'common.recordingCancelled' => '录音已取消',
			'common.voiceSttPreviewTitle' => '语音转文字预览',
			'common.voiceSttConverting' => '正在识别中...',
			'common.voiceSttNotConfigured' => '转文字功能暂未配置',
			'common.pullOfflineMessagesFailed' => '拉取离线消息失败',
			'common.pullOfflineMessagesAbnormal' => '拉取离线消息异常',
			'common.logoutRequestFailedPleaseCheckNetwork' => '退出登录请求失败，请检查网络连接',
			'common.permissionOnlySupportAndroidAndIos' => 'Permission 只支持 Android 和 IOS',
			'common.messageSendFailedPleaseCheckNetwork' => '消息发送失败，请检查网络连接',
			'common.retryingSend' => '正在重试发送...',
			'common.quickReplyOk' => '好的',
			'common.quickReplyOkThanks' => '好的，谢谢',
			'common.tagInspiration' => '灵感',
			'common.noDetailedInfo' => '该用户还没有设置个人签名等详细信息',
			'common.noNewRegisteredUsers' => '当前没有新注册的用户 请稍后再来查看',
			'common.newRegisteredUsersTip' => '这里显示最近注册的用户，你可以主动添加他们为好友',
			'common.notificationFriendRequest' => '好友请求',
			'common.notificationFriendRequestBody' => ({required Object requesterName}) => '${requesterName} 请求添加您为好友',
			'common.notificationGroupInvite' => '群邀请',
			'common.notificationGroupInviteBody' => ({required Object inviterName, required Object groupName}) => '${inviterName} 邀请您加入群组 ${groupName}',
			'common.youRevokedMessage' => '你撤回了一条消息',
			'common.otherRevokedMessage' => '对方撤回了一条消息',
			'common.networkFailureTryAgain' => '网络故障，请重试！',
			'common.networkNotAvailable' => '当前网络不可用。',
			'common.pleaseCheckNetworkConnection' => '请检查你的网络连接。',
			'common.lastSeenMinutesAgo' => ({required Object param}) => _root.common.timeMinutesAgo(param: param),
			'common.lastSeenHoursAgo' => ({required Object param}) => _root.common.timeHoursAgo(param: param),
			'common.lastSeenDaysAgo' => ({required Object param}) => _root.common.timeDaysAgo(param: param),
			'common.fontSettings' => _root.common.fontSizeSetting,
			'common.failed' => _root.common.error,
			'common.lazyUserNoSignature' => '暂无个人签名',
			'common.noFavoritesYet' => '暂无收藏内容，快去收藏一些有趣的消息吧',
			'common.fontPreviewText' => '这是正文内容，您可以在这里看到不同字体大小的显示效果。',
			'common.smaller' => '更小',
			'common.currentFontScale' => ({required Object param1, required Object param2}) => '当前：${param1} ${param2}%',
			'common.emailUpdatedTo' => ({required Object param}) => '邮箱已更新为 ${param}',
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
			'common.groupAlbumPhotoOpenExternal' => '外部打开',
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
			'common.durationMinutes' => ({required Object count}) => '${count}分钟',
			'common.durationSeconds' => ({required Object count}) => '${count}秒',
			'common.rechargeAmountError' => '请输入1元到10000元之间的金额',
			'common.rechargeSuccess' => '充值成功',
			'common.rechargeConfirm' => '确认充值',
			'common.transactionHistory2' => '流水记录',
			'common.noTransactionHistory' => '暂无流水记录',
			'common.allLoaded' => '— 已全部加载 —',
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
			'common.removeReaction' => '移除反应',
			'common.removeReactionConfirm' => ({required Object emoji}) => '确定要移除 ${emoji} 反应吗？',
			'common.fileOpenFailed' => '无法打开该文件',
			'common.e2eeLocalBackup' => '本地备份',
			'common.e2eeLocalBackupDesc' => '导出加密备份文件到本地或云端',
			'common.e2eeDeleteKey' => '删除密钥',
			'common.e2eeDeleteKeyDesc' => '删除本地存储的密钥（无法恢复）',
			'common.e2eeCurrentKeyInfo' => '当前密钥信息',
			'common.e2eeE2EEEnabled' => '端到端加密已启用',
			'common.e2eeNoKeyDetected' => '未检测到 E2EE 密钥',
			'common.e2eeNoKeyDesc' => '您需要先生成密钥对或从备份中恢复',
			'common.e2eeAboutTitle' => '关于端到端加密',
			'common.e2eeInfoPoint1' => '• 您的消息在发送前已加密，服务器无法查看内容',
			'common.e2eeInfoPoint2' => '• 更换设备或删除密钥后，旧消息可能无法解密',
			'common.e2eeInfoPoint3' => '• 请定期备份密钥以防数据丢失',
			'common.e2eeExportBackup' => '导出备份',
			'common.e2eeExportBackupDesc' => '生成加密备份文件',
			'common.e2eeImportBackup' => '导入备份',
			'common.e2eeImportBackupDesc' => '从备份文件恢复密钥',
			'common.e2eeBackupManage' => '备份管理',
			'common.e2eeBackupManageDesc' => '查看备份历史记录',
			'common.e2eeGenerateKeyConfirm' => '确定要生成新的 E2EE 密钥对吗？',
			'common.e2eeWarnOldMessagesLost' => '• 旧消息将无法解密',
			'common.e2eeWarnNeedNewBackup' => '• 需要重新生成备份文件',
			'common.e2eeConfirmGenerate' => '确认生成',
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
			'common.e2eeShardAvailableInfo' => ({required Object available, required Object required}) => '可用分片: ${available} 个，需要 ${required} 个代理协助',
			'common.e2eeNoRecoveryShards' => '没有可用的恢复分片',
			'common.e2eeRecoverSuccess' => '恢复成功',
			'common.e2eeRecoverFailed' => '恢复失败',
			'common.e2eeRecoverKeyFailed' => '恢复密钥失败，请重试',
			'common.e2eeLoadingShards' => '加载分片信息...',
			'common.e2eeNoShards' => '没有可用的分片',
			'common.e2eeLoadFailed' => '加载失败，请重试',
			'common.e2eeContactingProxy' => ({required Object name}) => '正在联系: ${name}',
			'common.e2eeRecoveryFailed' => '恢复失败，请重试',
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
			'common.e2eeDecryptFailed' => '消息无法解密',
			'common.e2eeDecryptFailedReasons' => '此消息无法解密，可能原因是：',
			'common.e2eeDecryptReasonOtherDevice' => '• 您在其他设备上登录',
			'common.e2eeDecryptReasonKeyExpired' => '• 设备密钥已过期',
			'common.e2eeDecryptReasonDataCorrupt' => '• 应用数据损坏',
			'common.e2eeDecryptChooseSolution' => '请选择解决方案：',
			'common.e2eeDecryptRecreateHint' => '提示：重建后，对方需重新获取你的新密钥；重建期间未送达的加密消息可能不会自动重发。历史消息不受影响。',
			'common.e2eePeerKeyChanged' => '对方的安全码已变更（可能因对方重装应用或更换设备）。若你重视安全，请通过其他渠道与对方核实身份。',
			'common.e2eeDecryptActionRecreateKey' => '重新创建密钥（推荐）',
			'common.e2eeDecryptActionRelogin' => '重新登录',
			'common.e2eeDecryptActionRemindLater' => '稍后提醒我',
			'common.e2eeBackupExportTitle' => '导出 E2EE 备份',
			'common.e2eeBackupPwdCantRecover' => '• 备份密码无法找回，请务必牢记！',
			'common.e2eeBackupStoreMultipleNote' => '• 建议将备份文件存储到多个安全位置（邮件、云盘、U盘）',
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
			'common.e2eeBackupExportSuccessBody' => '您的 E2EE 密钥备份已成功生成。',
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
			'common.e2eeBackupFileValid' => '✓ 文件格式有效',
			'common.e2eeBackupImportPwdHint' => '请输入备份时设置的密码',
			'common.e2eeBackupImportBtn' => '导入密钥',
			'common.e2eeBackupErrSelectFile' => '选择文件失败，请重试',
			'common.e2eeBackupErrValidateFailed' => '文件验证失败，请检查文件格式',
			'common.e2eeBackupErrImportFailed' => '导入失败，请检查密码是否正确',
			'common.e2eeBackupImportSuccessTitle' => '导入成功',
			'common.e2eeBackupImportSuccessBody' => 'E2EE 密钥已成功恢复！',
			'common.e2eeBackupImportSuccessNote' => '注意：旧消息可能无法访问，这是 E2EE 的正常行为',
			'common.e2eeBackupNoRecords' => '暂无备份记录',
			'common.e2eeBackupNoRecordsHint' => '导出备份后将在此显示历史记录',
			'common.e2eeBackupDeviceLabel' => ({required Object id}) => '设备 ${id}',
			'common.e2eeBackupCreatedAtLabel' => ({required Object time}) => '创建于 ${time}',
			'common.e2eeBackupDetailTitle' => '备份详情',
			'common.e2eeBackupDeviceIdLabel' => '设备 ID',
			'common.e2eeBackupVersionNum' => '备份版本',
			'common.e2eeBackupCreatedAtRow' => '创建时间',
			_ => null,
		} ?? switch (path) {
			'common.e2eeBackupFileSizeRow' => '文件大小',
			'common.e2eeBackupNoteRow' => '备注',
			'common.e2eeBackupDeleteTitle' => '删除备份记录',
			'common.e2eeBackupDeleteConfirm' => '确定要删除此备份记录吗？',
			'common.e2eeBackupDeleteSuccess' => '备份记录已删除',
			'common.e2eeSocialShardSettings' => '分片设置',
			'common.e2eeSocialShardStoredNote' => '说明：分片将存储在代理设备上，服务端不保存任何分片',
			'common.e2eeSocialAddProxy' => '添加代理',
			'common.e2eeSocialAddProxyHint' => '请添加代理联系人',
			'common.e2eeSocialCreateNeedMore' => ({required Object count}) => '请先添加 ${count} 个代理',
			'common.e2eeSocialCreateSuccessTitle' => '分片创建成功',
			'common.e2eeSocialTotalShardsInfo' => ({required Object count}) => '密钥已分割成 ${count} 个分片',
			'common.e2eeSocialThresholdInfo' => ({required Object count}) => '需要 ${count} 个代理协助即可恢复密钥',
			'common.e2eeSocialZeroTrustNote' => '零信任架构：服务端不保存任何分片',
			'common.e2eeSocialNoShards' => '您还没有创建任何恢复分片',
			'common.e2eeSocialNoProxyShards' => '没有代理分片',
			'common.e2eeSocialKeyVersionLabel' => '密钥版本',
			'common.e2eeTransferErrNoKey' => '请先生成密钥对',
			'common.e2eeTransferErrInitFailed' => '初始化失败，请重试',
			'common.e2eeTransferErrNoRecipientKey' => '接收方没有可用的公钥',
			'common.e2eeTransferErrKeyNotFound' => '密钥未找到',
			'common.e2eeTransferErrCreateFailed' => '创建传输会话失败，请重试',
			'common.e2eeTransferCreateSessionBtn' => '创建传输会话',
			'common.e2eeTransferSessionCreated' => '传输会话已创建',
			'common.e2eeTransferUidEmptyError' => '请输入有效的用户 ID',
			'common.e2eeTransferSuccess' => '传输成功！',
			'common.e2eeTransferFailed' => '传输失败，请重试',
			'common.e2eeTransferProcessingMsg' => '处理中...',
			'common.e2eeTransferSuccessTitle' => '传输成功',
			'common.e2eeTransferSuccessBody' => '密钥已成功传输到当前设备',
			'common.e2eeTransferScanError' => ({required Object error}) => '扫描错误: ${error}',
			'common.e2eeTransferErrNoDeviceId' => '无法获取设备 ID',
			'common.passwordEncryptFailed' => '密码加密失败',
			'common.initConfigTimeout' => '配置获取超时: 请检查网络连接或服务端状态',
			'common.initConfigNetworkError' => ({required Object code}) => '网络故障或服务故障 (HTTP ${code})',
			'common.initConfigProtocolError' => '服务故障协议有误',
			'common.initConfigFetchFailed' => '配置获取失败，请检查网络连接',
			'common.attachmentGetFileFailed' => '无法获取文件，请重试或使用相册选择',
			'common.attachmentGetFileFailedAndroid9' => '文件获取失败，Android 9 可能存在兼容性问题',
			'common.attachmentGetImageDataFailed' => '无法获取图片数据，请重试',
			'common.attachmentGetOriginalImageFailed' => '无法获取原始图片数据',
			'common.saveFailedRetry' => '保存失败，请重试',
			'common.downloadFileNotFound' => '下载文件不存在，请重试',
			'common.downloadHashRetrying' => ({required Object retry, required Object max}) => '文件校验失败，正在重新下载 (${retry}/${max})',
			'common.downloadHashFailed' => '文件多次校验失败，请检查网络后重试',
			'common.e2eeTransferToNewDevice' => '传输到新设备',
			'common.e2eeTransferPendingSection' => '待处理的传输',
			'common.e2eeTransferLoadFailed' => '加载失败',
			'common.e2eeTransferLoadFailedDesc' => '无法加载待处理的传输，请重试',
			'common.e2eeTransferNoPending' => '暂无待处理的传输',
			'common.e2eeTransferNoPendingDesc' => '当有设备向您发送密钥时，会显示在这里',
			'common.e2eeSocialEnoughShards' => '您已有足够的分片可以恢复密钥',
			'common.e2eeSocialMoreShards' => ({required Object count}) => '还有 ${count} 个分片...',
			'common.e2eeProxyLoadFriendsFailed' => '加载好友列表失败，请重试',
			'common.e2eeProxyNoPublicKey' => '该好友没有可用的公钥',
			'common.e2eeProxyGetKeyFailed' => ({required Object name}) => '获取 ${name} 的公钥失败',
			'common.e2eeProxySelectFailed' => '选择代理失败，请重试',
			'common.e2eeProxyNoFriends' => '暂无好友',
			'common.e2eeProxyNoFriendsHint' => '请先添加好友后再设置恢复代理',
			'common.e2eeProxyNeedMore' => ({required Object count, required Object selected}) => '至少需要 ${count} 个信任的联系人，已选择 ${selected} 个',
			'common.e2eeProxyConfirmCount' => ({required Object count}) => '确认选择 (${count} 个代理)',
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
			'common.redPacketOpen' => '抢红包',
			'common.redPacketDetail' => '红包详情',
			'common.transferSend' => '发起转账',
			'common.transferAccept' => '确认收钱',
			'common.greetingDefault' => '恭喜发财，大吉大利',
			'common.redPacketView' => '查看红包',
			'common.redPacketBrand' => 'IMBoy 红包',
			'common.redPacketDialogTitle' => '送你一个红包',
			'common.redPacketDialogSubtitle' => '大吉大利，恭喜发财',
			'common.grabAmountYuan' => ({required Object amount}) => '领到金额：${amount} 元',
			'common.transferAmountYuan' => ({required Object amount}) => '转账金额：${amount} 元',
			'common.insufficientBalance' => '余额不足',
			'common.goToRecharge' => '去充值',
			'common.withdrawSuccess' => '提现成功',
			'common.withdrawConfirm' => '确认提现',
			'common.withdrawAmountError' => '请输入不低于1元的金额',
			'common.withdrawAccountEmpty' => '请输入提现账号',
			'common.withdrawMethod' => '提现方式',
			'common.withdrawAccount' => '提现账号',
			'common.noHistory' => '暂无历史记录',
			'common.enterAmount' => '请输入金额',
			'common.transferDefaultRemark' => '转账给好友',
			'common.transferMinAmountError' => '转账最低金额为 0.1 元',
			'common.redPacketCurrentLucky' => '当前为：拼手气红包',
			'common.redPacketCurrentNormal' => '当前为：普通红包',
			'common.redPacketSwitchToNormal' => '改为普通红包',
			'common.redPacketSwitchToLucky' => '改为拼手气红包',
			'common.transferReceiving' => '正在收款...',
			'common.transferAccepted' => '已收取',
			'common.transferRefunded' => '已退回',
			'common.transferPending' => '等待对方确认',
			'common.transferTapToReceive' => '点击收款',
			'common.redPacketReceiverLabel' => ({required Object uid}) => '用户：${uid}',
			'common.redPacketNotFound' => '红包不存在或已被删除',
			'common.redPacketFetchFailed' => '获取红包详情失败',
			'common.redPacketFetchError' => '获取红包详情异常',
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
			'complaint.complaint' => '投诉',
			'complaintReason.spam' => '垃圾信息',
			'complaintReason.harassment' => '骚扰',
			'complaintReason.inappropriate' => '不当内容',
			'complaintReason.other' => '其他',
			'contact.applyFriend' => '申请好友',
			'contact.applyFriendLogic' => '申请好友逻辑',
			'contact.applyParam' => ({required Object param}) => '申请${param}',
			'contact.blocked' => '已拉黑',
			'contact.applyChanges' => '请重启应用以应用更改',
			'contact.inputNewTag' => '输入新标签...',
			'contact.denylist' => '黑名单',
			'contact.denylistEmpty' => '黑名单为空',
			'contact.denylistEmptyDesc' => '你还没有拉黑任何用户 被拉黑的用户将无法给你发送消息',
			'contact.favoriteGroupTagsEtc' => '收藏、人名、群名、标签等',
			'contact.groupRemarkView' => '群组备注视图',
			'contact.groupRemarkVisibility' => '群聊的备注仅自己可见',
			'contact.newFriend' => '新的朋友',
			'contact.recommendToFriend' => '把他推荐给朋友',
			'contact.remark' => '备注',
			'contact.remarksTags' => '备注和标签',
			'contact.applyFilters' => '应用筛选',
			'contact.selectAGroup' => '选择一个群',
			'contact.selectFriend' => '选择好友',
			'contact.selectFriends' => '选择朋友',
			'contact.selectOrEnterTag' => '选择或输入标签',
			'contact.tags' => '标签',
			'contact.tellFriend' => '告诉朋友',
			'contact.tagNameRequired' => '标签名称不能为空',
			'contact.suggestedTags' => '建议标签',
			'contact.tagManagement' => '标签管理',
			'contact.currentTags' => ({required Object param}) => '当前标签 (${param})',
			'contact.pleaseEnterRemark' => '请输入备注名',
			'contact.enterRemark' => '请输入备注名',
			'contact.pleaseEnterTags' => '请输入标签',
			'contact.momentsVisibilityFriends' => '仅好友',
			'contact.tagLengthExceeded' => ({required Object param}) => '标签长度不能超过 ${param} 个字符',
			'contact.maxTagsExceeded' => ({required Object param}) => '最多只能添加 ${param} 个标签',
			'contact.selectedTags' => ({required Object param, required Object max}) => '已选标签 (${param}/${max})',
			'contact.tagImportant' => '重要',
			'contact.tagUrgent' => '紧急',
			'contact.tagWork' => '工作',
			'contact.tagLife' => '生活',
			'contact.tagStudy' => '学习',
			'contact.tagEntertainment' => '娱乐',
			'contact.tagTravel' => '旅行',
			'contact.tagFood' => '美食',
			'contact.tagHealth' => '健康',
			'contact.tagFamily' => '家庭',
			'contact.tagFriends' => '朋友',
			'contact.tagProject' => '项目',
			'contact.tagIdeas' => '想法',
			'contact.tagMemo' => '备忘',
			'contact.friendRequestSent' => '已发送',
			'contact.channelMaxTagsCount' => '最多可添加 8 个标签',
			'contact.tagInputHint' => '输入标签...',
			'discovery.findNearbyPeople' => '找附近的人',
			'discovery.moment' => '朋友圈',
			'discovery.nearbyPeopleExplain' => '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。\n你的电话号码将会被隐藏。',
			'discovery.peopleNearby' => '附近的人',
			'discovery.peopleNearbyLogic' => '附近的人逻辑',
			'discovery.scan' => '扫一扫',
			'discovery.scanResult' => '扫描结果',
			'discovery.scannerResult' => '扫描结果',
			'discovery.titleDiscover' => '发现',
			'discovery.myChannels' => '我的频道',
			'discovery.channelSquare' => '频道广场',
			'discovery.otherUsersCanFindMe' => '其他用户可以通过搜索找到我',
			'discovery.moments' => '朋友圈',
			'discovery.momentsReport' => '举报动态',
			'discovery.momentsReportDesc' => '补充说明',
			'discovery.momentsComments' => '评论',
			'discovery.momentsWriteComment' => '写评论...',
			'discovery.momentsVisibility' => '可见性',
			'discovery.momentsVisibilityPublic' => '公开',
			'discovery.momentsVisibilityPartial' => '部分可见',
			'discovery.momentsVisibilityExclude' => '不给谁看',
			'discovery.momentsDenyUidsLabel' => '不给谁看 UID 列表（逗号分隔）',
			'discovery.momentsDraftRestored' => '已恢复上次未发送的草稿',
			'discovery.momentsFeedStale' => '网络异常，显示的是缓存内容',
			'discovery.discover' => '发现',
			'discovery.shake' => '摇一摇',
			'discovery.openChannel' => '打开频道',
			'discovery.paidChannelLocked' => '付费频道内容已锁定',
			'discovery.webQRScanned' => '已扫描',
			'error.restartRequired' => '需要重启应用',
			'error.networkFailureGuidance' => '网络失败指引',
			'error.pleaseCheckNetwork' => '请检查你的网络设置。',
			'error.networkTroubleshootingStep1' => '1.打开手机设置并把Wi-Fi开关保持开启状态。',
			'error.networkTroubleshootingStep2' => '2.打开手机设置-通用-蜂窝移动网络，并把蜂窝移动数据开关保持开启状态。',
			'error.networkTroubleshootingStep3' => '3.如果仍无法连接网络，请检查手机接入的Wi-Fi是否已接入互联网或者咨询网络运营商。',
			'error.suggestCheckNetwork' => '建议检查网络设置。',
			'error.e2eeStartRecoveryBtn' => ({required Object required}) => '开始恢复密钥（需要 ${required} 个代理协助）',
			'error.e2eeInsufficientShardBtn' => ({required Object required, required Object current}) => '分片不足（需要 ${required} 个，当前 ${current} 个）',
			'error.e2eeErrTimeout' => '加密超时，请检查网络连接后重试',
			'error.e2eeErrNetwork' => '网络错误，加密失败，消息未发送',
			'error.liveRoomTitleRequired' => '标题不能为空',
			'group.financialManagement' => '理财通',
			'group.enterSameGroup' => '与身边的朋友进入同一个群聊',
			'group.enterTheGroup' => '进入该群',
			'group.groupAlias' => '我在本群的昵称',
			'group.groupAlbum' => '群相册',
			'group.groupDissolve' => '解散群聊',
			'group.groupJoin' => '加入群聊',
			'group.groupLeave' => '退出群聊',
			'group.groupManagement' => '群管理',
			'group.groupMembers' => '群成员',
			'group.groupName' => '群聊名称',
			'group.mutualGroupsWithHer' => '我和他的共同群聊',
			'group.groupOwner' => '群主',
			'group.groupAdmin' => '管理员',
			'group.groupGuest' => '嘉宾',
			'group.groupMember' => '普通成员',
			'group.setAdmin' => '设为管理员',
			'group.transferGroup' => '转让群主',
			'group.joinTime' => '加入时间',
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
			'groupCategory.title' => '群分组',
			'groupCategory.createCategory' => '创建分组',
			'groupCategory.categoryName' => '分组名称',
			'groupCategory.categoryDesc' => '分组描述（可选）',
			'groupCategory.noCategory' => '暂无分组',
			'groupCategory.createFirst' => '创建第一个分组吧',
			'groupCategory.addGroup' => '添加群聊到分组',
			'groupCategory.removeGroup' => '从分组移除',
			'groupCategory.deleteCategory' => '删除分组',
			'groupCategory.deleteCategoryConfirm' => '确定要删除该分组吗？群聊不会被删除。',
			'groupCategory.categoryCreated' => '分组创建成功',
			'groupCategory.categoryDeleted' => '分组已删除',
			'groupCategory.renameCategory' => '重命名分组',
			'groupCategory.categoryRenamed' => '分组重命名成功',
			'groupCategory.renameFailed' => '重命名失败，请重试',
			'groupCategory.deleteFailed' => '删除失败，请重试',
			'groupCategory.categoryDetailTip' => '该分组下的群聊可以在群组列表中通过「移入分组」进行管理',
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
			'groupSchedule.reminder' => '提醒',
			'groupSchedule.noReminder' => '不提醒',
			'groupSchedule.noSchedule' => '暂无日程',
			'groupSchedule.scheduleCreated' => '日程创建成功',
			'groupSchedule.scheduleUpdated' => '日程更新成功',
			'groupSchedule.reminder15min' => '提前15分钟',
			'groupSchedule.reminder1hour' => '提前1小时',
			'groupSchedule.reminder1day' => '提前1天',
			'groupSchedule.startTime' => '开始时间',
			'groupSchedule.endTime' => '结束时间',
			'groupSchedule.participants' => '参与人数',
			'groupSchedule.statusCancelled' => '已取消',
			'groupSchedule.statusInProgress' => '进行中',
			'groupSchedule.cancelSuccess' => '日程已取消',
			'groupSchedule.cancelFailed' => '取消失败，请稍后重试',
			'groupSchedule.confirmAttend' => '确认参加',
			'groupSchedule.declineAttend' => '不参加',
			'groupSchedule.cancelSchedule' => '取消日程',
			'groupSchedule.scheduleIdMissing' => '日程ID缺失，无法查看详情',
			'groupTag.title' => '群标签',
			'groupTag.addTag' => '添加标签',
			'groupTag.tagName' => '标签名称',
			'groupTag.tagColor' => '标签颜色',
			'groupTag.noTag' => '暂无标签',
			'groupTag.tagAdded' => '标签添加成功',
			'groupTag.tagRemoved' => '标签已移除',
			'groupTag.removeTitle' => '移除标签',
			'groupTag.removeConfirm' => '确定要移除这个标签吗？',
			'groupTask.title' => '群作业',
			'groupTask.createTask' => '创建任务',
			'groupTask.taskTitle' => '任务标题',
			'groupTask.taskDescription' => '任务描述',
			'groupTask.assignTo' => '指派给',
			'groupTask.deadline' => '截止时间',
			'groupTask.noDeadline' => '无截止时间',
			'groupTask.noTask' => '暂无任务',
			'groupTask.all' => '全部',
			'groupTask.pending' => '待完成',
			'groupTask.completed' => '已完成',
			'groupTask.taskCreated' => '任务创建成功',
			'groupTask.taskSubmitted' => '任务已提交',
			'groupTask.taskCompleted' => '任务已完成',
			'groupTask.overdue' => '已过期',
			'groupTask.daysLeft' => ({required Object days}) => '${days} 天后截止',
			'groupTask.hoursLeft' => ({required Object hours}) => '${hours} 小时后截止',
			'groupTask.dueSoon' => '即将截止',
			'groupTask.submitFailed' => '提交失败，请稍后重试',
			'groupTask.taskId' => '任务ID',
			'groupTask.pendingReview' => '待审核',
			'groupTask.taskIdMissing' => '任务ID缺失，无法查看详情',
			'groupTask.taskIdMissingSubmit' => '任务ID缺失，无法提交',
			'groupVote.title' => '群投票',
			'groupVote.createVote' => '创建投票',
			'groupVote.voteTitle' => '投票标题',
			'groupVote.voteOptions' => '投票选项',
			'groupVote.addOption' => '添加选项',
			'groupVote.allowMultiple' => '允许多选',
			'groupVote.anonymous' => '匿名投票',
			'groupVote.deadline' => '截止时间',
			'groupVote.noDeadline' => '无截止时间',
			'groupVote.noVote' => '暂无投票',
			'groupVote.voteEnded' => '投票已结束',
			'groupVote.totalVotes' => ({required Object count}) => '共 ${count} 票',
			'groupVote.voteSuccess' => '投票成功',
			'groupVote.hasVoted' => '已投票',
			'groupVote.viewResults' => '查看结果',
			'groupVote.cancelVoteSuccess' => '已取消投票',
			'groupVote.cancelVoteFailed' => '取消失败，请稍后重试',
			'groupVote.endVoteFailed' => '结束失败，请稍后重试',
			'groupVote.eachOptionPerLine' => '每行一个选项',
			'groupVote.statusInProgress' => '进行中',
			'groupVote.updateVote' => '更新投票',
			'groupVote.cancelMyVote' => '取消我的投票',
			'groupVote.voteIdMissing' => '投票ID缺失，无法查看详情',
			'groupVote.participantCount' => ({required Object count}) => '参与人数: ${count}',
			'main.change' => '修改',
			'main.entertainment' => '电影演出',
			'main.lifePayment' => '生活缴费',
			'main.medicalHealth' => '医疗健康',
			'main.meituanDelivery' => '美团外卖',
			'main.tencentService' => '腾讯服务',
			'main.traffic' => '交通出行',
			'main.totalAssets' => '总资产',
			'main.album' => '照片',
			'main.appSize' => '应用大小',
			'main.arSa' => '阿拉伯语（沙特阿拉伯）',
			'main.audio' => '音频',
			'main.barcodeFound' => '找到条形码！',
			'main.botQianFan' => '千帆机器人',
			'main.liveRoomWhipLabel' => 'WHIP 推流地址',
			'main.liveRoomWhepLabel' => 'WHEP 拉流地址',
			'main.cache' => '缓存',
			'main.camera' => '拍摄',
			'main.changeNameView' => '修改名称视图',
			'main.changeParam' => ({required Object param}) => '修改${param}',
			'main.chooseFromAlbum' => '从相册选择',
			'main.clean' => '清理',
			'main.codeSentToParam' => ({required Object param}) => '验证码已发送到${param}',
			'main.codeSentToType' => ({required Object param}) => '验证码已发送到${param}',
			'main.collected' => '已收藏',
			'main.completed' => '已完结',
			'main.copied' => '已复制',
			'main.darkModel' => '深色模式',
			'main.deDd' => '德语（德国）',
			'main.disable' => '禁用',
			'main.earlier' => '更早',
			'main.enGb' => '英国英语',
			'main.enUs' => '美国英语',
			'main.enable' => '启用',
			'main.example' => '例:',
			'main.expired' => '已过期',
			'main.extraItem' => '额外项目',
			'main.faceToFaceLogic' => '面对面建群逻辑',
			'main.favorites' => '收藏',
			'main.female' => '女',
			'main.followSystem' => '跟随系统',
			'main.frFr' => '法语（法国）',
			'main.from' => '来自',
			'main.goClean' => '前往清理',
			'main.good' => '很棒',
			'main.hangup' => '挂断',
			'main.haveSet' => '已设置',
			'main.httpParse' => 'HTTP解析',
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
			'main.liveBroadcast' => '直播',
			'main.liveRoomListView' => '直播间列表视图',
			'main.publisherPage' => '推流页面',
			'main.subscriber' => '订阅者',
			'main.loggingOut' => '正在退出登录...',
			'main.loudspeaker' => '扩音器',
			'main.makeYourselfInvisible' => '让自己不可见',
			'main.makeYourselfVisible' => '让自己可见',
			'main.male' => '男',
			'main.manage' => '管理',
			'main.markImportant' => '重要',
			'main.markImportantDesc' => '标记为重要消息',
			'main.markStar' => '收藏',
			'main.markStarDesc' => '收藏此消息',
			'main.markTodo' => '待办',
			'main.markTodoDesc' => '标记为待办事项',
			'main.multiSelect' => '多选',
			'main.multiSelectMode' => '多选模式',
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
			'main.quickFilters' => '快速筛选',
			'main.quote' => '引用',
			'main.recentlyUsed' => '最近使用',
			'main.releaseEnd' => '松开结束',
			'main.remainingChars' => ({required Object param}) => '还可输入 ${param} 个字符',
			'main.kickMember' => '移出群聊',
			'main.memberDetail' => '成员详情',
			'main.memberRole' => '成员角色',
			'main.replied' => '已回复',
			'main.ringing' => '已响铃...',
			'main.ruRu' => '俄罗斯俄语',
			'main.selectedCount' => ({required Object count}) => '已选 (${count})',
			'main.selected' => '已选',
			'main.sent' => '已发送',
			'main.sentByMe' => '我发送的',
			'main.sentByOthers' => '他人发送的',
			'main.setParam' => ({required Object param}) => '设置${param}',
			'main.setting' => '设置',
			'main.siginQ' => '已经有账号了？',
			'main.signInWith' => ({required Object param}) => '用${param}登录',
			'main.source' => '来源',
			'main.speakingTooShort' => '说话时间太短',
			'main.speed' => '速度',
			'main.star' => _root.main.markStar,
			'main.stillNeeded' => '还需',
			'main.storageSpace' => '存储空间',
			'main.termOfServices' => '服务条款',
			'main.text' => '文本',
			'main.thisWeek' => '本周',
			'main.timeRange' => '时间范围',
			'main.timeWeekdays' => '星期一,星期二,星期三,星期四,星期五,星期六,星期日',
			'main.titleMine' => '我的',
			'main.titleSquare' => '广场',
			'main.tooBad' => '太差了',
			'main.tryAgainQ' => '想再试一次吗？',
			'main.type' => '类型',
			'main.unanswered' => '未应答',
			'main.unnamed' => '未命名',
			'main.upToWords' => ({required Object param}) => '最多${param}个字',
			'main.upgrade' => '升级',
			'main.usedSpace' => '已使用空间',
			'main.webView' => '网页视图',
			'main.you' => '你',
			'main.yourFeel' => '这让你感觉如何?',
			'main.zhCn' => '简体中文',
			'main.zhHant' => '繁体中文',
			'main.bound' => '已绑定',
			'main.correct' => '正确',
			'main.pendingInput' => '待输入',
			'main.lengthCheck' => '长度检查',
			'main.bugReport' => '错误报告',
			'main.deleting' => '删除中...',
			'main.current' => '当前',
			'main.publish' => '发布',
			'main.privacyPolicy' => '隐私政策',
			'main.termsOfService' => '服务条款',
			'main.saving' => _root.common.loading,
			'main.topStories' => '看一看',
			'main.systemDefault' => '系统默认',
			'main.custom' => '自定义',
			'main.previewArea' => '预览区域',
			_ => null,
		} ?? switch (path) {
			'main.simpleTexture' => '简约纹理',
			'main.gradientBlue' => '渐变蓝',
			'main.gradientPurple' => '渐变紫',
			'main.copiedToClipboard' => '已复制到剪贴板',
			'main.copiedLink' => '已复制链接',
			'main.destroyTime' => '销毁时间',
			'main.previewEffect' => '预览效果',
			'main.thisIsTitleText' => '这是标题文本',
			'main.thisIsAuxiliaryText' => '这是辅助说明文字',
			'main.toBeCompleted' => '待完善',
			'main.availableCount' => '可选择',
			'main.mostUsed' => '最常用',
			'main.commentPlaceholder' => '评论...',
			'main.delayMsLabel' => '延时毫秒 (>=100)',
			'main.processed' => '已处理',
			'main.export' => '导出',
			'main.school' => '学校',
			'main.hobbiesAndInterests' => '兴趣爱好',
			'main.interests' => '兴趣爱好',
			'main.pleaseEnterSchool' => '请输入学校',
			'main.pleaseEnterInterests' => '请输入兴趣爱好',
			'main.manageVisibility' => '管理个人信息的可见性',
			'main.exportToLocal' => '导出个人资料到本地',
			'main.exportAsText' => '导出为文本格式',
			'main.selectFromAlbum' => '从相册选择',
			'main.volumeUp' => '音量增加',
			'main.volumeDown' => '音量减少',
			'main.fastRewind' => ({required Object seconds}) => '快退 ${seconds}秒',
			'main.pleaseTryAgain' => '请重试',
			'main.secret' => '保密',
			'main.takePhoto' => '拍照',
			'main.publishing' => '发布中...',
			'main.deletingInProgressPleaseWait' => '正在删除中，请稍候...',
			'main.testUser1' => '用户1',
			'main.testUser2' => '用户2',
			'main.testUser3' => '用户3',
			'main.testUser4' => '用户4',
			'main.testUser5' => '用户5',
			'main.collecting' => '收藏中...',
			'main.user' => '用户',
			'main.recommended' => '推荐',
			'main.larger' => '更大',
			'main.currentLength' => ({required Object param1, required Object param2}) => '当前长度：${param1} / ${param2}',
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
			'main.e2eeSocialRecovery' => '社交恢复',
			'main.e2eeSocialRecoveryDesc' => '通过信任的联系人协助恢复密钥',
			'main.e2eeKeyIdLabel' => '密钥 ID',
			'main.e2eeWarnIrreversible' => '• 此操作不可撤销',
			'main.e2eeWarnNeedRestoreOrNew' => '• 需要从备份恢复或生成新密钥',
			'main.gotIt' => '我知道了',
			'main.e2eeRecoverKeyTitle' => '恢复密钥',
			'main.e2eeCanRecoverKey' => '可以恢复密钥',
			'main.e2eeInsufficientShards' => '分片数量不足',
			'main.e2eeProxyUser' => ({required Object uid}) => '代理用户: ${uid}',
			'main.e2eeShardLabel' => ({required Object index, required Object total}) => '分片 ${index} / ${total}',
			'main.e2eeReloadShards' => '重新加载',
			'main.e2eeRecovering' => '恢复中...',
			'main.e2eeKeyRestored' => '密钥已成功恢复',
			'main.e2eeUsedShards' => ({required Object count}) => '已使用 ${count} 个代理分片',
			'main.e2eePreparing' => '准备恢复...',
			'main.e2eeRecoveryProgressLabel' => ({required Object collected, required Object total}) => '进度: ${collected} / ${total} 个分片',
			'main.e2eeCollectingShards' => ({required Object collected, required Object total}) => '正在收集分片 (${collected}/${total})...',
			'main.e2eeShardsCollected' => '分片收集完成，正在重组密钥...',
			'main.webQRLoggingIn' => '登录中...',
			'main.webQRExpired' => '二维码已过期',
			'main.webQRRefresh' => '刷新二维码',
			'main.webSwitchToQR' => '使用 QR 码登录',
			'main.e2eeErrDefault' => '端到端加密失败，消息未发送',
			'main.e2eeSocialTotalShards' => '总分片数',
			'main.e2eeSocialThreshold' => '恢复阈值',
			'main.e2eeSocialThresholdHint' => ({required Object count}) => '恢复密钥时需要 ${count} 个代理协助',
			'main.e2eeSocialSelectProxy' => '选择恢复代理',
			'main.e2eeSocialProxyNeeded' => ({required Object count}) => '需要 ${count} 个信任的联系人作为代理',
			'main.e2eeSocialProxyDefaultName' => ({required Object uid}) => '用户 ${uid}',
			'main.e2eeSocialShardSentViaWs' => '分片已通过 WebSocket 直接发送到代理设备存储',
			'main.e2eeSocialSentCount' => ({required Object sent, required Object total}) => '已发送到 ${sent} 个代理设备（共 ${total} 个）',
			'main.e2eeSocialManageTitle' => '管理分片',
			'main.e2eeSocialMyShards' => '我的分片',
			'main.e2eeSocialProxyShards' => '代理分片',
			'main.e2eeSocialShardOf' => ({required Object idx, required Object total}) => '分片 ${idx} / ${total}',
			'main.e2eeSocialShardActive' => '活跃',
			'main.e2eeSocialShardUsed' => '已使用',
			'main.e2eeSocialShardValid' => '分片有效',
			'main.e2eeSocialUserShard' => ({required Object uid}) => '用户 ${uid} 的密钥分片',
			'main.e2eeSocialProxyUserLabel' => '代理用户',
			'main.e2eeSocialRecoveryThresholdLabel' => '恢复阈值',
			'main.e2eeSocialShardIndexLabel' => '分片编号',
			'main.e2eeTransferQRHint' => '请在新设备上扫描此二维码',
			'main.e2eeTransferQRExpiry' => ({required Object time}) => '二维码将在 ${time} 过期',
			'main.e2eeTransferRefreshQR' => '刷新二维码',
			'main.e2eeTransferEnterUidTitle' => '输入接收方用户 ID',
			'main.e2eeTransferUidPlaceholder' => '接收方用户 ID',
			'main.e2eeTransferReceiving' => '正在接受传输...',
			'main.e2eeTransferPageTitle' => '设备间传输',
			'main.e2eeTransferPendingItem' => '待处理的密钥传输',
			'main.e2eeTransferPendingItemDesc' => '点击查看详情',
			'main.e2eeTransferView' => '查看',
			'main.e2eeSocialTitle' => '社交恢复',
			'main.e2eeSocialCanRecover' => '可以恢复密钥',
			'main.e2eeSocialSetupProxy' => '设置恢复代理',
			'main.e2eeSocialChooseProxy' => '选择信任的联系人作为恢复代理',
			'main.e2eeSocialExistingShards' => '现有恢复分片',
			'main.e2eeSocialRecoverKeyTitle' => '恢复密钥',
			'main.e2eeSocialRecoverKeyDesc' => '使用代理的分片恢复密钥',
			'main.e2eeSocialManageShardsTitle' => '管理分片',
			'main.e2eeSocialManageShardsDesc' => '查看和管理所有恢复分片',
			'main.e2eeSocialZeroTrustHint1' => '零信任架构：服务端不存储分片，直接联系代理',
			'main.e2eeSocialZeroTrustHint2' => '零信任架构：分片存储在代理设备',
			'main.e2eeSocialZeroTrustHint3' => '零信任架构：分片由代理设备存储，服务端不接触明文',
			'main.e2eeProxyMinCount' => ({required Object count}) => '请至少选择 ${count} 个代理',
			'main.e2eeProxySelectTitle' => '选择恢复代理',
			'main.e2eeProxySelectedCount' => ({required Object selected, required Object total}) => '已选 ${selected} / ${total}',
			'main.e2eeProxyReachedMin' => '已达到最少代理数量',
			'main.liveRoomTitleLabel' => '直播间标题',
			'main.liveRoomTitleHint' => '请输入直播间标题',
			'mention.title' => '@提及',
			'mention.noMention' => '暂无@提及',
			'mention.allRead' => '全部已读',
			'mention.markAsRead' => '标记为已读',
			'mention.newMention' => '新的@提及',
			'mention.fromGroup' => '来自群聊',
			'mention.fromChat' => '来自聊天',
			'mention.viewContext' => '查看上下文',
			'mention.mentionCount' => ({required Object count}) => '${count} 条新提及',
			'mention.mentionAllDenied' => '仅管理员可以 @所有人',
			'mention.navInfoMissing' => '消息定位信息缺失，无法跳转',
			'momentFriendPicker.title' => '选择好友',
			'momentFriendPicker.titleAllow' => '指定可见',
			'momentFriendPicker.titleDeny' => '不给谁看',
			'momentFriendPicker.confirm' => '确定',
			'momentFriendPicker.confirmWithCount' => ({required Object count}) => '确定(${count})',
			'momentFriendPicker.selectedCount' => ({required Object count}) => '已选 ${count} 人',
			'momentFriendPicker.emptyFriends' => '暂无好友',
			'momentFriendPicker.tagsLabel' => '按标签选',
			'momentFriendPicker.emptyTags' => '暂无标签',
			'momentFriendPicker.tagLoadFailed' => '标签加载失败',
			'momentFriendPicker.searchHint' => '搜索好友',
			'momentNotify.title' => '消息通知',
			'momentNotify.emptyTitle' => '暂无新消息',
			'momentNotify.emptyHint' => '好友点赞或评论你的朋友圈后，会出现在这里',
			'momentNotify.actionLike' => '赞了你的朋友圈',
			'momentNotify.actionComment' => '评论了你',
			'momentNotify.markAllRead' => '全部已读',
			'momentNotify.clearAll' => '清空全部',
			'momentNotify.clearConfirmTitle' => '清空所有通知?',
			'momentNotify.clearConfirmMessage' => '清空后无法恢复',
			'momentNotify.confirm' => '确定',
			'momentNotify.cancel' => '取消',
			'momentNotify.delete' => '删除',
			'momentNotify.loadFailed' => '加载失败，请稍后重试',
			'passport.retrievePassword' => '找回密码',
			'passport.hintEmail' => '请输入邮箱',
			'passport.hintMobile' => '请输入手机号',
			'passport.forgetPassword' => '忘记密码？',
			'passport.register' => '注册账号',
			'passport.hintPassword' => '请输入密码',
			'passport.hintVerifyCode' => '请输入验证码',
			'passport.getVerifyCode' => '获取验证码',
			'passport.hasAccount' => '已有账号？',
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
			'splash.slogan' => '畅所欲言，自在沟通',
			'welcome.step1Title' => '简单连接',
			'welcome.step1Desc' => '体验无缝沟通的乐趣。 随时随地，畅所欲言。',
			'welcome.step2Title' => '安全私密',
			'welcome.step2Desc' => '端到端加密 保护你的个人时刻只属于你自己。',
			'welcome.step3Title' => '准备探索？',
			'welcome.step3Desc' => '加入一个充满活力的社区。 让对话开始吧！',
			'welcome.next' => '下一步',
			'welcome.getStarted' => '开始使用',
			'welcome.skip' => '跳过',
			_ => null,
		};
	}
}
