import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart' show Format;
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_providers.dart';

/// App settings: appearance, feedback, scanning defaults, retention and the
/// enabled-format filter. Everything persists via SharedPreferences.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings =
        ref.watch(settingsOrDefaults);
    final SettingsController controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              items: const <DropdownMenuItem<ThemeMode>>[
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
              onChanged: (ThemeMode? mode) =>
                  controller.edit((AppSettings s) => s.copyWith(themeMode: mode)),
            ),
          ),

          _SectionHeader('Scan feedback'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Beep on scan'),
            value: settings.beepEnabled,
            onChanged: (bool v) =>
                controller.edit((AppSettings s) => s.copyWith(beepEnabled: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_outlined),
            title: const Text('Vibrate on scan'),
            value: settings.vibrateEnabled,
            onChanged: (bool v) => controller
                .edit((AppSettings s) => s.copyWith(vibrateEnabled: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.link),
            title: const Text('Auto-open links'),
            subtitle: const Text('Opens scanned URLs in the browser right away'),
            value: settings.autoOpenLinks,
            onChanged: (bool v) =>
                controller.edit((AppSettings s) => s.copyWith(autoOpenLinks: v)),
          ),

          _SectionHeader('Scanning'),
          ListTile(
            leading: const Icon(Icons.filter_none),
            title: const Text('Default scan mode'),
            trailing: DropdownButton<ScanMode>(
              value: settings.defaultScanMode,
              items: const <DropdownMenuItem<ScanMode>>[
                DropdownMenuItem<ScanMode>(value: ScanMode.single, child: Text('Single')),
                DropdownMenuItem<ScanMode>(value: ScanMode.batch, child: Text('Batch')),
              ],
              onChanged: (ScanMode? mode) => controller
                  .edit((AppSettings s) => s.copyWith(defaultScanMode: mode)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Duplicate scans in batch'),
            trailing: DropdownButton<DuplicatePolicy>(
              value: settings.duplicatePolicy,
              items: const <DropdownMenuItem<DuplicatePolicy>>[
                DropdownMenuItem<DuplicatePolicy>(
                  value: DuplicatePolicy.ignore,
                  child: Text('Ignore'),
                ),
                DropdownMenuItem<DuplicatePolicy>(
                  value: DuplicatePolicy.count,
                  child: Text('Count again'),
                ),
                DropdownMenuItem<DuplicatePolicy>(
                  value: DuplicatePolicy.ask,
                  child: Text('Ask'),
                ),
              ],
              onChanged: (DuplicatePolicy? p) =>
                  controller.edit((AppSettings s) => s.copyWith(duplicatePolicy: p)),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.manage_search),
            title: const Text('Try harder'),
            subtitle: const Text('Slower, more thorough decoding for damaged codes'),
            value: settings.tryHarder,
            onChanged: (bool v) =>
                controller.edit((AppSettings s) => s.copyWith(tryHarder: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.invert_colors),
            title: const Text('Try inverted'),
            subtitle: const Text('Detect codes with inverted colors'),
            value: settings.tryInverted,
            onChanged: (bool v) =>
                controller.edit((AppSettings s) => s.copyWith(tryInverted: v)),
          ),
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('Enabled formats'),
            subtitle: Text(_formatSummary(settings.enabledFormats)),
            onTap: () => _pickFormats(context, controller, settings),
          ),

          _SectionHeader('History'),
          ListTile(
            leading: const Icon(Icons.auto_delete_outlined),
            title: const Text('Keep scans'),
            subtitle: const Text('Favorites are never removed'),
            trailing: DropdownButton<Retention>(
              value: settings.retention,
              items: const <DropdownMenuItem<Retention>>[
                DropdownMenuItem<Retention>(value: Retention.forever, child: Text('Forever')),
                DropdownMenuItem<Retention>(value: Retention.days30, child: Text('30 days')),
                DropdownMenuItem<Retention>(value: Retention.days90, child: Text('90 days')),
                DropdownMenuItem<Retention>(value: Retention.days365, child: Text('1 year')),
              ],
              onChanged: (Retention? r) =>
                  controller.edit((AppSettings s) => s.copyWith(retention: r)),
            ),
          ),

          _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export history'),
            onTap: () => context.push('/export'),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup'),
            subtitle: const Text('Save every scan and tag to a JSON file'),
            onTap: () => context.push('/export'),
          ),

          _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('vxScan'),
            subtitle: Text(
              'Offline-first. Camera is the only permission; scans never '
              'leave this device.',
            ),
          ),
        ],
      ),
    );
  }

  String _formatSummary(int mask) {
    if (mask == Format.any) {
      return 'All supported formats';
    }
    final List<String> names = <String>[];
    for (final MapEntry<int, String> entry in _namedFormats.entries) {
      if (mask & entry.key != 0) {
        names.add(entry.value);
      }
    }
    return names.isEmpty ? 'All supported formats' : names.join(', ');
  }

  Future<void> _pickFormats(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _FormatPicker(initial: settings.enabledFormats),
    ).then((Object? mask) {
      if (mask is int) {
        controller.edit((AppSettings s) => s.copyWith(enabledFormats: mask));
      }
    });
  }
}

const Map<int, String> _namedFormats = <int, String>{
  Format.qrCode: 'QR Code',
  Format.dataMatrix: 'Data Matrix',
  Format.aztec: 'Aztec',
  Format.pdf417: 'PDF417',
  Format.code128: 'Code 128',
  Format.code39: 'Code 39',
  Format.code93: 'Code 93',
  Format.codabar: 'Codabar',
  Format.itf: 'ITF',
  Format.ean13: 'EAN-13',
  Format.ean8: 'EAN-8',
  Format.upca: 'UPC-A',
  Format.upce: 'UPC-E',
  Format.dataBar: 'GS1 DataBar',
  Format.dataBarExpanded: 'GS1 DataBar Expanded',
};

class _FormatPicker extends StatefulWidget {
  const _FormatPicker({required this.initial});

  final int initial;

  @override
  State<_FormatPicker> createState() => _FormatPickerState();
}

class _FormatPickerState extends State<_FormatPicker> {
  late final Map<int, bool> _selected = <int, bool>{
    for (final int f in _namedFormats.keys)
      f: widget.initial == Format.any || widget.initial & f != 0,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Formats to scan for'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final MapEntry<int, String> e in _namedFormats.entries)
              CheckboxListTile(
                dense: true,
                title: Text(e.value),
                value: _selected[e.key],
                onChanged: (bool? v) => setState(() => _selected[e.key] = v ?? false),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final int mask =
                _selected.entries.where((MapEntry<int, bool> e) => e.value).fold(
                      0,
                      (int acc, MapEntry<int, bool> e) => acc | e.key,
                    );
            Navigator.of(context).pop(mask == 0 ? Format.any : mask);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
