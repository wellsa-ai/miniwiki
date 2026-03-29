import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app/router.dart';
import 'src/app/theme.dart';
import 'src/core/providers/app_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MiniWikiApp()));
}

class MiniWikiApp extends ConsumerStatefulWidget {
  const MiniWikiApp({super.key});

  @override
  ConsumerState<MiniWikiApp> createState() => _MiniWikiAppState();
}

class _MiniWikiAppState extends ConsumerState<MiniWikiApp> {
  @override
  void initState() {
    super.initState();
    // Kick off app initialization after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appControllerProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'miniwiki',
      theme: MiniWikiTheme.light,
      darkTheme: MiniWikiTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
