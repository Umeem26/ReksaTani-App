import 'package:flutter/material.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../../transaksi_luring/screens/transaksi_screen.dart';
import '../controllers/riwayat_controller.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  late final RiwayatController _ctrl;
  final _searchCtrl = TextEditingController();

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
    final list = _ctrl.filteredTransaksi;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: Column(
        children: [
          // ── Kolom Pencarian ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _ctrl.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Cari nama petani atau komoditas...',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecond, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecond, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _ctrl.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 1.5)),
              ),
            ),
          ),

          // ── Filter Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['Semua', 'Pending', 'Synced'].map((status) {
                final isActive = _ctrl.filterStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : AppTheme.textSecond,
                    ),
                    selected: isActive,
                    showCheckmark: false,
                    backgroundColor: AppTheme.bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isActive ? AppTheme.hijauMuda : AppTheme.border,
                        width: 1.0,
                      ),
                    ),
                    onSelected: (_) => _ctrl.setFilterStatus(status),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Informasi Jumlah Data ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('${list.length} transaksi ditemukan', style: const TextStyle(fontSize: 12, color: AppTheme.textSecond)),
              ],
            ),
          ),

          // ── Daftar Riwayat ──
          Expanded(
            child: list.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final t = list[i];
                      return _TransaksiCard(
                        trx: t,
                        onEdit: t.statusSinkronisasi != 'pending_delete'
                            ? () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TransaksiScreen(editTrx: t)),
                                );
                                // Refresh setelah kembali dari layar edit
                                setState(() {});
                              }
                            : null,
                        onDelete: t.statusSinkronisasi != 'pending_delete'
                            ? () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Hapus Transaksi', style: TextStyle(fontWeight: FontWeight.w700)),
                                    content: const Text('Transaksi ini akan dihapus. Kasbon dan uang jalan akan dikembalikan. Lanjutkan?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && mounted) {
                                  await _ctrl.hapusTransaksi(t);
                                }
                              }
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textHint),
            const SizedBox(height: 12),
            const Text('Tidak ada riwayat transaksi.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
            const SizedBox(height: 4),
            const Text('Coba ubah kata kunci pencarian atau filter status di atas.', style: TextStyle(fontSize: 12, color: AppTheme.textSecond)),
          ],
        ),
      );
}

// ── Komponen Reusable Kartu Riwayat ──
class _TransaksiCard extends StatelessWidget {
  final TransaksiHiveModel trx;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TransaksiCard({required this.trx, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = trx.statusSinkronisasi;
    
    Color badgeBg = AppTheme.hijauSoft;
    Color badgeDot = AppTheme.hijauMuda;
    Color badgeTextCol = AppTheme.hijauTua;
    String badgeText = 'Synced';

    if (status == 'pending') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeDot = const Color(0xFFF59E0B);
      badgeTextCol = const Color(0xFF92400E);
      badgeText = 'Pending';
    } else if (status == 'pending_update') {
      badgeBg = const Color(0xFFDBEAFE);
      badgeDot = const Color(0xFF3B82F6);
      badgeTextCol = const Color(0xFF1E3A8A);
      badgeText = 'Updating';
    } else if (status == 'pending_delete') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeDot = AppTheme.merah;
      badgeTextCol = const Color(0xFF991B1B);
      badgeText = 'Deleting';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('🌾', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trx.namaKomoditas} · ${trx.berat.toInt()} kg',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(trx.namaPetani, style: const TextStyle(fontSize: 11, color: AppTheme.textSecond)),
                if (trx.nominalPotongKasbon > 0) ...[
                  const SizedBox(height: 4),
                  Text('Potong Kasbon: Rp ${_fmtRibu(trx.nominalPotongKasbon.toInt())}', style: const TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                ]
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtRupiah(trx.totalBayar), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.hijauTua)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: badgeDot)),
                    const SizedBox(width: 4),
                    Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeTextCol)),
                  ],
                ),
              ),
            ],
          ),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') onEdit?.call();
                if (val == 'delete') onDelete?.call();
              },
              icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecond),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppTheme.merah), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: AppTheme.merah))])),
              ],
            ),
          ],
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

  String _fmtRibu(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}