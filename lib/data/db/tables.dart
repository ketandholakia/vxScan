import 'package:drift/drift.dart';

/// Every scan the app has ever decoded, regardless of source.
///
/// [format] stores the zxing-cpp `Format` bit flag (see
/// `package:flutter_zxing/src/models/format.dart`); [contentType] is filled by
/// the Phase 2 content parsers ('url', 'wifi', 'vcard', ...) and stays
/// 'unknown' until then.
@TableIndex(name: 'idx_scans_created_at', columns: {#createdAt})
@TableIndex(name: 'idx_scans_format', columns: {#format})
@TableIndex(name: 'idx_scans_is_favorite', columns: {#isFavorite})
class Scans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get rawText => text()();
  BlobColumn get rawBytes => blob().nullable()();
  IntColumn get format => integer()();
  TextColumn get contentType => text().withDefault(const Constant('unknown'))();
  TextColumn get parsedJson => text().nullable()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  IntColumn get sessionId => integer().nullable().references(Sessions, #id)();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

/// Join table between [Scans] and [Tags].
class ScanTags extends Table {
  IntColumn get scanId => integer().references(Scans, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {scanId, tagId};
}

/// A batch-scan session (Phase 3 continuous mode groups its scans this way).
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();
}

/// Barcodes created with the generator (Phase 4). The table is named
/// `generated` per the plan; the Dart class avoids the name `Generated`
/// because drift exports a class with that name.
@TableIndex(name: 'idx_generated_created_at', columns: {#createdAt})
class GeneratedBarcodes extends Table {
  @override
  String get tableName => 'generated';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get format => integer()();
  TextColumn get content => text()();
  TextColumn get optionsJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
