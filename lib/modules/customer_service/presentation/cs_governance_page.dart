/// 企业自助客服治理页（CS-APP-03 / CS-GOV-02B）。
///
/// 面向已登录 Flutter Organization 的 owner/admin 治理区：
/// - 席位额度事实（seat_limit n|unlimited + used 服务端现算）与自助调整
///   （PUT /seat-limit，走租户 Human JWT API——本页不触碰 /api/adm 平台
///   面，也不消费 Seat JWT 专属端点）；
/// - 坐席席位列表（enabled / max_concurrent / active_count 投影）与
///   suspend/resume 启停治理；
/// - widget 治理：tenant API 未提供只读 widget 治理端点（widget 面是
///   访客 bootstrap 令牌面），本页不伪装提供该能力。
///
/// 验收口径（CS-GOV-02B）：
/// - 权限负例：403（governance_insufficient）渲染权限终态文案，诚实
///   展示、不伪装成空列表；入口侧由组织详情页 PermissionGate 对 member
///   整区隐藏（服务端 403 仍是唯一裁决）；
/// - 冲突可解释：seat_limit_exceeded / invalid_seat_limit 按 envelope tag
///   分型为可解释文案（服务端 wire message 同时透出）；
/// - 切换 Organization 无陈旧数据：页面按 orgId 参数化，didUpdateWidget
///   检测 orgId 变化即失效重建（清空额度/列表/分页游标后重拉）；
/// - TSID lossless：identity/org id 全链 String（entityIdOf）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/modules/customer_service/infrastructure/cs_governance_api.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 治理页错误在页面上的呈现分型（镜像 org_async_state 契约：403 权限
/// 终态无重试；其余错误 wire message 优先 + 重试）。
class CsGovernanceErrorUi {
  const CsGovernanceErrorUi({this.permissionDenied = false, this.text = ''});

  final bool permissionDenied;
  final String text;
}

/// 错误 → UI 状态映射：页面/动作反馈共用（不自行解析错误字符串）。
CsGovernanceErrorUi csGovernanceErrorToUi(Object error, Translations t) {
  final gov = t.customerService.governance;
  if (error is CsGovernanceApiException) {
    if (error.isForbidden) {
      return CsGovernanceErrorUi(
        permissionDenied: true,
        text: gov.errorForbidden,
      );
    }
    return CsGovernanceErrorUi(
      text: gov.errorWithCode(msg: error.message, code: error.code),
    );
  }
  return CsGovernanceErrorUi(text: error.toString());
}

/// 客服治理页（/customer_service/governance/:orgId）。
class CsGovernancePage extends StatefulWidget {
  const CsGovernancePage({super.key, required this.orgId});

  final EntityId orgId;

  @override
  State<CsGovernancePage> createState() => _CsGovernancePageState();
}

class _CsGovernancePageState extends State<CsGovernancePage> {
  final CsGovernanceApi _api = CsGovernanceApi();
  final TextEditingController _limitInput = TextEditingController();

  CsSeatLimitView? _limit;
  List<CsGovernanceSeatRow> _seats = const <CsGovernanceSeatRow>[];
  String _nextAfterId = '';
  bool _loading = false;
  bool _loadingMore = false;
  int _scopeEpoch = 0;
  int _readGeneration = 0;

  /// 原始异常（catch 直传，分型交给 [csGovernanceErrorToUi]）。
  Object? _errorObj;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(CsGovernancePage old) {
    super.didUpdateWidget(old);
    // 切换 Organization 失效重建：orgId 变化即丢弃全部旧 Org 治理数据
    // （额度/列表/游标/错误态），按新 orgId 重新拉取——不残留陈旧事实。
    if (old.orgId != widget.orgId) {
      _scopeEpoch++;
      _resetState();
      _refresh();
    }
  }

  @override
  void dispose() {
    _limitInput.dispose();
    super.dispose();
  }

  void _resetState() {
    _limit = null;
    _seats = const <CsGovernanceSeatRow>[];
    _nextAfterId = '';
    _errorObj = null;
  }

  bool _currentScope(EntityId orgId, int epoch) =>
      mounted && widget.orgId == orgId && _scopeEpoch == epoch;

  bool _currentRead(EntityId orgId, int epoch, int generation) =>
      _currentScope(orgId, epoch) && _readGeneration == generation;

  Future<void> _refresh() async {
    final orgId = widget.orgId;
    final epoch = _scopeEpoch;
    final generation = ++_readGeneration;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _errorObj = null;
    });
    try {
      final limit = await _api.seatLimitView(orgId);
      if (!_currentRead(orgId, epoch, generation)) return;
      final page = await _api.seatsPage(orgId);
      if (!_currentRead(orgId, epoch, generation)) return;
      setState(() {
        _limit = limit;
        _seats = page.rows;
        _nextAfterId = page.nextAfterId;
      });
    } on Object catch (e) {
      if (!_currentRead(orgId, epoch, generation)) return;
      setState(() {
        _resetState();
        _errorObj = e;
      });
    } finally {
      if (_currentRead(orgId, epoch, generation)) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _nextAfterId.isEmpty) return;
    final orgId = widget.orgId;
    final epoch = _scopeEpoch;
    final generation = _readGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.seatsPage(orgId, afterId: _nextAfterId);
      if (!_currentRead(orgId, epoch, generation)) return;
      setState(() {
        _seats = [..._seats, ...page.rows];
        _nextAfterId = page.nextAfterId;
      });
    } on Object catch (e) {
      if (_currentRead(orgId, epoch, generation)) _showError(e);
    } finally {
      if (_currentRead(orgId, epoch, generation)) {
        setState(() => _loadingMore = false);
      }
    }
  }

  // ==================== 渲染 ====================

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService.governance;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final error = _errorObj;
    if (_loading && _limit == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_errorTile(error)],
      );
    }
    final limit = _limit;
    if (limit == null) {
      return const SizedBox.shrink();
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      children: [
        _scopeNote(),
        _LimitCard(view: limit, onAdjust: () => _showLimitDialog(context)),
        const Divider(),
        _seatsSection(),
      ],
    );
  }

  Widget _scopeNote() {
    final t = context.t.customerService.governance;
    return ListTile(
      key: const ValueKey('cs-governance-scope-note'),
      dense: true,
      leading: const Icon(CupertinoIcons.info),
      title: Text(t.scopeNote, style: context.textStyle(FontSizeType.footnote)),
    );
  }

  Widget _errorTile(Object error) {
    final t = context.t.customerService.governance;
    final ui = csGovernanceErrorToUi(error, context.t);
    return ListTile(
      key: const ValueKey('cs-governance-error'),
      leading: Icon(
        ui.permissionDenied
            ? CupertinoIcons.lock
            : CupertinoIcons.exclamationmark_triangle,
      ),
      title: Text(
        ui.permissionDenied
            ? t.errorForbidden
            : '${t.errorLoadFailed}：${ui.text}',
      ),
      trailing: ui.permissionDenied
          ? null
          : TextButton(
              key: const ValueKey('cs-governance-retry'),
              onPressed: _refresh,
              child: Text(t.retry),
            ),
    );
  }

  Widget _seatsSection() {
    final t = context.t.customerService.governance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.small,
          ),
          child: Text(
            t.seatsSectionTitle,
            style: context.textStyle(
              FontSizeType.large,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_seats.isEmpty)
          ListTile(
            key: const ValueKey('cs-governance-seats-empty'),
            title: Text(t.seatsEmpty),
          )
        else
          for (final row in _seats) _seatTile(row),
        if (_nextAfterId.isNotEmpty)
          ListTile(
            key: const ValueKey('cs-governance-seats-more'),
            enabled: !_loading && !_loadingMore,
            title: Text(t.seatLoadMore),
            trailing: _loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _loading || _loadingMore ? null : _loadMore,
          ),
      ],
    );
  }

  Widget _seatTile(CsGovernanceSeatRow row) {
    final t = context.t.customerService.governance;
    return ListTile(
      key: ValueKey('cs-governance-seat-${row.businessIdentityId}'),
      leading: Icon(
        row.enabled
            ? CupertinoIcons.person_crop_circle_badge_checkmark
            : CupertinoIcons.nosign,
        color: row.enabled ? AppColors.iosGreen : AppColors.iosGray,
      ),
      title: Text(
        t.seatIdentityLabel(identity: row.businessIdentityId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          row.enabled ? t.seatEnabledBadge : t.seatSuspendedBadge,
          t.seatCapacityLabel(active: row.activeCount, max: row.maxConcurrent),
        ].join(' · '),
      ),
      trailing: TextButton(
        key: ValueKey('cs-governance-seat-action-${row.businessIdentityId}'),
        onPressed: row.enabled
            ? () => _confirmSuspend(row)
            : () => _resume(row),
        child: Text(row.enabled ? t.suspendAction : t.resumeAction),
      ),
    );
  }

  // ==================== 动作 ====================

  Future<void> _showLimitDialog(BuildContext context) async {
    final orgId = widget.orgId;
    final epoch = _scopeEpoch;
    _limitInput.text = _limit?.limitValue?.toString() ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _LimitDialog(controller: _limitInput),
    );
    if (value == null || !_currentScope(orgId, epoch)) return;
    await _applyLimitValue(value.trim());
  }

  Future<void> _applyLimitValue(String raw) async {
    final orgId = widget.orgId;
    final epoch = _scopeEpoch;
    final t = context.t.customerService.governance;
    final parsed = int.tryParse(raw);
    if (raw.isNotEmpty && (parsed == null || parsed < 1)) {
      _snack(t.limitInvalidInput);
      return;
    }
    try {
      final view = await _api.setSeatLimit(orgId, raw.isEmpty ? null : parsed);
      if (!_currentScope(orgId, epoch)) return;
      setState(() => _limit = view);
      _snack(t.limitSaved);
    } on Object catch (e) {
      if (_currentScope(orgId, epoch)) _showError(e);
    }
  }

  Future<void> _confirmSuspend(CsGovernanceSeatRow row) async {
    final orgId = widget.orgId;
    final epoch = _scopeEpoch;
    final t = context.t.customerService.governance;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.suspendConfirmTitle),
        content: Text(t.suspendConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t.common.buttonCancel),
          ),
          TextButton(
            key: const ValueKey('cs-governance-suspend-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.suspendAction),
          ),
        ],
      ),
    );
    if (ok != true || !_currentScope(orgId, epoch)) return;
    await _runSeatAction(() => _api.suspendSeat(orgId, row.businessIdentityId));
  }

  Future<void> _resume(CsGovernanceSeatRow row) async {
    await _runSeatAction(
      () => _api.resumeSeat(widget.orgId, row.businessIdentityId),
    );
  }

  Future<void> _runSeatAction(Future<void> Function() action) async {
    final orgId = widget.orgId;
    final epoch = _scopeEpoch;
    final t = context.t.customerService.governance;
    try {
      await action();
      if (!_currentScope(orgId, epoch)) return;
      _snack(t.actionDone);
      await _refresh();
    } on Object catch (e) {
      if (_currentScope(orgId, epoch)) _showError(e);
    }
  }

  /// 动作失败反馈：seat_limit_exceeded 给可解释文案（含当前额度事实）；
  /// 403 给权限文案；其余透传 wire message（展示即事实，不伪装成功）。
  void _showError(Object error) {
    final t = context.t.customerService.governance;
    if (error is CsGovernanceApiException && error.isSeatLimitExceeded) {
      final limit = _limit;
      _snack(
        t.seatLimitExceededHint(
          used: limit?.used ?? 0,
          limit: limit?.limitValue ?? 0,
        ),
      );
      return;
    }
    final ui = csGovernanceErrorToUi(error, context.t);
    _snack(ui.permissionDenied ? t.errorForbidden : ui.text);
  }

  void _snack(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }
}

/// 额度事实卡（服务端事实只读呈现 + 调整入口）。
class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.view, required this.onAdjust});

  final CsSeatLimitView view;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService.governance;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.limitCardTitle,
                    style: context.textStyle(
                      FontSizeType.large,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('cs-governance-limit-adjust'),
                  onPressed: onAdjust,
                  child: Text(t.limitAdjustAction),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              view.isUnlimited
                  ? t.limitUnlimited
                  : t.limitValueLabel(
                      used: view.used,
                      limit: view.limitValue ?? 0,
                    ),
              key: const ValueKey('cs-governance-limit-value'),
              style: context.textStyle(FontSizeType.largeTitle),
            ),
            if (view.isAtCapacity)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.tiny),
                child: Text(
                  t.limitAtCapacity,
                  key: const ValueKey('cs-governance-limit-at-capacity'),
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 调整额度对话框：正整数 = 配置上限；留空 = 清除（→ unlimited）。
class _LimitDialog extends StatelessWidget {
  const _LimitDialog({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService.governance;
    return AlertDialog(
      title: Text(t.limitAdjustTitle),
      content: TextField(
        key: const ValueKey('cs-governance-limit-input'),
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: t.limitInputLabel,
          suffixIcon: IconButton(
            key: const ValueKey('cs-governance-limit-clear'),
            tooltip: t.limitClearAction,
            icon: const Icon(CupertinoIcons.clear),
            onPressed: controller.clear,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.common.buttonCancel),
        ),
        TextButton(
          key: const ValueKey('cs-governance-limit-save'),
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(t.limitAdjustAction),
        ),
      ],
    );
  }
}
