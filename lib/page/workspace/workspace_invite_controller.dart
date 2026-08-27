/// T9 (WP5) — 邀请向导「三条独立结果」控制器（纯逻辑，ChangeNotifier）
///
/// I14 / 计划 §1.4 Template 约定：三种关系分别写入、分别返回结果：
/// 1. 加入 Workspace（成为**工作区成员**）——必须成功，失败则整单失败
/// 2. 加入 General Group（成为**群成员**）——可选、可重试、独立显示结果
/// 3. 订阅 Announcements Channel（成为**频道订阅者**）——可选、可重试、独立显示结果
///
/// 后两项互不影响、不影响第 1 项；任一失败项可单独重试。动作经构造注入
/// （既有 group join / channel subscribe / workspace invite API 由页面装配，
/// 本类只管状态机，可无网络单测）。
library;

import 'package:flutter/foundation.dart';

/// 单条关系的执行状态。
enum WorkspaceRelationPhase { idle, running, success, failed }

/// 单条关系的独立结果。
class WorkspaceRelationResult {
  final WorkspaceRelationPhase phase;
  final String message;

  const WorkspaceRelationResult({this.phase = WorkspaceRelationPhase.idle})
    : message = '';

  const WorkspaceRelationResult._(this.phase, this.message);

  WorkspaceRelationResult copyWith({
    WorkspaceRelationPhase? phase,
    String? message,
  }) => WorkspaceRelationResult._(phase ?? this.phase, message ?? this.message);
}

/// 三条关系的聚合状态。
class WorkspaceInviteRelationsState {
  final WorkspaceRelationResult workspace;
  final WorkspaceRelationResult group;
  final WorkspaceRelationResult channel;

  const WorkspaceInviteRelationsState({
    this.workspace = const WorkspaceRelationResult(),
    this.group = const WorkspaceRelationResult(),
    this.channel = const WorkspaceRelationResult(),
  });

  WorkspaceInviteRelationsState copyWith({
    WorkspaceRelationResult? workspace,
    WorkspaceRelationResult? group,
    WorkspaceRelationResult? channel,
  }) => WorkspaceInviteRelationsState(
    workspace: workspace ?? this.workspace,
    group: group ?? this.group,
    channel: channel ?? this.channel,
  );
}

/// 邀请向导控制器。
///
/// submit 顺序：先邀请（必须成功）；成功后并行发起选中的两条可选关系，
/// 各自独立落结果；失败可重试（retryGroup / retryChannel）。
class WorkspaceInviteResultsController extends ChangeNotifier {
  WorkspaceInviteRelationsState _state = const WorkspaceInviteRelationsState();

  WorkspaceInviteRelationsState get state => _state;

  void _set(WorkspaceInviteRelationsState next) {
    _state = next;
    notifyListeners();
  }

  /// 提交整单：[invite] 必须成功；[joinGroup]/[subscribeChannel] 可空
  /// （未勾选）；后两项失败不影响主结果。
  Future<void> submit({
    required Future<void> Function() invite,
    Future<void> Function()? joinGroup,
    Future<void> Function()? subscribeChannel,
  }) async {
    _set(
      _state.copyWith(
        workspace: const WorkspaceRelationResult(
          phase: WorkspaceRelationPhase.running,
        ),
        group: joinGroup == null
            ? const WorkspaceRelationResult()
            : const WorkspaceRelationResult(
                phase: WorkspaceRelationPhase.running,
              ),
        channel: subscribeChannel == null
            ? const WorkspaceRelationResult()
            : const WorkspaceRelationResult(
                phase: WorkspaceRelationPhase.running,
              ),
      ),
    );
    try {
      await invite();
      _set(
        _state.copyWith(
          workspace: const WorkspaceRelationResult(
            phase: WorkspaceRelationPhase.success,
          ),
        ),
      );
    } catch (e) {
      // 主关系失败：可选两条不再发起（前置关系不存在），保持 idle
      _set(
        _state.copyWith(
          workspace: WorkspaceRelationResult(
            phase: WorkspaceRelationPhase.failed,
          ).copyWith(message: e.toString()),
          group: const WorkspaceRelationResult(),
          channel: const WorkspaceRelationResult(),
        ),
      );
      return;
    }
    // 两条可选关系独立执行：一个失败不影响另一个
    await Future.wait([
      _runOptional(joinGroup, isGroup: true),
      _runOptional(subscribeChannel, isGroup: false),
    ]);
  }

  /// 单独重试「加入 General Group」。
  Future<void> retryGroup(Future<void> Function() joinGroup) =>
      _runOptional(joinGroup, isGroup: true);

  /// 单独重试「订阅 Announcements Channel」。
  Future<void> retryChannel(Future<void> Function() subscribeChannel) =>
      _runOptional(subscribeChannel, isGroup: false);

  Future<void> _runOptional(
    Future<void> Function()? action, {
    required bool isGroup,
  }) async {
    if (action == null) return;
    _set(
      isGroup
          ? _state.copyWith(
              group: const WorkspaceRelationResult(
                phase: WorkspaceRelationPhase.running,
              ),
            )
          : _state.copyWith(
              channel: const WorkspaceRelationResult(
                phase: WorkspaceRelationPhase.running,
              ),
            ),
    );
    try {
      await action();
      _set(
        isGroup
            ? _state.copyWith(
                group: const WorkspaceRelationResult(
                  phase: WorkspaceRelationPhase.success,
                ),
              )
            : _state.copyWith(
                channel: const WorkspaceRelationResult(
                  phase: WorkspaceRelationPhase.success,
                ),
              ),
      );
    } catch (e) {
      _set(
        isGroup
            ? _state.copyWith(
                group: WorkspaceRelationResult(
                  phase: WorkspaceRelationPhase.failed,
                ).copyWith(message: e.toString()),
              )
            : _state.copyWith(
                channel: WorkspaceRelationResult(
                  phase: WorkspaceRelationPhase.failed,
                ).copyWith(message: e.toString()),
              ),
      );
    }
  }

  /// 重置（切换邀请对象时）。
  void reset() => _set(const WorkspaceInviteRelationsState());

  @override
  void dispose() {
    _state = const WorkspaceInviteRelationsState();
    super.dispose();
  }
}
