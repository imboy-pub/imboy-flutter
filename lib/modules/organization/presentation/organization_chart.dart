import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_shadows.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

import '../domain/human_directory_models.dart';
import '../infrastructure/human_directory_api.dart';
import '../infrastructure/organization_api.dart';

/// 仅绘制服务端授权返回的部门；展开时按层分页读取，不预取整棵树。
class OrganizationChart extends StatefulWidget {
  const OrganizationChart({
    super.key,
    required this.accountKey,
    required this.organizationId,
    required this.organizationName,
    required this.source,
    required this.onOpenDepartment,
    this.onAccessDenied,
  });
  final String accountKey;
  final EntityId organizationId;
  final String organizationName;
  final HumanDirectoryDataSource source;
  final ValueChanged<List<HumanDirectoryDepartment>> onOpenDepartment;
  final ValueChanged<OrganizationApiException>? onAccessDenied;

  @override
  State<OrganizationChart> createState() => _OrganizationChartState();
}

class _OrganizationChartState extends State<OrganizationChart> {
  final _transform = TransformationController();
  final _children = <EntityId, List<HumanDirectoryDepartment>>{};
  final _expanded = <EntityId>{''};
  final _loading = <EntityId>{};
  final _errors = <EntityId, String>{};
  String? _fatalError;
  int _generation = 0;
  Size _viewport = Size.zero;
  Size _canvas = Size.zero;

  /// 工具条展开态；收起后为单个百分比胶囊，点击恢复（重进回默认展开）。
  bool _toolbarOpen = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void didUpdateWidget(covariant OrganizationChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountKey != widget.accountKey ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.source != widget.source) {
      _refresh();
    }
  }

  void _refresh() {
    _generation++;
    _children.clear();
    _expanded
      ..clear()
      ..add('');
    _loading.clear();
    _errors.clear();
    _fatalError = null;
    _transform.value = Matrix4.identity();
    _load('');
  }

  Future<void> _load(EntityId parent) async {
    if (_loading.contains(parent) || widget.accountKey.isEmpty) return;
    final generation = _generation;
    setState(() {
      _loading.add(parent);
      _errors.remove(parent);
    });
    try {
      final rows = <EntityId, HumanDirectoryDepartment>{};
      final cursors = <String>{};
      String? cursor;
      do {
        final page = await widget.source.directoryDepartments(
          organizationId: widget.organizationId,
          parentId: parent.isEmpty ? null : parent,
          cursor: cursor,
          limit: 100,
        );
        if (!mounted || generation != _generation) return;
        for (final row in page.list) {
          if (row.id.isNotEmpty && row.id != parent && row.parentId == parent) {
            rows[row.id] = row;
          }
        }
        cursor = page.cursor;
        if (cursor != null && !cursors.add(cursor)) {
          throw StateError('Repeated directory cursor');
        }
      } while (cursor != null);
      setState(() {
        _children[parent] = rows.values.toList();
      });
      if (parent.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _generation) _fit(minimum: .5);
        });
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        if (error is OrganizationApiException &&
            (error.code == 403 || error.code == 404)) {
          _generation++;
          _children.clear();
          _expanded.clear();
          _loading.clear();
          _errors.clear();
          _fatalError = t.organization.common.forbidden403;
        } else {
          _errors[parent] = t.common.errorNetwork;
        }
      });
      if (error is OrganizationApiException &&
          (error.code == 403 || error.code == 404)) {
        widget.onAccessDenied?.call(error);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading.remove(parent);
        });
      }
    }
  }

  void _toggle(EntityId id) {
    if (_errors.containsKey(id)) {
      _load(id);
      return;
    }
    setState(() {
      _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id);
    });
    if (_expanded.contains(id) && !_children.containsKey(id)) _load(id);
  }

  double get _fitScale {
    if (_viewport.isEmpty || _canvas.isEmpty) return 1;
    final horizontal =
        (_viewport.width - AppSpacing.regular * 2) / _canvas.width;
    final vertical =
        (_viewport.height - AppSpacing.regular * 2) / _canvas.height;
    return (horizontal < vertical ? horizontal : vertical)
        .clamp(.0001, 1.0)
        .toDouble();
  }

  double get _minimumScale => _fitScale < .05 ? _fitScale : .05;

  void _fit({double minimum = 0}) {
    if (_viewport.isEmpty || _canvas.isEmpty) return;
    final fitted = _fitScale.clamp(minimum, 1.0).toDouble();
    _transform.value = Matrix4.diagonal3Values(fitted, fitted, 1)
      ..setTranslationRaw(
        (_viewport.width - _canvas.width * fitted) / 2,
        AppSpacing.regular,
        0,
      );
  }

  void _zoom(double factor) {
    final old = _transform.value;
    final scale = old.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(_minimumScale, 4.0).toDouble();
    final ratio = next / scale;
    _transform.value = Matrix4.diagonal3Values(next, next, 1)
      ..setTranslationRaw(
        old.storage[12] * ratio + _viewport.width / 2 * (1 - ratio),
        old.storage[13] * ratio + _viewport.height / 2 * (1 - ratio),
        0,
      );
  }

  @override
  void dispose() {
    _generation++;
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) return Center(child: Text(_fatalError!));
    if (widget.accountKey.isEmpty) return const SizedBox.shrink();
    final factor =
        (MediaQuery.textScalerOf(context).scale(FontSizeType.normal.size) /
                FontSizeType.normal.size)
            .clamp(1.0, 4.0);
    final layout = organizationChartLayout(
      _children,
      _expanded,
      nodeSize: Size(
        AppSpacing.xxxLarge * 4 * factor,
        (AppSpacing.xxxLarge + AppSpacing.xxLarge) * factor,
      ),
    );
    _canvas = layout.size;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewport = constraints.biggest;
              return Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: colors.surfaceContainerLow,
                      child: LayoutBuilder(
                        builder: (context, _) {
                          return InteractiveViewer(
                            key: const ValueKey('org-chart-canvas'),
                            transformationController: _transform,
                            constrained: false,
                            minScale: _minimumScale,
                            maxScale: 4,
                            trackpadScrollCausesScale: true,
                            boundaryMargin: EdgeInsets.all(
                              AppSpacing.xxxLarge * 4,
                            ),
                            child: SizedBox(
                              width: layout.size.width,
                              height: layout.size.height,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _ChartLines(
                                        layout,
                                        colors.outline,
                                      ),
                                    ),
                                  ),
                                  for (final entry in layout.nodes.entries)
                                    Positioned.fromRect(
                                      rect: entry.value.rect,
                                      child: _node(
                                        context,
                                        entry.key,
                                        entry.value.path,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // 悬浮可拖拽工具条（对标地图/白板类缩放控件）：默认
                  // 右下，可拖至视口内任意位置；支持收起为百分比胶囊，
                  // 不再占用布局行——画布占满全高（DESIGN.md 原则 2）。
                  _FloatingChartToolbar(
                    viewport: _viewport,
                    child: _toolbarOpen
                        ? _toolbar(context)
                        : _collapsedToolbar(context),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: AppSpacing.allSmall,
          child: Text(
            t.organization.chart.gestureHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// 工具条表面（底色 + 描边 + 圆角），展开/收起两态共用同一外观。
  Widget _toolbarSurface(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.regular),
      ),
      child: child,
    );
  }

  Widget _toolbar(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      child: _toolbarSurface(
        context,
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              key: const ValueKey('org-chart-zoom-out'),
              tooltip: t.organization.chart.zoomOut,
              onPressed: () => _zoom(1 / 1.25),
              icon: const Icon(CupertinoIcons.minus),
            ),
            IconButton(
              key: const ValueKey('org-chart-zoom-in'),
              tooltip: t.organization.chart.zoomIn,
              onPressed: () => _zoom(1.25),
              icon: const Icon(CupertinoIcons.plus),
            ),
            ListenableBuilder(
              listenable: _transform,
              builder: (context, _) => SizedBox(
                width: AppSpacing.xxxLarge,
                child: Center(
                  child: Text(
                    '${(_transform.value.getMaxScaleOnAxis() * 100).toStringAsFixed(_transform.value.getMaxScaleOnAxis() < .1 ? 1 : 0)}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('org-chart-fit'),
              tooltip: t.organization.chart.fit,
              onPressed: _fit,
              icon: const Icon(CupertinoIcons.arrow_up_left_arrow_down_right),
            ),
            IconButton(
              tooltip: t.organization.common.reload,
              onPressed: _refresh,
              icon: const Icon(CupertinoIcons.refresh),
            ),
            // 收起为百分比胶囊（地图/白板类标配）；点胶囊恢复。
            IconButton(
              key: const ValueKey('org-chart-toolbar-collapse'),
              tooltip: t.common.collapse,
              onPressed: () => setState(() => _toolbarOpen = false),
              icon: const Icon(CupertinoIcons.chevron_down),
            ),
          ],
        ),
      ),
    );
  }

  /// 收起态：单个百分比胶囊，点击展开完整工具条；缩放时实时刷新读数。
  Widget _collapsedToolbar(BuildContext context) {
    return ListenableBuilder(
      listenable: _transform,
      builder: (context, _) {
        final scale = _transform.value.getMaxScaleOnAxis();
        final label = '${(scale * 100).toStringAsFixed(scale < .1 ? 1 : 0)}%';
        return Semantics(
          button: true,
          label: t.common.expandFull,
          child: GestureDetector(
            key: const ValueKey('org-chart-toolbar-collapsed'),
            onTap: () => setState(() => _toolbarOpen = true),
            behavior: HitTestBehavior.opaque,
            child: _toolbarSurface(
              context,
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _node(
    BuildContext context,
    EntityId id,
    List<HumanDirectoryDepartment> path,
  ) {
    final department = path.isEmpty ? null : path.last;
    final label =
        department?.name ??
        (widget.organizationName.isEmpty
            ? t.organization.home.tabOrg
            : widget.organizationName);
    final colors = Theme.of(context).colorScheme;
    final loading = _loading.contains(id);
    final failed = _errors.containsKey(id);
    final canExpand = !_children.containsKey(id) || _children[id]!.isNotEmpty;
    return Container(
      key: ValueKey('org-chart-node-$id'),
      decoration: BoxDecoration(
        color: path.isEmpty
            ? colors.primaryContainer
            : colors.surfaceContainerLowest,
        border: Border.all(
          color: path.isEmpty ? colors.primary : colors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      padding: AppSpacing.allSmall,
      child: Row(
        children: [
          if (path.isEmpty) ...[
            Icon(
              CupertinoIcons.building_2_fill,
              color: colors.onPrimaryContainer,
              size: AppSpacing.xLarge,
            ),
            AppSpacing.horizontalSmall,
          ],
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: department == null
                  ? null
                  : () => widget.onOpenDepartment(path),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: label,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: path.isEmpty
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                  ),
                  if (department != null)
                    Text(
                      t.organization.chart.directMembers(
                        count: department.memberCount,
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: AppSpacing.xLarge,
              height: AppSpacing.xLarge,
              child: CupertinoActivityIndicator(),
            )
          else if (failed || canExpand)
            IconButton(
              key: ValueKey('org-chart-expand-$id'),
              tooltip: failed
                  ? t.organization.common.reload
                  : _expanded.contains(id)
                  ? t.organization.departments.collapseNode(name: label)
                  : t.organization.departments.expandNode(name: label),
              color: path.isEmpty
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
              onPressed: () => _toggle(id),
              icon: Icon(
                failed
                    ? CupertinoIcons.refresh
                    : _expanded.contains(id)
                    ? CupertinoIcons.minus_circle
                    : CupertinoIcons.plus_circle,
              ),
            ),
        ],
      ),
    );
  }
}

typedef OrganizationChartPlacement = ({
  Rect rect,
  List<HumanDirectoryDepartment> path,
});

/// 仅对已展开的节点计算位置；节点始终等宽，兄弟子树不重叠。
({Size size, Map<EntityId, OrganizationChartPlacement> nodes})
organizationChartLayout(
  Map<EntityId, List<HumanDirectoryDepartment>> children,
  Set<EntityId> expanded, {
  Size nodeSize = const Size(
    AppSpacing.xxxLarge * 4,
    AppSpacing.xxxLarge + AppSpacing.xxLarge,
  ),
}) {
  final width = nodeSize.width;
  final height = nodeSize.height;
  const gap = AppSpacing.xLarge;
  final widths = <EntityId, double>{};
  final measured = <EntityId>{};
  double measure(EntityId id) {
    if (!measured.add(id)) return width;
    final rows = expanded.contains(id)
        ? children[id] ?? []
        : <HumanDirectoryDepartment>[];
    final total =
        rows.fold<double>(0, (value, row) => value + measure(row.id)) +
        (rows.isEmpty ? 0 : (rows.length - 1) * gap);
    return widths[id] = total > width ? total : width;
  }

  final totalWidth = measure('') + gap * 2;
  final nodes = <EntityId, OrganizationChartPlacement>{};
  double bottom = 0;
  void place(
    EntityId id,
    double left,
    int depth,
    List<HumanDirectoryDepartment> path,
  ) {
    if (nodes.containsKey(id)) return;
    final rect = Rect.fromLTWH(
      left + ((widths[id] ?? width) - width) / 2,
      gap + depth * (height + AppSpacing.xxxLarge),
      width,
      height,
    );
    nodes[id] = (rect: rect, path: path);
    if (rect.bottom > bottom) bottom = rect.bottom;
    if (!expanded.contains(id)) return;
    for (final row in children[id] ?? <HumanDirectoryDepartment>[]) {
      place(row.id, left, depth + 1, [...path, row]);
      left += (widths[row.id] ?? width) + gap;
    }
  }

  place('', gap, 0, []);
  return (size: Size(totalWidth, bottom + gap), nodes: nodes);
}

class _ChartLines extends CustomPainter {
  const _ChartLines(this.layout, this.color);
  final ({Size size, Map<EntityId, OrganizationChartPlacement> nodes}) layout;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final node in layout.nodes.values) {
      if (node.path.isEmpty) continue;
      final parent = node.path.length == 1
          ? ''
          : node.path[node.path.length - 2].id;
      final source = layout.nodes[parent]?.rect.bottomCenter;
      if (source == null) continue;
      final target = node.rect.topCenter;
      final middle = (source.dy + target.dy) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(source.dx, source.dy)
          ..lineTo(source.dx, middle)
          ..lineTo(target.dx, middle)
          ..lineTo(target.dx, target.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartLines oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.color != color;
}

/// 悬浮可拖拽工具条容器（对标地图/白板类缩放控件）。
///
/// - 默认吸附右下角（[AppSpacing.regular] 边距）；拖动后按指针轨迹平移，
///   自动 clamp 在视口内（拖不出去也不遮挡不到的地方）。
/// - 浮层视觉：surface 容器底 + 描边 + [AppShadows.cardForBrightness]
///   极淡投影（DESIGN.md 5.2 浮层允许的唯二投影场景）。
/// - 手势：外层 pan 与内层按钮 tap 在手势竞技场自然分流——原地点击按钮
///   生效，移动超过 slop 才进入拖拽，互不误触；底层画布（InteractiveViewer）
///   不会收到穿透事件。
/// - 位置是页面级状态（重进回默认右下），不做持久化；child 由宿主在
///   展开/收起两态间切换，本容器只负责拖拽与定位。
class _FloatingChartToolbar extends StatefulWidget {
  const _FloatingChartToolbar({required this.viewport, required this.child});

  /// 宿主 Stack 的可用区域（用于 clamp），窗口 resize 时随 build 更新。
  final Size viewport;
  final Widget child;

  @override
  State<_FloatingChartToolbar> createState() => _FloatingChartToolbarState();
}

class _FloatingChartToolbarState extends State<_FloatingChartToolbar> {
  final GlobalKey _barKey = GlobalKey();

  /// null = 未拖过，保持默认右下吸附。
  Offset? _dragPos;

  Size get _barSize =>
      (_barKey.currentContext?.findRenderObject() as RenderBox?)?.size ??
      Size.zero;

  /// 把默认「右下角」换算成绝对坐标（首次拖动时锚定）。树向下生长、
  /// 根节点恒在画布顶部居中——右上是根的地盘，右下在浅树/深树时都是
  /// 空白区，与地图/白板类缩放控件的默认位一致。
  Offset get _defaultPos => Offset(
    widget.viewport.width - _barSize.width - AppSpacing.regular,
    widget.viewport.height - _barSize.height - AppSpacing.regular,
  );

  Offset _clamp(Offset next) {
    final size = _barSize;
    return Offset(
      next.dx.clamp(0.0, (widget.viewport.width - size.width).clamp(0, 1e9)),
      next.dy.clamp(0.0, (widget.viewport.height - size.height).clamp(0, 1e9)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // resize 后视口变小可能让已存位置越界，build 期收一次边界。
    final pos = _dragPos == null ? null : _clamp(_dragPos!);
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.regular),
        boxShadow: AppShadows.cardForBrightness(
          isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      child: KeyedSubtree(
        key: _barKey,
        child: GestureDetector(
          onPanUpdate: (details) => setState(
            () => _dragPos = _clamp((_dragPos ?? _defaultPos) + details.delta),
          ),
          behavior: HitTestBehavior.opaque,
          child: widget.child,
        ),
      ),
    );
    // 默认态用右/下锚（右下角）；拖过后切左/上锚，展开↔收起切换时
    // 尺寸变化由 build 期 clamp 收回视口内。
    return Positioned(
      left: pos?.dx,
      top: pos?.dy,
      right: pos == null ? AppSpacing.regular : null,
      bottom: pos == null ? AppSpacing.regular : null,
      child: bar,
    );
  }
}
