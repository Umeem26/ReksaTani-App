import 'package:flutter/material.dart';
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Komoditas', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus data $nama? Semua riwayat yang terkait tidak akan terhapus, namun tidak bisa dipilih lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await _controller.hapusKomoditas(id);
              await _fetchData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Memastikan tidak ada back button bawaan
        title: const Text(
          'Manajemen Harga & Komoditas',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.hijauTua),
            onPressed: () => _showFormDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.hijauMuda))
          : _komoditasList.isEmpty
              ? const Center(child: Text('Belum ada data komoditas', style: TextStyle(color: AppTheme.textSecond)))
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: AppTheme.hijauMuda,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _komoditasList.length,
                    itemBuilder: (context, index) {
                      final item = _komoditasList[index];
                      final id = item['_id'];
                      final nama = item['nama_komoditas'] ?? '';
                      final satuan = item['unit_satuan'] ?? 'kg';
                      final grades = List<Map<String, dynamic>>.from(item['grade_kualitas'] ?? []);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.cardDecoration(radius: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.hijauSoft,
                                      child: Text('🌾', style: TextStyle(fontSize: 14)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      nama,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ],
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'edit') _showFormDialog(dataLama: item);
                                    if (val == 'hapus') _hapus(id, nama);
                                  },
                                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecond),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width:8), Text('Edit')])),
                                    const PopupMenuItem(value: 'hapus', child: Row(children: [Icon(Icons.delete_outline, color: AppTheme.merah, size: 18), SizedBox(width:8), Text('Hapus', style: TextStyle(color: AppTheme.merah))])),
                                  ],
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            ...grades.map((g) {
                              final gradeName = g['grade'];
                              final harga = (g['harga_maks'] as num).toDouble();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.hijauMuda.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Grade $gradeName',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.hijauTua),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Rp ${harga.toInt()}/$satuan',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

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
  
  // List untuk menyimpan TextEditingController harga dinamis
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.dataLama == null ? 'Tambah Komoditas Baru' : 'Edit Komoditas',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _namaCtrl,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                        decoration: InputDecoration(
                          labelText: 'Nama Komoditas (contoh: Kopi)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _satuanCtrl,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                        decoration: InputDecoration(
                          labelText: 'Unit Satuan (contoh: kg)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Daftar Grade Kualitas & Harga', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 12),
                      ...List.generate(_gradesData.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _gradesData[index]['gradeCtrl'],
                                  validator: (v) => v!.isEmpty ? 'Isi' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Grade',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: _gradesData[index]['hargaCtrl'],
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? 'Isi harga' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Harga Maks',
                                    prefixText: 'Rp ',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              if (_gradesData.length > 1) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: AppTheme.merah),
                                  onPressed: () => _hapusGrade(index),
                                ),
                              ]
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: _tambahGrade,
                        icon: const Icon(Icons.add, color: AppTheme.hijauTua),
                        label: const Text('Tambah Grade Baru', style: TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.hijauMuda,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan Data Komoditas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
