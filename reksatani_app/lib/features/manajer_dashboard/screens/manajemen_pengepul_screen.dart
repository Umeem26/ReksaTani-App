import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../services/master_data_service.dart';
import '../controllers/manajemen_pengepul_controller.dart';

class ManajemenPengepulScreen extends StatefulWidget {
  const ManajemenPengepulScreen({super.key});

  @override
  State<ManajemenPengepulScreen> createState() => _ManajemenPengepulScreenState();
}

class _ManajemenPengepulScreenState extends State<ManajemenPengepulScreen> {
  final _controller = ManajemenPengepulController();
  final _svc = MasterDataService();
  List<Map<String, dynamic>> _pengepulList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await _controller.getSemuaPengepul();
    if (mounted) {
      setState(() {
        _pengepulList = data;
        _isLoading = false;
      });
    }
  }

  List<TransaksiHiveModel> _getTransaksiAgen(String pengepulId) {
    return _svc.getRiwayatTransaksi().where((t) => t.pengepulId == pengepulId).take(5).toList();
  }

  DateTime? _getWaktuSyncTerakhir(String pengepulId) {
    final trxAgen = _svc.getRiwayatTransaksi().where((t) => t.pengepulId == pengepulId).toList();
    if (trxAgen.isEmpty) return null;

    DateTime? terbaru;
    for (var t in trxAgen) {
      if (terbaru == null || t.createdAt.isAfter(terbaru)) {
        terbaru = t.createdAt;
      }
      if (t.waktuDisinkron != null) {
        if (terbaru == null || t.waktuDisinkron!.isAfter(terbaru)) {
          terbaru = t.waktuDisinkron;
        }
      }
    }
    return terbaru;
  }

  bool _isOnline(DateTime? lastSync) {
    if (lastSync == null) return false;
    final diff = DateTime.now().difference(lastSync);
    return diff.inMinutes.abs() < 60;
  }

  String _timeAgo(DateTime? lastSync) {
    if (lastSync == null) return 'Belum ada aktivitas';
    final diff = DateTime.now().difference(lastSync);
    
    if (diff.inSeconds.abs() < 60) return 'Baru saja';
    if (diff.inMinutes.abs() < 60) return '${diff.inMinutes.abs()}m lalu';
    if (diff.inHours.abs() < 24) return '${diff.inHours.abs()}j lalu';
    if (diff.inDays.abs() < 7) return '${diff.inDays.abs()} hari lalu';
    
    return '${lastSync.day}/${lastSync.month}/${lastSync.year}';
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

  void _showFormDialog({Map<String, dynamic>? dataLama}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => _PengepulFormSheet(
        dataLama: dataLama,
        onSimpan: (username, password, sisaUangJalan) async {
          Navigator.pop(context); // Tutup dialog
          setState(() => _isLoading = true);
          
          bool sukses = false;
          if (dataLama == null) {
            sukses = await _controller.tambahPengepul(
              username: username,
              password: password,
              sisaUangJalan: sisaUangJalan,
            );
          } else {
            sukses = await _controller.editPengepul(
              id: dataLama['_id'],
              username: username,
              password: password,
              sisaUangJalan: sisaUangJalan,
            );
          }

          if (!sukses && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('Gagal menyimpan! Username mungkin sudah terpakai.', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                  ],
                ),
                backgroundColor: AppTheme.merah,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              ),
            );
          }

          await _fetchData();
        },
      ),
    );
  }

  void _hapus(dynamic id, String username) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Agen', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.merah)),
        content: Text('Yakin ingin menghapus akun agen $username?\nAkun ini akan diblokir dan tidak bisa login lagi ke dalam sistem lapangan.', style: const TextStyle(color: AppTheme.textSecond, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _controller.hapusPengepul(id);
              await _fetchData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Hapus Permanen', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── PREMIUM DIGITAL ID CARD BOTTOM SHEET ──
  void _showDetailSheet(Map<String, dynamic> item, List<TransaksiHiveModel> history, DateTime? lastSync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) {
        final online = _isOnline(lastSync);
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIX TYPO: Menggunakan EdgeInsets.only(bottom: 24)
              Center(child: Container(width: 48, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)))),
              
              // 1. Profil Area
              Row(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.hijauMuda.withOpacity(0.3))),
                    child: Center(child: Text(item['username']?.toString().substring(0,1).toUpperCase() ?? '👤', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.hijauTua))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: online ? AppTheme.hijauSoft : AppTheme.bgPage, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? AppTheme.hijauTua : Colors.grey.shade400)),
                                  const SizedBox(width: 6),
                                  Text(
                                    online ? 'Sedang Online' : _timeAgo(lastSync),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: online ? AppTheme.hijauTua : AppTheme.textSecond),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              // 2. Info Finansial Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sisa Uang Jalan', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text((item['role'] ?? 'pengepul').toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          _fmtRupiah((item['sisa_uang_jalan'] ?? 0).toDouble()),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // 3. Riwayat Transaksi List
              const Text('5 Transaksi Terakhir Agen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.3)),
              const SizedBox(height: 16),
              if (history.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
                  child: const Center(child: Text('Belum ada transaksi lapangan.', style: TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600))),
                )
              else
                ...history.map((t) => _TrxDetailRow(trx: t)),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bgPage,
                    foregroundColor: AppTheme.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
                  ),
                  child: const Text('Tutup Panel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('Manajemen Pengepul', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 100.0),
          child: FloatingActionButton.extended(
            onPressed: () => _showFormDialog(),
            backgroundColor: AppTheme.hijauTua,
            elevation: 8,
            icon: const Icon(Icons.person_add_rounded, color: Colors.white),
            label: const Text('Daftarkan Agen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.hijauTua, strokeWidth: 3))
            : _pengepulList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                          child: const Icon(Icons.badge_outlined, size: 48, color: AppTheme.textHint),
                        ),
                        const SizedBox(height: 20),
                        const Text('Belum Ada Agen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        const Text('Gunakan tombol di bawah untuk\nmendaftarkan agen lapangan baru.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.4)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    color: AppTheme.hijauTua,
                    backgroundColor: Colors.white,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 180),
                      itemCount: _pengepulList.length,
                      itemBuilder: (context, index) {
                        final item = _pengepulList[index];
                        final id = item['_id'];
                        final username = item['username'] ?? '';
                        final sisaUangJalan = (item['sisa_uang_jalan'] ?? 0).toDouble();
                        final lastSync = _getWaktuSyncTerakhir(id.toString());
                        final history = _getTransaksiAgen(id.toString());
                        final online = _isOnline(lastSync);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(16)),
                                child: Center(child: Text(username.substring(0,1).toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.hijauTua))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(username, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary, letterSpacing: -0.3)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? AppTheme.hijauMuda : Colors.grey.shade400)),
                                        const SizedBox(width: 6),
                                        Text(
                                          online ? 'Sedang Online' : _timeAgo(lastSync),
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: online ? AppTheme.hijauTua : AppTheme.textSecond),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _fmtRupiahSingkat(sisaUangJalan),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.hijauTua, letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Kas Agen', style: TextStyle(fontSize: 11, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 32, height: 32,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  onSelected: (val) {
                                    if (val == 'detail') _showDetailSheet(item, history, lastSync);
                                    if (val == 'edit') _showFormDialog(dataLama: item);
                                    if (val == 'hapus') _hapus(id, username);
                                  },
                                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecond),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: Colors.white,
                                  elevation: 8,
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.assignment_ind_rounded, size: 18, color: AppTheme.textPrimary), SizedBox(width:8), Text('Profil & Histori', style: TextStyle(fontWeight: FontWeight.w600))])),
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppTheme.textPrimary), SizedBox(width:8), Text('Edit Akun', style: TextStyle(fontWeight: FontWeight.w600))])),
                                    const PopupMenuItem(value: 'hapus', child: Row(children: [Icon(Icons.delete_rounded, color: AppTheme.merah, size: 18), SizedBox(width:8), Text('Hapus', style: TextStyle(color: AppTheme.merah, fontWeight: FontWeight.w600))])),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  String _fmtRupiahSingkat(double angka) {
    if (angka >= 1000000) return 'Rp ${(angka / 1000000).toStringAsFixed(1)} Jt';
    if (angka >= 1000) return 'Rp ${(angka / 1000).toStringAsFixed(0)} Rb';
    return 'Rp ${angka.toInt()}';
  }
}

class _TrxDetailRow extends StatelessWidget {
  final TransaksiHiveModel trx;
  const _TrxDetailRow({required this.trx});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_rounded, color: AppTheme.textSecond, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trx.namaKomoditas} · ${trx.berat.toInt()} kg',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mitra: ${trx.namaPetani} · ${_fmtDate(trx.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecond, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            _fmtRupiah(trx.totalBayar),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.hijauTua, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}';
  
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

// ── BENTO STYLE FORM SHEET PENGEPUL ──
class _PengepulFormSheet extends StatefulWidget {
  final Map<String, dynamic>? dataLama;
  final Function(String username, String password, double sisaUangJalan) onSimpan;

  const _PengepulFormSheet({this.dataLama, required this.onSimpan});

  @override
  State<_PengepulFormSheet> createState() => _PengepulFormSheetState();
}

class _PengepulFormSheetState extends State<_PengepulFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _uangJalanCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    if (widget.dataLama != null) {
      _usernameCtrl.text = widget.dataLama!['username'] ?? '';
      _passwordCtrl.text = widget.dataLama!['password_hash'] ?? '';
      _uangJalanCtrl.text = (widget.dataLama!['sisa_uang_jalan'] ?? 0).toInt().toString();
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _uangJalanCtrl.dispose();
    super.dispose();
  }

  void _simpan() {
    if (!_formKey.currentState!.validate()) return;
    final uang = double.tryParse(_uangJalanCtrl.text) ?? 0.0;
    widget.onSimpan(_usernameCtrl.text, _passwordCtrl.text, uang);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIX TYPO: Menggunakan EdgeInsets.only(bottom: 16)
            Center(child: Container(width: 48, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)))),
            Text(
              widget.dataLama == null ? 'Daftarkan Agen Baru' : 'Edit Akun Agen',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5),
            ),
            const SizedBox(height: 24),
            
            const Text('Username Login', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameCtrl,
              validator: (val) => (val?.isEmpty ?? true) ? 'Username wajib diisi' : null,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: _inputDeco('Masukkan username unik agen'),
            ),
            const SizedBox(height: 16),
            
            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePass,
              validator: (val) => (val?.isEmpty ?? true) ? 'Password wajib diisi' : null,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: _inputDeco('Masukkan password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppTheme.textSecond, size: 20),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text('Suntik Saldo Awal Kas (Rp)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _uangJalanCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (val) => (val?.isEmpty ?? true) ? 'Saldo awal wajib diisi' : null,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.hijauTua),
              decoration: _inputDeco('Contoh: 5000000').copyWith(prefixText: 'Rp '),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hijauTua,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: AppTheme.hijauTua.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Simpan Data Agen', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.merah)),
    );
  }
}