import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// Small chip showing a barcode format's name (QR Code, EAN-13, …).
///
/// Takes the zxing `Format` bit flag straight from the database.
class FormatChip extends StatelessWidget {
  const FormatChip({super.key, required this.format});

  final int format;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        format.name,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
