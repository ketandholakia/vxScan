import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/scanner/share_in.dart';
import 'l10n/generated/app_localizations.dart';

class VxScanApp extends ConsumerStatefulWidget {
  const VxScanApp({super.key});

  @override
  ConsumerState<VxScanApp> createState() => _VxScanAppState();
}

class _VxScanAppState extends ConsumerState<VxScanApp> {
  ShareInService? _shareIn;
  bool _routingToInbox = false;

  @override
  void initState() {
    super.initState();
    _shareIn = ShareInService(_onSharedMedia)..start();
    _applyRetention();
  }

  /// Deletes non-favorite scans past the configured retention window.
  Future<void> _applyRetention() async {
    final AppSettings settings =
        ref.read(settingsProvider).value ?? const AppSettings();
    final int? days = settings.retentionDays;
    if (days != null) {
      try {
        await ref.read(scanRepositoryProvider).purgeExpired(days);
      } on Exception {
        // Cleanup must never block startup.
      }
    }
  }

  void _onSharedMedia(List<String> paths) {
    ref.read(sharedPathsProvider.notifier).set(paths);
    if (!_routingToInbox && mounted) {
      _routingToInbox = true;
      appRouter.push('/inbox').whenComplete(() => _routingToInbox = false);
    }
  }

  @override
  void dispose() {
    _shareIn?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(settingsOrDefaults);
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)?.appTitle ?? 'vxScan',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: appRouter,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
