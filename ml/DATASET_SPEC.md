# Spesifikasi dataset validasi lapangan ReksaTani

Tujuan: satu set foto **beku** (frozen) untuk mengukur model grade secara jujur. Foto di set ini
**tidak boleh** dipakai untuk melatih ulang model. Rubrik grade yang dipakai ada di Project
"Linkedin" → `reksatani-grading-rubric.md` (DRAFT v0.1, belum disahkan oleh validator).

## 1. Struktur folder

```
dataset/
  gabah/        A/  B/  C/
  kopi/         A/  B/  C/
  kelapa_sawit/ A/  B/  C/
  bukan_komoditas/          # tanpa sub-folder grade
```

Nama folder = label kebenaran (ground truth) hasil penilaian manusia menurut rubrik, bukan tebakan model.

## 2. Nama file

`<id_sampel>__<bebas>.jpg`, contoh `gA01__1.jpg`, `gA01__2.jpg`.

- `id_sampel` = satu tumpukan/tandan/karung fisik yang sama. Beberapa foto dari sampel yang sama
  boleh ada, tetapi harus memakai id yang sama.
- Alasannya: kalau foto dari sampel yang sama masuk ke set latih **dan** set uji, hasil evaluasi
  tampak bagus padahal model hanya menghafal. Pemisahan dilakukan per `id_sampel`, bukan per foto.

## 3. Jumlah minimum

| bagian | minimum | catatan |
|---|---|---|
| tiap kombinasi komoditas × grade (9 sel) | 30 foto dari ≥10 sampel berbeda | lebih banyak lebih baik |
| bukan_komoditas (hard negative) | 60 foto | gelas kopi, tanah, karung kosong, tangan, ruangan, komoditas lain, foto gelap/buram |

Total minimum: 270 + 60 = 330 foto. Dengan n=30 interval kepercayaan masih lebar
(± sekitar 15 poin persen); angka hasil evaluasi harus dibaca bersama intervalnya.

## 4. Cara memotret (usulan, bisa disesuaikan setelah uji coba)

- Gunakan ponsel yang sungguh dipakai pengguna aplikasi, bukan hanya satu perangkat bagus.
- Satu lapis komoditas di atas alas polos (nampan/terpal), bukan gundukan. (Ini saran saya, belum ada data
  yang menguji mana yang lebih baik; bandingkan lewat kolom `latar` di metadata.)
- Variasikan cahaya (terang, redup, teduh) dan jarak; jangan semua foto sempurna, karena di lapangan tidak begitu.
- Jangan edit atau filter foto. Simpan JPEG asli.

## 5. Penilaian grade (siapa dan bagaimana)

- Pemberi label grade harus orang yang paham mutu komoditas (pengepul, petugas gudang, penyuluh), bukan hanya tim.
- Idealnya dua orang menilai secara terpisah untuk sebagian foto; ukur kesepakatan dengan Cohen's kappa.
  Foto yang tidak disepakati dibuang atau diputuskan bersama.
- Catat siapa pelabelnya di metadata.

## 6. Lembar metadata (opsional tapi disarankan)

`metadata_template.csv` berisi kolom: file (path relatif terhadap `dataset/`), id_sampel, sumber, perangkat,
cahaya, latar, pelabel, tanggal_foto, catatan. Kolom `file` wajib jika dipakai; kolom lain bebas.
Pakai `--metadata metadata.csv --group-by cahaya` agar laporan memecah hasil per kondisi.

## 7. Data pribadi

Foto jangan memuat wajah, plat kendaraan, atau dokumen identitas. Folder `dataset/` sudah masuk
`.gitignore` agar tidak ter-commit.
