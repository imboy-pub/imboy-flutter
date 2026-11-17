abstract class TextElement {}

class MatchedElement extends TextElement {
  final int matchedIndex;
  final String originalText;

  MatchedElement({
    required this.matchedIndex,
    required this.originalText,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MatchedElement &&
        other.matchedIndex == matchedIndex &&
        other.originalText == originalText;
  }

  @override
  int get hashCode => Object.hash(matchedIndex, originalText);

  @override
  String toString() {
    return 'matchedIndex: $matchedIndex; originalText: $originalText';
  }
}

class UnmatchedElement extends TextElement {
  final String text;

  UnmatchedElement(this.text);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is UnmatchedElement && other.text == text;
  }

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() {
    return 'text: $text';
  }
}
