"""
models_ckd/paper_transforms.py

Custom MONAI transforms untuk pipeline Paper — direplikasi dari notebook
`CKD_TransBTS_Paper___5_.ipynb`.

Jangan ganti dengan MONAI built-in transforms — preprocessing Paper di
notebook memang pakai custom logic, dan hasil model bergantung distribusi
data yang persis sama.
"""

from typing import Sequence, Hashable, Mapping

import numpy as np
import torch
import torch.nn.functional as F
from monai.transforms import MapTransform


# ============================================================
# CropNonZeroBoundingBoxd
# ============================================================

class CropNonZeroBoundingBoxd(MapTransform):
    """
    Crop image (dan label optional) ke nonzero bounding box dengan margin 1 voxel.
    Match notebook Paper cell ~306-371 PERSIS.

    Aggregasi: `torch.sum(image, dim=0) != 0` (BUKAN `.any()`).
    Margin: min-1 (clamp 0), max+1.
    Output ke meta dict: `nonzero_indexes` = tuple of 3 (start, end) tuples.

    CATATAN: direct tensor slicing TIDAK update MetaTensor affine.
    Reconstruction menggunakan `nonzero_indexes` untuk meletakkan prediksi di
    lokasi yang benar pada volume asli.
    """

    def __init__(self, image_key: str = "image", label_key: str = "label"):
        super().__init__([image_key])
        self.image_key = image_key
        self.label_key = label_key

    def _compute_bbox(self, image):
        is_tensor = torch.is_tensor(image)

        if is_tensor:
            agg = torch.sum(image, dim=0)   # (D, H, W)
            nz = torch.nonzero(agg != 0)
            if len(nz) == 0:
                return None
            z_min = max(0, int(torch.min(nz[:, 0])) - 1)
            y_min = max(0, int(torch.min(nz[:, 1])) - 1)
            x_min = max(0, int(torch.min(nz[:, 2])) - 1)
            z_max = int(torch.max(nz[:, 0])) + 1
            y_max = int(torch.max(nz[:, 1])) + 1
            x_max = int(torch.max(nz[:, 2])) + 1
        else:
            agg = np.sum(image, axis=0)
            nz = np.argwhere(agg != 0)
            if len(nz) == 0:
                return None
            z_min = max(0, int(nz[:, 0].min()) - 1)
            y_min = max(0, int(nz[:, 1].min()) - 1)
            x_min = max(0, int(nz[:, 2].min()) - 1)
            z_max = int(nz[:, 0].max()) + 1
            y_max = int(nz[:, 1].max()) + 1
            x_max = int(nz[:, 2].max()) + 1

        return (z_min, z_max), (y_min, y_max), (x_min, x_max)

    def __call__(self, data: Mapping) -> dict:
        d = dict(data)
        image = d[self.image_key]

        bbox = self._compute_bbox(image)
        if bbox is None:
            d["nonzero_indexes"] = None
            return d

        (z_min, z_max), (y_min, y_max), (x_min, x_max) = bbox
        spatial_slices = (slice(z_min, z_max), slice(y_min, y_max), slice(x_min, x_max))
        full_slices = (slice(None),) + spatial_slices

        d[self.image_key] = image[full_slices]

        if self.label_key in d and d[self.label_key] is not None:
            label = d[self.label_key]
            if torch.is_tensor(label):
                if label.ndim == 4:
                    d[self.label_key] = label[full_slices]
                elif label.ndim == 3:
                    d[self.label_key] = label[spatial_slices]
            else:
                arr = np.asarray(label)
                if arr.ndim == 4:
                    d[self.label_key] = arr[full_slices]
                elif arr.ndim == 3:
                    d[self.label_key] = arr[spatial_slices]

        # CRITICAL untuk reconstruction:
        d["nonzero_indexes"] = (
            (int(z_min), int(z_max)),
            (int(y_min), int(y_max)),
            (int(x_min), int(x_max)),
        )
        return d


# ============================================================
# MinMaxNormalized
# Per-channel: (img - img.min()) / (img.max() - img.min() + eps)
# ============================================================

class MinMaxNormalized(MapTransform):
    """Per-channel min-max normalization → [0, 1]."""

    def __init__(self, keys: Sequence[Hashable] = ("image",), eps: float = 1e-7):
        super().__init__(keys)
        self.eps = eps

    def __call__(self, data: Mapping) -> dict:
        d = dict(data)
        for key in self.keys:
            img = d[key]  # (C, ...)
            if torch.is_tensor(img):
                img = img.float()
                out = torch.empty_like(img)
                for c in range(img.shape[0]):
                    ch = img[c]
                    mn = ch.min()
                    mx = ch.max()
                    out[c] = (ch - mn) / (mx - mn + self.eps)
                d[key] = out
            else:
                arr = np.asarray(img, dtype=np.float32)
                out = np.empty_like(arr)
                for c in range(arr.shape[0]):
                    ch = arr[c]
                    mn = ch.min()
                    mx = ch.max()
                    out[c] = (ch - mn) / (mx - mn + self.eps)
                d[key] = out
        return d


# ============================================================
# PadToMinSized
# Pad ke minimal min_size; kalau sudah lebih besar, biarkan.
# ============================================================

class PadToMinSized(MapTransform):
    """
    Pad tiap spatial dim hanya jika lebih kecil dari min_size.
    Menggunakan right-side-only padding (bukan center padding) untuk menyamakan
    dengan perilaku model di notebook training Paper.
    """

    def __init__(
        self,
        keys: Sequence[Hashable],
        min_size: Sequence[int] = (128, 128, 128),
        mode: str = "constant",
        value: float = 0.0,
    ):
        super().__init__(keys)
        self.min_size = tuple(min_size)
        self.mode = mode
        self.value = value

    def __call__(self, data: Mapping) -> dict:
        """
        Right-side-only padding match notebook Paper cell ~799.
        pad_list format: [W_left, W_right, H_left, H_right, D_left, D_right]
        (F.pad order: last spatial dim first).
        """
        d = dict(data)
        ref = d[self.keys[0]]
        # Asumsi shape (C, D, H, W)
        _, depth, height, width = ref.shape

        pad_d = max(0, self.min_size[0] - depth)
        pad_h = max(0, self.min_size[1] - height)
        pad_w = max(0, self.min_size[2] - width)

        # CRITICAL: pad hanya di sisi kanan/bawah/belakang
        pad_list = [0, pad_w, 0, pad_h, 0, pad_d]

        # Simpan metadata untuk unpad nanti saat reconstruction
        d["pad_list"] = pad_list
        d[f"{self.keys[0]}_shape_before_pad"] = [int(depth), int(height), int(width)]

        if sum(pad_list) > 0:
            for key in self.keys:
                if key not in d or d[key] is None:
                    continue
                arr = d[key]
                if torch.is_tensor(arr):
                    d[key] = F.pad(arr, pad_list, mode=self.mode, value=self.value)
                else:
                    # numpy fallback: spatial dims terurut (D, H, W)
                    # F.pad mengkonsumsi last-dim-first, jadi convert balik
                    pad_d_l, pad_d_r = pad_list[4], pad_list[5]
                    pad_h_l, pad_h_r = pad_list[2], pad_list[3]
                    pad_w_l, pad_w_r = pad_list[0], pad_list[1]
                    channel_pads = [(0, 0)] * (arr.ndim - 3) + [(pad_d_l, pad_d_r), (pad_h_l, pad_h_r), (pad_w_l, pad_w_r)]
                    d[key] = np.pad(arr, channel_pads, mode=self.mode, constant_values=self.value)
        return d
