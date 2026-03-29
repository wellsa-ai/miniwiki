import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ListView(
          children: [
            // --- Security ---
            const _SectionHeader(title: 'Security'),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Set Password'),
              subtitle: const Text('Encrypt your wiki'),
              onTap: () => _showSetPasswordDialog(context, ref),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Biometric Unlock'),
              subtitle: const Text('Face ID / Touch ID'),
              value: settings.biometricUnlock,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setBiometricUnlock(v),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock Now'),
              onTap: () => ref.read(appControllerProvider).lock(),
            ),

            // --- AI ---
            const _SectionHeader(title: 'AI'),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('Auto Tagging'),
              subtitle: const Text('AI suggests tags when saving'),
              value: settings.autoTagEnabled,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setAutoTag(v),
            ),

            // --- Appearance ---
            const _SectionHeader(title: 'Appearance'),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: Text(settings.themeMode),
              onTap: () => _showThemePicker(context, ref, settings.themeMode),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Font Size'),
              subtitle: Text(settings.fontSize),
              onTap: () =>
                  _showFontSizePicker(context, ref, settings.fontSize),
            ),

            // --- Data ---
            const _SectionHeader(title: 'Data'),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export All Notes'),
              subtitle: const Text('Markdown files'),
              onTap: () => _exportNotes(context, ref),
            ),

            // --- About ---
            const _SectionHeader(title: 'About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('miniwiki v0.1.0'),
              subtitle: Text('Privacy-first personal wiki'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetPasswordDialog(
      BuildContext context, WidgetRef ref) async {
    final appController = ref.read(appControllerProvider);
    final passwordExists = await appController.hasPassword();

    // If a password already exists, verify the current password first
    if (passwordExists && context.mounted) {
      final verified = await _showVerifyCurrentPasswordDialog(
          context, ref, appController);
      if (!verified || !context.mounted) return;
    }

    if (!context.mounted) return;

    final controller = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(passwordExists ? 'Change Password' : 'Set Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text == confirmController.text &&
                  controller.text.isNotEmpty) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      // Validate password
      if (!_validatePassword(result)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password must be at least 8 characters'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      try {
        await appController.setPassword(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password set successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to set password: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Shows a dialog to verify the current password.
  /// Returns true if verification succeeded, false otherwise.
  Future<bool> _showVerifyCurrentPasswordDialog(
      BuildContext context, WidgetRef ref, AppController appController) async {
    final currentPasswordController = TextEditingController();
    String? errorText;

    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Verify Current Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final success = await appController
                    .unlock(currentPasswordController.text);
                if (success) {
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } else {
                  setState(() {
                    errorText = 'Incorrect password';
                  });
                }
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );

    return verified == true;
  }

  void _showThemePicker(
      BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ['system', 'light', 'dark'])
              ListTile(
                title: Text(mode[0].toUpperCase() + mode.substring(1)),
                trailing: current == mode
                    ? const Icon(Icons.check, size: 20)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showFontSizePicker(
      BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final size in ['small', 'medium', 'large'])
              ListTile(
                title: Text(size[0].toUpperCase() + size.substring(1)),
                trailing: current == size
                    ? const Icon(Icons.check, size: 20)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setFontSize(size);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportNotes(BuildContext context, WidgetRef ref) async {
    // TODO: Implement markdown export via file_picker
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export coming soon')),
      );
    }
  }

  /// Validate password strength
  bool _validatePassword(String password) {
    // Minimum 8 characters
    if (password.length < 8) return false;
    // At least one uppercase, one lowercase, one digit (recommended)
    // For now, just enforce length
    return true;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
