# Runbook Atlas

Untuk yang memegang akses Atlas. Ihsan sudah mengonfirmasi bahwa isi Atlas adalah data uji dan boleh direset.

Semua skrip Dart membaca URI dari variabel lingkungan `MONGO_URI` dan tidak pernah mencetaknya. Tanpa `--confirm`, skrip hanya mencetak apa yang akan dilakukan.

## Urutan rilis

Jangan rilis APK dari titik tengah branch. Urutan ini dijalankan sekali, sebelum APK baru dibagikan.

1. **Hentikan APK lama di semua HP.** APK lama masih menulis `$inc` dan `$set` absolut, yang merusak saldo turunan.

2. **Lihat keadaan data** (baca saja):

   ```bash
   mongosh "$MONGO_URI" --quiet --file tool/atlas/kueri_baca.js
   ```

3. **Cadangkan** bila masih ingin menyimpan data uji: `mongodump --uri "$MONGO_URI" --out cadangan/`

4. **Reset data uji.** Jalankan dulu tanpa `--confirm`, periksa jumlahnya, lalu ulangi dengan `--confirm`:

   ```bash
   dart run tool/atlas/reset_data_uji.dart
   dart run tool/atlas/reset_data_uji.dart --kasbon=0 --confirm
   ```

   - Yang dihapus hanya koleksi `transaksi`. Akun, petani, dan komoditas tetap ada.
   - Saldo tiap petani dan agen diatur ulang sehingga `sisa_* == saldo_dasar_*`. Nilainya, berurutan: `--kasbon=N` atau `--uang-jalan=N`, saldo dasar yang sudah ada, lalu sisa sekarang.
   - Kasbon lama tidak punya riwayat transaksi, jadi `--kasbon=0` biasanya yang diinginkan.

5. **Isi saldo dasar yang masih kosong.** Setelah reset seharusnya tidak ada lagi, jadi langkah ini sekadar memastikan:

   ```bash
   dart run tool/atlas/isi_saldo_dasar.dart
   dart run tool/atlas/isi_saldo_dasar.dart --confirm
   ```

   Hanya menyentuh dokumen yang belum punya field. Bila masih ada transaksi, skrip memperingatkan: efeknya akan terhitung lagi di atas saldo dasar itu.

6. **Buat index:**

   ```bash
   dart run tool/atlas/buat_index.dart
   dart run tool/atlas/buat_index.dart --confirm
   ```

7. **Hapus data aplikasi di semua HP, lalu pasang APK baru.** Baris lama yang masih tersimpan di HP akan terkirim ulang dan menghidupkan kembali transaksi yang sudah direset.

## Aturan setelah rilis

- `sisa_hutang_kasbon` dan `sisa_uang_jalan` adalah hasil hitungan: `saldo_dasar + jumlah delta transaksi`. Mengubahnya langsung di Atlas atau Compass akan tertimpa pada sync berikutnya.
- Untuk koreksi manual, ubah `saldo_dasar_*` dan `sisa_*` dengan selisih yang sama.
- Dokumen tanpa `saldo_dasar_*` tidak pernah ditulis oleh aplikasi dan dilaporkan sebagai `belum_dimigrasi`.

## Uji asap pada Atlas

Semua tes otomatis memakai fake di memori. `uji_asap.dart` menjalankan `MongoRemote` dan `SyncEngine` asli terhadap Atlas, hanya pada dokumen `asap-` miliknya, lalu menghapusnya:

```bash
ASAP_KONFIRMASI=1 MONGO_URI=... flutter test --no-pub tool/atlas/uji_asap.dart
```

Tabel di bawah sudah dijalankan pada 2026-11-06, kecuali "mulai offline". Skrip berhenti merah pada langkah pencairan selama validator `transaksi` hanya menerima grade A, B, C.

| Uji | Yang diamati |
|---|---|
| Simpan transaksi online | Dokumen punya `id_lokal`, saldo petani dan agen berubah |
| Sinkron lagi | Tidak ada dokumen baru, saldo tetap |
| Edit dan hapus transaksi | Saldo cloud mengikuti |
| Top-up manajer | `saldo_dasar_uang_jalan` dan `sisa_uang_jalan` naik sebesar selisih, lalu sampai ke HP agen |
| `_id` ObjectId dan string | Saldo tertulis pada keduanya |
| Dua `id_lokal` sama setelah index | Ditolak dengan kode 11000 |
| Mulai offline, lalu online | Sync dan login hidup tanpa restart |
| Pull dengan projection (`modernFind`) | Daftar petani, agen, komoditas, dan riwayat terisi |
