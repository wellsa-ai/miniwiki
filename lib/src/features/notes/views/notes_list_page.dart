import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../editor/utils/content_converter.dart';
import '../providers/notes_provider.dart';

// ---------------------------------------------------------------------------
// Filter / Sort state
// ---------------------------------------------------------------------------

enum NotesSortOrder { updatedDesc, updatedAsc, titleAsc, createdDesc }

final notesSortProvider =
    StateProvider<NotesSortOrder>((ref) => NotesSortOrder.updatedDesc);

final notesFilterTagProvider = StateProvider<String?>((ref) => null);

final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final sortOrder = ref.watch(notesSortProvider);
  final filterTag = ref.watch(notesFilterTagProvider);
  final notesAsync = ref.watch(notesStreamProvider);

  return notesAsync.whenData((notes) {
    var result = List<Note>.from(notes);

    // TODO: tag filtering requires join — for now filter by category
    if (filterTag != null) {
      result = result.where((n) => n.category == filterTag).toList();
    }

    switch (sortOrder) {
      case NotesSortOrder.updatedDesc:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case NotesSortOrder.updatedAsc:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case NotesSortOrder.titleAsc:
        result.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case NotesSortOrder.createdDesc:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
  });
});

// ---------------------------------------------------------------------------
// Notes List Page
// ---------------------------------------------------------------------------

class NotesListPage extends ConsumerWidget {
  const NotesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(filteredNotesProvider);
    final noteCount = ref.watch(notesCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('miniwiki'),
            noteCount.whenOrNull(
                  data: (count) => Text(
                    '$count notes',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ) ??
                const SizedBox.shrink(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortMenu(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $err'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(notesStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return _EmptyState(onCreateNote: () => _createNote(context, ref));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notesStreamProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) => _NoteListTile(
                note: notes[index],
                onTap: () => context.push('/note/${notes[index].id}'),
                onDelete: () => _deleteNote(context, ref, notes[index]),
                cachedPreview: _NoteListTile.computePreview(notes[index].content),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNote(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(notesControllerProvider);
    final id = await controller.createNote();
    if (context.mounted) {
      context.push('/note/$id');
    }
  }

  Future<void> _deleteNote(
      BuildContext context, WidgetRef ref, Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${note.title}" will be moved to trash.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(notesControllerProvider).deleteNote(note.id);
    }
  }

  void _showSortMenu(BuildContext context, WidgetRef ref) {
    final current = ref.read(notesSortProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final order in NotesSortOrder.values)
              ListTile(
                title: Text(_sortLabel(order)),
                trailing:
                    current == order ? const Icon(Icons.check, size: 20) : null,
                onTap: () {
                  ref.read(notesSortProvider.notifier).state = order;
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(NotesSortOrder order) {
    return switch (order) {
      NotesSortOrder.updatedDesc => 'Recently updated',
      NotesSortOrder.updatedAsc => 'Oldest updated',
      NotesSortOrder.titleAsc => 'Title A-Z',
      NotesSortOrder.createdDesc => 'Recently created',
    };
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateNote;
  const _EmptyState({required this.onCreateNote});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories,
              size: 80, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 24),
          Text(
            'Your wiki is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first note to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateNote,
            icon: const Icon(Icons.add),
            label: const Text('New Note'),
          ),
        ],
      ),
    );
  }
}

class _NoteListTile extends StatelessWidget {
  static final _dateFormat = DateFormat('MM/dd HH:mm');

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String? _cachedPreview;

  const _NoteListTile({
    required this.note,
    required this.onTap,
    required this.onDelete,
    String? cachedPreview,
  }) : _cachedPreview = cachedPreview;

  /// Compute preview once, can be called from list builder
  static String computePreview(String content) {
    var rawPreview = content;
    if (rawPreview.startsWith('{')) {
      rawPreview = htmlToPlainText(appflowyJsonToHtml(rawPreview));
    } else if (rawPreview.contains('<')) {
      rawPreview = htmlToPlainText(rawPreview);
    }
    return rawPreview.length > 120
        ? '${rawPreview.substring(0, 120)}...'
        : rawPreview;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _cachedPreview ?? computePreview(note.content);

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Handle via dialog
      },
      child: ListTile(
        title: Text(
          note.title.isEmpty ? 'Untitled' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _dateFormat.format(note.updatedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
