import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../core/utils/hex.dart';
import '../../core/widgets/format_chip.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/scan_repository.dart';
import '../../domain/parsing/content_parser.dart';
import 'smart_actions.dart';

final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

final scanStreamProvider = StreamProvider.family<Scan?, int>(
  (ref, id) => ref.watch(scanRepositoryProvider).watchById(id),
);

/// Detail view of one saved scan: parsed fields, type-specific smart
/// actions, raw text, and the hex view for binary payloads.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.scanId});

  final int scanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Scan?> scan = ref.watch(scanStreamProvider(scanId));

    return Scaffold(
      appBar: AppBar(title: const Text('Scan result')),
      body: scan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => _ErrorView(message: '$error'),
        data: (Scan? scan) {
          if (scan == null) {
            return const _ErrorView(
              message: 'Scan not found. It may have been deleted.',
            );
          }
          return _ScanView(scan: scan);
        },
      ),
    );
  }
}

class _ScanView extends ConsumerWidget {
  const _ScanView({required this.scan});

  final Scan scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ParsedContent parsed =
        ParsedContent.fromJsonString(scan.parsedJson) ??
            ParsedContent.text(scan.rawText);
    final List<SmartAction> actions = actionsFor(parsed);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            FormatChip(format: scan.format),
            const SizedBox(width: 8),
            Icon(
              scan.source == 'camera'
                  ? Icons.photo_camera
                  : scan.source == 'share'
                      ? Icons.share
                      : Icons.photo_library,
              size: 18,
              color: theme.hintColor,
            ),
            const SizedBox(width: 4),
            Text(scan.source, style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(
              _dateFormat.format(scan.createdAt.toLocal()),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          parsed.type.label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 12),

        // Smart actions for the parsed payload type.
        if (actions.isNotEmpty) ...<Widget>[
          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8,
            overflowSpacing: 8,
            children: <Widget>[
              for (final SmartAction action in actions)
                FilledButton.tonalIcon(
                  onPressed: () => action.run(context),
                  icon: Icon(action.icon),
                  label: Text(action.label),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Structured fields, if the parser produced any.
        if (parsed.fields.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: <Widget>[
                  for (final MapEntry<String, List<String>> f
                      in parsed.fields.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 110,
                            child: Text(
                              _fieldLabel(f.key),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.hintColor),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              f.value.join('\n'),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Raw payload.
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              scan.rawText,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),

        // Note editor.
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: Text(scan.note == null || scan.note!.isEmpty
                ? 'Add a note'
                : scan.note!),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editNote(context, ref),
          ),
        ),

        // Tags editor.
        Card(
          child: ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Tags'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTags(context, ref),
          ),
        ),

        if (scan.rawBytes != null && scan.rawBytes!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text('Raw bytes (${scan.rawBytes!.length})',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                toHex(scan.rawBytes!),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _fieldLabel(String key) {
    final String spaced = key
        .replaceAllMapped(RegExp(r'[A-Z]'), (Match m) => ' ${m[0]}')
        .trim();
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController(text: scan.note);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What was this scan about?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(scanRepositoryProvider)
          .setNote(scan.id, result.isEmpty ? null : result);
    }
  }

  Future<void> _editTags(BuildContext context, WidgetRef ref) async {
    final ScanRepository repo = ref.read(scanRepositoryProvider);
    final List<Tag> all = await repo.allTags();
    final Set<int> current =
        (await repo.tagsForScan(scan.id)).map((Tag t) => t.id).toSet();

    if (!context.mounted) {
      return;
    }
    final Set<int>? result = await showDialog<Set<int>>(
      context: context,
      builder: (BuildContext dialogContext) => _TagPicker(
        tags: all,
        selected: current,
      ),
    );
    if (result != null) {
      await repo.setScanTags(scan.id, result);
    }
  }
}

/// Multi-select tag picker with inline creation.
class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({required this.tags, required this.selected});

  final List<Tag> tags;
  final Set<int> selected;

  @override
  ConsumerState<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<_TagPicker> {
  final Set<int> _selected = <int>{};
  List<Tag> _tags = const <Tag>[];

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.selected);
    _tags = List<Tag>.of(widget.tags);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tags'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final Tag tag in _tags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: _selected.contains(tag.id),
                      onSelected: (bool selected) {
                        setState(() => selected
                            ? _selected.add(tag.id)
                            : _selected.remove(tag.id));
                      },
                    ),
                  if (_tags.isEmpty)
                    const Text('No tags yet — create one below.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _newTagController,
                    decoration: const InputDecoration(
                      hintText: 'New tag',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createTag,
                ),
              ],
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
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Save'),
        ),
      ],
    );
  }

  final TextEditingController _newTagController = TextEditingController();

  Future<void> _createTag() async {
    final String name = _newTagController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final int id = await ref.read(scanRepositoryProvider).ensureTag(name);
    setState(() {
      _tags = <Tag>[
        ..._tags,
        Tag(id: id, name: name),
      ];
      _selected.add(id);
      _newTagController.clear();
    });
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
