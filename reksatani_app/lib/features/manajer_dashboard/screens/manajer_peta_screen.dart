import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final ManajerPetaController _ctrl;
  late final MapController _mapCtrl;
  TransaksiHiveModel? _selectedTrx;

  @override
  void initState() {
    super.initState();
    _ctrl = ManajerPetaController();
    _mapCtrl = MapController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daftarLokasi = _ctrl.getTransaksiDenganLokasi;

    // Titik pusat awal: Lokasi transaksi pertama yang cocok, atau default ke tengah Jawa
    final center = daftarLokasi.isNotEmpty
        ? LatLng(daftarLokasi.first.latitude, daftarLokasi.first.longitude)
        : const LatLng(-7.150975, 110.140259);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: AppTheme.bgCard,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('GIS Distribusi Panen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border),
          ),
        ),
        body: Stack(
          children: [
            // ─── LAPISAN PETA UTAMA ───
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: center,
                initialZoom: daftarLokasi.isNotEmpty ? 12.0 : 6.0,
                onTap: (_, __) => setState(() => _selectedTrx = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.reksatani.app',
                ),
                
                // Inovasi: Lapisan Zona Jangkauan/Kepadatan Panen (Radius Ring)
                CircleLayer(
                  circles: daftarLokasi.map((trx) {
                    final isSelected = _selectedTrx?.idLokal == trx.idLokal;
                    return CircleMarker(
                      point: LatLng(trx.latitude, trx.longitude),
                      // Jangkauan membesar seiring besarnya volume panen (simulasi zona lumbung)
                      radius: 120 + (trx.berat * 0.4),
                      useRadiusInMeter: true,
                      color: (isSelected ? AppTheme.merah : AppTheme.hijauMuda).withOpacity(0.18),
                      borderStrokeWidth: 1.5,
                      borderColor: (isSelected ? AppTheme.merah : AppTheme.hijauMuda).withOpacity(0.6),
                    );
                  }).toList(),
                ),

                // Lapisan Penanda Kustom Modern
                MarkerLayer(
                  markers: daftarLokasi.map((trx) {
                    final isSelected = _selectedTrx?.idLokal == trx.idLokal;
                    return Marker(
                      point: LatLng(trx.latitude, trx.longitude),
                      width: isSelected ? 52 : 42,
                      height: isSelected ? 52 : 42,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedTrx = trx);
                          HapticFeedback.lightImpact();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.merah : AppTheme.hijauTua,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isSelected ? AppTheme.merah : AppTheme.hijauTua).withOpacity(0.4),
                                blurRadius: isSelected ? 12 : 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              trx.gradeTerpilih.isNotEmpty ? trx.gradeTerpilih : '🌾',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: isSelected ? 15 : 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            // ─── BILAH HEADER ANALITIK & FILTER MELAYANG ───
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // 1. Kartu Rekap Analitik Realtime
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                      border: Border.all(color: AppTheme.border.withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeaderStat('Lokasi Aktif', '${daftarLokasi.length} Titik', Icons.place_outlined, AppTheme.hijauTua),
                        _buildHeaderStat('Volume Zona', '${_ctrl.totalVolumeAktif.toInt()} kg', Icons.scale_outlined, AppTheme.hijauMuda),
                        _buildHeaderStat('Valuasi Aset', _fmtRibuSingkat(_ctrl.totalValuasiAktif), Icons.payments_outlined, const Color(0xFF3B82F6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Baris Filter Dinamis (Scrollable)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Filter Komoditas Chips
                        ..._ctrl.daftarKomoditasUnik.map((komoditas) {
                          final isActive = _ctrl.filterKomoditas == komoditas;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(komoditas == 'Semua' ? '🌾 Semua Komoditas' : komoditas),
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                color: isActive ? Colors.white : AppTheme.textSecond,
                              ),
                              selected: isActive,
                              showCheckmark: false,
                              backgroundColor: Colors.white.withOpacity(0.9),
                              selectedColor: AppTheme.hijauTua,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isActive ? AppTheme.hijauTua : AppTheme.border.withOpacity(0.6)),
                              ),
                              onSelected: (_) {
                                _ctrl.setFilterKomoditas(komoditas);
                                setState(() => _selectedTrx = null);
                              },
                            ),
                          );
                        }),

                        Container(
                          height: 20, width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: AppTheme.border,
                        ),

                        // Filter Grade Kualitas Chips
                        ...['Semua', 'A', 'B', 'C'].map((grade) {
                          final isActive = _ctrl.filterGrade == grade;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(grade == 'Semua' ? '⭐ Semua Grade' : 'Grade $grade'),
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                color: isActive ? Colors.white : AppTheme.textSecond,
                              ),
                              selected: isActive,
                              showCheckmark: false,
                              backgroundColor: Colors.white.withOpacity(0.9),
                              selectedColor: AppTheme.hijauMuda,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isActive ? AppTheme.hijauMuda : AppTheme.border.withOpacity(0.6)),
                              ),
                              onSelected: (_) {
                                _ctrl.setFilterGrade(grade);
                                setState(() => _selectedTrx = null);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── TOMBOL BIDIK PEMUSATAN PETA (RECENTER) ───
            Positioned(
              bottom: _selectedTrx != null ? 220 : 32, // Menghindar secara dinamis dari kartu detail
              right: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: FloatingActionButton(
                  heroTag: 'recenterMapBtn',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textPrimary,
                  elevation: 4,
                  child: const Icon(Icons.my_location_rounded, size: 20, color: AppTheme.hijauTua),
                  onPressed: () {
                    if (daftarLokasi.isNotEmpty) {
                      _mapCtrl.move(
                        LatLng(daftarLokasi.first.latitude, daftarLokasi.first.longitude),
                        11.0,
                      );
                    } else {
                      _mapCtrl.move(const LatLng(-7.150975, 110.140259), 6.0);
                    }
                    HapticFeedback.lightImpact();
                  },
                ),
              ),
            ),

            // ─── KARTU DETAIL LOKASI (GLASSMORPHISM POP-UP) ───
            if (_selectedTrx != null)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header info
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.hijauSoft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.hijauMuda.withOpacity(0.3)),
                                ),
                                child: const Text('🌾', style: TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedTrx!.namaKomoditas,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.hijauMuda.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Grade ${_selectedTrx!.gradeTerpilih}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.hijauTua),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Petani: ${_selectedTrx!.namaPetani}',
                                      style: const TextStyle(color: AppTheme.textSecond, fontSize: 12.5, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecond),
                                onPressed: () => setState(() => _selectedTrx = null),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: AppTheme.border.withOpacity(0.6)),
                          const SizedBox(height: 16),
                          
                          // Isi rincian
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Volume Panen', style: TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_selectedTrx!.berat.toInt()} kg',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Valuasi Pembelian', style: TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmtRupiah(_selectedTrx!.totalBayar),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.hijauTua),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Status Sinkronisasi/Lokal Info
                          Row(
                            children: [
                              Icon(
                                _selectedTrx!.statusSinkronisasi == 'synced' ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                                size: 13,
                                color: _selectedTrx!.statusSinkronisasi == 'synced' ? AppTheme.hijauMuda : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _selectedTrx!.statusSinkronisasi == 'synced' ? 'Tersinkronisasi ke Cloud' : 'Menunggu Sinkronisasi Lokal',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedTrx!.statusSinkronisasi == 'synced' ? AppTheme.hijauTua : const Color(0xFF92400E),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _selectedTrx!.pengepulId.isNotEmpty ? 'Agen: ${_selectedTrx!.namaPengepul}' : '',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Pembangun komponen kolom statistik singkat pada header melayang
  Widget _buildHeaderStat(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecond, fontWeight: FontWeight.w500),
        ),
      ],
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

  String _fmtRibuSingkat(double angka) {
    if (angka >= 1000000) {
      return 'Rp ${(angka / 1000000).toStringAsFixed(1)} Jt';
    } else if (angka >= 1000) {
      return 'Rp ${(angka / 1000).toStringAsFixed(0)} Rb';
    }
    return 'Rp ${angka.toInt()}';
  }
}