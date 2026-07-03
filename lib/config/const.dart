// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart' show kDebugMode;

String qrcodeDataSuffix = "s=app_qrcode";

/// 仅在 debug 构建中开启 Dio 日志记录，避免 release 构建泄露 token/密码到系统日志
const recordLog = kDebugMode;

class Keys {
  static const String wsUrl = "ws_url";
  static const String apiPublicKey = "api_public_key";
  static const String uploadUrl = "upload_url";
  static const String uploadKey = "upload_key";
  static const String uploadScene = "upload_scene";
  // 公开资源（scope=public，如头像/表情）直读基址，由 /api/v1/init 下发
  static const String publicBaseUrl = "public_base_url";
  static const String appFeatures = "app_features";
  static const String appManifest = "app_manifest";
  static const String appManifestEtag = "app_manifest_etag";

  static const String publicKey = "public_key";
  static const String privateKey = "private_key";

  // 客服端Key
  static const String currentLanguageCode = "current_language_code";
  static const String currentLanguage = "current_language";

  static const String currentUid = "current_uid";
  static const String currentUser = "current_user";
  static const String currentLang = 'user_current_lang';

  static const String account = "account";
  static const String password = "password";
  static const String nickname = 'nickname';
  static const String avatar = 'avatar';
  static const String gender = 'gender';

  // 与服务端约定的Key
  static const tokenKey = 'authorization';
  static const refreshTokenKey = 'imboy-refreshtoken';

  static String lastLoginAccount = 'lastLoginAccount';
  static String loginHistory = 'loginHistory';
  static String loginHistoryAccount = 'loginHistoryAccount';
  static String loginHistoryMobile = 'loginHistoryMobile';
  static String loginHistoryEmail = 'loginHistoryEmail';
  static String themeType = 'theme_type';
  static String needSetPwd = 'need_set_password';
  static const String groupMembershipSelfHealPrefix =
      'group_membership_self_heal';
}

class API {
  static const initConfig = '/api/v1/init';
  static const refreshToken = '/api/v1/refreshtoken';
  static const login = '/api/v1/passport/login';
  static const signup = '/api/v1/passport/signup';
  static const getCode = '/api/v1/passport/getcode';
  static const quickLogin = '/api/v1/passport/quick_login';
  static const findPassword = '/api/v1/passport/findpassword';
  static const appVersionCheck = '/api/v1/app_version/check';
  static const appFeatures = '/api/v1/app/features';
  static const appManifest = '/api/v1/app/manifest';
  static const appPolicy = '/api/v1/app/policy';
  static const sqliteUpgradeDdl = '/api/v1/app_ddl/get?type=upgrade';
  static const sqliteDowngradeDdl = '/api/v1/app_ddl/get?type=downgrade';

  static const addFriend = '/api/v1/friend/add';
  static const confirmFriend = '/api/v1/friend/confirm';
  static const deleteFriend = '/api/v1/friend/delete';
  static const friendList = '/api/v1/friend/list';
  static const friendChangeRemark = '/api/v1/friend/change_remark';

  static const conversationList = '/api/v1/conversation/mine';
  static const conversationPin = '/api/v1/conversation/pin';
  static const conversationUnpin = '/api/v1/conversation/unpin';
  static const conversationDelete = '/api/v1/conversation/delete';
  static const conversationRestore = '/api/v1/conversation/restore';
  static const conversationPinned = '/api/v1/conversation/pinned';
  // 拉取离线
  static const msgOffline = '/api/v1/msg/offline';
  // 确认离线消息已处理
  static const msgOfflineAck = '/api/v1/msg/offline_ack';
  // 查询消息历史（conv_seq 游标分页）
  static const msgHistory = '/api/v1/msg/history';

  static const denylistAdd = '/api/v1/friend/denylist/add';
  static const denylistRemove = '/api/v1/friend/denylist/remove';
  static const denylistPage = '/api/v1/friend/denylist/page';

  static const groupFace2face = '/api/v1/group/face2face';
  static const groupFace2faceSave = '/api/v1/group/face2face_save';
  static const groupAdd = '/api/v1/group/add';
  static const groupEdit = '/api/v1/group/edit';
  static const groupDetail = '/api/v1/group/detail';
  static const groupDissolve = '/api/v1/group/dissolve';
  static const groupPage = '/api/v1/group/page';
  static const groupMemberPage = '/api/v1/group_member/page';
  static const groupMemberJoin = '/api/v1/group_member/join';
  static const groupMemberLeave = '/api/v1/group_member/leave';
  static const groupMemberAlias = '/api/v1/group_member/alias';
  static const groupMemberSameGroup = '/api/v1/group_member/same_group';
  static const groupMemberRole = '/api/v1/group_member/role';
  static const groupMemberMute = '/api/v1/group_member/mute';
  static const groupMemberUnmute = '/api/v1/group_member/unmute';
  static const groupTransfer = '/api/v1/group/transfer';
  static const groupRemark = '/api/v1/group/remark';

  static const userShow = '/api/v1/user/show';
  static const turnCredential = '/api/v1/user/credential';
  static const userUpdate = '/api/v1/user/update';
  static const userSetting = '/api/v1/user/setting';
  static const userChangePassword = '/api/v1/user/change_password';
  static const userSetPassword = '/api/v1/user/set_password';
  static const userApplyLogout = '/api/v1/user/apply_logout';
  static const userCancelLogout = '/api/v1/user/cancel_logout';
  static const userSearch = '/api/v1/user/search';

  static const ftsRecentlyUser = '/api/v1/fts/recently_user';
  static const ftsMessage = '/api/v1/fts/msg';

  static const userDevicePage = '/api/v1/user_device/page';
  static const userDeviceChangeName = '/api/v1/user_device/change_name';
  static const userDeviceDelete = '/api/v1/user_device/delete';
  static const userDeviceSessions = '/api/v1/user_device/sessions';
  static const userDeviceCheckLogin = '/api/v1/user_device/check_login';
  static const userDeviceKick = '/api/v1/user_device/kick';
  static const userDeviceKickOthers = '/api/v1/user_device/kick-others';

  static const userCollectPage = '/api/v1/user_collect/page';
  static const userCollectAdd = '/api/v1/user_collect/add';
  static const userCollectRemove = '/api/v1/user_collect/remove';
  static const userCollectChange = '/api/v1/user_collect/change';

  static const userTagPage = '/api/v1/user_tag/page';
  static const userTagAdd = '/api/v1/user_tag/add';
  static const userTagDelete = '/api/v1/user_tag/delete';
  static const userTagChangeName = '/api/v1/user_tag/change_name';

  static const userTagRelationFriendPage =
      '/api/v1/user_tag_relation/friend_page';
  static const userTagRelationCollectPage =
      '/api/v1/user_tag_relation/collect_page';
  static const userTagRelationAdd = '/api/v1/user_tag_relation/add';
  static const userTagRelationSet = '/api/v1/user_tag_relation/set';
  static const userTagRelationRemove = '/api/v1/user_tag_relation/remove';

  static const feedbackPage = '/api/v1/feedback/page';
  static const feedbackAdd = '/api/v1/feedback/add';
  static const feedbackRemove = '/api/v1/feedback/remove';
  static const feedbackChange = '/api/v1/feedback/change';
  static const feedbackPageReply = '/api/v1/feedback/page_reply';

  // 附近的人
  static const peopleNearby = '/api/v1/location/peopleNearby';
  static const makeMyselfVisible = '/api/v1/location/makeMyselfVisible';
  static const makeMyselfUnVisible = '/api/v1/location/makeMyselfUnvisible';

  // 群文件
  static const groupFileCategories = '/api/v1/group/file/categories';
  static const groupFileList = '/api/v1/group/file/list';
  static const groupFileUpload = '/api/v1/group/file/upload';
  static const groupFileSearch = '/api/v1/group/file/search';
  static const groupFileDelete = '/api/v1/group/file/delete';

  // @提及
  static const mentionList = '/api/v1/mention/list';
  static const mentionMarkRead = '/api/v1/mention/mark_read';
  static const mentionSuggest = '/api/v1/mention/suggest';
  static const mentionUnread = '/api/v1/mention/unread';

  // 群标签
  static const groupTagAdd = '/api/v1/group/tag/add';
  static const groupTagList = '/api/v1/group/tag/list';
  static const groupTagRemove = '/api/v1/group/tag/remove';
  static const groupTagSearch = '/api/v1/group/tag/search';
  static const groupTagHot = '/api/v1/group/tag/hot';

  // 群分组
  static const groupCategoryCreate = '/api/v1/group/category/create';
  static const groupCategoryDelete = '/api/v1/group/category/delete';
  static const groupCategoryList = '/api/v1/group/category/list';
  static const groupCategoryRename = '/api/v1/group/category/rename';
  static const groupCategorySort = '/api/v1/group/category/sort';
  static const groupCategoryMoveGroup = '/api/v1/group/category/move_group';

  // 群日程
  static const groupScheduleCreate = '/api/v1/group_schedule/create';
  static const groupScheduleUpdate = '/api/v1/group_schedule/update';
  static const groupScheduleCancel = '/api/v1/group_schedule/cancel';
  static const groupScheduleConfirm = '/api/v1/group_schedule/confirm';
  static const groupScheduleDetail = '/api/v1/group_schedule/detail';
  static const groupScheduleList = '/api/v1/group_schedule/list';
  static const groupScheduleMyList = '/api/v1/group_schedule/my_list';

  // 群相册
  static const groupAlbumCreate = '/api/v1/group_album/create';
  static const groupAlbumDelete = '/api/v1/group_album/delete';
  static const groupAlbumList = '/api/v1/group_album/list';
  static const groupAlbumRename = '/api/v1/group_album/rename';
  static const groupAlbumCoverUpdate = '/api/v1/group_album/cover/update';
  static const groupAlbumPhotoUpload = '/api/v1/group_album/photo/upload';
  static const groupAlbumPhotoList = '/api/v1/group_album/photo/list';
  static const groupAlbumPhotoDetail = '/api/v1/group_album/photo/detail';
  static const groupAlbumPhotoDelete = '/api/v1/group_album/photo/delete';

  // 群任务
  static const groupTaskCreate = '/api/v1/group/task/create';
  static const groupTaskUpdate = '/api/v1/group/task/update';
  static const groupTaskDetail = '/api/v1/group/task/detail';
  static const groupTaskList = '/api/v1/group/task/list';
  static const groupTaskMy = '/api/v1/group/task/my';
  static const groupTaskPending = '/api/v1/group/task/pending';
  static const groupTaskAssign = '/api/v1/group/task/assign';
  static const groupTaskSubmit = '/api/v1/group/task/submit';
  static const groupTaskReview = '/api/v1/group/task/review';

  // 群投票
  static const groupVoteCreate = '/api/v1/group/vote/create';
  static const groupVoteUpdate = '/api/v1/group/vote/update';
  static const groupVoteCancel = '/api/v1/group/vote/cancel';
  static const groupVoteClose = '/api/v1/group/vote/close';
  static const groupVoteCast = '/api/v1/group/vote/cast';
  static const groupVoteDetail = '/api/v1/group/vote/detail';
  static const groupVoteList = '/api/v1/group/vote/list';
  static const groupVoteMyVote = '/api/v1/group/vote/my_vote';

  // E2EE
  static const e2eeUserKeys = '/api/v1/e2ee/user_keys';
  static const e2eeGroupMemberKeys = '/api/v1/e2ee/group_member_keys';
  static const e2eeReportDeviceKey = '/api/v1/e2ee/report_device_key';
  static const e2eeKeyStatus = '/api/v1/e2ee/key/status';
  static const e2eeNotificationsPull = '/api/v1/e2ee/notifications/pull';

  // 合规密钥（三层加密架构）
  static const e2eeComplianceKey = '/api/v1/e2ee/compliance_key';

  // E2EE+ 社交恢复
  static const e2eeSocialContacts = '/api/v1/e2ee/social/contacts';
  static const e2eeSocialContactsAdd = '/api/v1/e2ee/social/contacts/add';
  static const e2eeSocialContactsRemove = '/api/v1/e2ee/social/contacts/remove';
  static const e2eeSocialCreateShards = '/api/v1/e2ee/social/create_shards';
  static const e2eeSocialShards = '/api/v1/e2ee/social/shards';
  static const e2eeSocialProxyShards = '/api/v1/e2ee/social/proxy_shards';
  static const e2eeSocialDecryptShard = '/api/v1/e2ee/social/decrypt_shard';
  static const e2eeSocialRecover = '/api/v1/e2ee/social/recover';

  // E2EE+ 设备间传输
  static const e2eeTransferCreate = '/api/v1/e2ee/transfer/create';
  static const e2eeTransferInfo = '/api/v1/e2ee/transfer/info';
  static const e2eeTransferAccept = '/api/v1/e2ee/transfer/accept';
  static const e2eeTransferConfirm = '/api/v1/e2ee/transfer/confirm';
  static const e2eeTransferPending = '/api/v1/e2ee/transfer/pending';

  // 推送通知
  static const pushRegister = '/api/v1/push/register';
  static const pushUnregister = '/api/v1/push/unregister';
  // 用户数据导出
  static const userExportData = '/api/v1/user/export_data';

  // 投诉举报
  static const reportCreate = '/api/v1/report/create';
  static const groupReportCreate = '/api/v1/group/report/create';

  // 直播间
  static const liveRoomList = '/api/v1/live_room/list';
  static const liveRoomMyList = '/api/v1/live_room/my_list';
  static const liveRoomCreate = '/api/v1/live_room/create';
  static const liveRoomStart = '/api/v1/live_room/start';
  static const liveRoomStop = '/api/v1/live_room/stop';
  static const liveRoomDetail = '/api/v1/live_room/detail';

  // 朋友圈（静态路径）
  static const momentCreate = '/api/v1/moment/create';
  static const momentsFeed = '/api/v1/moments/feed';

  // 钱包 API
  static const walletBalance = '/api/v1/wallet/balance';
  static const walletTransactions = '/api/v1/wallet/transactions';
  static const walletTopup = '/api/v1/wallet/topup';

  // 红包、转账、提现 API
  static const walletRedPacketSend = '/api/v1/wallet/red_packet/send';
  static const walletRedPacketOpen = '/api/v1/wallet/red_packet/open';
  static String walletRedPacketDetail(String id) =>
      '/api/v1/wallet/red_packet/$id/detail';
  static const walletTransferSend = '/api/v1/wallet/transfer/send';
  static const walletTransferAccept = '/api/v1/wallet/transfer/accept';
  static const walletWithdraw = '/api/v1/wallet/withdraw';

  // 钱包充值（真实链路：创建订单 → 拉起支付 → 查询状态）
  static const walletRechargeOrder = '/api/v1/wallet/recharge/order';
  static const walletRechargePay = '/api/v1/wallet/recharge/pay';
  static String walletRechargeOrderStatus(String orderNo) =>
      '/api/v1/wallet/recharge/$orderNo';

  // 付费频道订单（创建 → 支付 → 查询），均 JWT 保护
  static String channelCreateOrder(String channelId) =>
      '/api/v1/channel/$channelId/order';
  static const channelOrderPay = '/api/v1/channel/order/pay';
  static const channelOrderRefund = '/api/v1/channel/order/refund';
  static const channelMyOrders = '/api/v1/channel/orders/my';
  static String channelOrderStatus(String orderNo) =>
      '/api/v1/channel/order/$orderNo';

  // 附件 presign 直传（Garage S3），均 JWT 保护
  static const attachmentPresign = '/api/v1/attachment/presign';
  static const attachmentConfirm = '/api/v1/attachment/confirm';
  static const attachmentViewUrl = '/api/v1/attachment/view_url';

  // 朋友圈（动态路径）
  static String momentDetail(String id) => '/api/v1/moment/$id';
  static String momentDelete(String id) => '/api/v1/moment/$id/delete';
  static String momentLike(String id) => '/api/v1/moment/$id/like';
  static String momentUnlike(String id) => '/api/v1/moment/$id/unlike';
  static String momentComment(String id) => '/api/v1/moment/$id/comment';
  static String momentComments(String id) => '/api/v1/moment/$id/comments';
  static String momentCommentDelete(String momentId, String commentId) =>
      '/api/v1/moment/$momentId/comment/$commentId/delete';
  static String momentReport(String id) => '/api/v1/moment/$id/report';
  static String momentsUser(String uid) => '/api/v1/moments/user/$uid';
}
