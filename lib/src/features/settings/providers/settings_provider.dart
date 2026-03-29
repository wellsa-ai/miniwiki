import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/providers/app_providers.dart';

// ---------------------------------------------------------------------------
// Settings Keys
// ---------------------------------------------------------------------------

class SettingsKeys {
  static const autoTag = 'settings_auto_tag';
  static const biometricUnlock = 'settings_biometric';
  static const themeMode = 'settings_theme'; // 'system', 'light', 'dark'
  static const fontSize = 'settings_font_size'; // 'small', 'medium', 'large'
}

// ---------------------------------------------------------------------------
// Settings Provider
// ---------------------------------------------------------------------------

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class AppSettings {
  final bool autoTagEnabled;
  final bool biometricUnlock;
  final String themeMode;
  final String fontSize;

  const AppSettings({
    this.autoTagEnabled = true,
    this.biometricUnlock = false,
    this.themeMode = 'system',
    this.fontSize = 'medium',
  });

  AppSettings copyWith({
    bool? autoTagEnabled,
    bool? biometricUnlock,
    String? themeMode,
    String? fontSize,
  }) {
    return AppSettings(
      autoTagEnabled: autoTagEnabled ?? this.autoTagEnabled,
      biometricUnlock: biometricUnlock ?? this.biometricUnlock,
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  Future<AppSettings> build() async {
    final autoTag = await _storage.read(key: SettingsKeys.autoTag);
    final biometric = await _storage.read(key: SettingsKeys.biometricUnlock);
    final theme = await _storage.read(key: SettingsKeys.themeMode);
    final font = await _storage.read(key: SettingsKeys.fontSize);

    return AppSettings(
      autoTagEnabled: autoTag != 'false',
      biometricUnlock: biometric == 'true',
      themeMode: theme ?? 'system',
      fontSize: font ?? 'medium',
    );
  }

  Future<void> setAutoTag(bool enabled) async {
    await _storage.write(
        key: SettingsKeys.autoTag, value: enabled.toString());
    state = AsyncData(state.requireValue.copyWith(autoTagEnabled: enabled));
  }

  Future<void> setBiometricUnlock(bool enabled) async {
    await _storage.write(
        key: SettingsKeys.biometricUnlock, value: enabled.toString());
    state = AsyncData(state.requireValue.copyWith(biometricUnlock: enabled));
  }

  Future<void> setThemeMode(String mode) async {
    await _storage.write(key: SettingsKeys.themeMode, value: mode);
    state = AsyncData(state.requireValue.copyWith(themeMode: mode));
  }

  Future<void> setFontSize(String size) async {
    await _storage.write(key: SettingsKeys.fontSize, value: size);
    state = AsyncData(state.requireValue.copyWith(fontSize: size));
  }
}
