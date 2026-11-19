/// Helpers shared by the payload parsers.
library;

/// Removes ZXing-style escape sequences used by Wi-Fi/MeCard payloads.
String unescape(String raw) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    if (raw[i] == r'\' && i + 1 < raw.length) {
      i++;
      out.write(raw[i]);
    } else {
      out.write(raw[i]);
    }
  }
  return out.toString();
}

/// Splits on [sep], honoring backslash escapes (Wi-Fi and MeCard payloads).
List<String> splitEscaped(String raw, String sep) {
  final List<String> parts = <String>[];
  final StringBuffer current = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final String c = raw[i];
    if (c == r'\' && i + 1 < raw.length) {
      i++;
      current.write(raw[i]);
    } else if (c == sep) {
      parts.add(current.toString());
      current.clear();
    } else {
      current.write(c);
    }
  }
  parts.add(current.toString());
  return parts;
}

/// Unfolds vCard/iCalendar continuation lines: lines indented by a single
/// space or tab belong to the previous logical line.
List<String> unfoldLines(String raw) {
  final List<String> out = <String>[];
  for (final String line in raw.replaceAll('\r\n', '\n').split('\n')) {
    if (line.isEmpty) {
      continue;
    }
    if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
      out[out.length - 1] = out.last + line.substring(1);
    } else {
      out.add(line);
    }
  }
  return out;
}

/// Parses an iCalendar/property line into `(name, params, value)`; params are
/// lowercase keys. Example: `TEL;TYPE=CELL:+49 123` →
/// `('tel', {'type': 'cell'}, '+49 123')`.
({String name, Map<String, String> params, String value})?
    parsePropertyLine(String line) {
  final int colon = line.indexOf(':');
  if (colon <= 0) {
    return null;
  }
  final String value = line.substring(colon + 1);
  final List<String> head = line.substring(0, colon).split(';');
  final String name = head.first.trim().toUpperCase();
  final Map<String, String> params = <String, String>{};
  for (final String p in head.skip(1)) {
    final int eq = p.indexOf('=');
    if (eq > 0) {
      params[p.substring(0, eq).trim().toLowerCase()] =
          p.substring(eq + 1).trim();
    }
  }
  return (name: name, params: params, value: value);
}

/// Parses iCalendar date values: `20240131`, `20240131T153000`,
/// `20240131T153000Z`, `20240131T153000+0200`. Returns the normalized ISO
/// string, or null when unparsable.
String? parseIcsDate(String value) {
  final String v = value.trim().toUpperCase();
  final RegExpMatch? m = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z|[+-]\d{4})?)?$',
  ).firstMatch(v);
  if (m == null) {
    return null;
  }
  final String date =
      '${m[1]}-${m[2]}-${m[3]}';
  if (m[4] == null) {
    return date;
  }
  final String time = '${m[4]}:${m[5]}:${m[6]}';
  final String zone = m[7] ?? '';
  if (zone == 'Z') {
    return '${date}T$time.000Z';
  }
  if (zone.isEmpty) {
    return '${date}T$time';
  }
  // +0200 / -0500 → ±02:00
  final String sign = zone[0];
  final String hhmm = zone.substring(1);
  return '$date T$time$sign${hhmm.substring(0, 2)}:${hhmm.substring(2)}'
      .replaceAll(' ', '');
}

/// Parses URI query values (`mailto:x?subject=Hi` → `{'subject': 'Hi'}`).
Map<String, String> parseQuery(String query) {
  final Map<String, String> out = <String, String>{};
  for (final String pair in query.split('&')) {
    if (pair.isEmpty) {
      continue;
    }
    final int eq = pair.indexOf('=');
    final String key = eq < 0 ? pair : pair.substring(0, eq);
    final String value = eq < 0 ? '' : pair.substring(eq + 1);
    try {
      out[Uri.decodeComponent(key.trim()).toLowerCase()] =
          Uri.decodeComponent(value.replaceAll('+', '%20'));
    } on ArgumentError {
      // Malformed percent-encoding: keep the raw value instead.
      out[key.trim().toLowerCase()] = value;
    }
  }
  return out;
}
