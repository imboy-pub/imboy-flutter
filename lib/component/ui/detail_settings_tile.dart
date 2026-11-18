import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/component/ui/flat_list_tile.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Settings and profile details keep full values readable at large text sizes.
class DetailSettingsTile extends StatelessWidget {
  const DetailSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.destructive = false,
  });
  final Widget title;
  final Widget? subtitle, leading, trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  /// 纯文本标题（A11Y-02 AN1 命名素材）；非纯文本标题返回 null。
  Text? get _titleAsText => _plainTextOf(title);

  Text? get _subtitleAsText => _plainTextOf(subtitle);

  static Text? _plainTextOf(Widget? widget) {
    if (widget is Text && widget.data != null) return widget;
    // 注销/登出类 tile 传 Center(child: Text(...))（destructive 居中样式）。
    if (widget is Center) {
      final child = widget.child;
      if (child is Text && child.data != null) return child;
    }
    return null;
  }

  /// 组合可访问名：标题 + 副标题 + 值。仅当标题是纯文本时才接管命名——
  /// 此时被并入名字的可见文本用 ExcludeSemantics 排除，名字以 aria-label
  /// 落到 button 节点（engine 对「有 label 且子树含文本节点」的情况会把
  /// 名字渲染成 DOM textContent 而非 aria-label，即 SET-05/A11Y-02 AN1 的
  /// has_aria_label=false 现象）。非纯文本标题/副标题（如下拉选择器）不
  /// 并名也不排除，保持既有语义结构不冒险。
  String? get _semanticLabel {
    final titleText = _titleAsText?.data;
    if (titleText == null) return null;
    final parts = <String>[
      titleText,
      ?_subtitleAsText?.data,
      ?value,
    ].where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  bool get _takesNaming => _semanticLabel != null;

  /// 仅对被并入名字的纯文本部件做排除；其余（非文本副标题、trailing）
  /// 原样透传，避免吞掉下拉/开关等自身语义。
  Widget _excludeVisibleText(Widget widget, {bool? force}) {
    final exclude = force ?? _takesNaming;
    return exclude ? ExcludeSemantics(child: widget) : widget;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final brightness = Theme.of(context).brightness;
      final style = context.textStyle(FontSizeType.body);
      final stacked = _stackValue(context, constraints.maxWidth, style);
      final detail = value == null
          ? null
          : _excludeVisibleText(
              Text(
                value!,
                style: context.textStyle(
                  FontSizeType.normal,
                  color: AppColors.getTextColor(brightness, isSecondary: true),
                ),
                textAlign: stacked ? TextAlign.start : TextAlign.end,
              ),
            );
      final accessory =
          trailing ?? (onTap == null ? null : const CupertinoListTileChevron());
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: FlatListTile(
          leading: leading,
          leadingGap: AppSpacing.medium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          title: _title(context, style, stacked, detail),
          subtitle: subtitle == null
              ? null
              : _excludeVisibleText(
                  subtitle!,
                  // 非纯文本副标题（下拉/开关等交互件）不排除也不并名。
                  force: _subtitleAsText != null ? null : false,
                ),
          trailing: _accessory(
            constraints.maxWidth,
            stacked,
            detail,
            accessory,
          ),
          onTap: onTap,
          semanticLabel: _semanticLabel,
        ),
      );
    },
  );
  Widget _title(
    BuildContext context,
    TextStyle style,
    bool stacked,
    Widget? detail,
  ) {
    final brightness = Theme.of(context).brightness;
    return DefaultTextStyle.merge(
      style: style.copyWith(
        fontWeight: FontWeight.w400,
        color: destructive
            ? AppColors.getDestructiveText(brightness)
            : AppColors.getTextColor(brightness),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 非 Text 标题时 _takesNaming=false，_excludeVisibleText 原样透传。
          _excludeVisibleText(title),
          if (stacked && detail != null) ...[AppSpacing.verticalTiny, detail],
        ],
      ),
    );
  }

  Widget _accessory(
    double width,
    bool stacked,
    Widget? detail,
    Widget? accessory,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!stacked && detail != null)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * .42),
          child: detail,
        ),
      if (!stacked && detail != null && accessory != null)
        AppSpacing.horizontalSmall,
      ?accessory,
    ],
  );

  bool _stackValue(BuildContext context, double width, TextStyle style) {
    if (value == null) return false;
    final scaler = MediaQuery.textScalerOf(context);
    if (scaler.scale(1) > FontSizeOption.extraLarge.scale) return true;
    final text = title is Text ? (title as Text).data ?? '' : '';
    double measure(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final reserved =
        AppSpacing.regular * 2 +
        (leading == null ? 0 : AppSizes.iconSizeLarge + AppSpacing.medium) +
        (onTap == null && trailing == null ? 0 : AppSizes.touchTarget);
    return measure(text, style) +
            measure(value!, context.textStyle(FontSizeType.normal)) +
            reserved >
        width;
  }
}
