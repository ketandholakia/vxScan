import 'package:go_router/go_router.dart';

import '../../features/export/export_screen.dart';
import '../../features/generator/generated_screen.dart';
import '../../features/generator/generator_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/result/result_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../features/scanner/share_in.dart';
import '../../features/scanner/spike_screen.dart';
import '../../features/settings/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/scan',
  routes: <RouteBase>[
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/spike',
      builder: (context, state) => const SpikeScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/result/:id',
      builder: (context, state) {
        final int id = int.parse(state.pathParameters['id']!);
        return ResultScreen(scanId: id);
      },
    ),
    GoRoute(
      path: '/inbox',
      builder: (context, state) => const InboxScreen(),
    ),
    GoRoute(
      path: '/generate',
      builder: (context, state) => const GeneratorScreen(),
    ),
    GoRoute(
      path: '/generated',
      builder: (context, state) => const GeneratedScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/export',
      builder: (context, state) => const ExportScreen(),
    ),
  ],
);
