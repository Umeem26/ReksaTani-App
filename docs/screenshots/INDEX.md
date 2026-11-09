# Screenshots

**Demo data, Nov 2026.** All names, villages, amounts, and transactions are fictional and were seeded into Hive by [`tool/demo/demo_main.dart`](../../tool/demo/demo_main.dart). The app never reached MongoDB Atlas or Cloudinary while these were taken: the demo entrypoint blocks database connections and allows HTTP only to OpenStreetMap tiles.

Captured on an Android emulator (API 35, 1080x2400, light mode) with the status bar in SystemUI demo mode (9:41, full battery). The UI language is the app's own (Indonesian). Camera screens show the **emulator camera feed**, not real photos of receipts or crops. Map tiles © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors.

The account names Asep, Dudung, and `manajer` match the team's test accounts, but no real login took place: the session was seeded locally, because logging in always checks the password against Atlas.

| File | Screen | Role | State | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `01-splash.png` | Splash | All | First launch | |
| `02-onboarding-1.png` | Onboarding 1/3 | All | First launch | Copy is the app's own text |
| `03-onboarding-2.png` | Onboarding 2/3 | All | First launch | Copy mentions "AI price validation"; the app does not do that (AI only suggests the commodity) |
| `04-onboarding-3.png` | Onboarding 3/3 | All | First launch | Copy says "realtime"; sync only runs while the app is open |
| `05-login.png` | Login | All | Empty form | |
| `06-login-gagal-offline.png` | Login | All | Login failed, no server | Expected: first login needs the server |
| `07-agen-beranda.png` | Home | Collector | 7 transactions, 2 pending | |
| `08-agen-beranda-transaksi.png` | Home (scrolled) | Collector | Max prices, latest transactions | Pending and synced badges |
| `09-agen-detail-pending.png` | Transaction detail | Collector | Pending sync, kasbon deduction | No photos in seeded data |
| `10-agen-notifikasi.png` | Notifications | Collector | Sync pending, GPS failed | Seeded notifications |
| `11-agen-pasar.png` | Market prices | Collector | Max price per grade | |
| `12-agen-tren-harga.png` | Price trend | Collector | Current max price only | Price history is not stored yet |
| `13-agen-riwayat.png` | History | Collector | All transactions | |
| `14-agen-profil-cek-server-gagal.png` | Profile | Collector | Server check failed, never synced, 2 waiting | Last-synced state |
| `15-agen-mitra-sync-gagal.png` | Farmers | Collector | Sync failed, 2 waiting | |
| `16-agen-izin-kamera.png` | Camera permission | Collector | Android permission prompt | |
| `17-agen-kamera-nota.png` | Scanner menu | Collector | Before photos | |
| `18-agen-kamera-feed.png` | Camera | Collector | Receipt photo 1/2 | Emulator camera feed |
| `19-agen-sudut-nota.png` | Corner adjust | Collector | Receipt warp | Emulator camera feed |
| `20-agen-kamera-nota-ok.png` | Scanner menu | Collector | Receipt photo taken | Emulator camera feed thumbnail |
| `21-agen-form-transaksi.png` | Transaction form | Collector | No commodity suggestion | The router found no commodity in the emulator feed |
| `22-agen-form-dua-foto.png` | Transaction form | Collector | Two photos attached | Emulator camera feed |
| `23-agen-rubrik-grade.png` | Grade rubric | Collector | Checklist answered, grade A | Rubric `v0.1-draf`, not reviewed by an expert |
| `24-agen-harga-maks-ditolak.png` | Transaction form | Collector | Price above max reset to the limit | |
| `25-agen-izin-lokasi.png` | Location permission | Collector | Android permission prompt | Denied on purpose for the next state |
| `26-agen-simpan-gps-gagal.png` | Save result | Collector | Saved without GPS | Location stored as null |
| `27-agen-pencairan-kasbon.png` | Kasbon disbursement | Collector | Current debt shown | |
| `28-agen-pencairan-tersimpan.png` | Disbursement result | Collector | Saved locally, queued | Debt grows from Rp1.7M to Rp2.2M |
| `29-agen-riwayat-pending.png` | History (pending) | Collector | Disbursements and purchase waiting | Disbursements cannot be edited |
| `30-manajer-beranda.png` | Manager home | Manager | Totals across collectors | |
| `31-manajer-analitik.png` | Analytics | Manager | Sync ratio, stock per commodity | |
| `32-manajer-analitik-lanjut.png` | Analytics (scrolled) | Manager | Grade breakdown | |
| `33-manajer-peta.png` | Map | Manager | Transactions with coordinates | Fictional points; OSM tiles |
| `34-manajer-komoditas-offline-kosong.png` | Commodity management | Manager | Empty while offline | This screen reads from the server only, so it is empty without Atlas |
| `35-manajer-form-harga-maks.png` | Add commodity | Manager | Max price per grade | Example filled in, not saved |
| `36-manajer-pengepul.png` | Collectors | Manager | Two collectors | "Online" is derived from recent demo transactions |
| `37-manajer-detail-agen.png` | Collector detail | Manager | Cash and last 5 transactions | |
