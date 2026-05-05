import 'package:flutter/material.dart';
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
  final AuthController _authController = AuthController();
  bool _isPasswordVisible = false;

  void _handleLogin() async {
    FocusScope.of(context).unfocus();

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
    // Mendapatkan tinggi layar untuk proporsi header
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          // --- HEADER LENGKUNG (BACKGROUND) ---
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [greenMedium, greenPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),

          // --- KONTEN UTAMA ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      
                      // --- LOGO & NAMA APP ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 70,
                          height: 70,
                          errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.eco, size: 70, color: greenPrimary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ReksaTani',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: cardWhite,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Text(
                        'Sistem Rantai Pasok Finansial',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- KARTU FORM LOGIN (FLOATING CARD) ---
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Selamat Datang',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Masuk untuk melanjutkan aktivitas luring',
                              style: TextStyle(fontSize: 13, color: textMuted),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // --- INPUT USERNAME ---
                            _buildModernTextField(
                              controller: _usernameController,
                              label: 'Username',
                              hint: 'Masukkan username',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 20),

                            // --- INPUT PASSWORD ---
                            _buildModernTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Masukkan password',
                              icon: Icons.lock_outline,
                              isPassword: true,
                            ),
                            const SizedBox(height: 28),

                            // --- ERROR MESSAGE ---
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
                                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          error,
                                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // --- TOMBOL LOGIN ---
                            ValueListenableBuilder<bool>(
                              valueListenable: _authController.isLoading,
                              builder: (context, isLoading, child) {
                                return SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: greenPrimary,
                                      foregroundColor: cardWhite,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(color: cardWhite, strokeWidth: 3),
                                          )
                                        : const Text(
                                            'MASUK SEKARANG',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET MODERN TEXTFIELD ---
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          style: const TextStyle(color: textDark, fontSize: 15),
          cursorColor: greenPrimary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textMuted, fontSize: 14),
            prefixIcon: Icon(icon, color: textMuted, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: textMuted,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
      ],
    );
  }
}