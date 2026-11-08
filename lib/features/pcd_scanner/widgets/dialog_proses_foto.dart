import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_theme.dart';

/// Tampilan memuat selama foto diproses (pelurusan nota, OCR, saran komoditas).
class DialogProsesFoto extends StatelessWidget {
  const DialogProsesFoto({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.hijauMuda.withValues(alpha: 0.3)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.hijauMuda, strokeWidth: 3),
              SizedBox(height: 20),
              Text(
                'SEDANG MEMPROSES FOTO...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5, decoration: TextDecoration.none),
              ),
              SizedBox(height: 6),
              Text(
                'Membaca nota dan mencari saran komoditas',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecond, fontWeight: FontWeight.w400, fontSize: 11, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
