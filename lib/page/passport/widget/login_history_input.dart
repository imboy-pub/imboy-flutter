import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

class LoginHistoryInput extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final List<String> historyList;
  final void Function(String) onSelect;
  final void Function(String) onDelete;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;

  const LoginHistoryInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.historyList,
    required this.onSelect,
    required this.onDelete,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<LoginHistoryInput> createState() => _LoginHistoryInputState();
}

class _LoginHistoryInputState extends State<LoginHistoryInput> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Option: Show history when focused?
        // For now, we only show when clicking the dropdown arrow.
      } else {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_overlayEntry == null) {
      if (widget.historyList.isNotEmpty) {
        _overlayEntry = _createOverlayEntry();
        Overlay.of(context).insert(_overlayEntry!);
      }
    } else {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceContainer
                : AppColors.lightSurface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: widget.historyList.length,
                itemBuilder: (context, index) {
                  final item = widget.historyList[index];
                  return ListTile(
                    title: Text(item),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.iosGray,
                      ),
                      tooltip: t.common.buttonDelete,
                      onPressed: () {
                        widget.onDelete(item);
                        // Refresh overlay if needed, or close it
                        _removeOverlay();
                        // Re-open if list not empty?
                        // Simplified: just close for now or let parent rebuild handle it
                      },
                    ),
                    onTap: () {
                      widget.onSelect(item);
                      widget.controller.text = item;
                      _removeOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurface;
    final borderDefault = isDark ? AppColors.darkBorder : AppColors.iosGray5;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(widget.prefixIcon, color: AppColors.primary),
          suffixIcon:
              widget.suffixIcon ??
              (widget.historyList.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.arrow_drop_down),
                      tooltip: t.passport.loginHistoryToggle,
                      onPressed: _toggleOverlay,
                    )
                  : null),
          filled: true,
          fillColor: inputFill,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderDefault),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
