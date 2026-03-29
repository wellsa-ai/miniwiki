import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../notes/providers/notes_provider.dart';

class TagBar extends ConsumerWidget {
  final String noteId;
  const TagBar({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(noteTagsProvider(noteId));

    return tagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tags) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...tags.map((tag) => _TagChip(
                  tag: tag,
                  onDelete: () => ref
                      .read(notesControllerProvider)
                      .removeTag(noteId: noteId, tagId: tag.id),
                )),
            _AddTagButton(noteId: noteId),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback onDelete;

  const _TagChip({required this.tag, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = tag.color != null
        ? Color(int.parse(tag.color!, radix: 16) | 0xFF000000)
        : Theme.of(context).colorScheme.secondaryContainer;

    return Chip(
      label: Text(
        '#${tag.name}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      backgroundColor: color,
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDelete,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AddTagButton extends ConsumerStatefulWidget {
  final String noteId;
  const _AddTagButton({required this.noteId});

  @override
  ConsumerState<_AddTagButton> createState() => _AddTagButtonState();
}

class _AddTagButtonState extends ConsumerState<_AddTagButton> {
  bool _isEditing = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      return ActionChip(
        avatar: const Icon(Icons.add, size: 14),
        label: const Text('Tag', style: TextStyle(fontSize: 12)),
        onPressed: () => setState(() => _isEditing = true),
        visualDensity: VisualDensity.compact,
      );
    }

    return SizedBox(
      width: 120,
      child: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          hintText: 'tag name',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onSubmitted: _addTag,
        onTapOutside: (_) => setState(() => _isEditing = false),
      ),
    );
  }

  Future<void> _addTag(String name) async {
    final trimmed = name.trim().replaceAll('#', '');
    if (trimmed.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    try {
      await ref.read(notesControllerProvider).addTag(
            noteId: widget.noteId,
            tagName: trimmed,
          );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tag add failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }
}
