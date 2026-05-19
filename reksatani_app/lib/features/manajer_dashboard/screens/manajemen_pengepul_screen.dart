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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              const SnackBar(
                content: Text('Gagal menyimpan data! Username mungkin sudah terpakai.'),
                backgroundColor: AppTheme.merah,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Akun Pengepul', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus akun $username? Akun ini tidak akan bisa login lagi ke dalam sistem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _controller.hapusPengepul(id);
              await _fetchData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> item, List<TransaksiHiveModel> history, DateTime? lastSync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        final online = _isOnline(lastSync);
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).viewInsets.bottom + 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.hijauSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('👤', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: online ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              online ? 'Online' : _timeAgo(lastSync),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: online ? Colors.green.shade700 : AppTheme.textSecond,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(radius: 14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sisa Uang Jalan', style: TextStyle(fontSize: 13, color: AppTheme.textSecond)),
                        Text(
                          _fmtRupiah((item['sisa_uang_jalan'] ?? 0).toDouble()),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.hijauTua),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Role Akun', style: TextStyle(fontSize: 13, color: AppTheme.textSecond)),
                        Text(
                          (item['role'] ?? 'pengepul').toString().toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Riwayat 5 Transaksi Terakhir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Belum ada transaksi dari agen ini.', style: TextStyle(fontSize: 13, color: AppTheme.textSecond))),
                )
              else
                ...history.map((t) => _TrxDetailRow(trx: t)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.hijauMuda,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Manajemen Akun Pengepul',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: AppTheme.hijauTua,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.hijauMuda))
          : _pengepulList.isEmpty
              ? const Center(child: Text('Belum ada data agen terdaftar', style: TextStyle(color: AppTheme.textSecond)))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: AppTheme.hijauMuda,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
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
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.cardDecoration(radius: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppTheme.hijauSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: Text('👤', style: TextStyle(fontSize: 20))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: online ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        online ? 'Online' : _timeAgo(lastSync),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: online ? Colors.green.shade700 : AppTheme.textSecond,
                                        ),
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
                                  _fmtRupiah(sisaUangJalan),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.hijauTua),
                                ),
                                const SizedBox(height: 2),
                                const Text('Sisa Uang Jalan', style: TextStyle(fontSize: 11, color: AppTheme.textSecond)),
                              ],
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'detail') _showDetailSheet(item, history, lastSync);
                                if (val == 'edit') _showFormDialog(dataLama: item);
                                if (val == 'hapus') _hapus(id, username);
                              },
                              icon: const Icon(Icons.more_vert, color: AppTheme.textSecond),
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.info_outline, size: 18), SizedBox(width:8), Text('Lihat Detail')])),
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width:8), Text('Edit Akun')])),
                                const PopupMenuItem(value: 'hapus', child: Row(children: [Icon(Icons.delete_outline, color: AppTheme.merah, size: 18), SizedBox(width:8), Text('Hapus', style: TextStyle(color: AppTheme.merah))])),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _TrxDetailRow extends StatelessWidget {
  final TransaksiHiveModel trx;
  const _TrxDetailRow({required this.trx});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgPage.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trx.namaKomoditas} · ${trx.berat.toInt()} kg',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trx.namaPetani} · ${_fmtDate(trx.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecond),
                ),
              ],
            ),
          ),
          Text(
            _fmtRupiah(trx.totalBayar),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.hijauTua),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
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
      padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).viewInsets.bottom + 48),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.dataLama == null ? 'Tambah Akun Pengepul' : 'Edit Akun Pengepul',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 20),
            const Text('Username', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _usernameCtrl,
              validator: (val) => (val?.isEmpty ?? true) ? 'Username wajib diisi' : null,
              decoration: InputDecoration(
                hintText: 'Masukkan username agen',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                filled: true,
                fillColor: AppTheme.bgPage,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePass,
              validator: (val) => (val?.isEmpty ?? true) ? 'Password wajib diisi' : null,
              decoration: InputDecoration(
                hintText: 'Masukkan password',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                filled: true,
                fillColor: AppTheme.bgPage,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 1.5)),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecond, size: 18),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Saldo Awal Uang Jalan (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _uangJalanCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (val) => (val?.isEmpty ?? true) ? 'Saldo awal wajib diisi' : null,
              decoration: InputDecoration(
                hintText: 'Contoh: 2500000',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                filled: true,
                fillColor: AppTheme.bgPage,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 1.5)),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hijauMuda,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Simpan Data Agen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
