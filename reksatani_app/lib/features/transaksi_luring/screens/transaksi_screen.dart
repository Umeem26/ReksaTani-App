import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../models/hive/transaksi_hive_model.dart';
import '../../../models/hive/petani_hive_model.dart';
import '../../../models/hive/komoditas_hive_model.dart';
import '../controllers/transaksi_controller.dart';
import '../../../shared/widgets/app_theme.dart';
import '../../pcd_scanner/screens/pcd_camera_screen.dart'; 

class TransaksiScreen extends StatefulWidget {
  final TransaksiHiveModel? editTrx;
  final String? fotoNotaPath;
  final String? fotoBarangPath;
  final String? gradeTebakanPcd;
  final String? initialBeratOcr; 
  final String? initialHargaOcr; 
  final bool isMurniKasbon; 

  const TransaksiScreen({
    super.key,
    this.editTrx,
    this.fotoNotaPath,
    this.fotoBarangPath,
    this.gradeTebakanPcd,
    this.initialBeratOcr, 
    this.initialHargaOcr, 
    this.isMurniKasbon = false, 
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
  final _nominalKasbonCtrl = TextEditingController(); 

  PetaniHiveModel? _petaniTerpilih;
  KomoditasHiveModel? _komoditasTerpilih;
  String? _gradeTerpilih;
  String? _fotoNotaPath;
  String? _fotoBarangPath;
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
      if (widget.gradeTebakanPcd != null) {
        _gradeTerpilih = widget.gradeTebakanPcd;
      }
    }

    if (widget.initialBeratOcr != null && widget.initialBeratOcr!.isNotEmpty) {
      _beratCtrl.text = widget.initialBeratOcr!;
    }
    if (widget.initialHargaOcr != null && widget.initialHargaOcr!.isNotEmpty) {
      _hargaCtrl.text = widget.initialHargaOcr!;
    }
      
    _fotoNotaPath = widget.fotoNotaPath;
    _fotoBarangPath = widget.fotoBarangPath;
    
    if (_isEditMode) {
      _fotoNotaPath = trx?.fotoNota;
      _fotoBarangPath = trx?.fotoFisikBarang;
    }
  }

  @override
  void dispose() {
    _namaPenjualCtrl.dispose();
    _desaCtrl.dispose();
    _beratCtrl.dispose();
    _hargaCtrl.dispose();
    _nominalKasbonCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isMurniKasbon) {
      if (_petaniTerpilih == null) {
        _showSnack('Wajib memilih mitra petani terdaftar untuk pencairan kasbon!', isError: true);
        return;
      }
      final double dipinjam = double.tryParse(_nominalKasbonCtrl.text) ?? 0.0;
      if (_controller.sisaUangJalan < dipinjam) {
        _showSnack('Gagal! Saldo Uang Jalan Anda tidak cukup. Sisa: Rp ${_fmt(_controller.sisaUangJalan.toInt())}', isError: true);
        return;
      }

      setState(() => _saving = true);
      await _controller.simpanKasbonMurni(
        petaniTerpilih: _petaniTerpilih!,
        nominalKasbonText: _nominalKasbonCtrl.text,
      );
      setState(() => _saving = false);
      _showSuksesSheet();
      return;
    }

    if (_hargaMelebihi) {
      _showSnack('Harga melebihi batas maksimal grade $_gradeTerpilih (Rp ${_fmt(_hargaMaksGrade.toInt())})!', isError: true);
      return;
    }

    final sisaKasbon = _petaniTerpilih?.sisaHutangKasbon ?? 0;
    final potongan = sisaKasbon > 0 ? sisaKasbon.clamp(0, _totalBayar).toDouble() : 0.0;
    final uangTunaiKeluar = _totalBayar - potongan;

    if (_controller.sisaUangJalan < uangTunaiKeluar) {
      _showSnack('Saldo Uang Jalan tidak mencukupi! Sisa: Rp ${_fmt(_controller.sisaUangJalan.toInt())}', isError: true);
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
        fotoNotaPath: _fotoNotaPath ?? '',
        fotoBarangPath: _fotoBarangPath ?? '',
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
        fotoNotaPath: _fotoNotaPath ?? '',
        fotoBarangPath: _fotoBarangPath ?? '',
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _showSuksesSheet();
  }

  void _showSuksesSheet() {
    final double tampilNominal = widget.isMurniKasbon 
        ? (double.tryParse(_nominalKasbonCtrl.text) ?? 0) 
        : _totalBayar;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SuksesSheet(
        totalBayar: tampilNominal,
        namaPetani: _petaniTerpilih?.namaPetani ?? _namaPenjualCtrl.text,
        isKasbonTitle: widget.isMurniKasbon,
        onSelesai: () {
          Navigator.pop(context); 
          Navigator.pop(context, true); 
        },
      ),
    );
  }

  void _panggilKameraPcdUlang() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => PcdCameraScreen(
          initialFotoNota: _fotoNotaPath,
          initialFotoBarang: _fotoBarangPath,
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? AppTheme.merah : AppTheme.hijauTua,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
          centerTitle: false,
          title: Text(
            widget.isMurniKasbon 
                ? 'Pencairan Kasbon Baru' 
                : (_isEditMode ? 'Edit Transaksi' : 'Input Transaksi'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.border.withOpacity(0.5)),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (!_isEditMode && !widget.isMurniKasbon) _BannerPcd(gradeTebakan: widget.gradeTebakanPcd),
              if (!_isEditMode && !widget.isMurniKasbon) const SizedBox(height: 20),
              
              // ── BENTO SECTION: PETANI ──
              _FormSection(
                title: 'Informasi Mitra / Penjual',
                icon: Icons.person_pin_rounded,
                children: [
                  _FieldLabel(widget.isMurniKasbon ? 'Pilih Mitra Petani (Wajib)' : 'Pilih Petani (Opsional)'),
                  DropdownButtonFormField<PetaniHiveModel>(
                    value: _petaniTerpilih,
                    decoration: _dropDeco(),
                    hint: const Text('Pilih dari daftar mitra'),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint),
                    validator: (v) => widget.isMurniKasbon && v == null ? 'Mitra wajib dipilih' : null,
                    items: _daftarPetani
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.namaPetani, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary))))
                        .toList(),
                    onChanged: (p) => setState(() {
                      _petaniTerpilih = p;
                      if (p != null) {
                        _namaPenjualCtrl.text = p.namaPetani;
                        _desaCtrl.text = p.desa;
                      }
                    }),
                  ),
                  if (!widget.isMurniKasbon) ...[
                    const SizedBox(height: 16),
                    _ReksaField(
                      ctrl: _namaPenjualCtrl,
                      label: 'Nama Lengkap Penjual',
                      hint: 'Masukkan nama penjual',
                      validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    _ReksaField(
                      ctrl: _desaCtrl,
                      label: 'Asal Desa / Wilayah',
                      hint: 'Masukkan asal desa',
                      validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                    ),
                  ],
                  if (_petaniTerpilih != null)
                    _KasbonInfo(sisa: _petaniTerpilih!.sisaHutangKasbon, isNewLoanMode: widget.isMurniKasbon),
                ],
              ),
              const SizedBox(height: 24),
              
              if (widget.isMurniKasbon) ...[
                // ── BENTO SECTION: KASBON ──
                _FormSection(
                  title: 'Rincian Pencairan',
                  icon: Icons.payments_rounded,
                  iconColor: const Color(0xFFD97706),
                  children: [
                    _ReksaField(
                      ctrl: _nominalKasbonCtrl,
                      label: 'Nominal Pinjaman Kasbon (Rp)',
                      hint: 'Contoh: 500000',
                      type: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v?.isEmpty ?? true || (double.tryParse(v!) ?? 0) <= 0) ? 'Masukkan nominal valid' : null,
                    ),
                  ],
                ),
              ] else ...[
                // ── BENTO SECTION: KOMODITAS ──
                _FormSection(
                  title: 'Rincian Komoditas',
                  icon: Icons.eco_rounded,
                  children: [
                    _FieldLabel('Jenis Komoditas'),
                    DropdownButtonFormField<KomoditasHiveModel>(
                      value: _komoditasTerpilih,
                      decoration: _dropDeco(),
                      hint: const Text('Pilih komoditas panen'),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint),
                      items: _daftarKomoditas
                          .map((k) => DropdownMenuItem(value: k, child: Text(k.namaKomoditas, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary))))
                          .toList(),
                      validator: (_) => _komoditasTerpilih == null ? 'Pilih komoditas' : null,
                      onChanged: (k) => setState(() {
                        _komoditasTerpilih = k;
                        _gradeTerpilih = widget.gradeTebakanPcd;
                        _hargaCtrl.clear();
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ReksaField(
                            ctrl: _beratCtrl,
                            label: 'Kuantitas (kg)',
                            hint: '0',
                            type: TextInputType.number,
                            formatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() {}),
                            validator: (v) => (v?.isEmpty ?? true) ? 'Wajib' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ReksaField(
                            ctrl: _hargaCtrl,
                            label: 'Harga / kg (Rp)',
                            hint: '0',
                            type: TextInputType.number,
                            formatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (val) {
                              final maks = _hargaMaksGrade;
                              final h = double.tryParse(val) ?? 0;
                              if (maks > 0 && h > maks) {
                                _hargaCtrl.text = maks.toInt().toString();
                                _hargaCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _hargaCtrl.text.length));
                                _showSnack('Harga otomatis diturunkan ke batas maksimal Grade $_gradeTerpilih (Rp ${_fmt(maks.toInt())})', isError: true);
                              }
                              setState(() {});
                            },
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_rounded, color: AppTheme.merah, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Harga melebihi batas maksimal pasaran untuk Grade $_gradeTerpilih: Rp ${_fmt(_hargaMaksGrade.toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.merah, height: 1.3))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    _FieldLabel('Kualitas (Grade)'),
                    DropdownButtonFormField<String>(
                      value: _gradeTerpilih,
                      decoration: _dropDeco(),
                      hint: const Text('Pilih kualitas'),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint),
                      items: _daftarGrade
                          .map((g) => DropdownMenuItem<String>(
                                value: g['grade'] as String,
                                child: Row(
                                  children: [
                                    Text('Grade ${g['grade']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                    const SizedBox(width: 8),
                                    Text('(Maks Rp ${_fmt(((g['harga_maks'] as num?)?.toInt() ?? 0))})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecond)),
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
                const SizedBox(height: 24),
                
                // ── BENTO SECTION: DOKUMENTASI ──
                _FormSection(
                  title: 'Dokumentasi Luring',
                  icon: Icons.camera_alt_rounded,
                  children: [
                    _FieldLabel('Foto Nota / Kwitansi (PCD)'),
                    const SizedBox(height: 6),
                    if (_fotoNotaPath != null && _fotoNotaPath!.isNotEmpty)
                      _PhotoPreview(
                        path: _fotoNotaPath!, 
                        onClear: () => setState(() => _fotoNotaPath = null)
                      )
                    else
                      _AddPhotoButton(label: 'Pindai Ulang Nota via Kamera PCD', onTap: _panggilKameraPcdUlang),
                      
                    const SizedBox(height: 20),
                    
                    _FieldLabel('Foto Fisik Komoditas Barang'),
                    const SizedBox(height: 6),
                    if (_fotoBarangPath != null && _fotoBarangPath!.isNotEmpty)
                      _PhotoPreview(
                        path: _fotoBarangPath!, 
                        onClear: () => setState(() => _fotoBarangPath = null)
                      )
                    else
                      _AddPhotoButton(label: 'Ambil Ulang Foto Komoditas via PCD', onTap: _panggilKameraPcdUlang),
                  ],
                ),
              ],
              
              const SizedBox(height: 32),
              
              // ── KALKULASI & TOMBOL SIMPAN (FIXED BOTTOM) ──
              Builder(
                builder: (context) {
                  final double hitungTotal = widget.isMurniKasbon 
                      ? (double.tryParse(_nominalKasbonCtrl.text) ?? 0.0)
                      : _totalBayar;
                  
                  return Column(
                    children: [
                      if (hitungTotal > 0)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: widget.isMurniKasbon ? const Color(0xFFFEF3C7) : AppTheme.hijauSoft, 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: (widget.isMurniKasbon ? AppTheme.kuning : AppTheme.hijauMuda).withOpacity(0.5), width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(widget.isMurniKasbon ? Icons.payments_rounded : Icons.calculate_rounded, color: widget.isMurniKasbon ? const Color(0xFFB45309) : AppTheme.hijauTua, size: 18),
                                      const SizedBox(width: 6),
                                      Text(widget.isMurniKasbon ? 'Pencairan Kasbon' : 'Estimasi Total Bayar', style: TextStyle(color: widget.isMurniKasbon ? const Color(0xFF92400E) : AppTheme.hijauTua, fontWeight: FontWeight.w800, fontSize: 13)),
                                    ],
                                  ),
                                  if (!widget.isMurniKasbon && (_petaniTerpilih?.sisaHutangKasbon ?? 0) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('Sisa kasbon akan memotong total ini', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecond.withOpacity(0.8))),
                                    ),
                                ],
                              ),
                              Text('Rp ${_fmt(hitungTotal.toInt())}', style: TextStyle(color: widget.isMurniKasbon ? const Color(0xFFB45309) : AppTheme.hijauTua, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: hitungTotal > 0 ? 16 : 0),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _simpan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isMurniKasbon ? const Color(0xFFF59E0B) : AppTheme.hijauTua, 
                            foregroundColor: Colors.white, 
                            elevation: 8, 
                            shadowColor: (widget.isMurniKasbon ? const Color(0xFFF59E0B) : AppTheme.hijauTua).withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          child: _saving
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(widget.isMurniKasbon ? Icons.send_rounded : Icons.save_rounded, size: 20),
                                    const SizedBox(width: 10),
                                    Text(widget.isMurniKasbon ? 'Cairkan Pinjaman' : 'Simpan Transaksi', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                }
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dropDeco() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.hijauMuda, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.merah, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.merah, width: 2)),
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

// ─── KOMPONEN UI TAMBAHAN BENTO ───

class _BannerPcd extends StatelessWidget {
  final String? gradeTebakan;
  const _BannerPcd({this.gradeTebakan});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pemindaian AI Berhasil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text('Sistem mendeteksi kualitas: Grade ${gradeTebakan ?? "-"}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
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
  final Color? iconColor;
  final List<Widget> children;
  const _FormSection({required this.title, required this.icon, this.iconColor, required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppTheme.hijauMuda),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: iconColor ?? AppTheme.textPrimary, letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 20),
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
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecond)),
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

  const _ReksaField({required this.ctrl, required this.label, required this.hint, this.type = TextInputType.text, this.formatters, this.validator, this.onChanged, this.isError = false});

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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textHint.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isError ? AppTheme.merah : AppTheme.border, width: isError ? 1.5 : 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isError ? AppTheme.merah : AppTheme.hijauMuda, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.merah, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.merah, width: 2)),
          ),
        ),
      ],
    );
  }
}

class _KasbonInfo extends StatelessWidget {
  final double sisa;
  final bool isNewLoanMode; 
  const _KasbonInfo({required this.sisa, this.isNewLoanMode = false});

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
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isNewLoanMode ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7).withOpacity(0.6), 
          borderRadius: BorderRadius.circular(14), 
          border: Border.all(color: (isNewLoanMode ? Colors.blue : AppTheme.kuning).withOpacity(0.4), width: 1.5)
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isNewLoanMode ? Icons.account_balance_wallet_rounded : Icons.info_rounded, color: isNewLoanMode ? Colors.blue : const Color(0xFFD97706), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isNewLoanMode 
                    ? 'Hutang Kasbon saat ini: Rp ${_fmt(sisa.toInt())}. Pencairan baru akan ditambahkan ke akumulasi hutang.'
                    : 'Petani ini memiliki sisa kasbon Rp ${_fmt(sisa.toInt())} yang akan dipotong otomatis dari total hasil panen.', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isNewLoanMode ? const Color(0xFF1E40AF) : const Color(0xFF92400E), height: 1.4)
              )
            ),
          ],
        ),
      ),
    );
  }
}

// Komponen Pembantu Foto
class _PhotoPreview extends StatelessWidget {
  final String path;
  final VoidCallback onClear;
  const _PhotoPreview({required this.path, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 180, width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 2),
            image: DecorationImage(
              image: path.startsWith('http') ? NetworkImage(path) as ImageProvider : FileImage(File(path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 12, top: 12,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.merah, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddPhotoButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.bgPage,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.5, style: BorderStyle.solid), // Solid lebih rapi dari dashed
        ),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.textSecond, size: 24)),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textSecond)),
          ],
        ),
      ),
    );
  }
}

class _SuksesSheet extends StatelessWidget {
  final double totalBayar;
  final String namaPetani;
  final bool isKasbonTitle;
  final VoidCallback onSelesai;
  
  const _SuksesSheet({required this.totalBayar, required this.namaPetani, this.isKasbonTitle = false, required this.onSelesai});

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
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isKasbonTitle ? const Color(0xFFFEF3C7) : AppTheme.hijauSoft),
            child: Icon(isKasbonTitle ? Icons.payments_rounded : Icons.check_circle_rounded, color: isKasbonTitle ? const Color(0xFFD97706) : AppTheme.hijauMuda, size: 48),
          ),
          const SizedBox(height: 20),
          Text(isKasbonTitle ? 'Kasbon Berhasil Dicairkan!' : 'Transaksi Berhasil Disimpan!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Data tersimpan di perangkat lokal dan\nmasuk antrean sinkronisasi server.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mitra / Petani', style: TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                    Text(namaPetani, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppTheme.border)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isKasbonTitle ? 'Nominal Kasbon' : 'Total Bayar', style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600)),
                    Text('Rp ${_fmt(totalBayar.toInt())}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isKasbonTitle ? const Color(0xFFB45309) : AppTheme.hijauTua, letterSpacing: -0.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: onSelesai,
              style: ElevatedButton.styleFrom(backgroundColor: isKasbonTitle ? const Color(0xFFF59E0B) : AppTheme.hijauTua, foregroundColor: Colors.white, elevation: 6, shadowColor: (isKasbonTitle ? const Color(0xFFF59E0B) : AppTheme.hijauTua).withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}