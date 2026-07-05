"""
models_ckd/inference.py

Inference engine untuk CKD-TransBTS Optimisasi (L5) dan Paper.

Konvensi (Fix Brief §1):
  Modalitas  : _0000=t1n, _0001=t1c, _0002=t2w, _0003=t2f
  Label      : 0=BG, 1=NETC, 2=SNFH, 3=ET, 4=RC
  L5 args    : model(t1c, t1n, t2f, t2w) output half-res (D/2,H/2,W/2)
  Paper args : model(x) x[:,0]=t1n,[:,1]=t1c,[:,2]=t2w,[:,3]=t2f full-res sigmoid
  Preprocessing L5 vs Paper BERBEDA -- jangan share pipeline!
"""

import os
import time
from typing import Dict, Tuple

import numpy as np
import nibabel as nib
import torch
import torch.nn.functional as F

from monai.transforms import (
    Compose, LoadImaged, EnsureChannelFirstd, Orientationd, Spacingd,
    ScaleIntensityRangePercentilesd, CropForegroundd, SpatialPadd,
    ConcatItemsd, EnsureTyped, DeleteItemsd,
)
from monai.inferers import sliding_window_inference

from models_ckd.paper_transforms import (
    CropNonZeroBoundingBoxd, MinMaxNormalized, PadToMinSized,
)


MODALITY_SUFFIX = {
    "_0000": "t1n",
    "_0001": "t1c",
    "_0002": "t2w",
    "_0003": "t2f",
}
MODALITIES = ("t1n", "t1c", "t2w", "t2f")

MODEL_CONFIGS = {
    "optimisasi": {
        "checkpoint": "L5FINAL3_COSINE_best_model.pth",
        "roi_size": (64, 64, 64),
        "sw_batch_size": 1,        # ← UBAH dari 2 ke 1 (match notebook)
        "overlap": 0.6,
        "output_classes": 5,
        "output_type": "multiclass_halfres",
        "use_tta": False,          # ← stays False (sudah benar)
    },
    "paper": {
        "checkpoint": "best_model.pth",
        "roi_size": (128, 128, 128),
        "sw_batch_size": 2,        # ← UBAH dari 1 ke 2 (match notebook)
        "overlap": 0.6,
        "output_classes": 4,
        "output_type": "binary_fullres",
        "use_tta": False,          # ← UBAH dari True ke False!
    },
}

CHECKPOINT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "checkpoints"
)


def _build_data_dict(input_dir: str, case_id: str) -> Dict[str, str]:
    data = {}
    for suffix, modality in MODALITY_SUFFIX.items():
        filepath = os.path.join(input_dir, f"{case_id}{suffix}.nii.gz")
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"File modalitas tidak ditemukan: {filepath}")
        data[modality] = filepath
    return data


def preprocess_for_l5(
    input_dir: str,
    case_id: str,
    gt_label_path: str = None,
) -> Tuple[torch.Tensor, dict]:
    """
    Pipeline L5 — match val_transforms notebook L5 (Salinan_L5Final_CKDTransBTS).

    Order: Orientation(RAS) → Spacing(1mm) → ScalePercentiles(1-99) →
           CropForegroundd → SpatialPadd(64) → EnsureTyped.

    Args:
        gt_label_path: jika diberikan dan file exists, CropForegroundd akan
            menggunakan source_key="label" (replicates val_transforms notebook
            persis — gunakan saat ada GT untuk validasi reproduksi angka tesis).
            Jika None atau file tidak ada, fallback ke whole-brain mode tanpa crop
            (mode klinis untuk visualisasi tumor yang terlokasi rapi).
    """
    data_paths = _build_data_dict(input_dir, case_id)

    use_label_crop = gt_label_path is not None and os.path.exists(gt_label_path)

    if use_label_crop:
        print(f"[L5 PREPROCESS] Mode VALIDASI: source_key='label' (match notebook val_transforms)")
        data_paths["label"] = gt_label_path
        all_keys = list(MODALITIES) + ["label"]
        spacing_modes = ("bilinear",) * len(MODALITIES) + ("nearest",)
        crop_transforms = [CropForegroundd(keys=all_keys, source_key="label")]
    else:
        print(f"[L5 PREPROCESS] Mode KLINIS: whole-brain (no crop) — match notebook full_transforms")
        all_keys = list(MODALITIES)
        spacing_modes = ("bilinear",) * len(MODALITIES)
        crop_transforms = []

    pipeline = Compose([
        LoadImaged(keys=all_keys, image_only=False),
        EnsureChannelFirstd(keys=all_keys, channel_dim="no_channel"),
        Orientationd(keys=all_keys, axcodes="RAS"),
        Spacingd(keys=all_keys, pixdim=(1.0, 1.0, 1.0), mode=spacing_modes),
        ScaleIntensityRangePercentilesd(
            keys=list(MODALITIES), lower=1, upper=99,
            b_min=0.0, b_max=1.0, clip=True,
        ),
        *crop_transforms,
        SpatialPadd(keys=all_keys, spatial_size=(64, 64, 64)),
        EnsureTyped(keys=all_keys, dtype=torch.float32),
    ])

    out = pipeline(data_paths)

    x = torch.stack([
        out["t1c"][0],
        out["t1n"][0],
        out["t2f"][0],
        out["t2w"][0],
    ], dim=0).unsqueeze(0)

    orig_nii = nib.load(data_paths["t1c"])
    meta = {
        "preprocessed_affine": out["t1c"].meta["affine"].numpy(),
        "original_affine": orig_nii.affine,
        "original_shape": orig_nii.shape,
        "original_header": orig_nii.header,
    }
    return x, meta


def preprocess_for_paper(input_dir: str, case_id: str) -> Tuple[torch.Tensor, dict]:
    """
    Pipeline Paper — match notebook val_transforms.
    """
    data_paths = _build_data_dict(input_dir, case_id)
    all_keys = list(MODALITIES)

    pipeline = Compose([
        LoadImaged(keys=all_keys, image_only=False),
        EnsureChannelFirstd(keys=all_keys, channel_dim="no_channel"),
        ConcatItemsd(keys=list(MODALITIES), name="image", dim=0),
        DeleteItemsd(keys=all_keys),
        CropNonZeroBoundingBoxd(image_key="image"),
        MinMaxNormalized(keys=("image",)),
        PadToMinSized(keys=("image",), min_size=(128, 128, 128)),
        EnsureTyped(keys=("image",), dtype=torch.float32),
    ])

    out = pipeline(data_paths)
    x = out["image"].unsqueeze(0)

    orig_nii = nib.load(data_paths["t1c"])
    meta = {
        "original_affine": orig_nii.affine,
        "original_shape": tuple(orig_nii.shape),
        "original_header": orig_nii.header,
        # CRITICAL: untuk reconstruction
        "nonzero_indexes": out.get("nonzero_indexes"),
        "pad_list": out.get("pad_list"),
        "shape_before_pad": out.get("image_shape_before_pad"),
        "mode": "paper",
    }
    return x, meta


_loaded_models: Dict[str, torch.nn.Module] = {}


def load_model(model_type: str, device: torch.device) -> torch.nn.Module:
    if model_type in _loaded_models:
        print(f"[MODEL] Menggunakan cache: {model_type}")
        return _loaded_models[model_type]

    config = MODEL_CONFIGS[model_type]
    checkpoint_path = os.path.join(CHECKPOINT_DIR, config["checkpoint"])

    if not os.path.exists(checkpoint_path):
        raise FileNotFoundError(f"Checkpoint tidak ditemukan: {checkpoint_path}")

    print(f"[MODEL] Loading {model_type} dari {checkpoint_path}...")

    if model_type == "optimisasi":
        from models_ckd.ckd_transbts_l5 import CKD_TransBTS
        model = CKD_TransBTS(num_classes=5, base_c=16)
    elif model_type == "paper":
        from models_ckd.ckd_transbts_paper import CKD
        model = CKD(
            embed_dim=32, output_dim=4,
            img_size=(128, 128, 128), patch_size=(4, 4, 4),
            in_chans=1, depths=[2, 2, 2],
            num_heads=[2, 4, 8, 16], window_size=(7, 7, 7), mlp_ratio=4.0,
        )
    else:
        raise ValueError(f"Model type tidak dikenal: {model_type!r}")

    ckpt = torch.load(checkpoint_path, map_location=device, weights_only=False)
    if isinstance(ckpt, dict):
        state_dict = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
    else:
        raise ValueError(f"Format checkpoint tidak dikenali untuk {model_type}")

    model.load_state_dict(state_dict, strict=True)
    model = model.to(device).eval()
    _loaded_models[model_type] = model
    n_params = sum(p.numel() for p in model.parameters())
    print(f"[MODEL] {model_type} ready ({n_params:,} params)")
    return model


def _sliding_window(model, x, config, model_type):
    if model_type == "optimisasi":
        predictor = lambda inp: model(inp[:, 0:1], inp[:, 1:2], inp[:, 2:3], inp[:, 3:4])
    else:
        predictor = lambda inp: model(inp)
    return sliding_window_inference(
        inputs=x, roi_size=config["roi_size"],
        sw_batch_size=config["sw_batch_size"],
        predictor=predictor, overlap=config["overlap"], mode="gaussian",
    )


def _sliding_window_tta(model, x, config, model_type):
    """8-fold flip TTA sesuai notebook Paper. Returns averaged sigmoid probs."""
    def _s(inp):
        return torch.sigmoid(_sliding_window(model, inp, config, model_type))

    pred = _s(x)
    pred += _s(x.flip(2)).flip(2)
    pred += _s(x.flip(3)).flip(3)
    pred += _s(x.flip(4)).flip(4)
    pred += _s(x.flip([2, 3])).flip([2, 3])
    pred += _s(x.flip([2, 4])).flip([2, 4])
    pred += _s(x.flip([3, 4])).flip([3, 4])
    pred += _s(x.flip([2, 3, 4])).flip([2, 3, 4])
    return pred / 8.0


def run_inference(model, x, model_type, device):
    """
    Sliding window inference + post-processing.
    Returns uint8 numpy (D,H,W) values 0..4 di koordinat preprocessed.
    """
    config = MODEL_CONFIGS[model_type]
    x = x.to(device)

    with torch.no_grad():
        if config["use_tta"]:
            pred = _sliding_window_tta(model, x, config, model_type)
            from models_ckd.ckd_transbts_paper import convert_binary_to_multiclass
            pred_labels = convert_binary_to_multiclass(pred[0].cpu().numpy(), threshold=0.5)
        else:
            pred = _sliding_window(model, x, config, model_type)
            if config["output_type"] == "multiclass_halfres":
                if pred.shape[2:] != x.shape[2:]:
                    pred = F.interpolate(pred, size=x.shape[2:], mode="trilinear", align_corners=False)
                pred_labels = torch.argmax(pred, dim=1)[0].cpu().numpy().astype(np.uint8)
            elif config["output_type"] == "binary_fullres":
                from models_ckd.ckd_transbts_paper import convert_binary_to_multiclass
                pred_labels = convert_binary_to_multiclass(torch.sigmoid(pred)[0].cpu().numpy())
            else:
                raise ValueError(f"output_type tidak dikenal: {config['output_type']!r}")

    return pred_labels


def resample_to_original_grid(pred_labels, preprocessed_affine, original_affine, original_shape, original_header):
    """Resample prediksi ke grid MRI asli (nearest-neighbor, order=0)."""
    from nibabel.processing import resample_from_to

    pred_in_preproc = nib.Nifti1Image(pred_labels.astype(np.uint8), affine=preprocessed_affine)
    ref = nib.Nifti1Image(np.zeros(original_shape, dtype=np.uint8), affine=original_affine, header=original_header)
    pred_in_orig = resample_from_to(pred_in_preproc, ref, order=0, mode="constant", cval=0)

    final = nib.Nifti1Image(
        np.round(pred_in_orig.get_fdata()).astype(np.uint8),
        affine=original_affine, header=original_header,
    )
    final.set_data_dtype(np.uint8)
    return final


def reconstruct_to_original_paper(
    pred_labels: np.ndarray,
    meta: dict,
) -> nib.Nifti1Image:
    """
    Place Paper prediction back into original MRI volume.

    Reconstruction approach (notebook-style):
    1. Unpad pred (remove right-side padding) — pakai pad_list dari PadToMinSized
    2. Create empty volume di shape MRI asli
    3. Place pred di bbox location dari nonzero_indexes
    4. Save dengan affine + header MRI asli
    """
    # 1. UNPAD — remove right-side padding
    # pad_list format: [W_left, W_right, H_left, H_right, D_left, D_right]
    if meta.get("pad_list") is not None and sum(meta["pad_list"]) > 0:
        pad_list = meta["pad_list"]
        w_l, w_r, h_l, h_r, d_l, d_r = pad_list[:6]
        D, H, W = pred_labels.shape
        # numpy spatial order (D, H, W) — unpad dari kanan
        d_end = D - d_r if d_r > 0 else D
        h_end = H - h_r if h_r > 0 else H
        w_end = W - w_r if w_r > 0 else W
        pred_unpadded = pred_labels[d_l:d_end, h_l:h_end, w_l:w_end]
    else:
        pred_unpadded = pred_labels

    # 2. Create empty volume di shape original
    original_shape = tuple(meta["original_shape"])
    full_pred = np.zeros(original_shape, dtype=np.uint8)

    # 3. Place pred di bbox location dari nonzero_indexes
    if meta.get("nonzero_indexes") is not None:
        (z0, z1), (y0, y1), (x0, x1) = meta["nonzero_indexes"]
        expected_shape = (z1 - z0, y1 - y0, x1 - x0)

        if pred_unpadded.shape != expected_shape:
            # Tolerate small mismatch karena rounding di pad/unpad
            print(f"[WARN] reconstruction shape mismatch: pred {pred_unpadded.shape} vs bbox {expected_shape}")
            min_z = min(pred_unpadded.shape[0], z1 - z0)
            min_y = min(pred_unpadded.shape[1], y1 - y0)
            min_x = min(pred_unpadded.shape[2], x1 - x0)
            full_pred[z0:z0+min_z, y0:y0+min_y, x0:x0+min_x] = \
                pred_unpadded[:min_z, :min_y, :min_x]
        else:
            full_pred[z0:z1, y0:y1, x0:x1] = pred_unpadded
    else:
        # Fallback: tidak ada bbox info — kemungkinan input semua zero
        print("[WARN] no nonzero_indexes; pred kemungkinan kosong")

    # 4. Build NIfTI dengan affine + header asli
    nii = nib.Nifti1Image(
        full_pred,
        affine=meta["original_affine"],
        header=meta["original_header"],
    )
    nii.set_data_dtype(np.uint8)
    return nii


def predict_segmentation(
    input_dir: str,
    output_dir: str,
    case_id: str,
    model_type: str = "optimisasi",
    gt_label_path: str = None,
) -> Tuple[str, float]:
    """
    Pipeline lengkap: preprocess -> inference -> reconstruction -> save NIfTI.
    Returns (pred_path, inference_time_seconds).
    """
    if model_type not in MODEL_CONFIGS:
        raise ValueError(f"model_type harus 'optimisasi' atau 'paper', dapat: {model_type!r}")

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[INFERENCE] device={device}, model={model_type}, case={case_id}")

    if model_type == "optimisasi":
        x, meta = preprocess_for_l5(input_dir, case_id, gt_label_path=gt_label_path)
    else:
        x, meta = preprocess_for_paper(input_dir, case_id)

    print(f"[INFERENCE] preprocessed input shape: {tuple(x.shape)}")

    model = load_model(model_type, device)

    if device.type == "cuda":
        torch.cuda.synchronize()
    t0 = time.perf_counter()

    pred_labels_preproc = run_inference(model, x, model_type, device)

    if device.type == "cuda":
        torch.cuda.synchronize()
    inference_time = time.perf_counter() - t0
    print(f"[INFERENCE] selesai {inference_time:.2f}s, shape preproc: {pred_labels_preproc.shape}")

    # CRITICAL: jalur rekonstruksi BEDA per model
    if model_type == "optimisasi":
        # L5: MONAI dict transforms track affine. Pakai resample.
        preproc_affine = meta.get("preprocessed_affine")
        if preproc_affine is None:
            preproc_affine = meta["original_affine"]

        pred_nifti = resample_to_original_grid(
            pred_labels=pred_labels_preproc,
            preprocessed_affine=preproc_affine,
            original_affine=meta["original_affine"],
            original_shape=meta["original_shape"],
            original_header=meta["original_header"],
        )
    else:  # paper
        # Paper: custom transforms tidak update MetaTensor affine.
        # Pakai reconstruction manual dengan nonzero_indexes + pad_list.
        pred_nifti = reconstruct_to_original_paper(pred_labels_preproc, meta)

    print(f"[INFERENCE] resampled ke shape asli: {pred_nifti.shape}")

    assert pred_nifti.shape == tuple(meta["original_shape"]), (
        f"Shape mismatch: {pred_nifti.shape} vs {meta['original_shape']}"
    )

    os.makedirs(output_dir, exist_ok=True)
    pred_path = os.path.join(output_dir, f"{case_id}.nii.gz")
    nib.save(pred_nifti, pred_path)
    print(f"[INFERENCE] saved: {pred_path}")

    return pred_path, inference_time