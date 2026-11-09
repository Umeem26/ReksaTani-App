import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/master_data_service.dart';
import 'app_theme.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final bool showBanner;

  /// True: pill mengambil ruang di atas isi, sehingga isi bergeser ke bawah
  /// dan tidak tertutup. False (bawaan): pill mengambang di atas isi.
  final bool geserIsi;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showBanner = true,
    this.geserIsi = false,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOnline = true;
  bool _showPill = false;
  bool? _wasOnline;
  bool _gagalSinkron = false;

  late final AnimationController _animCtrl;
  late final Animation<Offset> _offsetAnim;

  @override
  void initState() {
    super.initState();
    
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutBack,
    ));

    _checkInitialConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    MasterDataService().addListener(_segarkanStatusSinkron);
    _segarkanStatusSinkron();
  }

  @override
  void dispose() {
    MasterDataService().removeListener(_segarkanStatusSinkron);
    _subscription.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  /// Dipanggil tiap sync selesai. Saat offline, pill offline yang tampil.
  void _segarkanStatusSinkron() {
    if (!mounted) return;
    final gagal = _isOnline && MasterDataService().perluPeringatanSinkron;
    setState(() => _gagalSinkron = gagal);
    if (gagal) {
      _animCtrl.forward();
    } else if (!_showPill) {
      _animCtrl.reverse();
    }
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (_) {}
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!mounted) return;

    if (_wasOnline != null && _wasOnline == false && online == true) {
      // Transition from offline to online: trigger auto-sync
      MasterDataService().syncAll();

      setState(() {
        _isOnline = true;
        _showPill = true;
      });
      _animCtrl.forward();

      // Automatically hide the green success pill after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isOnline) {
          if (_gagalSinkron) {
            setState(() => _showPill = false);
            return;
          }
          _animCtrl.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showPill = false;
              });
            }
          });
        }
      });
    } else if (!online) {
      // Connection lost
      setState(() {
        _isOnline = false;
        _showPill = true;
      });
      _animCtrl.forward();
    } else {
      // Initially online or stayed online
      setState(() {
        _isOnline = true;
        _showPill = false;
      });
      if (!_gagalSinkron) _animCtrl.reverse();
    }

    _wasOnline = online;
    _segarkanStatusSinkron();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.geserIsi) {
      final tampil = widget.showBanner && (_showPill || _gagalSinkron);
      // Slot pill selalu ada, supaya posisi isi di pohon widget tidak berubah
      // (state gulir tetap) saat pill muncul atau hilang.
      return Column(
        children: [
          ClipRect(
            child: tampil
                ? SlideTransition(
                    position: _offsetAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Material(color: Colors.transparent, child: _buildPill()),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(child: widget.child),
        ],
      );
    }
    return Stack(
      children: [
        widget.child,
        if (widget.showBanner && (_showPill || _gagalSinkron))
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SlideTransition(
                position: _offsetAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: _buildPill(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPill() {
    final amber = !_isOnline || _gagalSinkron;
    final bgColor = amber ? const Color(0xFFD97706) : AppTheme.hijauTua; // Amber vs Hijau
    final icon = !_isOnline
        ? Icons.cloud_off_rounded
        : _gagalSinkron
            ? Icons.sync_problem_rounded
            : Icons.cloud_done_rounded;
    final message = !_isOnline
        ? 'Mode Luring (Offline) · Menggunakan Data Lokal'
        : _gagalSinkron
            ? MasterDataService().pesanGagalSinkron
            : 'Kembali Online · Menyinkronkan...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
