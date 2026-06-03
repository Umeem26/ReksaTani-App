import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/master_data_service.dart';
import 'app_theme.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final bool showBanner;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showBanner = true,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOnline = true;
  bool _showPill = false;
  bool? _wasOnline;

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
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animCtrl.dispose();
    super.dispose();
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
      _animCtrl.reverse();
    }

    _wasOnline = online;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showBanner && _showPill)
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
    final bgColor = _isOnline ? AppTheme.hijauTua : const Color(0xFFD97706); // Hijau vs Amber
    final icon = _isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;
    final message = _isOnline 
        ? 'Kembali Online · Menyinkronkan...' 
        : 'Mode Luring (Offline) · Menggunakan Data Lokal';

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
