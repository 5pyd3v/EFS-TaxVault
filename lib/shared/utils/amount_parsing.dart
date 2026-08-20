/// Parses a user-typed or pre-filled money amount. A comma is ALWAYS a
/// thousands separator here, never a decimal point — this app is PKR-only
/// (period as the decimal separator, comma only for grouping, e.g.
/// "357,210.50"). Plain `double.tryParse` doesn't accept commas at all, so
/// without this, any comma in the text — typed directly, or produced by a
/// keyboard whose locale uses comma-as-decimal — made the whole field
/// silently parse to null and fall back to 0, quietly zeroing out a real
/// amount rather than misreading it.
double parseAmount(String text) {
  final cleaned = text.trim().replaceAll(',', '');
  return double.tryParse(cleaned) ?? 0;
}
