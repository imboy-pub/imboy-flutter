import 'highlighted_word.dart';

// sort words by length,
// so that we process longer words first in binding
// empty words are removed to prevent infinite loops
List<MapEntry<String, HighlightedWord>> sortAndFilterWords(
    List<MapEntry<String, HighlightedWord>> words) {
  return words
    ..sort(
      (a, b) => b.key.length.compareTo(a.key.length),
    )
    ..removeWhere((entry) => entry.key.trim().isEmpty);
}
