// Generates the app icon: a teal square with a stylized white QR pattern.
// Run: `dart run tool/gen_icon.dart`
import 'dart:io';

import 'package:image/image.dart' as img;

const int size = 1024;

void main() {
  // Full-square icon (used for the classic launcher icon and splash logo).
  final img.Image icon = img.Image(width: size, height: size);
  img.fill(icon, color: img.ColorRgba8(0, 105, 111, 255));

  _drawQrPattern(icon, inset: 200, module: 36, color: img.ColorRgba8(255, 255, 255, 255));

  final File iconFile = File('assets/icon/app_icon.png');
  iconFile.createSync(recursive: true);
  iconFile.writeAsBytesSync(img.encodePng(icon));

  // Adaptive-icon foreground: pattern centered on transparency, with the
  // safe-zone padding the launcher expects.
  final img.Image fg = img.Image(width: size, height: size);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  _drawQrPattern(fg, inset: 330, module: 30, color: img.ColorRgba8(255, 255, 255, 255));

  final File fgFile = File('assets/icon/app_icon_foreground.png');
  fgFile.createSync(recursive: true);
  fgFile.writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote ${iconFile.path} and ${fgFile.path}');
}

/// Deterministic QR-ish pattern: three finder squares plus a pseudo-random
/// module grid derived from a fixed seed so the icon is reproducible.
void _drawQrPattern(
  img.Image canvas, {
  required int inset,
  required int module,
  required img.Color color,
}) {
  const int grid = 11; // modules per side
  final double cell = (size - inset * 2) / grid;

  // Finder squares: top-left, top-right, bottom-left.
  for (final (int gx, int gy) in <(int, int)>[(0, 0), (grid - 4, 0), (0, grid - 4)]) {
    final double x = inset + gx * cell;
    final double y = inset + gy * cell;
    img.fillRect(
      canvas,
      x1: x.round(),
      y1: y.round(),
      x2: (x + cell * 3).round(),
      y2: (y + cell * 3).round(),
      color: color,
    );
    img.fillRect(
      canvas,
      x1: (x + cell * 0.75).round(),
      y1: (y + cell * 0.75).round(),
      x2: (x + cell * 2.25).round(),
      y2: (y + cell * 2.25).round(),
      color: img.ColorRgba8(0, 105, 111, 255),
    );
  }

  // Pseudo-random data modules (fixed seed → stable icon).
  int seed = 0x05353434;
  for (int gy = 0; gy < grid; gy++) {
    for (int gx = 0; gx < grid; gx++) {
      final bool inFinder = (gx < 4 && gy < 4) ||
          (gx >= grid - 4 && gy < 4) ||
          (gx < 4 && gy >= grid - 4);
      if (inFinder) {
        continue;
      }
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      if (seed % 100 < 55) {
        img.fillRect(
          canvas,
          x1: (inset + gx * cell).round(),
          y1: (inset + gy * cell).round(),
          x2: (inset + (gx + 1) * cell - 2).round(),
          y2: (inset + (gy + 1) * cell - 2).round(),
          color: color,
        );
      }
    }
  }
}
