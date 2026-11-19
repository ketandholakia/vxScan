import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/scan_filter.dart';
import '../generator/barcode_export.dart' show shareFile;
import 'export_service.dart';

/// Export history (CSV/XLSX/PDF) and backup/restore the database.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _favoritesOnly = false;
  DateTime? _from;
  DateTime? _to;
  bool _busy = false;

  ScanFilter get _filter => ScanFilter(
        favoritesOnly: _favoritesOnly,
        from: _from,
        to: _to?.add(const Duration(days: 1)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export & backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('History export', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: const Text('Favorites only'),
            value: _favoritesOnly,
            onChanged: (bool v) => setState(() => _favoritesOnly = v),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: Text(_dateLabel()),
            trailing: _from == null && _to == null
                ? TextButton(onPressed: _pickRange, child: const Text('Set range'))
                : TextButton(onPressed: () => setState(() { _from = null; _to = null; }), child: const Text('Clear')),
          ),
          const SizedBox(height: 8),
          OverflowBar(
            alignment: MainAxisAlignment.spaceEvenly,
            spacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _busy ? null : () => _export(_ExportFormat.csv),
                icon: const Icon(Icons.table_view),
                label: const Text('CSV'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _export(_ExportFormat.xlsx),
                icon: const Icon(Icons.grid_on_outlined),
                label: const Text('XLSX'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _export(_ExportFormat.pdf),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Database backup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup to file'),
            subtitle: const Text('All scans, tags and sessions as JSON'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _backup,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replaces current history with the backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _restore,
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  String _dateLabel() {
    final DateFormat fmt = DateFormat('yyyy-MM-dd');
    if (_from == null && _to == null) {
      return 'All dates';
    }
    return '${_from == null ? '…' : fmt.format(_from!)} — ${_to == null ? '…' : fmt.format(_to!)}';
  }

  Future<void> _pickRange() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }

  Future<void> _export(_ExportFormat format) async {
    setState(() => _busy = true);
    try {
      final ExportService service =
          ExportService(ref.read(scanRepositoryProvider));
      // The scope picked above maps directly onto a ScanFilter.
      final List<Scan> filtered =
          await ref.read(scanRepositoryProvider).watchFiltered(_filter, limit: 100000).first;

      if (filtered.isEmpty) {
        _snack('Nothing to export with the current scope.');
        return;
      }
      final File file = switch (format) {
        _ExportFormat.csv => await service.exportCsv(filtered),
        _ExportFormat.xlsx => await service.exportXlsx(filtered),
        _ExportFormat.pdf => await service.exportPdf(filtered),
      };
      await shareFile(file);
    } on Exception catch (e) {
      _snack('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final bool ok =
          await ExportService(ref.read(scanRepositoryProvider)).backup();
      _snack(ok ? 'Backup saved.' : 'Backup cancelled.');
    } on Exception catch (e) {
      _snack('Backup failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restore() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'The current history will be replaced by the backup contents. '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      final int? count =
          await ExportService(ref.read(scanRepositoryProvider)).restore();
      if (count != null) {
        _snack('$count scans restored.');
      }
    } on Exception catch (e) {
      _snack('Restore failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ExportFormat { csv, xlsx, pdf }
