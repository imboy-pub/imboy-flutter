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

	/// zh-CN: '关于'
	String get about => '关于';

	/// zh-CN: '关于应用'
	String get aboutApp => '关于应用';

	/// zh-CN: '接受'
	String get accept => '接受';

	/// zh-CN: '通过朋友验证'
	String get acceptFriendRequest => '通过朋友验证';

	/// zh-CN: '账号'
	String get account => '账号';

	/// zh-CN: '账号安全'
	String get accountSecurity => '账号安全';

	/// zh-CN: '添加朋友'
	String get addFriend => '添加朋友';

	/// zh-CN: '添加手机联系人'
	String get addPhoneContact => '添加手机联系人';

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

	/// zh-CN: '照片'
	String get album => '照片';

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

	/// zh-CN: '你已经输入过了'
	String get alreadyEntered => '你已经输入过了';

	/// zh-CN: '已是成员'
	String get alreadyMember => '已是成员';

	/// zh-CN: '应用大小'
	String get appSize => '应用大小';

	/// zh-CN: '包含APP运行的必要文件，包括 APK 文件、优化的编译器输出和解压的原生库。'
	String get appSizeTips => '包含APP运行的必要文件，包括 APK 文件、优化的编译器输出和解压的原生库。';

	/// zh-CN: '当前账号本地生成的sqlite文件大小；可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。'
	String get appSqliteFileSizeExplain => '当前账号本地生成的sqlite文件大小；可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。';

	/// zh-CN: '申请添加朋友'
	String get applyAddFriend => '申请添加朋友';

	/// zh-CN: 'applyFriend'
	String get applyFriend => 'applyFriend';

	/// zh-CN: 'applyFriendLogic'
	String get applyFriendLogic => 'applyFriendLogic';

	/// zh-CN: '申请{param}'
	String get applyParam => '申请{param}';

	/// zh-CN: '阿拉伯语（沙特阿拉伯）'
	String get arSa => '阿拉伯语（沙特阿拉伯）';

	/// zh-CN: 'attachmentProvider'
	String get attachmentProvider => 'attachmentProvider';

	/// zh-CN: '音频'
	String get audio => '音频';

	/// zh-CN: '语音消息'
	String get audioMessage => '语音消息';

	/// zh-CN: '头像'
	String get avatar => '头像';

	/// zh-CN: '待回复'
	String get awaitingReply => '待回复';

	/// zh-CN: '等待验证'
	String get awaitingVerification => '等待验证';

	/// zh-CN: '找到条形码！'
	String get barcodeFound => '找到条形码！';

	/// zh-CN: '已拉黑'
	String get blocked => '已拉黑';

	/// zh-CN: '千帆机器人'
	String get botQianFan => '千帆机器人';

	/// zh-CN: '名片'
	String get businessCard => '名片';

	/// zh-CN: '对方正忙，请稍后重试'
	String get busyTryAgainLater => '对方正忙，请稍后重试';

	/// zh-CN: '完成'
	String get buttonAccomplish => '完成';

	/// zh-CN: '添加'
	String get buttonAdd => '添加';

	/// zh-CN: '返回'
	String get buttonBack => '返回';

	/// zh-CN: '绑定'
	String get buttonBind => '绑定';

	/// zh-CN: '提升账户安全'
	String get accountSecurityEnhance => '提升账户安全';

	/// zh-CN: '绑定手机号和邮箱，让您的账户更安全'
	String get bindMobileAndEmailTips => '绑定手机号和邮箱，让您的账户更安全';

	/// zh-CN: '绑定手机号'
	String get bindMobile => '绑定手机号';

	/// zh-CN: '用于登录、找回密码和接收重要通知'
	String get bindMobileFor => '用于登录、找回密码和接收重要通知';

	/// zh-CN: '关联邮箱'
	String get linkEmail => '关联邮箱';

	/// zh-CN: '用于登录、身份验证和接收账单'
	String get linkEmailFor => '用于登录、身份验证和接收账单';

	/// zh-CN: '立即绑定'
	String get bindNow => '立即绑定';

	/// zh-CN: '以后再说'
	String get later => '以后再说';

	/// zh-CN: '取消'
	String get buttonCancel => '取消';

	/// zh-CN: 'buttonChangePassword'
	String get buttonChangePassword => 'buttonChangePassword';

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

	/// zh-CN: 'buttonDeleteAccount'
	String get buttonDeleteAccount => 'buttonDeleteAccount';

	/// zh-CN: '邀请码'
	String get buttonInviteCode => '邀请码';

	/// zh-CN: 'buttonLogin'
	String get buttonLogin => 'buttonLogin';

	/// zh-CN: '注销'
	String get buttonLogout => '注销';

	/// zh-CN: 'buttonNextStep'
	String get buttonNextStep => 'buttonNextStep';

	/// zh-CN: '确定'
	String get buttonOk => '确定';

	/// zh-CN: 'buttonRegister'
	String get buttonRegister => 'buttonRegister';

	/// zh-CN: 'buttonResetPassword'
	String get buttonResetPassword => 'buttonResetPassword';

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

	/// zh-CN: '缓存'
	String get cache => '缓存';

	/// zh-CN: '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。'
	String get cacheTips => '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。';

	/// zh-CN: '通话时长'
	String get callDuration => '通话时长';

	/// zh-CN: '正在通话'
	String get calling => '正在通话';

	/// zh-CN: '拍摄'
	String get camera => '拍摄';

	/// zh-CN: '你不能添加自己为好友'
	String get canNotAddYourselfFriend => '你不能添加自己为好友';

	/// zh-CN: '取消'
	String get cancel => '取消';

	/// zh-CN: '此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。'
	String get cancelLogoutBody => '此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。';

	/// zh-CN: '是否终止注销流程？'
	String get cancelLogoutTitle => '是否终止注销流程？';

	/// zh-CN: '已取消'
	String get cancelled => '已取消';

	/// zh-CN: '修改群聊名称后，将在群内通知其他成员。'
	String get changeGroupChatName => '修改群聊名称后，将在群内通知其他成员。';

	/// zh-CN: 'changeNameView'
	String get changeNameView => 'changeNameView';

	/// zh-CN: '修改{param}'
	String get changeParam => '修改{param}';

	/// zh-CN: '聊天记录'
	String get chatHistory => '聊天记录';

	/// zh-CN: '按住说话'
	String get chatHoldDownTalk => '按住说话';

	/// zh-CN: 'chatInput'
	String get chatInput => 'chatInput';

	/// zh-CN: '聊天消息'
	String get chatMessage => '聊天消息';

	/// zh-CN: '聊天、朋友圈、运动数据等'
	String get chatMomentSportDataEtc => '聊天、朋友圈、运动数据等';

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

	/// zh-CN: '置顶成功'
	String get chatSettingPinnedSuccess => '置顶成功';

	/// zh-CN: '已关闭免打扰'
	String get chatSettingUnmuted => '已关闭免打扰';

	/// zh-CN: '取消置顶'
	String get chatSettingUnpinnedSuccess => '取消置顶';

	/// zh-CN: '聊天设置'
	String get chatSettings => '聊天设置';

	/// zh-CN: '检查更新'
	String get checkForUpdates => '检查更新';

	/// zh-CN: '从相册选择'
	String get chooseFromAlbum => '从相册选择';

	/// zh-CN: '清理'
	String get clean => '清理';

	/// zh-CN: '清除全部'
	String get clearAll => '清除全部';

	/// zh-CN: '清空聊天记录'
	String get clearChatRecord => '清空聊天记录';

	/// zh-CN: '验证码已发送到{param}'
	String get codeSentToParam => '验证码已发送到{param}';

	/// zh-CN: '验证码已发送到{param}'
	String get codeSentToType => '验证码已发送到{param}';

	/// zh-CN: '验证码已发送到邮箱'
	String get codeSentToEmail => '验证码已发送到邮箱';

	/// zh-CN: '验证码已发送到手机'
	String get codeSentToMobile => '验证码已发送到手机';

	/// zh-CN: '已收藏'
	String get collected => '已收藏';

	/// zh-CN: '投诉'
	String get complaint => '投诉';

	/// zh-CN: '已完结'
	String get completed => '已完结';

	/// zh-CN: '确认码'
	String get confirmCode => '确认码';

	/// zh-CN: '确认码为空'
	String get confirmCodeError => '确认码为空';

	/// zh-CN: '账户已确认。'
	String get confirmCodeSuccess => '账户已确认。';

	/// zh-CN: '确定删除聊天记录吗？'
	String get confirmDeleteChatRecord => '确定删除聊天记录吗？';

	/// zh-CN: 'confirmNewFriend'
	String get confirmNewFriend => 'confirmNewFriend';

	/// zh-CN: 'confirmNewFriendLogic'
	String get confirmNewFriendLogic => 'confirmNewFriendLogic';

	/// zh-CN: '密码修改成功。'
	String get confirmRecoverSuccess => '密码修改成功。';

	/// zh-CN: 'contactSetting'
	String get contactSetting => 'contactSetting';

	/// zh-CN: 'contactSettingTag'
	String get contactSettingTag => 'contactSettingTag';

	/// zh-CN: 'contactTagListLogic'
	String get contactTagListLogic => 'contactTagListLogic';

	/// zh-CN: '联系人标签'
	String get contactTags => '联系人标签';

	/// zh-CN: '继续下载'
	String get continueDownloading => '继续下载';

	/// zh-CN: '已复制'
	String get copied => '已复制';

	/// zh-CN: '复制'
	String get copy => '复制';

	/// zh-CN: '卡券'
	String get coupon => '卡券';

	/// zh-CN: '面对面建群'
	String get createGroupF2f => '面对面建群';

	/// zh-CN: '这些朋友也将进入群聊'
	String get createGroupF2fConfirmTips => '这些朋友也将进入群聊';

	/// zh-CN: '和身边的朋友输入同样的四个数字，进入同一个群聊'
	String get createGroupF2fTips => '和身边的朋友输入同样的四个数字，进入同一个群聊';

	/// zh-CN: '当前设备'
	String get currentDevice => '当前设备';

	/// zh-CN: '深色模式'
	String get darkModel => '深色模式';

	/// zh-CN: '德语（德国）'
	String get deDd => '德语（德国）';

	/// zh-CN: '删除'
	String get delete => '删除';

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

	/// zh-CN: '黑名单'
	String get denylist => '黑名单';

	/// zh-CN: '黑名单为空'
	String get denylistEmpty => '黑名单为空';

	/// zh-CN: '你还没有拉黑任何用户 被拉黑的用户将无法给你发送消息'
	String get denylistEmptyDesc => '你还没有拉黑任何用户\n被拉黑的用户将无法给你发送消息';

	/// zh-CN: '被拉黑的用户无法给你发送消息，也无法查看你的动态。点击用户可以查看详情。'
	String get denylistNoteDesc => '被拉黑的用户无法给你发送消息，也无法查看你的动态。点击用户可以查看详情。';

	/// zh-CN: '黑名单说明'
	String get denylistNoteTitle => '黑名单说明';

	/// zh-CN: '详情'
	String get details => '详情';

	/// zh-CN: '设备可用空间'
	String get deviceAvailableSpace => '设备可用空间';

	/// zh-CN: '设备详情'
	String get deviceDetails => '设备详情';

	/// zh-CN: '设备列表'
	String get deviceList => '设备列表';

	/// zh-CN: '设备名称'
	String get deviceName => '设备名称';

	/// zh-CN: '设备类型'
	String get deviceType => '设备类型';

	/// zh-CN: '设备已使用空间'
	String get deviceUsedSpace => '设备已使用空间';

	/// zh-CN: '禁用'
	String get disable => '禁用';

	/// zh-CN: '显示你的资料'
	String get displayProfile => '显示你的资料';

	/// zh-CN: '已下载'
	String get downloaded => '已下载';

	/// zh-CN: '更早'
	String get earlier => '更早';

	/// zh-CN: '编辑'
	String get edit => '编辑';

	/// zh-CN: '编辑标签'
	String get editTag => '编辑标签';

	/// zh-CN: '邮箱'
	String get email => '邮箱';

	/// zh-CN: '英国英语'
	String get enGb => '英国英语';

	/// zh-CN: '美国英语'
	String get enUs => '美国英语';

	/// zh-CN: '启用'
	String get enable => '启用';

	/// zh-CN: '与身边的朋友进入同一个群聊'
	String get enterSameGroup => '与身边的朋友进入同一个群聊';

	/// zh-CN: '进入该群'
	String get enterTheGroup => '进入该群';

	/// zh-CN: '对 {param} 的访问被拒绝'
	String get errorAccessDenied => '对 {param} 的访问被拒绝';

	/// zh-CN: '没有找到已安装版本。'
	String get errorCliVersionNotFound => '没有找到已安装版本。';

	/// zh-CN: '{param} 是空的'
	String get errorEmptyDirectory => '{param} 是空的';

	/// zh-CN: '无法连接服务器'
	String get errorFailedConnectServer => '无法连接服务器';

	/// zh-CN: '连接到 {param} 失败'
	String get errorFailedToConnect => '连接到 {param} 失败';

	/// zh-CN: '在 {param} 中没有找到文件'
	String get errorFileNotFound => '在 {param} 中没有找到文件';

	/// zh-CN: '文件夹 {param} 未找到'
	String get errorFolderNotFound => '文件夹 {param} 未找到';

	/// zh-CN: '不支持HTTP协议请求'
	String get errorHttpNotSupported => '不支持HTTP协议请求';

	/// zh-CN: '服务器内部错误'
	String get errorInternalServer => '服务器内部错误';

	/// zh-CN: '{param} 是无效的'
	String get errorInvalid => '{param} 是无效的';

	/// zh-CN: '{param} 不是有效的dart文件'
	String get errorInvalidDart => '{param} 不是有效的dart文件';

	/// zh-CN: '{param} 不是有效的文件或目录'
	String get errorInvalidFileOrDirectory => '{param} 不是有效的文件或目录';

	/// zh-CN: '{param} 不是个有效的json文件'
	String get errorInvalidJson => '{param} 不是个有效的json文件';

	/// zh-CN: '无效的请求'
	String get errorInvalidRequest => '无效的请求';

	/// zh-CN: '{param}长度为{min}-{max}的任意字符'
	String get errorLengthBetween => '{param}长度为{min}-{max}的任意字符';

	/// zh-CN: '请求过多'
	String get errorManyRequest => '请求过多';

	/// zh-CN: '请输入你想移除的 package 名称'
	String get errorNoPackageToRemove => '请输入你想移除的 package 名称';

	/// zh-CN: '{param} 不是有效的文件或URL'
	String get errorNoValidFileOrUrl => '{param} 不是有效的文件或URL';

	/// zh-CN: '{param} 不存在'
	String get errorNonexistentDirectory => '{param} 不存在';

	/// zh-CN: '依赖: {param} 在 pub.dev 中没有找到'
	String get errorPackageNotFound => '依赖: {param} 在 pub.dev 中没有找到';

	/// zh-CN: '密码错误'
	String get errorPassword => '密码错误';

	/// zh-CN: '请求方法被禁止'
	String get errorRequestForbidden => '请求方法被禁止';

	/// zh-CN: '请求语法错误'
	String get errorRequestSyntax => '请求语法错误';

	/// zh-CN: '{param} 是必须的'
	String get errorRequired => '{param} 是必须的';

	/// zh-CN: '需要传入文件或路径'
	String get errorRequiredPath => '需要传入文件或路径';

	/// zh-CN: '两次输入密码不一致'
	String get errorRetypePassword => '两次输入密码不一致';

	/// zh-CN: '{param1} 和 {param2} 是同样的'
	String get errorSame => '{param1} 和 {param2} 是同样的';

	/// zh-CN: '服务器挂了'
	String get errorServerDown => '服务器挂了';

	/// zh-CN: '服务器拒绝执行'
	String get errorServerRefused => '服务器拒绝执行';

	/// zh-CN: 'key中包含不允许的特殊字符. \n key: {param}'
	String get errorSpecialCharactersInKey => 'key中包含不允许的特殊字符. \n key: {param}';

	/// zh-CN: '发生意外错误'
	String get errorUnexpected => '发生意外错误';

	/// zh-CN: '参数 {param} 是多余的'
	String get errorUnnecessaryParameter => '参数 {param} 是多余的';

	/// zh-CN: '参数 {param} 是多余的'
	String get errorUnnecessaryParameterPlural => '参数 {param} 是多余的';

	/// zh-CN: '升级 get_cli 错误'
	String get errorUpdateCli => '升级 get_cli 错误';

	/// zh-CN: '例:'
	String get example => '例:';

	/// zh-CN: '现有密码'
	String get existingPassword => '现有密码';

	/// zh-CN: '已过期'
	String get expired => '已过期';

	/// zh-CN: 'extraItem'
	String get extraItem => 'extraItem';

	/// zh-CN: 'faceToFaceLogic'
	String get faceToFaceLogic => 'faceToFaceLogic';

	/// zh-CN: '无法获取经纬度'
	String get failedGetLatLong => '无法获取经纬度';

	/// zh-CN: '获取地图失败,请重试'
	String get failedGetMapTryAgain => '获取地图失败,请重试';

	/// zh-CN: '发起请求失败，请检查网络连接，或稍后重试'
	String get failedRequestPleaseCheckNetwork => '发起请求失败，请检查网络连接，或稍后重试';

	/// zh-CN: '收藏人名、群名、标签等'
	String get favoriteGroupTagsEtc => '收藏人名、群名、标签等';

	/// zh-CN: '收藏'
	String get favorites => '收藏';

	/// zh-CN: '反馈建议'
	String get feedback => '反馈建议';

	/// zh-CN: 'feedbackBuilder'
	String get feedbackBuilder => 'feedbackBuilder';

	/// zh-CN: '反馈内容不能为空'
	String get feedbackContentRequired => '反馈内容不能为空';

	/// zh-CN: '反馈建议明细'
	String get feedbackDetails => '反馈建议明细';

	/// zh-CN: 'feedbackModel'
	String get feedbackModel => 'feedbackModel';

	/// zh-CN: 'feedbackReplyModel'
	String get feedbackReplyModel => 'feedbackReplyModel';

	/// zh-CN: '你的反馈问题我们已经收到了，会尽快处理！'
	String get feedbackSuccessMsg => '你的反馈问题我们已经收到了，会尽快处理！';

	/// zh-CN: '女'
	String get female => '女';

	/// zh-CN: '文件'
	String get file => '文件';

	/// zh-CN: '[文件]'
	String get fileMessage => '[文件]';

	/// zh-CN: '文件大小'
	String get fileSize => '文件大小';

	/// zh-CN: '找附近的人'
	String get findNearbyPeople => '找附近的人';

	/// zh-CN: '跟随系统'
	String get followSystem => '跟随系统';

	/// zh-CN: '开启后,将跟随系统打开或关闭深色模式'
	String get followSystemTips => '开启后,将跟随系统打开或关闭深色模式';

	/// zh-CN: '您已被设备【{param}】强制下线'
	String get forceLogoutNotification => '您已被设备【{param}】强制下线';

	/// zh-CN: '忘记密码？'
	String get forgotPassword => '忘记密码？';

	/// zh-CN: 'forgotPasswordPinCodeView'
	String get forgotPasswordPinCodeView => 'forgotPasswordPinCodeView';

	/// zh-CN: '转发'
	String get forward => '转发';

	/// zh-CN: '转发回复'
	String get forwardReply => '转发回复';

	/// zh-CN: '转发给'
	String get forwardTo => '转发给';

	/// zh-CN: '转发给朋友'
	String get forwardToFriend => '转发给朋友';

	/// zh-CN: '法语（法国）'
	String get frFr => '法语（法国）';

	/// zh-CN: '朋友权限'
	String get friendPermissions => '朋友权限';

	/// zh-CN: 'friendsPermissionsView'
	String get friendsPermissionsView => 'friendsPermissionsView';

	/// zh-CN: '来自'
	String get from => '来自';

	/// zh-CN: '性别'
	String get gender => '性别';

	/// zh-CN: '性别设置冲突，请重试'
	String get genderConflictError => '性别设置冲突，请重试';

	/// zh-CN: '网络异常，请检查网络连接'
	String get genderNetworkError => '网络异常，请检查网络连接';

	/// zh-CN: '保存中...'
	String get genderSaving => '保存中...';

	/// zh-CN: '性别设置失败，请重试'
	String get genderUpdateFailed => '性别设置失败，请重试';

	/// zh-CN: '性别设置成功'
	String get genderUpdateSuccess => '性别设置成功';

	/// zh-CN: '前往清理'
	String get goClean => '前往清理';

	/// zh-CN: '很棒'
	String get good => '很棒';

	/// zh-CN: '非常棒'
	String get great => '非常棒';

	/// zh-CN: '保存到通讯录'
	String get groupAddLocal => '保存到通讯录';

	/// zh-CN: '我在本群的昵称'
	String get groupAlias => '我在本群的昵称';

	/// zh-CN: '群公告'
	String get groupAnnouncement => '群公告';

	/// zh-CN: '群聊'
	String get groupChat => '群聊';

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

	/// zh-CN: '群二维码'
	String get groupQrcode => '群二维码';

	/// zh-CN: '该二维码{days}天内（{date}前）有效，重新进入将更新'
	String get groupQrcodeTips => '该二维码{days}天内（{date}前）有效，重新进入将更新';

	/// zh-CN: 'groupRemarkView'
	String get groupRemarkView => 'groupRemarkView';

	/// zh-CN: '群聊的备注仅自己可见'
	String get groupRemarkVisibility => '群聊的备注仅自己可见';

	/// zh-CN: '群名称和群简介'
	String get groupSearchTips => '群名称和群简介';

	/// zh-CN: '挂断'
	String get hangup => '挂断';

	/// zh-CN: '已设置'
	String get haveSet => '已设置';

	/// zh-CN: '帮助文档'
	String get helpDocument => '帮助文档';

	/// zh-CN: '编辑群公告'
	String get hintEditGroupAnnouncement => '编辑群公告';

	/// zh-CN: '账号/邮箱'
	String get hintLoginAccount => '账号/邮箱';

	/// zh-CN: 'httpParse'
	String get httpParse => 'httpParse';

	/// zh-CN: 'httpResponse'
	String get httpResponse => 'httpResponse';

	/// zh-CN: '我是'
	String get iAm => '我是';

	/// zh-CN: '图片'
	String get image => '图片';

	/// zh-CN: '[图片]'
	String get imageMessage => '[图片]';

	/// zh-CN: '{param}呼入'
	String get incomingCall => '{param}呼入';

	/// zh-CN: '信息'
	String get info => '信息';

	/// zh-CN: '你的账号已于{param}在其他设备登录'
	String get infoLoggedInOnAnotherDevice => '你的账号已于{param}在其他设备登录';

	/// zh-CN: '发起群聊'
	String get initiateChat => '发起群聊';

	/// zh-CN: '立即安装'
	String get installNow => '立即安装';

	/// zh-CN: 'AppStore未上架或AppID[{param}]不存在'
	String get iosAppIdUnknown => 'AppStore未上架或AppID[{param}]不存在';

	/// zh-CN: '意大利语（意大利）'
	String get itIt => '意大利语（意大利）';

	/// zh-CN: '日语（日本）'
	String get jaJp => '日语（日本）';

	/// zh-CN: '仅聊天'
	String get justChat => '仅聊天';

	/// zh-CN: '保密'
	String get keepSecret => '保密';

	/// zh-CN: '韩语（韩国）'
	String get koKr => '韩语（韩国）';

	/// zh-CN: '语言设置'
	String get languageSetting => '语言设置';

	/// zh-CN: 'languageState'
	String get languageState => 'languageState';

	/// zh-CN: '最近活跃时间'
	String get lastActiveTime => '最近活跃时间';

	/// zh-CN: '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。'
	String get lastActiveTips => '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。';

	/// zh-CN: '{param}天前'
	String get lastSeenDaysAgo => '{param}天前';

	/// zh-CN: '隐藏在线状态'
	String get lastSeenHide => '隐藏在线状态';

	/// zh-CN: '{param}小时前'
	String get lastSeenHoursAgo => '{param}小时前';

	/// zh-CN: '刚刚上线'
	String get lastSeenJustNow => '刚刚上线';

	/// zh-CN: '很久以前上线'
	String get lastSeenLongTimeAgo => '很久以前上线';

	/// zh-CN: '{param}分钟前'
	String get lastSeenMinutesAgo => '{param}分钟前';

	/// zh-CN: '{param}个月前'
	String get lastSeenMonthsAgo => '{param}个月前';

	/// zh-CN: '从未上线'
	String get lastSeenNever => '从未上线';

	/// zh-CN: '{param}周前'
	String get lastSeenWeeksAgo => '{param}周前';

	/// zh-CN: '上次在线 {param}'
	String get lastSeenExactTime => '上次在线 {param}';

	/// zh-CN: '请留下您宝贵的意见和建议'
	String get leaveYourSuggestions => '请留下您宝贵的意见和建议';

	/// zh-CN: '《软件许可及服务协议》'
	String get licenseAgreement => '《软件许可及服务协议》';

	/// zh-CN: '直播'
	String get liveBroadcast => '直播';

	/// zh-CN: 'liveRoomListView'
	String get liveRoomListView => 'liveRoomListView';

	/// zh-CN: '推流页面'
	String get publisherPage => '推流页面';

	/// zh-CN: '订阅者'
	String get subscriber => '订阅者';

	/// zh-CN: '加载失败，请重试'
	String get loadError => '加载失败，请重试';

	/// zh-CN: '加载更多'
	String get loadMore => '加载更多';

	/// zh-CN: '加载中'
	String get loading => '加载中';

	/// zh-CN: '位置'
	String get location => '位置';

	/// zh-CN: '位置消息'
	String get locationMessage => '位置消息';

	/// zh-CN: '退出登录'
	String get logOut => '退出登录';

	/// zh-CN: '登录'
	String get login => '登录';

	/// zh-CN: '登录设备管理'
	String get loginDeviceManagement => '登录设备管理';

	/// zh-CN: '你的帐号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。'
	String get loginDeviceManagementTips => '你的帐号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。';

	/// zh-CN: '登录邮箱'
	String get loginEmail => '登录邮箱';

	/// zh-CN: '注销账号'
	String get logoutAccount => '注销账号';

	/// zh-CN: '《注销须知》'
	String get logoutNotice => '《注销须知》';

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

	/// zh-CN: '手动选择'
	String get manually => '手动选择';

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

	/// zh-CN: '消息'
	String get message => '消息';

	/// zh-CN: '发消息'
	String get messageCall => '发消息';

	/// zh-CN: '消息内容'
	String get messageContent => '消息内容';

	/// zh-CN: 'messageHandlingMixin'
	String get messageHandlingMixin => 'messageHandlingMixin';

	/// zh-CN: 'messageLocationBuilder'
	String get messageLocationBuilder => 'messageLocationBuilder';

	/// zh-CN: '消息标记'
	String get messageMarkTitle => '消息标记';

	/// zh-CN: '消息免打扰'
	String get messageMute => '消息免打扰';

	/// zh-CN: '消息通知'
	String get messageNotification => '消息通知';

	/// zh-CN: '消息已撤回'
	String get messageRevoked => '消息已撤回';

	/// zh-CN: 'messageRevokedBuilder'
	String get messageRevokedBuilder => 'messageRevokedBuilder';

	/// zh-CN: '消息类型'
	String get messageType => '消息类型';

	/// zh-CN: 'messageVisitCardBuilder'
	String get messageVisitCardBuilder => 'messageVisitCardBuilder';

	/// zh-CN: '撤回了一条消息'
	String get messageWasWithdrawn => '撤回了一条消息';

	/// zh-CN: 'messageWebrtcBuilder'
	String get messageWebrtcBuilder => 'messageWebrtcBuilder';

	/// zh-CN: '麦克风'
	String get microphone => '麦克风';

	/// zh-CN: '未获取到麦克风权限'
	String get microphonePermissionNotObtained => '未获取到麦克风权限';

	/// zh-CN: '手机'
	String get mobile => '手机';

	/// zh-CN: '一键登录'
	String get mobileQuickLogin => '一键登录';

	/// zh-CN: '朋友圈'
	String get moment => '朋友圈';

	/// zh-CN: '朋友圈和状态'
	String get momentStatus => '朋友圈和状态';

	/// zh-CN: '更多信息'
	String get moreInfo => '更多信息';

	/// zh-CN: '多选'
	String get multiSelect => '多选';

	/// zh-CN: '多选模式'
	String get multiSelectMode => '多选模式';

	/// zh-CN: '我和他的共同群聊'
	String get mutualGroupsWithHer => '我和他的共同群聊';

	/// zh-CN: '我的账号'
	String get myAccount => '我的账号';

	/// zh-CN: '我的地址'
	String get myAddress => '我的地址';

	/// zh-CN: '我的收藏'
	String get myFavorites => '我的收藏';

	/// zh-CN: '我的直播'
	String get myLive => '我的直播';

	/// zh-CN: '我的二维码'
	String get myQrcode => '我的二维码';

	/// zh-CN: '名称'
	String get name => '名称';

	/// zh-CN: '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。 你的电话号码将会被隐藏。'
	String get nearbyPeopleExplain => '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。\n\n你的电话号码将会被隐藏。';

	/// zh-CN: '和附近的人交换联系方式，结交新朋友'
	String get nearbyPeopleTips => '和附近的人交换联系方式，结交新朋友';

	/// zh-CN: '需要继续加油'
	String get needContinueWorkHard => '需要继续加油';

	/// zh-CN: '需要确认提交，该操作才生效'
	String get needSubmitEffect => '需要确认提交，该操作才生效';

	/// zh-CN: '网络连接异常'
	String get networkException => '网络连接异常';

	/// zh-CN: '网络状态异常，需要打开网络才能够查看数据'
	String get networkExceptionPlaseNeedNetworkToViewData => '网络状态异常，需要打开网络才能够查看数据';

	/// zh-CN: 'networkFailureGuidance'
	String get networkFailureGuidance => 'networkFailureGuidance';

	/// zh-CN: 'networkFailureTips'
	String get networkFailureTips => 'networkFailureTips';

	/// zh-CN: '网络故障，请重试！'
	String get networkFailureTryAgain => '网络故障，请重试！';

	/// zh-CN: '当前网络不可用。'
	String get networkNotAvailable => '当前网络不可用。';

	/// zh-CN: '新的朋友'
	String get newFriend => '新的朋友';

	/// zh-CN: '新的密码'
	String get newPassword => '新的密码';

	/// zh-CN: '检测到新版本'
	String get newVersionDetected => '检测到新版本';

	/// zh-CN: '新注册的人'
	String get newlyRegisteredPeople => '新注册的人';

	/// zh-CN: '下一步'
	String get nextStep => '下一步';

	/// zh-CN: '昵称'
	String get nickname => '昵称';

	/// zh-CN: '昵称修改后，只会在此群内显示，群内成员都可以看见。'
	String get nicknameChangeVisibility => '昵称修改后，只会在此群内显示，群内成员都可以看见。';

	/// zh-CN: '还可输入{param}个字符'
	String get nicknameCharsRemaining => '还可输入{param}个字符';

	/// zh-CN: '昵称已被使用，请选择其他昵称'
	String get nicknameConflictError => '昵称已被使用，请选择其他昵称';

	/// zh-CN: '昵称不能仅包含表情符号'
	String get nicknameEmojiOnlyError => '昵称不能仅包含表情符号';

	/// zh-CN: '昵称不能为空'
	String get nicknameEmptyError => '昵称不能为空';

	/// zh-CN: '请输入昵称'
	String get nicknameHint => '请输入昵称';

	/// zh-CN: '昵称长度应在2-24个字符之间'
	String get nicknameLengthError => '昵称长度应在2-24个字符之间';

	/// zh-CN: '网络异常，请检查网络连接'
	String get nicknameNetworkError => '网络异常，请检查网络连接';

	/// zh-CN: '保存中...'
	String get nicknameSaving => '保存中...';

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

	/// zh-CN: '还不错'
	String get notBad => '还不错';

	/// zh-CN: '未绑定'
	String get notBound => '未绑定';

	/// zh-CN: '未填写'
	String get notFilled => '未填写';

	/// zh-CN: '您没有安装任何地图APP哦'
	String get notInstallAnyMapApp => '您没有安装任何地图APP哦';

	/// zh-CN: '不让他（她）看'
	String get notLetHimSee => '不让他（她）看';

	/// zh-CN: '没有收到验证码？'
	String get notReceiveCoeQ => '没有收到验证码？';

	/// zh-CN: '不看他（她）'
	String get notSeeHim => '不看他（她）';

	/// zh-CN: '未设置'
	String get notSet => '未设置';

	/// zh-CN: '不显示'
	String get notShow => '不显示';

	/// zh-CN: '您还没有打开位置信息服务'
	String get notTurnedLocationService => '您还没有打开位置信息服务';

	/// zh-CN: '未检测到新版本'
	String get nowNewVersion => '未检测到新版本';

	/// zh-CN: '{param}个'
	String get numUnit => '{param}个';

	/// zh-CN: '已关闭'
	String get off => '已关闭';

	/// zh-CN: '离线'
	String get offline => '离线';

	/// zh-CN: '下线通知'
	String get offlineNotification => '下线通知';

	/// zh-CN: '已开启'
	String get on => '已开启';

	/// zh-CN: '在线'
	String get online => '在线';

	/// zh-CN: '在浏览器中打开'
	String get openInBrowser => '在浏览器中打开';

	/// zh-CN: '操作失败，请稍后重试'
	String get operationFailedAgainLater => '操作失败，请稍后重试';

	/// zh-CN: '不'
	String get optionsNo => '不';

	/// zh-CN: '我想重命名'
	String get optionsRename => '我想重命名';

	/// zh-CN: '是的!'
	String get optionsYes => '是的!';

	/// zh-CN: '或者'
	String get or => '或者';

	/// zh-CN: '对方'
	String get otherParty => '对方';

	/// zh-CN: 'p2pCallScreenLogic'
	String get p2pCallScreenLogic => 'p2pCallScreenLogic';

	/// zh-CN: 'p2pCallScreenView'
	String get p2pCallScreenView => 'p2pCallScreenView';

	/// zh-CN: '包大小'
	String get packageSize => '包大小';

	/// zh-CN: '{param}已存在'
	String get paramAlreadyExist => '{param}已存在';

	/// zh-CN: '{param}格式有误'
	String get paramFormatError => '{param}格式有误';

	/// zh-CN: '{param}登录'
	String get paramLogin => '{param}登录';

	/// zh-CN: '密码'
	String get password => '密码';

	/// zh-CN: '暂停下载'
	String get pauseDownloading => '暂停下载';

	/// zh-CN: '对方已挂断'
	String get peerHasHungUp => '对方已挂断';

	/// zh-CN: '对方无应答...'
	String get peerNoResponse => '对方无应答...';

	/// zh-CN: 'peopleInfoMoreLogic'
	String get peopleInfoMoreLogic => 'peopleInfoMoreLogic';

	/// zh-CN: 'peopleInfoSameGroupView'
	String get peopleInfoSameGroupView => 'peopleInfoSameGroupView';

	/// zh-CN: '附近的人'
	String get peopleNearby => '附近的人';

	/// zh-CN: 'peopleNearbyLogic'
	String get peopleNearbyLogic => 'peopleNearbyLogic';

	/// zh-CN: '每分钟只能请求一次'
	String get perMinuteOnce => '每分钟只能请求一次';

	/// zh-CN: 'permission'
	String get permission => 'permission';

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

	/// zh-CN: '置顶'
	String get pin => '置顶';

	/// zh-CN: '置顶聊天'
	String get pinChat => '置顶聊天';

	/// zh-CN: '请把方格填满'
	String get pinCodeFillTips => '请把方格填满';

	/// zh-CN: '已置顶'
	String get pinned => '已置顶';

	/// zh-CN: '播放'
	String get play => '播放';

	/// zh-CN: '请检查你的网络设置。'
	String get pleaseCheckNetwork => '请检查你的网络设置。';

	/// zh-CN: '请输入{param}'
	String get pleaseInputParam => '请输入{param}';

	/// zh-CN: '请选择'
	String get pleaseSelect => '请选择';

	/// zh-CN: '请选择要添加的成员'
	String get pleaseSelectMembersForAdd => '请选择要添加的成员';

	/// zh-CN: '私聊回复'
	String get privateReply => '私聊回复';

	/// zh-CN: '资料设置'
	String get profileSettings => '资料设置';

	/// zh-CN: '二维码名片'
	String get qrCodeBusinessCard => '二维码名片';

	/// zh-CN: '快速筛选'
	String get quickFilters => '快速筛选';

	/// zh-CN: '引用'
	String get quote => '引用';

	/// zh-CN: '引用回复'
	String get quoteReply => '引用回复';

	/// zh-CN: '评级'
	String get rating => '评级';

	/// zh-CN: '重新编辑'
	String get reEdit => '重新编辑';

	/// zh-CN: '已经阅读并同意{param}'
	String get readAgreeParam => '已经阅读并同意{param}';

	/// zh-CN: '最近聊天'
	String get recentChats => '最近聊天';

	/// zh-CN: '最近转发'
	String get recentForwards => '最近转发';

	/// zh-CN: 'recentlyRegisteredUser'
	String get recentlyRegisteredUser => 'recentlyRegisteredUser';

	/// zh-CN: '最近使用'
	String get recentlyUsed => '最近使用';

	/// zh-CN: '把他推荐给朋友'
	String get recommendToFriend => '把他推荐给朋友';

	/// zh-CN: '我们会将密码恢复码发送到您的邮箱。'
	String get recoverCodePasswordDesc => '我们会将密码恢复码发送到您的邮箱。';

	/// zh-CN: '找回密码'
	String get recoverPassword => '找回密码';

	/// zh-CN: ''
	String get recoverPasswordDesc => '';

	/// zh-CN: '不要感觉不好，这是常有的事。'
	String get recoverPasswordIntro => '不要感觉不好，这是常有的事。';

	/// zh-CN: '验证码发送成功'
	String get recoverPasswordSuccess => '验证码发送成功';

	/// zh-CN: '地区'
	String get region => '地区';

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

	/// zh-CN: '松开结束'
	String get releaseEnd => '松开结束';

	/// zh-CN: '松开手指,取消发送'
	String get releaseFingerCancelSending => '松开手指,取消发送';

	/// zh-CN: '还可输入 {param} 个字符'
	String get remainingChars => '还可输入 {param} 个字符';

	/// zh-CN: '备注'
	String get remark => '备注';

	/// zh-CN: '备注和标签'
	String get remarksTags => '备注和标签';

	/// zh-CN: '下次再说'
	String get remindMeLater => '下次再说';

	/// zh-CN: '从标签中移除联系人'
	String get removeContactFromTag => '从标签中移除联系人';

	/// zh-CN: '移出成员'
	String get removeMember => '移出成员';

	/// zh-CN: '已回复'
	String get replied => '已回复';

	/// zh-CN: '回复于'
	String get repliedAt => '回复于';

	/// zh-CN: '回复'
	String get reply => '回复';

	/// zh-CN: '回复'
	String get replyTo => '回复';

	/// zh-CN: '重发验证码'
	String get resendCode => '重发验证码';

	/// zh-CN: '已发送新邮件。'
	String get resendCodeSuccess => '已发送新邮件。';

	/// zh-CN: '重置筛选'
	String get resetFilters => '重置筛选';

	/// zh-CN: '重新输入密码'
	String get retypePassword => '重新输入密码';

	/// zh-CN: '撤回'
	String get revoke => '撤回';

	/// zh-CN: '已响铃...'
	String get ringing => '已响铃...';

	/// zh-CN: '俄罗斯俄语'
	String get ruRu => '俄罗斯俄语';

	/// zh-CN: '保存二维码'
	String get saveQrCode => '保存二维码';

	/// zh-CN: '保存成功'
	String get saveSuccess => '保存成功';

	/// zh-CN: '扫一扫'
	String get scan => '扫一扫';

	/// zh-CN: '扫描二维码'
	String get scanQrCode => '扫描二维码';

	/// zh-CN: '扫描二维码名片'
	String get scanQrCodeBusinessCard => '扫描二维码名片';

	/// zh-CN: '扫一扫上面的二维码图案，加我为朋友'
	String get scanQrcodeAddFriend => '扫一扫上面的二维码图案，加我为朋友';

	/// zh-CN: '扫描结果'
	String get scanResult => '扫描结果';

	/// zh-CN: 'scannerResult'
	String get scannerResult => 'scannerResult';

	/// zh-CN: '搜索'
	String get search => '搜索';

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

	/// zh-CN: '应用筛选'
	String get applyFilters => '应用筛选';

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

	/// zh-CN: '第 {current} 个，共 {total} 个结果'
	String get searchResultsCount => '第 {current} 个，共 {total} 个结果';

	/// zh-CN: '搜索建议'
	String get searchSuggestions => '搜索建议';

	/// zh-CN: '安全中心'
	String get securityCenter => '安全中心';

	/// zh-CN: '选择一个群'
	String get selectAGroup => '选择一个群';

	/// zh-CN: '全选'
	String get selectAll => '全选';

	/// zh-CN: '选择联系人'
	String get selectContacts => '选择联系人';

	/// zh-CN: '已选 ({count})'
	String get selectedCount => '已选 ({count})';

	/// zh-CN: 'selectFriend'
	String get selectFriend => 'selectFriend';

	/// zh-CN: '选择朋友'
	String get selectFriends => '选择朋友';

	/// zh-CN: '选择群聊'
	String get selectGroup => '选择群聊';

	/// zh-CN: '选择或输入标签'
	String get selectOrEnterTag => '选择或输入标签';

	/// zh-CN: 'selectRegionView'
	String get selectRegionView => 'selectRegionView';

	/// zh-CN: '已选'
	String get selected => '已选';

	/// zh-CN: '{param} 个选定项目'
	String get selectedItems => '{param} 个选定项目';

	/// zh-CN: '已选地区'
	String get selectedRegion => '已选地区';

	/// zh-CN: '发送添加朋友申请'
	String get sendFriendRequest => '发送添加朋友申请';

	/// zh-CN: '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。'
	String get sendMsgNotFriendTips => '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。';

	/// zh-CN: '消息已发出，但被对方拒收了。'
	String get sendMsgRejected => '消息已发出，但被对方拒收了。';

	/// zh-CN: '分别发送给'
	String get sendSeparatelyTo => '分别发送给';

	/// zh-CN: '发送给'
	String get sendTo => '发送给';

	/// zh-CN: '发送者'
	String get sender => '发送者';

	/// zh-CN: '正在发送...'
	String get sending => '正在发送...';

	/// zh-CN: '已发送'
	String get sent => '已发送';

	/// zh-CN: '我发送的'
	String get sentByMe => '我发送的';

	/// zh-CN: '他人发送的'
	String get sentByOthers => '他人发送的';

	/// zh-CN: '设置当前聊天背景'
	String get setChatBackground => '设置当前聊天背景';

	/// zh-CN: '设置昵称'
	String get setNickname => '设置昵称';

	/// zh-CN: '设置{param}'
	String get setParam => '设置{param}';

	/// zh-CN: '设置'
	String get setting => '设置';

	/// zh-CN: '分享'
	String get share => '分享';

	/// zh-CN: '已经有账号了？'
	String get siginQ => '已经有账号了？';

	/// zh-CN: '用{param}登录'
	String get signInWith => '用{param}登录';

	/// zh-CN: '个性签名'
	String get signature => '个性签名';

	/// zh-CN: '签名输入提示'
	String get signatureInputHint => '签名输入提示';

	/// zh-CN: '签名占位符'
	String get signaturePlaceholder => '签名占位符';

	/// zh-CN: '签名提示'
	String get signatureTips => '签名提示';

	/// zh-CN: '注册'
	String get signup => '注册';

	/// zh-CN: '请填写此表格以完成注册'
	String get signupFormDesc => '请填写此表格以完成注册';

	/// zh-CN: '确认码已发送到您的邮箱， 请输入确认码确认您的帐户。'
	String get signupIntro => '确认码已发送到您的邮箱，\n请输入确认码确认您的帐户。';

	/// zh-CN: '手指上滑,取消发送'
	String get slideUpCancelSending => '手指上滑,取消发送';

	/// zh-CN: '社交资料'
	String get socialProfile => '社交资料';

	/// zh-CN: '来源'
	String get source => '来源';

	/// zh-CN: '通过扫一扫添加'
	String get sourceQrcode => '通过扫一扫添加';

	/// zh-CN: '说话时间太短'
	String get speakingTooShort => '说话时间太短';

	/// zh-CN: '速度'
	String get speed => '速度';

	/// zh-CN: '收藏'
	String get star => '收藏';

	/// zh-CN: '状态'
	String get status => '状态';

	/// zh-CN: '还需'
	String get stillNeeded => '还需';

	/// zh-CN: '未获取存储权限'
	String get storagePermissionNotObtained => '未获取存储权限';

	/// zh-CN: '存储空间'
	String get storageSpace => '存储空间';

	/// zh-CN: '存储空间和数据'
	String get storageSpaceData => '存储空间和数据';

	/// zh-CN: '强提醒'
	String get strongReminder => '强提醒';

	/// zh-CN: '提交于'
	String get submittedAt => '提交于';

	/// zh-CN: '确认删除吗？删除后不可恢复。'
	String get sureDeleteData => '确认删除吗？删除后不可恢复。';

	/// zh-CN: '确定删除群的聊天记录吗？'
	String get sureDeleteGroupChatRecord => '确定删除群的聊天记录吗？';

	/// zh-CN: '确定要打开文件吗？'
	String get sureOpenTheFile => '确定要打开文件吗？';

	/// zh-CN: '确定要解散本群吗？'
	String get sureToDissolveGroup => '确定要解散本群吗？';

	/// zh-CN: '确定要退出本群吗？'
	String get sureToLeaveGroup => '确定要退出本群吗？';

	/// zh-CN: '切换账号'
	String get switchAccount => '切换账号';

	/// zh-CN: '切换环境'
	String get switchEnvironment => '切换环境';

	/// zh-CN: '标签'
	String get tags => '标签';

	/// zh-CN: '告诉朋友'
	String get tellFriend => '告诉朋友';

	/// zh-CN: '服务条款'
	String get termOfServices => '服务条款';

	/// zh-CN: '文本'
	String get text => '文本';

	/// zh-CN: '文本消息'
	String get textMessage => '文本消息';

	/// zh-CN: '本月'
	String get thisMonth => '本月';

	/// zh-CN: '本周'
	String get thisWeek => '本周';

	/// zh-CN: '{param}天前'
	String get timeDaysAgo => '{param}天前';

	/// zh-CN: '{param}小时前'
	String get timeHoursAgo => '{param}小时前';

	/// zh-CN: '刚刚'
	String get timeJustNow => '刚刚';

	/// zh-CN: '{param}分钟前'
	String get timeMinutesAgo => '{param}分钟前';

	/// zh-CN: '时间范围'
	String get timeRange => '时间范围';

	/// zh-CN: '今天'
	String get timeToday => '今天';

	/// zh-CN: '星期一,星期二,星期三,星期四,星期五,星期六,星期日'
	String get timeWeekdays => '星期一,星期二,星期三,星期四,星期五,星期六,星期日';

	/// zh-CN: '昨天'
	String get timeYesterday => '昨天';

	/// zh-CN: '无网络'
	String get tipConnectDesc => '无网络';

	/// zh-CN: '将联系人"{param}"删除，同时删除与该联系人的聊天记录'
	String get tipDeleteContact => '将联系人"{param}"删除，同时删除与该联系人的聊天记录';

	/// zh-CN: '占设备 {param1}‰ 存储空间({param2})'
	String get tipDeviceSpace => '占设备 {param1}‰ 存储空间({param2})';

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

	/// zh-CN: '消息'
	String get titleMessage => '消息';

	/// zh-CN: '我的'
	String get titleMine => '我的';

	/// zh-CN: '今天'
	String get today => '今天';

	/// zh-CN: '太差了'
	String get tooBad => '太差了';

	/// zh-CN: '置顶聊天'
	String get topChat => '置顶聊天';

	/// zh-CN: '想再试一次吗？'
	String get tryAgainQ => '想再试一次吗？';

	/// zh-CN: '类型'
	String get type => '类型';

	/// zh-CN: '输入消息...'
	String get typeMessage => '输入消息...';

	/// zh-CN: '未应答'
	String get unanswered => '未应答';

	/// zh-CN: '未知'
	String get unknown => '未知';

	/// zh-CN: '未知消息'
	String get unknownMessage => '未知消息';

	/// zh-CN: '未命名'
	String get unnamed => '未命名';

	/// zh-CN: '取消置顶'
	String get unpin => '取消置顶';

	/// zh-CN: '不支持的文件类型'
	String get unsupportedFileType => '不支持的文件类型';

	/// zh-CN: '最多{param}个字'
	String get upToWords => '最多{param}个字';

	/// zh-CN: '更新日志'
	String get updateLog => '更新日志';

	/// zh-CN: '立即更新'
	String get updateNow => '立即更新';

	/// zh-CN: 'upgrade'
	String get upgrade => 'upgrade';

	/// zh-CN: '上传中'
	String get uploading => '上传中';

	/// zh-CN: '已使用空间'
	String get usedSpace => '已使用空间';

	/// zh-CN: '用户数据'
	String get userData => '用户数据';

	/// zh-CN: '包含APP运行时必要的文件，以及聊天消息、好友关系等所有记录数据。'
	String get userDataTips => '包含APP运行时必要的文件，以及聊天消息、好友关系等所有记录数据。';

	/// zh-CN: '用户被禁用或已删除'
	String get userDisabledOrDeleted => '用户被禁用或已删除';

	/// zh-CN: '用户不存在'
	String get userNotExist => '用户不存在';

	/// zh-CN: 'userOnlineStatusWidget'
	String get userOnlineStatusWidget => 'userOnlineStatusWidget';

	/// zh-CN: 'userTagRelationView'
	String get userTagRelationView => 'userTagRelationView';

	/// zh-CN: 'userTagSaveView'
	String get userTagSaveView => 'userTagSaveView';

	/// zh-CN: '对方发来的验证消息为：{param}'
	String get verificationMessageSentByPeerIs => '对方发来的验证消息为：{param}';

	/// zh-CN: '版本'
	String get version => '版本';

	/// zh-CN: '视频'
	String get video => '视频';

	/// zh-CN: '视频通话'
	String get videoCall => '视频通话';

	/// zh-CN: '[视频]'
	String get videoMessage => '[视频]';

	/// zh-CN: '查看全部群成员'
	String get viewAllGroupMember => '查看全部群成员';

	/// zh-CN: '浏览附件'
	String get viewAttachments => '浏览附件';

	/// zh-CN: '语音'
	String get voice => '语音';

	/// zh-CN: '语音通话'
	String get voiceCall => '语音通话';

	/// zh-CN: '语音输入'
	String get voiceInput => '语音输入';

	/// zh-CN: '语音输入功能暂无实现'
	String get voiceInputNotImplemented => '语音输入功能暂无实现';

	/// zh-CN: '语音消息'
	String get voiceMessage => '语音消息';

	/// zh-CN: '等待下载'
	String get waitingDownload => '等待下载';

	/// zh-CN: '等待对方接受邀请...'
	String get waitingPeerAccept => '等待对方接受邀请...';

	/// zh-CN: '警告:'
	String get warning => '警告:';

	/// zh-CN: 'webView'
	String get webView => 'webView';

	/// zh-CN: '网页加载中...'
	String get webpageLoading => '网页加载中...';

	/// zh-CN: '你的反馈是什么?'
	String get whatYourFeedback => '你的反馈是什么?';

	/// zh-CN: '昨天'
	String get yesterday => '昨天';

	/// zh-CN: '你'
	String get you => '你';

	/// zh-CN: '你撤回了一条消息'
	String get youWithdrewAMessage => '你撤回了一条消息';

	/// zh-CN: '你的联系方式'
	String get yourContactInformation => '你的联系方式';

	/// zh-CN: '这让你感觉如何?'
	String get yourFeel => '这让你感觉如何?';

	/// zh-CN: '简体中文'
	String get zhCn => '简体中文';

	/// zh-CN: '繁体中文'
	String get zhHant => '繁体中文';

	/// zh-CN: '确认移出'
	String get confirmRemove => '确认移出';

	/// zh-CN: '确认将此用户移出黑名单？'
	String get confirmRemoveFromDenylist => '确认将此用户移出黑名单？';

	/// zh-CN: '移出'
	String get buttonRemove => '移出';

	/// zh-CN: '已移出黑名单'
	String get removedFromDenylist => '已移出黑名单';

	/// zh-CN: '修改邮箱'
	String get changeEmail => '修改邮箱';

	/// zh-CN: '绑定邮箱'
	String get bindEmail => '绑定邮箱';

	/// zh-CN: '当前邮箱'
	String get currentEmail => '当前邮箱';

	/// zh-CN: '已绑定'
	String get bound => '已绑定';

	/// zh-CN: '新邮箱地址'
	String get newEmailAddress => '新邮箱地址';

	/// zh-CN: '邮箱地址'
	String get emailAddress => '邮箱地址';

	/// zh-CN: '请输入邮箱地址'
	String get enterEmailAddress => '请输入邮箱地址';

	/// zh-CN: '格式检查'
	String get formatCheck => '格式检查';

	/// zh-CN: '正确'
	String get correct => '正确';

	/// zh-CN: '待输入'
	String get pendingInput => '待输入';

	/// zh-CN: '获取验证码'
	String get getVerificationCode => '获取验证码';

	/// zh-CN: '长度检查'
	String get lengthCheck => '长度检查';

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

	/// zh-CN: '新邮箱与当前绑定一致'
	String get newEmailSameAsCurrent => '新邮箱与当前绑定一致';

	/// zh-CN: '新手机号与当前绑定一致'
	String get newMobileSameAsCurrent => '新手机号与当前绑定一致';

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

	/// zh-CN: '处理中...'
	String get processing => '处理中...';

	/// zh-CN: '错误报告'
	String get bugReport => '错误报告';

	/// zh-CN: '功能请求'
	String get featureRequest => '功能请求';

	/// zh-CN: '验证码'
	String get verificationCode => '验证码';

	/// zh-CN: '反馈内容'
	String get feedbackContent => '反馈内容';

	/// zh-CN: '官方回复'
	String get officialReply => '官方回复';

	/// zh-CN: '设置密码'
	String get setPassword => '设置密码';

	/// zh-CN: '设置登录密码'
	String get setLoginPassword => '设置登录密码';

	/// zh-CN: '提升账号安全性'
	String get enhanceAccountSecurity => '提升账号安全性';

	/// zh-CN: '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。'
	String get setPasswordSecurityTips => '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。';

	/// zh-CN: '密码长度为4-32的任意字符'
	String get passwordLengthRequirement => '密码长度为4-32的任意字符';

	/// zh-CN: '请输入密码'
	String get pleaseEnterPassword => '请输入密码';

	/// zh-CN: '已隐藏您的位置'
	String get locationHidden => '已隐藏您的位置';

	/// zh-CN: '已显示您的位置'
	String get locationVisible => '已显示您的位置';

	/// zh-CN: '暂无附近的人'
	String get noNearbyPeople => '暂无附近的人';

	/// zh-CN: '点击上方的搜索按钮查找附近的人'
	String get clickSearchButtonToFind => '点击上方的搜索按钮查找附近的人';

	/// zh-CN: '删除中...'
	String get deleting => '删除中...';

	/// zh-CN: '操作成功'
	String get operationSuccess => '操作成功';

	/// zh-CN: '操作失败'
	String get operationFailed => '操作失败';

	/// zh-CN: '功能开发中...'
	String get featureInDevelopment => '功能开发中...';

	/// zh-CN: '已加入黑名单'
	String get addedToDenylist => '已加入黑名单';

	/// zh-CN: '更换手机号'
	String get changeMobile => '更换手机号';

	/// zh-CN: '当前手机号'
	String get currentMobile => '当前手机号';

	/// zh-CN: '新手机号'
	String get newMobile => '新手机号';

	/// zh-CN: '请输入手机号'
	String get enterMobileHint => '请输入手机号';

	/// zh-CN: '重新发送 ({count}秒)'
	String get resendCodeWithCount => '重新发送 ({count}秒)';

	/// zh-CN: '已发送至 {param}'
	String get codeSentToMobileParam => '已发送至 {param}';

	/// zh-CN: '绑定成功'
	String get bindSuccess => '绑定成功';

	/// zh-CN: '手机号已更新为 {param}'
	String get mobileUpdatedToParam => '手机号已更新为 {param}';
}

/// The flat map containing all translations for locale <zh-CN>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'about' => '关于',
			'aboutApp' => '关于应用',
			'accept' => '接受',
			'acceptFriendRequest' => '通过朋友验证',
			'account' => '账号',
			'accountSecurity' => '账号安全',
			'addFriend' => '添加朋友',
			'addPhoneContact' => '添加手机联系人',
			'addTag' => '添加标签',
			'addToContacts' => '添加到通讯录',
			'addToDenylist' => '加入黑名单',
			'added' => '已添加',
			'addedToDenylistTips' => '已添加至黑名单，你将不再收到对方的消息',
			'agreeContinue' => '同意并继续',
			'album' => '照片',
			'all' => '全部',
			'allSenders' => '所有发送者',
			'allTags' => '全部标签',
			'allTime' => '所有时间',
			'allTypes' => '所有类型',
			'allowSearchMe' => '允许搜索我',
			'allowedBeSearched' => '最近新注册的并且允许被搜索到的朋友',
			'alreadyEntered' => '你已经输入过了',
			'alreadyMember' => '已是成员',
			'appSize' => '应用大小',
			'appSizeTips' => '包含APP运行的必要文件，包括 APK 文件、优化的编译器输出和解压的原生库。',
			'appSqliteFileSizeExplain' => '当前账号本地生成的sqlite文件大小；可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。',
			'applyAddFriend' => '申请添加朋友',
			'applyFriend' => 'applyFriend',
			'applyFriendLogic' => 'applyFriendLogic',
			'applyParam' => '申请{param}',
			'arSa' => '阿拉伯语（沙特阿拉伯）',
			'attachmentProvider' => 'attachmentProvider',
			'audio' => '音频',
			'audioMessage' => '语音消息',
			'avatar' => '头像',
			'awaitingReply' => '待回复',
			'awaitingVerification' => '等待验证',
			'barcodeFound' => '找到条形码！',
			'blocked' => '已拉黑',
			'botQianFan' => '千帆机器人',
			'businessCard' => '名片',
			'busyTryAgainLater' => '对方正忙，请稍后重试',
			'buttonAccomplish' => '完成',
			'buttonAdd' => '添加',
			'buttonBack' => '返回',
			'buttonBind' => '绑定',
			'accountSecurityEnhance' => '提升账户安全',
			'bindMobileAndEmailTips' => '绑定手机号和邮箱，让您的账户更安全',
			'bindMobile' => '绑定手机号',
			'bindMobileFor' => '用于登录、找回密码和接收重要通知',
			'linkEmail' => '关联邮箱',
			'linkEmailFor' => '用于登录、身份验证和接收账单',
			'bindNow' => '立即绑定',
			'later' => '以后再说',
			'buttonCancel' => '取消',
			'buttonChangePassword' => 'buttonChangePassword',
			'buttonClose' => '关闭',
			'buttonConfirm' => '确认',
			'buttonContinue' => '继续',
			'buttonCopy' => '复制',
			'buttonDelete' => '删除',
			'buttonDeleteAccount' => 'buttonDeleteAccount',
			'buttonInviteCode' => '邀请码',
			'buttonLogin' => 'buttonLogin',
			'buttonLogout' => '注销',
			'buttonNextStep' => 'buttonNextStep',
			'buttonOk' => '确定',
			'buttonRegister' => 'buttonRegister',
			'buttonResetPassword' => 'buttonResetPassword',
			'buttonRetry' => '重试',
			'buttonSave' => '保存',
			'buttonSelectFromAlbum' => '从相册选择',
			'buttonSend' => '发送',
			'buttonSetEmpty' => '置空',
			'buttonSubmit' => '提交',
			'buttonTakingPictures' => '拍照',
			'cache' => '缓存',
			'cacheTips' => '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。',
			'callDuration' => '通话时长',
			'calling' => '正在通话',
			'camera' => '拍摄',
			'canNotAddYourselfFriend' => '你不能添加自己为好友',
			'cancel' => '取消',
			'cancelLogoutBody' => '此账号处于注销反悔期，若登录成功则视作终止注销流程。如需继续注销，请在注销申请提交后的15天内不要登录IMBoy。',
			'cancelLogoutTitle' => '是否终止注销流程？',
			'cancelled' => '已取消',
			'changeGroupChatName' => '修改群聊名称后，将在群内通知其他成员。',
			'changeNameView' => 'changeNameView',
			'changeParam' => '修改{param}',
			'chatHistory' => '聊天记录',
			'chatHoldDownTalk' => '按住说话',
			'chatInput' => 'chatInput',
			'chatMessage' => '聊天消息',
			'chatMomentSportDataEtc' => '聊天、朋友圈、运动数据等',
			'chatSettingBackground' => '聊天背景',
			'chatSettingBackgroundCustom' => '已设置自定义背景',
			'chatSettingBackgroundDefault' => '默认背景',
			'chatSettingBackgroundSelectorTip' => '背景选择功能开发中',
			'chatSettingBackgroundSuccess' => '背景设置成功',
			'chatSettingClearHistory' => '清空聊天记录',
			'chatSettingClearHistoryConfirm' => '确定要清空所有聊天记录吗？此操作不可恢复。',
			'chatSettingClearHistoryDesc' => '删除所有消息，此操作不可恢复',
			'chatSettingClearedSuccess' => '清空成功',
			'chatSettingMute' => '消息免打扰',
			'chatSettingMuteDesc' => '关闭此聊天的消息通知',
			'chatSettingMuted' => '已开启免打扰',
			'chatSettingPin' => '置顶聊天',
			'chatSettingPinDesc' => '将此聊天置顶到列表顶部',
			'chatSettingPinnedSuccess' => '置顶成功',
			'chatSettingUnmuted' => '已关闭免打扰',
			'chatSettingUnpinnedSuccess' => '取消置顶',
			'chatSettings' => '聊天设置',
			'checkForUpdates' => '检查更新',
			'chooseFromAlbum' => '从相册选择',
			'clean' => '清理',
			'clearAll' => '清除全部',
			'clearChatRecord' => '清空聊天记录',
			'codeSentToParam' => '验证码已发送到{param}',
			'codeSentToType' => '验证码已发送到{param}',
			'codeSentToEmail' => '验证码已发送到邮箱',
			'codeSentToMobile' => '验证码已发送到手机',
			'collected' => '已收藏',
			'complaint' => '投诉',
			'completed' => '已完结',
			'confirmCode' => '确认码',
			'confirmCodeError' => '确认码为空',
			'confirmCodeSuccess' => '账户已确认。',
			'confirmDeleteChatRecord' => '确定删除聊天记录吗？',
			'confirmNewFriend' => 'confirmNewFriend',
			'confirmNewFriendLogic' => 'confirmNewFriendLogic',
			'confirmRecoverSuccess' => '密码修改成功。',
			'contactSetting' => 'contactSetting',
			'contactSettingTag' => 'contactSettingTag',
			'contactTagListLogic' => 'contactTagListLogic',
			'contactTags' => '联系人标签',
			'continueDownloading' => '继续下载',
			'copied' => '已复制',
			'copy' => '复制',
			'coupon' => '卡券',
			'createGroupF2f' => '面对面建群',
			'createGroupF2fConfirmTips' => '这些朋友也将进入群聊',
			'createGroupF2fTips' => '和身边的朋友输入同样的四个数字，进入同一个群聊',
			'currentDevice' => '当前设备',
			'darkModel' => '深色模式',
			'deDd' => '德语（德国）',
			'delete' => '删除',
			'deleteCollectConfirmDesc' => '删除后无法恢复，确定要删除这条收藏吗？',
			'deleteContact' => '删除联系人',
			'deleteForEveryone' => '删除所有人的消息',
			'deleteForMe' => '删除我的消息',
			'deleteTagTips' => '删除标签后，标签中的联系人不会被删除',
			'deleteThisDevice' => '删除该设备',
			'deleteThisDeviceTips' => '删除后，下次在该设备登录时需要进行安全验证。',
			'denylist' => '黑名单',
			'denylistEmpty' => '黑名单为空',
			'denylistEmptyDesc' => '你还没有拉黑任何用户\n被拉黑的用户将无法给你发送消息',
			'denylistNoteDesc' => '被拉黑的用户无法给你发送消息，也无法查看你的动态。点击用户可以查看详情。',
			'denylistNoteTitle' => '黑名单说明',
			'details' => '详情',
			'deviceAvailableSpace' => '设备可用空间',
			'deviceDetails' => '设备详情',
			'deviceList' => '设备列表',
			'deviceName' => '设备名称',
			'deviceType' => '设备类型',
			'deviceUsedSpace' => '设备已使用空间',
			'disable' => '禁用',
			'displayProfile' => '显示你的资料',
			'downloaded' => '已下载',
			'earlier' => '更早',
			'edit' => '编辑',
			'editTag' => '编辑标签',
			'email' => '邮箱',
			'enGb' => '英国英语',
			'enUs' => '美国英语',
			'enable' => '启用',
			'enterSameGroup' => '与身边的朋友进入同一个群聊',
			'enterTheGroup' => '进入该群',
			'errorAccessDenied' => '对 {param} 的访问被拒绝',
			'errorCliVersionNotFound' => '没有找到已安装版本。',
			'errorEmptyDirectory' => '{param} 是空的',
			'errorFailedConnectServer' => '无法连接服务器',
			'errorFailedToConnect' => '连接到 {param} 失败',
			'errorFileNotFound' => '在 {param} 中没有找到文件',
			'errorFolderNotFound' => '文件夹 {param} 未找到',
			'errorHttpNotSupported' => '不支持HTTP协议请求',
			'errorInternalServer' => '服务器内部错误',
			'errorInvalid' => '{param} 是无效的',
			'errorInvalidDart' => '{param} 不是有效的dart文件',
			'errorInvalidFileOrDirectory' => '{param} 不是有效的文件或目录',
			'errorInvalidJson' => '{param} 不是个有效的json文件',
			'errorInvalidRequest' => '无效的请求',
			'errorLengthBetween' => '{param}长度为{min}-{max}的任意字符',
			'errorManyRequest' => '请求过多',
			'errorNoPackageToRemove' => '请输入你想移除的 package 名称',
			'errorNoValidFileOrUrl' => '{param} 不是有效的文件或URL',
			'errorNonexistentDirectory' => '{param} 不存在',
			'errorPackageNotFound' => '依赖: {param} 在 pub.dev 中没有找到',
			'errorPassword' => '密码错误',
			'errorRequestForbidden' => '请求方法被禁止',
			'errorRequestSyntax' => '请求语法错误',
			'errorRequired' => '{param} 是必须的',
			'errorRequiredPath' => '需要传入文件或路径',
			'errorRetypePassword' => '两次输入密码不一致',
			'errorSame' => '{param1} 和 {param2} 是同样的',
			'errorServerDown' => '服务器挂了',
			'errorServerRefused' => '服务器拒绝执行',
			'errorSpecialCharactersInKey' => 'key中包含不允许的特殊字符. \n key: {param}',
			'errorUnexpected' => '发生意外错误',
			'errorUnnecessaryParameter' => '参数 {param} 是多余的',
			'errorUnnecessaryParameterPlural' => '参数 {param} 是多余的',
			'errorUpdateCli' => '升级 get_cli 错误',
			'example' => '例:',
			'existingPassword' => '现有密码',
			'expired' => '已过期',
			'extraItem' => 'extraItem',
			'faceToFaceLogic' => 'faceToFaceLogic',
			'failedGetLatLong' => '无法获取经纬度',
			'failedGetMapTryAgain' => '获取地图失败,请重试',
			'failedRequestPleaseCheckNetwork' => '发起请求失败，请检查网络连接，或稍后重试',
			'favoriteGroupTagsEtc' => '收藏人名、群名、标签等',
			'favorites' => '收藏',
			'feedback' => '反馈建议',
			'feedbackBuilder' => 'feedbackBuilder',
			'feedbackContentRequired' => '反馈内容不能为空',
			'feedbackDetails' => '反馈建议明细',
			'feedbackModel' => 'feedbackModel',
			'feedbackReplyModel' => 'feedbackReplyModel',
			'feedbackSuccessMsg' => '你的反馈问题我们已经收到了，会尽快处理！',
			'female' => '女',
			'file' => '文件',
			'fileMessage' => '[文件]',
			'fileSize' => '文件大小',
			'findNearbyPeople' => '找附近的人',
			'followSystem' => '跟随系统',
			'followSystemTips' => '开启后,将跟随系统打开或关闭深色模式',
			'forceLogoutNotification' => '您已被设备【{param}】强制下线',
			'forgotPassword' => '忘记密码？',
			'forgotPasswordPinCodeView' => 'forgotPasswordPinCodeView',
			'forward' => '转发',
			'forwardReply' => '转发回复',
			'forwardTo' => '转发给',
			'forwardToFriend' => '转发给朋友',
			'frFr' => '法语（法国）',
			'friendPermissions' => '朋友权限',
			'friendsPermissionsView' => 'friendsPermissionsView',
			'from' => '来自',
			'gender' => '性别',
			'genderConflictError' => '性别设置冲突，请重试',
			'genderNetworkError' => '网络异常，请检查网络连接',
			'genderSaving' => '保存中...',
			'genderUpdateFailed' => '性别设置失败，请重试',
			'genderUpdateSuccess' => '性别设置成功',
			'goClean' => '前往清理',
			'good' => '很棒',
			'great' => '非常棒',
			'groupAddLocal' => '保存到通讯录',
			'groupAlias' => '我在本群的昵称',
			'groupAnnouncement' => '群公告',
			'groupChat' => '群聊',
			'groupDissolve' => '解散群聊',
			'groupJoin' => '加入群聊',
			'groupLeave' => '退出群聊',
			'groupManagement' => '群管理',
			'groupMembers' => '群成员',
			'groupName' => '群聊名称',
			'groupQrcode' => '群二维码',
			'groupQrcodeTips' => '该二维码{days}天内（{date}前）有效，重新进入将更新',
			'groupRemarkView' => 'groupRemarkView',
			'groupRemarkVisibility' => '群聊的备注仅自己可见',
			'groupSearchTips' => '群名称和群简介',
			'hangup' => '挂断',
			'haveSet' => '已设置',
			'helpDocument' => '帮助文档',
			'hintEditGroupAnnouncement' => '编辑群公告',
			'hintLoginAccount' => '账号/邮箱',
			'httpParse' => 'httpParse',
			'httpResponse' => 'httpResponse',
			'iAm' => '我是',
			'image' => '图片',
			'imageMessage' => '[图片]',
			'incomingCall' => '{param}呼入',
			'info' => '信息',
			'infoLoggedInOnAnotherDevice' => '你的账号已于{param}在其他设备登录',
			'initiateChat' => '发起群聊',
			'installNow' => '立即安装',
			'iosAppIdUnknown' => 'AppStore未上架或AppID[{param}]不存在',
			'itIt' => '意大利语（意大利）',
			'jaJp' => '日语（日本）',
			'justChat' => '仅聊天',
			'keepSecret' => '保密',
			'koKr' => '韩语（韩国）',
			'languageSetting' => '语言设置',
			'languageState' => 'languageState',
			'lastActiveTime' => '最近活跃时间',
			'lastActiveTips' => '当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时间。',
			'lastSeenDaysAgo' => '{param}天前',
			'lastSeenHide' => '隐藏在线状态',
			'lastSeenHoursAgo' => '{param}小时前',
			'lastSeenJustNow' => '刚刚上线',
			'lastSeenLongTimeAgo' => '很久以前上线',
			'lastSeenMinutesAgo' => '{param}分钟前',
			'lastSeenMonthsAgo' => '{param}个月前',
			'lastSeenNever' => '从未上线',
			'lastSeenWeeksAgo' => '{param}周前',
			'lastSeenExactTime' => '上次在线 {param}',
			'leaveYourSuggestions' => '请留下您宝贵的意见和建议',
			'licenseAgreement' => '《软件许可及服务协议》',
			'liveBroadcast' => '直播',
			'liveRoomListView' => 'liveRoomListView',
			'publisherPage' => '推流页面',
			'subscriber' => '订阅者',
			'loadError' => '加载失败，请重试',
			'loadMore' => '加载更多',
			'loading' => '加载中',
			'location' => '位置',
			'locationMessage' => '位置消息',
			'logOut' => '退出登录',
			'login' => '登录',
			'loginDeviceManagement' => '登录设备管理',
			'loginDeviceManagementTips' => '你的帐号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。',
			'loginEmail' => '登录邮箱',
			'logoutAccount' => '注销账号',
			'logoutNotice' => '《注销须知》',
			'loudspeaker' => '扩音器',
			'makeYourselfInvisible' => '让自己不可见',
			'makeYourselfVisible' => '让自己可见',
			'male' => '男',
			'manage' => '管理',
			'manually' => '手动选择',
			'markImportant' => '重要',
			'markImportantDesc' => '标记为重要消息',
			'markStar' => '收藏',
			'markStarDesc' => '收藏此消息',
			'markTodo' => '待办',
			'markTodoDesc' => '标记为待办事项',
			'message' => '消息',
			'messageCall' => '发消息',
			'messageContent' => '消息内容',
			'messageHandlingMixin' => 'messageHandlingMixin',
			'messageLocationBuilder' => 'messageLocationBuilder',
			'messageMarkTitle' => '消息标记',
			'messageMute' => '消息免打扰',
			'messageNotification' => '消息通知',
			'messageRevoked' => '消息已撤回',
			'messageRevokedBuilder' => 'messageRevokedBuilder',
			'messageType' => '消息类型',
			'messageVisitCardBuilder' => 'messageVisitCardBuilder',
			'messageWasWithdrawn' => '撤回了一条消息',
			'messageWebrtcBuilder' => 'messageWebrtcBuilder',
			'microphone' => '麦克风',
			'microphonePermissionNotObtained' => '未获取到麦克风权限',
			'mobile' => '手机',
			'mobileQuickLogin' => '一键登录',
			'moment' => '朋友圈',
			'momentStatus' => '朋友圈和状态',
			'moreInfo' => '更多信息',
			'multiSelect' => '多选',
			'multiSelectMode' => '多选模式',
			'mutualGroupsWithHer' => '我和他的共同群聊',
			'myAccount' => '我的账号',
			'myAddress' => '我的地址',
			'myFavorites' => '我的收藏',
			'myLive' => '我的直播',
			'myQrcode' => '我的二维码',
			'name' => '名称',
			'nearbyPeopleExplain' => '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。\n\n你的电话号码将会被隐藏。',
			'nearbyPeopleTips' => '和附近的人交换联系方式，结交新朋友',
			'needContinueWorkHard' => '需要继续加油',
			'needSubmitEffect' => '需要确认提交，该操作才生效',
			'networkException' => '网络连接异常',
			'networkExceptionPlaseNeedNetworkToViewData' => '网络状态异常，需要打开网络才能够查看数据',
			'networkFailureGuidance' => 'networkFailureGuidance',
			'networkFailureTips' => 'networkFailureTips',
			'networkFailureTryAgain' => '网络故障，请重试！',
			'networkNotAvailable' => '当前网络不可用。',
			'newFriend' => '新的朋友',
			'newPassword' => '新的密码',
			'newVersionDetected' => '检测到新版本',
			'newlyRegisteredPeople' => '新注册的人',
			'nextStep' => '下一步',
			'nickname' => '昵称',
			'nicknameChangeVisibility' => '昵称修改后，只会在此群内显示，群内成员都可以看见。',
			'nicknameCharsRemaining' => '还可输入{param}个字符',
			'nicknameConflictError' => '昵称已被使用，请选择其他昵称',
			'nicknameEmojiOnlyError' => '昵称不能仅包含表情符号',
			'nicknameEmptyError' => '昵称不能为空',
			'nicknameHint' => '请输入昵称',
			'nicknameLengthError' => '昵称长度应在2-24个字符之间',
			'nicknameNetworkError' => '网络异常，请检查网络连接',
			'nicknameSaving' => '保存中...',
			'nicknameSensitiveWordError' => '昵称包含敏感词，请重新输入',
			'nicknameServerError' => '服务器错误，请稍后重试',
			'nicknameUpdateFailed' => '昵称修改失败，请重试',
			'nicknameUpdateSuccess' => '昵称修改成功',
			'nicknameWhitespaceError' => '昵称不能仅包含空白字符',
			'noAvatar' => '无头像',
			'noBarcodeFound' => '未找到条形码！',
			'noContacts' => '无联系人',
			'noConversationMessages' => '无会话消息',
			'noData' => '暂无数据',
			'noMembersInCurrentTag' => '当前标签无成员',
			'noMoreData' => '没有更多数据了',
			'noNewFriends' => '没有新的好友',
			'noPermission' => '没有权限',
			'noReply' => '暂无回复',
			'noSiginQ' => '还没有账号？',
			'noUpdateDescription' => '无更新说明',
			'normalModel' => '普通模式',
			'notAuthorizedLatLong' => '您还没有授权获取经纬度',
			'notBad' => '还不错',
			'notBound' => '未绑定',
			'notFilled' => '未填写',
			'notInstallAnyMapApp' => '您没有安装任何地图APP哦',
			'notLetHimSee' => '不让他（她）看',
			'notReceiveCoeQ' => '没有收到验证码？',
			'notSeeHim' => '不看他（她）',
			'notSet' => '未设置',
			'notShow' => '不显示',
			'notTurnedLocationService' => '您还没有打开位置信息服务',
			'nowNewVersion' => '未检测到新版本',
			'numUnit' => '{param}个',
			'off' => '已关闭',
			'offline' => '离线',
			'offlineNotification' => '下线通知',
			'on' => '已开启',
			'online' => '在线',
			'openInBrowser' => '在浏览器中打开',
			'operationFailedAgainLater' => '操作失败，请稍后重试',
			'optionsNo' => '不',
			'optionsRename' => '我想重命名',
			'optionsYes' => '是的!',
			'or' => '或者',
			'otherParty' => '对方',
			'p2pCallScreenLogic' => 'p2pCallScreenLogic',
			'p2pCallScreenView' => 'p2pCallScreenView',
			'packageSize' => '包大小',
			'paramAlreadyExist' => '{param}已存在',
			'paramFormatError' => '{param}格式有误',
			'paramLogin' => '{param}登录',
			'password' => '密码',
			'pauseDownloading' => '暂停下载',
			'peerHasHungUp' => '对方已挂断',
			'peerNoResponse' => '对方无应答...',
			'peopleInfoMoreLogic' => 'peopleInfoMoreLogic',
			'peopleInfoSameGroupView' => 'peopleInfoSameGroupView',
			'peopleNearby' => '附近的人',
			'peopleNearbyLogic' => 'peopleNearbyLogic',
			'perMinuteOnce' => '每分钟只能请求一次',
			'permission' => 'permission',
			'permissionAcquisitionFailed' => '权限获取失败',
			'personalCard' => '个人名片',
			'personalInfoDesc' => '个人信息描述',
			'personalInfoTip' => '个人信息提示',
			'personalInformation' => '个人信息',
			'pin' => '置顶',
			'pinChat' => '置顶聊天',
			'pinCodeFillTips' => '请把方格填满',
			'pinned' => '已置顶',
			'play' => '播放',
			'pleaseCheckNetwork' => '请检查你的网络设置。',
			'pleaseInputParam' => '请输入{param}',
			'pleaseSelect' => '请选择',
			'pleaseSelectMembersForAdd' => '请选择要添加的成员',
			'privateReply' => '私聊回复',
			'profileSettings' => '资料设置',
			'qrCodeBusinessCard' => '二维码名片',
			'quickFilters' => '快速筛选',
			'quote' => '引用',
			'quoteReply' => '引用回复',
			'rating' => '评级',
			'reEdit' => '重新编辑',
			'readAgreeParam' => '已经阅读并同意{param}',
			'recentChats' => '最近聊天',
			'recentForwards' => '最近转发',
			'recentlyRegisteredUser' => 'recentlyRegisteredUser',
			'recentlyUsed' => '最近使用',
			'recommendToFriend' => '把他推荐给朋友',
			'recoverCodePasswordDesc' => '我们会将密码恢复码发送到您的邮箱。',
			'recoverPassword' => '找回密码',
			'recoverPasswordDesc' => '',
			'recoverPasswordIntro' => '不要感觉不好，这是常有的事。',
			'recoverPasswordSuccess' => '验证码发送成功',
			'region' => '地区',
			'regionCancel' => '取消',
			'regionConfirm' => '确定',
			'regionNoResult' => '暂无结果',
			'regionSearchHint' => '按地区名称搜索',
			'regionSearchTips' => '按地区名称或区域编码搜索',
			'regionSelectTitle' => '选择地区',
			'releaseEnd' => '松开结束',
			'releaseFingerCancelSending' => '松开手指,取消发送',
			'remainingChars' => '还可输入 {param} 个字符',
			'remark' => '备注',
			'remarksTags' => '备注和标签',
			'remindMeLater' => '下次再说',
			'removeContactFromTag' => '从标签中移除联系人',
			'removeMember' => '移出成员',
			'replied' => '已回复',
			'repliedAt' => '回复于',
			'reply' => '回复',
			'replyTo' => '回复',
			'resendCode' => '重发验证码',
			'resendCodeSuccess' => '已发送新邮件。',
			'resetFilters' => '重置筛选',
			'retypePassword' => '重新输入密码',
			'revoke' => '撤回',
			'ringing' => '已响铃...',
			'ruRu' => '俄罗斯俄语',
			'saveQrCode' => '保存二维码',
			'saveSuccess' => '保存成功',
			'scan' => '扫一扫',
			_ => null,
		} ?? switch (path) {
			'scanQrCode' => '扫描二维码',
			'scanQrCodeBusinessCard' => '扫描二维码名片',
			'scanQrcodeAddFriend' => '扫一扫上面的二维码图案，加我为朋友',
			'scanResult' => '扫描结果',
			'scannerResult' => 'scannerResult',
			'search' => '搜索',
			'searchChatContent' => '查找聊天内容',
			'searchChatRecord' => '查找聊天记录',
			'searchError' => '搜索错误',
			'searchFilterAll' => '全部筛选',
			'searchFilterImage' => '图片筛选',
			'searchFilterText' => '文本筛选',
			'searchFilterToday' => '今日筛选',
			'searchFilters' => '搜索筛选',
			'applyFilters' => '应用筛选',
			'searchFriendsTips' => '通过好友昵称、备注搜索好友',
			'searchHint' => '输入关键词搜索消息',
			'searchHistory' => '搜索历史',
			'searchLocation' => '搜索地点',
			'searchMessagesHint' => '搜索消息提示',
			'searchNoFound' => '搜索结果为空 :(',
			'searchNoResults' => '无搜索结果',
			'noSearchHistory' => '暂无搜索历史',
			'searchRegion' => '搜索地区',
			'searchResults' => '搜索结果',
			'searchResultsCount' => '第 {current} 个，共 {total} 个结果',
			'searchSuggestions' => '搜索建议',
			'securityCenter' => '安全中心',
			'selectAGroup' => '选择一个群',
			'selectAll' => '全选',
			'selectContacts' => '选择联系人',
			'selectedCount' => '已选 ({count})',
			'selectFriend' => 'selectFriend',
			'selectFriends' => '选择朋友',
			'selectGroup' => '选择群聊',
			'selectOrEnterTag' => '选择或输入标签',
			'selectRegionView' => 'selectRegionView',
			'selected' => '已选',
			'selectedItems' => '{param} 个选定项目',
			'selectedRegion' => '已选地区',
			'sendFriendRequest' => '发送添加朋友申请',
			'sendMsgNotFriendTips' => '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。',
			'sendMsgRejected' => '消息已发出，但被对方拒收了。',
			'sendSeparatelyTo' => '分别发送给',
			'sendTo' => '发送给',
			'sender' => '发送者',
			'sending' => '正在发送...',
			'sent' => '已发送',
			'sentByMe' => '我发送的',
			'sentByOthers' => '他人发送的',
			'setChatBackground' => '设置当前聊天背景',
			'setNickname' => '设置昵称',
			'setParam' => '设置{param}',
			'setting' => '设置',
			'share' => '分享',
			'siginQ' => '已经有账号了？',
			'signInWith' => '用{param}登录',
			'signature' => '个性签名',
			'signatureInputHint' => '签名输入提示',
			'signaturePlaceholder' => '签名占位符',
			'signatureTips' => '签名提示',
			'signup' => '注册',
			'signupFormDesc' => '请填写此表格以完成注册',
			'signupIntro' => '确认码已发送到您的邮箱，\n请输入确认码确认您的帐户。',
			'slideUpCancelSending' => '手指上滑,取消发送',
			'socialProfile' => '社交资料',
			'source' => '来源',
			'sourceQrcode' => '通过扫一扫添加',
			'speakingTooShort' => '说话时间太短',
			'speed' => '速度',
			'star' => '收藏',
			'status' => '状态',
			'stillNeeded' => '还需',
			'storagePermissionNotObtained' => '未获取存储权限',
			'storageSpace' => '存储空间',
			'storageSpaceData' => '存储空间和数据',
			'strongReminder' => '强提醒',
			'submittedAt' => '提交于',
			'sureDeleteData' => '确认删除吗？删除后不可恢复。',
			'sureDeleteGroupChatRecord' => '确定删除群的聊天记录吗？',
			'sureOpenTheFile' => '确定要打开文件吗？',
			'sureToDissolveGroup' => '确定要解散本群吗？',
			'sureToLeaveGroup' => '确定要退出本群吗？',
			'switchAccount' => '切换账号',
			'switchEnvironment' => '切换环境',
			'tags' => '标签',
			'tellFriend' => '告诉朋友',
			'termOfServices' => '服务条款',
			'text' => '文本',
			'textMessage' => '文本消息',
			'thisMonth' => '本月',
			'thisWeek' => '本周',
			'timeDaysAgo' => '{param}天前',
			'timeHoursAgo' => '{param}小时前',
			'timeJustNow' => '刚刚',
			'timeMinutesAgo' => '{param}分钟前',
			'timeRange' => '时间范围',
			'timeToday' => '今天',
			'timeWeekdays' => '星期一,星期二,星期三,星期四,星期五,星期六,星期日',
			'timeYesterday' => '昨天',
			'tipConnectDesc' => '无网络',
			'tipDeleteContact' => '将联系人"{param}"删除，同时删除与该联系人的聊天记录',
			'tipDeviceSpace' => '占设备 {param1}‰ 存储空间({param2})',
			'tipDraft' => '草稿',
			'tipEmptyChatPlaceholder' => '这里还没有消息',
			'tipFailed' => '操作失败！',
			'tipGreeting' => '欢迎使用',
			'tipProvidersTitleFirst' => '或用以下账号登录',
			'tipSuccess' => '操作成功！',
			'tipTips' => '小贴士',
			'titleContact' => '联系人',
			'titleMessage' => '消息',
			'titleMine' => '我的',
			'today' => '今天',
			'tooBad' => '太差了',
			'topChat' => '置顶聊天',
			'tryAgainQ' => '想再试一次吗？',
			'type' => '类型',
			'typeMessage' => '输入消息...',
			'unanswered' => '未应答',
			'unknown' => '未知',
			'unknownMessage' => '未知消息',
			'unnamed' => '未命名',
			'unpin' => '取消置顶',
			'unsupportedFileType' => '不支持的文件类型',
			'upToWords' => '最多{param}个字',
			'updateLog' => '更新日志',
			'updateNow' => '立即更新',
			'upgrade' => 'upgrade',
			'uploading' => '上传中',
			'usedSpace' => '已使用空间',
			'userData' => '用户数据',
			'userDataTips' => '包含APP运行时必要的文件，以及聊天消息、好友关系等所有记录数据。',
			'userDisabledOrDeleted' => '用户被禁用或已删除',
			'userNotExist' => '用户不存在',
			'userOnlineStatusWidget' => 'userOnlineStatusWidget',
			'userTagRelationView' => 'userTagRelationView',
			'userTagSaveView' => 'userTagSaveView',
			'verificationMessageSentByPeerIs' => '对方发来的验证消息为：{param}',
			'version' => '版本',
			'video' => '视频',
			'videoCall' => '视频通话',
			'videoMessage' => '[视频]',
			'viewAllGroupMember' => '查看全部群成员',
			'viewAttachments' => '浏览附件',
			'voice' => '语音',
			'voiceCall' => '语音通话',
			'voiceInput' => '语音输入',
			'voiceInputNotImplemented' => '语音输入功能暂无实现',
			'voiceMessage' => '语音消息',
			'waitingDownload' => '等待下载',
			'waitingPeerAccept' => '等待对方接受邀请...',
			'warning' => '警告:',
			'webView' => 'webView',
			'webpageLoading' => '网页加载中...',
			'whatYourFeedback' => '你的反馈是什么?',
			'yesterday' => '昨天',
			'you' => '你',
			'youWithdrewAMessage' => '你撤回了一条消息',
			'yourContactInformation' => '你的联系方式',
			'yourFeel' => '这让你感觉如何?',
			'zhCn' => '简体中文',
			'zhHant' => '繁体中文',
			'confirmRemove' => '确认移出',
			'confirmRemoveFromDenylist' => '确认将此用户移出黑名单？',
			'buttonRemove' => '移出',
			'removedFromDenylist' => '已移出黑名单',
			'changeEmail' => '修改邮箱',
			'bindEmail' => '绑定邮箱',
			'currentEmail' => '当前邮箱',
			'bound' => '已绑定',
			'newEmailAddress' => '新邮箱地址',
			'emailAddress' => '邮箱地址',
			'enterEmailAddress' => '请输入邮箱地址',
			'formatCheck' => '格式检查',
			'correct' => '正确',
			'pendingInput' => '待输入',
			'getVerificationCode' => '获取验证码',
			'lengthCheck' => '长度检查',
			'confirmChange' => '确认更换',
			'verificationCodeSentToEmail' => '验证码将发送至该邮箱，请在有效期内完成验证',
			'verificationCodeSentToMobile' => '验证码将发送至该手机，请在有效期内完成验证',
			'pleaseEnterCorrectEmailAddress' => '请输入正确的邮箱地址',
			'pleaseEnter6DigitVerificationCode' => '请输入 6 位验证码',
			'verificationCodeSent' => '验证码已发送',
			'sendFailed' => '发送失败',
			'noChangeNeeded' => '无需修改',
			'newEmailSameAsCurrent' => '新邮箱与当前绑定一致',
			'newMobileSameAsCurrent' => '新手机号与当前绑定一致',
			'submissionFailed' => '提交失败',
			'checkVerificationCodeOrRetry' => '请检查验证码或稍后重试',
			'forceOffline' => '下线',
			'forceDeviceOffline' => '让该设备下线',
			'forceDeviceOfflineConfirm' => '将向该设备发送下线指令，确认继续？',
			'confirmForceOffline' => '确认下线',
			'forceOfflineCommandSent' => '已发送下线指令',
			'feedbackSlogan' => '您的建议是我们改进的动力',
			'newFeedback' => '新建反馈',
			'feedbackHistory' => '反馈历史',
			'confirmDelete' => '确认删除',
			'processing' => '处理中...',
			'bugReport' => '错误报告',
			'featureRequest' => '功能请求',
			'verificationCode' => '验证码',
			'feedbackContent' => '反馈内容',
			'officialReply' => '官方回复',
			'setPassword' => '设置密码',
			'setLoginPassword' => '设置登录密码',
			'enhanceAccountSecurity' => '提升账号安全性',
			'setPasswordSecurityTips' => '为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设置登录密码。',
			'passwordLengthRequirement' => '密码长度为4-32的任意字符',
			'pleaseEnterPassword' => '请输入密码',
			'locationHidden' => '已隐藏您的位置',
			'locationVisible' => '已显示您的位置',
			'noNearbyPeople' => '暂无附近的人',
			'clickSearchButtonToFind' => '点击上方的搜索按钮查找附近的人',
			'deleting' => '删除中...',
			'operationSuccess' => '操作成功',
			'operationFailed' => '操作失败',
			'featureInDevelopment' => '功能开发中...',
			'addedToDenylist' => '已加入黑名单',
			'changeMobile' => '更换手机号',
			'currentMobile' => '当前手机号',
			'newMobile' => '新手机号',
			'enterMobileHint' => '请输入手机号',
			'resendCodeWithCount' => '重新发送 ({count}秒)',
			'codeSentToMobileParam' => '已发送至 {param}',
			'bindSuccess' => '绑定成功',
			'mobileUpdatedToParam' => '手机号已更新为 {param}',
			_ => null,
		};
	}
}
