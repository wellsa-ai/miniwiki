/// Extracts wikilinks ([[target]]) from markdown text.
/// Returns a list of target note titles.
List<String> extractWikilinks(String text) {
  final regex = RegExp(r'\[\[([^\]]+)\]\]');
  return regex.allMatches(text).map((m) => m.group(1)!.trim()).toList();
}

/// Extracts hashtags (#tag) from markdown text.
/// Returns a list of tag names (without #).
List<String> extractHashtags(String text) {
  final regex = RegExp(r'(?<!\w)#([a-zA-Z가-힣0-9_\-]+)');
  return regex.allMatches(text).map((m) => m.group(1)!).toList();
}

/// Replaces [[wikilink]] with markdown links.
/// Used when rendering markdown for display.
String wikilinkToMarkdown(String text, Map<String, String> titleToId) {
  return text.replaceAllMapped(
    RegExp(r'\[\[([^\]]+)\]\]'),
    (match) {
      final title = match.group(1)!.trim();
      final id = titleToId[title];
      if (id != null) {
        return '[$title](miniwiki://note/$id)';
      }
      return '[$title](miniwiki://new?title=${Uri.encodeComponent(title)})';
    },
  );
}
