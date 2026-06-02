import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../controllers/riwayat_controller.dart';
import '../../../../shared/widgets/transaksi_detail_sheet.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  late final RiwayatController _ctrl;
  final _searchCtrl = TextEditingController();
  
  // ── INOVASI: Variabel Pelacak Filter Tab ──
  int _selectedTab = 0; // 0: Semua, 1: Pending, 2: Tersinkron

  @override
  void initState() {
    super.initState();
    _ctrl = RiwayatController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Ambil data asli yang sudah di-search
    final baseList = _ctrl.filteredTransaksi;
    
    // 2. Terapkan Filter Tab (Pending vs Synced)
    List<TransaksiHiveModel> listTampil = baseList;
    if (_selectedTab == 1) {
      // Pending: Semua status yang BUKAN synced
      listTampil = baseList.where((t) => t.statusSinkronisasi != 'synced').toList();
    } else if (_selectedTab == 2) {
      // Selesai: Hanya yang statusnya synced
      listTampil = baseList.where((t) => t.statusSinkronisasi == 'synced').toList();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
          
          // ── INOVASI: Header Sticky Sempurna (Search + Segmented Tabs) ──
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(132),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _ctrl.setSearchQuery,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari petani atau komoditas...',
                        hintStyle: TextStyle(color: AppTheme.textHint.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecond, size: 22),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppTheme.textHint, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _ctrl.setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.bgPage,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Segmented Filter Tabs ala iOS
                  _buildSegmentedTab(),
                  const SizedBox(height: 12),
                  
                  Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        ),
        
        body: Column(
          children: [
            // Meta Info Jumlah Data
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.list_alt_rounded, color: AppTheme.hijauTua, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Menampilkan ${listTampil.length} transaksi',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            // Daftar Transaksi Invoice Card
            Expanded(
              child: listTampil.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: listTampil.length,
                      itemBuilder: (_, i) => _TransaksiCardPremium(
                        trx: listTampil[i],
                        onEdit: listTampil[i].statusSinkronisasi != 'pending_delete'
                            ? () async {
                                final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TransaksiScreen(editTrx: listTampil[i])));
                                if (changed == true && mounted) setState(() {});
                              }
                            : null,
                        onDelete: listTampil[i].statusSinkronisasi != 'pending_delete'
                            ? () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    title: const Text('Hapus Transaksi', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.merah)),
                                    content: const Text('Transaksi ini akan dihapus permanen dari perangkat. Lanjutkan?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond))),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
                                        child: const Text('Hapus Permanen'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && mounted) {
                                  await _ctrl.hapusTransaksi(listTampil[i]);
                                }
                              }
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── INOVASI: Widget Segmented Control Modern ──
  Widget _buildSegmentedTab() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgPage, // Background abu-abu
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Semua'),
          _buildTabItem(1, 'Pending'),
          _buildTabItem(2, 'Tersinkron'),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? AppTheme.textPrimary : AppTheme.textSecond,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    String title = 'Pencarian Kosong';
    String desc = 'Tidak ada transaksi yang cocok\ndengan kata kunci pencarian.';
    
    if (_searchCtrl.text.isEmpty) {
      if (_selectedTab == 1) {
        title = 'Bagus Sekali!';
        desc = 'Tidak ada transaksi yang berstatus pending.\nSemua data sudah tersinkronisasi.';
      } else if (_selectedTab == 2) {
        title = 'Belum Ada Sinkronisasi';
        desc = 'Belum ada transaksi yang berhasil\ndikirim ke server pusat.';
      } else {
        title = 'Belum Ada Transaksi';
        desc = 'Tekan ikon kamera di menu bawah\nuntuk memulai transaksi baru.';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
            child: Icon(_selectedTab == 1 ? Icons.cloud_done_rounded : Icons.receipt_long_rounded, size: 48, color: AppTheme.textHint),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── INOVASI: KARTU TRANSAKSI PREMIUM (BERBENTUK INVOICE / TIKET) ───
class _TransaksiCardPremium extends StatelessWidget {
  final TransaksiHiveModel trx;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TransaksiCardPremium({required this.trx, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = trx.statusSinkronisasi;
    final isKasbonMurni = trx.namaKomoditas.toLowerCase().contains('pencairan kasbon');

    // Pengaturan Detail Badge Status Sinkronisasi
    String badgeLabel = 'Tersinkron';
    Color badgeBg = AppTheme.hijauSoft;
    Color badgeTextCol = AppTheme.hijauTua;
    IconData badgeIcon = Icons.cloud_done_rounded;

    if (status == 'pending') { 
      badgeLabel = 'Menunggu Sinkron'; 
      badgeBg = const Color(0xFFFEF3C7); 
      badgeTextCol = const Color(0xFFB45309); 
      badgeIcon = Icons.cloud_upload_rounded; 
    } else if (status == 'pending_update') { 
      badgeLabel = 'Menunggu Update'; 
      badgeBg = const Color(0xFFDBEAFE); 
      badgeTextCol = const Color(0xFF1D4ED8); 
      badgeIcon = Icons.sync_rounded; 
    } else if (status == 'pending_delete') { 
      badgeLabel = 'Akan Dihapus'; 
      badgeBg = const Color(0xFFFEE2E2); 
      badgeTextCol = const Color(0xFFB91C1C); 
      badgeIcon = Icons.delete_sweep_rounded; 
    }

    return GestureDetector(
      onTap: () => TransaksiDetailSheet.show(context, trx),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border.withOpacity(0.6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            // ── BAGIAN ATAS (INFO PETANI & TANGGAL) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.person_rounded, size: 14, color: AppTheme.textSecond),
                      ),
                      const SizedBox(width: 8),
                      Text(trx.namaPetani, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text(_fmtWaktu(trx.createdAt), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            
            Container(height: 1, color: AppTheme.bgPage), // Divider Halus
            
            // ── BAGIAN TENGAH (KOMODITAS & HARGA TOTAL) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  // Ikon Barang
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: isKasbonMurni ? const Color(0xFFFEF3C7) : AppTheme.hijauSoft.withOpacity(0.5), 
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: Center(
                      child: isKasbonMurni 
                          ? const Icon(Icons.payments_rounded, color: Color(0xFFF59E0B), size: 26) 
                          : const Text('🌾', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Info Komoditas
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isKasbonMurni ? 'Pencairan Kasbon' : trx.namaKomoditas,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isKasbonMurni ? const Color(0xFFB45309) : AppTheme.textPrimary, letterSpacing: -0.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isKasbonMurni ? 'Pinjaman uang jalan' : 'Kuantitas: ${trx.berat.toInt()} kg',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  
                  // Nominal Bayar
                  Text(
                    _fmtRupiah(trx.totalBayar),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isKasbonMurni ? const Color(0xFFB45309) : AppTheme.hijauTua, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
            
            Container(height: 1, color: AppTheme.bgPage), // Divider Halus

            // ── BAGIAN BAWAH (STATUS SYNC & ACTION BUTTONS) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 14, color: badgeTextCol),
                        const SizedBox(width: 6),
                        Text(badgeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeTextCol)),
                      ],
                    ),
                  ),
                  
                  // Action Buttons (Edit & Delete) yang modern
                  Row(
                    children: [
                      if (onEdit != null)
                        _ActionBtn(icon: Icons.edit_rounded, color: AppTheme.textPrimary, onTap: onEdit!),
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        _ActionBtn(icon: Icons.delete_rounded, color: AppTheme.merah, onTap: onDelete!),
                      ],
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
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

  String _fmtWaktu(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// Widget Bantuan Tombol Aksi Bawah
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}