// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

const contactAssets = 'assets/images/contact/';

const constHelpUrl =
    'https://kf.qq.com/touch/product/wechat_app.html?scene_id=kf338';

String qrcodeDataSuffix = "s=app_qrcode";

const recordLog = true;

Icon navigateNextIcon = const Icon(Icons.navigate_next);

class Keys {
  static const String wsUrl = "ws_url";
  static const String apiPublicKey = "api_public_key";
  static const String uploadUrl = "upload_url";
  static const String uploadKey = "upload_key";
  static const String uploadScene = "upload_scene";
  static const String appFeatures = "app_features";

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
  static const initConfig = '/v1/init';
  static const refreshToken = '/v1/refreshtoken';
  static const login = '/v1/passport/login';
  static const signup = '/v1/passport/signup';
  static const getCode = '/v1/passport/getcode';
  static const quickLogin = '/v1/passport/quick_login';
  static const findPassword = '/v1/passport/findpassword';
  static const appVersionCheck = '/v1/app_version/check';
  static const appFeatures = '/v1/app/features';
  static const appPolicy = '/v1/app/policy';
  static const sqliteUpgradeDdl = '/v1/app_ddl/get?type=upgrade';
  static const sqliteDowngradeDdl = '/v1/app_ddl/get?type=downgrade';

  static const addFriend = '/v1/friend/add';
  static const confirmFriend = '/v1/friend/confirm';
  static const deleteFriend = '/v1/friend/delete';
  static const friendList = '/v1/friend/list';
  static const friendChangeRemark = '/v1/friend/change_remark';

  static const conversationList = '/v1/conversation/mine';
  static const conversationPin = '/v1/conversation/pin';
  static const conversationUnpin = '/v1/conversation/unpin';
  static const conversationDelete = '/v1/conversation/delete';
  static const conversationRestore = '/v1/conversation/restore';
  static const conversationPinned = '/v1/conversation/pinned';
  // 拉取离线
  static const msgOffline = '/v1/msg/offline';
  // 确认离线消息已处理
  static const msgOfflineAck = '/v1/msg/offline_ack';
  // 查询消息历史（conv_seq 游标分页）
  static const msgHistory = '/v1/msg/history';

  static const denylistAdd = '/v1/friend/denylist/add';
  static const denylistRemove = '/v1/friend/denylist/remove';
  static const denylistPage = '/v1/friend/denylist/page';

  static const groupFace2face = '/v1/group/face2face';
  static const groupFace2faceSave = '/v1/group/face2face_save';
  static const groupAdd = '/v1/group/add';
  static const groupEdit = '/v1/group/edit';
  static const groupDetail = '/v1/group/detail';
  static const groupDissolve = '/v1/group/dissolve';
  static const groupPage = '/v1/group/page';
  static const groupMemberPage = '/v1/group_member/page';
  static const groupMemberJoin = '/v1/group_member/join';
  static const groupMemberLeave = '/v1/group_member/leave';
  static const groupMemberAlias = '/v1/group_member/alias';
  static const groupMemberSameGroup = '/v1/group_member/same_group';
  static const groupMemberRole = '/v1/group_member/role';
  static const groupMemberMute = '/v1/group_member/mute';
  static const groupTransfer = '/v1/group/transfer';
  static const groupRemark = '/v1/group/remark';

  static const userShow = '/v1/user/show';
  static const turnCredential = '/v1/user/credential';
  static const userUpdate = '/v1/user/update';
  static const userSetting = '/v1/user/setting';
  static const userChangePassword = '/v1/user/change_password';
  static const userSetPassword = '/v1/user/set_password';
  static const userApplyLogout = '/v1/user/apply_logout';
  static const userCancelLogout = '/v1/user/cancel_logout';
  static const userSearch = '/v1/user/search';

  static const ftsRecentlyUser = '/v1/fts/recently_user';
  static const ftsMessage = '/v1/fts/msg';

  static const userDevicePage = '/v1/user_device/page';
  static const userDeviceChangeName = '/v1/user_device/change_name';
  static const userDeviceDelete = '/v1/user_device/delete';
  static const userDeviceSessions = '/v1/user_device/sessions';
  static const userDeviceCheckLogin = '/v1/user_device/check_login';
  static const userDeviceKick = '/v1/user_device/kick';
  static const userDeviceKickOthers = '/v1/user_device/kick-others';

  static const userCollectPage = '/v1/user_collect/page';
  static const userCollectAdd = '/v1/user_collect/add';
  static const userCollectRemove = '/v1/user_collect/remove';
  static const userCollectChange = '/v1/user_collect/change';

  static const userTagPage = '/v1/user_tag/page';
  static const userTagAdd = '/v1/user_tag/add';
  static const userTagDelete = '/v1/user_tag/delete';
  static const userTagChangeName = '/v1/user_tag/change_name';

  static const userTagRelationFriendPage = '/v1/user_tag_relation/friend_page';
  static const userTagRelationCollectPage =
      '/v1/user_tag_relation/collect_page';
  static const userTagRelationAdd = '/v1/user_tag_relation/add';
  static const userTagRelationSet = '/v1/user_tag_relation/set';
  static const userTagRelationRemove = '/v1/user_tag_relation/remove';

  static const feedbackPage = '/v1/feedback/page';
  static const feedbackAdd = '/v1/feedback/add';
  static const feedbackRemove = '/v1/feedback/remove';
  static const feedbackChange = '/v1/feedback/change';
  static const feedbackPageReply = '/v1/feedback/page_reply';

  // 附近的人
  static const peopleNearby = '/v1/location/peopleNearby';
  static const makeMyselfVisible = '/v1/location/makeMyselfVisible';
  static const makeMyselfUnVisible = '/v1/location/makeMyselfUnvisible';

  // 群文件
  static const groupFileCategories = '/v1/group/file/categories';
  static const groupFileList = '/v1/group/file/list';
  static const groupFileUpload = '/v1/group/file/upload';
  static const groupFileSearch = '/v1/group/file/search';
  static const groupFileDelete = '/v1/group/file/delete';

  // @提及
  static const mentionList = '/v1/mention/list';
  static const mentionMarkRead = '/v1/mention/mark_read';
  static const mentionSuggest = '/v1/mention/suggest';
  static const mentionUnread = '/v1/mention/unread';

  // 群标签
  static const groupTagAdd = '/v1/group/tag/add';
  static const groupTagList = '/v1/group/tag/list';
  static const groupTagRemove = '/v1/group/tag/remove';
  static const groupTagSearch = '/v1/group/tag/search';
  static const groupTagHot = '/v1/group/tag/hot';

  // 群分组
  static const groupCategoryCreate = '/v1/group/category/create';
  static const groupCategoryDelete = '/v1/group/category/delete';
  static const groupCategoryList = '/v1/group/category/list';
  static const groupCategoryRename = '/v1/group/category/rename';
  static const groupCategorySort = '/v1/group/category/sort';
  static const groupCategoryMoveGroup = '/v1/group/category/move_group';

  // 群日程
  static const groupScheduleCreate = '/v1/group_schedule/create';
  static const groupScheduleUpdate = '/v1/group_schedule/update';
  static const groupScheduleCancel = '/v1/group_schedule/cancel';
  static const groupScheduleConfirm = '/v1/group_schedule/confirm';
  static const groupScheduleDetail = '/v1/group_schedule/detail';
  static const groupScheduleList = '/v1/group_schedule/list';
  static const groupScheduleMyList = '/v1/group_schedule/my_list';

  // 群相册
  static const groupAlbumCreate = '/v1/group_album/create';
  static const groupAlbumDelete = '/v1/group_album/delete';
  static const groupAlbumList = '/v1/group_album/list';
  static const groupAlbumRename = '/v1/group_album/rename';
  static const groupAlbumCoverUpdate = '/v1/group_album/cover/update';
  static const groupAlbumPhotoUpload = '/v1/group_album/photo/upload';
  static const groupAlbumPhotoList = '/v1/group_album/photo/list';
  static const groupAlbumPhotoDetail = '/v1/group_album/photo/detail';
  static const groupAlbumPhotoDelete = '/v1/group_album/photo/delete';

  // 群任务
  static const groupTaskCreate = '/v1/group/task/create';
  static const groupTaskUpdate = '/v1/group/task/update';
  static const groupTaskDetail = '/v1/group/task/detail';
  static const groupTaskList = '/v1/group/task/list';
  static const groupTaskMy = '/v1/group/task/my';
  static const groupTaskPending = '/v1/group/task/pending';
  static const groupTaskAssign = '/v1/group/task/assign';
  static const groupTaskSubmit = '/v1/group/task/submit';
  static const groupTaskReview = '/v1/group/task/review';

  // 群投票
  static const groupVoteCreate = '/v1/group/vote/create';
  static const groupVoteUpdate = '/v1/group/vote/update';
  static const groupVoteCancel = '/v1/group/vote/cancel';
  static const groupVoteClose = '/v1/group/vote/close';
  static const groupVoteCast = '/v1/group/vote/cast';
  static const groupVoteDetail = '/v1/group/vote/detail';
  static const groupVoteList = '/v1/group/vote/list';
  static const groupVoteMyVote = '/v1/group/vote/my_vote';

  // E2EE
  static const e2eeUserKeys = '/v1/e2ee/user_keys';
  static const e2eeGroupMemberKeys = '/v1/e2ee/group_member_keys';
  static const e2eeReportDeviceKey = '/v1/e2ee/report_device_key';

  // 合规密钥（三层加密架构）
  static const e2eeComplianceKey = '/v1/e2ee/compliance_key';

  // E2EE+ 社交恢复
  static const e2eeSocialContacts = '/v1/e2ee/social/contacts';
  static const e2eeSocialContactsAdd = '/v1/e2ee/social/contacts/add';
  static const e2eeSocialContactsRemove = '/v1/e2ee/social/contacts/remove';
  static const e2eeSocialCreateShards = '/v1/e2ee/social/create_shards';
  static const e2eeSocialShards = '/v1/e2ee/social/shards';
  static const e2eeSocialProxyShards = '/v1/e2ee/social/proxy_shards';
  static const e2eeSocialDecryptShard = '/v1/e2ee/social/decrypt_shard';
  static const e2eeSocialRecover = '/v1/e2ee/social/recover';

  // E2EE+ 设备间传输
  static const e2eeTransferCreate = '/v1/e2ee/transfer/create';
  static const e2eeTransferInfo = '/v1/e2ee/transfer/info';
  static const e2eeTransferAccept = '/v1/e2ee/transfer/accept';
  static const e2eeTransferConfirm = '/v1/e2ee/transfer/confirm';
  static const e2eeTransferPending = '/v1/e2ee/transfer/pending';
  static const e2eeBackupList = '/v1/e2ee/backup/list';
  static const e2eeBackupDelete = '/v1/e2ee/backup/delete';

  // 推送通知
  static const pushRegister = '/v1/push/register';
  static const pushUnregister = '/v1/push/unregister';
  // 用户数据导出
  static const userExportData = '/v1/user/export_data';

  // 投诉举报
  static const reportCreate = '/v1/report/create';
  static const groupReportCreate = '/v1/group/report/create';

  // 直播间
  static const liveRoomList = '/v1/live_room/list';
  static const liveRoomMyList = '/v1/live_room/my_list';
  static const liveRoomCreate = '/v1/live_room/create';
  static const liveRoomStart = '/v1/live_room/start';
  static const liveRoomStop = '/v1/live_room/stop';
  static const liveRoomDetail = '/v1/live_room/detail';

  // 朋友圈（静态路径）
  static const momentCreate = '/v1/moment/create';
  static const momentsFeed = '/v1/moments/feed';

  // 钱包 API
  static const walletBalance = '/v1/wallet/balance';
  static const walletTransactions = '/v1/wallet/transactions';
  static const walletTopup = '/v1/wallet/topup';

  // 朋友圈（动态路径）
  static String momentDetail(String id) => '/v1/moment/$id';
  static String momentDelete(String id) => '/v1/moment/$id/delete';
  static String momentLike(String id) => '/v1/moment/$id/like';
  static String momentUnlike(String id) => '/v1/moment/$id/unlike';
  static String momentComment(String id) => '/v1/moment/$id/comment';
  static String momentComments(String id) => '/v1/moment/$id/comments';
  static String momentCommentDelete(String momentId, String commentId) =>
      '/v1/moment/$momentId/comment/$commentId/delete';
  static String momentReport(String id) => '/v1/moment/$id/report';
  static String momentsUser(String uid) => '/v1/moments/user/$uid';
}
