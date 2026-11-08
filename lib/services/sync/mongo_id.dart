import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

/// Satu tempat untuk urusan bentuk `_id`.
///
/// Tipe `_id` di Atlas bisa ObjectId atau UUID string, bahkan tercampur dalam
/// satu koleksi. Selain itu, aplikasi lama menyimpan hasil `ObjectId.toString()`
/// ke Hive, lalu ikut menuliskan literal `ObjectId("<hex>")` itu ke `pengepul_id`
/// dan `petani_id` di cloud.
///
/// Aturan: Hive dan semua perbandingan memakai [kanonik], sedangkan filter ke
/// cloud memakai [kandidat] supaya semua bentuk terjangkau. Filter berbasis
/// [kandidat] memakai `$in`, jadi **tidak boleh dipakai untuk upsert**: MongoDB
/// hanya menyalin kesetaraan ke dokumen baru, sehingga upsert yang tidak cocok
/// akan membuat `_id` baru dan dokumen ganda.
class MongoId {
  MongoId._();

  static final RegExp _legacy = RegExp(r'^ObjectId\("([a-fA-F0-9]{24})"\)$');

  /// `id_lokal` yang dibuat aplikasi selalu berakhiran `_<milidetik>`.
  static final RegExp _idLokalAplikasi = RegExp(r'_\d+$');

  /// Bentuk tunggal untuk Hive dan perbandingan: hex untuk ObjectId, apa adanya
  /// untuk UUID, dan string kosong untuk null.
  static String kanonik(Object? raw) {
    if (raw is ObjectId) return raw.oid;
    if (raw == null) return '';
    final s = raw.toString();
    return _legacy.firstMatch(s)?.group(1) ?? s;
  }

  /// Semua bentuk BSON yang mungkin dipakai untuk id ini di Atlas.
  static List<Object> kandidat(Object? raw) {
    final k = kanonik(raw);
    final oid = ObjectId.tryParse(k);
    return [
      k,
      ?oid,
      if (oid != null) 'ObjectId("${oid.oid}")',
    ];
  }

  static Map<String, dynamic> filterId(Object? raw) => filterRef('_id', raw);

  static Map<String, dynamic> filterRef(String field, Object? raw) => {
        field: {r'$in': kandidat(raw)},
      };

  static bool sama(Object? a, Object? b) => kanonik(a) == kanonik(b);

  /// False untuk baris hasil pull dari dokumen cloud yang tidak punya `id_lokal`.
  /// Kunci baris seperti itu adalah `_id` dokumennya, dan nilainya tidak ada di
  /// field `id_lokal` mana pun di cloud.
  static bool idLokalBuatanAplikasi(String idLokal) =>
      _idLokalAplikasi.hasMatch(idLokal);
}
