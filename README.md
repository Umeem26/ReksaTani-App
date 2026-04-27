# 🌾 ReksaTani: Manajemen Transaksi & Pengepulan Komoditas Pertanian

ReksaTani adalah platform Sistem Manajemen Rantai Pasok Finansial berbasis *mobile* yang dirancang khusus untuk agen pengepul komoditas pertanian di area *blank spot* (nirsinyal). 

Dibangun dengan arsitektur **Offline-First**, aplikasi ini menjadikan *local storage* sebagai *Single Source of Truth* di lapangan. ReksaTani memungkinkan pengepul untuk mencatat transaksi, memotong piutang (kasbon) petani secara otomatis, dan memvalidasi harga berdasarkan kualitas (Grade) komoditas sepenuhnya tanpa koneksi internet. Seluruh data kompleks termasuk bukti foto ganda dan titik koordinat GPS luring akan diunggah secara asinkron ke *cloud* melalui *Sync Manager* saat perangkat kembali ke area bersinyal.

## ✨ Fitur Unggulan

* **Offline-First & Asynchronous Sync:** Eksekusi transaksi 100% luring. *Sync Manager* bekerja di latar belakang untuk mengamankan data ke *cloud* saat jaringan stabil tanpa memblokir UI pengguna.
* **Automasi Rekonsiliasi Finansial:** Kalkulasi dan pemotongan otomatis sisa piutang (*kasbon*) petani dari total pembayaran secara luring.
* **Dynamic Grade Constraint:** Validasi penolakan *input* secara cerdas jika harga beli agen melebihi batas patokan Manajer berdasarkan Grade Kualitas komoditas.
* **Dual-Hardware Authentication:** Bukti transaksi yang tak terbantahkan melalui tangkapan kamera ganda (nota fisik & wujud barang).
* **Offline Geotagging:** Merekam titik spasial (GPS) transaksi di pelosok yang kemudian divisualisasikan dalam Peta Digital pada Dasbor Manajer.
* **Role-Based Access Control (RBAC):** Pemisahan antarmuka secara aman antara Pengepul Lapangan dan Manajer Gudang.

## 🛠️ Tech Stack

* **Frontend & Mobile Framework:** Flutter
* **Local Database / Cache:** Hive (NoSQL)
* **Cloud Database:** MongoDB Atlas (via REST API)
* **Architecture Pattern:** Clean Architecture / 3-Tier Layer (Presentation, Domain, Data)

---

## 👨‍💻 Identitas Tim Pengembang (Kelompok C4)

Proyek ini dikembangkan oleh tiga mahasiswa dari program studi D-3 Teknik Informatika, Politeknik Negeri Bandung, dengan pembagian fokus pengerjaan sebagai berikut:

| Nama | NIM | Peran |
| :--- | :--- | :--- |
| **Hisyam Khaeru Umam** | 241511078 | **Project Manager & Full Stack.** |
| **Ibnu Hilmi Athaillah** | 241511079 | **Full Stack Developer.** |
| **Muhammad Ihsan Ramadhan** | 241511083 | **Full Stack Developer.** |

---

> **Status Proyek:** Sedang dalam masa pengembangan (Proyek 4 - Semester Genap 2026).
