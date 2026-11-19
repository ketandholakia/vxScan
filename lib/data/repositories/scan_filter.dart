/// History filters. Null / empty means "no constraint" per field.
///
/// Lives outside the repository so both the repository and the raw-SQL
/// search in the database class can use it without an import cycle.
class ScanFilter {
  const ScanFilter({
    this.formats,
    this.types,
    this.favoritesOnly = false,
    this.from,
    this.to,
    this.sessionId,
    this.tagId,
  });

  final Set<int>? formats;
  final Set<String>? types;
  final bool favoritesOnly;
  final DateTime? from;
  final DateTime? to;
  final int? sessionId;
  final int? tagId;

  bool get isEmpty =>
      (formats == null || formats!.isEmpty) &&
      (types == null || types!.isEmpty) &&
      !favoritesOnly &&
      from == null &&
      to == null &&
      sessionId == null &&
      tagId == null;
}
