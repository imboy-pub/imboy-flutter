import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// Template class for custom implementation
/// Inhert this class to create your own Category view
abstract class CategoryView extends StatefulWidget {
  /// Constructor
  const CategoryView(
    this.config,
    this.state,
    this.tabController,
    this.pageController, {
    super.key,
  });

  /// Config for customizations
  final Config config;

  /// State that holds current emoji data
  final EmojiViewState state;

  /// TabController for Category view
  final TabController tabController;

  /// Page Controller of Emoji view
  final PageController pageController;
}

/// Returns the icon for the category
IconData getIconForCategory(CategoryIcons categoryIcons, Category category) {
  switch (category) {
    case Category.recent:
      return categoryIcons.recentIcon;
    case Category.smileys:
      return categoryIcons.smileyIcon;
    case Category.animals:
      return categoryIcons.animalIcon;
    case Category.foods:
      return categoryIcons.foodIcon;
    case Category.travel:
      return categoryIcons.travelIcon;
    case Category.activities:
      return categoryIcons.activityIcon;
    case Category.objects:
      return categoryIcons.objectIcon;
    case Category.symbols:
      return categoryIcons.symbolIcon;
    case Category.flags:
      return categoryIcons.flagIcon;
  }
}

/// Template class for custom implementation
/// Inhert this class to create your own category view state
class CategoryViewState<T extends CategoryView> extends State<T>
    with SkinToneOverlayStateMixin {
  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('Category View implementation missing');
  }
}
