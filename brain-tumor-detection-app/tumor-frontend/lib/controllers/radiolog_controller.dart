import 'dart:convert';
import 'dart:math';
import 'package:axon_vision/models/patient_model.dart';
import 'package:axon_vision/pages/login/login_page.dart';
import 'package:axon_vision/utils/api_config.dart';
import 'package:axon_vision/controllers/notification_controller.dart';
import 'package:axon_vision/helpers/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:axon_vision/pages/global_widgets/text_fonts/poppins_text_view.dart';
import 'package:axon_vision/utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class RadiologController extends GetxController {
  final box = GetStorage();

  Timer? _pollingTimer;
  Timer? _uploadPollTimer;

  // Variabel Data
  var activeIndex = 0.obs;
  var isSidebarExpanded = true.obs;
  var patientViewStep = 0.obs;
  var detailAnalysisData = {}.obs;
  var isLoadingDetail = false.obs;
  var isLoading = false.obs;
  var selectedAnalysisId = "".obs;
  var isSortNewest = true.obs;
  var selectedDateFilter = Rxn<DateTime>();

  // Data Profil
  var displayName = 'Radiolog'.obs;
  var displayRole = 'Radiologist'.obs;
  var profileImageUrl = "".obs;
  var currentUserId = 0.obs;

  // Data Dashboard
  var dashboardSummary =
      {"total_pasien": 0, "total_menunggu": 0, "total_selesai": 0}.obs;
  var riwayatScanList = <dynamic>[].obs;
  var selectedPatient = Rxn<PatientModel>();

  var notificationsList = <dynamic>[].obs;
  var unreadNotifCount = 0.obs;

  // Pagination & Data Pasien
  var allPatientList = <PatientModel>[].obs;
  var filteredPatientList = <PatientModel>[].obs;
  var patientCurrentPage = 1.obs;
  var itemsPerPage = 9;

  List<PatientModel> get currentPatients {
    if (filteredPatientList.isEmpty) return [];
    int start = (patientCurrentPage.value - 1) * itemsPerPage;
    int end = start + itemsPerPage;
    return filteredPatientList.sublist(
        start, min(end, filteredPatientList.length));
  }

  int get totalPatientPages {
    if (filteredPatientList.isEmpty) return 1;
    return (filteredPatientList.length / itemsPerPage).ceil();
  }

  List<dynamic> get selectedPatientHistory {
    if (selectedPatient.value == null) return [];
    return riwayatScanList.where((scan) {
      return scan['id_rm'] == selectedPatient.value!.idPasienRs;
    }).toList();
  }

  // FORM VARIABLES
  TextEditingController namaPasienC = TextEditingController();
  TextEditingController idRmC = TextEditingController();
  TextEditingController tglLahirC = TextEditingController();
  TextEditingController catatanC = TextEditingController();

  var selectedGender = "Laki-laki".obs;
  var selectedStatus = "Aktif".obs;
  var selectedJenisMRI = "T1 Weighted".obs;
  var selectedFile = Rxn<PlatformFile>();
  var selectedFileName = "".obs;
  var selectedModelType = "optimisasi".obs;

  TextEditingController myUsernameC = TextEditingController();
  TextEditingController myFullNameC = TextEditingController();
  TextEditingController oldPasswordC = TextEditingController();
  TextEditingController newPasswordC = TextEditingController();

  var isObscureOld = true.obs;
  var isObscureNew = true.obs;

  // LIFECYCLE & HELPERS
  @override
  void onInit() {
    super.onInit();
    refreshAllData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchDashboardSummary();
      fetchRiwayat();
      fetchNotifications();

      if (Get.isRegistered<NotificationController>()) {
        Get.find<NotificationController>().fetchNotifications();
      }
    });
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    _uploadPollTimer?.cancel();
    super.onClose();
  }

  void refreshAllData() {
    fetchMyProfile();
    fetchDashboardSummary();
    fetchPatients();
    fetchRiwayat();
  }

  String? getToken() {
    String? token = box.read('token');
    if (token == null) {
      Get.offAll(() => const LoginPage());
      return null;
    }
    return token;
  }

  void filterHistoryByDate(DateTime date) {
    selectedDateFilter.value = date;
  }

  void clearDateFilter() {
    selectedDateFilter.value = null;
  }

  void nextPatientPage() {
    if (patientCurrentPage.value < totalPatientPages) {
      patientCurrentPage.value++;
    }
  }

  void prevPatientPage() {
    if (patientCurrentPage.value > 1) {
      patientCurrentPage.value--;
    }
  }

  void searchPatient(String query) {
    if (query.isEmpty) {
      filteredPatientList.assignAll(allPatientList);
    } else {
      var result = allPatientList
          .where((p) =>
              p.nama.toLowerCase().contains(query.toLowerCase()) ||
              p.idPasienRs.toLowerCase().contains(query.toLowerCase()))
          .toList();
      filteredPatientList.assignAll(result);
    }
    patientCurrentPage.value = 1;
  }

  // Helper Reset Form Profil
  void clearProfileForm() {
    oldPasswordC.clear();
    newPasswordC.clear();
    isObscureOld.value = true;
    isObscureNew.value = true;
    myFullNameC.text = displayName.value;
    myUsernameC.text = box.read('username') ?? "";
  }

  void clearUploadForm() {
    selectedFile.value = null;
    selectedFileName.value = "";
    catatanC.clear();
  }

  // NAVIGASI
  void toggleSidebar() => isSidebarExpanded.toggle();

  String get currentHeaderTitle {
    if (activeIndex.value == 0) {
      return "Dashboard Overview";
    } else if (activeIndex.value == 1) {
      switch (patientViewStep.value) {
        case 0:
          return "Data Pasien";
        case 1:
        case 2:
          return "Detail & Upload MRI";
        case 3:
          return "Hasil Analisis AI";
        default:
          return "Data Pasien";
      }
    } else if (activeIndex.value == 2) {
      return "Pengaturan Profil";
    }
    return "NeuroScan AI";
  }

  void changeMenu(int index) {
    activeIndex.value = index;
    patientViewStep.value = 0;
    selectedPatient.value = null;
    if (index == 2) clearProfileForm();
  }

  void navigateToProfile() => changeMenu(2);

  void openPatientDetail(PatientModel patient) {
    selectedPatient.value = patient;
    patientViewStep.value = 1;
  }

  void openUploadPage() {
    if (selectedPatient.value == null) return;
    var p = selectedPatient.value!;
    namaPasienC.text = p.nama;
    idRmC.text = p.idPasienRs;
    tglLahirC.text = p.tanggalLahir;
    selectedGender.value = p.jenisKelamin;
    selectedStatus.value = p.statusPasien;
    clearUploadForm();
    patientViewStep.value = 2;
  }

  void openAnalysisResult(String analysisId) {
    debugPrint("[RADIOLOG DEBUG] openAnalysisResult called with ID: $analysisId");
    selectedAnalysisId.value = analysisId;
    detailAnalysisData.value = {};
    isLoadingDetail.value = true;
    patientViewStep.value = 3;
    fetchAnalysisDetail(analysisId);
  }

  void backToPreviousStep() {
    if (patientViewStep.value == 3) {
      if (selectedPatient.value == null) {
        activeIndex.value = 0;
        patientViewStep.value = 0;
      } else {
        patientViewStep.value = 1;
      }
      selectedAnalysisId.value = "";
    } else if (patientViewStep.value == 2) {
      patientViewStep.value = 1;
    } else if (patientViewStep.value == 1) {
      patientViewStep.value = 0;
      selectedPatient.value = null;
    }
  }

  void sortHistory(String order) {
    isSortNewest.value = order == 'Terbaru';
  }

  List<dynamic> get sortedPatientHistory {
    var tempList = List<dynamic>.from(selectedPatientHistory);

    if (selectedDateFilter.value != null) {
      String filterDateStr =
          DateFormat('dd/MM/yyyy').format(selectedDateFilter.value!);

      tempList = tempList.where((scan) {
        return scan['tanggal_periksa'].toString() == filterDateStr;
      }).toList();
    }

    DateTime parseDate(String dateStr) {
      try {
        var parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        return DateTime(1970);
      }
      return DateTime(1970);
    }

    tempList.sort((a, b) {
      DateTime dateA = parseDate(a['tanggal_periksa'].toString());
      DateTime dateB = parseDate(b['tanggal_periksa'].toString());

      if (isSortNewest.value) {
        return dateB.compareTo(dateA);
      } else {
        return dateA.compareTo(dateB);
      }
    });
    return tempList;
  }

  // API ACTIONS
  Future<void> fetchMyProfile() async {
    try {
      String? token = getToken();
      if (token == null) return;
      var response = await http.get(Uri.parse('${ApiConfig.baseUrl}/users/me/'),
          headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        currentUserId.value = data['id'];
        displayName.value = data['full_name'] ?? 'Radiolog';
        displayRole.value = data['role'] ?? 'Radiologist';
        myUsernameC.text = data['username'];
        myFullNameC.text = data['full_name'];
        if (data['avatar'] != null) profileImageUrl.value = data['avatar'];
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> saveProfile() async {
    if (currentUserId.value == 0) {
      SnackbarHelper.showError(
          title: "Sistem Belum Siap",
          message:
              "Data Anda belum termuat sempurna. Silakan muat ulang halaman.");
      fetchMyProfile();
      return;
    }

    if (newPasswordC.text.isNotEmpty || oldPasswordC.text.isNotEmpty) {
      if (newPasswordC.text.isEmpty || oldPasswordC.text.isEmpty) {
        SnackbarHelper.showError(
          title: "Validasi Gagal",
          message:
              "Untuk mengganti kata sandi, WAJIB mengisi Password Lama dan Password Baru.",
        );
        return;
      }
      if (oldPasswordC.text == newPasswordC.text) {
        SnackbarHelper.showError(
          title: "Password Sama",
          message: "password baru tidak boleh sama dengan password lama Anda!",
        );
        return;
      }

      String pattern =
          r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$';
      RegExp regex = RegExp(pattern);

      if (!regex.hasMatch(newPasswordC.text)) {
        SnackbarHelper.showError(
          title: "Password Terlalu Lemah",
          message:
              "Password minimal 8 karakter, wajib mengandung huruf, angka, dan simbol.",
        );
        return;
      }
    }

    try {
      isLoading.value = true;
      String? token = getToken();
      if (token == null) {
        return;
      }

      Map<String, dynamic> bodyData = {
        "username": myUsernameC.text,
        "full_name": myFullNameC.text,
        "role": displayRole.value,
      };

      if (profileImageUrl.value.isNotEmpty) {
        bodyData["avatar"] = profileImageUrl.value;
      }

      if (newPasswordC.text.isNotEmpty) {
        bodyData["password"] = newPasswordC.text;
      }

      var response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/users/${currentUserId.value}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: json.encode(bodyData));

      // 3. TANGANI RESPON API DENGAN POP-UP KITA
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 👇 INI YANG KAMU TUNGGU-TUNGGU: POPUP SUKSES 👇
        SnackbarHelper.showSuccess(
          title: "Profil Tersimpan",
          message: "Data profil atau kata sandi Anda berhasil diperbarui.",
        );
        fetchMyProfile();
        clearProfileForm();
      } else if (response.statusCode == 422) {
        debugPrint("Alasan Error 422 dari Backend: ${response.body}");
        SnackbarHelper.showError(
          title: "Gagal Disimpan",
          message: "Data ditolak oleh server. Pastikan isian Anda sudah benar.",
        );
      } else {
        SnackbarHelper.showError(
          title: "Gagal Terhubung",
          message:
              "Terjadi kesalahan server dengan status: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("Error saat saveProfile: $e");
      SnackbarHelper.showError(
          title: "Koneksi Terputus",
          message:
              "Gagal terhubung ke server. Periksa jaringan internet Anda.");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        String? token = getToken();
        var request = http.MultipartRequest(
            'POST', Uri.parse('${ApiConfig.baseUrl}/users/upload-avatar/'));
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(http.MultipartFile.fromBytes(
            'file', await image.readAsBytes(),
            filename: image.name));

        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );
        var response = await http.Response.fromStream(await request.send());

        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        await Future.delayed(const Duration(milliseconds: 300));

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          if (data['url'] != null) profileImageUrl.value = data['url'];

          SnackbarHelper.showSuccess(
            title: "Profil Diperbarui",
            message: "Foto profil Anda berhasil diperbarui.",
          );
        }
      } catch (e) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        debugPrint("Error: $e");
        await Future.delayed(const Duration(milliseconds: 300));

        SnackbarHelper.showError(
          title: "Gagal Mengunggah",
          message:
              "Pastikan ukuran gambar tidak terlalu besar atau periksa koneksi Anda.",
        );
      }
    }
  }

  Future<void> fetchDashboardSummary() async {
    try {
      String? token = getToken();
      if (token == null) return;
      var response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/dashboard-summary/'),
          headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        dashboardSummary.value = {
          "total_pasien": data['total_pasien'],
          "total_menunggu": data['total_menunggu'],
          "total_selesai": data['total_selesai'],
        };
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> fetchPatients() async {
    try {
      isLoading.value = true;
      String? token = getToken();
      var response = await http.get(Uri.parse('${ApiConfig.baseUrl}/patients/'),
          headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        var data = jsonResponse.map((e) => PatientModel.fromJson(e)).toList();

        allPatientList.assignAll(data);
        filteredPatientList.assignAll(data);
        patientCurrentPage.value = 1;
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchRiwayat() async {
    try {
      String? token = getToken();
      var response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/riwayat-semua/'),
          headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        riwayatScanList.value = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> fetchNotifications() async {
    try {
      String? token = getToken();
      if (token == null) return;

      var response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/notifications/'),
          headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        notificationsList.value = data;

        unreadNotifCount.value =
            data.where((n) => n['is_read'] == false).length;
      }
    } catch (e) {
      debugPrint("Error fetch notif: $e");
    }
  }

  Future<void> pickMRIFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['zip'], withData: true);
    if (result != null) {
      selectedFile.value = result.files.first;
      selectedFileName.value = result.files.first.name;
    }
  }

  Future<void> uploadAndAnalyze() async {
    if (selectedFile.value == null) {
      SnackbarHelper.showError(
        title: "File Kosong",
        message: "Harap pilih file zip hasil scan MRI terlebih dahulu!",
      );
      return;
    }

    try {
      isLoading.value = true;
      String? token = getToken();
      var request = http.MultipartRequest(
          'POST', Uri.parse('${ApiConfig.baseUrl}/upload-mri/'));
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['nama'] = namaPasienC.text;
      request.fields['id_pasien'] = idRmC.text;
      request.fields['tgl_lahir'] = tglLahirC.text;
      request.fields['status'] = selectedStatus.value;
      request.fields['jenis_mri'] = 'MRI Otak (4 Modalitas ZIP)';
      request.fields['catatan'] = catatanC.text.isEmpty
          ? "Radiolog tidak menambahkan catatan"
          : catatanC.text;
      request.fields['model_type'] = selectedModelType.value;

      if (selectedFile.value!.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
            'file', selectedFile.value!.bytes!,
            filename: selectedFile.value!.name));
      } else if (selectedFile.value!.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'file', selectedFile.value!.path!));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          final scanId = body['scan_id'];
          if (scanId != null) {
            _showProgressDialog(scanId, selectedModelType.value);
          } else {
            _showLegacySuccess();
          }
        } catch (_) {
          _showLegacySuccess();
        }
      } else {
        SnackbarHelper.showError(
          title: "Upload Gagal",
          message: "Sistem menolak file Anda: ${response.body}",
        );
      }
    } catch (e) {
      SnackbarHelper.showError(
        title: "Koneksi Terputus",
        message: "Gagal terhubung ke server. Periksa koneksi internet Anda.",
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _showLegacySuccess() {
    SnackbarHelper.showSuccessDialog(
        title: "MRI Berhasil Dikirim",
        description:
            "File MRI sedang diproses oleh AI. Mohon tunggu beberapa saat untuk hasil analisis.",
        onConfirm: () {
          if (dashboardSummary.containsKey('total_menunggu')) {
            dashboardSummary['total_menunggu'] =
                (dashboardSummary['total_menunggu'] ?? 0) + 1;
            dashboardSummary.refresh();
          }
          fetchRiwayat();
          clearUploadForm();
          patientViewStep.value = 1;
        });
  }

  void _showProgressDialog(int scanId, String modelType) {
    final progressNotifier = ValueNotifier<double>(0.02);
    final messageNotifier =
        ValueNotifier<String>('Berkas diterima, antri untuk diproses...');
    final statusNotifier = ValueNotifier<String>('uploaded');

    double targetProgress = 0.02;
    Timer? progressSmoothTimer;

    // Ticker untuk pergerakan halus (Cepat s.d 50%, lalu asimtotik merayap menyesuaikan durasi model)
    progressSmoothTimer =
        Timer.periodic(const Duration(milliseconds: 50), (smoothTimer) {
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
          // L5 mencapai 50% dalam ~1.5 detik, Paper mencapai 50% dalam ~3 detik
          double speed = modelType == 'paper' ? 0.0083 : 0.0167;
          progressNotifier.value = (current + speed).clamp(0.0, 0.50);
        } else {
          // Fase 2: Di atas 50%
          if (modelType == 'paper') {
            // Khusus Model Paper: Perlambatan bertingkat (50%-80% lambat, 80%-99% super lambat)
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
              if (creepStep < 0.00002) creepStep = 0.00002; // langkah minimum super kecil
              progressNotifier.value = (current + creepStep).clamp(0.0, 0.99);
            }
          } else {
            // Model L5: Merayap biasa menuju 98%
            double limit = 0.98;
            double remaining = limit - current;
            if (remaining > 0) {
              double divider = 220.0;
              double creepStep = remaining / divider;
              if (creepStep < 0.0001) creepStep = 0.0001;
              progressNotifier.value = (current + creepStep).clamp(0.0, 0.98);
            }
          }
        }
      }

      // Selesai sepenuhnya
      if (targetProgress >= 0.99 && progressNotifier.value >= 0.995) {
        smoothTimer.cancel();
        Get.back(); // Tutup progress dialog
        _showLegacySuccess();
      }
    });

    _uploadPollTimer?.cancel();
    _uploadPollTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology_rounded,
                    color: Color(0xFF1565C0), size: 52),
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
                            _uploadPollTimer?.cancel();
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

  Future<void> fetchAnalysisDetail(String analysisId) async {
    isLoadingDetail.value = true;
    detailAnalysisData.value = {};

    final String url = "${ApiConfig.baseUrl}/analisis/$analysisId";

    debugPrint("[WEB DEBUG] Fetching URL: $url");

    try {
      final response = await http.get(Uri.parse(url));

      debugPrint("[WEB DEBUG] Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        if (data['notes_dokter'] == null) {
          data['notes_dokter'] = "Belum ada catatan dokter";
        }

        if (data['notes_radiolog'] == null) {
          data['notes_radiolog'] = "-";
        }

        detailAnalysisData.value = data;
        debugPrint("[WEB DEBUG] Data Berhasil Disimpan & Siap Tampil!");
      } else {
        SnackbarHelper.showError(
          title: "Gagal Memuat Analisis",
          message: "Server mengembalikan status: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      SnackbarHelper.showError(
        title: "Koneksi Terputus",
        message: "Gagal menarik data analisis dari server.",
      );
    } finally {
      isLoadingDetail.value = false;
    }
  }

  Future<void> logout() async {
    try {
      _pollingTimer?.cancel();
      _uploadPollTimer?.cancel();
      String? token = getToken();

      if (token != null) {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/logout/'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (e) {
      debugPrint("Gagal lapor ke server saat logout: $e");
    } finally {
      box.remove('token');
      box.remove('role');
      box.remove('username');

      Get.offAll(() => const LoginPage());
    }
  }
}
