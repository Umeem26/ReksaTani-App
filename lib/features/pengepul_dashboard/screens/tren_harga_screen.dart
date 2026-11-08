import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/connectivity_wrapper.dart';
import '../../../../services/master_data_service.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../controllers/tren_harga_controller.dart';

class TrenHargaScreen extends StatefulWidget {
  const TrenHargaScreen({super.key});

  @override
  State<TrenHargaScreen> createState() => _TrenHargaScreenState();
}

class _TrenHargaScreenState extends State<TrenHargaScreen> {
  late final TrenHargaController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TrenHargaController();
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
    // KITA KEMBALI MENGGUNAKAN LOGIKA ASLI DARI CONTROLLERMU
    final item = _ctrl.itemTerpilih;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text('Analitik Tren Pasar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
          ),
        ),
        body: ConnectivityWrapper(
          child: _ctrl.daftarTren.isEmpty
              ? RefreshIndicator(
                  color: AppTheme.hijauMuda,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await MasterDataService().syncAll();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      alignment: Alignment.center,
                      child: const Text('Data komoditas belum tersedia.', style: TextStyle(color: AppTheme.textHint)),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // ── INOVASI: Floating Dropdown Selector ──
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KOMODITAS AKTIF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecond, letterSpacing: 1.0)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.bgPage,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border, width: 1.5),
                            ),
                            child: DropdownButtonHideUnderline(
                              // MENGGUNAKAN SELECTED INDEX SESUAI LOGIKAMU
                              child: DropdownButton<int>(
                                value: _ctrl.selectedIndex,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.hijauTua, size: 28),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                items: List.generate(_ctrl.daftarTren.length, (index) {
                                  final currentItem = _ctrl.daftarTren[index];
                                  return DropdownMenuItem<int>(
                                    value: index,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                                          child: Text(AppTheme.getCommodityIcon(currentItem.namaKomoditas), style: const TextStyle(fontSize: 14)),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('${currentItem.namaKomoditas} - Grade ${currentItem.grade}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                  );
                                }),
                                onChanged: (val) {
                                  if (val != null) {
                                    _ctrl.setSelectedIndex(val); // Fungsi ASLI dari controllermu
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── KONTEN UTAMA ──
                    if (item != null)
                      Expanded(
                        child: RefreshIndicator(
                          color: AppTheme.hijauMuda,
                          backgroundColor: Colors.white,
                          onRefresh: () async {
                            await MasterDataService().syncAll();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                            children: [
                              // Info Harga Saat ini
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.headerGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Harga Maksimal Saat Ini', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('Rp ${_fmt(item.hargaSaatIni.toInt())} / ${item.satuan}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white, letterSpacing: -0.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Tidak ada riwayat harga yang tersimpan, jadi tidak ada grafik.
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: AppTheme.textSecond, size: 22),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(TrenHargaController.labelTanpaRiwayat, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  String _fmt(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
