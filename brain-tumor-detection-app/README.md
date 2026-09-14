# 🧠 BrainScan AI — Frontend (Flutter Web)

[![Flutter](https://img.shields.io/badge/Flutter-3.x%20Web-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart)](https://dart.dev)
[![GetX](https://img.shields.io/badge/GetX-State%20Management-8A2BE2?style=flat-square)](https://pub.dev/packages/get)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=flat-square)](https://flutter.dev)

Antarmuka pengguna (Frontend Web) untuk **BrainScan AI — 3D Brain Tumor Detection & Segmentation System**. Aplikasi ini dibangun menggunakan **Flutter Web** dengan bahasa pemrograman **Dart**, dirancang khusus untuk memenuhi standar antarmuka medis klinis yang responsif, modern, dan intuitif bagi Dokter Saraf (Sp.S), Radiolog (Sp.Rad), serta Administrator Rumah Sakit.

---

## 🎨 UI/UX Design System & Brand Alignment

Frontend BrainScan AI mengusung *Design System* korporat kelas medis berbasis **Pine Green & Emerald Accent**:

- **Primary Brand Color**: Pine Green (`#09503C`) — Digunakan pada panel autentikasi utama, header, dan elemen navigasi primer.
- **Secondary Accent Color**: Emerald Green (`#037B55`) — Digunakan pada aksen UI, tombol aksi utama, dan indikator status aktif.
- **Background Palette**: Light Clean Slate (`#F8FAFC`) — Memastikan tingkat keterbacaan (*readability*) tinggi untuk pembacaan citra medis.
- **Typography System**: Google Fonts (Inter / Outfit) untuk tampilan profesional yang tajam di berbagai resolusi layar.

---

## ✨ Fitur Utama (*Key Features*)

- 🔐 **Multi-Role Authentication**:
  - Login berbasis role (Admin, Dokter, Radiolog).
  - Manajemen sesi terenkripsi lokal via `get_storage` (otomatis mengingat sesi JWT token).
- 👥 **Pasien & Rekam Medis Management (CRUD)**:
  - Form pendaftaran pasien baru dengan pembuat ID Rekam Medis otomatis (`RM-XXXXXX`).
  - Pencarian (*live filtering*) data pasien berdasarkan nama atau nomor rekam medis.
- 🩻 **Interactive 2D Slice Viewer**:
  - Inspeksi hasil pemindaian MRI pada 3 bidang aksial: Aksial (*Axial*), Sagital (*Sagittal*), dan Koronal (*Coronal*).
  - Kontrol Zooming, Pan, Rotasi, serta Penyesuaian Inversi Kontras (*Contrast Inversion*).
  - Indikator *Dynamic Tumor Slice Auto-Detection* untuk menandai slice dengan area tumor paling dominan.
- 🧊 **Interactive 3D Volume Mesh Viewer**:
  - Rekonstruksi model 3D tumor dan jaringan otak secara real-time.
  - Rotasi 360 derajat, Zoom, dan inspeksi sub-region tumor (NETC, SNFH, ET, RC).
- 📊 **System Audit Log & Activity Monitoring**:
  - Log audit lengkap aktivitas pengguna untuk administrator.
  - Filter log berdasarkan Peran (*Role*) dan Rentang Tanggal (*Date Range*).
- 📱 **Responsive Adaptive Layout**:
  - Dukungan layar penuh untuk layar desktop workstation rumah sakit.
  - Layout adaptif dengan perbaikan menu drawer untuk perangkat tablet dan mobile viewport.

---

## 🛠️ Tech Stack & Dependencies

| Library / Package | Fungsi |
|-------------------|--------|
| **Flutter Web SDK** (`>=3.0.0`) | UI Framework utama |
| **GetX** | State management, reactive dependency injection, & routing |
| **get_storage** | Persistent storage lokal untuk menyimpan JWT token & user session |
| **http** | HTTP Client untuk komunikasi REST API ke backend FastAPI |
| **flutter_svg** | Rendering ikon kustom SVG berkualitas tinggi |
| **google_fonts** | Sistem tipografi medis modern (Inter / Outfit) |
| **calendar_date_picker2** | Widget pemilih tanggal lahir & filter audit log |

---

## 📁 Struktur Kode Frontend

```
tumor-frontend/
├── lib/
│   ├── main.dart                  # Root entry point aplikasi Flutter
│   ├── controllers/               # GetX Controllers (Auth, Patient, Scan, Log Controllers)
│   ├── models/                    # Data Models (User, Patient, Scan, Log Models)
│   ├── services/                  # API Services (Authentication, Patient, & Scan Services)
│   ├── utils/                     # Helper Utilities & ApiConfig
│   │   └── api_config.dart        # Switcher URL API (Local vs Hostinger VPS)
│   └── views/                     # UI Views & Screens
│       ├── login_screen.dart      # Halaman Login Brand Alignment
│       ├── dashboard_screen.dart  # Dashboard Utama & Metrics
│       ├── patient_screen.dart    # Manajamen Data Pasien & Form
│       ├── scan_detail_screen.dart# Interactive 2D & 3D Scan Inspection
│       └── audit_log_screen.dart  # Audit Trail Log Aktivitas
└── web/                           # CanvasKit & Static Web Assets
```

---

## ⚙️ Panduan Setup & Local Development

### Prasyarat
- **Flutter SDK** versi 3.0.0 atau yang lebih baru.
- Browser **Google Chrome** (direkomendasikan untuk performa CanvasKit optimal).

### Langkah-Langkah Menjalankan Frontend

1. **Navigasi ke Folder Source Code**:
   ```bash
   cd brain-tumor-detection-app/tumor-frontend
   ```

2. **Unduh Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Jalankan Aplikasi di Web (Chrome)**:
   ```bash
   flutter run -d chrome
   ```
   Aplikasi akan terbuka secara otomatis di `http://localhost:<random-port>`.

---

## 🌐 Konfigurasi URL API Backend (`ApiConfig`)

Pengaturan endpoint Backend API dikelola pada file `lib/utils/api_config.dart`:

```dart
class ApiConfig {
  // VPS Hostinger KVM 2 Production Server
  static const String _vpsUrl = "http://31.97.49.142/api";

  // Local Development Server
  static const String _localUrl = "http://127.0.0.1:8000";

  static String get baseUrl {
    if (kReleaseMode) {
      return _vpsUrl; // Otomatis mengarah ke VPS saat release build
    } else {
      return _localUrl; // Mengarah ke local backend saat debug
    }
  }
}
```

---

## 📦 Build untuk Produksi (*Production Web Deployment*)

Untuk menghasilkan bundel web statis siap deploy ke server Nginx:

1. Jalankan perintah build web:
   ```bash
   flutter build web --release
   ```

2. Hasil build akan berada pada direktori:
   `build/web/`

3. Upload seluruh isi folder `build/web/` ke web root server Nginx (misalnya `/var/www/BrainScan/`).

---

## 🛡️ Lisensi & Hak Cipta
Copyright © 2026 **BrainScan AI Team**. All Rights Reserved.
