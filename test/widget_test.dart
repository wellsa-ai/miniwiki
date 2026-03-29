import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miniwiki/src/core/providers/app_providers.dart';

void main() {
  testWidgets('Splash screen shows app name', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith((ref) => AppState.uninitialized),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories, size: 64),
                  SizedBox(height: 16),
                  Text('miniwiki', style: TextStyle(fontSize: 24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('miniwiki'), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
  });
}
