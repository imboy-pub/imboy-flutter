/// 面聊记录（talk_record）UI 服务接口层（T10）。
///
/// 页面不直接持有 [TalkRecordApi]：全部数据与副作用经此处抽象网关注入，
/// 目的有三：
/// 1. widget 测试零网络、零麦克风副作用（fixture 注入，见 test/talk_record/）；
/// 2. T11+ 联调时替换为带缓存/重试的实现而无需改页面；
/// 3. 录音/参与者目录等后续任务（T09/T16）的接入点在编译期可见，
///    不做「假装已接入」的 UI。
///
/// 默认实现纪律：
/// - 数据和目录服务走认证 [TalkRecordApi]，失败不吞成空列表；
/// - 麦克风权限默认走 permission_handler（仅用户主动点击「开始录音/
///   重试」后触发；本文件不初始化任何权限请求）；
/// - 录音启动器由常驻 application 协调器接入本机服务；仅主动开始后开麦；
/// - 参与者目录按当前归属查询；选择仅记录参与者事实，不创建共享授权。
library;

import 'package:permission_handler/permission_handler.dart';

import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'talk_record_entry_context.dart';

// ---------------------------------------------------------------------------
// 数据服务（列表 / 能力 / 创建上下文）
// ---------------------------------------------------------------------------

/// 列表与能力数据源抽象。
abstract class TalkRecordListService {
  /// GET /（cursor 分页；scope/org/ws/filter/q 与 T08 API 同义）。
  Future<TalkRecordCursorPage<TalkRecordModel>> page({
    TalkRecordScope? scope,
    EntityId? organizationId,
    EntityId? workspaceId,
    TalkRecordListFilter? filter,
    String? q,
    String cursor = '',
    int? limit,
  });

  /// GET /capabilities。
  Future<TalkRecordCapabilitiesModel> capabilities();

  /// GET /creation-contexts（首屏聚合，V1 取首页；更多翻页留给 T11）。
  Future<List<TalkRecordCreationContextModel>> creationContexts({
    String cursor = '',
    int? limit,
  });
}

/// 默认实现：薄封装 T08 API 客户端。
class TalkRecordApiListService implements TalkRecordListService {
  TalkRecordApiListService([TalkRecordApi? api])
    : _api = api ?? TalkRecordApi();

  final TalkRecordApi _api;

  @override
  Future<TalkRecordCursorPage<TalkRecordModel>> page({
    TalkRecordScope? scope,
    EntityId? organizationId,
    EntityId? workspaceId,
    TalkRecordListFilter? filter,
    String? q,
    String cursor = '',
    int? limit,
  }) {
    return _api.list(
      scope: scope,
      organizationId: organizationId,
      workspaceId: workspaceId,
      filter: filter,
      q: q,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<TalkRecordCapabilitiesModel> capabilities() {
    return _api.capabilities();
  }

  @override
  Future<List<TalkRecordCreationContextModel>> creationContexts({
    String cursor = '',
    int? limit,
  }) async {
    final result = await _api.creationContexts(cursor: cursor, limit: limit);
    return result.list;
  }
}

// ---------------------------------------------------------------------------
// 麦克风权限网关
// ---------------------------------------------------------------------------

/// 麦克风权限状态（UI 侧归并：restricted/permanentlyDenied 都按
/// 「被拒绝且需引导」处理，但保留区分以决定「去设置」文案权重）。
enum TalkRecordMicPermissionStatus { granted, denied, restricted }

/// 麦克风权限网关抽象（widget 测试注入 fake，绝不触平台通道）。
abstract class TalkRecordMicPermissionGateway {
  Future<TalkRecordMicPermissionStatus> request();
  Future<void> openSettings();
}

/// 默认实现：permission_handler（仅用户主动触发后调用）。
class PermissionHandlerMicPermissionGateway
    implements TalkRecordMicPermissionGateway {
  const PermissionHandlerMicPermissionGateway();

  @override
  Future<TalkRecordMicPermissionStatus> request() async {
    final status = await Permission.microphone.request();
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited => TalkRecordMicPermissionStatus.granted,
      PermissionStatus.permanentlyDenied =>
        TalkRecordMicPermissionStatus.restricted,
      _ => TalkRecordMicPermissionStatus.denied,
    };
  }

  @override
  Future<void> openSettings() => openAppSettings();
}

// ---------------------------------------------------------------------------
// 录音启动器（application 协调器接入点）
// ---------------------------------------------------------------------------

/// 准备页提交给录音引擎的最小请求（对齐 POST / 创建语义的字段子集）。
class TalkRecordRecordingDraftRequest {
  final String title;
  final String policyVersion;
  final String processorConfigVersion;
  final bool Function()? isCurrentOperation;
  final String language;
  final TalkRecordEntryContext saveTo;
  final TalkRecordProcessingMode processingMode;
  final List<TalkRecordParticipantSelection> participants;

  const TalkRecordRecordingDraftRequest({
    this.title = '',
    this.policyVersion = '',
    this.processorConfigVersion = '',
    this.isCurrentOperation,
    this.language = 'auto',
    required this.saveTo,
    this.processingMode = TalkRecordProcessingMode.recordOnly,
    this.participants = const [],
  });

  void checkCurrentOperation() {
    if (isCurrentOperation?.call() == false) {
      throw StateError('Recording start intent expired');
    }
  }
}

/// 准备页参与者选择；与录音持久化并同步参与者接口，不创建 grants。
class TalkRecordParticipantSelection {
  final EntityId userId;
  final String displayName;

  const TalkRecordParticipantSelection({
    required this.userId,
    this.displayName = '',
  });

  @override
  bool operator ==(Object other) =>
      other is TalkRecordParticipantSelection &&
      (userId.isNotEmpty
          ? other.userId == userId
          : other.userId.isEmpty &&
                other.displayName.trim() == displayName.trim());

  @override
  int get hashCode =>
      userId.isNotEmpty ? userId.hashCode : displayName.trim().hashCode;
}

/// 启动结果：started=false 时 messageKey 为 i18n 键名（不给假成功）。
class TalkRecordRecordingLaunchResult {
  final bool started;
  final String messageKey;

  const TalkRecordRecordingLaunchResult._({
    required this.started,
    required this.messageKey,
  });

  /// 本机服务成功启动。
  const TalkRecordRecordingLaunchResult.started()
    : this._(started: true, messageKey: '');

  const TalkRecordRecordingLaunchResult.unavailable()
    : this._(started: false, messageKey: 'recordingUnavailableMessage');

  const TalkRecordRecordingLaunchResult.notificationsRequired()
    : this._(started: false, messageKey: 'recordingNotificationRequired');
  bool get notificationRequired =>
      messageKey == 'recordingNotificationRequired';
}

/// 录音启动器抽象：权限后开本机采集；服务端映射联网后单独同步。
abstract class TalkRecordRecordingLauncher {
  Future<TalkRecordRecordingLaunchResult> launch(
    TalkRecordRecordingDraftRequest request,
  );
}

/// 默认占位实现：无任何录音副作用，如实返回「不可用」。
class UnavailableRecordingLauncher implements TalkRecordRecordingLauncher {
  const UnavailableRecordingLauncher();

  @override
  Future<TalkRecordRecordingLaunchResult> launch(
    TalkRecordRecordingDraftRequest request,
  ) async {
    return const TalkRecordRecordingLaunchResult.unavailable();
  }
}

// ---------------------------------------------------------------------------
// 参与者目录（认证 API；空目录仅供显式降级与测试注入）
// ---------------------------------------------------------------------------

/// 参与者候选（最小展示信息）。
class TalkRecordParticipantOption {
  final EntityId userId;
  final String displayName;
  final String account;

  const TalkRecordParticipantOption({
    required this.userId,
    this.displayName = '',
    this.account = '',
  });
}

/// 参与者目录抽象：T16 接 share-candidates/企业目录。
abstract class TalkRecordParticipantDirectory {
  /// 目录是否可用（默认实现 false：选择器如实提示「待接入」）。
  bool get isAvailable;

  Future<List<TalkRecordParticipantOption>> search(
    EntityId organizationId,
    String q,
  );
}

/// 默认实现：不可用空目录（不猜候选人，不假装可共享）。
class EmptyParticipantDirectory implements TalkRecordParticipantDirectory {
  const EmptyParticipantDirectory();

  @override
  bool get isAvailable => false;

  @override
  Future<List<TalkRecordParticipantOption>> search(
    EntityId organizationId,
    String q,
  ) async {
    return const [];
  }
}

/// Directory results remain subject to server validation when saved.
class ApiTalkRecordParticipantDirectory extends TalkRecordParticipantDirectory {
  ApiTalkRecordParticipantDirectory(this.api);
  final TalkRecordApi api;
  @override
  bool get isAvailable => true;
  @override
  Future<List<TalkRecordParticipantOption>> search(
    String organizationId,
    String q,
  ) => searchContext(
    TalkRecordEntryContext(
      scope: TalkRecordScope.organization,
      organizationId: organizationId,
    ),
    q,
  );
  Future<List<TalkRecordParticipantOption>> searchContext(
    TalkRecordEntryContext context,
    String query,
  ) async {
    final page = await api.participantCandidates(
      scope: context.scope,
      organizationId: context.organizationId,
      workspaceId: context.workspaceId,
      q: query,
    );
    return page.list
        .map(
          (item) => TalkRecordParticipantOption(
            userId: item.userId,
            displayName: item.displayName,
          ),
        )
        .toList(growable: false);
  }
}

extension TalkRecordParticipantDirectoryContext
    on TalkRecordParticipantDirectory {
  Future<List<TalkRecordParticipantOption>> searchContext(
    TalkRecordEntryContext context,
    String query,
  ) {
    final directory = this;
    if (directory is ApiTalkRecordParticipantDirectory) {
      return directory.searchContext(context, query);
    }
    return search(context.organizationId, query);
  }
}
