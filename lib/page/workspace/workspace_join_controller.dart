/// T2.6 (WP 团队码) — 「团队码加入」控制器（纯逻辑，ChangeNotifier）
///
/// 仿 [WorkspaceInviteResultsController] 的动作注入模式：joinByCode 经
/// 构造/方法参数由页面装配（真实实现读 workspaceApiProvider，测试注入
/// Future），本类只管输入规范化与状态机，可无网络单测。
///
/// 状态机：idle → submitting → success（joined/unchanged 均成功）|
/// invalidCode(981) | expiredCode(982) | failed（其它异常，服务端消息
/// 透出）。错误文案映射（i18n）留在页面——控制器不持有 BuildContext。
///
/// GZAPP-04：入口决定端点分支（[WorkspaceJoinEntryKind]）——
/// workspace（默认，团队码 join ws）| organization（企业邀请码 join org，
/// 需 organizationId + joinOrgByCode 注入；981/982 语义与 ws 团队码一致）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// 团队码长度（后端契约：8 位大写字母数字）。
const int kWorkspaceJoinCodeLength = 8;

/// 加入入口决定调用哪个端点（GZAPP-04：org code vs ws code）。
enum WorkspaceJoinEntryKind { workspace, organization }

/// 加入流程阶段。
enum WorkspaceJoinPhase {
  idle,
  submitting,
  success,
  invalidCode,
  expiredCode,
  failed,
}

/// 加入流程状态快照。
class WorkspaceJoinState {
  final WorkspaceJoinPhase phase;

  /// 成功加入的工作区（仅 success 且 workspace 入口有值）。
  final WorkspaceModel workspace;

  /// success 下：unchanged（已是成员，幂等命中）→ 成功提示用 joinAlreadyMember。
  final bool alreadyMember;

  /// 成功加入的企业（仅 success 且 organization 入口有值）。
  final OrganizationJoinOutcome orgOutcome;

  /// failed 的透出消息（invalidCode/expiredCode 由页面映射 i18n）。
  final String message;

  const WorkspaceJoinState({
    this.phase = WorkspaceJoinPhase.idle,
    this.workspace = const WorkspaceModel(id: '', name: '', ownerId: ''),
    this.alreadyMember = false,
    this.orgOutcome = const OrganizationJoinOutcome(),
    this.message = '',
  });

  WorkspaceJoinState copyWith({
    WorkspaceJoinPhase? phase,
    WorkspaceModel? workspace,
    bool? alreadyMember,
    OrganizationJoinOutcome? orgOutcome,
    String? message,
  }) => WorkspaceJoinState(
    phase: phase ?? this.phase,
    workspace: workspace ?? this.workspace,
    alreadyMember: alreadyMember ?? this.alreadyMember,
    orgOutcome: orgOutcome ?? this.orgOutcome,
    message: message ?? this.message,
  );
}

/// 团队码输入 formatter：转大写 + 仅保留字母数字（配合
/// LengthLimitingTextInputFormatter 使用，本类兜底再截一次长度）。
class WorkspaceCodeInputFormatter extends TextInputFormatter {
  final int maxLength;

  const WorkspaceCodeInputFormatter({
    this.maxLength = kWorkspaceJoinCodeLength,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitized = newValue.text.toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    final capped = sanitized.length > maxLength
        ? sanitized.substring(0, maxLength)
        : sanitized;
    // 团队码为整段输入场景：光标始终随末尾（规避中段删除时的越界 selection）
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}

/// 「团队码加入」状态机。
class WorkspaceJoinController extends ChangeNotifier {
  WorkspaceJoinController({
    this.entryKind = WorkspaceJoinEntryKind.workspace,
    this.organizationId = '',
  });

  /// 入口决定的端点分支（GZAPP-04：org code vs ws code）。
  final WorkspaceJoinEntryKind entryKind;

  /// organization 入口的目标企业 ID（TSID 字符串；workspace 入口忽略）。
  final EntityId organizationId;

  WorkspaceJoinState _state = const WorkspaceJoinState();
  String _code = '';

  WorkspaceJoinState get state => _state;
  String get code => _code;

  bool get canSubmit => _code.length == kWorkspaceJoinCodeLength;
  bool get isSubmitting => _state.phase == WorkspaceJoinPhase.submitting;

  /// 输入变更（TextField onChanged；formatter 已产出大写形态，此处再兜底
  /// 规范化一次——粘贴等路径不经过 formatter 时语义不变）。
  ///
  /// 返回是否「刚好输满 8 位」——页面据此自动提交（镜像 face_to_face
  /// 输满 4 位自动提交体验）；从满位回改/删除不触发。
  bool updateCode(String raw) {
    final wasFull = _code.length == kWorkspaceJoinCodeLength;
    _code = _normalize(raw);
    // 编辑即清除错误态（页面内错误文案随输入消失）
    if (_state.phase == WorkspaceJoinPhase.invalidCode ||
        _state.phase == WorkspaceJoinPhase.expiredCode ||
        _state.phase == WorkspaceJoinPhase.failed) {
      _state = _state.copyWith(phase: WorkspaceJoinPhase.idle, message: '');
    }
    notifyListeners();
    return !wasFull && _code.length == kWorkspaceJoinCodeLength;
  }

  /// 提交加入。返回是否成功（joined/unchanged 均为 true；失败留在页面，
  /// 由 state.phase/message 驱动页内错误文案）。
  ///
  /// 端点分支由 [entryKind] 决定（GZAPP-04）：workspace → joinByCode
  /// （注入必须非空）；organization → joinOrgByCode（注入必须非空且
  /// [organizationId] 已配置），organization 分支成功态落在
  /// state.orgOutcome。
  Future<bool> submit({
    Future<WorkspaceJoinResult> Function(String code)? joinByCode,
    Future<OrganizationJoinOutcome> Function(EntityId orgId, String code)?
    joinOrgByCode,
  }) async {
    if (!canSubmit || isSubmitting) return false;
    if (entryKind == WorkspaceJoinEntryKind.workspace && joinByCode == null) {
      return false;
    }
    if (entryKind == WorkspaceJoinEntryKind.organization &&
        (joinOrgByCode == null || organizationId.isEmpty)) {
      return false;
    }
    _set(const WorkspaceJoinState(phase: WorkspaceJoinPhase.submitting));
    try {
      if (entryKind == WorkspaceJoinEntryKind.organization) {
        final outcome = await joinOrgByCode!(organizationId, _code);
        _set(
          WorkspaceJoinState(
            phase: WorkspaceJoinPhase.success,
            orgOutcome: outcome,
          ),
        );
        return true;
      }
      final result = await joinByCode!(_code);
      _set(
        WorkspaceJoinState(
          phase: WorkspaceJoinPhase.success,
          workspace: result.workspace,
          alreadyMember: result.isAlreadyMember,
        ),
      );
      return true;
    } on WorkspaceApiException catch (e) {
      return _mapJoinError(e.isInviteInvalid, e.isInviteExpired, e.message);
    } on OrganizationApiException catch (e) {
      // 企业邀请码分支：981/982 与 ws 团队码同语义（GZAPP-01 契约）。
      return _mapJoinError(e.isInviteInvalid, e.isInviteExpired, e.message);
    } catch (e) {
      _set(
        WorkspaceJoinState(
          phase: WorkspaceJoinPhase.failed,
          message: e.toString(),
        ),
      );
      return false;
    }
  }

  bool _mapJoinError(bool invalid, bool expired, String message) {
    if (invalid) {
      _set(const WorkspaceJoinState(phase: WorkspaceJoinPhase.invalidCode));
    } else if (expired) {
      _set(const WorkspaceJoinState(phase: WorkspaceJoinPhase.expiredCode));
    } else {
      // 403 越权 / 980 归档 / 404 等：服务端消息原样透出
      _set(
        WorkspaceJoinState(phase: WorkspaceJoinPhase.failed, message: message),
      );
    }
    return false;
  }

  /// 重置（离开页面/换码重输）。
  void reset() {
    _code = '';
    _set(const WorkspaceJoinState());
  }

  String _normalize(String raw) {
    final s = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return s.length > kWorkspaceJoinCodeLength
        ? s.substring(0, kWorkspaceJoinCodeLength)
        : s;
  }

  void _set(WorkspaceJoinState next) {
    // 提交在途时退出页面（输满自动提交 + 立即返回）：dispose 后
    // notifyListeners 会抛 FlutterError（debug）/静默写死对象（release）
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _state = const WorkspaceJoinState();
    _code = '';
    super.dispose();
  }
}
