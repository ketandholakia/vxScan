/// Hex helpers for the raw-bytes view on the result screen.
library;

String toHex(List<int> bytes, {int limit = 64}) {
  final StringBuffer out = StringBuffer();
  final int n = bytes.length < limit ? bytes.length : limit;
  for (int i = 0; i < n; i++) {
    out.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    if (i != n - 1) {
      out.write(i % 16 == 15 ? '\n' : ' ');
    }
  }
  if (bytes.length > limit) {
    out.write('… (${bytes.length - limit} more bytes)');
  }
  return out.toString();
}
