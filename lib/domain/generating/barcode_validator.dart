/// Per-format content validation and normalization for the generator.
///
/// Returns an error message, or null when the content is valid. Some
/// validators also *complete* content: a missing check digit is computed
/// rather than rejected (users rarely know EAN check digits).
library;

/// GS1-family (EAN/UPC/ITF-14) mod-10 check digit.
///
/// Weights run from the RIGHTMOST data digit: ×3, ×1, ×3, … (starting from
/// the left instead only agrees for odd-length payloads and silently breaks
/// EAN-13).
int gs1CheckDigit(String digitsWithoutCheck) {
  int sum = 0;
  final int n = digitsWithoutCheck.length;
  for (int i = 0; i < n; i++) {
    final int d = int.parse(digitsWithoutCheck[n - 1 - i]);
    sum += d * ((i % 2 == 0) ? 3 : 1);
  }
  return (10 - sum % 10) % 10;
}

/// Completes a GS1-family code: [fullLength] digits pass through as-is,
/// `fullLength - 1` digits get the computed check digit appended.
/// Returns null when the length fits neither.
String? completeGs1(String text, {required int fullLength}) {
  if (text.length == fullLength) {
    return text;
  }
  if (text.length == fullLength - 1) {
    return text + gs1CheckDigit(text).toString();
  }
  return null;
}

String? _digitsOnly(String text) =>
    RegExp(r'^\d+$').hasMatch(text) ? null : 'Only digits are allowed';

/// All validators in one map keyed by the generator format id.
/// Signature: (content) → error message or null.
String? validateContent(String formatId, String content) {
  final String t = content.trim();
  if (t.isEmpty) {
    return null; // Nothing typed yet — preview shows a hint instead.
  }
  switch (formatId) {
    case 'ean13':
      return _gs1Family(t, 13);
    case 'ean8':
      return _gs1Family(t, 8);
    case 'upca':
      return _gs1Family(t, 12);
    case 'upce':
      if (RegExp(r'^\d+$').hasMatch(t) && t.length >= 6 && t.length <= 8) {
        return null;
      }
      return 'UPC-E needs 6–8 digits';
    case 'itf':
      if (!RegExp(r'^\d+$').hasMatch(t)) {
        return _digitsOnly(t);
      }
      if (t.length.isOdd) {
        return 'ITF needs an even number of digits (got ${t.length})';
      }
      return null;
    case 'itf14':
      return _gs1Family(t, 14);
    case 'isbn':
      if (t.length == 10) {
        return RegExp(r'^\d{9}[\dXx]$').hasMatch(t)
            ? null
            : 'ISBN-10 must be 9 digits + check digit';
      }
      return _gs1Family(t, 13);
    case 'codabar':
      return RegExp(r'^[A-D][0-9\-$:/+.]+[A-D]$|^[0-9\-$:/+.]+$',
              caseSensitive: false)
          .hasMatch(t)
          ? null
          : 'Codabar allows digits and - \$ : / . + (optional A–D start/stop)';
    case 'code39':
      return RegExp(r'^[0-9A-Z\-. \$/+%]+$').hasMatch(t)
          ? null
          : 'Code 39 allows A–Z, digits, and - . \$ / + % space';
    case 'code93':
      return RegExp(r'^[0-9A-Z\-. \$/+%]+$').hasMatch(t)
          ? null
          : 'Code 93 allows A–Z, digits, and - . \$ / + % space';
    case 'code128':
      if (t.codeUnits.any((int c) => c < 32 || c > 126)) {
        return 'Code 128 supports printable ASCII only';
      }
      return null;
    case 'gs1_128':
      // GS1 element string with AI in parentheses: (01)9501234…(3103)000123.
      if (!RegExp(r'^\(\d{2,4}\)').hasMatch(t)) {
        return 'Start with an application identifier, e.g. (01)…';
      }
      return null;
    case 'rm4scc':
      return RegExp(r'^[0-9A-Z]+$').hasMatch(t)
          ? null
          : 'RM4SCC allows uppercase letters and digits';
    case 'telepen':
      if (t.codeUnits.any((int c) => c < 32 || c > 126)) {
        return 'Telepen supports printable ASCII only';
      }
      return null;
    case 'qr':
    case 'datamatrix':
    case 'aztec':
    case 'pdf417':
    case 'text':
      return null;
    default:
      return null;
  }
}

/// Accepts the full length or one-short (check digit gets appended).
String? _gs1Family(String t, int fullLength) {
  if (!RegExp(r'^\d+$').hasMatch(t)) {
    return _digitsOnly(t);
  }
  if (completeGs1(t, fullLength: fullLength) == null) {
    return 'Needs $fullLength digits (or ${fullLength - 1}; the check digit is added automatically)';
  }
  return null;
}

/// Fills in a missing check digit where the format allows it.
String normalizeContent(String formatId, String content) {
  final String t = content.trim();
  switch (formatId) {
    case 'ean13':
    case 'ean8':
    case 'upca':
    case 'itf14':
      final int full = switch (formatId) {
        'ean13' => 13,
        'ean8' => 8,
        'upca' => 12,
        _ => 14,
      };
      return completeGs1(t, fullLength: full) ?? t;
    case 'codabar':
      // The barcode package wraps start/stop automatically; strip ours.
      final RegExp strip = RegExp(r'^([A-D])(.+?)\1$', caseSensitive: false);
      final RegExpMatch? m = strip.firstMatch(t);
      return m == null ? t : m[2]!;
    default:
      return t;
  }
}
