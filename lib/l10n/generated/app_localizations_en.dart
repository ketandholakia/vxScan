// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'vxScan';

  @override
  String get historyEmpty =>
      'Nothing scanned yet.\nPoint the camera at a barcode!';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get scanDeleted => 'Scan deleted';

  @override
  String get undo => 'Undo';

  @override
  String get privacyNote =>
      'Offline-first. Camera is the only permission; scans never leave this device.';
}
