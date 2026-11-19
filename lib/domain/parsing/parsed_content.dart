import 'dart:convert';

import 'content_type.dart';

/// Structured view of a scanned payload, produced by the content parser.
///
/// [fields] carries the per-type attributes (e.g. Wi-Fi SSID and password,
/// contact name and phone numbers) so the UI never re-parses raw text.
class ParsedContent {
  const ParsedContent({
    required this.type,
    this.title,
    this.fields = const <String, List<String>>{},
  });

  final ContentType type;

  /// Short human summary for list tiles; falls back to the raw text.
  final String? title;

  /// Attribute values keyed by lowercase field name ('ssid', 'password',
  /// 'name', 'tel', 'email', ...). Values repeat for multi-value fields
  /// (a vCard can hold several phone numbers).
  final Map<String, List<String>> fields;

  String? first(String key) => fields[key]?.firstOrNull;

  List<String> all(String key) => fields[key] ?? const <String>[];

  factory ParsedContent.text(String raw) =>
      ParsedContent(type: ContentType.text);

  /// Serializes to the `parsed_json` database column.
  String toJson() => jsonEncode(<String, dynamic>{
        'type': type.storageName,
        'title': title,
        'fields': fields,
      });

  /// Rebuilds from the `parsed_json` column; null when missing/corrupt.
  static ParsedContent? fromJsonString(String? json) {
    if (json == null || json.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(json) as Map<String, dynamic>;
      return ParsedContent(
        type: ContentType.fromStorageName(data['type'] as String? ?? 'text'),
        title: data['title'] as String?,
        fields: (data['fields'] as Map<String, dynamic>? ?? <String, dynamic>{})
            .map((String k, dynamic v) => MapEntry<String, List<String>>(
                  k,
                  (v as List<dynamic>).cast<String>(),
                )),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
