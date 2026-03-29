import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../notes/providers/notes_provider.dart';

class BacklinksPanel extends ConsumerWidget {
  final String noteId;
  const BacklinksPanel({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backlinksAsync = ref.watch(noteBacklinksProvider(noteId));

    return backlinksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Backlinks error: $err',
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
      ),
      data: (links) {
        if (links.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.link,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 8),
                  Text(
                    'Backlinks (${links.length})',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...links.map((link) => _BacklinkTile(
                    sourceNoteId: link.sourceId,
                    context: link.context,
                    onTap: () => context.push('/note/${link.sourceId}'),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _BacklinkTile extends ConsumerWidget {
  final String sourceNoteId;
  final String? context;
  final VoidCallback onTap;

  const _BacklinkTile({
    required this.sourceNoteId,
    this.context,
    required this.onTap,
  });

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final noteAsync = ref.watch(noteByIdProvider(sourceNoteId));

    return noteAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (note) {
        if (note == null) return const SizedBox.shrink();
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            note.title.isEmpty ? 'Untitled' : note.title,
            style: ctx.mounted
                ? Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.primary,
                    )
                : null,
          ),
          subtitle: context != null
              ? Text(context!,
                  maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          onTap: onTap,
        );
      },
    );
  }
}
