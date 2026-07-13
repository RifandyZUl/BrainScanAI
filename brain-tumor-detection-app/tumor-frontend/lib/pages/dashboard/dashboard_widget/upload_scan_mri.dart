import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:axon_vision/controllers/dashboard_controller.dart';
import 'package:axon_vision/models/data_pasien_model.dart';
import 'package:axon_vision/pages/global_widgets/custom/custom_flat_button.dart';
import 'package:axon_vision/pages/global_widgets/text_fonts/poppins_text_view.dart';
import 'package:axon_vision/utils/api_config.dart';
import 'package:axon_vision/utils/app_colors.dart';
import 'package:axon_vision/utils/size_config.dart';
import 'package:axon_vision/utils/space_sizer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class UploadScanMri extends StatefulWidget {
  const UploadScanMri({
    super.key,
    required this.dashboardController,
    required this.pasienData,
    required this.onBack,
  });

  final DashboardController dashboardController;
  final DataPasienModel pasienData;
  final VoidCallback onBack;

  @override
  State<UploadScanMri> createState() => _UploadScanMriState();
}

class _UploadScanMriState extends State<UploadScanMri> {
  PlatformFile? pickedFile;
  String selectedMriType = 'T1 Weighted';
  String _selectedModel = 'optimisasi'; // default: CKD-TransBTS L5
  bool isHovering = false;

  TextEditingController catatanController = TextEditingController();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        pickedFile = result.files.first;
      });
    }
  }

  Future<void> _uploadToBackend() async {
    if (pickedFile == null) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final box = GetStorage();
      String? token = box.read('token');

      // Pakai ApiConfig.baseUrl agar benar di mode release maupun debug
      var uri = Uri.parse('${ApiConfig.baseUrl}/upload-mri/');

      var request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['nama'] = widget.pasienData.namePatient;
      request.fields['id_pasien'] = widget.pasienData.idPatient;
      request.fields['tgl_lahir'] = widget.pasienData.tanggalLahir;
      request.fields['status'] = widget.pasienData.status;
      request.fields['jenis_mri'] = selectedMriType;
      request.fields['catatan'] = catatanController.text.isEmpty
          ? "Radiolog tidak menambahkan catatan"
          : catatanController.text;
      request.fields['model_type'] = _selectedModel;

      if (pickedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            pickedFile!.bytes!,
            filename: pickedFile!.name,
          ),
        );
      } else if (pickedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', pickedFile!.path!),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      Get.back(); // Tutup Loading

      if (response.statusCode == 200) {
        // Parse scan_id dari response untuk progress tracking
        try {
          final body = jsonDecode(response.body);
          final scanId = body['scan_id'];
          if (scanId != null) {
            _showProgressDialog(scanId, _selectedModel);
          } else {
            _showSuccessDialog();
          }
        } catch (_) {
          _showSuccessDialog();
        }
      } else {
        Get.snackbar("Gagal", "Server menolak: ${response.statusCode}\nDetail: ${response.body}");
      }
    } catch (e) {
      Get.back(); // Tutup Loading
      Get.snackbar("Error Koneksi", "Pastikan Backend sudah nyala!\nError: $e");
    }
  }

  // ── PROGRESS TRACKING ──
  Timer? _pollTimer;
  
  void _showProgressDialog(int scanId, String modelType) {
    final progressNotifier = ValueNotifier<double>(0.02);
    final messageNotifier = ValueNotifier<String>('Berkas diterima, antri untuk diproses...');
    final statusNotifier = ValueNotifier<String>('uploaded');

    double targetProgress = 0.02;
    Timer? progressSmoothTimer;

    // Ticker untuk pergerakan halus (Cepat s.d 50%, lalu asimtotik merayap menyesuaikan durasi model)
    progressSmoothTimer = Timer.periodic(const Duration(milliseconds: 50), (smoothTimer) {
      if (statusNotifier.value == 'failed') {
        smoothTimer.cancel();
        return;
      }
      
      double current = progressNotifier.value;
      if (targetProgress >= 0.99) {
        // Backend selesai! Tarik progress bar dengan cepat ke 100%
        double step = (1.0 - current) / 8.0;
        if (step < 0.015) step = 0.015;
        progressNotifier.value = (current + step).clamp(0.0, 1.0);
      } else {
        if (current < 0.50) {
          // Fase 1: Jalan stabil dan cepat dari awal hingga 50%
          // L5 mencapai 50% dalam ~3 detik, Paper mencapai 50% dalam ~6 detik
          double speed = modelType == 'paper' ? 0.0041 : 0.0083;
          progressNotifier.value = (current + speed).clamp(0.0, 0.50);
        } else {
          // Fase 2: Di atas 50%
          if (modelType == 'paper') {
            // Model Paper: Lebih lambat lagi dari optimisasi
            double limit = 0.995;
            double remaining = limit - current;
            if (remaining > 0) {
              double divider;
              if (current < 0.75) {
                divider = 2000.0;
              } else if (current < 0.85) {
                divider = 4000.0;
              } else {
                divider = 7000.0;
              }
              
              double creepStep = remaining / divider;
              if (creepStep < 0.00001) creepStep = 0.00001; // langkah minimum super kecil
              progressNotifier.value = (current + creepStep).clamp(0.0, 0.99);
            }
          } else {
            // Model L5/Optimisasi: Disamakan dengan kecepatan Model Paper sebelumnya
            double limit = 0.995;
            double remaining = limit - current;
            if (remaining > 0) {
              double divider;
              if (current < 0.75) {
                divider = 700.0;
              } else if (current < 0.85) {
                divider = 1300.0;
              } else {
                divider = 2200.0;
              }
              
              double creepStep = remaining / divider;
              if (creepStep < 0.00002) creepStep = 0.00002;
              progressNotifier.value = (current + creepStep).clamp(0.0, 0.99);
            }
          }
        }
      }

      // Selesai sepenuhnya
      if (targetProgress >= 0.99 && progressNotifier.value >= 0.995) {
        smoothTimer.cancel();
        Get.back(); // Tutup progress dialog
        _showSuccessDialog();
      }
    });

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final resp = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/scan/$scanId/status'),
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final progress = (data['progress'] ?? 0) / 100.0;
          final message = data['message'] ?? '';
          final status = data['status'] ?? 'uploaded';

          targetProgress = progress.clamp(0.0, 1.0);
          messageNotifier.value = message;
          statusNotifier.value = status;

          if (data['is_complete'] == true) {
            timer.cancel();
            targetProgress = 1.0;
          } else if (data['is_failed'] == true) {
            timer.cancel();
            progressSmoothTimer?.cancel();
            progressNotifier.value = 0.0;
            messageNotifier.value = data['message'] ?? 'Proses gagal';
            statusNotifier.value = 'failed';
          }
        }
      } catch (_) {
        // Polling failure — skip silently, will retry next tick
      }
    });

    Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology_rounded, color: Color(0xFF1565C0), size: 52),
                const SizedBox(height: 16),
                PoppinsTextView(
                  value: 'Proses AI Sedang Berjalan',
                  fontWeight: FontWeight.bold,
                  size: 18,
                  color: AppColors.blueDark,
                ),
                const SizedBox(height: 20),
                // Progress bar
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (_, value, __) {
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF1565C0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(value * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Status message
                ValueListenableBuilder<String>(
                  valueListenable: messageNotifier,
                  builder: (_, msg, __) {
                    return Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Failed state button
                ValueListenableBuilder<String>(
                  valueListenable: statusNotifier,
                  builder: (_, status, __) {
                    if (status == 'failed') {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton(
                          onPressed: () {
                            _pollTimer?.cancel();
                            progressSmoothTimer?.cancel();
                            Get.back();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: PoppinsTextView(
                            value: 'Tutup',
                            fontWeight: FontWeight.w600,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    catatanController.dispose();
    super.dispose();
  }

  // LOGIKA POPUP
  void _showSuccessDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 10,
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 80,
              ),
              const SizedBox(height: 20),
              PoppinsTextView(
                value: "Berhasil Dikirim",
                fontWeight: FontWeight.bold,
                size: 22,
                color: AppColors.blueDark,
              ),
              const SizedBox(height: 10),
              PoppinsTextView(
                value:
                    "File MRI sedang dalam antrean analisis AI.\nAnda akan menerima notifikasi saat hasil siap.",
                textAlign: TextAlign.center,
                size: 14,
                color: AppColors.grey,
                height: 1.5,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    widget.dashboardController.backToPasienList();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: PoppinsTextView(
                    value: "Selesai",
                    fontWeight: FontWeight.w600,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _handleBackNavigation() {
    if (pickedFile != null) {
      Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 20),
                PoppinsTextView(
                  value: "Batalkan Upload?",
                  fontWeight: FontWeight.bold,
                  size: 22,
                  color: Colors.black87,
                ),
                const SizedBox(height: 10),
                PoppinsTextView(
                  value:
                      "Anda memiliki file yang belum dikirim.\nJika kembali sekarang, data ini akan hilang.",
                  textAlign: TextAlign.center,
                  size: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.greyDisabled),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: PoppinsTextView(
                          value: "Lanjutkan Edit",
                          color: AppColors.grey,
                          fontWeight: FontWeight.w600,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          widget.onBack();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: PoppinsTextView(
                          value: "Ya, Batalkan",
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );
    } else {
      widget.onBack();
    }
  }

  Widget _buildMiniInfo(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PoppinsTextView(value: label, color: AppColors.grey, size: 12),
        PoppinsTextView(value: value, fontWeight: FontWeight.w600, size: 13),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isActive = status.toLowerCase() == 'aktif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive ? Colors.green : Colors.red,
          width: 0.5,
        ),
      ),
      child: PoppinsTextView(
        value: status,
        size: 11,
        fontWeight: FontWeight.bold,
        color: isActive ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: _handleBackNavigation,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: AppColors.grey,
                ),
              ),
            ),
            SpaceSizer(horizontal: 1),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsTextView(
                  value: 'Upload Scan MRI',
                  size: SizeConfig.safeBlockHorizontal * 1.2,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blueDark,
                ),
                PoppinsTextView(
                  value: 'Pastikan file dalam format DICOM atau High-Res JPG',
                  size: SizeConfig.safeBlockHorizontal * 0.8,
                  color: AppColors.grey,
                ),
              ],
            ),
          ],
        ),
        SpaceSizer(vertical: 3),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(SizeConfig.horizontal(1.5)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.greyDisabled),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: AppColors.blueDark,
                              size: 40,
                            ),
                            SpaceSizer(horizontal: 1),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PoppinsTextView(
                                  value: widget.pasienData.namePatient,
                                  fontWeight: FontWeight.bold,
                                  size: SizeConfig.safeBlockHorizontal * 0.9,
                                ),
                                PoppinsTextView(
                                  value: 'ID: ${widget.pasienData.idPatient}',
                                  color: AppColors.grey,
                                  size: SizeConfig.safeBlockHorizontal * 0.75,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Divider(
                          height: SizeConfig.vertical(3),
                          color: AppColors.greyDisabled,
                        ),
                        _buildMiniInfo(
                          'Tanggal Lahir',
                          widget.pasienData.tanggalLahir,
                        ),
                        SpaceSizer(vertical: 1.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PoppinsTextView(
                              value: 'Status Pasien',
                              color: AppColors.grey,
                              size: 12,
                            ),
                            _buildStatusBadge(widget.pasienData.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SpaceSizer(vertical: 2),

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(SizeConfig.horizontal(1.5)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.greyDisabled),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsTextView(
                          value: 'Detail Pemeriksaan',
                          fontWeight: FontWeight.w600,
                          size: SizeConfig.safeBlockHorizontal * 0.9,
                        ),
                        SpaceSizer(vertical: 2),

                        PoppinsTextView(
                          value: 'Jenis Sequence',
                          size: 12,
                          color: AppColors.grey,
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.greyDisabled),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedMriType,
                              isExpanded: true,
                              items:
                                  [
                                        'T1 Weighted',
                                        'T2 Weighted',
                                        'FLAIR',
                                        'Disfussion',
                                      ]
                                      .map(
                                        (String value) => DropdownMenuItem(
                                          value: value,
                                          child: PoppinsTextView(
                                            value: value,
                                            size: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedMriType = v!),
                            ),
                          ),
                        ),
                        SpaceSizer(vertical: 2),

                        PoppinsTextView(
                          value: 'Catatan Teknis (Opsional)',
                          size: 12,
                          color: AppColors.grey,
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: catatanController,
                          decoration: InputDecoration(
                            hintText: 'Misal: Pasien bergerak, Kontras 5ml...',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: AppColors.greySecond.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          maxLines: 3,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        SpaceSizer(vertical: 2),

                        // --- Pilihan Model AI ---
                        PoppinsTextView(
                          value: 'Model AI',
                          size: 12,
                          color: AppColors.grey,
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.greyDisabled),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedModel,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'optimisasi',
                                  child: Text('CKD-TransBTS Optimisasi (L5)'),
                                ),
                                DropdownMenuItem(
                                  value: 'paper',
                                  child: Text('CKD-TransBTS Paper'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedModel = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SpaceSizer(horizontal: 3),

            Expanded(
              flex: 6,
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickFile,
                    onHover: (val) => setState(() => isHovering = val),
                    child: CustomPaint(
                      painter: DottedBorderPainter(
                        color: isHovering ? AppColors.blueDark : AppColors.grey,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: SizeConfig.safeBlockVertical * 55,
                        decoration: BoxDecoration(
                          color: isHovering
                              ? AppColors.blueCard.withOpacity(0.05)
                              : AppColors.greySecond.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: pickedFile == null
                            ? _buildEmptyState()
                            : _buildSelectedState(),
                      ),
                    ),
                  ),
                  SpaceSizer(vertical: 3),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CustomFlatButton(
                        text: 'Batalkan',
                        onTap: _handleBackNavigation,
                        width: SizeConfig.blockSizeHorizontal * 8,
                        height: SizeConfig.safeBlockVertical * 6.0,
                        backgroundColor: Colors.white,
                        borderColor: AppColors.grey,
                        textColor: AppColors.grey,
                        radius: 0.8,
                        textSize: SizeConfig.safeBlockHorizontal * 0.75,
                      ),
                      SpaceSizer(horizontal: 2),

                      CustomFlatButton(
                        text: 'Mulai Analisis',
                        onTap: () {
                          if (pickedFile != null) {
                            _uploadToBackend();
                          } else {
                            Get.snackbar(
                              "Belum ada file",
                              "Harap pilih file MRI terlebih dahulu!",
                              backgroundColor: Colors.redAccent,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.TOP,
                              margin: EdgeInsets.all(20),
                            );
                          }
                        },
                        width: SizeConfig.blockSizeHorizontal * 12,
                        height: SizeConfig.safeBlockVertical * 6.0,
                        backgroundColor: pickedFile != null
                            ? AppColors.blueDark
                            : AppColors.greyDisabled,
                        textColor: Colors.white,
                        radius: 0.8,
                        textSize: SizeConfig.safeBlockHorizontal * 0.75,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_rounded,
          size: SizeConfig.safeBlockHorizontal * 4,
          color: AppColors.blueDark,
        ),
        SpaceSizer(vertical: 2),
        PoppinsTextView(
          value: 'Klik untuk Pilih File MRI',
          size: SizeConfig.safeBlockHorizontal * 1.1,
          fontWeight: FontWeight.bold,
          color: AppColors.black,
        ),
        SpaceSizer(vertical: 1),
        PoppinsTextView(
          value: 'Format: JPG, PNG, JPEG, DICOM, NII, GZ',
          size: SizeConfig.safeBlockHorizontal * 0.8,
          color: AppColors.grey,
        ),
      ],
    );
  }

  Widget _buildSelectedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.insert_drive_file, size: 60, color: AppColors.blueDark),
        SpaceSizer(vertical: 2),
        PoppinsTextView(
          value: pickedFile!.name,
          size: SizeConfig.safeBlockHorizontal * 1.0,
          fontWeight: FontWeight.bold,
        ),
        PoppinsTextView(
          value:
              '${(pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB • Siap Upload',
          size: SizeConfig.safeBlockHorizontal * 0.8,
          color: Colors.green,
        ),
        SpaceSizer(vertical: 2),
        TextButton.icon(
          onPressed: () => setState(() => pickedFile = null),
          icon: Icon(Icons.close, color: Colors.red, size: 18),
          label: PoppinsTextView(
            value: 'Ganti File',
            color: Colors.red,
            size: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class DottedBorderPainter extends CustomPainter {
  final Color color;
  DottedBorderPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final double dashWidth = 8, dashSpace = 6, radius = 16;
    Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );
    Path dashPath = Path();
    double distance = 0.0;
    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
