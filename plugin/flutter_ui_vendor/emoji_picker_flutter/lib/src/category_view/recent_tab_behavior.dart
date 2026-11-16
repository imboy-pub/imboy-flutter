/// Behavior of Recent Tab
enum RecentTabBehavior {
  /// Don't show Recent Tab
  none('NONE'),

  /// Display the last used emoji at the top of the list
  recent('RECENT'),

  /// Display the most often used emoji at the top of the list
  popular('POPULAR');

  const RecentTabBehavior(this.name);

  /// Original upstream name retained for existing callers.
  final String name;

  @override
  String toString() => 'RecentTabBehavior.$name';
}
