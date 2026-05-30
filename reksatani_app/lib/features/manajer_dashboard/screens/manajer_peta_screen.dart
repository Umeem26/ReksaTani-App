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
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Row(
            children: [
              Icon(Icons.map_rounded, color: AppTheme.hijauTua, size: 22),
              SizedBox(width: 8),
              Text('GIS Distribusi Panen', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
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
                
                // Zona Jangkauan/Kepadatan Panen (Radius Ring)
                CircleLayer(
                  circles: daftarLokasi.map((trx) {
                    final isSelected = _selectedTrx?.idLokal == trx.idLokal;
                    return CircleMarker(
                      point: LatLng(trx.latitude, trx.longitude),
                      radius: 120 + (trx.berat * 0.4),
                      useRadiusInMeter: true,
                      color: (isSelected ? AppTheme.merah : AppTheme.hijauMuda).withOpacity(0.15),
                      borderStrokeWidth: 2,
                      borderColor: (isSelected ? AppTheme.merah : AppTheme.hijauMuda).withOpacity(0.5),
                    );
                  }).toList(),
                ),

                // Lapisan Penanda Kustom Modern (Pulsing Markers)
                MarkerLayer(
                  markers: daftarLokasi.map((trx) {
                    final isSelected = _selectedTrx?.idLokal == trx.idLokal;
                    return Marker(
                      point: LatLng(trx.latitude, trx.longitude),
                      width: isSelected ? 56 : 44,
                      height: isSelected ? 56 : 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedTrx = trx);
                          HapticFeedback.lightImpact();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isSelected 
                                  ? [AppTheme.merah, const Color(0xFF991B1B)] 
                                  : [AppTheme.hijauMuda, AppTheme.hijauTua],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isSelected ? AppTheme.merah : AppTheme.hijauTua).withOpacity(0.5),
                                blurRadius: isSelected ? 16 : 10,
                                offset: const Offset(0, 6),
                              )
                            ],
                            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                          ),
                          child: Center(
                            child: Text(
                              trx.gradeTerpilih.isNotEmpty ? trx.gradeTerpilih : '🌾',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: isSelected ? 18 : 14,
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

            // ─── BILAH HEADER ANALITIK & FILTER MELAYANG (ULTRA GLASS) ───
            Positioned(
              top: 16, left: 16, right: 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          // 1. Kartu Rekap Analitik Realtime
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildHeaderStat('Lokasi Aktif', '${daftarLokasi.length} Titik', Icons.place_rounded, AppTheme.hijauTua),
                                Container(width: 1, height: 30, color: AppTheme.border),
                                _buildHeaderStat('Volume Zona', '${_ctrl.totalVolumeAktif.toInt()} kg', Icons.scale_rounded, AppTheme.hijauMuda),
                                Container(width: 1, height: 30, color: AppTheme.border),
                                _buildHeaderStat('Valuasi Aset', _fmtRibuSingkat(_ctrl.totalValuasiAktif), Icons.payments_rounded, const Color(0xFF3B82F6)),
                              ],
                            ),
                          ),
                          
                          Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
                          
                          // 2. Baris Filter Dinamis (Scrollable)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  // Filter Komoditas Chips
                                  ..._ctrl.daftarKomoditasUnik.map((komoditas) {
                                    final isActive = _ctrl.filterKomoditas == komoditas;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _GlassChip(
                                        label: komoditas == 'Semua' ? '🌾 Semua Komoditas' : komoditas,
                                        isActive: isActive,
                                        activeColor: AppTheme.hijauTua,
                                        onTap: () {
                                          _ctrl.setFilterKomoditas(komoditas);
                                          setState(() => _selectedTrx = null);
                                        },
                                      ),
                                    );
                                  }),

                                  Container(
                                    height: 24, width: 1.5,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    color: AppTheme.border.withOpacity(0.8),
                                  ),

                                  // Filter Grade Kualitas Chips
                                  ...['Semua', 'A', 'B', 'C'].map((grade) {
                                    final isActive = _ctrl.filterGrade == grade;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _GlassChip(
                                        label: grade == 'Semua' ? '⭐ Semua Grade' : 'Grade $grade',
                                        isActive: isActive,
                                        activeColor: const Color(0xFFF59E0B),
                                        onTap: () {
                                          _ctrl.setFilterGrade(grade);
                                          setState(() => _selectedTrx = null);
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── TOMBOL BIDIK PEMUSATAN PETA (RECENTER) ───
            Positioned(
              // FIX: Angka bottom disesuaikan (110) agar melayang TEPAT DI ATAS navbar kaca saat tdk ada pop-up.
              // Jika ada pop-up (380), tombol melompat naik menghindari pop-up.
              bottom: _selectedTrx != null ? 380 : 110, 
              right: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                child: FloatingActionButton(
                  heroTag: 'recenterMapBtn',
                  mini: false,
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.hijauTua,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
                  child: const Icon(Icons.my_location_rounded, size: 24),
                  onPressed: () {
                    if (daftarLokasi.isNotEmpty) {
                      _mapCtrl.move(
                        LatLng(daftarLokasi.first.latitude, daftarLokasi.first.longitude),
                        11.0,
                      );
                    } else {
                      _mapCtrl.move(const LatLng(-7.150975, 110.140259), 6.0);
                    }
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ),

            // ─── KARTU DETAIL LOKASI (APPLE MAPS STYLE POP-UP) ───
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              // FIX: Angka bottom disesuaikan (110) agar melayang TEPAT DI ATAS navbar kaca. -400 untuk menyembunyikan ke bawah.
              bottom: _selectedTrx != null ? 110 : -400,
              left: 16, right: 16,
              child: _selectedTrx == null ? const SizedBox.shrink() : Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 35, offset: const Offset(0, 15))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pill drag handle illusion
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          
                          // Header info
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  color: AppTheme.hijauSoft,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.hijauMuda.withOpacity(0.3)),
                                ),
                                child: const Center(child: Text('🌾', style: TextStyle(fontSize: 26))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedTrx!.namaKomoditas,
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.textPrimary, letterSpacing: -0.5),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.hijauTua,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Grade ${_selectedTrx!.gradeTerpilih}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_rounded, size: 14, color: AppTheme.textSecond),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _selectedTrx!.namaPetani,
                                            style: const TextStyle(color: AppTheme.textSecond, fontSize: 13, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _selectedTrx = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppTheme.bgPage, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textHint),
                                ),
                              )
                            ],
                          ),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1, color: AppTheme.border),
                          ),
                          
                          // Isi rincian
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Volume Panen', style: TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selectedTrx!.berat.toInt()} kg',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Valuasi Pembelian', style: TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _fmtRupiah(_selectedTrx!.totalBayar),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.hijauTua, letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Lencana Status Ekstra Elegan
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTrx!.statusSinkronisasi == 'synced' ? AppTheme.hijauSoft : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedTrx!.statusSinkronisasi == 'synced' ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                                  size: 16,
                                  color: _selectedTrx!.statusSinkronisasi == 'synced' ? AppTheme.hijauTua : const Color(0xFFD97706),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTrx!.statusSinkronisasi == 'synced' ? 'Tersinkronisasi ke Cloud' : 'Menunggu Sinkronisasi Lokal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedTrx!.statusSinkronisasi == 'synced' ? AppTheme.hijauTua : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                                if (_selectedTrx!.pengepulId.isNotEmpty)
                                  Text(
                                    'Agen: ${_selectedTrx!.namaPengepul}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: (_selectedTrx!.statusSinkronisasi == 'synced' ? AppTheme.hijauTua : const Color(0xFFD97706)).withOpacity(0.6)),
                                  )
                              ],
                            ),
                          )
                        ],
                      ),
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

  Widget _buildHeaderStat(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.3)),
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

// Komponen Pembantu Filter Chips Glassmorphism
class _GlassChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _GlassChip({required this.label, required this.isActive, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppTheme.bgPage.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? activeColor : AppTheme.border, width: 1.5),
          boxShadow: isActive ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? Colors.white : AppTheme.textSecond,
          ),
        ),
      ),
    );
  }
}