import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../models/hive/petani_hive_model.dart';
import '../../../../../shared/widgets/app_theme.dart';
import '../../../../../services/hive_service.dart';
import '../../../../../services/mongodb_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mongo_dart/mongo_dart.dart' show modify, where;

class ManajemenPetaniScreen extends StatefulWidget {
  const ManajemenPetaniScreen({super.key});

  @override
  State<ManajemenPetaniScreen> createState() => _ManajemenPetaniScreenState();
}

class _ManajemenPetaniScreenState extends State<ManajemenPetaniScreen> {
  final _hiveService = HiveService();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _tampilkanFormPetani({PetaniHiveModel? petani}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => PetaniFormSheet(
        petaniLama: petani,
        onSimpan: (nama, desa) async {
          if (petani == null) {
            final id = const Uuid().v4();
            final currentUser = _hiveService.usersBox.get('currentUser')!;
            final baru = PetaniHiveModel(
              id: id,
              namaPetani: nama,
              desa: desa,
              pengepulId: currentUser.id,
              sisaHutangKasbon: 0.0,
              waktuDibuat: DateTime.now(),
            );
            await _hiveService.petaniBox.put(id, baru);
            try {
              final col = MongoDatabase.getCollection('petani');
              await col.insertOne({
                '_id': id,
                'nama_petani': nama,
                'desa': desa,
                'pengepul_id': currentUser.id,
                'sisa_hutang_kasbon': 0.0,
                'created_at': DateTime.now().toIso8601String(),
              });
            } catch (_) {}
          } else {
            petani.namaPetani = nama;
            petani.desa = desa;
            await petani.save();
            try {
              final col = MongoDatabase.getCollection('petani');
              await col.updateOne(where.eq('_id', petani.id), modify.set('nama_petani', nama).set('desa', desa));
            } catch (_) {}
          }
          if (mounted) {
            Navigator.pop(context);
            setState(() {});
          }
        },
      ),
    );
  }

  void _hapusPetani(PetaniHiveModel petani) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Petani', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.merah)),
        content: Text('Yakin ingin menghapus ${petani.namaPetani} dari daftar mitra?', style: const TextStyle(color: AppTheme.textSecond, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w700))),
          ElevatedButton(
            onPressed: () async {
              final idHapus = petani.id;
              await petani.delete();
              try {
                final col = MongoDatabase.getCollection('petani');
                await col.deleteOne(where.eq('_id', idHapus));
              } catch (_) {}
              if (mounted) { Navigator.pop(context); setState(() {}); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.merah, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _hiveService.usersBox.get('currentUser');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bgPage,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Manajemen Mitra', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80), // Untuk Search Bar Sticky
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau asal desa...',
                        hintStyle: TextStyle(color: AppTheme.textHint.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecond, size: 22),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.textHint, size: 20), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
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
                  Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        ),
        body: ValueListenableBuilder(
          valueListenable: _hiveService.petaniBox.listenable(),
          builder: (context, Box<PetaniHiveModel> box, _) {
            if (user == null) return const Center(child: Text('User tidak ditemukan'));
            
            final listPetani = box.values.where((p) {
              final isMilikUser = p.pengepulId == user.id;
              final matchSearch = p.namaPetani.toLowerCase().contains(_searchQuery) || p.desa.toLowerCase().contains(_searchQuery);
              return isMilikUser && matchSearch;
            }).toList();

            if (listPetani.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                      child: const Icon(Icons.group_off_rounded, size: 48, color: AppTheme.textHint),
                    ),
                    const SizedBox(height: 20),
                    const Text('Belum ada mitra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    const Text('Gunakan tombol di bawah untuk\nmenambahkan mitra petani baru.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.4)),
                  ],
                ),
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              itemCount: listPetani.length,
              itemBuilder: (context, index) {
                final p = listPetani[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(16)),
                        child: Center(
                          child: Text(p.namaPetani.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w900, fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.namaPetani, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary, letterSpacing: -0.3)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: AppTheme.textHint, size: 14),
                                const SizedBox(width: 4),
                                Text(p.desa, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (val) { if (val == 'edit') _tampilkanFormPetani(petani: p); if (val == 'delete') _hapusPetani(p); },
                        icon: const Icon(Icons.more_vert_rounded, size: 24, color: AppTheme.textSecond),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: Colors.white,
                        elevation: 10,
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: AppTheme.textPrimary), SizedBox(width: 10), Text('Edit Mitra', style: TextStyle(fontWeight: FontWeight.w600))])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppTheme.merah), SizedBox(width: 10), Text('Hapus', style: TextStyle(color: AppTheme.merah, fontWeight: FontWeight.w600))])),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _tampilkanFormPetani(),
          backgroundColor: AppTheme.hijauTua,
          elevation: 8,
          icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
          label: const Text('Tambah Mitra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

class PetaniFormSheet extends StatefulWidget {
  final PetaniHiveModel? petaniLama;
  final Function(String nama, String desa) onSimpan;

  const PetaniFormSheet({super.key, this.petaniLama, required this.onSimpan});

  @override
  State<PetaniFormSheet> createState() => _PetaniFormSheetState();
}

class _PetaniFormSheetState extends State<PetaniFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _desaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.petaniLama != null) {
      _namaCtrl.text = widget.petaniLama!.namaPetani;
      _desaCtrl.text = widget.petaniLama!.desa;
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _desaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.hijauSoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(widget.petaniLama == null ? Icons.person_add_rounded : Icons.manage_accounts_rounded, color: AppTheme.hijauTua, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.petaniLama == null ? 'Tambah Mitra Baru' : 'Edit Data Mitra',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              const Text('Nama Petani', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _namaCtrl,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: _deco('Contoh: Budi Santoso', Icons.person_outline_rounded),
                validator: (v) => (v == null || v.isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              
              const Text('Asal Desa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _desaCtrl,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: _deco('Contoh: Desa Sukamaju', Icons.location_on_outlined),
                validator: (v) => (v == null || v.isEmpty) ? 'Desa wajib diisi' : null,
              ),
              const SizedBox(height: 36),
              
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) widget.onSimpan(_namaCtrl.text, _desaCtrl.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.hijauTua, foregroundColor: Colors.white, elevation: 6, shadowColor: AppTheme.hijauTua.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Simpan Data', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textHint.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: AppTheme.textSecond, size: 20),
      filled: true,
      fillColor: AppTheme.bgPage,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.merah.withOpacity(0.5), width: 1.5)),
    );
  }
}