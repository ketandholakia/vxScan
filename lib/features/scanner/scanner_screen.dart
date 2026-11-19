import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart' as zxing;
import 'package:flutter_zxing/flutter_zxing.dart' show Format;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/providers.dart';
import '../../core/services/scan_feedback.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_providers.dart';
import '../../data/db/app_database.dart';
import '../../domain/decoding/barcode_decoder.dart';
import '../../domain/parsing/content_parser.dart';

/// Live camera scanner.
///
/// Two modes: single (first hit opens the result) and batch/continuous
/// (scans accumulate in a session with a duplicate policy). Gallery picks
/// decode every code in the image, not just the first.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  ScanMode _mode = ScanMode.single;
  Session? _session;
  int _batchCount = 0;
  final Set<String> _seenInSession = <String>{};
  bool _pickingGallery = false;

  @override
  void initState() {
    super.initState();
    // Start in the mode stored in settings (may still be loading).
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final AppSettings settings =
          ref.read(settingsProvider).value ?? const AppSettings();
      setState(() => _mode = settings.defaultScanMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(settingsOrDefaults);
    return Scaffold(
      appBar: AppBar(
        title: const Text('vxScan'),
        actions: <Widget>[
          IconButton(
            tooltip: _mode == ScanMode.single
                ? 'Switch to batch scan'
                : 'Finish batch session',
            icon: Icon(_mode == ScanMode.single
                ? Icons.filter_none
                : Icons.all_inclusive),
            onPressed: _toggleMode,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Generate',
            onPressed: () => context.push('/generate'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'spike',
                child: Text('Engine round-trip test'),
              ),
              const PopupMenuItem<String>(
                value: 'created',
                child: Text('Created codes'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          zxing.ReaderWidget(
            onScan: (zxing.Code result) => _onScan(result, settings),
            codeFormat: settings.enabledFormats,
            tryHarder: settings.tryHarder,
            tryInverted: settings.tryInverted,
            allowPinchZoom: true,
            showFlashlight: true,
            // Gallery decoding uses our own multi-code flow.
            showGallery: false,
            showToggleCamera: true,
            cropPercent: _mode == ScanMode.single ? 0.7 : 1.0,
          ),
          if (_mode == ScanMode.batch)
            _BatchBanner(session: _session, count: _batchCount, onEnd: _toggleMode),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'gallery',
        tooltip: 'Scan image from gallery',
        onPressed: _pickingGallery ? null : _pickAndDecode,
        child: const Icon(Icons.photo_library_outlined),
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'spike':
        context.push('/spike');
      case 'created':
        context.push('/generated');
    }
  }

  Future<void> _toggleMode() async {
    if (_mode == ScanMode.batch) {
      final int count = _batchCount;
      final String? name = _session?.name;
      await ref.read(scanRepositoryProvider).endSession(_session!.id);
      setState(() {
        _mode = ScanMode.single;
        _session = null;
        _batchCount = 0;
        _seenInSession.clear();
      });
      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count scans saved to “$name”')),
        );
      }
      return;
    }
    // Entering batch mode opens a session that collects scans.
    final DateTime now = DateTime.now();
    final Session session = await ref
        .read(scanRepositoryProvider)
        .createSession('Batch ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
    setState(() {
      _mode = ScanMode.batch;
      _session = session;
      _batchCount = 0;
      _seenInSession.clear();
    });
  }

  Future<void> _onScan(zxing.Code result, AppSettings settings) async {
    final String? text = result.text;
    if (!result.isValid || text == null || text.isEmpty) {
      return;
    }

    if (_mode == ScanMode.batch) {
      await _onBatchScan(text, result, settings);
      return;
    }

    final ParsedContent parsed =
        parseScanContent(text, result.format ?? Format.none);
    final int id = await _saveScan(text, result, null, parsed);
    await ref.read(scanFeedbackProvider).success();
    _maybeAutoOpen(parsed, settings);
    if (mounted) {
      context.push('/result/$id');
    }
  }

  Future<void> _onBatchScan(
    String text,
    zxing.Code result,
    AppSettings settings,
  ) async {
    final Session? session = _session;
    if (session == null) {
      return;
    }
    if (_seenInSession.contains(text)) {
      switch (settings.duplicatePolicy) {
        case DuplicatePolicy.ignore:
          return;
        case DuplicatePolicy.ask:
          final bool add = await _askDuplicate(text) ?? false;
          if (!add || !mounted) {
            return;
          }
        case DuplicatePolicy.count:
          break;
      }
    }
    _seenInSession.add(text);
    await _saveScan(
      text,
      result,
      session.id,
      parseScanContent(text, result.format ?? Format.none),
    );
    await ref.read(scanFeedbackProvider).success();
    if (mounted) {
      setState(() => _batchCount += 1);
    }
  }

  Future<bool?> _askDuplicate(String text) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Duplicate scan'),
        content: Text(
          '“${_short(text)}” was already scanned in this batch. Add it again?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<int> _saveScan(
    String text,
    zxing.Code result,
    int? sessionId,
    ParsedContent parsed,
  ) {
    return ref.read(scanRepositoryProvider).insert(
          ScansCompanion.insert(
            rawText: text,
            rawBytes: Value(result.rawBytes),
            format: result.format ?? Format.none,
            contentType: Value(parsed.type.storageName),
            parsedJson: Value(parsed.toJson()),
            source:
                result.source == zxing.CodeSource.camera ? 'camera' : 'gallery',
            sessionId: Value(sessionId),
          ),
        );
  }

  /// With the setting on, URLs open in the browser right away.
  Future<void> _maybeAutoOpen(ParsedContent parsed, AppSettings settings) async {
    if (!settings.autoOpenLinks || parsed.type != ContentType.url) {
      return;
    }
    final String? raw = parsed.first('url');
    if (raw == null) {
      return;
    }
    final Uri uri = Uri.parse(
      raw.startsWith('http') ? raw : 'https://$raw',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on Exception {
      // Never let auto-open break scanning.
    }
  }

  /// Gallery import: decode every code in the picked image.
  Future<void> _pickAndDecode() async {
    setState(() => _pickingGallery = true);
    try {
      final XFile? file =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) {
        return;
      }
      final List<BarcodeRead> found =
          await ref.read(barcodeDecoderProvider).decodeImageFile(file.path);
      if (found.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No barcodes found in the image')),
          );
        }
        return;
      }
      final List<int> ids = <int>[];
      for (final BarcodeRead read in found) {
        final ParsedContent parsed = parseScanContent(read.text, read.format);
        final int id = await ref.read(scanRepositoryProvider).insert(
              ScansCompanion.insert(
                rawText: read.text,
                rawBytes: Value(read.rawBytes),
                format: read.format,
                contentType: Value(parsed.type.storageName),
                parsedJson: Value(parsed.toJson()),
                source: 'gallery',
              ),
            );
        ids.add(id);
      }
      await ref.read(scanFeedbackProvider).success();
      if (mounted) {
        await _showGalleryResults(ids, found);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingGallery = false);
      }
    }
  }

  Future<void> _showGalleryResults(List<int> ids, List<BarcodeRead> found) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${found.length} barcode${found.length == 1 ? '' : 's'} found — saved to history',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (int i = 0; i < found.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.qr_code_2),
                title: Text(
                  found[i].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(found[i].formatName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/result/${ids[i]}');
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _short(String text) =>
    text.length <= 40 ? text : '${text.substring(0, 37)}…';

/// Batch-mode status chip pinned over the camera preview.
class _BatchBanner extends StatelessWidget {
  const _BatchBanner({
    required this.session,
    required this.count,
    required this.onEnd,
  });

  final Session? session;
  final int count;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 88,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .inverseSurface
              .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.all_inclusive, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count scanned — tap ✓ to finish this batch',
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Finish batch',
              onPressed: onEnd,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
