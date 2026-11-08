/// Memetakan label ML / OCR ke nama komoditas di master data Hive.
///
/// Label router ('gabah', 'kelapa_sawit', 'kopi') tidak sama persis dengan nama
/// master data ("Gabah", "Sawit", "Kopi Robusta"), jadi pencocokan memakai
/// contains-match case-insensitive dengan kata kunci per label.
class CommodityMapper {
  static const Map<String, List<String>> _keywords = {
    'gabah': ['gabah', 'padi'],
    'kelapa_sawit': ['sawit'],
    'sawit': ['sawit'],
    'kopi': ['kopi'],
    'kopi robusta': ['kopi'],
  };

  /// Mengembalikan item pertama yang namanya cocok dengan [label], atau null.
  static T? match<T>(Iterable<T> items, String Function(T) nameOf, String? label) {
    if (label == null) return null;
    final key = label.toLowerCase().trim();
    if (key.isEmpty) return null;
    final terms = _keywords[key] ?? [key.replaceAll('_', ' ')];
    for (final term in terms) {
      for (final item in items) {
        if (nameOf(item).toLowerCase().contains(term)) return item;
      }
    }
    return null;
  }

  /// Label ML lebih dulu; jika tidak ada yang cocok, pakai komoditas hasil OCR.
  static T? matchWithFallback<T>(
    Iterable<T> items,
    String Function(T) nameOf, {
    String? mlLabel,
    String? ocrLabel,
  }) {
    return match(items, nameOf, mlLabel) ?? match(items, nameOf, ocrLabel);
  }
}
