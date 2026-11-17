import 'package:material_ui/material_ui.dart';

/// Class used to define all the [CategoryIcon] shown for each [Category]
///
/// This allows the keyboard to be personalized by changing icons shown.
/// If a [CategoryIcon] is set as null or not defined during initialization,
/// the default icons will be used instead
class CategoryIcons {
  /// Constructor
  const CategoryIcons({
    this.recentIcon = Icons.access_time,
    this.smileyIcon = Icons.tag_faces,
    this.animalIcon = Icons.pets,
    this.foodIcon = Icons.fastfood,
    this.activityIcon = Icons.directions_run,
    this.travelIcon = Icons.location_city,
    this.objectIcon = Icons.lightbulb_outline,
    this.symbolIcon = Icons.emoji_symbols,
    this.flagIcon = Icons.flag,
  });

  /// Icon for [Category.recent]
  final IconData recentIcon;

  /// Icon for [Category.smileys]
  final IconData smileyIcon;

  /// Icon for [Category.animals]
  final IconData animalIcon;

  /// Icon for [Category.foods]
  final IconData foodIcon;

  /// Icon for [Category.activities]
  final IconData activityIcon;

  /// Icon for [Category.travel]
  final IconData travelIcon;

  /// Icon for [Category.objects]
  final IconData objectIcon;

  /// Icon for [Category.symbols]
  final IconData symbolIcon;

  /// Icon for [Category.flags]
  final IconData flagIcon;
}
