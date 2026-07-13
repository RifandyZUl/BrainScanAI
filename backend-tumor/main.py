# main.py
from fastapi.security import OAuth2AuthorizationCodeBearer, OAuth2PasswordRequestForm, OAuth2PasswordBearer
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse
from jose import JWTError, jwt
from fastapi import FastAPI, UploadFile, File, Form, Depends, HTTPException, status, BackgroundTasks
from fastapi.staticfiles import StaticFiles
from urllib.parse import unquote
from typing import List, Optional
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from database import SessionLocal, engine
from datetime import datetime
from sqlalchemy import func
import os
import time
import zipfile
import auth
import models, schemas
import shutil
import uuid
import io
from PIL import Image
import pydantic
import nibabel as nib
import numpy as np
import json
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import plotly.graph_objects as go
from skimage import measure
from scipy.ndimage import gaussian_filter, distance_transform_edt, binary_erosion
import torch
from datetime import datetime, timezone
import pytz

from models_ckd.inference import predict_segmentation

try:
    torch.serialization.add_safe_globals([np._core.multiarray.scalar])
except AttributeError:
    try:
        torch.serialization.add_safe_globals([np.core.multiarray.scalar])
    except AttributeError:
        pass


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Create Database Table
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# CORS Hardening
cors_origins_raw = os.getenv("CORS_ORIGINS", "*")
CORS_ORIGINS = [origin.strip() for origin in cors_origins_raw.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory=UPLOAD_DIR), name="static")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(status_code=401, detail="Token tidak valid", headers={"WWW-Authenticate": "Bearer"})
    try:
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        username: str = payload.get("sub")
        if username is None: raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = db.query(models.User).filter(models.User.username == username).first()
    if user is None: raise credentials_exception
    return user

def save_log(db: Session, username: str, role: str, activity: str, details: str = ""):
    try:
        new_log = models.ActivityLog(username=username, role=role, activity=activity, details=details)
        db.add(new_log)
        db.commit()
    except Exception as e:
        print(f"Gagal menyimpan log: {e}")

# ENDPOINT AUTH & USER
@app.post("/token/")
async def login_for_access_token(from_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.username == from_data.username).first()
    if not user or not auth.verify_password(from_data.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Username atau Password Salah")
    access_token = auth.create_access_token(data={"sub": user.username, "role": user.role, "id": user.id})
    save_log(db, user.username, user.role, "Login", "Login Berhasil")
    return {"access_token": access_token, "token_type": "bearer", "role": user.role}

@app.post("/logout/")
def logout(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    save_log(db, current_user.username, current_user.role, "Logout", "Logout dari sistem")
    return {"message": "Berhasil logout"}

@app.post("/users/", response_model=schemas.UserResponse)
def create_new_user(user: schemas.UserCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db_user = db.query(models.User).filter(models.User.username == user.username).first()
    if db_user: raise HTTPException(status_code=400, detail="Username sudah terdaftar")
    hashed_pw = auth.get_password_hash(user.password)
    new_user = models.User(username=user.username, full_name=user.full_name, role=user.role, hashed_password=hashed_pw)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    save_log(db, current_user.username, current_user.role, "Create User", f"Membuat user: {user.username} ({user.role})")
    return new_user

@app.put("/users/{user_id}", response_model=schemas.UserResponse)
def update_user(user_id: int, user_update: schemas.UserUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user: raise HTTPException(status_code=404, detail="User tidak ditemukan")
    if user_update.username is not None: db_user.username = user_update.username
    if user_update.full_name is not None: db_user.full_name = user_update.full_name
    if user_update.role is not None: db_user.role = user_update.role
    if user_update.password and user_update.password.strip():
        db_user.hashed_password = auth.get_password_hash(user_update.password)
    if user_update.avatar is not None: db_user.avatar = user_update.avatar
    if user_update.is_active is not None:
        db_user.is_active = user_update.is_active
    db.commit()
    db.refresh(db_user)
    status_text = "Aktif" if db_user.is_active else "Nonaktif"
    save_log(db, current_user.username, current_user.role, "Edit User", f"Mengedit user ID: {user_id} - Status: {status_text}")
    return db_user

@app.delete("/users/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user: raise HTTPException(status_code=404, detail="User tidak ditemukan")
    if db_user.id == current_user.id: raise HTTPException(status_code=400, detail="Tidak dapat menghapus akun sendiri")
    target_username = db_user.username
    db_user.is_active = False
    db.commit()
    save_log(db, current_user.username, current_user.role, "Deactivate User", f"Menonaktifkan user: {target_username}")
    return {"detail": "User berhasil dinonaktifkan"}

@app.get("/users/me/", response_model=schemas.UserResponse)
def read_users_me(current_user: models.User = Depends(get_current_user)):
    return current_user

@app.get("/users/", response_model=List[schemas.UserResponse])
def read_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    return db.query(models.User).offset(skip).limit(limit).all()

@app.post("/users/upload-avatar/")
async def upload_avatar(file: UploadFile = File(...), current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    file_extension = file.filename.split(".")[-1]
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gagal menyimpan file: {str(e)}")
    avatar_url = f"static/{unique_filename}"
    current_user.avatar = avatar_url
    db.commit()
    db.refresh(current_user)
    save_log(db, current_user.username, current_user.role, "Update Profile", "Mengganti foto profil")
    return {"message": "Foto profil berhasil diupdate", "url": avatar_url} 

# ENDPOINT DATA PASIEN
@app.get("/patients/", response_model=List[schemas.PatientResponse])
def read_patient(db: Session = Depends(get_db)):
    return db.query(models.Patient).order_by(models.Patient.id.asc()).all()

@app.post("/patients/", response_model=schemas.PatientResponse)
def create_patient(patient: schemas.PatientCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    existing = db.query(models.Patient).filter(models.Patient.id_pasien_rs == patient.id_pasien_rs).first()
    if existing: raise HTTPException(status_code=400, detail="ID Pasien (RM) Sudah terdaftar")
    new_patient = models.Patient(id_pasien_rs=patient.id_pasien_rs, nama=patient.nama, tanggal_lahir=patient.tanggal_lahir, jenis_kelamin=patient.jenis_kelamin, status_pasien=patient.status_pasien)
    db.add(new_patient)
    db.commit()
    db.refresh(new_patient)
    save_log(db, current_user.username, current_user.role, "Create Patient", f"Menambah pasien baru: {new_patient.nama} (RM: {new_patient.id_pasien_rs})")
    return new_patient

@app.put("/patients/{patient_id}", response_model=schemas.PatientResponse)
def update_patient(patient_id: int, patient_update: schemas.PatientCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_patient = db.query(models.Patient).filter(models.Patient.id == patient_id).first()
    if not db_patient: raise HTTPException(status_code=404, detail="Pasien tidak ditemukan")
    old_status = db_patient.status_pasien
    db_patient.id_pasien_rs = patient_update.id_pasien_rs
    db_patient.nama = patient_update.nama
    db_patient.tanggal_lahir = patient_update.tanggal_lahir
    db_patient.jenis_kelamin = patient_update.jenis_kelamin
    db_patient.status_pasien = patient_update.status_pasien
    db.commit()
    db.refresh(db_patient)
    detail_msg = f"Update data pasien: {db_patient.nama} (RM: {db_patient.id_pasien_rs})"
    if old_status != db_patient.status_pasien: detail_msg += f" | Status ubah: {old_status} -> {db_patient.status_pasien}"
    save_log(db, current_user.username, current_user.role, "Edit Patient", detail_msg)
    return db_patient

# METRIC FUNCTIONS (Dice + Sensitivity + HD95)

def _dice(p_mask, g_mask, eps=1e-5):
    p_sum, g_sum = int(p_mask.sum()), int(g_mask.sum())
    if p_sum == 0 and g_sum == 0: return 1.0
    if p_sum == 0 or g_sum == 0: return 0.0
    inter = int(np.logical_and(p_mask, g_mask).sum())
    return float((2 * inter + eps) / (p_sum + g_sum + eps))

def _sens(p_mask, g_mask, eps=1e-5):
    """Sensitivity = Recall = TP / (TP + FN)."""
    tp = int(np.logical_and(p_mask, g_mask).sum())
    fn = int(np.logical_and(~p_mask, g_mask).sum())
    if tp + fn == 0: return 1.0
    return float((tp + eps) / (tp + fn + eps))

def _hd95(p_mask, g_mask):
    """HD95 — 95th percentile bidirectional Hausdorff distance (voxel units)."""
    p_sum, g_sum = int(p_mask.sum()), int(g_mask.sum())
    if p_sum == 0 and g_sum == 0: return 0.0
    if p_sum == 0 or g_sum == 0: return float("nan")
    ps = np.logical_xor(p_mask, binary_erosion(p_mask, border_value=1))
    ts = np.logical_xor(g_mask, binary_erosion(g_mask, border_value=1))
    if not ps.any() or not ts.any(): return float("nan")
    dt = distance_transform_edt(~ts, sampling=(1, 1, 1))
    dp = distance_transform_edt(~ps, sampling=(1, 1, 1))
    return float(np.percentile(np.concatenate([dt[ps], dp[ts]]), 95))

def _safe_round(v, ndigits):
    if v is None or (isinstance(v, float) and np.isnan(v)):
        return None
    return round(float(v), ndigits)

def _triplet(p_mask, g_mask):
    return {
        "dice": _safe_round(_dice(p_mask, g_mask), 4),
        "sens": _safe_round(_sens(p_mask, g_mask), 4),
        "hd95": _safe_round(_hd95(p_mask, g_mask), 2),
    }

def _mean_triplet(metrics_list):
    """Compute mean dice/sens/hd95 over list of metric dicts."""
    all_dice = [m["dice"] for m in metrics_list if m["dice"] is not None]
    all_sens = [m["sens"] for m in metrics_list if m["sens"] is not None]
    all_hd95 = [m["hd95"] for m in metrics_list if m["hd95"] is not None]
    return {
        "dice": round(float(np.mean(all_dice)), 4) if all_dice else None,
        "sens": round(float(np.mean(all_sens)), 4) if all_sens else None,
        "hd95": round(float(np.mean(all_hd95)), 2) if all_hd95 else None,
    }

def load_u8(path):
    nii = nib.as_closest_canonical(nib.load(path))
    return np.rint(nii.get_fdata()).astype(np.uint8)

def calculate_metrics_if_gt_exists(pred_path, gt_file_path):
    """
    Notebook-style metric:
    - per_class (default view): 4 class (NETC, SNFH, ET, RC) + mean
    - per_region_brats (toggle): 3 region (ET, TC, WT)
    - mean_brats_6: mean over 6 metrik gabungan
    """
    if gt_file_path is None or not os.path.exists(gt_file_path):
        return None
    try:
        pred = load_u8(pred_path)
        gt = load_u8(gt_file_path)

        if pred.shape != gt.shape:
            print(f"Shape mismatch: pred {pred.shape} vs gt {gt.shape}")
            return None

        # ── Compound BraTS regions ──
        et_p, et_g = (pred == 3), (gt == 3)
        tc_p = (pred == 3) | (pred == 1)
        tc_g = (gt == 3) | (gt == 1)
        wt_p = (pred == 1) | (pred == 2) | (pred == 3)
        wt_g = (gt == 1) | (gt == 2) | (gt == 3)

        # ── Per-class individual ──
        netc_p, netc_g = (pred == 1), (gt == 1)
        snfh_p, snfh_g = (pred == 2), (gt == 2)
        rc_p, rc_g = (pred == 4), (gt == 4)

        per_region_brats = {
            "ET": _triplet(et_p, et_g),
            "TC": _triplet(tc_p, tc_g),
            "WT": _triplet(wt_p, wt_g),
        }
        per_class = {
            "NETC": _triplet(netc_p, netc_g),
            "SNFH": _triplet(snfh_p, snfh_g),
            "ET":   _triplet(et_p, et_g),
            "RC":   _triplet(rc_p, rc_g),
        }
        per_class["mean"] = _mean_triplet(
            [per_class["NETC"], per_class["SNFH"], per_class["ET"], per_class["RC"]]
        )

        # Mean BraTS 6 = 3 regions + 3 individual (NETC, SNFH, RC; ET sudah di regions)
        mean_brats_6 = _mean_triplet([
            per_region_brats["ET"], per_region_brats["TC"], per_region_brats["WT"],
            per_class["NETC"], per_class["SNFH"], per_class["RC"],
        ])

        result = {
            "default_view": "per_class",
            "per_class": per_class,
            "per_region_brats": per_region_brats,
            "mean_brats_6": mean_brats_6,
        }
        return json.dumps(result)
    except Exception as e:
        print(f"Error saat menghitung metric: {e}")
        return None

def norm01(x):
    v = x[np.isfinite(x)]
    lo, hi = np.percentile(v, [2, 98]) if v.size > 0 else (0.0, 1.0)
    if hi <= lo: hi = lo + 1e-8
    return np.clip((x - lo) / (hi - lo + 1e-8), 0, 1)

def generate_single_3d(mri_ds, pred_ds, out_path, target_label, ds=2, show_brain=True):
    # Match Colab colors and naming exactly:
    # 1: NETC (Cyan), 2: SNFH (Yellow), 3: ET (Red), 4: RC (Purple/Magenta)
    colors_3d = {
        1: ("NETC", "#00ffff"),  # Cyan
        2: ("SNFH", "#e5c100"),  # Yellow/Gold
        3: ("ET",   "#ff0000"),  # Red
        4: ("RC",   "#ff00ff")   # Purple/Magenta
    }
    # Match Colab opacities exactly:
    op_map = {1: 0.7, 2: 0.4, 3: 0.9, 4: 0.8}
    fig_3d = go.Figure()

    if show_brain:
        # Match Colab add_brain_outline: brain_mask = (mri_vol > 0.02)
        brain = mri_ds > 0.02
        if brain.sum() > 0:
            # Match Colab: sigma=1.5, level=0.1, color="gainsboro", opacity=0.05
            brain_smooth = gaussian_filter(brain.astype(float), sigma=1.5)
            try:
                v, f, _, _ = measure.marching_cubes(brain_smooth, level=0.1)
                fig_3d.add_trace(go.Mesh3d(
                    x=v[:,0] * ds, y=v[:,1] * ds, z=v[:,2] * ds,
                    i=f[:,0], j=f[:,1], k=f[:,2],
                    color="gainsboro", opacity=0.05,
                    lighting=dict(
                        ambient=0.4,
                        diffuse=0.6,
                        specular=0.5,
                        roughness=0.3
                    ),
                    lightposition=dict(x=150, y=150, z=250),
                    name="Brain", hoverinfo="skip"
                ))
            except Exception as e:
                print(f"Error marching cubes for brain: {e}")

    labels_to_draw = [2, 4, 3, 1] if target_label == 0 else [target_label]

    for lbl in labels_to_draw:
        name, col = colors_3d[lbl]
        bin_vol = (pred_ds == lbl).astype(np.float32)
        if bin_vol.sum() >= 10:
            # Match Colab add_tumor_mesh: smooth_sigma=0.8, level=0.2
            bin_smooth = gaussian_filter(bin_vol, sigma=0.8)
            try:
                v, f, _, _ = measure.marching_cubes(bin_smooth, level=0.2, allow_degenerate=True)
                fig_3d.add_trace(go.Mesh3d(
                    x=v[:,0] * ds, y=v[:,1] * ds, z=v[:,2] * ds,
                    i=f[:,0], j=f[:,1], k=f[:,2],
                    color=col, opacity=op_map[lbl] if target_label == 0 else 1.0,
                    lighting=dict(
                        ambient=0.5,
                        diffuse=0.8,
                        specular=0.3,
                        roughness=0.5,
                    ),
                    lightposition=dict(x=100, y=200, z=300),
                    name=name
                ))
            except Exception as e:
                print(f"Error marching cubes for label {lbl}: {e}")
            
    # Match Colab Clean Layout: No Grid, No Box, White Background, Eye Camera
    camera = dict(
        eye=dict(x=1.5, y=1.5, z=1.0),
        up=dict(x=0, y=0, z=1),
    )
    scene_config = dict(
        aspectmode="data",
        xaxis=dict(visible=False, showgrid=False, zeroline=False, showbackground=False),
        yaxis=dict(visible=False, showgrid=False, zeroline=False, showbackground=False),
        zaxis=dict(visible=False, showgrid=False, zeroline=False, showbackground=False),
        bgcolor="white",
        camera=camera,
    )
    fig_3d.update_layout(
        paper_bgcolor='white', plot_bgcolor='white', font=dict(color='black'),
        scene=scene_config,
        margin=dict(l=0, r=0, b=0, t=0)
    )
    fig_3d.write_html(out_path, full_html=True, include_plotlyjs='cdn')


# ── Progress helper ──
def _update_scan_progress(db, scan, status: str, progress: int, message: str = None):
    """Update progress field tanpa block proses utama. Best-effort."""
    try:
        scan.processing_status = status
        scan.processing_progress = progress
        if message:
            scan.processing_message = message
        db.commit()
    except Exception as e:
        print(f"[WARN] Gagal update progress: {e}")
        db.rollback()

# AI PROCESSOR (BACKGROUND TASK)
def process_mri_ai(scan_id: int, input_dir: str, output_dir: str, case_id: str, gt_file_path: str, model_type: str = "optimisasi"):
    db = SessionLocal()
    scan = db.query(models.MRIScan).filter(models.MRIScan.id == scan_id).first()
    if not scan:
        db.close()
        return

    print(f"[PROSES MULAI] AI ({model_type}) sedang membedah pasien: {case_id}...")

    try:
        # Stage 1: Loading model
        _update_scan_progress(db, scan, "loading_model", 15,
                             f"Memuat model {model_type.upper()}...")

        # Stage 2: Preprocessing
        _update_scan_progress(db, scan, "preprocessing", 25,
                             "Memproses data MRI (orientation, spacing, normalisasi)...")

        # Stage 3: Inference
        _update_scan_progress(db, scan, "running_inference", 60,
                             f"Menjalankan AI segmentasi (sliding window inference)...")

        pred_path, inference_time = predict_segmentation(
            input_dir=input_dir,
            output_dir=output_dir,
            case_id=case_id,
            model_type=model_type,
            gt_label_path=gt_file_path,
        )

        print(f"[INFERENCE TIME] {inference_time:.2f} detik (model: {model_type})")

        mri_path_3d = os.path.join(input_dir, f"{case_id}_0003.nii.gz")

        pred_data = nib.load(pred_path).get_fdata()
        unique_labels = np.unique(pred_data).astype(int).tolist()
        if 0 in unique_labels: unique_labels.remove(0)
        scan.detected_regions = json.dumps(unique_labels)

        # Stage 4: Metrics
        _update_scan_progress(db, scan, "computing_metrics", 75,
                             "Menghitung metrik evaluasi (Dice, Sensitivity, HD95)...")

        metrics_json = calculate_metrics_if_gt_exists(pred_path, gt_file_path)

        original_notes = scan.catatan_teknis or "-"

        scan.catatan_teknis = json.dumps({
            "catatan": original_notes,
            "metrics": json.loads(metrics_json) if metrics_json else None,
            "shape": list(pred_data.shape),
            "case_id": case_id,
            "model_type": model_type,
            "inference_time_seconds": round(inference_time, 2),
        })

        # Stage 5: 3D Rendering
        _update_scan_progress(db, scan, "rendering_3d", 85,
                             "Membuat visualisasi 3D interaktif...")

        mri_3d = nib.as_closest_canonical(nib.load(mri_path_3d)).get_fdata().astype(np.float32)
        pred_3d = nib.as_closest_canonical(nib.load(pred_path)).get_fdata().astype(np.uint8)

        ds = 2
        mri01 = norm01(mri_3d)
        mri_ds = mri01[::ds, ::ds, ::ds]

        pred_ds = pred_3d[::ds, ::ds, ::ds]
        path_3d_db = {}
        base_labels = {"all": 0, "netc": 1, "snfh": 2, "et": 3, "rc": 4}

        for key, lbl in base_labels.items():
            fname_3d_with = f"result_{scan_id}_3d_{key}.html"
            out_path_with = os.path.join(UPLOAD_DIR, fname_3d_with)
            generate_single_3d(mri_ds, pred_ds, out_path_with, lbl, show_brain=True)
            path_3d_db[key] = f"static/{fname_3d_with}"

            fname_3d_no = f"result_{scan_id}_3d_{key}_nobrain.html"
            out_path_no = os.path.join(UPLOAD_DIR, fname_3d_no)
            generate_single_3d(mri_ds, pred_ds, out_path_no, lbl, show_brain=False)
            path_3d_db[f"{key}_nobrain"] = f"static/{fname_3d_no}"

        scan.filepath_3d = json.dumps(path_3d_db)
        scan.filepath_2d = "dynamic" 
        scan.hasil_prediksi = "Tumor Terdeteksi" if unique_labels else "Normal"

        # Stage 6: Saving
        _update_scan_progress(db, scan, "saving_results", 95,
                             "Menyimpan hasil...")

        target_roles = ["Dokter", "Radiolog"]
        for target in target_roles:
            db.add(models.Notification(
                target_role=target,
                title="Analisis AI Selesai!",
                message=f"Model: {model_type.upper()} | Waktu: {inference_time:.1f}s | Hasil pemindaian 3D dan Slice 2D dapat dilihat.",
                analysis_id=scan.id
            ))

        # Stage 7: Complete
        _update_scan_progress(db, scan, "completed", 100, "Analisis selesai!")
        db.commit()
    
    except Exception as e:
        import traceback
        print(f"[ERROR AI] Gagal memproses: {e}")
        traceback.print_exc()
        scan.hasil_prediksi = "Gagal Diproses AI"
        try:
            scan.processing_status = "failed"
            scan.processing_progress = -1
            scan.processing_message = f"Error: {str(e)[:200]}"
            db.commit()
        except Exception:
            db.rollback()
    finally:
        db.close()

@app.get("/scan/{scan_id}/status")
def get_scan_status(scan_id: int, db: Session = Depends(get_db)):
    """
    Return current processing status. Frontend poll endpoint ini setiap 1-2s
    selama scan masih processing.
    """
    scan = db.query(models.MRIScan).filter(models.MRIScan.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan tidak ditemukan")
    
    return {
        "scan_id": scan.id,
        "status": scan.processing_status or "uploaded",
        "progress": scan.processing_progress if scan.processing_progress is not None else 0,
        "message": scan.processing_message or "",
        "is_complete": scan.processing_status == "completed",
        "is_failed": scan.processing_status == "failed",
        "hasil_prediksi": scan.hasil_prediksi,
    }

# ENDPOINT ANALISIS & FILE
@app.post("/upload-mri/")
async def upload_mri_smart(
    background_tasks: BackgroundTasks, nama: str = Form(...), id_pasien: str = Form(...), tgl_lahir: str = Form(...),
    status: str = Form(...), jenis_mri: str = Form(...), catatan: str = Form(default="-"),
    model_type: str = Form(default="optimisasi"),
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)
):
    if not file.filename.endswith('.zip'): raise HTTPException(status_code=400, detail="Harus file .zip yang berisi 4 modalitas MRI!")
    if model_type not in ("optimisasi", "paper"): raise HTTPException(status_code=400, detail="model_type harus 'optimisasi' atau 'paper'")

    pasien_db = db.query(models.Patient).filter(models.Patient.id_pasien_rs == id_pasien).first()
    if not pasien_db:
        pasien_db = models.Patient(nama=nama, id_pasien_rs=id_pasien, tanggal_lahir=tgl_lahir, status_pasien=status)
        db.add(pasien_db)
        db.commit()
        db.refresh(pasien_db)
    else:
        pasien_db.nama = nama
        pasien_db.status_pasien = status
        db.commit()
    
    new_scan = models.MRIScan(patient_id=pasien_db.id, jenis_mri="MRI Otak", catatan_teknis=catatan, filepath_raw="", hasil_prediksi="Sedang Dianalisis...", processing_status="uploaded", processing_progress=5, processing_message="Berkas diterima, antri untuk diproses...")
    db.add(new_scan)
    db.commit()
    db.refresh(new_scan)

    # Folder Scan
    scan_folder = os.path.join(UPLOAD_DIR, f"scan_{new_scan.id}")
    input_dir = os.path.join(scan_folder, "input")
    output_dir = os.path.join(scan_folder, "output")

    # Retry logic untuk mengatasi OSError: [Errno 5] pada Docker/WSL2 volume mount
    for attempt in range(3):
        try:
            os.makedirs(input_dir, exist_ok=True)
            os.makedirs(output_dir, exist_ok=True)
            break
        except OSError as e:
            if attempt < 2:
                print(f"[WARN] os.makedirs gagal (attempt {attempt+1}/3): {e}. Retry dalam 1 detik...")
                time.sleep(1)
            else:
                raise HTTPException(status_code=500, detail=f"Gagal membuat folder scan: {e}. Coba restart Docker Desktop.")

    # Ekstrak ZIP dengan proteksi Zip-Slip (Path Traversal)
    zip_path = os.path.join(scan_folder, "temp.zip")
    with open(zip_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        for member in zip_ref.infolist():
            # Validasi absolut path agar tidak melompat keluar dari input_dir
            target_path = os.path.abspath(os.path.join(input_dir, member.filename))
            if not target_path.startswith(os.path.abspath(input_dir)):
                raise HTTPException(status_code=400, detail="Zip file contains illegal path traversal attempt.")
            zip_ref.extract(member, input_dir)
    os.remove(zip_path)

    # Flatten nested folder: kalau semua file ada di subfolder, pindahkan ke input_dir
    for root, dirs, files in os.walk(input_dir):
        if root == input_dir:
            continue
        for f in files:
            src = os.path.join(root, f)
            dst = os.path.join(input_dir, f)
            if not os.path.exists(dst):
                shutil.move(src, dst)
    # Hapus subfolder kosong
    for root, dirs, files in os.walk(input_dir, topdown=False):
        if root == input_dir:
            continue
        if not os.listdir(root):
            os.rmdir(root)

    extracted_files = [f for f in os.listdir(input_dir) if f.endswith('.nii.gz')]
    
    t1n_file = None
    t1c_file = None
    t2w_file = None
    t2f_file = None
    seg_file = None

    # Pencocokan nama file secara fleksibel (BraTS & nnUNet formats)
    # Urutan if-elif sangat penting untuk mencegah greediness (misal '-t2' mencocokkan '-t2f')
    for f in extracted_files:
        f_lower = f.lower()
        if any(x in f_lower for x in ["-seg", "_seg", "-gt", "_gt"]):
            seg_file = f
        elif any(x in f_lower for x in ["_0003", "-t2f", "_t2f", "-flair", "_flair"]):
            t2f_file = f
        elif any(x in f_lower for x in ["_0001", "-t1c", "_t1c", "-t1ce", "_t1ce"]):
            t1c_file = f
        elif any(x in f_lower for x in ["_0000", "-t1n", "_t1n"]) or (any(x in f_lower for x in ["-t1", "_t1"]) and not any(x in f_lower for x in ["t1c", "t1ce"])):
            t1n_file = f
        elif any(x in f_lower for x in ["_0002", "-t2w", "_t2w", "-t2", "_t2"]):
            t2w_file = f

    if not (t1n_file and t1c_file and t2w_file and t2f_file):
        raise HTTPException(
            status_code=400,
            detail="Format ZIP salah! Harus berisi 4 modalitas MRI (T1, T1c, T2, FLAIR). "
                   f"Ditemukan: T1={t1n_file}, T1c={t1c_file}, T2={t2w_file}, FLAIR={t2f_file}"
        )


    # Tentukan case_id dari prefix file T1c
    case_id = t1c_file
    for suff in [".nii.gz", "-t1c", "_t1c", "-t1ce", "_t1ce", "_0001"]:
        if case_id.lower().endswith(suff):
            case_id = case_id[:-len(suff)]
    
    # Standarisasi nama file ke format internal (_0000 s/d _0003)
    shutil.move(os.path.join(input_dir, t1n_file), os.path.join(input_dir, f"{case_id}_0000.nii.gz"))
    shutil.move(os.path.join(input_dir, t1c_file), os.path.join(input_dir, f"{case_id}_0001.nii.gz"))
    shutil.move(os.path.join(input_dir, t2w_file), os.path.join(input_dir, f"{case_id}_0002.nii.gz"))
    shutil.move(os.path.join(input_dir, t2f_file), os.path.join(input_dir, f"{case_id}_0003.nii.gz"))

    gt_file_path = None
    if seg_file:
        gt_file_path = os.path.join(scan_folder, f"{case_id}_GT.nii.gz")
        shutil.move(os.path.join(input_dir, seg_file), gt_file_path)
        print(f"File GT ditemukan dan diamankan ke: {gt_file_path}")


    new_scan.filepath_raw = scan_folder
    db.commit()

    new_notif = models.Notification(target_role="Dokter", title="Data MRI Otak Diterima", message=f"File ZIP Pasien {nama} berhasil diekstrak dan masuk antrean AI (Model: {model_type.upper()}).", analysis_id=new_scan.id)
    db.add(new_notif)
    db.commit()

    save_log(db, current_user.username, current_user.role, "Upload MRI", f"Upload scan untuk pasien: {nama} (Model: {model_type})")

    background_tasks.add_task(process_mri_ai, new_scan.id, input_dir, output_dir, case_id, gt_file_path, model_type)

    return {
        "status": "sukses",
        "pesan": f"ZIP terekstrak dan masuk antrean AI (model: {model_type})",
        "scan_id": new_scan.id,
        "model_type": model_type,
    }

@app.get("/analisis/{analysis_id}/slice")
def get_mri_slice(analysis_id: int, axis: int = 2, idx: int = 75, label: str = "all", db: Session = Depends(get_db)):
    scan = db.query(models.MRIScan).filter(models.MRIScan.id == analysis_id).first()
    if not scan: raise HTTPException(status_code=404, detail="Scan tidak ditemukan")
    try:
        meta = json.loads(scan.catatan_teknis)
        case_id = meta.get("case_id")
    except (json.JSONDecodeError, KeyError, TypeError, AttributeError):
        raise HTTPException(status_code=400, detail="Data belum siap")

    scan_folder = scan.filepath_raw
    input_dir = os.path.join(scan_folder, "input")
    output_dir = os.path.join(scan_folder, "output")

    pred_path = os.path.join(output_dir, f"{case_id}.nii.gz")
    mri_path_2d = os.path.join(input_dir, f"{case_id}_0001.nii.gz")  # T1c: konsisten dengan 3D viewer & standar klinis


    try:
        mri_vol = nib.load(mri_path_2d).get_fdata().astype(np.float32)
        pred_vol = nib.load(pred_path).get_fdata().astype(np.uint8)

        axis_size = mri_vol.shape[axis]

        # Dynamic slice index selection:
        # If the index is the default 75 or not specified:
        if idx == 75 or idx is None:
            tumor_mask = pred_vol > 0
            if tumor_mask.any():
                # Find slice with maximum tumor segmentation area
                sum_axes = tuple(i for i in range(3) if i != axis)
                tumor_area_per_slice = tumor_mask.sum(axis=sum_axes)
                idx = int(np.argmax(tumor_area_per_slice))
            else:
                # Find slice with maximum brain tissue area (intensity > 10% of max)
                brain_mask = mri_vol > (mri_vol.max() * 0.1)
                if brain_mask.any():
                    sum_axes = tuple(i for i in range(3) if i != axis)
                    brain_area_per_slice = brain_mask.sum(axis=sum_axes)
                    idx = int(np.argmax(brain_area_per_slice))
                else:
                    idx = axis_size // 2

        # Clamp idx to safe boundary
        idx = max(0, min(int(idx), axis_size - 1))

        def take_slice(vol, axis, idx):
            if axis == 0: return vol[idx, :, :]
            if axis == 1: return vol[:, idx, :] 
            if axis == 2: return vol[:, :, idx]
            raise HTTPException(status_code=400, detail=f"Axis tidak valid: {axis}. Harus 0, 1, atau 2.")

        mri_s = norm01(take_slice(mri_vol, axis, idx))
        pred_s = take_slice(pred_vol, axis, idx)

        if label == "netc": pred_s = np.where(pred_s == 1, 1, 0)
        elif label == "snfh": pred_s = np.where(pred_s == 2, 2, 0)
        elif label == "et": pred_s = np.where(pred_s == 3, 3, 0)
        elif label == "rc": pred_s = np.where(pred_s == 4, 4, 0)

        colors_hex = {
            1: "#00ffff",  # NETC (Cyan)
            2: "#e5c100",  # SNFH (Yellow/Gold)
            3: "#ff0000",  # ET (Red)
            4: "#ff00ff"   # RC (Purple/Magenta)
        }
        mask_cmap = ListedColormap(["none", colors_hex[1], colors_hex[2], colors_hex[3], colors_hex[4]])

        fig, ax = plt.subplots(figsize=(6, 6), dpi=100)
        ax.imshow(np.rot90(mri_s), cmap="gray")
        ax.imshow(np.rot90(pred_s), cmap=mask_cmap, alpha=0.6, vmin=0, vmax=4)
        ax.axis("off")

        buf = io.BytesIO()
        plt.savefig(buf, format="png", bbox_inches='tight', pad_inches=0, transparent=True)
        plt.close(fig)
        buf.seek(0)
        return StreamingResponse(
            buf,
            media_type="image/png",
            headers={"Access-Control-Allow-Origin": "*", "Cache-Control": "no-cache"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analisis/{analysis_id}/info")
def get_analysis_info(analysis_id: int, db: Session = Depends(get_db)):
    scan = db.query(models.MRIScan).filter(models.MRIScan.id == analysis_id).first()
    if not scan: 
        raise HTTPException(status_code=404, detail="Scan tidak ditemukan")
    try:
        meta = json.loads(scan.catatan_teknis)
        return {
            "case_id": meta.get("case_id"),
            "model_type": meta.get("model_type", "unknown"),
            "inference_time_seconds": meta.get("inference_time_seconds"),
            "metrics": meta.get("metrics"),
            "shape": meta.get("shape"),
        }
    except (json.JSONDecodeError, KeyError, TypeError, AttributeError):
        raise HTTPException(status_code=400, detail="Data belum siap")

@app.get("/riwayat-semua/")
def get_all_history(db: Session = Depends(get_db)):
    scans = db.query(models.MRIScan).order_by(models.MRIScan.upload_date.desc()).all()
    
    tz_jkt = pytz.timezone('Asia/Jakarta')
    results = []
    
    for scan in scans:
        if not scan.upload_date:
            tgl_cantik = "-"
        else:
            if scan.upload_date.tzinfo is None:
                waktu_utc = scan.upload_date.replace(tzinfo=pytz.utc)
                waktu_lokal = waktu_utc.astimezone(tz_jkt)
            else:
                waktu_lokal = scan.upload_date.astimezone(tz_jkt)
            
            tgl_cantik = waktu_lokal.strftime("%d/%m/%Y")

        # Parse catatan teknis
        catatan_val = "-"
        if scan.catatan_teknis:
            if scan.catatan_teknis.strip().startswith("{"):
                try:
                    import json
                    meta = json.loads(scan.catatan_teknis)
                    catatan_val = meta.get("catatan", "-")
                except Exception:
                    catatan_val = scan.catatan_teknis
            else:
                catatan_val = scan.catatan_teknis

        results.append({
            "id": scan.id, "jenis_mri": scan.jenis_mri, "tanggal_periksa": tgl_cantik,
            "hasil_prediksi": scan.hasil_prediksi, "nama_pasien": scan.patient.nama if scan.patient else "Tanpa Nama",
            "id_rm": scan.patient.id_pasien_rs if scan.patient else "-",
            "catatan_teknis": catatan_val
        })
    return results

@app.get("/analisis/{analysis_id}")
def get_analysis_detail(analysis_id: int, db: Session = Depends(get_db)):
    scan = db.query(models.MRIScan).filter(models.MRIScan.id == analysis_id).first()
    if not scan: raise HTTPException(status_code=404, detail="Data MRI tidak ditemukan")

    detected_list = []
    if scan.detected_regions:
        try:
            detected_list = json.loads(scan.detected_regions)
        except (json.JSONDecodeError, TypeError):
            pass
    
    meta = {}
    if scan.catatan_teknis and "{" in scan.catatan_teknis:
        try:
            meta = json.loads(scan.catatan_teknis)
        except (json.JSONDecodeError, TypeError):
            pass

    paths_3d = {}
    if scan.filepath_3d and "{" in scan.filepath_3d:
        try:
            paths_3d = json.loads(scan.filepath_3d)
        except (json.JSONDecodeError, TypeError):
            paths_3d = {"all": scan.filepath_3d}
    else:
        paths_3d = {"all": scan.filepath_3d}

    # Konversi Zona Waktu
    tz_jkt = pytz.timezone('Asia/Jakarta')
    if scan.upload_date:
        if scan.upload_date.tzinfo is None:
            waktu_utc = scan.upload_date.replace(tzinfo=pytz.utc)
            waktu_lokal = waktu_utc.astimezone(tz_jkt)
        else:
            waktu_lokal = scan.upload_date.astimezone(tz_jkt)
        waktu_scan_cantik = waktu_lokal.strftime("%d/%m/%Y • %H:%M WIB")
    else:
        waktu_scan_cantik = "-"

    return {
        "id": scan.id,
        "image_url": "dynamic", 
        "paths_3d": paths_3d,
        "result": scan.hasil_prediksi,

        "waktu_scan": waktu_scan_cantik,
        "nama_pasien": scan.patient.nama if scan.patient else "-",
        "id_rm": scan.patient.id_pasien_rs if scan.patient else "-",
        "tgl_lahir": scan.patient.tanggal_lahir if scan.patient else "-",
        "jenis_kelamin": scan.patient.jenis_kelamin if scan.patient else "-",
        "notes_radiolog": meta.get("catatan", "-"), 
        "notes_dokter": getattr(scan, "catatan_dokter", "Belum ada catatan dokter"),
        "detected_regions": detected_list,
        "metrics": meta.get("metrics"),
        "shape": meta.get("shape", [155, 240, 240]),
        "model_type": meta.get("model_type", "unknown"),
        "inference_time_seconds": meta.get("inference_time_seconds"),
    }

@app.get("/get-image/{filename}")
async def get_image_manual(filename: str, db: Session = Depends(get_db)):
    file_path = os.path.join(UPLOAD_DIR, filename)
    if os.path.exists(file_path):
        return FileResponse(file_path, headers={"Access-Control-Allow-Origin": "*", "Cache-Control": "no-cache"})
    return {"error": "File tidak ditemukan"}

@app.put("/analisis/{analysis_id}/update-notes/")
async def update_doctor_notes(analysis_id: int, data: dict, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    scan = db.query(models.MRIScan).filter(models.MRIScan.id == analysis_id).first()
    if not scan: raise HTTPException(status_code=404, detail="Data MRI tidak ditemukan")
    
    new_notes = data.get("notes_dokter", "")
    scan.catatan_dokter = new_notes
    db.commit()
    db.refresh(scan)

    nama_pasien = scan.patient.nama if scan.patient else "Tanpa Nama"
    db.add(models.Notification(target_role="Radiolog", title="Catatan Dokter", message=f"Dokter telah menambahkan catatan untuk pasien {nama_pasien}.", analysis_id=scan.id))
    db.commit()

    save_log(db, current_user.username, current_user.role, "Update Notes", f"Update catatan dokter untuk Scan ID: {analysis_id}")
    return {"status": "sukses", "message": "Catatan berhasil diperbarui", "data": new_notes}

# ENDPOINT SUMMARY
@app.get("/dashboard-summary/", response_model=schemas.DashboardSummary)
def get_summary(db: Session = Depends(get_db)):
    total_p = db.query(models.Patient).count()
    menunggu = db.query(models.MRIScan).filter(models.MRIScan.hasil_prediksi == "Sedang Dianalisis...").count()
    selesai = db.query(models.MRIScan).filter(models.MRIScan.hasil_prediksi != "Sedang Dianalisis...").count()
    return {"total_pasien": total_p, "total_menunggu": menunggu, "total_selesai": selesai}

@app.get("/logs/", response_model=List[schemas.LogResponse])
def get_logs(role: str = None, start_date: str = None, end_date: str = None, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    query = db.query(models.ActivityLog)
    if role and role != "Semua": query = query.filter(models.ActivityLog.role == role)
    if start_date and end_date:
        try:
            start = datetime.strptime(start_date, "%Y-%m-%d")
            end = datetime.strptime(end_date, "%Y-%m-%d").replace(hour=23, minute=59, second=59)
            query = query.filter(models.ActivityLog.timestamp >= start)
            query = query.filter(models.ActivityLog.timestamp <= end)
        except ValueError: pass
        
    logs = query.order_by(models.ActivityLog.timestamp.desc()).all()
    tz_jkt = pytz.timezone('Asia/Jakarta')
    results = []
    
    for log in logs:
        if log.timestamp:
            if log.timestamp.tzinfo is None:
                waktu_utc = log.timestamp.replace(tzinfo=pytz.utc)
                waktu_lokal = waktu_utc.astimezone(tz_jkt)
            else:
                waktu_lokal = log.timestamp.astimezone(tz_jkt)
        else:
            waktu_lokal = None

        results.append({
            "id": log.id,
            "username": log.username,
            "role": log.role,
            "activity": log.activity,
            "details": log.details,
            "timestamp": waktu_lokal
        })
        
    return results

@app.get("/notifications/")
def get_notifications(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    notifs = db.query(models.Notification).filter(func.lower(models.Notification.target_role) == func.lower(current_user.role)).order_by(models.Notification.created_at.desc()).all()
    
    tz_jkt = pytz.timezone('Asia/Jakarta')
    results = []
    
    for n in notifs:
        if not n.created_at:
            tgl_cantik = "-"
        else:
            if n.created_at.tzinfo is None:
                waktu_utc = n.created_at.replace(tzinfo=pytz.utc)
                waktu_lokal = waktu_utc.astimezone(tz_jkt)
            else:
                waktu_lokal = n.created_at.astimezone(tz_jkt)
            
            tgl_cantik = waktu_lokal.strftime("%d/%m/%Y • %H:%M WIB")

        results.append({
            "id": n.id, 
            "title": n.title, 
            "message": n.message, 
            "analysis_id": n.analysis_id, 
            "is_read": n.is_read, 
            "created_at": tgl_cantik
        })
        
    return results

@app.put("/notifications/{notif_id}/read")
def mark_notification_read(notif_id: int, db: Session = Depends(get_db)):
    notif = db.query(models.Notification).filter(models.Notification.id == notif_id).first()
    if notif:
        notif.is_read = True
        db.commit()
    return {"status": "sukses"}