import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/widgets/app_theme.dart';
import '../controllers/manajer_peta_controller.dart';
import '../../../../models/hive/transaksi_hive_model.dart';

class ManajerPetaScreen extends StatefulWidget {
  const ManajerPetaScreen({super.key});

  @override
  State<ManajerPetaScreen> createState() => _ManajerPetaScreenState();
}

class _ManajerPetaScreenState extends State<ManajerPetaScreen> {
  final _ctrl = ManajerPetaController();
  TransaksiHiveModel? _selectedTrx;

  @override
  Widget build(BuildContext context) {
    final daftarLokasi = _ctrl.getTransaksiDenganLokasi;
    
    // Titik tengah peta: Ambil lokasi transaksi pertama, atau default ke tengah Pulau Jawa jika kosong
    final center = daftarLokasi.isNotEmpty
        ? LatLng(daftarLokasi.first.latitude, daftarLokasi.first.longitude)
        : const LatLng(-7.150975, 110.140259);

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text('Peta Persebaran Panen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: daftarLokasi.isNotEmpty ? 12.0 : 6.0,
              // Jika area peta kosong diklik, sembunyikan popup detail
              onTap: (_, __) => setState(() => _selectedTrx = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.reksatani.app',
              ),
              MarkerLayer(
                markers: daftarLokasi.map((trx) {
                  final isSelected = _selectedTrx?.idLokal == trx.idLokal;
                  return Marker(
                    point: LatLng(trx.latitude, trx.longitude),
                    width: 45,
                    height: 45,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTrx = trx),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: isSelected ? 45 : 36,
                        color: isSelected ? AppTheme.merah : AppTheme.hijauTua,
                        shadows: const [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ─── KARTU DETAIL MELAYANG (FLOATING CARD) ───
          if (_selectedTrx != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: _selectedTrx != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(radius: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.grass_rounded, color: AppTheme.hijauMuda, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_selectedTrx!.namaKomoditas} · Grade ${_selectedTrx!.gradeTerpilih}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text('Petani: ${_selectedTrx!.namaPetani}', style: const TextStyle(color: AppTheme.textSecond, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecond),
                            onPressed: () => setState(() => _selectedTrx = null),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Volume Panen', style: TextStyle(fontSize: 11, color: AppTheme.textSecond)),
                              Text('${_selectedTrx!.berat.toInt()} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Nilai Transaksi', style: TextStyle(fontSize: 11, color: AppTheme.textSecond)),
                              Text(_fmtRupiah(_selectedTrx!.totalBayar), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.hijauTua)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtRupiah(double angka) {
    final s = angka.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${buf.toString()}';
  }
}