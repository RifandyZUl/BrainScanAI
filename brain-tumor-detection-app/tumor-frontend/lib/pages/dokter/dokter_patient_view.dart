import 'package:axon_vision/controllers/dokter_controller.dart';
import 'package:axon_vision/pages/detail_analisis_page.dart';
import 'package:axon_vision/utils/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

const String brainSvg = r'''<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36">
	<path d="M0 0h36v36H0z" fill="none" />
	<path fill="#ea596e" d="M29.896 26.667c.003.283-.07.653-.146.958c-.531 2.145-2.889 4.552-6.208 4.333c-3.008-.198-5.458-1.642-5.458-3.667s2.444-3.667 5.458-3.667s6.335.018 6.354 2.043" />
	<path fill="#dd2e44" d="M23.542 24.964c-1.619 0-5.314.448-6.162.448c-1.498 0-2.713.94-2.713 2.1c0 .558.286 1.062.744 1.438c0 0 1.006 1.009 2.818.525c.793-.212 2.083-1.786 4.354-2.036c1.131-.125 3.25.75 6.974.771c.16-.344.193-.583.193-.583c0-2.027-3.194-2.663-6.208-2.663" />
	<path fill="#f4abba" d="M29.75 27.625s2.184-.443 3.542-2.229c1.583-2.083 1.375-4.312 1.375-4.312c1.604-3-.5-5.813-.5-5.813C33.958 12.104 32 10.792 32 10.792c-1.271-3.021-4.083-3.833-4.083-3.833c-2.208-2.583-6.125-2.5-6.125-2.5s-3.67-1.345-8.708.167c-.833.25-3.625.833-5.667 2.083C.981 10.649.494 16.793.584 17.792C1.083 23.375 5 24.375 7.5 24.958c.583 1.583 2.729 4.5 6.583 3.417c4.75-.833 6.75-2.25 7.917-2.25s4.417 1.25 7.75 1.5" />
	<g fill="#ea596e">
		<path d="M17.737 18.648c2.328-1.255 3.59-1.138 4.704-1.037c.354.032.689.057 1.028.055c1.984-.045 3.591-.881 4.302-1.69a.501.501 0 0 0-.752-.661c-.548.624-1.899 1.313-3.573 1.351c-.3.009-.601-.021-.913-.05c-1.195-.111-2.679-.247-5.271 1.152c-.665.359-1.577.492-2.565.592c-2.197-3.171-.875-5.933-.497-6.591c.037.002.073.014.111.014c.4 0 .802-.098 1.166-.304a.5.5 0 0 0-.492-.87a1.426 1.426 0 0 1-1.88-.467a.5.5 0 0 0-.841.539c.237.371.571.65.948.837c-.521 1.058-1.51 3.84.372 6.951c-1.324.13-2.65.317-3.688.986a7.2 7.2 0 0 0-1.878 1.791c-.629-.108-2.932-.675-3.334-3.231c.25-.194.452-.45.577-.766a.5.5 0 1 0-.93-.368a.77.77 0 0 1-.454.461a.78.78 0 0 1-.643-.07a.5.5 0 0 0-.486.874c.284.158.588.238.89.238c.037 0 .072-.017.109-.019c.476 2.413 2.383 3.473 3.732 3.794a3.7 3.7 0 0 0-.331 1.192a.5.5 0 0 0 .454.542l.045.002a.5.5 0 0 0 .498-.456c.108-1.213 1.265-2.48 2.293-3.145c.964-.621 2.375-.752 3.741-.879c1.325-.121 2.577-.237 3.558-.767m12.866-1.504a.5.5 0 0 0 .878.48c.019-.034 1.842-3.449-1.571-5.744a.5.5 0 0 0-.558.83c2.644 1.778 1.309 4.326 1.251 4.434M9.876 9.07a.5.5 0 0 0 .406-.208c1.45-2.017 3.458-1.327 3.543-1.295a.5.5 0 0 0 .345-.938c-.96-.356-3.177-.468-4.7 1.65a.5.5 0 0 0 .406.791m13.072-1.888c2.225-.181 3.237 1.432 3.283 1.508a.5.5 0 0 0 .863-.507c-.054-.091-1.34-2.218-4.224-1.998a.5.5 0 0 0 .078.997m9.15 14.611c-.246-.014-.517.181-.539.457c-.002.018-.161 1.719-1.91 2.294a.499.499 0 0 0 .157.975a.5.5 0 0 0 .156-.025c2.372-.778 2.586-3.064 2.594-3.161a.5.5 0 0 0-.458-.54" />
		<path d="M7.347 16.934a.5.5 0 1 0 .965.26a1.423 1.423 0 0 1 1.652-1.014a.5.5 0 0 0 .205-.979a2.35 2.35 0 0 0-1.248.086c-1.166-1.994-.939-3.96-.936-3.981a.5.5 0 0 0-.429-.562a.503.503 0 0 0-.562.427c-.013.097-.28 2.316 1.063 4.614a2.4 2.4 0 0 0-.71 1.149m11.179-2.47a1.07 1.07 0 0 1 1.455.015a.5.5 0 0 0 .707-.011a.5.5 0 0 0-.01-.707a2 2 0 0 0-.797-.465c.296-1.016.179-1.467-.096-2.312a21 21 0 0 1-.157-.498l-.03-.1c-.364-1.208-.605-2.005.087-3.13a.5.5 0 0 0-.852-.524c-.928 1.508-.587 2.637-.192 3.944l.03.1q.088.29.163.517c.247.761.322 1.016.02 1.936a2 2 0 0 0-1.01.504a.5.5 0 0 0 .682.731m6.365-2.985a2 2 0 0 0 .859-.191a.5.5 0 0 0-.426-.905a1.07 1.07 0 0 1-1.384-.457a.5.5 0 1 0-.881.472c.18.336.448.601.76.785c-.537 1.305-.232 2.691.017 3.426a.5.5 0 1 0 .947-.319c-.168-.498-.494-1.756-.002-2.826c.038.002.073.015.11.015m4.797 9.429a.497.497 0 0 0-.531-.467a1.825 1.825 0 0 1-1.947-1.703a.51.51 0 0 0-.533-.465a.5.5 0 0 0-.465.533c.041.59.266 1.122.608 1.555c-.804.946-1.857 1.215-2.444 1.284c-.519.062-.973.009-1.498-.053c-.481-.055-1.025-.118-1.698-.098l-.005.001c-.02-.286-.088-.703-.305-1.05a.501.501 0 0 0-.847.531c.134.215.159.558.159.725c-.504.181-.94.447-1.334.704c-.704.458-1.259.82-2.094.632c-.756-.173-1.513-.208-2.155-.118c-.1-.251-.258-.551-.502-.782a.5.5 0 0 0-.687.727c.086.081.154.199.209.317c-1.103.454-1.656 1.213-1.682 1.25a.499.499 0 0 0 .407.788a.5.5 0 0 0 .406-.205c.005-.008.554-.743 1.637-1.04c.56-.154 1.363-.141 2.146.037c.219.05.422.067.619.07c.093.218.129.477.134.573a.5.5 0 0 0 .499.472l.027-.001a.5.5 0 0 0 .473-.523a3 3 0 0 0-.13-.686c.461-.167.862-.428 1.239-.673c.572-.373 1.113-.726 1.82-.749c.592-.021 1.08.036 1.551.091c.474.055.94.091 1.454.061c.091.253.084.591.07.704a.503.503 0 0 0 .497.563a.5.5 0 0 0 .495-.435a2.9 2.9 0 0 0-.059-.981a4.67 4.67 0 0 0 2.345-1.471a2.8 2.8 0 0 0 1.656.413a.5.5 0 0 0 .465-.531" />
	</g>
</svg>''';

class DokterPatientView extends GetView<DokterController> {
  const DokterPatientView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.patientViewStep.value == 0) {
        controller.fetchPatients();
      }
    });

    final Color tealColor = const Color(0xFF0E616B);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 650;

        return Obx(() {
          switch (controller.patientViewStep.value) {
            case 0:
              return _buildPatientListView(context, isMobile, tealColor);
            case 1:
              return _buildPatientDetailView(context, isMobile, tealColor);
            case 2:
              return DetailAnalisisPage(
                analysisId: controller.selectedAnalysisId.value,
                role: "DOKTER",
              );
            default:
              return _buildPatientListView(context, isMobile, tealColor);
          }
        });
      },
    );
  }

  // ==========================================================================
  // 1. DAFTAR PASIEN REDESIGN (MODERN ROW LIST TABLE)
  // ==========================================================================
  Widget _buildPatientListView(BuildContext context, bool isMobile, Color tealColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pilih pasien untuk melihat detail atau riwayat analisis AI.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),

        // Search Bar & Refresh
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (val) => controller.searchPatient(val),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 18),
                      hintText: "Cari Nama atau ID Pasien...",
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                      filled: true,
                      fillColor: const Color(0xffF8F9FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => controller.fetchPatients(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                  label: Text(
                    "Refresh",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Modern Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[100]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.filteredPatientList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        "Data pasien tidak ditemukan",
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, animVal, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - animVal)),
                    child: Opacity(
                      opacity: animVal.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    // Header Tabel
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: _headerTabel("ID REKAM MEDIS")),
                          Expanded(flex: 3, child: _headerTabel("NAMA PASIEN")),
                          if (!isMobile) Expanded(flex: 2, child: _headerTabel("GENDER")),
                          if (!isMobile) Expanded(flex: 2, child: _headerTabel("TGL LAHIR")),
                          Expanded(flex: 2, child: _headerTabel("STATUS")),
                          Expanded(flex: 1, child: Center(child: _headerTabel("AKSI"))),
                        ],
                      ),
                    ),

                    // Isi Tabel
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: controller.currentPatients.length,
                        itemBuilder: (context, index) {
                          final p = controller.currentPatients[index];
                          return PatientRowTile(
                            patient: p,
                            index: index,
                            isMobile: isMobile,
                            onTap: () => controller.openPatientDetail(p),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        // Pagination
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, -4),
              )
            ],
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(() => Text(
                    "Halaman ${controller.patientCurrentPage} dari ${controller.totalPatientPages} (Total ${controller.filteredPatientList.length})",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  )),
              Row(
                children: [
                  IconButton(
                    onPressed: () => controller.prevPatientPage(),
                    icon: Icon(Icons.chevron_left_rounded, size: 20, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Obx(() => Text(
                          "${controller.patientCurrentPage}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        )),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => controller.nextPatientPage(),
                    icon: Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[600]),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 2. DETAIL PASIEN & RIWAYAT SCAN (DOKTER)
  // ==========================================================================
  Widget _buildPatientDetailView(BuildContext context, bool isMobile, Color tealColor) {
    final p = controller.selectedPatient.value!;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, animVal, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animVal)),
          child: Opacity(
            opacity: animVal.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => controller.backToPreviousStep(),
              icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[600], size: 16),
              label: Text(
                "Kembali ke Daftar Pasien",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Detail Pasien Card
            Container(
              padding: const EdgeInsets.all(28),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: tealColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p.nama.trim().isNotEmpty ? p.nama.trim().substring(0, 1).toUpperCase() : 'P',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nama,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.idPasienRs,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusLabel(p.statusPasien),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFF1F3F5)),
                  const SizedBox(height: 24),
                  if (isMobile)
                    Column(
                      children: [
                        _detailRow("ID Rekam Medis", p.idPasienRs),
                        const SizedBox(height: 12),
                        _detailRow("Jenis Kelamin", p.jenisKelamin),
                        const SizedBox(height: 12),
                        _detailRow("Tanggal Lahir", p.tanggalLahir),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: _detailRow("ID Rekam Medis", p.idPasienRs)),
                        Expanded(child: _detailRow("Jenis Kelamin", p.jenisKelamin)),
                        Expanded(child: _detailRow("Tanggal Lahir", p.tanggalLahir)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bagian Header Riwayat Scan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Riwayat Scan MRI",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Obx(() {
                      bool isFiltered = controller.selectedDateFilter.value != null;
                      return IconButton(
                        icon: Icon(
                          isFiltered ? Icons.event_busy_rounded : Icons.calendar_today_rounded,
                          color: isFiltered ? Colors.redAccent : Colors.grey[600],
                          size: 18,
                        ),
                        tooltip: isFiltered ? "Hapus Filter Tanggal" : "Filter Tanggal",
                        onPressed: () async {
                          if (isFiltered) {
                            controller.clearDateFilter();
                          } else {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: tealColor,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black87,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (pickedDate != null) {
                              controller.filterHistoryByDate(pickedDate);
                            }
                          }
                        },
                      );
                    }),
                    const SizedBox(width: 8),
                    Obx(() => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!, width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: controller.isSortNewest.value ? 'Terbaru' : 'Terlama',
                              icon: Icon(Icons.sort_rounded, size: 14, color: Colors.grey[600]),
                              items: ['Terbaru', 'Terlama'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  controller.sortHistory(newValue);
                                }
                              },
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // List Riwayat Scan
            Obx(() {
              final history = controller.sortedPatientHistory;
              if (history.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[100]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        "Belum ada riwayat scan MRI",
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final scan = history[index];
                  return HistoryScanItemTile(
                    scan: scan,
                    onTap: () => controller.openAnalysisResult(scan['id'].toString()),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HELPER WIDGETS
  // ==========================================================================
  Widget _buildStatusLabel(String status) {
    bool isActive = status.toLowerCase() == "aktif";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? "AKTIF" : "NONAKTIF",
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        const Text(": ", style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerTabel(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
      ),
    );
  }
}

// ==========================================================================
// STATEFUL PATIENT ROW WITH ALTERNATING COLORS AND HOVER GLOW
// ==========================================================================
class PatientRowTile extends StatefulWidget {
  final dynamic patient;
  final int index;
  final bool isMobile;
  final VoidCallback onTap;

  const PatientRowTile({
    super.key,
    required this.patient,
    required this.index,
    required this.isMobile,
    required this.onTap,
  });

  @override
  State<PatientRowTile> createState() => _PatientRowTileState();
}

class _PatientRowTileState extends State<PatientRowTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color tealColor = const Color(0xFF0E616B);
    final bool isEven = widget.index % 2 == 0;

    Color bgColor;
    if (_isHovered) {
      bgColor = tealColor.withOpacity(0.08);
    } else {
      bgColor = isEven ? tealColor.withOpacity(0.03) : Colors.white;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: Colors.grey[100]!, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                widget.patient.idPasienRs,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tealColor,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                widget.patient.nama,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            if (!widget.isMobile)
              Expanded(
                flex: 2,
                child: Text(
                  widget.patient.jenisKelamin,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            if (!widget.isMobile)
              Expanded(
                flex: 2,
                child: Text(
                  widget.patient.tanggalLahir,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: _buildStatusBadge(widget.patient.statusPasien),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: AnimatedScale(
                  scale: _isHovered ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.visibility_rounded, // Eye icon to inspect/view patient details
                      color: _isHovered ? tealColor : Colors.grey[500],
                      size: 20,
                    ),
                    tooltip: "Lihat Detail & Rekam Medis",
                    onPressed: widget.onTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isActive = status.toLowerCase() == "aktif";
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isActive ? "AKTIF" : "NONAKTIF",
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
          ),
        ),
      ),
    );
  }
}

class HistoryScanItemTile extends StatefulWidget {
  final Map<String, dynamic> scan;
  final VoidCallback onTap;

  const HistoryScanItemTile({
    super.key,
    required this.scan,
    required this.onTap,
  });

  @override
  State<HistoryScanItemTile> createState() => _HistoryScanItemTileState();
}

class _HistoryScanItemTileState extends State<HistoryScanItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String hasil = widget.scan['hasil_prediksi'].toString().toLowerCase();
    bool isNormal = hasil.contains("non") || hasil.contains("normal") || hasil.contains("aman");
    bool isProcessing = hasil.contains("analisis");
    bool isFailed = hasil.contains("gagal");

    Color badgeColor = isNormal
        ? const Color(0xFFD1FAE5)
        : (isFailed ? Colors.grey[200]! : const Color(0xFFFEE2E2));
    Color textColor = isNormal
        ? const Color(0xFF065F46)
        : (isFailed ? Colors.grey[700]! : const Color(0xFF991B1B));


    // Dynamic Image URL
    String imageUrl = "${ApiConfig.baseUrl}/analisis/${widget.scan['id']}/slice?axis=2&idx=75";

    // Complaints text
    String keluhan = widget.scan['catatan_teknis'] ?? "";
    bool hasKeluhan = keluhan.isNotEmpty &&
        keluhan != "-" &&
        !keluhan.toLowerCase().contains("tidak menambahkan catatan") &&
        !keluhan.toLowerCase().contains("belum ada catatan");

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Stack(
        children: [
          // 1. Timeline vertical line
          Positioned(
            left: 15,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: const Color(0xFF92D0C6).withOpacity(0.4),
            ),
          ),
          
          // 2. Timeline circle node
          Positioned(
            left: 8,
            top: 32, // Aligned with the header icon center of the card
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF30E3CA),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF30E3CA),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          
          // 3. Card content (wrapped with padding to clear the timeline)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered ? const Color(0xFF30E3CA).withOpacity(0.5) : const Color(0xFFE2F0ED),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? const Color(0xFF0E616B).withOpacity(0.04)
                        : Colors.black.withOpacity(0.01),
                    blurRadius: _isHovered ? 12 : 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    hoverColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2F0ED),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SvgPicture.string(
                                  brainSvg,
                                  width: 22,
                                  height: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.scan['jenis_mri'] ?? "MRI Otak",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Tanggal: ${widget.scan['tanggal_periksa']}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Hasil Prediksi",
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      widget.scan['hasil_prediksi'] ?? "Normal",
                                      style: GoogleFonts.poppins(
                                        color: textColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Nested MRI Image & Complaint Area
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F8F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE6EFEF),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // MRI Scan Image Slice
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    color: Colors.black,
                                    child: isProcessing
                                        ? const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                        Color(0xFF30E3CA)),
                                              ),
                                            ),
                                          )
                                        : isFailed
                                            ? const Center(
                                                child: Icon(
                                                  Icons.broken_image_rounded,
                                                  color: Colors.redAccent,
                                                  size: 28,
                                                ),
                                              )
                                            : Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return const Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.0,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                                Color(
                                                                    0xFF30E3CA)),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Center(
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_rounded,
                                                      color: Colors.grey,
                                                      size: 24,
                                                    ),
                                                  );
                                                },
                                              ),
                                  ),
                                ),
                                
                                // Complaints (Keluhan Penyakit)
                                if (hasKeluhan) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Keluhan Penyakit",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          keluhan,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[700],
                                            height: 1.4,
                                          ),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Action row
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Action",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF0E616B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Color(0xFF0E616B),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
