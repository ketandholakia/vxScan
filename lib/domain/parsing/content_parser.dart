import '../decoding/barcode_decoder.dart';
import 'content_type.dart';
import 'parsed_content.dart';
import 'parsers/card_parsers.dart';
import 'parsers/structured_parsers.dart';

export 'content_type.dart';
export 'parsed_content.dart';

/// Top-level payload parser: raw text (+ engine format hint) → [ParsedContent].
///
/// Detection runs from the most-structured payload down; scheme-based types
/// (WIFI:, geo:, mailto:, tel:, sms:, upi://) win over heuristic guesses, and
/// product formats are decided by the *format*, never by guessing on digits.
ParsedContent parseScanContent(String raw, int format) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return ParsedContent.text(raw);
  }

  // Structured payloads first — they are unambiguous.
  final List<ParsedContent? Function(String)> structured = <ParsedContent? Function(String)>[
    parseMeCard,
    parseVCard,
    parseWifi,
    parseUpi,
    parseGeo,
    parseMailto,
    parseTel,
    parseSms,
  ];
  for (final ParsedContent? Function(String) parser in structured) {
    final ParsedContent? result = parser(trimmed);
    if (result != null) {
      return result;
    }
  }

  // Calendar events (may sit inside a VCALENDAR wrapper).
  final ParsedContent? event = parseEvent(raw);
  if (event != null) {
    return event;
  }

  // URL: explicit scheme, www. shorthand, or a bare domain.
  if (_isUrl(trimmed)) {
    return ParsedContent(
      type: ContentType.url,
      title: _hostOf(trimmed),
      fields: <String, List<String>>{'url': <String>[trimmed]},
    );
  }

  // Product formats are decided by the format alone (digits are digits).
  if (parseProductFormat(format, trimmed) case final ParsedContent product) {
    return product;
  }

  // Bare email address.
  if (_emailRegExp.hasMatch(trimmed)) {
    return ParsedContent(
      type: ContentType.email,
      title: 'Email: $trimmed',
      fields: <String, List<String>>{'to': <String>[trimmed]},
    );
  }

  // Bare phone number — only for non-product formats, so a serial number in
  // a QR code is treated as text, not as a call target.
  if (_isPhoneLike(trimmed)) {
    return ParsedContent(
      type: ContentType.phone,
      title: 'Call $trimmed',
      fields: <String, List<String>>{'tel': <String>[trimmed]},
    );
  }

  return ParsedContent.text(raw);
}

ParsedContent? parseProductFormat(int format, String text) {
  switch (format) {
    case _ean13:
      // 978/979 prefix = ISBN (Bookland EAN).
      if (text.startsWith('978') || text.startsWith('979')) {
        return ParsedContent(
          type: ContentType.product,
          title: 'ISBN $text',
          fields: <String, List<String>>{'isbn': <String>[text]},
        );
      }
      return ParsedContent(
        type: ContentType.product,
        title: 'EAN $text',
        fields: <String, List<String>>{'code': <String>[text]},
      );
    case _ean8:
      return ParsedContent(
        type: ContentType.product,
        title: 'EAN-8 $text',
        fields: <String, List<String>>{'code': <String>[text]},
      );
    case _upca:
      return ParsedContent(
        type: ContentType.product,
        title: 'UPC $text',
        fields: <String, List<String>>{'code': <String>[text]},
      );
    case _upce:
      return ParsedContent(
        type: ContentType.product,
        title: 'UPC-E $text',
        fields: <String, List<String>>{'code': <String>[text]},
      );
    case _dataBar:
    case _dataBarExpanded:
    case _dataBarLimited:
      return ParsedContent(
        type: ContentType.product,
        title: 'GS1 $text',
        fields: <String, List<String>>{'code': <String>[text]},
      );
    default:
      return null;
  }
}

final RegExp _emailRegExp = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
);

bool _isUrl(String text) {
  if (text.startsWith('http://') || text.startsWith('https://')) {
    return true;
  }
  if (text.startsWith('www.')) {
    return true;
  }
  // Bare domain: no spaces, at least one dot, 2+ letter TLD, no leading slash.
  return !text.contains(' ') &&
      !text.contains('\n') &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}(:\d+)?(/\S*)?$')
          .hasMatch(text);
}

String _hostOf(String text) {
  if (text.startsWith('http://') || text.startsWith('https://')) {
    return Uri.tryParse(text)?.host ?? text;
  }
  if (text.startsWith('www.')) {
    return text.split('/').first;
  }
  return text.split('/').first;
}

bool _isPhoneLike(String text) {
  // A bare number only counts as a phone when it looks like one: either an
  // international form with a leading +, or separators typical of phone
  // numbers. A 13-digit run without either is a serial number, not a call
  // target — that distinction is why this runs only for non-product formats.
  final bool hasPlus = text.startsWith('+');
  final bool hasSeparator = RegExp(r'[ ()\-.]').hasMatch(text);
  final String digits = text.replaceAll(RegExp(r'[ ()\-.]'), '');
  return digits.length >= 7 &&
      digits.length <= 15 &&
      RegExp(r'^\+?\d[ ()\-.0-9]{5,20}$').hasMatch(text) &&
      (hasPlus || hasSeparator);
}

// Format bit flags mirror zxing-cpp (kept as literals so the domain layer
// does not import the engine — same values as flutter_zxing Format).
const int _ean8 = 1 << 8;
const int _ean13 = 1 << 9;
const int _upca = 1 << 14;
const int _upce = 1 << 15;
const int _dataBar = 1 << 5;
const int _dataBarExpanded = 1 << 6;
const int _dataBarLimited = 1 << 19;

/// Exposed for tests and the UI: formats whose payloads are always products.
bool isProductFormat(int format) =>
    format & (_ean8 | _ean13 | _upca | _upce | _dataBar | _dataBarExpanded | _dataBarLimited) != 0;

/// Convenience used by screens that already hold a [BarcodeRead].
ParsedContent parseBarcodeRead(BarcodeRead read) =>
    parseScanContent(read.text, read.format);
