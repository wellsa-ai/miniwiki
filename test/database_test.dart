import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNotNull, isNull;
import 'package:miniwiki/src/core/database/database.dart';
import 'package:miniwiki/src/core/database/daos/notes_dao.dart';

AppDatabase _createTestDb() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;
  late NotesDao dao;

  setUp(() {
    db = _createTestDb();
    dao = NotesDao(db);
  });

  tearDown(() => db.close());

  // =========================================================================
  // Notes CRUD
  // =========================================================================
  group('Notes CRUD', () {
    test('insert and retrieve a note', () async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-1',
        title: 'Test Note',
        content: 'Hello world',
        createdAt: now,
        updatedAt: now,
      ));

      final notes = await dao.getAllNotes();
      expect(notes.length, 1);
      expect(notes.first.title, 'Test Note');
      expect(notes.first.content, 'Hello world');
      expect(notes.first.isDeleted, false);
      expect(notes.first.version, 1);
    });

    test('insert multiple notes ordered by updatedAt desc', () async {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 1, 2);
      final t3 = DateTime(2026, 1, 3);

      await dao.insertNote(NotesCompanion.insert(
        id: 'old', title: 'Old', content: '', createdAt: t1, updatedAt: t1,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'new', title: 'New', content: '', createdAt: t3, updatedAt: t3,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'mid', title: 'Mid', content: '', createdAt: t2, updatedAt: t2,
      ));

      final notes = await dao.getAllNotes();
      expect(notes.map((n) => n.id).toList(), ['new', 'mid', 'old']);
    });

    test('getNoteById returns null for non-existent id', () async {
      final note = await dao.getNoteById('non-existent');
      expect(note == null, true);
    });

    test('soft delete hides note from getAllNotes', () async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-1', title: 'To Delete', content: 'content',
        createdAt: now, updatedAt: now,
      ));

      await dao.softDeleteNote('note-1');

      final notes = await dao.getAllNotes();
      expect(notes.length, 0);

      // Still exists in DB with isDeleted=true
      final note = await dao.getNoteById('note-1');
      expect(note != null, true);
      expect(note!.isDeleted, true);
    });

    test('permanently delete removes from DB', () async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-1', title: 'Delete Me', content: '',
        createdAt: now, updatedAt: now,
      ));

      await dao.permanentlyDeleteNote('note-1');

      final note = await dao.getNoteById('note-1');
      expect(note == null, true);
    });

    test('update note fields', () async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-1', title: 'Original', content: 'original content',
        createdAt: now, updatedAt: now,
      ));

      await dao.updateNote(NotesCompanion(
        id: const Value('note-1'),
        title: const Value('Updated'),
        content: const Value('new content'),
        category: const Value('tech'),
        updatedAt: Value(DateTime.now()),
      ));

      final note = await dao.getNoteById('note-1');
      expect(note!.title, 'Updated');
      expect(note.content, 'new content');
      expect(note.category, 'tech');
    });

    test('partial update preserves unchanged fields', () async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-1', title: 'Keep This', content: 'keep this too',
        createdAt: now, updatedAt: now,
      ));

      // Update only content
      await dao.updateNote(NotesCompanion(
        id: const Value('note-1'),
        content: const Value('changed'),
        updatedAt: Value(DateTime.now()),
      ));

      final note = await dao.getNoteById('note-1');
      expect(note!.title, 'Keep This'); // preserved
      expect(note.content, 'changed');
    });
  });

  // =========================================================================
  // FTS5 Search
  // =========================================================================
  group('FTS5 Search', () {
    setUp(() async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-flutter', title: 'Flutter Development',
        content: 'Flutter is a cross-platform framework for building apps',
        createdAt: now, updatedAt: now,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-dart', title: 'Dart Language',
        content: 'Dart is the programming language used by Flutter',
        createdAt: now, updatedAt: now,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-wiki', title: 'Personal Wiki',
        content: 'A personal wiki helps organize knowledge and ideas',
        createdAt: now, updatedAt: now,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-deleted', title: 'Deleted Note',
        content: 'This note about Flutter is deleted',
        createdAt: now, updatedAt: now,
      ));
      await dao.softDeleteNote('note-deleted');
    });

    test('search by title', () async {
      final results = await dao.searchNotes('Flutter');
      expect(results.any((n) => n.id == 'note-flutter'), true);
    });

    test('search by content', () async {
      final results = await dao.searchNotes('knowledge');
      expect(results.length, 1);
      expect(results.first.id, 'note-wiki');
    });

    test('search excludes deleted notes', () async {
      final results = await dao.searchNotes('Flutter');
      expect(results.any((n) => n.id == 'note-deleted'), false);
    });

    test('empty query returns all non-deleted notes', () async {
      final results = await dao.searchNotes('');
      expect(results.length, 3);
    });

    test('no match returns empty', () async {
      final results = await dao.searchNotes('nonexistent');
      expect(results.length, 0);
    });

    test('search after update finds new content', () async {
      await dao.updateNote(NotesCompanion(
        id: const Value('note-wiki'),
        content: const Value('Now this is about encryption and security'),
        updatedAt: Value(DateTime.now()),
      ));

      final results = await dao.searchNotes('encryption');
      expect(results.length, 1);
      expect(results.first.id, 'note-wiki');

      // Old content should no longer match
      final oldResults = await dao.searchNotes('knowledge');
      expect(oldResults.length, 0);
    });
  });

  // =========================================================================
  // Tags
  // =========================================================================
  group('Tags', () {
    setUp(() async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-1', title: 'Tagged Note', content: 'content',
        createdAt: now, updatedAt: now,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-2', title: 'Another Note', content: 'content',
        createdAt: now, updatedAt: now,
      ));
    });

    test('add and retrieve tags for a note', () async {
      await dao.insertTag(TagsCompanion.insert(id: 'tag-1', name: 'flutter'));
      await dao.addTagToNote(noteId: 'note-1', tagId: 'tag-1');

      final tags = await dao.getTagsForNote('note-1');
      expect(tags.length, 1);
      expect(tags.first.name, 'flutter');
    });

    test('multiple tags on one note', () async {
      await dao.insertTag(TagsCompanion.insert(id: 'tag-1', name: 'flutter'));
      await dao.insertTag(TagsCompanion.insert(id: 'tag-2', name: 'dart'));
      await dao.addTagToNote(noteId: 'note-1', tagId: 'tag-1');
      await dao.addTagToNote(noteId: 'note-1', tagId: 'tag-2');

      final tags = await dao.getTagsForNote('note-1');
      expect(tags.length, 2);
    });

    test('same tag on multiple notes', () async {
      await dao.insertTag(TagsCompanion.insert(id: 'tag-1', name: 'shared'));
      await dao.addTagToNote(noteId: 'note-1', tagId: 'tag-1');
      await dao.addTagToNote(noteId: 'note-2', tagId: 'tag-1');

      expect((await dao.getTagsForNote('note-1')).length, 1);
      expect((await dao.getTagsForNote('note-2')).length, 1);
    });

    test('remove tag from note', () async {
      await dao.insertTag(TagsCompanion.insert(id: 'tag-1', name: 'test'));
      await dao.addTagToNote(noteId: 'note-1', tagId: 'tag-1');
      await dao.removeTagFromNote('note-1', 'tag-1');

      final tags = await dao.getTagsForNote('note-1');
      expect(tags.length, 0);

      // Tag itself still exists
      final allTags = await dao.getAllTags();
      expect(allTags.length, 1);
    });

    test('duplicate tag insert is ignored', () async {
      await dao.insertTag(TagsCompanion.insert(id: 'tag-1', name: 'flutter'));
      await dao.insertTag(TagsCompanion.insert(id: 'tag-2', name: 'flutter'));

      final tags = await dao.getAllTags();
      expect(tags.length, 1);
      expect(tags.first.id, 'tag-1'); // First one kept
    });

    test('tag with confidence and isManual', () async {
      await dao.insertTag(TagsCompanion.insert(id: 'tag-1', name: 'ai-tag'));
      await dao.addTagToNote(
        noteId: 'note-1',
        tagId: 'tag-1',
        confidence: 0.85,
        isManual: false,
      );

      // Verify via raw query (NoteTag is not directly exposed)
      final result = await db.customSelect(
        'SELECT * FROM note_tags WHERE note_id = ?',
        variables: [Variable.withString('note-1')],
      ).get();

      expect(result.first.read<double>('confidence'), 0.85);
      expect(result.first.read<bool>('is_manual'), false);
    });
  });

  // =========================================================================
  // Links (Wikilinks + Backlinks)
  // =========================================================================
  group('Links', () {
    setUp(() async {
      final now = DateTime.now();
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-a', title: 'Note A', content: 'see [[Note B]]',
        createdAt: now, updatedAt: now,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-b', title: 'Note B', content: 'target',
        createdAt: now, updatedAt: now,
      ));
      await dao.insertNote(NotesCompanion.insert(
        id: 'note-c', title: 'Note C', content: 'also links to [[Note B]]',
        createdAt: now, updatedAt: now,
      ));
    });

    test('insert wikilink and get outgoing links', () async {
      await dao.insertLink(NoteLinksCompanion.insert(
        sourceId: 'note-a', targetId: 'note-b', linkType: 'wikilink',
        context: const Value('Note B'),
      ));

      final links = await dao.getLinksFromNote('note-a');
      expect(links.length, 1);
      expect(links.first.targetId, 'note-b');
      expect(links.first.linkType, 'wikilink');
    });

    test('get backlinks to a note', () async {
      await dao.insertLink(NoteLinksCompanion.insert(
        sourceId: 'note-a', targetId: 'note-b', linkType: 'wikilink',
      ));
      await dao.insertLink(NoteLinksCompanion.insert(
        sourceId: 'note-c', targetId: 'note-b', linkType: 'wikilink',
      ));

      final backlinks = await dao.getBacklinksToNote('note-b');
      expect(backlinks.length, 2);
      expect(backlinks.map((l) => l.sourceId).toSet(), {'note-a', 'note-c'});
    });

    test('duplicate link is replaced (upsert)', () async {
      await dao.insertLink(NoteLinksCompanion.insert(
        sourceId: 'note-a', targetId: 'note-b', linkType: 'wikilink',
        context: const Value('first'),
      ));
      await dao.insertLink(NoteLinksCompanion.insert(
        sourceId: 'note-a', targetId: 'note-b', linkType: 'wikilink',
        context: const Value('updated'),
      ));

      final links = await dao.getLinksFromNote('note-a');
      expect(links.length, 1);
      // Context should be updated due to insertOrReplace
    });

    test('different link types coexist', () async {
      await dao.insertLink(NoteLinksCompanion.insert(
        sourceId: 'note-a', targetId: 'note-b', linkType: 'wikilink',
      ));
      await dao.insertLink(NoteLinksCompanion.insert(
        sourceId: 'note-a', targetId: 'note-b', linkType: 'ai_suggestion',
        confidence: const Value(0.9),
      ));

      final links = await dao.getLinksFromNote('note-a');
      expect(links.length, 2);
    });
  });

  // =========================================================================
  // Streams (Reactivity)
  // =========================================================================
  group('Streams', () {
    test('watchAllNotes emits on insert', () async {
      final stream = dao.watchAllNotes();

      // Should start empty
      expectLater(
        stream,
        emitsInOrder([
          hasLength(0),
          hasLength(1),
        ]),
      );

      // Small delay then insert
      await Future.delayed(const Duration(milliseconds: 50));
      await dao.insertNote(NotesCompanion.insert(
        id: 'new', title: 'New', content: '',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
    });
  });

  // =========================================================================
  // Data Integrity (after encryption/recovery scenarios)
  // =========================================================================
  group('Data Integrity', () {
    test('data persists across db operations', () async {
      final now = DateTime.now();
      const testNote = 'important-note';

      // Insert a note with content
      await dao.insertNote(NotesCompanion.insert(
        id: testNote,
        title: 'Critical Data',
        content: 'This data must survive',
        createdAt: now,
        updatedAt: now,
      ));

      // Retrieve and verify
      final retrieved = await dao.getNoteById(testNote);
      expect(retrieved != null, true);
      expect(retrieved!.content, 'This data must survive');

      // Update and verify again
      await dao.updateNote(NotesCompanion(
        id: const Value(testNote),
        content: const Value('Updated content'),
        updatedAt: Value(now.add(const Duration(seconds: 1))),
      ));

      final updated = await dao.getNoteById(testNote);
      expect(updated!.content, 'Updated content');
    });

    test('soft delete does not lose data', () async {
      final now = DateTime.now();

      await dao.insertNote(NotesCompanion.insert(
        id: 'soft-delete-test',
        title: 'To be soft-deleted',
        content: 'Still in database',
        createdAt: now,
        updatedAt: now,
      ));

      // Mark as deleted
      await dao.updateNote(NotesCompanion(
        id: const Value('soft-delete-test'),
        isDeleted: const Value(true),
      ));

      // Should not appear in getAllNotes
      final active = await dao.getAllNotes();
      expect(active.map((n) => n.id), isNot(contains('soft-delete-test')));

      // But should still exist in database
      final note = await dao.getNoteById('soft-delete-test');
      expect(note != null, true);
      expect(note!.isDeleted, true);
    });

    test('concurrent operations maintain consistency', () async {
      final now = DateTime.now();

      // Insert multiple notes concurrently
      await Future.wait([
        dao.insertNote(NotesCompanion.insert(
          id: 'concurrent-1',
          title: 'Note 1',
          content: 'Content 1',
          createdAt: now,
          updatedAt: now,
        )),
        dao.insertNote(NotesCompanion.insert(
          id: 'concurrent-2',
          title: 'Note 2',
          content: 'Content 2',
          createdAt: now,
          updatedAt: now,
        )),
      ]);

      final notes = await dao.getAllNotes();
      expect(
        notes.map((n) => n.id).toSet(),
        contains('concurrent-1'),
      );
      expect(
        notes.map((n) => n.id).toSet(),
        contains('concurrent-2'),
      );
    });
  });
}
