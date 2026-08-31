/// T2.6 (WP 团队码) — 「团队码加入」控制器（纯逻辑，ChangeNotifier）
///
/// 仿 [WorkspaceInviteResultsController] 的动作注入模式：joinByCode 经
/// 构造/方法参数由页面装配（真实实现读 workspaceApiProvider，测试注入
/// Future），本类只管输入规范化与状态机，可无网络单测。
///
/// 状态机：idle → submitting → success（joined/unchanged 均成功）|
/// invalidCode(981) | expiredCode(982) | failed（其它异常，服务端消息
/// 透出）。错误文案映射（i18n）留在页面——控制器不持有 BuildContext。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// 团队码长度（后端契约：8 位大写字母数字）。
const int kWorkspaceJoinCodeLength = 8;

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

  /// 成功加入的工作区（仅 success 有值）。
  final WorkspaceModel workspace;

  /// success 下：unchanged（已是成员，幂等命中）→ 成功提示用 joinAlreadyMember。
  final bool alreadyMember;

  /// failed 的透出消息（invalidCode/expiredCode 由页面映射 i18n）。
  final String message;

  const WorkspaceJoinState({
    this.phase = WorkspaceJoinPhase.idle,
    this.workspace = const WorkspaceModel(id: '', name: '', ownerId: ''),
    this.alreadyMember = false,
    this.message = '',
  });

  WorkspaceJoinState copyWith({
    WorkspaceJoinPhase? phase,
    WorkspaceModel? workspace,
    bool? alreadyMember,
    String? message,
  }) => WorkspaceJoinState(
    phase: phase ?? this.phase,
    workspace: workspace ?? this.workspace,
    alreadyMember: alreadyMember ?? this.alreadyMember,
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
  Future<bool> submit({
    required Future<WorkspaceJoinResult> Function(String code) joinByCode,
  }) async {
    if (!canSubmit || isSubmitting) return false;
    _set(const WorkspaceJoinState(phase: WorkspaceJoinPhase.submitting));
    try {
      final result = await joinByCode(_code);
      _set(
        WorkspaceJoinState(
          phase: WorkspaceJoinPhase.success,
          workspace: result.workspace,
          alreadyMember: result.isAlreadyMember,
        ),
      );
      return true;
    } on WorkspaceApiException catch (e) {
      if (e.isInviteInvalid) {
        _set(const WorkspaceJoinState(phase: WorkspaceJoinPhase.invalidCode));
      } else if (e.isInviteExpired) {
        _set(const WorkspaceJoinState(phase: WorkspaceJoinPhase.expiredCode));
      } else {
        // 403 越权 / 980 归档 / 404 等：服务端消息原样透出
        _set(
          WorkspaceJoinState(
            phase: WorkspaceJoinPhase.failed,
            message: e.message,
          ),
        );
      }
      return false;
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
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _state = const WorkspaceJoinState();
    _code = '';
    super.dispose();
  }
}
