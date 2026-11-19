import '../content_type.dart';
import '../parsed_content.dart';
import 'simple_parsers.dart';

/// vCard 2.1 / 3.0 / 4.0 — a pragmatic subset: FN, N, ORG, TITLE, TEL,
/// EMAIL, ADR, URL, NOTE, BDAY. Handles folded lines, TYPE params and
/// repeated TEL/EMAIL/URL entries.
ParsedContent? parseVCard(String raw) {
  final String upper = raw.toUpperCase().trimLeft();
  if (!upper.startsWith('BEGIN:VCARD')) {
    return null;
  }
  final Map<String, List<String>> fields = <String, List<String>>{};
  final Map<String, List<String>> telTypes = <String, List<String>>{};
  String? version;

  for (final String line in unfoldLines(raw)) {
    final line0 = parsePropertyLine(line);
    if (line0 == null) {
      continue;
    }
    final String value = line0.value.trim();
    if (value.isEmpty) {
      continue;
    }
    switch (line0.name) {
      case 'VERSION':
        version = value;
      case 'FN':
        fields['name'] = <String>[value];
      case 'N':
        // N:Doe;John;;Mr — surname;given;middle;prefix (semicolon-separated).
        final List<String> parts = value.split(';');
        if (!fields.containsKey('name')) {
          final String given = parts.length > 1 ? parts[1] : '';
          final String surname = parts.first;
          fields['name'] = <String>[
            '$given $surname'.trim().isEmpty ? value : '$given $surname'.trim(),
          ];
        }
        if (parts.length > 3 && parts[3].isNotEmpty) {
          fields['honorific'] = <String>[parts[3]];
        }
      case 'ORG':
        fields['org'] = <String>[value.replaceAll(';', ' · ')];
      case 'TITLE':
        fields['title'] = <String>[value];
      case 'TEL':
        (fields['tel'] ??= <String>[]).add(value);
        final String? type = line0.params['type']?.isNotEmpty == true
            ? line0.params['type']!
            : null;
        if (type != null && type.toUpperCase() != 'INTERNET') {
          (telTypes[value] ??= <String>[]).add(type.toUpperCase());
        }
      case 'EMAIL':
        (fields['email'] ??= <String>[]).add(value);
      case 'ADR':
        fields['address'] = <String>[value.split(';').nonEmpty()];
      case 'URL':
        (fields['url'] ??= <String>[]).add(value);
      case 'NOTE':
        (fields['note'] ??= <String>[]).add(value);
      case 'BDAY':
        fields['birthday'] = <String>[value];
    }
  }

  if (!fields.containsKey('name') && !fields.containsKey('tel') && !fields.containsKey('email')) {
    return null; // Too empty to be a usable contact.
  }
  final String displayName = fields['name']?.first ??
      fields['tel']?.first ??
      fields['email']!.first;
  return ParsedContent(
    type: ContentType.vcard,
    title: displayName,
    fields: {
      ...fields,
      if (version != null) 'version': <String>[version],
    },
  );
}

/// MeCard: `MECARD:N:Doe,John;TEL:12345;EMAIL:x@y.z;ADR:;;URL:;;`
ParsedContent? parseMeCard(String raw) {
  if (!raw.trim().toUpperCase().startsWith('MECARD:')) {
    return null;
  }
  final Map<String, List<String>> fields = <String, List<String>>{};
  for (final String part
      in splitEscaped(raw.trim().substring(7).replaceAll(RegExp(r';+$'), ''), ';')) {
    if (part.isEmpty) {
      continue;
    }
    final int colon = part.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    final String key = part.substring(0, colon).toUpperCase();
    final String value = part.substring(colon + 1);
    switch (key) {
      case 'N':
        final List<String> parts = value.split(',');
        fields['name'] = <String>[parts.length > 1
            ? '${parts[1]} ${parts[0]}'
            : value];
      case 'TEL':
        (fields['tel'] ??= <String>[]).add(value);
      case 'EMAIL':
        (fields['email'] ??= <String>[]).add(value);
      case 'ADR':
        fields['address'] = <String>[value];
      case 'URL':
        (fields['url'] ??= <String>[]).add(value);
      case 'MEMO':
        fields['note'] = <String>[value];
      case 'BDAY':
        fields['birthday'] = <String>[value];
    }
  }
  if (!fields.containsKey('name')) {
    return null;
  }
  return ParsedContent(
    type: ContentType.mecard,
    title: fields['name']!.first,
    fields: fields,
  );
}

/// `BEGIN:VEVENT … END:VEVENT` (with or without a VCALENDAR wrapper).
ParsedContent? parseEvent(String raw) {
  final String upper = raw.toUpperCase();
  if (!upper.contains('BEGIN:VEVENT')) {
    return null;
  }
  final Map<String, List<String>> fields = <String, List<String>>{};
  for (final String line in unfoldLines(raw)) {
    final line0 = parsePropertyLine(line);
    if (line0 == null) {
      continue;
    }
    final String value = line0.value.trim();
    if (value.isEmpty) {
      continue;
    }
    switch (line0.name) {
      case 'SUMMARY':
        fields['summary'] = <String>[value];
      case 'DTSTART':
        final String? iso = parseIcsDate(value);
        if (iso != null) {
          fields['start'] = <String>[iso];
        }
      case 'DTEND':
        final String? iso = parseIcsDate(value);
        if (iso != null) {
          fields['end'] = <String>[iso];
        }
      case 'LOCATION':
        fields['location'] = <String>[value];
      case 'DESCRIPTION':
        fields['description'] = <String>[value];
    }
  }
  if (!fields.containsKey('summary')) {
    return null;
  }
  return ParsedContent(
    type: ContentType.event,
    title: fields['summary']!.first,
    fields: fields,
  );
}

extension on List<String> {
  /// Joins non-empty comma-separated parts (used for ADR components).
  String nonEmpty() => where((String s) => s.trim().isNotEmpty)
      .map((String s) => s.trim())
      .join(', ');
}
