/// Behavior of extra tab
enum CategoryExtraTab {
  /// Don't show extra tab
  none('NONE'),

  /// Display backspace button in tab bar
  backspace('BACKSPACE'),

  /// Display search button in tab bar
  search('SEARCH');

  const CategoryExtraTab(this.name);

  /// Original upstream name retained for existing callers.
  final String name;

  @override
  String toString() => 'CategoryExtraTab.$name';
}
