import 'package:axon_vision/controllers/radiolog_controller.dart';
import 'package:axon_vision/utils/api_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class RadiologProfileView extends StatefulWidget {
  const RadiologProfileView({super.key});

  @override
  State<RadiologProfileView> createState() => _RadiologProfileViewState();
}

class _RadiologProfileViewState extends State<RadiologProfileView> {
  final RadiologController controller = Get.find<RadiologController>();
  final TextEditingController _confirmPasswordC = TextEditingController();
  final RxBool _isObscureConfirm = true.obs;
  bool _isSaveHovered = false;
  bool _isCameraHovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchMyProfile();
    });
  }

  @override
  void dispose() {
    _confirmPasswordC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color tealColor = const Color(0xFF0E616B);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 850;

        // ===============================================
        // 1. KARTU PROFIL & DATA INFORMASI (Kiri)
        // ===============================================
        Widget profileCard = Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Lingkaran Foto
                  Obx(() {
                    String url = controller.profileImageUrl.value;
                    bool hasImage = url.isNotEmpty;

                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tealColor.withOpacity(0.15),
                          width: 2,
                        ),
                      ),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tealColor.withOpacity(0.05),
                          border: Border.all(
                            color: tealColor.withOpacity(0.3),
                            width: 1,
                          ),
                          image: DecorationImage(
                            image: hasImage
                                ? NetworkImage(
                                    "${ApiConfig.baseUrl}/$url?v=${DateTime.now().millisecondsSinceEpoch}") as ImageProvider
                                : const AssetImage("assets/doctor_avatar.png"),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }),

                  // Tombol Kamera Kecil
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isCameraHovered = true),
                      onExit: (_) => setState(() => _isCameraHovered = false),
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        transform: Matrix4.identity()..scale(_isCameraHovered ? 1.1 : 1.0),
                        child: InkWell(
                          onTap: () => controller.pickAndUploadAvatar(),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tealColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: tealColor.withOpacity(0.3),
                                  blurRadius: _isCameraHovered ? 8 : 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Nama & Role di bawah foto
              Obx(() => Text(
                    controller.displayName.value,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  )),
              const SizedBox(height: 6),
              Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      controller.displayRole.value.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: tealColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  )),
              const SizedBox(height: 28),
              const Divider(height: 1, color: Color(0xFFF1F3F5)),
              const SizedBox(height: 28),

              // Input fields inside Profile Card
              _buildTextField(
                label: "Nama Lengkap",
                controller: controller.myFullNameC,
                icon: Icons.badge_outlined,
                hint: "Masukkan nama lengkap",
                tealColor: tealColor,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: "Username",
                controller: controller.myUsernameC,
                icon: Icons.person_outline_rounded,
                hint: "Masukkan username",
                readOnly: true,
                tealColor: tealColor,
              ),
            ],
          ),
        );

        // ===============================================
        // 2. KARTU KEAMANAN & PASSWORD (Kanan)
        // ===============================================
        Widget formCard = Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section 2 (Ganti Password)
              Text(
                "Keamanan (Ganti Password)",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              // FIELD PASSWORD LAMA
              _buildPasswordField(
                label: "Password Lama (Opsional)",
                controller: controller.oldPasswordC,
                isObscure: controller.isObscureOld,
                hint: "Masukkan password lama",
                tealColor: tealColor,
              ),

              const SizedBox(height: 20),

              // FIELD PASSWORD BARU
              _buildPasswordField(
                label: "Password Baru (Opsional)",
                controller: controller.newPasswordC,
                isObscure: controller.isObscureNew,
                hint: "Masukkan password baru",
                tealColor: tealColor,
              ),

              const SizedBox(height: 20),

              // FIELD KONFIRMASI PASSWORD BARU
              _buildPasswordField(
                label: "Konfirmasi Password Baru (Opsional)",
                controller: _confirmPasswordC,
                isObscure: _isObscureConfirm,
                hint: "Konfirmasi password baru",
                tealColor: tealColor,
              ),

              const SizedBox(height: 40),

              // TOMBOL SIMPAN
              SizedBox(
                width: double.infinity,
                height: 48,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isSaveHovered = true),
                  onExit: (_) => setState(() => _isSaveHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: Matrix4.identity()..scale(_isSaveHovered ? 1.015 : 1.0),
                    decoration: BoxDecoration(
                      color: tealColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (_isSaveHovered)
                          BoxShadow(
                            color: tealColor.withOpacity(0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          )
                      ],
                    ),
                    child: Obx(() => ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () {
                                  if (controller.newPasswordC.text.isNotEmpty &&
                                      controller.newPasswordC.text != _confirmPasswordC.text) {
                                    Get.snackbar(
                                      "Peringatan",
                                      "Konfirmasi password baru tidak cocok!",
                                      backgroundColor: Colors.redAccent,
                                      colorText: Colors.white,
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                    return;
                                  }
                                  controller.saveProfile();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                          ),
                          child: controller.isLoading.value
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  "Simpan Perubahan",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                        )),
                  ),
                ),
              ),
            ],
          ),
        );

        // ===============================================
        // 3. SUSUNAN HALAMAN UTAMA (Dengan Entrance Animations)
        // ===============================================
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutBack,
          builder: (context, animVal, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - animVal)),
              child: Opacity(
                opacity: animVal.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Perbarui informasi akun dan keamanan Anda.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 28),

                // --- RENDER RESPONSIF ---
                if (isMobile)
                  Column(
                    children: [
                      profileCard,
                      const SizedBox(height: 24),
                      formCard,
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: profileCard),
                      const SizedBox(width: 28),
                      Expanded(flex: 5, child: formCard),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool readOnly = false,
    required Color tealColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: readOnly ? Colors.grey[600] : Colors.black87,
            fontWeight: readOnly ? FontWeight.w500 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            isDense: true,
            fillColor: readOnly ? const Color(0xFFF8F9FA) : Colors.white,
            filled: true,
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: readOnly
                ? Tooltip(
                    message: "Username tidak dapat diubah",
                    child: Icon(Icons.lock_outline_rounded,
                        color: Colors.grey[400], size: 16),
                  )
                : null,
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: tealColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required RxBool isObscure,
    String? hint,
    required Color tealColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => TextField(
              controller: controller,
              obscureText: isObscure.value,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.lock_outline_rounded,
                    color: Colors.grey[400], size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    isObscure.value
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[500],
                    size: 18,
                  ),
                  onPressed: () => isObscure.toggle(),
                ),
                hintText: hint ?? "Masukkan $label",
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tealColor, width: 1.5),
                ),
              ),
            )),
      ],
    );
  }
}
