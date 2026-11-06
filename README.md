# 🌾 ReksaTani: Manajemen Transaksi & Pengepulan Komoditas Pertanian

ReksaTani adalah aplikasi Android (Flutter) untuk agen pengepul komoditas pertanian yang sering bekerja tanpa sinyal, dan untuk manajer yang memantau mereka.

Agen mencatat pembelian di HP tanpa internet. Aplikasi menghitung potongan kasbon petani, menahan harga di atas batas per grade, dan menyimpan foto serta lokasi. Saat ada sinyal, data dikirim ke MongoDB Atlas.

> **Status:** dalam pengembangan (Proyek 4, Semester Genap 2026). **Belum siap rilis:** pencairan kasbon belum bisa sampai ke cloud (lihat [Batasan](#batasan)).

## Arsitektur

Aplikasi berjalan **offline-first dengan Hive**, dan **sinkron langsung dari perangkat ke MongoDB Atlas**. **Tidak ada backend sendiri**: tidak ada server aplikasi atau API di antara HP dan database.

```text
Layar Flutter → Controller → Hive (di HP)
                                 ↕  SyncEngine, memakai driver mongo_dart
                           MongoDB Atlas

Foto: HP → Cloudinary (unggahan tanpa tanda tangan)
```

- **Hive** menyimpan transaksi, petani, komoditas, dan sesi login. Pencatatan transaksi tidak butuh internet. Login pertama butuh internet.
- **Sinkronisasi** berjalan selama aplikasi terbuka: sesudah menyimpan, saat sinyal kembali, dan saat layar ditarik untuk menyegarkan. Tidak ada layanan latar belakang yang berjalan saat aplikasi ditutup.
- **Saldo** kasbon dan uang jalan di cloud dihitung ulang dari saldo dasar ditambah transaksi. Aturan koreksi manualnya ada di [tool/atlas/README.md](reksatani_app/tool/atlas/README.md).
- **Kode** dibagi per fitur di `lib/features/` (layar dan controller), dengan layanan bersama di `lib/services/`.

## Fitur

- Pencatatan pembelian luring, dengan potongan kasbon otomatis dan batas harga per grade dari manajer.
- Foto nota dan barang, serta lokasi GPS. Bila GPS gagal, transaksi tetap tersimpan dan agen diberi tahu.
- Pemindaian nota dengan OCR dan saran grade dari model TFLite di perangkat. Agen tetap bisa mengganti grade di form.
- Dasbor manajer: analitik, peta transaksi, serta pengelolaan agen dan komoditas.
- Layar harga menampilkan `harga_maks` saat ini. Riwayat harga belum disimpan, jadi tidak ada grafik tren.

## Batasan

**Menahan rilis**

- **Pencairan kasbon belum tersinkron.** Validator Atlas hanya menerima grade A, B, atau C, sedangkan baris pencairan memakai grade `-`, sehingga ditolak dengan kode 121. Barisnya tetap `pending` di HP, manajer tidak melihatnya, dan saldo di HP berbeda dari cloud. Mengubah validator butuh akun admin Atlas.

**Keamanan**

- **RBAC hanya di sisi klien.** Peran pengepul dan manajer hanya menentukan layar yang tampil. Database tidak membatasi akses per peran.
- **Kredensial database ada di dalam APK.** URI MongoDB hanya diobfuskasi, jadi siapa pun yang mengekstraknya dapat mengakses database dengan hak akun tersebut.
- **Unggahan Cloudinary memakai preset tanpa tanda tangan.** Siapa pun yang mengetahui nama cloud dan preset dapat mengunggah.
- **Login diverifikasi di perangkat**, dengan membaca `password_hash` dari cloud. Fallback password plaintext masih ada sampai data Atlas diperiksa.

**Data dan model**

- **Model grade belum tervalidasi.** Saran grade belum teruji pada data lapangan, jadi grade sebaiknya diputuskan manusia.
- **Lokasi yang gagal tersimpan sebagai 0,0**, karena validator Atlas menolak null. Peta manajer melewati titik ini.
- **`harga_maks` 0 berarti tanpa batas harga** pada pemeriksaan transaksi.

## Status pengujian

Ketiga kelompok ini berbeda bobotnya. Lulus dengan fake bukan bukti perilaku Atlas.

### Terbukti di tes dengan fake

`flutter test` memakai `FakeRemote` di memori. Penjaga di `test/flutter_test_config.dart` memblokir koneksi database dan HTTP sungguhan.

- Saldo: potongan kasbon, edit, hapus, top-up, dan skenario beberapa HP.
- Sinkronisasi: kirim ulang, percobaan ulang terbatas, dan penolakan server.
- Foto yang tertunda, antrean perubahan petani, dan aturan harga serta foto di controller.
- Angka manajer yang tidak memuat pencairan, validasi dan hasil tulis komoditas, pesan login, dan pemberitahuan GPS.

### Terbukti di Atlas lewat uji asap

Dijalankan sekali pada 2026-11-06 dengan `tool/atlas/uji_asap.dart`, memakai `MongoRemote` dan `SyncEngine` asli, sebelum perubahan terakhir di kode aplikasi. Skripnya berhenti merah di langkah pencairan.

- Simpan pembelian dan sinkron, sinkron ulang tanpa tulisan baru, dan kirim ulang saat balasan hilang.
- Edit, hapus, dan top-up manajer sampai ke HP agen.
- Saldo tertulis pada `_id` ObjectId maupun string, dan pembelian tanpa petani.
- `id_lokal` ganda ditolak dengan kode 11000, dan pull dengan projection.
- Penolakan pencairan oleh validator (kode 121).

### Belum teruji

- Pencairan kasbon sampai ke cloud, serta hapus pencairan di server.
- Login, pengelolaan komoditas, `pushPetani`, dan `tambahPengepul` terhadap Atlas.
- Unggahan foto ke Cloudinary.
- Mulai offline lalu online, dan koneksi yang menggantung di perangkat nyata.
- GPS dan seluruh layar di HP sungguhan.
- APK dengan `applicationId` baru dan penandatanganan dengan keystore rilis.
- Akurasi model grade pada data lapangan.

## Setup

1. Masuk ke folder aplikasi: `cd reksatani_app`
2. Salin `.env.example` menjadi `.env`, lalu isi nilai setiap variabel.
3. Generate file environment: `dart run build_runner build --delete-conflicting-outputs`
4. Jalankan aplikasi: `flutter run`

Untuk build rilis, buat `android/key.properties` berisi `storeFile`, `storePassword`, `keyAlias`, dan `keyPassword`. Tanpa berkas itu, build rilis memakai kunci debug dan tidak layak dibagikan.

Sebelum rilis, ikuti [runbook Atlas](reksatani_app/tool/atlas/README.md).

---

## 👨‍💻 Identitas Tim Pengembang (Kelompok C4)

Proyek ini dikembangkan oleh tiga mahasiswa dari program studi D-3 Teknik Informatika, Politeknik Negeri Bandung, dengan pembagian fokus pengerjaan sebagai berikut:

| Nama | NIM | Peran |
| :--- | :--- | :--- |
| **Hisyam Khaeru Umam** | 241511078 | **Project Manager & Full Stack.** |
| **Ibnu Hilmi Athaillah** | 241511079 | **Full Stack Developer.** |
| **Muhammad Ihsan Ramadhan** | 241511083 | **Full Stack Developer.** |
