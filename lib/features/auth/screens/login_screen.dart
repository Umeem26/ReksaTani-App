import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final AuthController _authController = AuthController();
  
  bool _isPasswordVisible = false;
  
  // Animasi untuk Aurora Background
  late AnimationController _bgAnimCtrl;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    
    // Kecepatan putaran Aurora (20 detik 1 putaran penuh)
    _bgAnimCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _bgAnimCtrl.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    bool isSuccess = await _authController.login(_usernameController.text, _passwordController.text);
    if (isSuccess && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AppRouter.getGatekeeper()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: AppTheme.bgPage,
          body: Stack(
            children: [
              // ─── 1. AURORA MESH GRADIENT BACKGROUND ───
              Positioned.fill(
                child: ImageFiltered(
                  // Blur ekstrim untuk menyatukan warna menjadi gradasi halus
                  imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: AnimatedBuilder(
                    animation: _bgAnimCtrl,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _bgAnimCtrl.value * 2 * math.pi,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Bola Hijau
                            Positioned(
                              top: size.height * -0.2, left: size.width * -0.2,
                              child: Container(width: size.width * 0.8, height: size.width * 0.8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.hijauMuda.withOpacity(0.5))),
                            ),
                            // Bola Biru
                            Positioned(
                              bottom: size.height * -0.1, right: size.width * -0.3,
                              child: Container(width: size.width * 0.9, height: size.width * 0.9, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.biru.withOpacity(0.4))),
                            ),
                            // Bola Kuning
                            Positioned(
                              top: size.height * 0.2, right: size.width * -0.1,
                              child: Container(width: size.width * 0.6, height: size.width * 0.6, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.kuning.withOpacity(0.4))),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ),
              ),

              // ─── 2. FLOATING GLASS TABLET (FORM LOGIN) ───
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 40, offset: const Offset(0, 15))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // LOGO MELAYANG DI DALAM KACA
                                Container(
                                  width: 80, height: 80, padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))]),
                                  child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 40, color: AppTheme.hijauTua)),
                                ),
                                const SizedBox(height: 24),
                                
                                // HEADER TEKS
                                const Text('Selamat Datang', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                                const SizedBox(height: 6),
                                const Text('Rantai Pasok Finansial ReksaTani', style: TextStyle(color: AppTheme.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 40),

                                // INPUT FORM
                                _buildModernTextField(controller: _usernameController, focusNode: _usernameFocus, hint: 'Username', icon: Icons.person_outline_rounded),
                                const SizedBox(height: 20),
                                _buildModernTextField(controller: _passwordController, focusNode: _passwordFocus, hint: 'Password', icon: Icons.lock_outline_rounded, isPassword: true),
                                const SizedBox(height: 24),

                                // ERROR MESSAGE PILL
                                ValueListenableBuilder<String?>(
                                  valueListenable: _authController.errorMessage,
                                  builder: (context, error, child) {
                                    if (error == null) return const SizedBox.shrink();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      margin: const EdgeInsets.only(bottom: 24),
                                      decoration: BoxDecoration(color: AppTheme.merah.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.merah.withOpacity(0.3))),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: AppTheme.merah, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(error, style: const TextStyle(color: AppTheme.merah, fontSize: 12, fontWeight: FontWeight.w700))),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                // LOGIN BUTTON GRADIENT
                                ValueListenableBuilder<bool>(
                                  valueListenable: _authController.isLoading,
                                  builder: (context, isLoading, child) {
                                    return Container(
                                      width: double.infinity, height: 58,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.headerGradient,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                        child: isLoading
                                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                            : const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0)),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
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

  // WIDGET TEXTFIELD "PILL" MODERN
  Widget _buildModernTextField({required TextEditingController controller, required FocusNode focusNode, required String hint, required IconData icon, bool isPassword = false}) {
    final hasFocus = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: hasFocus ? [BoxShadow(color: AppTheme.hijauMuda.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))] : null,
      ),
      child: TextFormField(
        controller: controller, focusNode: focusNode, obscureText: isPassword && !_isPasswordVisible,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
        cursorColor: AppTheme.hijauTua,
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: AppTheme.textSecond.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: hasFocus ? AppTheme.hijauTua : AppTheme.textSecond, size: 22),
          suffixIcon: isPassword ? IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: AppTheme.textSecond, size: 20), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)) : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.7), // Kontras warna solid untuk input
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.hijauTua, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppTheme.merah.withOpacity(0.5), width: 1.5)),
        ),
      ),
    );
  }
}