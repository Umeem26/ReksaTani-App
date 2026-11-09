import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../models/hive/transaksi_hive_model.dart';
import '../../../models/hive/petani_hive_model.dart';
import '../../../models/hive/komoditas_hive_model.dart';
import '../controllers/transaksi_controller.dart';
import '../../../services/saldo/kasbon_rules.dart';
import '../../../services/saldo/transaksi_ditolak.dart';
import '../../../shared/widgets/app_theme.dart';
import '../../pcd_scanner/screens/pcd_camera_screen.dart';
import '../../pcd_scanner/services/commodity_mapper.dart';
import '../../pcd_scanner/services/grading_rubric.dart';
import '../../pcd_scanner/widgets/checklist_rubrik.dart';

class TransaksiScreen extends StatefulWidget {
  /// Tes menyuntik controller agar tidak melakukan I/O sungguhan.
  final TransaksiController? controller;
  final TransaksiHiveModel? editTrx;
  final String? fotoNotaPath;
  final String? fotoBarangPath;
  final String? initialBeratOcr; 
  final String? initialHargaOcr; 
  final String? initialNamaPenjualOcr; 
  final String? initialDesaOcr; 
  final String? initialKomoditasOcr; 
  /// Label router yang disarankan AI ('gabah', 'kelapa_sawit', 'kopi'); null = tanpa saran.
  final String? saranKomoditasAi;
  final double? keyakinanSaranAi;
  final bool isMurniKasbon; 

  const TransaksiScreen({
    super.key,
    this.controller,
    this.editTrx,
    this.fotoNotaPath,
    this.fotoBarangPath,
    this.initialBeratOcr, 
    this.initialHargaOcr, 
    this.initialNamaPenjualOcr,
    this.initialDesaOcr,
    this.initialKomoditasOcr,
    this.saranKomoditasAi,
    this.keyakinanSaranAi,
    this.isMurniKasbon = false, 
  });

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TransaksiController _controller =
      widget.controller ?? TransaksiController();

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
  /// Potongan kasbon transaksi yang sedang disimpan, hanya untuk lembar sukses.
  /// Dihitung dengan rumus yang sama dengan controller, sebelum kasbon petani berubah.
  double _potonganTampil = 0;
  /// Komoditas master data yang cocok dengan label AI (bukan fallback OCR).
  KomoditasHiveModel? _komoditasDariAi;

  /// Jawaban checklist rubrik: kode pertanyaan -> kode opsi.
  Map<String, String> _jawabanRubrik = {};

  /// False selama checklist transaksi yang diedit belum disentuh, supaya
  /// jawaban dan grade lamanya tidak ditimpa.
  bool _jawabanDisentuh = false;

  /// Hanya angka dengan satu pemisah desimal (titik atau koma).
  static final _desimalFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) => RegExp(r'^\d*[.,]?\d*$').hasMatch(newValue.text) ? newValue : oldValue,
  );

  List<PetaniHiveModel> get _daftarPetani => _controller.daftarPetani;
  List<KomoditasHiveModel> get _daftarKomoditas => _controller.daftarKomoditas;
  List<Map<String, dynamic>> get _daftarGrade => _controller.getDaftarGrade(_komoditasTerpilih);
  double get _hargaMaksGrade => _controller.getHargaMaksGrade(_komoditasTerpilih, _gradeTerpilih);
  double get _totalBayar => _controller.getTotalBayar(_beratCtrl.text, _hargaCtrl.text);
  bool get _hargaMelebihi => _controller.isHargaMelebihi(_komoditasTerpilih, _gradeTerpilih, _hargaCtrl.text);
  bool get _isEditMode => widget.editTrx != null;
  bool get _adaSaranAi => widget.saranKomoditasAi?.isNotEmpty ?? false;
  RubrikKomoditas? get _rubrik => rubrikUntukKomoditas(_komoditasTerpilih?.namaKomoditas);

  /// Grade dari checklist; null selama checklist belum lengkap.
  String? get _gradeChecklist {
    final r = _rubrik;
    return r == null ? null : gradeDariJawaban(r, _jawabanRubrik);
  }

  /// Jawaban untuk disimpan, hanya bila checklist lengkap dan disentuh.
  List<String>? get _jawabanUntukDisimpan {
    final r = _rubrik;
    if (!_jawabanDisentuh || r == null || _gradeChecklist == null) return null;
    return kodekanJawaban(r, _jawabanRubrik);
  }

  void _pilihJawaban(String pertanyaan, String opsi) {
    setState(() {
      _jawabanRubrik = {..._jawabanRubrik, pertanyaan: opsi};
      _jawabanDisentuh = true;
      _gradeTerpilih = _gradeChecklist;
      // Hanya mengisi kolom yang masih kosong, tidak menimpa isian pengguna atau OCR.
      final maks = _hargaMaksGrade.toInt();
      if (_gradeTerpilih != null && maks > 0 && _hargaCtrl.text.isEmpty) _hargaCtrl.text = '$maks';
    });
  }

  void _gantiKomoditas(KomoditasHiveModel? k) {
    setState(() {
      _komoditasTerpilih = k;
      _jawabanRubrik = {};
      _jawabanDisentuh = true;
      _gradeTerpilih = null;
      // Harga dari pengguna atau OCR dipertahankan. Bila melebihi batas grade
      // nanti, form memperingatkan dan simpan ditolak; harga tidak diganti diam-diam.
    });
  }

  @override
  void initState() {
    super.initState();
    final trx = widget.editTrx;
    if (trx != null) {
      _namaPenjualCtrl.text = trx.namaPetani;
      _beratCtrl.text = trx.berat == trx.berat.roundToDouble() ? trx.berat.toInt().toString() : trx.berat.toString();
      _hargaCtrl.text = trx.hargaBeliSatuan.toInt().toString();
      try {
        _petaniTerpilih = _controller.daftarPetani.firstWhere((p) => p.id == trx.petaniId);
        _desaCtrl.text = _petaniTerpilih?.desa ?? '';
      } catch (_) {}
      try {
        _komoditasTerpilih = _controller.daftarKomoditas.firstWhere((k) => k.namaKomoditas == trx.namaKomoditas);
      } catch (_) {}
      _gradeTerpilih = trx.gradeTerpilih;
      // Jawaban dari versi rubrik lain tidak dimuat: kodenya bisa sudah berbeda.
      if (trx.rubrikVersi == rubrikVersi) _jawabanRubrik = bacaJawaban(trx.rubrikJawaban);
    }

    if (widget.initialBeratOcr != null && widget.initialBeratOcr!.isNotEmpty) {
      _beratCtrl.text = widget.initialBeratOcr!;
    }
    if (widget.initialHargaOcr != null && widget.initialHargaOcr!.isNotEmpty) {
      _hargaCtrl.text = widget.initialHargaOcr!;
    }
    if (widget.initialNamaPenjualOcr != null && widget.initialNamaPenjualOcr!.isNotEmpty) {
      _namaPenjualCtrl.text = widget.initialNamaPenjualOcr!;
      try {
        final ocrTokens = widget.initialNamaPenjualOcr!
            .toLowerCase()
            .split(RegExp(r'[\s\.\,]+'))
            .where((t) => t.length > 1)
            .toSet();
        
        PetaniHiveModel? bestMatch;
        double bestScore = 0.0;

        for (final p in _controller.daftarPetani) {
          final nameTokens = p.namaPetani
              .toLowerCase()
              .split(RegExp(r'[\s\.\,]+'))
              .where((t) => t.length > 1)
              .toSet();
          
          if (nameTokens.isEmpty || ocrTokens.isEmpty) continue;
          
          final intersection = ocrTokens.intersection(nameTokens).length;
          final union = ocrTokens.union(nameTokens).length;
          final score = intersection / union;

          if (score > bestScore) {
            bestScore = score;
            bestMatch = p;
          }
        }

        if (bestMatch != null && bestScore >= 0.3) {
          _petaniTerpilih = bestMatch;
          _namaPenjualCtrl.text = _petaniTerpilih!.namaPetani;
          _desaCtrl.text = _petaniTerpilih!.desa;
        } else {
          // Fallback substring matching
          final matches = _controller.daftarPetani.where((p) =>
              p.namaPetani.toLowerCase().contains(widget.initialNamaPenjualOcr!.toLowerCase()) ||
              widget.initialNamaPenjualOcr!.toLowerCase().contains(p.namaPetani.toLowerCase()));
          if (matches.isNotEmpty) {
            _petaniTerpilih = matches.first;
            _namaPenjualCtrl.text = _petaniTerpilih!.namaPetani;
            _desaCtrl.text = _petaniTerpilih!.desa;
          }
        }
      } catch (_) {}
    }
    if (widget.initialDesaOcr != null && widget.initialDesaOcr!.isNotEmpty) {
      if (_desaCtrl.text.isEmpty) {
        _desaCtrl.text = widget.initialDesaOcr!;
      }
    }
    // Prefill komoditas HANYA bila ada saran AI. Grade tidak pernah datang dari AI.
    // Label ML (gabah/kelapa_sawit/kopi) dipetakan ke master data dengan contains-match;
    // bila tidak ada yang cocok, pakai komoditas OCR.
    if (!_isEditMode && !widget.isMurniKasbon && _adaSaranAi) {
      _komoditasDariAi = CommodityMapper.match<KomoditasHiveModel>(
          _controller.daftarKomoditas, (k) => k.namaKomoditas, widget.saranKomoditasAi);
      if (_komoditasDariAi != null) {
        _komoditasTerpilih = _komoditasDariAi;
      } else {
        _komoditasTerpilih = CommodityMapper.match<KomoditasHiveModel>(
            _controller.daftarKomoditas, (k) => k.namaKomoditas, widget.initialKomoditasOcr);
      }
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
        _showSnack('Silakan pilih mitra petani terlebih dahulu untuk mencairkan kasbon.', isError: true);
        return;
      }
      final double dipinjam = double.tryParse(_nominalKasbonCtrl.text) ?? 0.0;
      if (_controller.sisaUangJalan < dipinjam) {
        _showSnack('Saldo Uang Jalan Anda tidak mencukupi untuk pencairan ini (Sisa saldo: Rp ${_fmt(_controller.sisaUangJalan.toInt())}).', isError: true);
        return;
      }

      await _jalankanSimpan(() => _controller.simpanKasbonMurni(
            petaniTerpilih: _petaniTerpilih!,
            nominalKasbonText: _nominalKasbonCtrl.text,
          ));
      return;
    }

    if (_hargaMelebihi) {
      _showSnack('Harga yang dimasukkan melebihi batas maksimal untuk Grade $_gradeTerpilih (Maksimal Rp ${_fmt(_hargaMaksGrade.toInt())}).', isError: true);
      return;
    }

    final bool kasCukup;
    if (_isEditMode) {
      // Saldo yang sudah negatif tidak boleh menghalangi edit yang tidak menambah pengeluaran.
      final efek = _controller
          .pratinjauEdit(widget.editTrx!, petaniTerpilih: _petaniTerpilih, totalBayar: _totalBayar);
      final kasSetelahEdit = efek.uangJalan;
      kasCukup = kasSetelahEdit >= 0 || kasSetelahEdit >= _controller.sisaUangJalan;
      _potonganTampil = efek.potonganBaru;
    } else {
      final potongan = KasbonRules.potongan(
        sisaKasbon: _petaniTerpilih?.sisaHutangKasbon ?? 0,
        totalBayar: _totalBayar,
      );
      final uangTunaiKeluar = KasbonRules.tunaiKeluar(totalBayar: _totalBayar, potongan: potongan);
      kasCukup = _controller.sisaUangJalan >= uangTunaiKeluar;
      _potonganTampil = potongan;
    }

    if (!kasCukup) {
      _showSnack('Saldo Uang Jalan Anda tidak mencukupi untuk menyelesaikan transaksi ini (Sisa saldo: Rp ${_fmt(_controller.sisaUangJalan.toInt())}).', isError: true);
      return;
    }

    if (_isEditMode) {
      await _jalankanSimpan(() async {
        await _controller.updateTransaksi(
          widget.editTrx!,
          petaniTerpilih: _petaniTerpilih,
          namaPenjual: _namaPenjualCtrl.text,
          komoditasTerpilih: _komoditasTerpilih,
          gradeTerpilih: _gradeTerpilih,
          beratText: _beratCtrl.text,
          hargaText: _hargaCtrl.text,
          fotoNotaPath: _fotoNotaPath ?? '',
          fotoBarangPath: _fotoBarangPath ?? '',
          grading: CatatanGrading(rubrikJawaban: _jawabanUntukDisimpan),
        );
        // Edit tidak mengambil GPS: lokasi asli transaksi dipertahankan.
        return true;
      });
      return;
    }

    final fotoKurang = (_fotoNotaPath ?? '').isEmpty || (_fotoBarangPath ?? '').isEmpty;
    if (fotoKurang && !await _konfirmasiTanpaFoto()) return;
    if (!mounted) return;

    await _jalankanSimpan(() => _controller.simpanTransaksi(
          petaniTerpilih: _petaniTerpilih,
          namaPenjual: _namaPenjualCtrl.text,
          komoditasTerpilih: _komoditasTerpilih,
          gradeTerpilih: _gradeTerpilih,
          beratText: _beratCtrl.text,
          hargaText: _hargaCtrl.text,
          fotoNotaPath: _fotoNotaPath ?? '',
          fotoBarangPath: _fotoBarangPath ?? '',
          izinkanTanpaFoto: fotoKurang,
          grading: CatatanGrading(
            saranKomoditasAi: _adaSaranAi ? widget.saranKomoditasAi : null,
            rubrikJawaban: _jawabanUntukDisimpan,
          ),
        ));
  }

  /// Satu tempat untuk semua penyimpanan, supaya tombol tidak pernah macet di
  /// keadaan menyimpan bila ada yang gagal. [simpan] mengembalikan true bila lokasi
  /// GPS tercatat.
  Future<void> _jalankanSimpan(Future<bool> Function() simpan) async {
    setState(() => _saving = true);
    var berhasil = false;
    var lokasiTercatat = true;
    try {
      lokasiTercatat = await simpan();
      berhasil = true;
    } on TransaksiDitolak catch (e) {
      if (mounted) _showSnack(e.pesan, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Gagal menyimpan transaksi. Silakan coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (berhasil && mounted) _showSuksesSheet(lokasiTercatat: lokasiTercatat);
  }

  /// True bila agen memilih menyimpan tanpa foto. Menutup dialog berarti tidak.
  Future<bool> _konfirmasiTanpaFoto() async {
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Foto Belum Lengkap', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Foto nota atau barang belum ada. Simpan tanpa foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan tanpa foto', style: TextStyle(color: AppTheme.textSecond)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.hijauTua, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Ambil foto'),
          ),
        ],
      ),
    );
    return lanjut ?? false;
  }

  void _showSuksesSheet({required bool lokasiTercatat}) {
    final double tampilNominal = widget.isMurniKasbon 
        ? (double.tryParse(_nominalKasbonCtrl.text) ?? 0) 
        : _totalBayar;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SuksesSheet(
        totalBayar: tampilNominal,
        potonganKasbon: widget.isMurniKasbon ? 0 : _potonganTampil,
        namaPetani: _petaniTerpilih?.namaPetani ?? _namaPenjualCtrl.text,
        isKasbonTitle: widget.isMurniKasbon,
        lokasiTercatat: lokasiTercatat,
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
              
              // ── BENTO SECTION: PETANI ──
              _FormSection(
                title: 'Informasi Mitra / Penjual',
                icon: Icons.person_pin_rounded,
                children: [
                  _FieldLabel(widget.isMurniKasbon ? 'Pilih Mitra Petani (Wajib)' : 'Pilih Petani (Opsional)'),
                  DropdownButtonFormField<PetaniHiveModel>(
                    value: _petaniTerpilih,
                    isExpanded: true,
                    decoration: _dropDeco(),
                    hint: const Text('Pilih dari daftar mitra'),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint),
                    validator: (v) => widget.isMurniKasbon && v == null ? 'Silakan pilih mitra petani' : null,
                    items: _daftarPetani
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.namaPetani, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary))))
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
                      validator: (v) => (v?.isEmpty ?? true) ? 'Nama lengkap tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),
                    _ReksaField(
                      ctrl: _desaCtrl,
                      label: 'Asal Desa / Wilayah',
                      hint: 'Masukkan asal desa',
                      validator: (v) => (v?.isEmpty ?? true) ? 'Nama desa tidak boleh kosong' : null,
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
                      validator: (v) => ((v?.isEmpty ?? true) || (double.tryParse(v!) ?? 0) <= 0) ? 'Silakan masukkan jumlah nominal pinjaman yang valid' : null,
                    ),
                  ],
                ),
              ] else ...[
                // ── BENTO SECTION: KOMODITAS ──
                _FormSection(
                  title: 'Rincian Komoditas',
                  icon: Icons.eco_rounded,
                  children: [
                    if (!_isEditMode) ...[
                      KartuSaranKomoditas(
                        labelSaran: _adaSaranAi ? widget.saranKomoditasAi : null,
                        keyakinan: widget.keyakinanSaranAi,
                        onGanti: _komoditasTerpilih == null ? null : () => _gantiKomoditas(null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _FieldLabel('Jenis Komoditas'),
                    DropdownButtonFormField<KomoditasHiveModel>(
                      value: _komoditasTerpilih,
                      isExpanded: true,
                      decoration: _dropDeco(),
                      hint: const Text('Pilih komoditas panen'),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint),
                      items: _daftarKomoditas
                          .map((k) => DropdownMenuItem(value: k, child: Text(k.namaKomoditas, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary))))
                          .toList(),
                      validator: (_) => _komoditasTerpilih == null ? 'Silakan pilih komoditas' : null,
                      onChanged: _gantiKomoditas,
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel('Kualitas (Checklist)'),
                    FormField<String>(
                      validator: (_) {
                        if (_komoditasTerpilih == null) return null;
                        if (_rubrik == null) return 'Belum ada rubrik untuk komoditas ini';
                        if (_gradeTerpilih == null) return 'Lengkapi checklist kualitas untuk menentukan grade';
                        if (!_daftarGrade.any((g) => g['grade'] == _gradeTerpilih)) {
                          return 'Grade $_gradeTerpilih tidak ada di master data komoditas ini';
                        }
                        return null;
                      },
                      builder: (field) {
                        final rubrik = _rubrik;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_komoditasTerpilih == null)
                              const Text('Pilih komoditas dulu untuk menampilkan checklist.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecond))
                            else if (rubrik == null)
                              const Text('Belum ada rubrik untuk komoditas ini.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecond))
                            else
                              ChecklistRubrik(
                                rubrik: rubrik,
                                jawaban: _jawabanRubrik,
                                onJawab: _pilihJawaban,
                                grade: _gradeChecklist,
                                hargaMaks: _gradeChecklist == null ? null : _hargaMaksGrade,
                                gradeTersimpan: _isEditMode && !_jawabanDisentuh ? _gradeTerpilih : null,
                              ),
                            if (field.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Text(field.errorText!,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.merah)),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ReksaField(
                            ctrl: _beratCtrl,
                            label: 'Kuantitas (kg)',
                            hint: '0',
                            type: const TextInputType.numberWithOptions(decimal: true),
                            formatters: [_desimalFormatter],
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Jumlah berat tidak boleh kosong';
                              if (TransaksiController.parseAngka(v!) == null) return 'Format berat tidak valid';
                              return null;
                            },
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
                                _showSnack('Harga disesuaikan kembali ke batas maksimum Grade $_gradeTerpilih yaitu Rp ${_fmt(maks.toInt())}.', isError: true);
                              }
                              setState(() {});
                            },
                            validator: (v) => (v?.isEmpty ?? true) ? 'Harga per kg tidak boleh kosong' : null,
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
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(widget.isMurniKasbon ? Icons.payments_rounded : Icons.calculate_rounded, color: widget.isMurniKasbon ? const Color(0xFFB45309) : AppTheme.hijauTua, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(child: Text(widget.isMurniKasbon ? 'Pencairan Kasbon' : 'Estimasi Total Bayar', style: TextStyle(color: widget.isMurniKasbon ? const Color(0xFF92400E) : AppTheme.hijauTua, fontWeight: FontWeight.w800, fontSize: 13))),
                                    ],
                                  ),
                                  if (!widget.isMurniKasbon && (_petaniTerpilih?.sisaHutangKasbon ?? 0) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('Sisa kasbon akan memotong total ini', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecond.withOpacity(0.8))),
                                    ),
                                ],
                              )),
                              const SizedBox(width: 8),
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
                                    Flexible(child: Text(widget.isMurniKasbon ? 'Cairkan Pinjaman' : 'Simpan Transaksi', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5))),
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
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: iconColor ?? AppTheme.textPrimary, letterSpacing: -0.3))),
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
  /// Total pembelian (berat x harga), sama dengan `total_bayar` yang tersimpan.
  final double totalBayar;
  /// Bagian total yang melunasi kasbon petani; sisanya dibayar tunai.
  final double potonganKasbon;
  final String namaPetani;
  final bool isKasbonTitle;
  final bool lokasiTercatat;
  final VoidCallback onSelesai;

  const _SuksesSheet({required this.totalBayar, this.potonganKasbon = 0, required this.namaPetani, this.isKasbonTitle = false, this.lokasiTercatat = true, required this.onSelesai});

  Widget _baris(String label, String nilai, {Color warna = AppTheme.textPrimary, double ukuran = 14}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecond, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text(nilai, style: TextStyle(fontSize: ukuran, fontWeight: FontWeight.w900, color: warna, letterSpacing: -0.5)),
        ],
      );

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
      child: SingleChildScrollView(child: Column(
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
          // Di dalam lembar ini, bukan SnackBar: SnackBar akan tertutup lembarnya.
          if (!lokasiTercatat) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.location_off_rounded, color: Color(0xFFB45309), size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text(TransaksiController.pesanLokasiGagal, style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w700, height: 1.3))),
                ],
              ),
            ),
          ],
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
                    const SizedBox(width: 8),
                    Flexible(child: Text(namaPetani, textAlign: TextAlign.end, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppTheme.border)),
                if (potonganKasbon > 0) ...[
                  // Total tersimpan adalah bruto; kasbon dipotong dari situ, sisanya tunai.
                  _baris('Total pembelian', 'Rp ${_fmt(totalBayar.toInt())}'),
                  const SizedBox(height: 10),
                  _baris('Potongan kasbon', '- Rp ${_fmt(potonganKasbon.toInt())}', warna: AppTheme.merah),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppTheme.border)),
                  _baris('Dibayar tunai', 'Rp ${_fmt((totalBayar - potonganKasbon).toInt())}', warna: AppTheme.hijauTua, ukuran: 18),
                ] else
                  _baris(isKasbonTitle ? 'Nominal Kasbon' : 'Total Bayar', 'Rp ${_fmt(totalBayar.toInt())}',
                      warna: isKasbonTitle ? const Color(0xFFB45309) : AppTheme.hijauTua, ukuran: 18),
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
      )),
    );
  }
}