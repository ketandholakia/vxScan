import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Loads settings from SharedPreferences once, then serves them in-memory.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppSettings.fromPrefs(prefs);
  }

  /// Applies [transform], persists the result and updates the state.
  ///
  /// Named `edit` because Riverpod 3's AsyncNotifier already defines an
  /// inherited `update`.
  Future<void> edit(AppSettings Function(AppSettings) transform) async {
    final AppSettings? current = state.value;
    if (current == null) {
      return;
    }
    final AppSettings next = transform(current);
    state = AsyncData<AppSettings>(next);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await next.saveTo(prefs);
  }
}

final AsyncNotifierProvider<SettingsController, AppSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Synchronous snapshot for widgets that must not rebuild on async churn;
/// falls back to defaults until settings have loaded.
final Provider<AppSettings> settingsOrDefaults = Provider<AppSettings>((ref) {
  return ref.watch(settingsProvider).value ?? const AppSettings();
});
