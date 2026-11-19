/// What kind of payload a scanned barcode contains.
enum ContentType {
  url('URL'),
  email('Email'),
  phone('Phone'),
  sms('SMS'),
  wifi('Wi-Fi'),
  vcard('Contact (vCard)'),
  mecard('Contact (MeCard)'),
  event('Calendar event'),
  geo('Location'),
  product('Product'),
  upi('UPI payment'),
  text('Text');

  const ContentType(this.label);

  /// Human-readable label for filters and the result screen.
  final String label;

  /// Stable storage key for the `content_type` column.
  String get storageName => name;

  static ContentType fromStorageName(String name) =>
      ContentType.values.where((ContentType t) => t.name == name).firstOrNull ??
      ContentType.text;
}
