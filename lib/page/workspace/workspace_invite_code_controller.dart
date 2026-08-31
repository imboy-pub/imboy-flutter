/// T2.6 (WP 团队码) — 邀请页「团队码」卡片控制器（纯逻辑，ChangeNotifier）
///
/// 仿 [WorkspaceInviteResultsController] 的动作注入模式：createInviteCode /
/// revokeInviteCode 与剪贴板写入由页面装配（API / Clipboard），本类只管
/// 状态机，可无网络单测。
///
/// 契约口径：一工作区一个 active 码。「重新生成」由后端同事务撤旧码实现
/// 覆盖语义；「撤销」走独立 revoke 端点，成功后回 idle（码清空，输码即
/// 981）。
library;

import 'package:flutter/foundation.dart';

import 'package:imboy/store/model/workspace_model.dart';

/// 团队码卡片阶段。
enum WorkspaceInviteCodePhase { idle, generating, ready, revoking, failed }

/// 团队码卡片状态快照。
class WorkspaceInviteCodeState {
  final WorkspaceInviteCodePhase phase;

  /// 当前 active 码（仅 ready 有值）。
  final WorkspaceInviteCode inviteCode;

  /// failed 的透出消息（生成失败：403 越权 / 980 归档等）。
  final String message;

  /// 最近一次复制是否成功（页面据此轻提示，重新生成后复位）。
  final bool copied;

  const WorkspaceInviteCodeState({
    this.phase = WorkspaceInviteCodePhase.idle,
    this.inviteCode = const WorkspaceInviteCode(),
    this.message = '',
    this.copied = false,
  });

  WorkspaceInviteCodeState copyWith({
    WorkspaceInviteCodePhase? phase,
    WorkspaceInviteCode? inviteCode,
    String? message,
    bool? copied,
  }) => WorkspaceInviteCodeState(
    phase: phase ?? this.phase,
    inviteCode: inviteCode ?? this.inviteCode,
    message: message ?? this.message,
    copied: copied ?? this.copied,
  );
}

/// 团队码卡片状态机（generate / copy）。
class WorkspaceInviteCodeController extends ChangeNotifier {
  WorkspaceInviteCodeState _state = const WorkspaceInviteCodeState();

  WorkspaceInviteCodeState get state => _state;
  bool get isGenerating => _state.phase == WorkspaceInviteCodePhase.generating;
  bool get isRevoking => _state.phase == WorkspaceInviteCodePhase.revoking;
  bool get hasCode => _state.inviteCode.isValid;

  /// 生成 / 重新生成团队码（重新生成覆盖旧码：一工作区一个 active 码）。
  Future<void> generate({
    required Future<WorkspaceInviteCode> Function() createInviteCode,
  }) async {
    // 撤销在途时同样忽略：revoke 完成态与 generating 态互写会瞬态清码
    if (isGenerating || isRevoking) return;
    _set(
      _state.copyWith(
        phase: WorkspaceInviteCodePhase.generating,
        message: '',
        copied: false,
      ),
    );
    try {
      final code = await createInviteCode();
      if (code.isValid) {
        _set(
          WorkspaceInviteCodeState(
            phase: WorkspaceInviteCodePhase.ready,
            inviteCode: code,
          ),
        );
      } else {
        // 契约外空 payload：按失败处理，不伪装成功
        _set(
          _state.copyWith(
            phase: WorkspaceInviteCodePhase.failed,
            message: 'empty invite_code payload',
          ),
        );
      }
    } catch (e) {
      _set(
        _state.copyWith(
          phase: WorkspaceInviteCodePhase.failed,
          message: e.toString(),
        ),
      );
    }
  }

  /// 复制当前码（剪贴板写入动作注入；无码时 no-op）。
  Future<void> copy({
    required Future<void> Function(String code) writeToClipboard,
  }) async {
    final code = _state.inviteCode.code;
    if (code.isEmpty) return;
    try {
      await writeToClipboard(code);
      _set(_state.copyWith(copied: true, message: ''));
    } catch (e) {
      _set(_state.copyWith(copied: false, message: e.toString()));
    }
  }

  /// 撤销当前 active 码（动作注入 revokeInviteCode；成功回 idle 清码）。
  ///
  /// 无码 / 正在生成 / 正在撤销时 no-op；失败留在 ready 并透出消息。
  Future<void> revoke({
    required Future<int> Function() revokeInviteCode,
  }) async {
    if (!hasCode || isGenerating || isRevoking) return;
    _set(
      _state.copyWith(phase: WorkspaceInviteCodePhase.revoking, message: ''),
    );
    try {
      await revokeInviteCode();
      _set(const WorkspaceInviteCodeState());
    } catch (e) {
      _set(
        _state.copyWith(
          phase: WorkspaceInviteCodePhase.ready,
          message: e.toString(),
        ),
      );
    }
  }

  /// 重置（离开页面）。
  void reset() => _set(const WorkspaceInviteCodeState());

  void _set(WorkspaceInviteCodeState next) {
    // 生成/撤销在途时退出页面：dispose 后 notifyListeners 抛
    // FlutterError（debug）/静默写死（release），守卫拦截
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _state = const WorkspaceInviteCodeState();
    super.dispose();
  }
}
