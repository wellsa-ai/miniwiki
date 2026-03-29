import 'package:flutter_test/flutter_test.dart';
import 'package:miniwiki/src/features/editor/utils/content_converter.dart';

void main() {
  group('appflowyJsonToHtml', () {
    test('converts simple AppFlowy JSON to HTML', () {
      const json = '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Hello World"}]}}]}}';
      final result = appflowyJsonToHtml(json);
      expect(result, '<p>Hello World</p>');
    });

    test('converts multiple paragraphs', () {
      const json = '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Line 1"}]}},{"type":"paragraph","data":{"delta":[{"insert":"Line 2"}]}}]}}';
      final result = appflowyJsonToHtml(json);
      expect(result, '<p>Line 1</p><p>Line 2</p>');
    });

    test('handles empty delta', () {
      const json = '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[]}}]}}';
      final result = appflowyJsonToHtml(json);
      expect(result, '<p><br></p>');
    });

    test('escapes HTML in content', () {
      const json = '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"<script>alert(1)</script>"}]}}]}}';
      final result = appflowyJsonToHtml(json);
      expect(result, contains('&lt;script&gt;'));
      expect(result, isNot(contains('<script>')));
    });

    test('returns empty for invalid JSON', () {
      expect(appflowyJsonToHtml('not json'), '');
      expect(appflowyJsonToHtml(''), '');
    });

    test('handles Korean text', () {
      const json = '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"한글 테스트입니다"}]}}]}}';
      final result = appflowyJsonToHtml(json);
      expect(result, '<p>한글 테스트입니다</p>');
    });
  });

  group('plainTextToHtml', () {
    test('converts single line', () {
      expect(plainTextToHtml('Hello'), '<p>Hello</p>');
    });

    test('converts multiple lines', () {
      expect(plainTextToHtml('A\nB\nC'), '<p>A</p><p>B</p><p>C</p>');
    });

    test('handles empty lines', () {
      expect(plainTextToHtml('A\n\nB'), '<p>A</p><p><br></p><p>B</p>');
    });
  });

  group('htmlToPlainText', () {
    test('strips tags', () {
      expect(htmlToPlainText('<p>Hello <strong>World</strong></p>'), 'Hello World');
    });

    test('decodes entities', () {
      expect(htmlToPlainText('&lt;script&gt;'), '<script>');
      expect(htmlToPlainText('&amp;'), '&');
    });
  });

  group('escapeHtml', () {
    test('escapes special characters', () {
      expect(escapeHtml('<script>'), '&lt;script&gt;');
      expect(escapeHtml('"hello"'), '&quot;hello&quot;');
      expect(escapeHtml('a & b'), 'a &amp; b');
    });

    test('leaves normal text unchanged', () {
      expect(escapeHtml('Hello World'), 'Hello World');
      expect(escapeHtml('한글'), '한글');
    });
  });
}
