import 'package:axon_vision/controllers/login_controller.dart';
import 'package:axon_vision/pages/global_widgets/frame/frame_scaffold.dart';
import 'package:axon_vision/utils/app_colors.dart';
import 'package:axon_vision/utils/asset_list.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isObscure = true;

  @override
  Widget build(BuildContext context) {
    // Warna sesuai mockup screenshot
    final Color deepGreen = const Color(0xFF09503C); // Deep pine green matching user image background
    final Color buttonGreen = const Color(0xFF037B55); // Emerald green untuk tombol masuk & highlight
    final Color borderActive = const Color(0xFF0F9F72); // Border hijau aktif

    return FrameScaffold(
      heightBar: 0,
      elevation: 0,
      color: AppColors.black,
      statusBarColor: AppColors.black,
      colorScaffold: Colors.white,
      statusBarBrightness: Brightness.light,
      view: GetBuilder<LoginController>(
        init: LoginController(),
        builder: (LoginController loginController) => LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 800;

            if (isMobile) {
              // ============================================
              // TAMPILAN MOBILE & TABLET KECIL
              // ============================================
              return Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo dan Judul Atas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              AssetList.axonLogo,
                              height: 36,
                              color: deepGreen,
                              errorBuilder: (c, e, s) => Icon(
                                Icons.psychology_outlined,
                                size: 36,
                                color: deepGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text.rich(
                              TextSpan(
                                text: "Neuro",
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: deepGreen,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Scan",
                                    style: GoogleFonts.poppins(
                                      color: buttonGreen,
                                    ),
                                  ),
                                  TextSpan(
                                    text: " AI",
                                    style: GoogleFonts.poppins(
                                      color: deepGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Sistem Deteksi Tumor Otak",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Form Fields
                        _buildFormContent(loginController, deepGreen, buttonGreen, borderActive, isMobile: true),
                        
                        const SizedBox(height: 48),
                        Text(
                          '© 2026 NeuroScan AI. All Rights Reserved.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              // ============================================
              // TAMPILAN DESKTOP (MATCHING SCREENSHOT 100%)
              // ============================================
              return Row(
                children: [
                  // 1. PANEL HIJAU (KIRI)
                  Expanded(
                    flex: 6,
                    child: Container(
                      height: double.infinity,
                      color: deepGreen,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top-Left Header: Logo + Title
                          Row(
                            children: [
                              Image.asset(
                                AssetList.axonLogo,
                                height: 40,
                                color: Colors.white,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.psychology_outlined,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text.rich(
                                TextSpan(
                                  text: "Neuro",
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: "Scan",
                                      style: TextStyle(
                                        color: Color(0xFF30E3CA), // Premium mint-turquoise
                                      ),
                                    ),
                                    const TextSpan(
                                      text: " AI",
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Center: 3D Brain Illustration
                          Center(
                            child: Image.asset(
                              "assets/login_brain.png",
                              height: 380,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.psychology_outlined,
                                size: 180,
                                color: Colors.white24,
                              ),
                            ),
                          ),

                          // Bottom: Technical details
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  "Advanced Medical AI for Brain Tumor Detection.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Powered by Deep Learning.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. PANEL PUTIH (KANAN)
                  Expanded(
                    flex: 5,
                    child: Container(
                      height: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Header: NeuroScan AI + Subtitle
                                Text.rich(
                                  TextSpan(
                                    text: "Neuro",
                                    style: GoogleFonts.poppins(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      height: 1.1,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: "Scan",
                                        style: GoogleFonts.poppins(
                                          color: buttonGreen,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: " AI",
                                        style: TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Sistem Deteksi Tumor Otak",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 48),

                                // Login Fields
                                _buildFormContent(loginController, deepGreen, buttonGreen, borderActive, isMobile: false),
                                
                                const SizedBox(height: 48),
                                // Footer Copyright
                                Center(
                                  child: Text(
                                    '© 2026 NeuroScan AI. All Rights Reserved.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  // Login Form Content Builder
  Widget _buildFormContent(
    LoginController loginController,
    Color deepGreen,
    Color buttonGreen,
    Color borderActive, {
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input Email
        _buildInputField(
          label: 'Email',
          hint: 'user@example.com',
          controller: loginController.emailController,
          borderActive: borderActive,
          textInputAction: TextInputAction.next,
          // Mengatur agar border awal terlihat hijau pudar seperti di screenshot jika diinginkan,
          // tapi tetap rapi dan bersih
        ),
        const SizedBox(height: 24),

        // Input Kata Sandi
        _buildInputField(
          label: 'Kata Sandi',
          hint: 'Masukkan kata sandi',
          controller: loginController.passwordController,
          borderActive: borderActive,
          isObscure: isObscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            loginController.login();
          },
          suffixIcon: IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey[400],
              size: 20,
            ),
            onPressed: () {
              setState(() {
                isObscure = !isObscure;
              });
            },
          ),
        ),
        const SizedBox(height: 32),

        // Button Masuk
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              loginController.login();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Masuk',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Link: Lupa Kata Sandi?
        Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showForgotPasswordDialog(context),
              child: Text(
                'Lupa Kata Sandi?',
                style: GoogleFonts.poppins(
                  color: buttonGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Link: Belum punya akun? Daftar
        Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                // Sesuai logic bawaan (Daftar / Info)
                Get.snackbar("Info", "Silakan hubungi admin rumah sakit untuk registrasi akun baru.");
              },
              child: Text(
                'Belum punya akun? Daftar',
                style: GoogleFonts.poppins(
                  color: buttonGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Input Field Widget
  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color borderActive,
    bool isObscure = false,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderActive, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// Dialog Info Lupa Password
void _showForgotPasswordDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      final Color tealColor = const Color(0xFF024E3A);
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_person_outlined, color: tealColor),
            const SizedBox(width: 12),
            Text(
              "Akses Terbatas",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        content: Text(
          "Untuk alasan keamanan data medis, pengaturan ulang sandi tidak dapat dilakukan secara mandiri. Silakan hubungi Administrator SIMRS / IT Rumah Sakit.",
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Mengerti",
              style: GoogleFonts.poppins(color: tealColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}
