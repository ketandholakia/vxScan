import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../repositories/scan_filter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Scans, Tags, ScanTags, Sessions, GeneratedBarcodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.test(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createFts();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Add `else if (from < 2) { ... }` steps as the schema evolves.
        },
      );

  /// Full-text index over `raw_text` and `note`.
  ///
  /// Managed with raw SQL (external-content FTS5 + sync triggers) because it
  /// must stay in lockstep with the `scans` table, which drift's FTS5 DSL
  /// does not sync automatically.
  Future<void> _createFts() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS scans_fts USING fts5('
      "raw_text, note, content='scans', content_rowid='id')",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS scans_ai AFTER INSERT ON scans BEGIN '
      'INSERT INTO scans_fts(rowid, raw_text, note) '
      'VALUES (new.id, new.raw_text, new.note); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS scans_ad AFTER DELETE ON scans BEGIN '
      "INSERT INTO scans_fts(scans_fts, rowid, raw_text, note) "
      "VALUES ('delete', old.id, old.raw_text, old.note); END",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS scans_au AFTER UPDATE ON scans BEGIN '
      "INSERT INTO scans_fts(scans_fts, rowid, raw_text, note) "
      "VALUES ('delete', old.id, old.raw_text, old.note); "
      'INSERT INTO scans_fts(rowid, raw_text, note) '
      'VALUES (new.id, new.raw_text, new.note); END',
    );
  }

  /// FTS5 search over raw text and notes, optionally combined with a
  /// [ScanFilter]; newest first.
  Future<List<Scan>> searchScans(String query, {ScanFilter filter = const ScanFilter()}) {
    // Quote the user input so punctuation in scanned content cannot be
    // interpreted as FTS5 query syntax.
    final String match = '"${query.replaceAll('"', '""')}"';

    final StringBuffer sql = StringBuffer(
      'SELECT s.* FROM scans s '
      'JOIN scans_fts f ON s.id = f.rowid ',
    );
    final List<Variable<Object>> variables =
        <Variable<Object>>[Variable.withString(match)];

    if (filter.tagId != null) {
      sql.write('JOIN scan_tags st ON st.scan_id = s.id ');
    }

    final List<String> conditions = <String>['scans_fts MATCH ?'];
    if (filter.formats != null && filter.formats!.isNotEmpty) {
      final String placeholders =
          List<String>.filled(filter.formats!.length, '?').join(', ');
      conditions.add('s.format IN ($placeholders)');
      variables.addAll(filter.formats!.map(Variable<int>.new));
    }
    if (filter.types != null && filter.types!.isNotEmpty) {
      final String placeholders =
          List<String>.filled(filter.types!.length, '?').join(', ');
      conditions.add('s.content_type IN ($placeholders)');
      variables.addAll(filter.types!.map(Variable<String>.new));
    }
    if (filter.favoritesOnly) {
      conditions.add('s.is_favorite = 1');
    }
    if (filter.from != null) {
      conditions.add('s.created_at >= ?');
      variables.add(Variable<DateTime>(filter.from!));
    }
    if (filter.to != null) {
      conditions.add('s.created_at <= ?');
      variables.add(Variable<DateTime>(filter.to!));
    }
    if (filter.sessionId != null) {
      conditions.add('s.session_id = ?');
      variables.add(Variable<int>(filter.sessionId!));
    }
    if (filter.tagId != null) {
      conditions.add('st.tag_id = ?');
      variables.add(Variable<int>(filter.tagId!));
    }

    sql
      ..write('WHERE ${conditions.join(' AND ')} ')
      ..write('ORDER BY s.created_at DESC LIMIT 500');

    return customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: <ResultSetImplementation>{scans, scanTags},
    ).map(_scanFromRow).get();
  }

  /// Maps a `SELECT s.*` row from [searchScans] back to a [Scan].
  ///
  /// `QueryRow` has no table-aware reader, so columns are read by hand in
  /// the database's storage order (drift types map values to Dart).
  Scan _scanFromRow(QueryRow row) => Scan(
        id: row.read<int>('id'),
        rawText: row.read<String>('raw_text'),
        rawBytes: row.readNullable<Uint8List>('raw_bytes'),
        format: row.read<int>('format'),
        contentType: row.read<String>('content_type'),
        parsedJson: row.readNullable<String>('parsed_json'),
        source: row.read<String>('source'),
        createdAt: row.read<DateTime>('created_at'),
        isFavorite: row.read<bool>('is_favorite'),
        note: row.readNullable<String>('note'),
        sessionId: row.readNullable<int>('session_id'),
      );

  /// JSON-able snapshot of every table, for the backup file.
  ///
  /// Chosen over copying the raw sqlite file: the dump is portable, survives
  /// schema-version differences (restore re-runs through normal inserts) and
  /// avoids file-lock issues while the app is running.
  Future<Map<String, Object?>> exportBackup() {
    return transaction(() async {
      final List<Scan> scanRows = await select(scans).get();
      final List<Tag> tagRows = await select(tags).get();
      final List<ScanTag> scanTagRows = await select(scanTags).get();
      final List<Session> sessionRows = await select(sessions).get();
      final List<GeneratedBarcode> generatedRows =
          await select(generatedBarcodes).get();
      return <String, Object?>{
        'schemaVersion': schemaVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'scans': scanRows.map(_scanToJson).toList(),
        'tags': tagRows.map(_tagToJson).toList(),
        'scan_tags': scanTagRows
            .map((ScanTag st) => <String, Object?>{
                  'scan_id': st.scanId,
                  'tag_id': st.tagId,
                })
            .toList(),
        'sessions': sessionRows.map(_sessionToJson).toList(),
        'generated': generatedRows.map(_generatedToJson).toList(),
      };
    });
  }

  /// Restores a snapshot from [exportBackup]: clears all tables and inserts.
  ///
  /// Restored scans get fresh ids; the id maps keep joins intact.
  Future<void> restoreBackup(Map<String, Object?> data) {
    return transaction(() async {
      // Order matters: children first, and the FTS triggers keep the index
      // in sync automatically.
      await delete(scanTags).go();
      await delete(scans).go();
      await delete(tags).go();
      await delete(sessions).go();
      await delete(generatedBarcodes).go();

      // Pre-map old ids → new ids per table.
      final Map<int, int> tagIds = <int, int>{};
      for (final Map<String, Object?> t in _castList(data['tags'])) {
        final int newId = await into(tags).insert(
          TagsCompanion.insert(name: t['name']! as String),
        );
        tagIds[t['id']! as int] = newId;
      }
      final Map<int, int> sessionIds = <int, int>{};
      for (final Map<String, Object?> s in _castList(data['sessions'])) {
        final int newId = await into(sessions).insert(
          SessionsCompanion.insert(
            name: s['name']! as String,
            startedAt: Value(DateTime.parse(s['started_at']! as String)),
            endedAt: Value(s['ended_at'] == null
                ? null
                : DateTime.parse(s['ended_at']! as String)),
          ),
        );
        sessionIds[s['id']! as int] = newId;
      }
      final Map<int, int> scanIds = <int, int>{};
      for (final Map<String, Object?> s in _castList(data['scans'])) {
        final Object? rawBytesRaw = s['raw_bytes'];
        final Uint8List? rawBytes = rawBytesRaw == null
            ? null
            : Uint8List.fromList((rawBytesRaw as List<Object?>).cast<int>());
        final int? oldSessionId =
            s['session_id'] == null ? null : sessionIds[s['session_id']! as int];
        final int newId = await into(scans).insert(
          ScansCompanion.insert(
            rawText: s['raw_text']! as String,
            rawBytes: Value(rawBytes),
            format: s['format']! as int,
            contentType: Value(s['content_type']! as String),
            parsedJson: Value(s['parsed_json'] as String?),
            source: s['source']! as String,
            createdAt: Value(DateTime.parse(s['created_at']! as String)),
            isFavorite: Value(s['is_favorite']! as bool),
            note: Value(s['note'] as String?),
            sessionId: Value(oldSessionId),
          ),
        );
        scanIds[s['id']! as int] = newId;
      }
      for (final Map<String, Object?> st in _castList(data['scan_tags'])) {
        final int? scanId = scanIds[st['scan_id']! as int];
        final int? tagId = tagIds[st['tag_id']! as int];
        if (scanId != null && tagId != null) {
          await into(scanTags).insert(
            ScanTagsCompanion.insert(scanId: scanId, tagId: tagId),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
      for (final Map<String, Object?> g in _castList(data['generated'])) {
        await into(generatedBarcodes).insert(
          GeneratedBarcodesCompanion.insert(
            format: g['format']! as int,
            content: g['content']! as String,
            optionsJson: g['options_json']! as String,
            createdAt: Value(DateTime.parse(g['created_at']! as String)),
          ),
        );
      }
    });
  }

  List<Map<String, Object?>> _castList(Object? raw) =>
      (raw as List<Object?>? ?? <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> m) => m.cast<String, Object?>())
          .toList();

  Map<String, Object?> _scanToJson(Scan s) => <String, Object?>{
        'id': s.id,
        'raw_text': s.rawText,
        'raw_bytes': s.rawBytes?.toList(),
        'format': s.format,
        'content_type': s.contentType,
        'parsed_json': s.parsedJson,
        'source': s.source,
        'created_at': s.createdAt.toIso8601String(),
        'is_favorite': s.isFavorite,
        'note': s.note,
        'session_id': s.sessionId,
      };

  Map<String, Object?> _tagToJson(Tag t) => <String, Object?>{
        'id': t.id,
        'name': t.name,
      };

  Map<String, Object?> _sessionToJson(Session s) => <String, Object?>{
        'id': s.id,
        'name': s.name,
        'started_at': s.startedAt.toIso8601String(),
        'ended_at': s.endedAt?.toIso8601String(),
      };

  Map<String, Object?> _generatedToJson(GeneratedBarcode g) =>
      <String, Object?>{
        'id': g.id,
        'format': g.format,
        'content': g.content,
        'options_json': g.optionsJson,
        'created_at': g.createdAt.toIso8601String(),
      };
}

QueryExecutor _openConnection() => driftDatabase(name: 'vxscan');
