import requests
import json
import sys
import os

# Konfigurasi URL dan kredensial default dari seed.py
BASE_URL = "http://127.0.0.1:8000"
USERNAME = "admin"
PASSWORD = "admin123"

def print_separator():
    print("-" * 50)

def main():
    print(f"=== Demo Sistem BrainScan API ===")
    print(f"Menghubungkan ke: {BASE_URL}")
    print_separator()

    # 1. Login untuk mendapatkan Token JWT
    print(f"1. Mencoba Login sebagai '{USERNAME}'...")
    login_data = {
        "username": USERNAME,
        "password": PASSWORD
    }
    
    try:
        response = requests.post(f"{BASE_URL}/token/", data=login_data)
        response.raise_for_status()
        
        token_data = response.json()
        access_token = token_data.get("access_token")
        
        print("✅ Login Berhasil!")
        print(f"🔑 Token didapatkan: {access_token[:20]}... (disembunyikan)")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Gagal login: {e}")
        if response.status_code == 400:
            print("Pastikan server backend sudah berjalan dan database telah di-seed (python seed.py)")
        sys.exit(1)

    print_separator()

    # Set Header Authorization untuk request selanjutnya
    headers = {
        "Authorization": f"Bearer {access_token}"
    }

    # 2. Mengambil Informasi User Saat Ini
    print("2. Mengambil Profil User Saat Ini...")
    try:
        response = requests.get(f"{BASE_URL}/users/me/", headers=headers)
        response.raise_for_status()
        user_info = response.json()
        print(f"👤 Username: {user_info.get('username')}")
        print(f"🏷️  Role: {user_info.get('role')}")
        print(f"📝 Nama Lengkap: {user_info.get('full_name')}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Gagal mengambil info user: {e}")

    print_separator()

    # 3. Mengambil Daftar Pasien
    print("3. Mengambil Daftar Pasien (10 data pertama)...")
    try:
        response = requests.get(f"{BASE_URL}/patients/", headers=headers)
        response.raise_for_status()
        patients = response.json()
        
        print(f"🏥 Total Pasien Ditemukan: {len(patients)}")
        for idx, p in enumerate(patients[:10]):
            print(f"   [{idx+1}] RM: {p.get('id_pasien_rs')} | Nama: {p.get('nama')} | Status: {p.get('status_pasien')}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Gagal mengambil data pasien: {e}")

    print_separator()
    
    # 4. Contoh upload MRI jika diberikan argumen file ZIP
    if len(sys.argv) > 1:
        zip_path = sys.argv[1]
        print(f"4. Mengunggah file MRI: {zip_path}")
        if not os.path.exists(zip_path):
            print("❌ File tidak ditemukan!")
        else:
            try:
                # Membuat data dummy untuk request
                upload_data = {
                    "nama": "Pasien Demo",
                    "id_pasien": "RM-999999",
                    "tgl_lahir": "1990-01-01",
                    "status": "Aktif",
                    "jenis_mri": "MRI Otak",
                    "catatan": "Upload via script demo",
                    "model_type": "optimisasi"
                }
                
                with open(zip_path, 'rb') as f:
                    files = {'file': (os.path.basename(zip_path), f, 'application/zip')}
                    response = requests.post(
                        f"{BASE_URL}/upload-mri/", 
                        headers=headers, 
                        data=upload_data, 
                        files=files
                    )
                    
                response.raise_for_status()
                result = response.json()
                print("✅ Upload berhasil!")
                print(f"📋 Scan ID: {result.get('scan_id')}")
                print(f"Pesan: {result.get('pesan')}")
                print("⚠️  Gunakan endpoint /scan/{scan_id}/status untuk polling status pemrosesan.")
            except requests.exceptions.RequestException as e:
                print(f"❌ Gagal mengunggah MRI: {e}")
                if response:
                    print(f"Detail: {response.text}")
    else:
        print("💡 Tips: Untuk mendemonstrasikan upload MRI, jalankan script ini dengan:")
        print("   python demo_api.py path/ke/file_mri.zip")

    print_separator()
    print("✨ Demo Selesai!")

if __name__ == "__main__":
    main()
