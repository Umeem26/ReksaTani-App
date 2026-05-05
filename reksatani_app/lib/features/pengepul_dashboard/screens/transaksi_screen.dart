import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/hive/transaksi_hive_model.dart';
import '../../../models/hive/petani_hive_model.dart';
import '../../../models/hive/komoditas_hive_model.dart';
import '../../../services/hive_service.dart';
import '../../../shared/widgets/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// SHELL — orkestrasi flow: Kamera → Form
// ═══════════════════════════════════════════════════════════════
class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

enum _Fase { kamera, form }

class _TransaksiScreenState extends State<TransaksiScreen> {
  _Fase _fase = _Fase.kamera;

  void _onFotoDiambil() => setState(() => _fase = _Fase.form);
  void _onKembali()     => setState(() => _fase = _Fase.kamera);
  void _onSelesai()     => setState(() => _fase = _Fase.kamera);

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: _fase == _Fase.kamera
            ? _KameraScreen(
                key: const ValueKey('kamera'),
                onFotoDiambil: _onFotoDiambil,
              )
            : _FormScreen(
                key: const ValueKey('form'),
                onKembali: _onKembali,
                onSelesai: _onSelesai,
              ),
      );
}

// ═══════════════════════════════════════════════════════════════
// KAMERA SCREEN
// ═══════════════════════════════════════════════════════════════
class _KameraScreen extends StatefulWidget {
  final VoidCallback onFotoDiambil;
  const _KameraScreen({super.key, required this.onFotoDiambil});

  @override
  State<_KameraScreen> createState() => _KameraScreenState();
}

class _KameraScreenState extends State<_KameraScreen> {
  bool _flashOn   = false;
  bool _capturing = false;

  Future<void> _shoot() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    widget.onFotoDiambil();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Dummy viewfinder ─────────────────────────────
            Container(
              color: const Color(0xFF1A1A1A),
              child: CustomPaint(painter: _GridPainter()),
            ),

            // ── Top bar ──────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _CamBtn(icon: Icons.close_rounded, onTap: () {}),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Foto Nota Pembayaran',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    _CamBtn(
                      icon: _flashOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      onTap: () =>
                          setState(() => _flashOn = !_flashOn),
                    ),
                  ],
                ),
              ),
            ),

            // ── Hint ─────────────────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.crop_free_rounded,
                        color: Colors.white70, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Arahkan ke nota pembayaran',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom controls ───────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Galeri
                    _CamBtn(
                      icon: Icons.photo_library_outlined,
                      size: 48,
                      onTap: widget.onFotoDiambil,
                    ),
                    // Shutter
                    GestureDetector(
                      onTap: _shoot,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 3),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _capturing
                                  ? Colors.grey[300]
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Flip kamera
                    _CamBtn(
                      icon: Icons.flip_camera_ios_outlined,
                      size: 48,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CamBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CamBtn(
      {required this.icon, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black45,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width / 3 * i, 0),
          Offset(size.width / 3 * i, size.height), p);
      canvas.drawLine(Offset(0, size.height / 3 * i),
          Offset(size.width, size.height / 3 * i), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════
// FORM INPUT SCREEN
// ═══════════════════════════════════════════════════════════════
class _FormScreen extends StatefulWidget {
  final VoidCallback onKembali;
  final VoidCallback onSelesai;

  const _FormScreen(
      {super.key,
      required this.onKembali,
      required this.onSelesai});

  @override
  State<_FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<_FormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _hive       = HiveService();

  // Controllers
  final _namaPenjualCtrl = TextEditingController();
  final _desaCtrl        = TextEditingController();
  final _beratCtrl       = TextEditingController();
  final _hargaCtrl       = TextEditingController();

  // State
  PetaniHiveModel?    _petaniTerpilih;
  KomoditasHiveModel? _komoditasTerpilih;
  String?             _gradeTerpilih;
  bool                _saving = false;

  // Data dari Hive
  List<PetaniHiveModel> get _daftarPetani =>
      _hive.petaniBox.values.toList();

  List<KomoditasHiveModel> get _daftarKomoditas =>
      _hive.komoditasBox.values.toList();

  List<Map<String, dynamic>> get _daftarGrade {
    if (_komoditasTerpilih == null) return [];
    return _komoditasTerpilih!.gradeKualitas;
  }

  double get _hargaMaksGrade {
    if (_gradeTerpilih == null || _daftarGrade.isEmpty) return 0;
    final g = _daftarGrade.firstWhere(
      (g) => g['grade'] == _gradeTerpilih,
      orElse: () => {},
    );
    return (g['harga_maks'] as num?)?.toDouble() ?? 0;
  }

  double get _totalBayar {
    final berat = double.tryParse(_beratCtrl.text) ?? 0;
    final harga = double.tryParse(_hargaCtrl.text) ?? 0;
    return berat * harga;
  }

  bool get _hargaMelebihi {
    final harga = double.tryParse(_hargaCtrl.text) ?? 0;
    return _hargaMaksGrade > 0 && harga > _hargaMaksGrade;
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
        'Harga melebihi batas maksimal grade $_gradeTerpilih '
        '(Rp ${_fmt(_hargaMaksGrade.toInt())})!',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    final user = _hive.usersBox.get('currentUser')!;
    final now  = DateTime.now();

    final trx = TransaksiHiveModel(
      idLokal: '${user.id}_${now.millisecondsSinceEpoch}',
      pengepulId: user.id,
      petaniId: _petaniTerpilih?.id ?? '',
      namaPengepul: user.username,
      namaPetani: _namaPenjualCtrl.text.trim(),
      namaKomoditas: _komoditasTerpilih?.namaKomoditas ?? '',
      gradeTerpilih: _gradeTerpilih ?? '',
      berat: double.tryParse(_beratCtrl.text) ?? 0,
      hargaBeliSatuan: double.tryParse(_hargaCtrl.text) ?? 0,
      nominalPotongKasbon: _petaniTerpilih?.sisaHutangKasbon ?? 0,
      totalBayar: _totalBayar,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: 0,
      longitude: 0,
      statusSinkronisasi: 'pending',
      createdAt: now,
    );

    await _hive.saveTransaksi(trx);
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _saving = false);
    _showSuksesSheet();
  }

  void _showSuksesSheet() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _SuksesSheet(
          totalBayar: _totalBayar,
          namaPetani: _namaPenjualCtrl.text,
          onSelesai: () {
            Navigator.pop(context);
            widget.onSelesai();
          },
        ),
      );

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppTheme.merah : AppTheme.hijauTua,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final bulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final tanggal =
        '${now.day} ${bulan[now.month]} ${now.year}';
    final jam =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Input Transaksi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: widget.onKembali,
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

            // ── Banner foto berhasil ───────────────────────────
            _BannerFoto(),
            const SizedBox(height: 16),

            // ── Data Penjual ───────────────────────────────────
            _FormSection(
              title: 'Data Penjual',
              icon: Icons.person_outline_rounded,
              children: [
                // Dropdown petani dari Hive
                if (_daftarPetani.isNotEmpty) ...[
                  _FieldLabel('Pilih Petani (opsional)'),
                  DropdownButtonFormField<PetaniHiveModel>(
                    value: _petaniTerpilih,
                    hint: const Text('Pilih dari daftar petani',
                        style: TextStyle(
                            color: AppTheme.textHint, fontSize: 13)),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecond),
                    decoration: _dropDeco(),
                    onChanged: (p) {
                      setState(() {
                        _petaniTerpilih = p;
                        if (p != null) {
                          _namaPenjualCtrl.text = p.namaPetani;
                          _desaCtrl.text = p.desa;
                        }
                      });
                    },
                    items: _daftarPetani
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.namaPetani,
                                  style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                _ReksaField(
                  ctrl: _namaPenjualCtrl,
                  label: 'Nama Penjual',
                  hint: 'Masukkan nama penjual',
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                _ReksaField(
                  ctrl: _desaCtrl,
                  label: 'Desa / Asal',
                  hint: 'Masukkan asal desa',
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                ),
                // Info kasbon jika petani dipilih
                if (_petaniTerpilih != null &&
                    _petaniTerpilih!.sisaHutangKasbon > 0)
                  _KasbonInfo(
                      sisa: _petaniTerpilih!.sisaHutangKasbon),
              ],
            ),
            const SizedBox(height: 14),

            // ── Data Komoditas ─────────────────────────────────
            _FormSection(
              title: 'Data Komoditas',
              icon: Icons.grass_rounded,
              children: [
                _FieldLabel('Jenis Komoditas'),
                DropdownButtonFormField<KomoditasHiveModel>(
                  value: _komoditasTerpilih,
                  hint: const Text('Pilih komoditas',
                      style: TextStyle(
                          color: AppTheme.textHint, fontSize: 13)),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecond),
                  decoration: _dropDeco(),
                  validator: (_) => _komoditasTerpilih == null
                      ? 'Pilih komoditas'
                      : null,
                  onChanged: (k) => setState(() {
                    _komoditasTerpilih = k;
                    _gradeTerpilih = null;
                    _hargaCtrl.clear();
                  }),
                  items: _daftarKomoditas
                      .map((k) => DropdownMenuItem(
                            value: k,
                            child: Text(k.namaKomoditas,
                                style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
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
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Wajib' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReksaField(
                        ctrl: _hargaCtrl,
                        label: 'Harga / kg (Rp)',
                        hint: '0',
                        type: TextInputType.number,
                        formatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Wajib' : null,
                        isError: _hargaMelebihi,
                      ),
                    ),
                  ],
                ),
                // Warning harga melebihi maks
                if (_hargaMelebihi)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.merah, size: 14),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Harga melebihi batas maks grade '
                            '$_gradeTerpilih: '
                            'Rp ${_fmt(_hargaMaksGrade.toInt())}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.merah),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _FieldLabel('Kualitas'),
                DropdownButtonFormField<String>(
                  value: _gradeTerpilih,
                  hint: const Text('Pilih kualitas',
                      style: TextStyle(
                          color: AppTheme.textHint, fontSize: 13)),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecond),
                  decoration: _dropDeco(),
                  validator: (_) =>
                      _gradeTerpilih == null ? 'Pilih kualitas' : null,
                  onChanged: (g) => setState(() {
                    _gradeTerpilih = g;
                    // Auto-isi harga dengan harga maks grade
                    final maks = _daftarGrade.firstWhere(
                      (x) => x['grade'] == g,
                      orElse: () => {},
                    );
                    final hMaks =
                        (maks['harga_maks'] as num?)?.toInt() ?? 0;
                    if (hMaks > 0) _hargaCtrl.text = '$hMaks';
                    setState(() {});
                  }),
                  items: _daftarGrade
                      .map((g) => DropdownMenuItem<String>(
                            value: g['grade'] as String,
                            child: Row(children: [
                              Text(g['grade'] as String,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(
                                '(Maks Rp ${_fmt(((g['harga_maks'] as num?)?.toInt() ?? 0))})',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecond),
                              ),
                            ]),
                          ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Total Bayar live ───────────────────────────────
            if (_totalBayar > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.hijauSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.hijauMuda.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        color: AppTheme.hijauTua, size: 20),
                    const SizedBox(width: 10),
                    const Text('Total Bayar',
                        style: TextStyle(
                            color: AppTheme.hijauTua,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      'Rp ${_fmt(_totalBayar.toInt())}',
                      style: const TextStyle(
                          color: AppTheme.hijauTua,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            if (_totalBayar > 0) const SizedBox(height: 14),

            // ── Waktu Transaksi (otomatis) ─────────────────────
            _FormSection(
              title: 'Waktu Transaksi',
              icon: Icons.access_time_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ReadonlyField(
                          label: 'Tanggal (Otomatis)',
                          value: tanggal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReadonlyField(
                          label: 'Jam (Otomatis)', value: jam),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Tombol Simpan ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hijauMuda,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Simpan Transaksi'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropDeco() => InputDecoration(
        filled: true,
        fillColor: AppTheme.bgPage,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.hijauMuda, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.merah, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.merah, width: 1.5)),
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
}

// ═══════════════════════════════════════════════════════════════
// REUSABLE FORM WIDGETS
// ═══════════════════════════════════════════════════════════════

class _BannerFoto extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF019241), Color(0xFF00AE3F)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 26),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Foto note berhasil diambil',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                SizedBox(height: 2),
                Text('Lengkapi data transaksi di bawah',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      );
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSection(
      {required this.title,
      required this.icon,
      required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: AppTheme.hijauMuda),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary)),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecond)),
      );
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
  Widget build(BuildContext context) => Column(
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
              hintStyle: const TextStyle(
                  color: AppTheme.textHint, fontSize: 13),
              filled: true,
              fillColor: AppTheme.bgPage,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.border)),
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
                    color: isError
                        ? AppTheme.merah
                        : AppTheme.hijauMuda,
                    width: 1.5,
                  )),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.merah, width: 1.5)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.merah, width: 1.5)),
            ),
          ),
        ],
      );
}

class _ReadonlyField extends StatelessWidget {
  final String label, value;
  const _ReadonlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppTheme.hijauSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.hijauMuda.withOpacity(0.3)),
            ),
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.hijauTua,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      );
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppTheme.kuning.withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.kuning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Petani ini memiliki sisa kasbon '
                'Rp ${_fmt(sisa.toInt())} yang akan dipotong.',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM SHEET SUKSES
// ═══════════════════════════════════════════════════════════════
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikon sukses
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.hijauSoft),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.hijauMuda, size: 42),
            ),
            const SizedBox(height: 16),
            const Text('Transaksi Berhasil Disimpan!',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Tersimpan di perangkat · Pending Sync ke server',
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textSecond),
            ),
            const SizedBox(height: 20),

            // Ringkasan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgPage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                _Row('Petani', namaPetani),
                const SizedBox(height: 8),
                _Row('Total Bayar',
                    'Rp ${_fmt(totalBayar.toInt())}',
                    valueColor: AppTheme.hijauTua),
                const SizedBox(height: 8),
                _Row('Status', 'Pending Sync'),
              ]),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Selesai',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecond)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppTheme.textPrimary)),
        ],
      );
}