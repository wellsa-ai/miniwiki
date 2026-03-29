import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/app_providers.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Read Providers (reactive streams)
// ---------------------------------------------------------------------------

/// All non-deleted notes, newest first.
final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  final dao = ref.watch(notesDaoProvider);
  return dao.watchAllNotes();
});

/// Single note by ID (reactive).
final noteByIdProvider = StreamProvider.family<Note?, String>((ref, id) {
  final dao = ref.watch(notesDaoProvider);
  return dao.watchNoteById(id);
});

/// Tags for a specific note.
final noteTagsProvider = StreamProvider.family<List<Tag>, String>((ref, id) {
  final dao = ref.watch(notesDaoProvider);
  return dao.watchTagsForNote(id);
});

/// Backlinks pointing to a specific note.
final noteBacklinksProvider =
    StreamProvider.family<List<NoteLink>, String>((ref, id) {
  final dao = ref.watch(notesDaoProvider);
  return dao.watchBacklinksToNote(id);
});

/// All tags in the system.
final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  final dao = ref.watch(notesDaoProvider);
  return dao.watchAllTags();
});

/// Notes count (for stats).
final notesCountProvider = FutureProvider<int>((ref) async {
  final notes = await ref.watch(notesStreamProvider.future);
  return notes.length;
});

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Note>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().length < 2) return []; // min 2 chars to search
  final dao = ref.watch(notesDaoProvider);
  return dao.searchNotes(query);
});

// ---------------------------------------------------------------------------
// Mutations (NotesController)
// ---------------------------------------------------------------------------

final notesControllerProvider =
    Provider<NotesController>((ref) => NotesController(ref));

class NotesController {
  final Ref _ref;
  NotesController(this._ref);

  Future<String> createNote({
    String title = '',
    String content = '',
    String? contentBlocks,
  }) async {
    final dao = _ref.read(notesDaoProvider);
    final id = _uuid.v7();
    final now = DateTime.now();

    await dao.insertNote(NotesCompanion.insert(
      id: id,
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      contentBlocks: Value(contentBlocks),
      createdAt: now,
      updatedAt: now,
    ));

    return id;
  }

  Future<void> updateNote({
    required String id,
    String? title,
    String? content,
    String? contentBlocks,
    String? category,
  }) async {
    final dao = _ref.read(notesDaoProvider);
    await dao.updateNote(NotesCompanion(
      id: Value(id),
      title: title != null ? Value(title) : const Value.absent(),
      content: content != null ? Value(content) : const Value.absent(),
      contentBlocks:
          contentBlocks != null ? Value(contentBlocks) : const Value.absent(),
      category: category != null ? Value(category) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteNote(String id) async {
    final dao = _ref.read(notesDaoProvider);
    await dao.softDeleteNote(id);
  }

  // --- Tags ---

  Future<void> addTag({
    required String noteId,
    required String tagName,
    String? color,
  }) async {
    final dao = _ref.read(notesDaoProvider);

    // Look up existing tag by name (single query, not full table scan)
    final existing = await dao.getTagByName(tagName);
    final tagId = existing?.id ?? _uuid.v7();

    if (existing == null) {
      await dao.insertTag(TagsCompanion.insert(
        id: tagId,
        name: tagName,
        color: Value(color),
      ));
    }

    await dao.addTagToNote(noteId: noteId, tagId: tagId);
  }

  Future<void> removeTag({
    required String noteId,
    required String tagId,
  }) async {
    final dao = _ref.read(notesDaoProvider);
    await dao.removeTagFromNote(noteId, tagId);
  }

  // --- Links ---

  Future<void> addWikilink({
    required String sourceId,
    required String targetId,
    String? context,
  }) async {
    final dao = _ref.read(notesDaoProvider);
    await dao.insertLink(NoteLinksCompanion.insert(
      sourceId: sourceId,
      targetId: targetId,
      linkType: 'wikilink',
      context: Value(context),
    ));
  }
}
