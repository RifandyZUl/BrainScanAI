"""
Unit tests untuk verifikasi fix Brief V3.

Run: cd backend-tumor && python -m tests.test_paper_transforms
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import torch
from models_ckd.paper_transforms import (
    CropNonZeroBoundingBoxd, MinMaxNormalized, PadToMinSized,
)


def test_crop_uses_sum_with_margin():
    """Fix B: aggregasi sum != 0 + 1-voxel margin"""
    img = torch.zeros(4, 100, 100, 100)
    img[:, 2:8, 3:7, 1:9] = torch.randn(4, 6, 4, 8)

    out = CropNonZeroBoundingBoxd()({"image": img, "label": None})
    # Expected dengan margin: z[1:8], y[2:7], x[0:9]  → shape (4, 7, 5, 9)
    assert out["image"].shape == (4, 7, 5, 9), f"got {out['image'].shape}"
    assert out["nonzero_indexes"] == ((1, 8), (2, 7), (0, 9)), \
        f"got {out['nonzero_indexes']}"
    print("[OK] test_crop_uses_sum_with_margin PASSED")


def test_crop_sum_vs_any_diff():
    """Edge case: sum=0 tapi ada channel nonzero (+1 di ch0, -1 di ch1)"""
    img = torch.zeros(2, 10, 10, 10)
    img[0, 5, 5, 5] = 1.0
    img[1, 5, 5, 5] = -1.0   # sum = 0 → notebook treat sebagai background
    # Tapi any() akan treat sebagai foreground
    out = CropNonZeroBoundingBoxd()({"image": img, "label": None})
    # Dengan sum-based: nonzero_indexes harus None
    assert out["nonzero_indexes"] is None, \
        "sum=0 case harus return None (notebook behavior), tapi got bbox"
    print("[OK] test_crop_sum_vs_any_diff PASSED")


def test_pad_right_only():
    """Fix A: pad hanya di sisi kanan/bawah/belakang"""
    img = torch.zeros(4, 60, 80, 100)
    img[:, 0, 0, 0] = 99.0      # marker depan-atas-kiri
    img[:, 59, 79, 99] = 88.0   # marker pojok akhir brain

    out = PadToMinSized(keys=["image"], min_size=(128, 128, 128))({"image": img})

    assert out["image"].shape == (4, 128, 128, 128)
    # Marker pojok depan-atas-kiri TETAP di (0,0,0)
    assert out["image"][0, 0, 0, 0].item() == 99.0, \
        "Brain pojok harus tetap di (0,0,0) — bukan center pad"
    # Marker akhir brain TETAP di (59, 79, 99)
    assert out["image"][0, 59, 79, 99].item() == 88.0, \
        "Marker akhir brain harus tetap di (59,79,99)"
    # Daerah pad (di belakang) harus zero
    assert out["image"][0, 60:, :, :].sum() == 0
    assert out["image"][0, :, 80:, :].sum() == 0
    assert out["image"][0, :, :, 100:].sum() == 0
    # pad_list format F.pad: [W_l, W_r, H_l, H_r, D_l, D_r]
    assert out["pad_list"] == [0, 28, 0, 48, 0, 68]
    print("[OK] test_pad_right_only PASSED")


def test_pad_no_op_when_already_large():
    img = torch.zeros(4, 200, 50, 100)
    out = PadToMinSized(keys=["image"], min_size=(128, 128, 128))({"image": img})
    assert out["image"].shape == (4, 200, 128, 128)
    assert out["pad_list"] == [0, 28, 0, 78, 0, 0]
    print("[OK] test_pad_no_op_when_already_large PASSED")


def test_minmax_per_channel():
    img = torch.tensor([
        [[0., 1., 2.], [3., 4., 5.]],
        [[10., 20., 30.], [40., 50., 60.]],
    ])
    out = MinMaxNormalized()({"image": img})["image"]
    assert abs(out[0].min().item()) < 1e-5
    assert abs(out[0].max().item() - 1.0) < 1e-5
    assert abs(out[1].min().item()) < 1e-5
    assert abs(out[1].max().item() - 1.0) < 1e-5
    print("[OK] test_minmax_per_channel PASSED")


if __name__ == "__main__":
    test_crop_uses_sum_with_margin()
    test_crop_sum_vs_any_diff()
    test_pad_right_only()
    test_pad_no_op_when_already_large()
    test_minmax_per_channel()
    print("\n[SUCCESS] All tests PASSED — Brief V3 fixes ter-verified")
