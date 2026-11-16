import 'text_element.dart';

List<TextElement> firstOccurance(
  List<String> words,
  String text, [
  bool matchCase = true,
]) {
  List<TextElement> result = [UnmatchedElement(text)];
  for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
    final word = words[wordIndex];
    int pointer = 0;
    while (pointer < result.length) {
      final element = result[pointer];
      if (element is UnmatchedElement) {
        final occuranceIndex = matchCase
            ? element.text.indexOf(word)
            : element.text.toLowerCase().indexOf(
                  word.toLowerCase(),
                );
        if (occuranceIndex != -1) {
          final replacements = [
            UnmatchedElement(
              element.text.substring(0, occuranceIndex),
            ),
            MatchedElement(
              matchedIndex: wordIndex,
              originalText: element.text.substring(
                occuranceIndex,
                occuranceIndex + word.length,
              ),
            ),
            UnmatchedElement(
              element.text.substring(occuranceIndex + word.length),
            ),
          ].where((item) =>
              item is MatchedElement ||
              (item as UnmatchedElement).text.isNotEmpty);
          result.replaceRange(pointer, pointer + 1, replacements);
          break;
        }
      }
      pointer++;
    }
  }
  return result;
}

List<TextElement> lastOccurance(
  List<String> words,
  String text, [
  bool matchCase = true,
]) {
  List<TextElement> result = [UnmatchedElement(text)];
  for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
    final word = words[wordIndex];
    int pointer = result.length - 1;
    while (pointer >= 0) {
      final element = result[pointer];
      if (element is UnmatchedElement) {
        final occuranceIndex = matchCase
            ? element.text.lastIndexOf(word)
            : element.text.toLowerCase().lastIndexOf(
                  word.toLowerCase(),
                );
        if (occuranceIndex != -1) {
          final replacements = [
            UnmatchedElement(
              element.text.substring(0, occuranceIndex),
            ),
            MatchedElement(
              matchedIndex: wordIndex,
              originalText: element.text.substring(
                occuranceIndex,
                occuranceIndex + word.length,
              ),
            ),
            UnmatchedElement(
              element.text.substring(occuranceIndex + word.length),
            ),
          ].where((item) =>
              item is MatchedElement ||
              (item as UnmatchedElement).text.isNotEmpty);
          result.replaceRange(pointer, pointer + 1, replacements);
          break;
        }
      }
      pointer--;
    }
  }
  return result;
}

List<TextElement> allOccurance(
  List<String> words,
  String text, [
  bool matchCase = true,
]) {
  List<TextElement> result = [UnmatchedElement(text)];
  for (var wordIndex = 0; wordIndex < words.length; wordIndex++) {
    final word = words[wordIndex];
    int pointer = 0;
    while (pointer < result.length) {
      final element = result[pointer];
      if (element is UnmatchedElement) {
        final occuranceIndex = matchCase
            ? element.text.indexOf(word)
            : element.text.toLowerCase().indexOf(
                  word.toLowerCase(),
                );
        if (occuranceIndex != -1) {
          final replacements = [
            UnmatchedElement(
              element.text.substring(0, occuranceIndex),
            ),
            MatchedElement(
              matchedIndex: wordIndex,
              originalText: element.text.substring(
                occuranceIndex,
                occuranceIndex + word.length,
              ),
            ),
            UnmatchedElement(
              element.text.substring(occuranceIndex + word.length),
            ),
          ].where((item) =>
              item is MatchedElement ||
              (item as UnmatchedElement).text.isNotEmpty);
          result.replaceRange(pointer, pointer + 1, replacements);
        }
      }
      pointer++;
    }
  }
  return result;
}
