import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../ai/providers/ai_provider.dart';
import '../../notes/providers/notes_provider.dart';

import '../utils/content_converter.dart';
import '../utils/wikilink_parser.dart';
import '../widgets/tag_bar.dart';
import '../widgets/backlinks_panel.dart';
import '../widgets/webview_editor.dart';

class EditorPage extends ConsumerStatefulWidget {
  final String? noteId;
  const EditorPage({super.key, this.noteId});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late final TextEditingController _titleController;
  final GlobalKey<WebViewEditorState> _editorKey = GlobalKey();
  Timer? _autoSaveTimer;
  bool _isLoading = true;
  bool _isDirty = false;
  String _initialContent = '';
  String _currentHtml = '';
  String? _noteId;
  bool _isSaving = false;
  static const _autoSaveDelay = Duration(seconds: 3);

  bool get isNewNote => _noteId == null;

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _titleController = TextEditingController();
    _loadNote();
  }

  Future<void> _loadNote() async {
    if (!isNewNote) {
      final dao = ref.read(notesDaoProvider);
      final note = await dao.getNoteById(_noteId!);
      if (note != null) {
        _titleController.text = note.title;
        // Use contentBlocks if HTML, extract text from AppFlowy JSON, or use plain content
        if (note.contentBlocks != null && note.contentBlocks!.isNotEmpty) {
          final blocks = note.contentBlocks!;
          if (blocks.startsWith('{')) {
            _initialContent = appflowyJsonToHtml(blocks);
          } else {
            // HTML content (may or may not start with a tag)
            _initialContent = blocks;
          }
        }
        if (_initialContent.isEmpty && note.content.isNotEmpty) {
          _initialContent = plainTextToHtml(note.content);
        }
        _currentHtml = _initialContent;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      if (_isDirty && mounted) _saveNote();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveNote();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _buildTitleField(),
          actions: [
            if (_isDirty)
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  await _saveNote();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            PopupMenuButton<String>(
              onSelected: _onMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'tags',
                  child: ListTile(
                    leading: Icon(Icons.tag),
                    title: Text('Tags'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete'),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(isDark),
      ),
    );
  }

  Widget _buildTitleField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        hintText: 'Title',
        hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
        border: InputBorder.none,
      ),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
      onChanged: (_) {
        if (!_isDirty) setState(() => _isDirty = true);
        _scheduleAutoSave();
      },
    );
  }

  Widget _buildBody(bool isDark) {
    return Column(
      children: [
        if (!isNewNote) TagBar(noteId: _noteId!),
        Expanded(
          child: WebViewEditor(
            key: _editorKey,
            initialContent: _initialContent,
            isDarkMode: isDark,
            onContentChanged: (html) {
              _currentHtml = html;
              if (!_isDirty && mounted) setState(() => _isDirty = true);
              _scheduleAutoSave();
            },
          ),
        ),
        if (!isNewNote) BacklinksPanel(noteId: _noteId!),
      ],
    );
  }

  Future<void> _saveNote() async {
    if (!_isDirty && isNewNote && _titleController.text.isEmpty && _currentHtml.isEmpty) return;
    if (_isSaving) return;
    _isSaving = true;

    try {
      final controller = ref.read(notesControllerProvider);
      final title = _titleController.text;
      final plainText = htmlToPlainText(_currentHtml);

      // Create new note on first save
      if (isNewNote) {
        if (title.isEmpty && plainText.trim().isEmpty) return;
        _noteId = await controller.createNote(
          title: title.isEmpty ? 'Untitled' : title,
          content: plainText,
          contentBlocks: _currentHtml.isEmpty ? null : _currentHtml,
        );
      } else {
        await controller.updateNote(
          id: _noteId!,
          title: title.isEmpty ? 'Untitled' : title,
          content: plainText,
          contentBlocks: _currentHtml,
        );
      }

      await _syncWikilinks(plainText);
      await _syncHashtags(plainText);

      if (_noteId != null) {
        unawaited(
          ref
              .read(aiControllerProvider)
              .autoTagNote(_noteId!)
              .catchError((_) => <String>[]),
        );
      }

      if (mounted) setState(() => _isDirty = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _syncWikilinks(String content) async {
    if (_noteId == null) return;
    final wikilinks = extractWikilinks(content);
    if (wikilinks.isEmpty) return;

    final dao = ref.read(notesDaoProvider);
    final controller = ref.read(notesControllerProvider);
    for (final target in wikilinks) {
      final targetNote = await dao.getNoteByTitle(target);
      if (targetNote != null) {
        await controller.addWikilink(
          sourceId: _noteId!,
          targetId: targetNote.id,
          context: target,
        );
      }
    }
  }

  Future<void> _syncHashtags(String content) async {
    if (_noteId == null) return;
    final hashtags = extractHashtags(content);
    if (hashtags.isEmpty) return;

    final controller = ref.read(notesControllerProvider);
    for (final tag in hashtags) {
      await controller.addTag(noteId: _noteId!, tagName: tag);
    }
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'delete':
        _confirmDelete();
      case 'tags':
        break;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be moved to trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _noteId != null && mounted) {
      await ref.read(notesControllerProvider).deleteNote(_noteId!);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
