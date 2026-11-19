import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../core/widgets/format_chip.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/scan_filter.dart';
import '../../domain/parsing/content_parser.dart';

final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

/// Scanning history: live list, FTS search, filters (format / type / date /
/// favorites / tag), multi-select with delete, swipe-to-delete with undo.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  ScanFilter _filter = const ScanFilter();
  final Set<int> _selected = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool selecting = _selected.isNotEmpty;
    final bool filtered = !_filter.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(selecting ? '${_selected.length} selected' : 'History'),
        actions: selecting
            ? <Widget>[
                IconButton(
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteSelected,
                ),
                IconButton(
                  tooltip: 'Export selected',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => context.push('/export'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('Cancel'),
                ),
              ]
            : <Widget>[
                IconButton(
                  tooltip: 'Filter',
                  icon: Badge(
                    isLabelVisible: filtered,
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: _openFilters,
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                hintText: 'Search scans…',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (String value) => setState(() => _query = value.trim()),
            ),
          ),
        ),
      ),
      body: _query.isEmpty
          ? _LiveList(
              filter: _filter,
              selecting: selecting,
              selected: _selected,
              onTapItem: _onTap,
              onLongPressItem: _onLongPress,
              onDeleteItem: _deleteWithUndo,
              onFavoriteItem: _toggleFavorite,
            )
          : _SearchResults(
              query: _query,
              filter: _filter,
              selecting: selecting,
              selected: _selected,
              onTapItem: _onTap,
              onLongPressItem: _onLongPress,
              onDeleteItem: _deleteWithUndo,
              onFavoriteItem: _toggleFavorite,
            ),
    );
  }

  void _onTap(Scan scan) {
    if (_selected.isNotEmpty) {
      setState(() => _selected.contains(scan.id)
          ? _selected.remove(scan.id)
          : _selected.add(scan.id));
      return;
    }
    context.push('/result/${scan.id}');
  }

  void _onLongPress(Scan scan) {
    setState(() => _selected.add(scan.id));
  }

  Future<void> _toggleFavorite(Scan scan) async {
    await ref
        .read(scanRepositoryProvider)
        .setFavorite(scan.id, !scan.isFavorite);
  }

  Future<void> _deleteSelected() async {
    final int n = _selected.length;
    await ref.read(scanRepositoryProvider).removeAll(_selected);
    if (!mounted) {
      return;
    }
    setState(() => _selected.clear());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$n scans deleted')));
  }

  Future<void> _deleteWithUndo(Scan scan) async {
    await ref.read(scanRepositoryProvider).remove(scan.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Scan deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Re-inserting keeps every field but gets a new id.
            ref.read(scanRepositoryProvider).insert(
                  ScansCompanion.insert(
                    rawText: scan.rawText,
                    rawBytes: Value(scan.rawBytes),
                    format: scan.format,
                    contentType: Value(scan.contentType),
                    parsedJson: Value(scan.parsedJson),
                    source: scan.source,
                    createdAt: Value(scan.createdAt),
                    isFavorite: Value(scan.isFavorite),
                    note: Value(scan.note),
                    sessionId: Value(scan.sessionId),
                  ),
                );
          },
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    final ScanFilter? result = await showModalBottomSheet<ScanFilter>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _FilterSheet(initial: _filter),
    );
    if (result != null) {
      setState(() => _filter = result);
    }
  }
}

/// Live-streamed list for the unfiltered/unsearched case.
class _LiveList extends ConsumerWidget {
  const _LiveList({
    required this.filter,
    required this.selecting,
    required this.selected,
    required this.onTapItem,
    required this.onLongPressItem,
    required this.onDeleteItem,
    required this.onFavoriteItem,
  });

  final ScanFilter filter;
  final bool selecting;
  final Set<int> selected;
  final void Function(Scan) onTapItem;
  final void Function(Scan) onLongPressItem;
  final Future<void> Function(Scan) onDeleteItem;
  final Future<void> Function(Scan) onFavoriteItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Stream<List<Scan>> stream = ref
        .read(scanRepositoryProvider)
        .watchFiltered(filter);
    return StreamBuilder<List<Scan>>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<List<Scan>> snapshot) {
        final List<Scan>? scans = snapshot.data;
        if (scans == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _ScanListBody(
          scans: scans,
          selecting: selecting,
          selected: selected,
          onTapItem: onTapItem,
          onLongPressItem: onLongPressItem,
          onDeleteItem: onDeleteItem,
          onFavoriteItem: onFavoriteItem,
        );
      },
    );
  }
}

/// FTS search results.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.filter,
    required this.selecting,
    required this.selected,
    required this.onTapItem,
    required this.onLongPressItem,
    required this.onDeleteItem,
    required this.onFavoriteItem,
  });

  final String query;
  final ScanFilter filter;
  final bool selecting;
  final Set<int> selected;
  final void Function(Scan) onTapItem;
  final void Function(Scan) onLongPressItem;
  final Future<void> Function(Scan) onDeleteItem;
  final Future<void> Function(Scan) onFavoriteItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Scan>>(
      future: ref.read(scanRepositoryProvider).search(query, filter: filter),
      builder: (BuildContext context, AsyncSnapshot<List<Scan>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _ScanListBody(
          scans: snapshot.data ?? const <Scan>[],
          selecting: selecting,
          selected: selected,
          onTapItem: onTapItem,
          onLongPressItem: onLongPressItem,
          onDeleteItem: onDeleteItem,
          onFavoriteItem: onFavoriteItem,
        );
      },
    );
  }
}

class _ScanListBody extends StatelessWidget {
  const _ScanListBody({
    required this.scans,
    required this.selecting,
    required this.selected,
    required this.onTapItem,
    required this.onLongPressItem,
    required this.onDeleteItem,
    required this.onFavoriteItem,
  });

  final List<Scan> scans;
  final bool selecting;
  final Set<int> selected;
  final void Function(Scan) onTapItem;
  final void Function(Scan) onLongPressItem;
  final Future<void> Function(Scan) onDeleteItem;
  final Future<void> Function(Scan) onFavoriteItem;

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) {
      return const Center(
        child: Text(
          'No scans match.\nPoint the camera at a barcode!',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      itemCount: scans.length,
      itemBuilder: (BuildContext context, int index) {
        final Scan scan = scans[index];
        final ParsedContent parsed =
            ParsedContent.fromJsonString(scan.parsedJson) ??
                ParsedContent.text(scan.rawText);
        final bool isSelected = selected.contains(scan.id);
        return Dismissible(
          key: ValueKey<int>(scan.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => onDeleteItem(scan),
          background: Container(
            color: Theme.of(context).colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline),
          ),
          child: ListTile(
            selected: isSelected,
            leading: isSelected
                ? const Icon(Icons.check_circle)
                : const Icon(Icons.qr_code_2),
            title: Text(
              scan.rawText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${parsed.type.label} · ${_dateFormat.format(scan.createdAt.toLocal())}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FormatChip(format: scan.format),
                IconButton(
                  icon: Icon(scan.isFavorite ? Icons.star : Icons.star_border),
                  onPressed: () => onFavoriteItem(scan),
                ),
              ],
            ),
            onTap: () => onTapItem(scan),
            onLongPress: () => onLongPressItem(scan),
          ),
        );
      },
    );
  }
}

/// Filter panel: favorites, date range, content types, tag.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final ScanFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  bool _favorites = false;
  DateTime? _from;
  DateTime? _to;
  Set<ContentType> _types = <ContentType>{};
  int? _tagId;
  List<Tag> _tags = const <Tag>[];

  @override
  void initState() {
    super.initState();
    // Initial values come from the widget; field initializers cannot touch
    // `widget`, so they are applied here.
    _favorites = widget.initial.favoritesOnly;
    _from = widget.initial.from;
    _to = widget.initial.to;
    _types = <ContentType>{
      for (final String t in widget.initial.types ?? <String>[])
        ContentType.fromStorageName(t),
    };
    _tagId = widget.initial.tagId;
    ref.read(scanRepositoryProvider).allTags().then((List<Tag> tags) {
      if (mounted) {
        setState(() => _tags = tags);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _favorites = false;
                      _from = null;
                      _to = null;
                      _types = <ContentType>{};
                      _tagId = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('Favorites only'),
              value: _favorites,
              onChanged: (bool v) => setState(() => _favorites = v),
            ),
            ListTile(
              title: const Text('Date range'),
              subtitle: Text(
                _from == null && _to == null
                    ? 'Any time'
                    : '${_from?.toLocal().toString().split(' ').first ?? '…'} — ${_to?.toLocal().toString().split(' ').first ?? '…'}',
              ),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
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
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final ContentType t in ContentType.values)
                  FilterChip(
                    label: Text(t.label),
                    selected: _types.contains(t),
                    onSelected: (bool selected) => setState(() => selected
                        ? _types.add(t)
                        : _types.remove(t)),
                  ),
              ],
            ),
            if (_tags.isNotEmpty)
              DropdownButtonFormField<int?>(
                decoration: const InputDecoration(labelText: 'Tag'),
                initialValue: _tagId,
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(value: null, child: Text('Any tag')),
                  for (final Tag t in _tags)
                    DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
                ],
                onChanged: (int? v) => setState(() => _tagId = v),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(ScanFilter(
                  favoritesOnly: _favorites,
                  from: _from,
                  to: _to?.add(const Duration(days: 1)),
                  types:
                      _types.isEmpty ? null : _types.map((ContentType t) => t.storageName).toSet(),
                  tagId: _tagId,
                ));
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
