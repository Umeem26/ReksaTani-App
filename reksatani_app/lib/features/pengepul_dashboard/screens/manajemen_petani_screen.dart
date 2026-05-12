import 'package:flutter/material.dart';
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
  String _searchQuery = '';

  void _tampilkanFormPetani({PetaniHiveModel? petani}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PetaniFormSheet(
        petaniLama: petani,
        onSimpan: (nama, desa) async {
          if (petani == null) {
            // Create
            final id = const Uuid().v4();
            final currentUser = _hiveService.usersBox.get('currentUser');
            final p = PetaniHiveModel(
              id: id,
              pengepulId: currentUser?.id ?? '',
              namaPetani: nama,
              desa: desa,
              sisaHutangKasbon: 0.0,
              waktuDibuat: DateTime.now(),
            );
            await _hiveService.petaniBox.put(id, p);
            
            try {
              final col = MongoDatabase.getCollection('petani');
              await col.insertOne({
                '_id': id,
                'nama_petani': nama,
                'desa': desa,
                'pengepul_id': p.pengepulId,
                'sisa_hutang_kasbon': 0.0,
                'waktu_dibuat': p.waktuDibuat.toIso8601String(),
              });
            } catch (e) {
              print('Gagal push petani baru ke mongo: $e');
            }

          } else {
            // Update
            petani.namaPetani = nama;
            petani.desa = desa;
            await petani.save();

            try {
              final col = MongoDatabase.getCollection('petani');
              await col.updateOne(
                where.eq('_id', petani.id),
                modify.set('nama_petani', nama).set('desa', desa),
              );
            } catch (e) {
               print('Gagal update petani di mongo: $e');
            }
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _hapusPetani(PetaniHiveModel petani) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Petani', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus ${petani.namaPetani}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecond)),
          ),
          ElevatedButton(
            onPressed: () async {
              final idHapus = petani.id;
              await petani.delete();
              
              try {
                final col = MongoDatabase.getCollection('petani');
                await col.deleteOne(where.eq('_id', idHapus));
              } catch (e) {
                print('Gagal hapus petani di mongo: $e');
              }

              Navigator.pop(context);
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
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text('Daftar Mitra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.hijauMuda,
        onPressed: () => _tampilkanFormPetani(),
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.bgCard,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari nama mitra atau desa...',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.bgPage,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _hiveService.petaniBox.listenable(),
              builder: (context, Box<PetaniHiveModel> box, _) {
                final currentUser = _hiveService.usersBox.get('currentUser');
                final currentUserId = currentUser?.id ?? '';
                
                final list = box.values.where((p) {
                  final isMyMitra = p.pengepulId == currentUserId;
                  final matchSearch = p.namaPetani.toLowerCase().contains(_searchQuery) ||
                         p.desa.toLowerCase().contains(_searchQuery);
                  return isMyMitra && matchSearch;
                }).toList();

                if (list.isEmpty) {
                  return const Center(
                    child: Text('Belum ada data mitra.', style: TextStyle(color: AppTheme.textSecond)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return Container(
                      decoration: AppTheme.cardDecoration(radius: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.hijauSoft,
                          child: Text(
                            p.namaPetani.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(p.namaPetani, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(p.desa, style: const TextStyle(fontSize: 12, color: AppTheme.textSecond)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') _tampilkanFormPetani(petani: p);
                            if (val == 'delete') _hapusPetani(p);
                          },
                          icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecond),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline, size: 18, color: AppTheme.merah),
                                SizedBox(width: 8),
                                Text('Hapus', style: TextStyle(color: AppTheme.merah)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
  final _namaCtrl = TextEditingController();
  final _desaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.petaniLama != null) {
      _namaCtrl.text = widget.petaniLama!.namaPetani;
      _desaCtrl.text = widget.petaniLama!.desa;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kbrd = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + kbrd),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.petaniLama == null ? 'Tambah Mitra Baru' : 'Edit Mitra',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Nama Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _namaCtrl,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              decoration: _deco('Masukkan nama mitra'),
            ),
            const SizedBox(height: 12),
            const Text('Desa / Asal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _desaCtrl,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              decoration: _deco('Masukkan asal desa'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSimpan(_namaCtrl.text, _desaCtrl.text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hijauMuda,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Simpan Data', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
      filled: true,
      fillColor: AppTheme.bgPage,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 1.5)),
    );
  }
}
