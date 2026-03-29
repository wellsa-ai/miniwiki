/// Riverpod providers for on-device AI features.
///
/// The main entry-points:
/// - [aiServiceProvider]           -- singleton AI service
/// - [aiTagSuggestionsProvider]    -- tag suggestions for a note
/// - [aiClassificationProvider]    -- category classification for a note
/// - [aiConnectionsProvider]       -- connection suggestions for a note
/// - [aiControllerProvider]        -- controller with auto-tag-on-save logic
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../notes/providers/notes_provider.dart';
import '../../settings/providers/settings_provider.dart';

// ---------------------------------------------------------------------------
// Singleton AI Service
// ---------------------------------------------------------------------------

/// Provides the singleton [AiService] instance.
///
/// Disposed automatically when the provider is discarded.
final aiServiceProvider = Provider<AiService>((ref) {
  final service = AiService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ---------------------------------------------------------------------------
// Tag Suggestions
// ---------------------------------------------------------------------------

/// Get AI-suggested tags for a given note.
///
/// Returns a [TagSuggestionResult] containing the suggested tag names
/// and whether mock mode was used.
final aiTagSuggestionsProvider =
    FutureProvider.family<TagSuggestionResult, String>((ref, noteId) async {
  final service = ref.read(aiServiceProvider);
  final dao = ref.read(notesDaoProvider);

  final note = await dao.getNoteById(noteId);
  if (note == null) {
    return const TagSuggestionResult(tags: [], isMock: true);
  }

  // Gather existing tags so the model can prefer reusing them
  final allTags = await dao.getAllTags();
  final existingTagNames = allTags.map((t) => t.name).toList();

  return service.suggestTags(
    title: note.title,
    content: note.content,
    existingTags: existingTagNames,
  );
});

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

/// Get AI-suggested category for a given note.
final aiClassificationProvider =
    FutureProvider.family<ClassificationResult, String>((ref, noteId) async {
  final service = ref.read(aiServiceProvider);
  final dao = ref.read(notesDaoProvider);

  final note = await dao.getNoteById(noteId);
  if (note == null) {
    return const ClassificationResult(category: 'reference', isMock: true);
  }

  return service.classifyNote(
    title: note.title,
    content: note.content,
  );
});

// ---------------------------------------------------------------------------
// Connection Suggestions
// ---------------------------------------------------------------------------

/// Get AI-suggested connections for a given note.
final aiConnectionsProvider =
    FutureProvider.family<ConnectionSuggestionResult, String>(
        (ref, noteId) async {
  final service = ref.read(aiServiceProvider);
  final dao = ref.read(notesDaoProvider);

  final note = await dao.getNoteById(noteId);
  if (note == null) {
    return const ConnectionSuggestionResult(connections: [], isMock: true);
  }

  final allNotes = await dao.getAllNotes();
  final otherTitles =
      allNotes.where((n) => n.id != noteId).map((n) => n.title).toList();

  return service.suggestConnections(
    title: note.title,
    content: note.content,
    otherNoteTitles: otherTitles,
  );
});

// ---------------------------------------------------------------------------
// AI Controller (auto-tag on save, etc.)
// ---------------------------------------------------------------------------

/// Controller for AI-powered mutations (auto-tagging, classification).
///
/// Follows the same pattern as [NotesController] in the project — a plain
/// class exposed through a [Provider] that holds a [Ref].
final aiControllerProvider = Provider<AiController>((ref) {
  return AiController(ref);
});

class AiController {
  final Ref _ref;
  AiController(this._ref);

  /// Auto-tag a note after save.
  ///
  /// Checks the auto-tag setting first. If disabled, returns immediately.
  /// Returns the list of tag names that were applied.
  Future<List<String>> autoTagNote(String noteId) async {
    // Check if auto-tag is enabled
    final settings = _ref.read(settingsProvider);
    final autoTagEnabled = settings.valueOrNull?.autoTagEnabled ?? false;
    if (!autoTagEnabled) return [];

    final service = _ref.read(aiServiceProvider);
    final dao = _ref.read(notesDaoProvider);

    final note = await dao.getNoteById(noteId);
    if (note == null) return [];

    // Skip very short notes — not enough context for tagging
    if (note.content.trim().length < 20) return [];

    // Gather existing tags for reuse
    final allTags = await dao.getAllTags();
    final existingTagNames = allTags.map((t) => t.name).toList();

    final result = await service.suggestTags(
      title: note.title,
      content: note.content,
      existingTags: existingTagNames,
    );

    // Apply suggested tags
    final controller = _ref.read(notesControllerProvider);
    for (final tagName in result.tags) {
      await controller.addTag(noteId: noteId, tagName: tagName);
    }

    return result.tags;
  }

  /// Classify a note and update its category field.
  Future<String?> classifyAndUpdateNote(String noteId) async {
    final service = _ref.read(aiServiceProvider);
    final dao = _ref.read(notesDaoProvider);

    final note = await dao.getNoteById(noteId);
    if (note == null) return null;

    final result = await service.classifyNote(
      title: note.title,
      content: note.content,
    );

    // Update the note's category
    final controller = _ref.read(notesControllerProvider);
    await controller.updateNote(id: noteId, category: result.category);

    return result.category;
  }
}
