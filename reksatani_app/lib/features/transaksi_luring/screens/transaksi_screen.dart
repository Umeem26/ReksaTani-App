import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/hive/transaksi_hive_model.dart';
import '../../../models/hive/petani_hive_model.dart';
import '../../../models/hive/komoditas_hive_model.dart';
import '../controllers/transaksi_controller.dart';
import '../../../shared/widgets/app_theme.dart';

class TransaksiScreen extends StatefulWidget {
  final TransaksiHiveModel? editTrx;
  final String? fotoNotaPath;
  final String? fotoBarangPath;
  final String? gradeTebakanPcd;

  const TransaksiScreen({
    super.key,
    this.editTrx,
    this.fotoNotaPath,
    this.fotoBarangPath,
    this.gradeTebakanPcd,
  });

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TransaksiController();

  final _namaPenjualCtrl = TextEditingController();
  final _desaCtrl = TextEditingController();
  final _beratCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();

  PetaniHiveModel? _petaniTerpilih;
  KomoditasHiveModel? _komoditasTerpilih;
  String? _gradeTerpilih;
  bool _saving = false;

  List<PetaniHiveModel> get _daftarPetani => _controller.daftarPetani;
  List<KomoditasHiveModel> get _daftarKomoditas => _controller.daftarKomoditas;
  List<Map<String, dynamic>> get _daftarGrade => _controller.getDaftarGrade(_komoditasTerpilih);
  double get _hargaMaksGrade => _controller.getHargaMaksGrade(_komoditasTerpilih, _gradeTerpilih);
  double get _totalBayar => _controller.getTotalBayar(_beratCtrl.text, _hargaCtrl.text);
  bool get _hargaMelebihi => _controller.isHargaMelebihi(_komoditasTerpilih, _gradeTerpilih, _hargaCtrl.text);
  bool get _isEditMode => widget.editTrx != null;

  @override
  void initState() {
    super.initState();
    final trx = widget.editTrx;
    if (trx != null) {
      // --- MODE EDIT ---
      _namaPenjualCtrl.text = trx.namaPetani;
      _beratCtrl.text = trx.berat.toInt().toString();
      _hargaCtrl.text = trx.hargaBeliSatuan.toInt().toString();
      try {
        _petaniTerpilih = _controller.daftarPetani.firstWhere((p) => p.id == trx.petaniId);
        _desaCtrl.text = _petaniTerpilih?.desa ?? '';
      } catch (_) {}
      try {
        _komoditasTerpilih = _controller.daftarKomoditas.firstWhere((k) => k.namaKomoditas == trx.namaKomoditas);
      } catch (_) {}
      _gradeTerpilih = trx.gradeTerpilih;
    } else {
      // --- MODE BARU (DARI KAMERA PCD) ---
      if (widget.gradeTebakanPcd != null) {
        _gradeTerpilih = widget.gradeTebakanPcd;
      }
    }
  }

  @override
  void dispose() {
    _namaPenjualCtrl.dispose();
    _desaCtrl.dispose();
    _beratCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hargaMelebihi) {
      _showSnack(
        'Harga melebihi batas maksimal grade $_gradeTerpilih (Rp ${_fmt(_hargaMaksGrade.toInt())})!',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    if (_isEditMode) {
      await _controller.updateTransaksi(
        widget.editTrx!,
        petaniTerpilih: _petaniTerpilih,
        namaPenjual: _namaPenjualCtrl.text,
        komoditasTerpilih: _komoditasTerpilih,
        gradeTerpilih: _gradeTerpilih,
        beratText: _beratCtrl.text,
        hargaText: _hargaCtrl.text,
        totalBayar: _totalBayar,
        fotoNotaPath: widget.fotoNotaPath ?? '',
        fotoBarangPath: widget.fotoBarangPath ?? '',
      );
    } else {
      await _controller.simpanTransaksi(
        petaniTerpilih: _petaniTerpilih,
        namaPenjual: _namaPenjualCtrl.text,
        komoditasTerpilih: _komoditasTerpilih,
        gradeTerpilih: _gradeTerpilih,
        beratText: _beratCtrl.text,
        hargaText: _hargaCtrl.text,
        totalBayar: _totalBayar,
        fotoNotaPath: widget.fotoNotaPath ?? '',
        fotoBarangPath: widget.fotoBarangPath ?? '',
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    _showSuksesSheet();
  }

  void _showSuksesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SuksesSheet(
        totalBayar: _totalBayar,
        namaPetani: _namaPenjualCtrl.text,
        onSelesai: () {
          Navigator.pop(context); // Tutup bottom sheet
          Navigator.pop(context, true); // Tutup form dan kembali ke tab
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.merah : AppTheme.hijauTua,
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
        title: Text(
          _isEditMode ? 'Edit Transaksi' : 'Input Transaksi',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEditMode) _BannerPcd(gradeTebakan: widget.gradeTebakanPcd),
            if (!_isEditMode) const SizedBox(height: 16),
            
            _FormSection(
              title: 'Data Penjual',
              icon: Icons.person_outline_rounded,
              children: [
                if (_daftarPetani.isNotEmpty) ...[
                  _FieldLabel('Pilih Petani (opsional)'),
                  DropdownButtonFormField<PetaniHiveModel>(
                    value: _petaniTerpilih,
                    decoration: _dropDeco(),
                    hint: const Text('Pilih dari daftar petani'),
                    items: _daftarPetani
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.namaPetani)))
                        .toList(),
                    onChanged: (p) => setState(() {
                      _petaniTerpilih = p;
                      if (p != null) {
                        _namaPenjualCtrl.text = p.namaPetani;
                        _desaCtrl.text = p.desa;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                _ReksaField(
                  ctrl: _namaPenjualCtrl,
                  label: 'Nama Penjual',
                  hint: 'Masukkan nama penjual',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                _ReksaField(
                  ctrl: _desaCtrl,
                  label: 'Desa / Asal',
                  hint: 'Masukkan asal desa',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                ),
                if (_petaniTerpilih != null && _petaniTerpilih!.sisaHutangKasbon > 0)
                  _KasbonInfo(sisa: _petaniTerpilih!.sisaHutangKasbon),
              ],
            ),
            const SizedBox(height: 14),
            
            _FormSection(
              title: 'Data Komoditas',
              icon: Icons.grass_rounded,
              children: [
                _FieldLabel('Jenis Komoditas'),
                DropdownButtonFormField<KomoditasHiveModel>(
                  value: _komoditasTerpilih,
                  decoration: _dropDeco(),
                  hint: const Text('Pilih komoditas'),
                  items: _daftarKomoditas
                      .map((k) => DropdownMenuItem(value: k, child: Text(k.namaKomoditas)))
                      .toList(),
                  validator: (_) => _komoditasTerpilih == null ? 'Pilih komoditas' : null,
                  onChanged: (k) => setState(() {
                    _komoditasTerpilih = k;
                    _gradeTerpilih = widget.gradeTebakanPcd;
                    _hargaCtrl.clear();
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ReksaField(
                        ctrl: _beratCtrl,
                        label: 'Jumlah Berat (kg)',
                        hint: '0',
                        type: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v?.isEmpty ?? true) ? 'Wajib' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReksaField(
                        ctrl: _hargaCtrl,
                        label: 'Harga / kg (Rp)',
                        hint: '0',
                        type: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v?.isEmpty ?? true) ? 'Wajib' : null,
                        isError: _hargaMelebihi,
                      ),
                    ),
                  ],
                ),
                if (_hargaMelebihi)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.merah, size: 14),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Harga melebihi batas maks grade $_gradeTerpilih: Rp ${_fmt(_hargaMaksGrade.toInt())}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.merah),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _FieldLabel('Kualitas'),
                DropdownButtonFormField<String>(
                  value: _gradeTerpilih,
                  decoration: _dropDeco(),
                  hint: const Text('Pilih kualitas'),
                  items: _daftarGrade
                      .map((g) => DropdownMenuItem<String>(
                            value: g['grade'] as String,
                            child: Row(
                              children: [
                                Text(g['grade'] as String),
                                const SizedBox(width: 8),
                                Text(
                                  '(Maks Rp ${_fmt(((g['harga_maks'] as num?)?.toInt() ?? 0))})',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecond),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  validator: (_) => _gradeTerpilih == null ? 'Pilih kualitas' : null,
                  onChanged: (g) => setState(() {
                    _gradeTerpilih = g;
                    final hMaks = (_daftarGrade.firstWhere((x) => x['grade'] == g, orElse: () => {})['harga_maks'] as num?)?.toInt() ?? 0;
                    if (hMaks > 0) _hargaCtrl.text = '$hMaks';
                    setState(() {});
                  }),
                ),
              ],
            ),
            const SizedBox(height: 14),
            
            if (_totalBayar > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.hijauSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.hijauMuda.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: AppTheme.hijauTua, size: 20),
                    const SizedBox(width: 10),
                    const Text('Total Bayar', style: TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      'Rp ${_fmt(_totalBayar.toInt())}',
                      style: const TextStyle(color: AppTheme.hijauTua, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
              ),
            if (_totalBayar > 0) const SizedBox(height: 14),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hijauMuda,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Simpan Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropDeco() {
    return InputDecoration(
      filled: true,
      fillColor: AppTheme.bgPage,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.merah, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.merah, width: 1.5),
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

// ═══════════════════════════════════════════════════════════════
// KOMPONEN REUSABLE (Sudah Dirapikan)
// ═══════════════════════════════════════════════════════════════

class _BannerPcd extends StatelessWidget {
  final String? gradeTebakan;
  
  const _BannerPcd({this.gradeTebakan});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF019241), Color(0xFF00AE3F)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hasil Pemindaian PCD',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  'Sistem mendeteksi kualitas: Grade ${gradeTebakan ?? "-"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.hijauMuda),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecond),
      ),
    );
  }
}

class _ReksaField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType type;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool isError;

  const _ReksaField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.type = TextInputType.text,
    this.formatters,
    this.validator,
    this.onChanged,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          inputFormatters: formatters,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
            filled: true,
            fillColor: AppTheme.bgPage,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isError ? AppTheme.merah : AppTheme.border,
                width: isError ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isError ? AppTheme.merah : AppTheme.hijauMuda,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.merah, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.merah, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _KasbonInfo extends StatelessWidget {
  final double sisa;
  
  const _KasbonInfo({required this.sisa});

  String _fmt(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.kuning.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppTheme.kuning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Petani ini memiliki sisa kasbon Rp ${_fmt(sisa.toInt())} yang akan dipotong.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuksesSheet extends StatelessWidget {
  final double totalBayar;
  final String namaPetani;
  final VoidCallback onSelesai;

  const _SuksesSheet({
    required this.totalBayar,
    required this.namaPetani,
    required this.onSelesai,
  });

  String _fmt(int angka) {
    final s = angka.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.hijauSoft),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.hijauMuda, size: 42),
          ),
          const SizedBox(height: 16),
          const Text(
            'Transaksi Berhasil Disimpan!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tersimpan di perangkat · Pending Sync ke server',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecond),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgPage,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Petani', style: TextStyle(fontSize: 13, color: AppTheme.textSecond)),
                    Text(
                      namaPetani,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bayar', style: TextStyle(fontSize: 13, color: AppTheme.textSecond)),
                    Text(
                      'Rp ${_fmt(totalBayar.toInt())}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.hijauTua),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSelesai,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.hijauMuda,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}