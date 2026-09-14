import 'package:axon_vision/controllers/dokter_controller.dart';
import 'package:axon_vision/controllers/notification_controller.dart';
import 'package:axon_vision/pages/global_widgets/custom/custom_ripple_button.dart';
import 'package:axon_vision/pages/global_widgets/frame/frame_scaffold.dart';
import 'package:axon_vision/pages/global_widgets/text_fonts/poppins_text_view.dart';
import 'package:axon_vision/pages/dokter/dokter_patient_view.dart';
import 'package:axon_vision/pages/dokter/dokter_profile_view.dart';
import 'package:axon_vision/helpers/snackbar.dart';
import 'package:axon_vision/utils/api_config.dart';
import 'package:axon_vision/utils/app_colors.dart';
import 'package:axon_vision/utils/asset_list.dart';
import 'package:axon_vision/utils/size_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ========================================================================
// 1. WIDGET KONTEN DASHBOARD (HOME) DOKTER
// ========================================================================
class DokterHomeView extends StatelessWidget {
  const DokterHomeView({super.key});

  String getGreeting() {
    var hour = DateTime.now().hour;
    if (hour >= 4 && hour < 10) return 'Selamat Pagi';
    if (hour >= 10 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final DokterController controller = Get.find<DokterController>();
    String todayDate =
        DateFormat('EEE, d MMM yyyy', 'id_ID').format(DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        // DETEKSI LAYAR
        bool isMobile = constraints.maxWidth < 800;

        return Scaffold(
          backgroundColor: const Color(0xffF4F7F9),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.0 : 24.0, vertical: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER WELCOME ---
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeText(controller, todayDate),
                          const SizedBox(height: 16),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWelcomeText(controller, todayDate),
                        ],
                      ),
                const SizedBox(height: 30),

                // --- STATISTIK CARD (AMAN GETX) ---
                Obx(() {
                  // ignore: unused_local_variable
                  var trigger = controller.isLoading.value;
                  // ignore: unused_local_variable
                  var trigger2 = controller.isSidebarExpanded.value;

                  var pasientTotal =
                      controller.dashboardSummary['total_pasien'] ?? 0;
                  var pasientNunggu =
                      controller.dashboardSummary['total_menunggu'] ?? 0;
                  var pasientSelesai =
                      controller.dashboardSummary['total_selesai'] ?? 0;

                  if (isMobile) {
                    return Column(
                      children: [
                        StatCard(
                            title: "Total Pasien",
                            value: "$pasientTotal",
                            icon: Icons.group_rounded,
                            color: const Color(0xff2196F3),
                            delayMs: 0),
                        const SizedBox(height: 16),
                        StatCard(
                            title: "Menunggu Hasil MRI",
                            value: "$pasientNunggu",
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xffFF9F43),
                            delayMs: 150),
                        const SizedBox(height: 16),
                        StatCard(
                            title: "Hasil Tersedia",
                            value: "$pasientSelesai",
                            icon: Icons.verified_rounded,
                            color: const Color(0xff10B981),
                            delayMs: 300),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                            child: StatCard(
                                title: "Total Pasien",
                                value: "$pasientTotal",
                                icon: Icons.group_rounded,
                                color: const Color(0xff2196F3),
                                delayMs: 0)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: StatCard(
                                title: "Menunggu Hasil MRI",
                                value: "$pasientNunggu",
                                icon: Icons.pending_actions_rounded,
                                color: const Color(0xffFF9F43),
                                delayMs: 150)),
                        const SizedBox(width: 20),
                        Expanded(
                            child: StatCard(
                                title: "Hasil Tersedia",
                                value: "$pasientSelesai",
                                icon: Icons.verified_rounded,
                                color: const Color(0xff10B981),
                                delayMs: 300)),
                      ],
                    );
                  }
                }),
                const SizedBox(height: 40),

                // --- RIWAYAT ANALISIS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Riwayat Analisis Terbaru",
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff2C3E50)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => controller.changeMenu(1),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text("Lihat Semua",
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0E616B))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // BOX LIST RIWAYAT
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator()));
                    }
                    if (controller.riwayatScanList.isEmpty) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(30),
                              child: PoppinsTextView(
                                  value: "Belum ada riwayat scan.",
                                  color: Colors.grey,
                                  fontSize: 12)));
                    }

                    var recentHistory =
                        controller.riwayatScanList.take(5).toList();

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentHistory.length,
                      separatorBuilder: (c, i) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                          indent: 24,
                          endIndent: 24),
                      itemBuilder: (context, index) {
                        var item = recentHistory[index];
                        return HistoryItemTile(
                          item: item,
                          isMobile: isMobile,
                          index: index,
                          onTap: () {
                            controller.activeIndex.value = 1;
                            controller
                                .openAnalysisResult(item['id'].toString());
                          },
                        );
                      },
                    );
                  }),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeText(DokterController controller, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() => Text("${getGreeting()},\n${controller.displayName.value}!",
            style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: const Color(0xff2C3E50)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 8),
        PoppinsTextView(
            value: "Update hari ini: $date", fontSize: 12, color: Colors.grey),
      ],
    );
  }

}

// ========================================================================
// 2. KERANGKA UTAMA DASHBOARD DOKTER
// ========================================================================
class DokterDashboardPage extends StatelessWidget {
  const DokterDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final DokterController controller = Get.put(DokterController());

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    bool isMobile = screenWidth < 850;

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xffF4F7F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: IconThemeData(color: AppColors.black),
          title: Obx(() {
            var _ = controller.activeIndex.value;
            return Text(
              controller.currentHeaderTitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.blueDark,
              ),
            );
          }),
          actions: [
            const NotificationBell(role: 'Dokter'),
            const SizedBox(width: 8),
            _buildProfileMenu(controller),
            const SizedBox(width: 16),
          ],
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF0E616B),
          child: _buildSidebarContent(context, controller, true),
        ),
        body: Obx(() {
          var _ = controller.activeIndex.value;
          return Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ClipRRect(child: _buildContent(controller)),
          );
        }),
      );
    }

    return FrameScaffold(
      heightBar: 0,
      elevation: 0,
      color: AppColors.black,
      statusBarColor: AppColors.white,
      statusBarBrightness: Brightness.light,
      view: Obx(
        () => Center(
          child: Container(
            width: screenWidth,
            height: screenHeight,
            decoration: const BoxDecoration(
              color: Color(0xffF4F7F9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: controller.isSidebarExpanded.value ? 256 : 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Container(
                      width: 256,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0E616B),
                      ),
                      child: _buildSidebarContent(context, controller, false),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xffF4F7F9),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => controller.toggleSidebar(),
                              icon: Icon(
                                controller.isSidebarExpanded.value
                                    ? Icons.menu_open_rounded
                                    : Icons.menu_rounded,
                                color: Colors.grey[700],
                                size: 24,
                              ),
                            ),
                            const Spacer(),
                            _buildProfileMenu(controller),
                            const SizedBox(width: 12),
                            Obx(() => Text(
                              controller.displayName.value,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                            )),
                            const SizedBox(width: 16),
                            const NotificationBell(role: 'Dokter'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: const EdgeInsets.all(24),
                          color: const Color(0xffF4F7F9),
                          child: ClipRRect(child: _buildContent(controller)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContent(
      BuildContext context, DokterController controller, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                AssetList.axonLogo,
                fit: BoxFit.contain,
                height: 42,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.psychology_outlined,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      text: "Brain",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: "Scan",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF30E3CA), // Premium mint-turquoise
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(height: 1.1),
                  ),
                  Text(
                    "AI",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Obx(() => Column(
                  children: [
                    _buildMenuItem(
                      index: 0,
                      label: 'Dashboard',
                      icon: Icons.grid_view_rounded,
                      isActive: controller.activeIndex.value == 0,
                      onTap: () {
                        controller.changeMenu(0);
                        if (isMobile) Get.back();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      index: 1,
                      label: 'Patients & Analysis',
                      icon: Icons.people_outline,
                      isActive: controller.activeIndex.value == 1,
                      onTap: () {
                        controller.changeMenu(1);
                        if (isMobile) Get.back();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      index: 2,
                      label: 'Profile Settings',
                      icon: Icons.settings_outlined,
                      isActive: controller.activeIndex.value == 2,
                      onTap: () {
                        controller.changeMenu(2);
                        if (isMobile) Get.back();
                      },
                    ),
                  ],
                )),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(
                color: Colors.white.withOpacity(0.1),
                thickness: 0.5,
              ),
              const SizedBox(height: 10),
              PoppinsTextView(
                value: "BrainScan AI v1.0.0",
                size: 10,
                color: Colors.white.withOpacity(0.4),
              ),
              const SizedBox(height: 4),
              PoppinsTextView(
                value: "© 2026 All Rights Reserved",
                size: 10,
                color: Colors.white.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMenu(DokterController controller) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        if (val == 'profil') {
          controller.changeMenu(2);
        }
        if (val == 'logout') {
          _showLogoutDialog(controller);
        }
      },
      child: Obx(() {
        String url = controller.profileImageUrl.value;
        bool hasImage = url.isNotEmpty;
        return CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF0E616B).withOpacity(0.1),
          backgroundImage: hasImage
              ? NetworkImage(
                  "${ApiConfig.baseUrl}/$url?v=${DateTime.now().millisecondsSinceEpoch}") as ImageProvider
              : const AssetImage("assets/doctor_avatar.png"),
        );
      }),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'profil',
          child: Row(
            children: [
              Icon(Icons.person_outline, color: Colors.grey, size: 18),
              SizedBox(width: 12),
              PoppinsTextView(
                value: "Profil Saya",
                size: 12,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, color: Colors.red, size: 18),
            SizedBox(width: 12),
            PoppinsTextView(
              value: "Keluar",
              size: 12,
              color: Colors.red,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildContent(DokterController controller) {
    if (controller.activeIndex.value == 0) return const DokterHomeView();
    if (controller.activeIndex.value == 1) return const DokterPatientView();
    if (controller.activeIndex.value == 2) return const DokterProfileView();
    return const SizedBox();
  }

  Widget _buildMenuItem(
      {required int index,
      required String label,
      required bool isActive,
      required IconData icon,
      required VoidCallback onTap}) {
    return CustomRippleButton(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (isActive)
              Positioned(
                left: 0,
                child: Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(DokterController controller) {
    SnackbarHelper.showConfirmDialog(
        title: "Konfirmasi Logout",
        description:
            "Apakah Anda yakin ingin keluar dari aplikasi BrainScan AI? Sesi Anda akan berakhir.",
        confirmText: "Ya, Keluar",
        icon: Icons.power_settings_new_rounded,
        iconColor: Colors.redAccent,
        onConfirm: () {
          Get.delete<NotificationController>();
          controller.logout();
        });
  }
}

// ========================================================================
// 3. WIDGET NOTIFICATION BELL (DI-REUSE/SAMA SEPERTI RADIOLOG)
// ========================================================================
class NotificationBell extends StatelessWidget {
  final String role;
  const NotificationBell({super.key, required this.role});

  void _showNotificationPopup(
      BuildContext context, NotificationController notifCtrl) {
    Get.dialog(
      Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(
            top: SizeConfig.safeBlockVertical * 10,
            right: SizeConfig.safeBlockHorizontal * 5,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 350,
              constraints: const BoxConstraints(minWidth: 300, maxHeight: 450),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PoppinsTextView(
                          value: "Notifikasi",
                          fontWeight: FontWeight.bold,
                          size: 14,
                          color: AppColors.black,
                        ),
                        InkWell(
                          onTap: () => Get.back(),
                          child: const Icon(Icons.close,
                              size: 20, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: AppColors.greyDisabled.withOpacity(0.5),
                  ),
                  Expanded(
                    child: Obx(() {
                      if (notifCtrl.isLoading.value &&
                          notifCtrl.notifications.isEmpty) {
                        return const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: notifCtrl.notifications.length,
                          separatorBuilder: (c, i) => Divider(
                                height: 1,
                                color: AppColors.greyDisabled
                                    .withOpacity(0.5),
                              ),
                          itemBuilder: (c, i) {
                            var notif = notifCtrl.notifications[i];
                            return InkWell(
                              onTap: () {
                                notifCtrl.markAsRead(notif.id);
                                Get.back();

                                if (notif.analysisId != null) {
                                  // DIUBAH: Panggil DokterController
                                  final ctrl = Get.find<DokterController>();
                                  ctrl.activeIndex.value = 1;
                                  ctrl.openAnalysisResult(
                                      notif.analysisId.toString());
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                color: notif.isRead
                                    ? Colors.transparent
                                    : AppColors.blueDark
                                        .withOpacity(0.05),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: notif.isRead
                                            ? Colors.grey.withOpacity(0.1)
                                            : AppColors.blueDark
                                                .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.notifications_active,
                                          size: 18,
                                          color: notif.isRead
                                              ? Colors.grey
                                              : AppColors.blueDark),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          PoppinsTextView(
                                            value: notif.title,
                                            fontWeight: notif.isRead
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                            size: 12,
                                            color: AppColors.black,
                                          ),
                                          const SizedBox(height: 4),
                                          PoppinsTextView(
                                            value: notif.message,
                                            size: 11,
                                            color: Colors.black87,
                                          ),
                                          const SizedBox(height: 8),
                                          PoppinsTextView(
                                            value: notif.createdAt,
                                            size: 10,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!notif.isRead)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: CircleAvatar(
                                          radius: 4,
                                          backgroundColor: Colors.red,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          });
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final NotificationController notifCtrl = Get.put(NotificationController());
    return Obx(() {
      int count = notifCtrl.unreadCount;
      return InkWell(
        onTap: () => _showNotificationPopup(context, notifCtrl),
        borderRadius: BorderRadius.circular(50),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_outlined, color: AppColors.grey, size: 26),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final int delayMs;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.delayMs = 0,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color tealColor = const Color(0xFF0E616B);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Interval(
        widget.delayMs / 1000.0 > 1.0 ? 0.0 : widget.delayMs / 1000.0,
        1.0,
        curve: Curves.easeOutBack,
      ),
      builder: (context, animVal, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - animVal)),
          child: Opacity(
            opacity: animVal.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.color.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _isHovered ? 25 : 20,
                offset: _isHovered ? const Offset(0, 10) : const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.value,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: tealColor,
                      height: 1.0,
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isHovered ? 0.05 : 0.0,
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      color: _isHovered ? widget.color : tealColor,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryItemTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isMobile;
  final VoidCallback onTap;
  final int index;

  const HistoryItemTile({
    super.key,
    required this.item,
    required this.isMobile,
    required this.onTap,
    required this.index,
  });

  @override
  State<HistoryItemTile> createState() => _HistoryItemTileState();
}

class _HistoryItemTileState extends State<HistoryItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String char = (widget.item['nama_pasien'] ?? 'T').trim().isNotEmpty
        ? (widget.item['nama_pasien'] ?? 'T').trim().substring(0, 1).toUpperCase()
        : 'T';
    const List<Color> premiumColors = [
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFF14B8A6),
    ];
    final Color avatarColor = premiumColors[char.codeUnitAt(0) % premiumColors.length];

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (widget.index * 100)),
      curve: Curves.easeOut,
      builder: (context, animVal, child) {
        return Transform.translate(
          offset: Offset(0, 15 * (1 - animVal)),
          child: Opacity(
            opacity: animVal,
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.grey.withOpacity(0.04) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          transform: Matrix4.identity()..translate(_isHovered ? 4.0 : 0.0, 0.0),
          child: ListTile(
            onTap: widget.onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                char,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: avatarColor,
                ),
              ),
            ),
            title: Text(widget.item['nama_pasien'] ?? 'Tanpa Nama',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  "${widget.item['jenis_mri']} • ${widget.item['hasil_prediksi']}",
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            trailing: widget.isMobile
                ? null
                : PoppinsTextView(
                    value: widget.item['tanggal_periksa'],
                    fontSize: 13,
                    color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}
