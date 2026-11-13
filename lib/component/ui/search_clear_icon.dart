import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_sizes.dart';

// CupertinoSearchTextField's Icon-only slot fixes the button to the icon's box.
class SearchClearIcon extends Icon {
  const SearchClearIcon({super.key, super.semanticLabel})
    : super(CupertinoIcons.xmark_circle_fill);

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minWidth: AppSizes.touchTarget,
      minHeight: AppSizes.touchTarget,
    ),
    child: Center(widthFactor: 1, heightFactor: 1, child: super.build(context)),
  );
}
