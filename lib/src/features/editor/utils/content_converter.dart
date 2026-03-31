import 'dart:convert';
import 'package:markdown/markdown.dart' as md;

/// Convert AppFlowy JSON contentBlocks to HTML paragraphs.
String appflowyJsonToHtml(String jsonStr) {
  try {
    dynamic parsed = jsonDecode(jsonStr);
    if (parsed is String) parsed = jsonDecode(parsed);
    final Map<String, dynamic> json = parsed as Map<String, dynamic>;
    final doc = json['document'] as Map<String, dynamic>?;
    final children = (doc?['children'] ?? []) as List;
    final buffer = StringBuffer();
    for (final child in children) {
      final Map<String, dynamic>? data =
          child['data'] as Map<String, dynamic>?;
      final delta = (data?['delta'] ?? []) as List;
      final texts = delta.map((d) => d['insert']?.toString() ?? '').join();
      buffer.write('<p>${texts.isEmpty ? "<br>" : escapeHtml(texts)}</p>');
    }
    return buffer.toString();
  } catch (_) {
    return '';
  }
}

/// Convert plain text to HTML paragraphs.
String plainTextToHtml(String text) {
  return text
      .split('\n')
      .map((line) => '<p>${line.isEmpty ? "<br>" : escapeHtml(line)}</p>')
      .join();
}

/// Strip HTML tags and decode entities to plain text.
String htmlToPlainText(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?(p|div|li|h[1-6]|blockquote)[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

/// Escape HTML special characters.
String escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

// ---------------------------------------------------------------------------
// Markdown Conversion
// ---------------------------------------------------------------------------

/// Convert HTML to Markdown.
/// Simple conversion: strips tags and converts common HTML patterns to Markdown.
String htmlToMarkdown(String html) {
  var markdown = html;
  // Remove HTML tags
  markdown = markdown.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
  markdown = markdown.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  markdown = markdown.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  markdown = markdown.replaceAll(RegExp(r'<strong[^>]*>', caseSensitive: false), '**');
  markdown = markdown.replaceAll(RegExp(r'</strong>', caseSensitive: false), '**');
  markdown = markdown.replaceAll(RegExp(r'<em[^>]*>', caseSensitive: false), '_');
  markdown = markdown.replaceAll(RegExp(r'</em>', caseSensitive: false), '_');
  markdown = markdown.replaceAll(RegExp(r'<b[^>]*>', caseSensitive: false), '**');
  markdown = markdown.replaceAll(RegExp(r'</b>', caseSensitive: false), '**');
  markdown = markdown.replaceAll(RegExp(r'<i[^>]*>', caseSensitive: false), '_');
  markdown = markdown.replaceAll(RegExp(r'</i>', caseSensitive: false), '_');
  // Decode HTML entities
  markdown = markdown
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // Clean up extra whitespace
  markdown = markdown.replaceAll(RegExp(r'\n\s*\n+'), '\n\n').trim();
  return markdown;
}

/// Convert Markdown to HTML.
/// Uses the markdown package to parse and render.
String markdownToHtml(String markdown) {
  try {
    final html = md.markdownToHtml(markdown);
    return html;
  } catch (_) {
    // Fallback: treat as plain text
    return plainTextToHtml(markdown);
  }
}

/// Convert plain text to Markdown (identity, since plain text is already Markdown-compatible).
String plainTextToMarkdown(String text) {
  // Plain text is already valid Markdown, just ensure proper line breaks
  return text.replaceAll(RegExp(r'\n\s*\n+'), '\n\n').trim();
}
