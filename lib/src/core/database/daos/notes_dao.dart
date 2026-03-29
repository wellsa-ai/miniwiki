import 'package:drift/drift.dart';
import '../database.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, Tags, NoteTags, NoteLinks])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  // --- Notes CRUD ---

  Future<List<Note>> getAllNotes() {
    return (select(notes)
          ..where((n) => n.isDeleted.equals(false))
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .get();
  }

  Stream<List<Note>> watchAllNotes() {
    return (select(notes)
          ..where((n) => n.isDeleted.equals(false))
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Future<Note?> getNoteById(String id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  Stream<Note?> watchNoteById(String id) {
    return (select(notes)..where((n) => n.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> insertNote(NotesCompanion note) {
    return into(notes).insert(note);
  }

  Future<void> updateNote(NotesCompanion note) {
    return (update(notes)..where((n) => n.id.equals(note.id.value)))
        .write(note);
  }

  Future<void> softDeleteNote(String id) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> permanentlyDeleteNote(String id) {
    return (delete(notes)..where((n) => n.id.equals(id))).go();
  }

  // --- Full-Text Search ---

  Future<List<Note>> searchNotes(String query) async {
    if (query.trim().isEmpty) return getAllNotes();

    // Sanitize FTS5 query: escape special characters that cause syntax errors
    // FTS5 operators: AND OR NOT NEAR " * ^ ( )
    final sanitized = query
        .replaceAll('"', '""')
        .replaceAll(RegExp(r'[*^(){}[\]]'), ' ')
        .trim();
    if (sanitized.isEmpty) return getAllNotes();

    // Wrap each word in quotes for exact prefix matching
    final quoted = sanitized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '"$w"*')
        .join(' ');

    final results = await customSelect(
      '''
      SELECT notes.* FROM notes
      INNER JOIN notes_fts ON notes.rowid = notes_fts.rowid
      WHERE notes_fts MATCH ? AND notes.is_deleted = 0
      ORDER BY rank
      ''',
      variables: [Variable.withString(quoted)],
      readsFrom: {notes},
    ).get();

    return results
        .map((row) => Note(
              id: row.read<String>('id'),
              title: row.read<String>('title'),
              content: row.read<String>('content'),
              contentBlocks: row.readNullable<String>('content_blocks'),
              category: row.readNullable<String>('category'),
              createdAt: row.read<DateTime>('created_at'),
              updatedAt: row.read<DateTime>('updated_at'),
              isDeleted: row.read<bool>('is_deleted'),
              version: row.read<int>('version'),
            ))
        .toList();
  }

  // --- Tags ---

  Future<List<Tag>> getAllTags() => select(tags).get();

  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  Future<List<Tag>> getTagsForNote(String noteId) {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])
      ..where(noteTags.noteId.equals(noteId));
    return query.map((row) => row.readTable(tags)).get();
  }

  Stream<List<Tag>> watchTagsForNote(String noteId) {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])
      ..where(noteTags.noteId.equals(noteId));
    return query.map((row) => row.readTable(tags)).watch();
  }

  Future<Tag?> getTagByName(String name) {
    return (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  Future<Note?> getNoteByTitle(String title) {
    return (select(notes)
          ..where((n) => n.title.equals(title) & n.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<void> insertTag(TagsCompanion tag) {
    return into(tags).insert(tag, mode: InsertMode.insertOrIgnore);
  }

  Future<void> addTagToNote({
    required String noteId,
    required String tagId,
    double? confidence,
    bool isManual = true,
  }) {
    return into(noteTags).insert(
      NoteTagsCompanion.insert(
        noteId: noteId,
        tagId: tagId,
        confidence: Value(confidence),
        isManual: Value(isManual),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> removeTagFromNote(String noteId, String tagId) {
    return (delete(noteTags)
          ..where((t) => t.noteId.equals(noteId) & t.tagId.equals(tagId)))
        .go();
  }

  // --- Links ---

  Future<List<NoteLink>> getLinksFromNote(String noteId) {
    return (select(noteLinks)..where((l) => l.sourceId.equals(noteId))).get();
  }

  Future<List<NoteLink>> getBacklinksToNote(String noteId) {
    return (select(noteLinks)..where((l) => l.targetId.equals(noteId))).get();
  }

  Stream<List<NoteLink>> watchBacklinksToNote(String noteId) {
    return (select(noteLinks)..where((l) => l.targetId.equals(noteId)))
        .watch();
  }

  Future<void> insertLink(NoteLinksCompanion link) {
    return into(noteLinks).insert(link, mode: InsertMode.insertOrReplace);
  }
}
