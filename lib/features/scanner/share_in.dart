import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/di/providers.dart';
import '../../data/db/app_database.dart';
import '../../domain/decoding/barcode_decoder.dart';
import '../../domain/parsing/content_parser.dart';

/// Image file paths shared into the app from other apps (gallery, chat…),
/// pending decode on the inbox screen. Riverpod 3 has no StateProvider, so
/// this is a tiny Notifier.
class SharedPaths extends Notifier<List<String>> {
  @override
  List<String> build() => <String>[];

  void set(List<String> paths) => state = paths;
}

final NotifierProvider<SharedPaths, List<String>> sharedPathsProvider =
    NotifierProvider<SharedPaths, List<String>>(SharedPaths.new);

/// App-level listener for ACTION_SEND images. Registered once in [VxScanApp];
/// on arrival it parks the paths in [sharedPathsProvider] and reports the
/// route to push.
class ShareInService {
  ShareInService(this._onMedia);

  final void Function(List<String> paths) _onMedia;
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  void start() {
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> media) {
        final List<String> images = media
            .where((SharedMediaFile m) =>
                m.type == SharedMediaType.image && m.path.isNotEmpty)
            .map((SharedMediaFile m) => m.path)
            .toList(growable: false);
        if (images.isNotEmpty) {
          _onMedia(images);
        }
      },
    );
    // Cold start: app was launched by a share action.
    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> media) {
        final List<String> images = media
            .where((SharedMediaFile m) =>
                m.type == SharedMediaType.image && m.path.isNotEmpty)
            .map((SharedMediaFile m) => m.path)
            .toList(growable: false);
        if (images.isNotEmpty) {
          _onMedia(images);
        }
        ReceiveSharingIntent.instance.reset();
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}

/// Decode-and-save screen for shared images.
///
/// The paths are already parked in [sharedPathsProvider]; this screen decodes
/// every code in each image and inserts them into history (source 'share'),
/// then lists the results for the user to open.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _done = false;
  String? _error;
  final List<int> _ids = <int>[];
  final List<BarcodeRead> _reads = <BarcodeRead>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_decodeAndSave);
  }

  Future<void> _decodeAndSave() async {
    final List<String> paths = ref.read(sharedPathsProvider);
    if (paths.isEmpty) {
      setState(() => _error = 'Nothing was shared.');
      return;
    }
    try {
      final BarcodeDecoder decoder = ref.read(barcodeDecoderProvider);
      final List<BarcodeRead> found = <BarcodeRead>[];
      for (final String path in paths) {
        found.addAll(await decoder.decodeImageFile(path));
      }
      if (found.isEmpty) {
        setState(() => _error = 'No barcodes found in the shared image(s).');
        return;
      }
      for (final BarcodeRead read in found) {
        final ParsedContent parsed = parseScanContent(read.text, read.format);
        final int id = await ref.read(scanRepositoryProvider).insert(
              ScansCompanion.insert(
                rawText: read.text,
                rawBytes: Value(read.rawBytes),
                format: read.format,
                contentType: Value(parsed.type.storageName),
                parsedJson: Value(parsed.toJson()),
                source: 'share',
              ),
            );
        _ids.add(id);
        _reads.add(read);
      }
      setState(() => _done = true);
    } on Exception catch (e) {
      setState(() => _error = 'Could not read the shared image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared images')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : !_done
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: <Widget>[
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '${_reads.length} barcode${_reads.length == 1 ? '' : 's'} found — saved to history',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (int i = 0; i < _reads.length; i++)
                      ListTile(
                        leading: const Icon(Icons.qr_code_2),
                        title: Text(
                          _reads[i].text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_reads[i].formatName),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/result/${_ids[i]}'),
                      ),
                  ],
                ),
    );
  }
}
