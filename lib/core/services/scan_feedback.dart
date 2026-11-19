import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../settings/app_settings.dart';
import '../settings/settings_providers.dart';

/// Haptic + audio feedback for a successful scan.
///
/// Holds one long-lived [AudioPlayer]; beeps are cheap and never fatal —
/// any failure is swallowed so scanning keeps working.
class ScanFeedback {
  ScanFeedback(this._ref) {
    try {
      _player.setReleaseMode(ReleaseMode.stop);
    } on Exception {
      // Audio is optional feedback.
    }
  }

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();

  Future<void> success() async {
    final AppSettings settings =
        _ref.read(settingsProvider).value ?? const AppSettings();
    if (settings.beepEnabled) {
      try {
        await _player.play(AssetSource('sounds/beep.wav'));
      } on Exception {
        // Audio is optional feedback.
      }
    }
    if (settings.vibrateEnabled) {
      try {
        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 40);
        }
      } on Exception {
        // Haptics are optional feedback.
      }
    }
  }

  /// The player is app-lifetime; nothing to dispose per screen.
}

final Provider<ScanFeedback> scanFeedbackProvider =
    Provider<ScanFeedback>((Ref ref) => ScanFeedback(ref));
