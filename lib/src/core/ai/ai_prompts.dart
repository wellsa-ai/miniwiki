/// Prompt templates for on-device LLM (Qwen2.5-1.5B-Instruct).
///
/// All prompts follow the ChatML format expected by the Qwen model:
/// <|im_start|>system\n...<|im_end|>\n<|im_start|>user\n...<|im_end|>\n<|im_start|>assistant\n
library;

class AiPrompts {
  AiPrompts._();

  /// Build a tag-suggestion prompt.
  ///
  /// Returns a ChatML-formatted prompt that asks the model to extract
  /// 3-5 relevant tags from the given note [title] and [content].
  static String tagSuggestion({
    required String title,
    required String content,
    List<String> existingTags = const [],
  }) {
    final existingSection = existingTags.isNotEmpty
        ? '\nExisting tags in wiki: ${existingTags.join(", ")}'
        : '';

    return '''<|im_start|>system
You are a personal wiki assistant. Extract 3-5 relevant tags from the note.
Reply ONLY with a JSON object: {"tags": ["tag1", "tag2", ...]}
Prefer reusing existing tags when they fit.$existingSection<|im_end|>
<|im_start|>user
Title: $title
Content: $content<|im_end|>
<|im_start|>assistant
''';
  }

  /// Build a category-classification prompt.
  ///
  /// Returns a ChatML-formatted prompt that classifies the note into one
  /// of the provided [categories].
  static String classifyNote({
    required String title,
    required String content,
    List<String> categories = const [
      'personal',
      'work',
      'study',
      'project',
      'reference',
      'journal',
      'idea',
    ],
  }) {
    final cats = categories.join(', ');
    return '''<|im_start|>system
You are a personal wiki assistant. Classify the note into exactly one category.
Available categories: $cats
Reply ONLY with a JSON object: {"category": "chosen_category"}<|im_end|>
<|im_start|>user
Title: $title
Content: $content<|im_end|>
<|im_start|>assistant
''';
  }

  /// Build a connection-suggestion prompt.
  ///
  /// Returns a ChatML-formatted prompt that suggests related notes from
  /// [otherNoteTitles] that may be connected to the current note.
  static String suggestConnections({
    required String title,
    required String content,
    required List<String> otherNoteTitles,
  }) {
    final titles = otherNoteTitles.join('\n- ');
    return '''<|im_start|>system
You are a personal wiki assistant. Suggest up to 5 related notes from the list.
Reply ONLY with a JSON object: {"connections": ["title1", "title2", ...]}<|im_end|>
<|im_start|>user
Current note title: $title
Current note content: $content

Available notes:
- $titles<|im_end|>
<|im_start|>assistant
''';
  }
}
