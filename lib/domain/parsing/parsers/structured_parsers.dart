import '../content_type.dart';
import '../parsed_content.dart';
import 'simple_parsers.dart';

/// `WIFI:T:WPA;S:MyNet;P:secret;H:false;;` (also the older `WIFI:S:...`).
ParsedContent? parseWifi(String raw) {
  if (!raw.toUpperCase().startsWith('WIFI:')) {
    return null;
  }
  final String body = raw.substring(5);
  final Map<String, List<String>> fields = <String, List<String>>{};
  for (final String part in splitEscaped(body, ';')) {
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
      case 'T':
        fields['authtype'] = <String>[value];
      case 'S':
        fields['ssid'] = <String>[value];
      case 'P':
        fields['password'] = <String>[value];
      case 'H':
        fields['hidden'] =
            <String>[value.toLowerCase() == 'true' ? 'yes' : 'no'];
    }
  }
  if (!fields.containsKey('ssid')) {
    return null; // Not a usable Wi-Fi payload.
  }
  fields['ssid'] = _stripQuotes(fields['ssid']!);
  if (fields.containsKey('password')) {
    fields['password'] = _stripQuotes(fields['password']!);
  }
  return ParsedContent(
    type: ContentType.wifi,
    title: 'Wi-Fi: ${fields['ssid']!.first}',
    fields: fields,
  );
}

List<String> _stripQuotes(List<String> values) =>
    values
        .map((String s) =>
            s.startsWith('"') && s.endsWith('"') && s.length > 1
                ? s.substring(1, s.length - 1)
                : s)
        .toList(growable: false);

/// `geo:52.5200,13.4050` (optionally `?q=...&z=14`; altitude `,-30` ignored).
ParsedContent? parseGeo(String raw) {
  final RegExpMatch? m = RegExp(
    r'^geo:([-+]?\d+(?:\.\d+)?),([-+]?\d+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final String lat = m[1]!;
  final String lng = m[2]!;
  final Map<String, String> query =
      parseQuery(raw.contains('?') ? raw.split('?')[1] : '');
  return ParsedContent(
    type: ContentType.geo,
    title: 'Location: $lat, $lng',
    fields: <String, List<String>>{
      'lat': <String>[lat],
      'lng': <String>[lng],
      if (query.containsKey('q')) 'query': <String>[query['q']!],
      if (query.containsKey('z')) 'zoom': <String>[query['z']!],
    },
  );
}

/// `upi://pay?pa=merchant@bank&pn=Name&am=10.00&cu=INR&tn=note`.
ParsedContent? parseUpi(String raw) {
  final RegExpMatch? m = RegExp(
    r'^upi://pay\?(.*)$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final Map<String, String> q = parseQuery(m[1]!);
  if (!q.containsKey('pa')) {
    return null;
  }
  return ParsedContent(
    type: ContentType.upi,
    title: 'Pay ${q['pn'] ?? q['pa']}',
    fields: <String, List<String>>{
      'vpa': <String>[q['pa']!],
      if (q.containsKey('pn')) 'payeename': <String>[q['pn']!],
      if (q.containsKey('am')) 'amount': <String>[q['am']!],
      if (q.containsKey('cu')) 'currency': <String>[q['cu']!],
      if (q.containsKey('tn')) 'note': <String>[q['tn']!],
    },
  );
}

/// `mailto:someone@example.com?subject=Hi&body=Line`.
ParsedContent? parseMailto(String raw) {
  final RegExpMatch? m = RegExp(
    r'^mailto:([^?]*)(?:\?(.*))?$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final Map<String, String> q = parseQuery(m[2] ?? '');
  final String to = m[1]!.trim();
  return ParsedContent(
    type: ContentType.email,
    title: to.isEmpty ? 'Email' : 'Email: $to',
    fields: <String, List<String>>{
      'to': <String>[to],
      if (q.containsKey('subject')) 'subject': <String>[q['subject']!],
      if (q.containsKey('body')) 'body': <String>[q['body']!],
      if (q.containsKey('cc')) 'cc': <String>[q['cc']!],
    },
  );
}

/// `tel:+49 123 456`.
ParsedContent? parseTel(String raw) {
  final RegExpMatch? m = RegExp(
    r'^tel:([^?]*)(?:\?(.*))?$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final String number = m[1]!.trim();
  return ParsedContent(
    type: ContentType.phone,
    title: 'Call $number',
    fields: <String, List<String>>{'tel': <String>[number]},
  );
}

/// `sms:+49123?body=Hi` and the older `smsto:+49123:Hi` variant.
ParsedContent? parseSms(String raw) {
  final RegExpMatch? m = RegExp(
    r'^(smsto|sms):([^?:]*)(?::([^?]*))?(?:\?(.*))?$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final String number = m[2]!.trim();
  // smsto:number:body carries the body in the third segment; sms: uses ?body=.
  final Map<String, String> q = parseQuery(m[4] ?? '');
  final String body = m[3] ?? q['body'] ?? '';
  return ParsedContent(
    type: ContentType.sms,
    title: number.isEmpty ? 'SMS' : 'SMS to $number',
    fields: <String, List<String>>{
      'tel': <String>[number],
      if (body.isNotEmpty) 'body': <String>[body],
    },
  );
}
