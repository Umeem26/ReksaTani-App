// Kueri baca saja. Tidak ada yang ditulis.
//
//   mongosh "$MONGO_URI" --quiet --file tool/atlas/kueri_baca.js

function judul(teks) {
  print("\n== " + teks);
}

function tipePer(koleksi, field) {
  return db[koleksi].aggregate([
    { $group: {
        _id: {
          tipe: { $type: "$" + field },
          literalLama: { $cond: [
            { $eq: [{ $type: "$" + field }, "string"] },
            { $regexMatch: { input: "$" + field, regex: /^ObjectId\(/ } },
            false,
          ] },
        },
        n: { $sum: 1 },
    } },
  ]).toArray();
}

judul("Tipe _id per koleksi");
["users", "petani", "komoditas", "transaksi"].forEach(function (c) {
  print(c);
  printjson(db[c].aggregate([
    { $group: { _id: { $type: "$_id" }, n: { $sum: 1 } } },
  ]).toArray());
});

judul("Bentuk referensi");
print("transaksi.pengepul_id"); printjson(tipePer("transaksi", "pengepul_id"));
print("transaksi.petani_id");   printjson(tipePer("transaksi", "petani_id"));
print("petani.pengepul_id");    printjson(tipePer("petani", "pengepul_id"));

judul("Duplikat id_lokal");
printjson(db.transaksi.aggregate([
  { $match: { id_lokal: { $type: "string" } } },
  { $group: { _id: "$id_lokal", n: { $sum: 1 }, ids: { $push: "$_id" } } },
  { $match: { n: { $gt: 1 } } },
]).toArray());

judul("Transaksi tanpa id_lokal");
print(db.transaksi.countDocuments({ id_lokal: { $not: { $type: "string" } } }));

judul("Index transaksi");
printjson(db.transaksi.getIndexes());

judul("Path lokal foto di cloud");
print(db.transaksi.countDocuments({ $or: [
  { foto_nota: { $nin: ["", null], $not: /^https?:/ } },
  { foto_fisik_barang: { $nin: ["", null], $not: /^https?:/ } },
] }));

judul("String 24-hex yang bisa tertukar dengan ObjectId");
printjson(db.petani.find(
  { _id: { $type: "string", $regex: /^[0-9a-fA-F]{24}$/ } },
  { _id: 1 },
).toArray());

judul("Belum punya saldo dasar");
print("petani " + db.petani.countDocuments({ saldo_dasar_kasbon: { $exists: false } }));
print("agen   " + db.users.countDocuments({
  role: "pengepul",
  saldo_dasar_uang_jalan: { $exists: false },
}));
