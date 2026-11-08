# ml/ — evaluasi model grade ReksaTani

Folder ini **tidak** menyentuh kode aplikasi. Isinya alat ukur untuk menjawab: seberapa benar model
TFLite yang ada di `assets/models/` terhadap foto lapangan berlabel.

## Pasang

```
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
```

Jika `ai-edge-litert` tidak bisa dipasang di Windows, pakai `pip install tensorflow` sebagai gantinya
(skrip mencoba ai_edge_litert → tflite_runtime → tensorflow secara berurutan).

## Jalankan

```
python eval_models.py --data dataset --models ../assets/models
```

Opsi: `--preprocess squash|crop` (cara memperkecil ke 224x224; coba keduanya, aplikasi harus memakai yang sama dengan
yang terbukti lebih baik), `--metadata metadata.csv --group-by cahaya`, `--no-dup-check`, `--out reports`.

Hasil ada di `reports/<waktu>/`: `report.md` (dibaca manusia), `predictions.csv` (per foto), `metrics.json`.

## Cara membaca

- **Router**: matriks 4×4 (bukan_komoditas, gabah, kelapa_sawit, kopi), recall per kelas dengan interval Wilson 95%, ECE.
- **Grader (oracle)**: akurasi grade jika komoditas dianggap benar; fokus pada baris "over-grading", yaitu
  B/C yang diprediksi A. Itu kesalahan yang merugikan uang.
- **Sweep ambang**: untuk tiap ambang keyakinan, berapa foto yang diterima otomatis, berapa yang benar, dan berapa
  foto non-komoditas yang salah diterima.
- **Cek duplikat**: foto hampir kembar dengan `id_sampel` berbeda. Jika ada, hasil tidak bisa dipercaya sebelum diperbaiki.

## Catatan penting

- Urutan kelas router diasumsikan alfabetis dan urutan grader A/B/C. Tidak ada notebook pelatihan yang bisa
  memastikannya. Jika matriks tampak "terbalik" secara sistematis, urutan inilah yang perlu diperiksa dengan Ibnu.
- Input model: RGB float [0,255] (lapisan Rescaling 1/255 sudah menyatu di model). Sesuai hasil audit.
- Angka dari dataset kecil atau sintetis hanya membuktikan skrip berjalan, bukan kualitas model.
- Spesifikasi pengumpulan data: `DATASET_SPEC.md`.

## Uji awal sawit dari data publik

`prepare_sawit_public.py` membangun set uji dari dataset Suharjito & Junior (CC BY 4.0, lihat `data_public/README.md`)
hanya dari video satu-kelas. Pemetaan kelas ke A/B/C ada di bagian `MAPPING` skrip itu dan masih DRAF.

```
python prepare_sawit_public.py --zips data_public --out dataset_sawit_public
python eval_models.py --data dataset_sawit_public --models ../assets/models --out reports/sawit_public
```

Catatan: jumlah sampel efektif = jumlah video (frame dari satu video nyaris kembar). Baca bagian "Sample-level view" di laporan,
bukan hanya angka per foto. Foto 416x416 berbentuk persegi, jadi `--preprocess crop` dan `squash` memberi hasil identik.
