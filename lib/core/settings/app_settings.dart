import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_zxing/flutter_zxing.dart' show Format;

/// How the scanner behaves after each hit.
enum ScanMode { single, batch }

/// What to do when the same code is scanned twice in a batch session.
enum DuplicatePolicy { ignore, count, ask }

/// How long non-favorite scans are kept; null = forever.
enum Retention { forever, days30, days90, days365 }

/// User preferences, persisted in SharedPreferences.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.beepEnabled = true,
    this.vibrateEnabled = true,
    this.autoOpenLinks = false,
    this.defaultScanMode = ScanMode.single,
    this.duplicatePolicy = DuplicatePolicy.ignore,
    this.retention = Retention.forever,
    this.enabledFormats = Format.any,
    this.tryHarder = true,
    this.tryInverted = false,
  });

  final ThemeMode themeMode;
  final bool beepEnabled;
  final bool vibrateEnabled;
  final bool autoOpenLinks;
  final ScanMode defaultScanMode;
  final DuplicatePolicy duplicatePolicy;
  final Retention retention;

  /// zxing format bitmask restricts what the scanner decodes.
  final int enabledFormats;
  final bool tryHarder;
  final bool tryInverted;

  int? get retentionDays => switch (retention) {
        Retention.forever => null,
        Retention.days30 => 30,
        Retention.days90 => 90,
        Retention.days365 => 365,
      };

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? beepEnabled,
    bool? vibrateEnabled,
    bool? autoOpenLinks,
    ScanMode? defaultScanMode,
    DuplicatePolicy? duplicatePolicy,
    Retention? retention,
    int? enabledFormats,
    bool? tryHarder,
    bool? tryInverted,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        beepEnabled: beepEnabled ?? this.beepEnabled,
        vibrateEnabled: vibrateEnabled ?? this.vibrateEnabled,
        autoOpenLinks: autoOpenLinks ?? this.autoOpenLinks,
        defaultScanMode: defaultScanMode ?? this.defaultScanMode,
        duplicatePolicy: duplicatePolicy ?? this.duplicatePolicy,
        retention: retention ?? this.retention,
        enabledFormats: enabledFormats ?? this.enabledFormats,
        tryHarder: tryHarder ?? this.tryHarder,
        tryInverted: tryInverted ?? this.tryInverted,
      );

  static AppSettings fromPrefs(SharedPreferences prefs) => AppSettings(
        themeMode: _enumFromName(
          ThemeMode.values,
          prefs.getString(PrefKeys.themeMode),
          ThemeMode.system,
        ),
        beepEnabled: prefs.getBool(PrefKeys.beep) ?? true,
        vibrateEnabled: prefs.getBool(PrefKeys.vibrate) ?? true,
        autoOpenLinks: prefs.getBool(PrefKeys.autoOpen) ?? false,
        defaultScanMode: _enumFromName(
          ScanMode.values,
          prefs.getString(PrefKeys.scanMode),
          ScanMode.single,
        ),
        duplicatePolicy: _enumFromName(
          DuplicatePolicy.values,
          prefs.getString(PrefKeys.duplicate),
          DuplicatePolicy.ignore,
        ),
        retention: _enumFromName(
          Retention.values,
          prefs.getString(PrefKeys.retention),
          Retention.forever,
        ),
        enabledFormats: prefs.getInt(PrefKeys.formats) ?? Format.any,
        tryHarder: prefs.getBool(PrefKeys.tryHarder) ?? true,
        tryInverted: prefs.getBool(PrefKeys.tryInverted) ?? false,
      );

  Future<void> saveTo(SharedPreferences prefs) async {
    await prefs.setString(PrefKeys.themeMode, themeMode.name);
    await prefs.setBool(PrefKeys.beep, beepEnabled);
    await prefs.setBool(PrefKeys.vibrate, vibrateEnabled);
    await prefs.setBool(PrefKeys.autoOpen, autoOpenLinks);
    await prefs.setString(PrefKeys.scanMode, defaultScanMode.name);
    await prefs.setString(PrefKeys.duplicate, duplicatePolicy.name);
    await prefs.setString(PrefKeys.retention, retention.name);
    await prefs.setInt(PrefKeys.formats, enabledFormats);
    await prefs.setBool(PrefKeys.tryHarder, tryHarder);
    await prefs.setBool(PrefKeys.tryInverted, tryInverted);
  }

  static T _enumFromName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) =>
      values.where((T v) => v.name == name).firstOrNull ?? fallback;
}

abstract final class PrefKeys {
  static const String themeMode = 'theme_mode';
  static const String beep = 'beep_enabled';
  static const String vibrate = 'vibrate_enabled';
  static const String autoOpen = 'auto_open_links';
  static const String scanMode = 'default_scan_mode';
  static const String duplicate = 'duplicate_policy';
  static const String retention = 'history_retention';
  static const String formats = 'enabled_formats';
  static const String tryHarder = 'try_harder';
  static const String tryInverted = 'try_inverted';
}
