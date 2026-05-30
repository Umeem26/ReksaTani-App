import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/app_theme.dart';
import '../controllers/manajemen_komoditas_controller.dart';

class ManajemenKomoditasScreen extends StatefulWidget {
  const ManajemenKomoditasScreen({super.key});

  @override
  State<ManajemenKomoditasScreen> createState() => _ManajemenKomoditasScreenState();
}

class _ManajemenKomoditasScreenState extends State<ManajemenKomoditasScreen> {
  final _controller = ManajemenKomoditasController();
  List<Map<String, dynamic>> _komoditasList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await _controller.getSemuaKomoditas();
    if (mounted) {
      setState(() {
        _komoditasList = data;
        _isLoading = false;
      });
    }
  }

  void _showFormDialog({Map<String, dynamic>? dataLama}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => _KomoditasFormSheet(
        dataLama: dataLama,
        onSimpan: (nama, satuan, grades) async {
          Navigator.pop(context); // Tutup dialog
          setState(() => _isLoading = true);
          
          if (dataLama == null) {
            await _controller.tambahKomoditas(
              namaKomoditas: nama,
              unitSatuan: satuan,
              gradeKualitas: grades,
            );
          } else {
            await _controller.editKomoditas(
              id: dataLama['_id'],
              namaKomoditas: nama,
              unitSatuan: satuan,
              gradeKualitas: grades,
            );
          }
          await _fetchData();
        },
      ),
    );
  }

  void _hapus(dynamic id, String nama) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Komoditas', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.merah)),
        content: Text('Yakin ingin menghapus data $nama?\nSemua riwayat yang terkait tidak akan terhapus, namun tidak bisa dipilih lagi saat transaksi baru.', style: const TextStyle(color: AppTheme.textSecond, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _controller.hapusKomoditas(id);
              await _fetchData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Hapus Permanen', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
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
          title: const Text('Manajemen Komoditas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 100.0), // Hindari tertutup navbar bawah
          child: FloatingActionButton.extended(
            onPressed: () => _showFormDialog(),
            backgroundColor: AppTheme.hijauTua,
            elevation: 8,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Tambah Komoditas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.hijauTua, strokeWidth: 3))
            : _komoditasList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                          child: const Icon(Icons.category_outlined, size: 48, color: AppTheme.textHint),
                        ),
                        const SizedBox(height: 20),
                        const Text('Belum Ada Komoditas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        const Text('Gunakan tombol di bawah untuk\nmenambahkan harga & komoditas baru.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.4)),
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
                      itemCount: _komoditasList.length,
                      itemBuilder: (context, index) {
                        final item = _komoditasList[index];
                        final id = item['_id'];
                        final nama = item['nama_komoditas'] ?? '';
                        final satuan = item['unit_satuan'] ?? 'kg';
                        final grades = List<Map<String, dynamic>>.from(item['grade_kualitas'] ?? []);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Header Kartu Komoditas ──
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48, height: 48,
                                          decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(14)),
                                          child: const Center(child: Text('🌾', style: TextStyle(fontSize: 22))),
                                        ),
                                        const SizedBox(width: 14),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nama, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary, letterSpacing: -0.3)),
                                            const SizedBox(height: 4),
                                            Text('${grades.length} Variasi Grade', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      width: 32, height: 32,
                                      child: PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        onSelected: (val) {
                                          if (val == 'edit') _showFormDialog(dataLama: item);
                                          if (val == 'hapus') _hapus(id, nama);
                                        },
                                        icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textSecond),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        color: Colors.white,
                                        elevation: 8,
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppTheme.textPrimary), SizedBox(width:8), Text('Edit', style: TextStyle(fontWeight: FontWeight.w600))])),
                                          const PopupMenuItem(value: 'hapus', child: Row(children: [Icon(Icons.delete_rounded, color: AppTheme.merah, size: 18), SizedBox(width:8), Text('Hapus', style: TextStyle(color: AppTheme.merah, fontWeight: FontWeight.w600))])),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              
                              Container(height: 1, color: AppTheme.bgPage),
                              
                              // ── Daftar Harga per Grade ──
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                child: Column(
                                  children: grades.map((g) {
                                    final gradeName = g['grade'];
                                    final harga = (g['harga_maks'] as num).toDouble();
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: AppTheme.hijauMuda.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                            child: Text('Grade $gradeName', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.hijauTua)),
                                          ),
                                          Text(
                                            'Rp ${_fmtRupiahSingkat(harga)} / $satuan',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
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
    final s = angka.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── BENTO STYLE FORM SHEET ──
class _KomoditasFormSheet extends StatefulWidget {
  final Map<String, dynamic>? dataLama;
  final Function(String nama, String satuan, List<Map<String, dynamic>> grades) onSimpan;

  const _KomoditasFormSheet({this.dataLama, required this.onSimpan});

  @override
  State<_KomoditasFormSheet> createState() => _KomoditasFormSheetState();
}

class _KomoditasFormSheetState extends State<_KomoditasFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _satuanCtrl = TextEditingController();
  
  final List<Map<String, dynamic>> _gradesData = [];

  @override
  void initState() {
    super.initState();
    if (widget.dataLama != null) {
      _namaCtrl.text = widget.dataLama!['nama_komoditas'] ?? '';
      _satuanCtrl.text = widget.dataLama!['unit_satuan'] ?? 'kg';
      
      final grades = List<Map<String, dynamic>>.from(widget.dataLama!['grade_kualitas'] ?? []);
      for (var g in grades) {
        _gradesData.add({
          'gradeCtrl': TextEditingController(text: g['grade']),
          'hargaCtrl': TextEditingController(text: (g['harga_maks'] as num).toInt().toString()),
        });
      }
    } else {
      _satuanCtrl.text = 'kg';
      _gradesData.add({
        'gradeCtrl': TextEditingController(text: 'A'),
        'hargaCtrl': TextEditingController(),
      });
    }
  }

  void _tambahGrade() {
    setState(() {
      _gradesData.add({
        'gradeCtrl': TextEditingController(),
        'hargaCtrl': TextEditingController(),
      });
    });
  }

  void _hapusGrade(int index) {
    if (_gradesData.length > 1) {
      setState(() {
        _gradesData[index]['gradeCtrl'].dispose();
        _gradesData[index]['hargaCtrl'].dispose();
        _gradesData.removeAt(index);
      });
    }
  }

  void _simpan() {
    if (_formKey.currentState!.validate()) {
      List<Map<String, dynamic>> hasilGrades = [];
      for (var item in _gradesData) {
        hasilGrades.add({
          'grade': item['gradeCtrl'].text.trim().toUpperCase(),
          'harga_maks': double.tryParse(item['hargaCtrl'].text.trim()) ?? 0.0,
        });
      }
      widget.onSimpan(_namaCtrl.text.trim(), _satuanCtrl.text.trim(), hasilGrades);
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _satuanCtrl.dispose();
    for (var item in _gradesData) {
      item['gradeCtrl'].dispose();
      item['hargaCtrl'].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // FIX TYPO: Menggunakan EdgeInsets.only(bottom: 16)
            Center(child: Container(width: 48, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)))),
            Text(
              widget.dataLama == null ? 'Tambah Komoditas Baru' : 'Edit Komoditas',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5),
            ),
            const SizedBox(height: 24),
            
            // Area Scrollable untuk Input
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nama Komoditas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _namaCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      decoration: _inputDeco('Contoh: Biji Kopi'),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Unit Satuan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _satuanCtrl,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      decoration: _inputDeco('Contoh: kg'),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grade & Harga Maksimal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textPrimary)),
                        TextButton.icon(
                          onPressed: _tambahGrade,
                          icon: const Icon(Icons.add_circle_rounded, color: AppTheme.hijauTua, size: 18),
                          label: const Text('Tambah', style: TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Dynamic Grade List (Bento Box inside)
                    ...List.generate(_gradesData.length, (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _gradesData[index]['gradeCtrl'],
                                validator: (v) => v!.isEmpty ? 'Isi' : null,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.hijauTua),
                                decoration: _inputDeco('Grade', isSmall: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: _gradesData[index]['hargaCtrl'],
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? 'Isi harga' : null,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                                decoration: _inputDeco('Harga (Rp)', isSmall: true).copyWith(prefixText: 'Rp '),
                              ),
                            ),
                            if (_gradesData.length > 1) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: IconButton(
                                  icon: const Icon(Icons.remove_circle_rounded, color: AppTheme.merah, size: 24),
                                  onPressed: () => _hapusGrade(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ]
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hijauTua,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: AppTheme.hijauTua.withOpacity(0.4),
                ),
                child: const Text('Simpan Komoditas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, {bool isSmall = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textHint, fontSize: isSmall ? 13 : 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 12 : 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.merah)),
    );
  }
}