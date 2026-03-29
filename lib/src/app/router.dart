import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/app_providers.dart';
import '../features/notes/views/notes_list_page.dart';
import '../features/editor/views/editor_page.dart';
import '../features/search/views/search_page.dart';
import '../features/settings/views/settings_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final appState = ref.watch(appStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (appState == AppState.uninitialized) return '/splash';
      if (appState == AppState.locked) return '/lock';
      if (state.matchedLocation == '/splash' ||
          state.matchedLocation == '/lock') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashPage(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const _LockPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const NotesListPage(),
      ),
      GoRoute(
        path: '/note/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditorPage(noteId: id);
        },
      ),
      GoRoute(
        path: '/new',
        builder: (context, state) => const EditorPage(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Splash (initializing)
// ---------------------------------------------------------------------------

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories, size: 64),
            SizedBox(height: 16),
            Text('miniwiki', style: TextStyle(fontSize: 24)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lock Screen (placeholder — will add biometric later)
// ---------------------------------------------------------------------------

class _LockPage extends ConsumerStatefulWidget {
  const _LockPage();

  @override
  ConsumerState<_LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<_LockPage> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              const Text('miniwiki', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _unlock,
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final success =
        await ref.read(appControllerProvider).unlock(_controller.text);
    if (!success && mounted) {
      setState(() => _error = 'Wrong password');
    }
  }
}
