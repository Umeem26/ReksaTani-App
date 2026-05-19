import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../../../core/routing/app_router.dart';

// --- COLOR PALETTE (Light Mode Adapted) ---
const Color textDark = Color(0xFF061621);    // Teks utama (Gelap pekat)
const Color textMuted = Color(0xFF7B8B9A);   // Teks sekunder (Abu-abu)
const Color bgLight = Color(0xFFF5F7FA);     // Background utama aplikasi (Off-white)
const Color cardWhite = Color(0xFFFFFFFF);   // Background form
const Color greenPrimary = Color(0xFF00AE3F);// Hijau nyala
const Color greenMedium = Color(0xFF019241); // Hijau sedang (Gradient)
const Color inputBg = Color(0xFFF3F4F6);     // Background kolom isian

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final AuthController _authController = AuthController();
  
  bool _isPasswordVisible = false;
  Offset _pointerOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Memantau fokus untuk animasi pendaran bayangan input
    _usernameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();

    // Menggunakan AuthController asli milik Anda
    bool isSuccess = await _authController.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (isSuccess && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AppRouter.getGatekeeper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        // Deteksi gestur untuk efek Parallax 3D pada latar belakang
        onPanUpdate: (details) {
          setState(() {
            _pointerOffset += details.delta;
          });
        },
        child: Scaffold(
          backgroundColor: bgLight,
          body: Stack(
            children: [
              // ─── 1. LATAR BELAKANG GRADIEN HALUS ───
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cardWhite, Color(0xFFF0FFF4), Color(0xFFE6FFFA)],
                  ),
                ),
              ),
              
              // ─── 2. BOLA DEKORASI DENGAN EFEK PARALLAX ───
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                top: (size.height * 0.08) + (_pointerOffset.dy * 0.05), 
                left: -40 + (_pointerOffset.dx * 0.05),
                child: CircleAvatar(radius: 95, backgroundColor: greenPrimary.withOpacity(0.15)),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                bottom: (size.height * 0.12) - (_pointerOffset.dy * 0.05), 
                right: -20 - (_pointerOffset.dx * 0.05),
                child: CircleAvatar(radius: 85, backgroundColor: const Color(0xFFE6FFFA).withOpacity(0.8)),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                top: (size.height * 0.35) + (_pointerOffset.dy * 0.02), 
                right: 25 + (_pointerOffset.dx * 0.02),
                child: CircleAvatar(radius: 45, backgroundColor: const Color(0xFFFEF3C7).withOpacity(0.6)),
              ),

              // ─── 3. KONTEN UTAMA ───
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // --- LOGO & BRANDING ---
                          Container(
                            width: 75, height: 75,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cardWhite,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 25,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 45, color: greenPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'ReksaTani',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sistem Rantai Pasok Finansial',
                            style: TextStyle(color: textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 32),

                          // ─── KARTU FORM GLASSMORPHISM ───
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: cardWhite.withOpacity(0.8), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 35,
                                  offset: const Offset(0, 12),
                                )
                              ],
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: cardWhite.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Selamat Datang',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Masuk ke akun untuk melanjutkan aktivitas',
                                      style: TextStyle(fontSize: 12, color: textMuted),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 28),

                                    // --- INPUT USERNAME ---
                                    _buildModernTextField(
                                      controller: _usernameController,
                                      focusNode: _usernameFocus,
                                      label: 'Username',
                                      hint: 'Masukkan username',
                                      icon: Icons.person_outline,
                                    ),
                                    const SizedBox(height: 18),

                                    // --- INPUT PASSWORD ---
                                    _buildModernTextField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      label: 'Password',
                                      hint: 'Masukkan password',
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                    ),
                                    const SizedBox(height: 24),

                                    // --- ERROR MESSAGE (Reaktif Asli) ---
                                    ValueListenableBuilder<String?>(
                                      valueListenable: _authController.errorMessage,
                                      builder: (context, error, child) {
                                        if (error == null) return const SizedBox.shrink();
                                        return Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                          margin: const EdgeInsets.only(bottom: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  error,
                                                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),

                                    // --- TOMBOL LOGIN (Reaktif Asli) ---
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _authController.isLoading,
                                      builder: (context, isLoading, child) {
                                        return SizedBox(
                                          height: 52,
                                          child: ElevatedButton(
                                            onPressed: isLoading ? null : _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: greenPrimary,
                                              foregroundColor: cardWhite,
                                              elevation: 4,
                                              shadowColor: greenPrimary.withOpacity(0.3),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: isLoading
                                                ? const SizedBox(
                                                    height: 22, width: 22,
                                                    child: CircularProgressIndicator(color: cardWhite, strokeWidth: 2.5),
                                                  )
                                                : const Text(
                                                    'MASUK',
                                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET MODERN TEXTFIELD DENGAN EFEK FOKUS ---
  Widget _buildModernTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    final hasFocus = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textDark),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: hasFocus
                ? [BoxShadow(color: greenPrimary.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword && !_isPasswordVisible,
            style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
            cursorColor: greenPrimary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.normal),
              prefixIcon: Icon(icon, color: hasFocus ? greenPrimary : textMuted, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: textMuted,
                        size: 19,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardWhite.withOpacity(0.9),
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: greenPrimary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}