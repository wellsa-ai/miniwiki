import 'package:flutter_test/flutter_test.dart';
import 'package:miniwiki/src/features/editor/utils/wikilink_parser.dart';

void main() {
  group('extractWikilinks', () {
    test('extracts single wikilink', () {
      final result = extractWikilinks('Check out [[My Note]]');
      expect(result, ['My Note']);
    });

    test('extracts multiple wikilinks', () {
      final result =
          extractWikilinks('See [[Note A]] and [[Note B]] for details');
      expect(result, ['Note A', 'Note B']);
    });

    test('returns empty for no wikilinks', () {
      expect(extractWikilinks('No links here'), isEmpty);
    });

    test('handles Korean titles', () {
      final result = extractWikilinks('참조: [[플러터 개발 가이드]]');
      expect(result, ['플러터 개발 가이드']);
    });

    test('trims whitespace', () {
      final result = extractWikilinks('[[  spaced  ]]');
      expect(result, ['spaced']);
    });
  });

  group('extractHashtags', () {
    test('extracts single hashtag', () {
      final result = extractHashtags('This is #flutter related');
      expect(result, ['flutter']);
    });

    test('extracts multiple hashtags', () {
      final result = extractHashtags('#dart #flutter #위키');
      expect(result, ['dart', 'flutter', '위키']);
    });

    test('returns empty for no hashtags', () {
      expect(extractHashtags('No tags here'), isEmpty);
    });

    test('ignores hashtags inside words', () {
      // email#tag should not match
      expect(extractHashtags('email#tag'), isEmpty);
    });

    test('handles Korean hashtags', () {
      final result = extractHashtags('#개인위키 #프라이버시');
      expect(result, ['개인위키', '프라이버시']);
    });

    test('handles hyphens and underscores', () {
      final result = extractHashtags('#my-tag #my_tag');
      expect(result, ['my-tag', 'my_tag']);
    });
  });

  group('wikilinkToMarkdown', () {
    test('converts known wikilink to markdown link', () {
      final result = wikilinkToMarkdown(
        'See [[Note A]]',
        {'Note A': 'id-123'},
      );
      expect(result, 'See [Note A](miniwiki://note/id-123)');
    });

    test('converts unknown wikilink to new-note link', () {
      final result = wikilinkToMarkdown('See [[New Note]]', {});
      expect(result, contains('miniwiki://new?title=New%20Note'));
    });
  });
}
