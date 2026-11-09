# Screenshots

**Demo data, Nov 2026.** All names, villages, amounts, and transactions are fictional and were seeded into Hive by [`tool/demo/demo_main.dart`](../../tool/demo/demo_main.dart). The app never reached MongoDB Atlas or Cloudinary while these were taken: the demo entrypoint blocks database connections and allows HTTP only to OpenStreetMap tiles. Notification texts are the ones the app itself produces.

Captured on an Android emulator (API 35, 1080x2400, light mode) with the status bar in SystemUI demo mode (9:41, full battery). The UI language is the app's own (Indonesian). Map tiles © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors.

The account names Asep, Dudung, and `manajer` match the team's test accounts, but no real login took place: the session was seeded locally, because logging in always checks the password against Atlas.

## Camera screens

Camera screens are the **emulator camera feed** (Android emulator virtual scene), not photos taken in the field. Real public-dataset photos were loaded as posters in that scene and photographed through the app's camera:

- Oil palm bunches: Suharjito & Junior, "Annotated Video Dataset of Oil Palm Fruit Bunch Piles for Ripeness Grading", Science Data Bank, DOI [10.57760/sciencedb.j00001.00713](https://doi.org/10.57760/sciencedb.j00001.00713), CC BY 4.0.
- Green coffee beans: CBD Coffee Beans Dataset, Mendeley Data, DOI [10.17632/52877z55vr.1](https://doi.org/10.17632/52877z55vr.1), CC BY 4.0.

The receipt is a generated image marked "CONTOH / DEMO - FIKTIF" with a "DEMO · FIKTIF" watermark; it is not a real receipt. Commodity suggestions are shown exactly as the router produced them; nothing was adjusted.

## Flow

| File | Screen | Role | State | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `01-splash.png` | Splash | All | First launch | |
| `02-onboarding-1.png` | Onboarding 1/3 | All | First launch | Offline recording, sent when the connection returns |
| `03-onboarding-2.png` | Onboarding 2/3 | All | First launch | Price limit per commodity, grade by checklist, AI only suggests the commodity |
| `04-onboarding-3.png` | Onboarding 3/3 | All | First launch | Manager map and totals from synced data |
| `05-login.png` | Login | All | Empty form | |
| `06-login-gagal-offline.png` | Login | All | Login failed, no server | Expected: first login needs the server |
| `07-agen-beranda.png` | Home | Collector | 7 transactions, 2 pending | |
| `08-agen-beranda-transaksi.png` | Home (scrolled) | Collector | Max prices, latest transactions | Pending and synced badges |
| `09-agen-detail-foto.png` | Transaction detail | Collector | Pending, kasbon deduction, proof photos | Seeded local files: dataset palm photo and the demo receipt |
| `10-agen-notifikasi.png` | Notifications | Collector | Sync failed, saved, synced | App-generated texts |
| `11-agen-pasar.png` | Market prices | Collector | Max price per grade | |
| `12-agen-tren-harga.png` | Price trend | Collector | Current max price only | Price history is not stored yet |
| `13-agen-riwayat.png` | History | Collector | All transactions | |
| `14-agen-profil-cek-server-gagal.png` | Profile | Collector | Server check failed, never synced, 2 waiting | Last-synced state |
| `15-agen-mitra-sync-gagal.png` | Farmers | Collector | Sync failed, 2 waiting | |
| `16-agen-izin-kamera.png` | Camera permission | Collector | Android permission prompt | |
| `17-agen-kamera-menu.png` | Scanner menu | Collector | Before photos | |
| `18-agen-kamera-nota-poster.png` | Camera | Collector | Receipt photo 1/2 | Emulator camera feed; demo receipt poster |
| `19-agen-sudut-nota.png` | Corner adjust | Collector | Auto-detected corners | Emulator camera feed; corners left as detected (they do not fit the receipt exactly) |
| `20-agen-kamera-nota-ok.png` | Scanner menu | Collector | Receipt photo taken | Emulator camera feed thumbnail |
| `21-agen-kamera-sawit-poster.png` | Camera | Collector | Commodity photo 2/2 | Emulator camera feed; dataset palm photo posters |
| `22-agen-form-saran-ai.png` | Transaction form | Collector | No commodity suggestion | Router (still): not a commodity 0.85, coffee 0.08, palm 0.07 |
| `23-agen-form-ocr-dua-foto.png` | Transaction form | Collector | OCR weight and price, two photos | 1250 kg and Rp1,950 read from the demo receipt |
| `24-agen-form-kasbon-rubrik.png` | Transaction form | Collector | Kasbon to deduct, rubric draft notice | Rubric `v0.1-draf`, not reviewed by an expert |
| `25-agen-rubrik-grade.png` | Grade rubric | Collector | Checklist answered, grade A | |
| `26-agen-harga-maks-ditolak.png` | Transaction form | Collector | Price above max reset to the limit | |
| `27-agen-izin-lokasi.png` | Location permission | Collector | Android permission prompt | Denied on purpose |
| `28-agen-simpan-gps-gagal.png` | Save result | Collector | Saved without GPS, kasbon deducted | Location permission denied in the emulator; stored as null. Shows total, kasbon deduction, and cash paid (1250 kg × Rp1,950 read by OCR; receipt picked from the gallery) |
| `29-agen-kamera-kopi-poster.png` | Camera | Collector | Commodity photo | Emulator camera feed; dataset coffee photo posters |
| `30-agen-form-saran-ai-kopi.png` | Transaction form | Collector | No commodity suggestion | Router (still): not a commodity 0.98, coffee 0.01 |
| `31-agen-pencairan-kasbon.png` | Kasbon disbursement | Collector | Current debt shown | |
| `32-agen-pencairan-tersimpan.png` | Disbursement result | Collector | Saved locally, queued | Debt grows from Rp1.7M to Rp2.2M |
| `33-agen-riwayat-pending.png` | History (pending) | Collector | Disbursements and purchase waiting | Disbursements cannot be edited |
| `34-manajer-beranda.png` | Manager home | Manager | Totals across collectors | |
| `35-manajer-notifikasi.png` | Notifications | Manager | New transactions, sync failed | App-generated texts; the sync pill sits above the list |
| `36-manajer-analitik.png` | Analytics | Manager | Sync ratio, stock per commodity | |
| `37-manajer-analitik-lanjut.png` | Analytics (scrolled) | Manager | Grade breakdown | |
| `38-manajer-peta.png` | Map | Manager | Transactions with coordinates | Fictional points; OSM tiles |
| `39-manajer-komoditas-gagal-muat.png` | Commodity management | Manager | Load failed, retry button | This screen reads from the server only |
| `40-manajer-form-harga-maks.png` | Add commodity | Manager | Max price per grade | Example filled in, not saved |
| `41-manajer-pengepul.png` | Collectors | Manager | Two collectors | "Online" is derived from recent demo transactions |
| `42-manajer-detail-agen.png` | Collector detail | Manager | Cash and last 5 transactions | |
