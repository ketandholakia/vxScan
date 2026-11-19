import 'dart:async';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'scan_filter.dart';

/// Single gateway for reading and writing scans.
///
/// UI-facing types are the generated drift row classes ([Scan]) and
/// [ScansCompanion] for inserts; content parsing happens in the domain layer
/// and arrives here with `contentType`/`parsedJson` filled.
class ScanRepository {
  ScanRepository(this._db);

  final AppDatabase _db;

  Stream<List<Scan>> watchAll({int limit = 500}) {
    return (_db.select(_db.scans)
          ..orderBy(<OrderClauseGenerator<$ScansTable>>[
            (u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  /// Newest scans matching [filter], watched live.
  Stream<List<Scan>> watchFiltered(ScanFilter filter, {int limit = 1000}) {
    final SimpleSelectStatement<$ScansTable, Scan> query =
        _db.select(_db.scans);
    _applyFilter(query, filter);
    query
      ..orderBy(<OrderClauseGenerator<$ScansTable>>[
        (u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.watch();
  }

  /// Search combined with [filter]; FTS handles the text, SQL the rest.
  Future<List<Scan>> search(String query, {ScanFilter filter = const ScanFilter()}) {
    final String match = '"${query.replaceAll('"', '""')}"';
    return _db.searchScans(match, filter: filter);
  }

  Stream<Scan?> watchById(int id) {
    return (_db.select(_db.scans)..where((u) => u.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Scan?> getById(int id) {
    return (_db.select(_db.scans)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
  }

  /// Inserts a scan and returns its row id.
  Future<int> insert(ScansCompanion entry) => _db.into(_db.scans).insert(entry);

  Future<void> setFavorite(int id, bool favorite) {
    return (_db.update(_db.scans)..where((u) => u.id.equals(id)))
        .write(ScansCompanion(isFavorite: Value(favorite)));
  }

  Future<void> setNote(int id, String? note) {
    return (_db.update(_db.scans)..where((u) => u.id.equals(id)))
        .write(ScansCompanion(note: Value(note)));
  }

  Future<int> remove(int id) =>
      (_db.delete(_db.scans)..where((u) => u.id.equals(id))).go();

  Future<int> removeAll(Iterable<int> ids) =>
      (_db.delete(_db.scans)..where((u) => u.id.isIn(ids))).go();

  /// Deletes non-favorite scans older than [days]; returns the count.
  Future<int> purgeExpired(int days) {
    final DateTime cutoff =
        DateTime.now().toUtc().subtract(Duration(days: days));
    return (_db.delete(_db.scans)
          ..where(
            (u) =>
                u.createdAt.isSmallerThanValue(cutoff) &
                u.isFavorite.equals(false),
          ))
        .go();
  }

  /// Applies [filter] to [query]. drift 2.35's `where` takes a callback per
  /// condition and ANDs repeated calls, so each constraint is added alone.
  void _applyFilter(
    SimpleSelectStatement<$ScansTable, Scan> query,
    ScanFilter filter,
  ) {
    if (filter.formats != null && filter.formats!.isNotEmpty) {
      query.where((u) => u.format.isIn(filter.formats!));
    }
    if (filter.types != null && filter.types!.isNotEmpty) {
      query.where((u) => u.contentType.isIn(filter.types!));
    }
    if (filter.favoritesOnly) {
      query.where((u) => u.isFavorite.equals(true));
    }
    if (filter.from != null) {
      query.where((u) => u.createdAt.isBiggerOrEqualValue(filter.from!));
    }
    if (filter.to != null) {
      query.where((u) => u.createdAt.isSmallerOrEqualValue(filter.to!));
    }
    if (filter.sessionId != null) {
      query.where((u) => u.sessionId.equals(filter.sessionId!));
    }
    if (filter.tagId != null) {
      query.join(<Join>[
        innerJoin(
          _db.scanTags,
          _db.scanTags.scanId.equalsExp(_db.scans.id),
          useColumns: false,
        ),
      ]);
      query.where((u) => _db.scanTags.tagId.equals(filter.tagId!));
    }
  }

  // -- Sessions -----------------------------------------------------------

  Future<Session> createSession(String name) async {
    final int id = await _db.into(_db.sessions).insert(
          SessionsCompanion.insert(name: name),
        );
    return Session(
      id: id,
      name: name,
      startedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> endSession(int id) {
    return (_db.update(_db.sessions)..where((u) => u.id.equals(id)))
        .write(SessionsCompanion(endedAt: Value(DateTime.now().toUtc())));
  }

  Future<Session?> getSession(int id) =>
      (_db.select(_db.sessions)..where((u) => u.id.equals(id)))
          .getSingleOrNull();

  // -- Tags ---------------------------------------------------------------

  Stream<List<Tag>> watchTags() => (_db.select(_db.tags)
            ..orderBy(<OrderClauseGenerator<$TagsTable>>[
              (u) => OrderingTerm.asc(u.name),
            ]))
          .watch();

  Future<List<Tag>> allTags() => _db.select(_db.tags).get();

  Future<List<Tag>> tagsForScan(int scanId) {
    final query = _db.select(_db.tags).join(<Join>[
      innerJoin(_db.scanTags, _db.scanTags.tagId.equalsExp(_db.tags.id)),
    ]);
    query.where(_db.scanTags.scanId.equals(scanId));
    return query
        .map((TypedResult row) => row.readTable(_db.tags))
        .get();
  }

  /// Returns the tag id for [name], creating it when missing.
  Future<int> ensureTag(String name) async {
    final List<Tag> existing =
        await (_db.select(_db.tags)..where((u) => u.name.equals(name))).get();
    if (existing.isNotEmpty) {
      return existing.first.id;
    }
    return _db.into(_db.tags).insert(TagsCompanion.insert(name: name));
  }

  Future<void> deleteTag(int tagId) async {
    await (_db.delete(_db.scanTags)..where((u) => u.tagId.equals(tagId))).go();
    await (_db.delete(_db.tags)..where((u) => u.id.equals(tagId))).go();
  }

  Future<void> setScanTags(int scanId, Set<int> tagIds) {
    return _db.transaction(() async {
      await (_db.delete(_db.scanTags)
            ..where((u) => u.scanId.equals(scanId)))
          .go();
      for (final int tagId in tagIds) {
        await _db.into(_db.scanTags).insert(
              ScanTagsCompanion.insert(scanId: scanId, tagId: tagId),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  // -- Generated barcodes ---------------------------------------------------

  Future<int> insertGenerated(GeneratedBarcodesCompanion entry) =>
      _db.into(_db.generatedBarcodes).insert(entry);

  Stream<List<GeneratedBarcode>> watchGenerated({int limit = 200}) {
    return (_db.select(_db.generatedBarcodes)
          ..orderBy(<OrderClauseGenerator<$GeneratedBarcodesTable>>[
            (u) => OrderingTerm(expression: u.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<int> removeGenerated(int id) =>
      (_db.delete(_db.generatedBarcodes)..where((u) => u.id.equals(id))).go();

  /// All scans + generated rows as a JSON-able map (backup/restore).
  Future<Map<String, Object?>> exportAll() => _db.exportBackup();

  /// Wipes and restores every table from a backup produced by [exportAll].
  Future<void> importAll(Map<String, Object?> data) => _db.restoreBackup(data);
}
