import torch
import torch.nn as nn
import torch.nn.functional as F


def window_partition(x, ws):
    B, C, H, W, D = x.shape
    pad_h = (ws - H % ws) % ws
    pad_w = (ws - W % ws) % ws
    pad_d = (ws - D % ws) % ws

    x = F.pad(x, (0, pad_d, 0, pad_w, 0, pad_h))
    Hp, Wp, Dp = H + pad_h, W + pad_w, D + pad_d

    x = x.view(B, C,
               Hp // ws, ws,
               Wp // ws, ws,
               Dp // ws, ws)
    x = x.permute(0,2,4,6,1,3,5,7).contiguous()

    return x.view(-1, C, ws, ws, ws), (H, W, D)


def window_reverse(x, ws, original_shape):
    H, W, D = original_shape
    Hp = (H + ws - 1) // ws * ws
    Wp = (W + ws - 1) // ws * ws
    Dp = (D + ws - 1) // ws * ws

    B = int(x.shape[0] / (Hp * Wp * Dp / ws**3))

    x = x.view(B,
               Hp // ws,
               Wp // ws,
               Dp // ws,
               -1,
               ws, ws, ws)

    x = x.permute(0,4,1,5,2,6,3,7).contiguous()
    x = x.view(B, -1, Hp, Wp, Dp)

    return x[:, :, :H, :W, :D]


def flatten_3d(x):
    return x.flatten(2).transpose(1, 2)


def unflatten_3d(x, H, W, D):
    return x.transpose(1, 2).view(x.shape[0], -1, H, W, D)


class CrossAttention(nn.Module):
    def __init__(self, dim, heads=2):
        super().__init__()
        self.attn = nn.MultiheadAttention(dim, heads, batch_first=True)

    def forward(self, q, k, v):
        out, _ = self.attn(q, k, v)
        return out


class MSA(nn.Module):
    def __init__(self, dim, heads=2):
        super().__init__()
        self.attn = nn.MultiheadAttention(dim, heads, batch_first=True)

    def forward(self, x):
        out, _ = self.attn(x, x, x)
        return out


class MBConv(nn.Module):
    def __init__(self, dim):
        super().__init__()
        self.block = nn.Sequential(
            nn.Conv3d(dim, dim * 2, 1),
            nn.GELU(),
            nn.Conv3d(dim * 2, dim * 2, 3, padding=1, groups=dim * 2),
            nn.GELU(),
            nn.Conv3d(dim * 2, dim, 1),
        )

    def forward(self, x):
        return self.block(x)


class SelfModalBlock(nn.Module):
    def __init__(self, dim, ws=4):
        super().__init__()
        self.ws = ws
        self.norm1 = nn.LayerNorm(dim)
        self.attn = MSA(dim)
        self.norm2 = nn.InstanceNorm3d(dim)
        self.mbconv = MBConv(dim)

    def forward(self, x):
        xw, shape = window_partition(x, self.ws)

        t = flatten_3d(xw)
        shortcut_t = t

        t = self.norm1(t)
        t = self.attn(t)
        t = t + shortcut_t

        xw = unflatten_3d(t, self.ws, self.ws, self.ws)
        x = window_reverse(xw, self.ws, shape)

        shortcut = x

        x = self.norm2(x)
        x = self.mbconv(x)
        x = x + shortcut

        return x


class CrossModalBlock(nn.Module):
    def __init__(self, dim, ws=4):
        super().__init__()
        self.ws = ws
        self.norm = nn.LayerNorm(dim)
        self.cross_attn = CrossAttention(dim)

    def forward(self, x1, x2):
        shift = self.ws // 2
        x1 = torch.roll(x1, (-shift, -shift, -shift), dims=(2, 3, 4))
        x2 = torch.roll(x2, (-shift, -shift, -shift), dims=(2, 3, 4))

        x1w, shape1 = window_partition(x1, self.ws)
        x2w, shape2 = window_partition(x2, self.ws)

        t1 = flatten_3d(x1w)
        t2 = flatten_3d(x2w)

        s1 = t1
        s2 = t2

        t1 = self.norm(t1)
        t2 = self.norm(t2)

        mt1 = self.cross_attn(t1, t2, t2)
        mt2 = self.cross_attn(t2, t1, t1)

        t1 = t1 + mt1 + s1
        t2 = t2 + mt2 + s2

        x1 = unflatten_3d(t1, self.ws, self.ws, self.ws)
        x2 = unflatten_3d(t2, self.ws, self.ws, self.ws)

        x1 = window_reverse(x1, self.ws, shape1)
        x2 = window_reverse(x2, self.ws, shape2)

        return x1, x2


class MCCA(nn.Module):
    def __init__(self, dim):
        super().__init__()
        self.self1 = SelfModalBlock(dim)
        self.self2 = SelfModalBlock(dim)
        self.cross = CrossModalBlock(dim)

    def forward(self, x1, x2):
        x1 = self.self1(x1)
        x2 = self.self2(x2)
        x1, x2 = self.cross(x1, x2)
        return x1, x2


class ConvBlock(nn.Module):
    def __init__(self, in_c, out_c):
        super().__init__()
        self.block = nn.Sequential(
            nn.Conv3d(in_c, out_c, 3, padding=1),
            nn.InstanceNorm3d(out_c),
            nn.ReLU(inplace=True),
            nn.Conv3d(out_c, out_c, 3, padding=1),
            nn.InstanceNorm3d(out_c),
            nn.ReLU(inplace=True),
        )

    def forward(self, x):
        return self.block(x)


class ConvStem(nn.Module):
    def __init__(self, in_c=1, base_c=16):
        super().__init__()
        self.conv1 = nn.Sequential(
            nn.Conv3d(in_c, base_c, 3, stride=2, padding=1),
            nn.InstanceNorm3d(base_c),
            nn.ReLU(inplace=True)
        )
        self.conv2 = nn.Sequential(
            nn.Conv3d(base_c, base_c * 2, 3, stride=2, padding=1),
            nn.InstanceNorm3d(base_c * 2),
            nn.ReLU(inplace=True)
        )

    def forward(self, x):
        c1 = self.conv1(x)
        c2 = self.conv2(c1)
        return c1, c2


class SEBlock(nn.Module):
    def __init__(self, c):
        super().__init__()
        self.pool = nn.AdaptiveAvgPool3d(1)
        self.fc = nn.Sequential(
            nn.Linear(c, c // 4),
            nn.ReLU(inplace=True),
            nn.Linear(c // 4, c),
            nn.Sigmoid()
        )

    def forward(self, x):
        b, c, _, _, _ = x.shape
        w = self.pool(x).view(b, c)
        w = self.fc(w).view(b, c, 1, 1, 1)
        return x * w


class Bottleneck(nn.Module):
    def __init__(self, dim):
        super().__init__()
        self.block1 = ConvBlock(dim, dim)
        self.block2 = ConvBlock(dim, dim)
        self.se = SEBlock(dim)

    def forward(self, x):
        x = self.block1(x)
        x = self.block2(x)
        x = self.se(x)
        return x


class TCFC(nn.Module):
    def __init__(self, in_c, skip_c):
        super().__init__()

        self.proj_x = nn.Conv3d(in_c, in_c, 1)
        self.proj_s = nn.Conv3d(skip_c, in_c, 1)

        self.conv_xyz = nn.Conv3d(in_c * 3, in_c, 3, padding=1)
        self.conv_attn = nn.Conv3d(in_c, in_c, 1)

        self.sigmoid = nn.Sigmoid()

        self.fuse = nn.Sequential(
            nn.Conv3d(in_c * 2, in_c, 3, padding=1),
            nn.InstanceNorm3d(in_c),
            nn.ReLU(inplace=True)
        )

    def forward(self, x, skip):
        if x.shape[2:] != skip.shape[2:]:
            x = F.interpolate(x, size=skip.shape[2:], mode="trilinear", align_corners=False)

        x = self.proj_x(x)
        s = self.proj_s(skip)

        f = x + s

        fx = torch.mean(f, dim=2, keepdim=True)
        fy = torch.mean(f, dim=3, keepdim=True)
        fz = torch.mean(f, dim=4, keepdim=True)

        fx = fx.expand_as(f)
        fy = fy.expand_as(f)
        fz = fz.expand_as(f)

        f_xyz = torch.cat([fx, fy, fz], dim=1)

        attn = self.conv_xyz(f_xyz)
        attn = self.conv_attn(attn)
        attn = self.sigmoid(attn)

        x_out = x * attn + x
        s_out = s * attn + s

        out = torch.cat([x_out, s_out], dim=1)
        out = self.fuse(out)

        return out


class CKD_TransBTS(nn.Module):
    def __init__(self, num_classes=5, base_c=16):
        super().__init__()

        self.cs_t1c = ConvStem(1, base_c)
        self.cs_t1n = ConvStem(1, base_c)
        self.cs_t2f = ConvStem(1, base_c)
        self.cs_t2w = ConvStem(1, base_c)

        self.t1_reduce = nn.Conv3d(base_c * 4, base_c * 2, 1)
        self.t2_reduce = nn.Conv3d(base_c * 4, base_c * 2, 1)

        self.mcca1 = MCCA(base_c * 2)
        self.mcca2 = MCCA(base_c * 2)
        self.mcca3 = MCCA(base_c * 2)

        self.bottleneck = Bottleneck(base_c * 4)

        self.up3 = nn.ConvTranspose3d(base_c * 4, base_c * 2, 2, 2)
        self.up2 = nn.ConvTranspose3d(base_c * 2, base_c * 2, 2, 2)

        self.tcfc3 = TCFC(base_c * 2, base_c * 2)
        self.tcfc2 = TCFC(base_c * 2, base_c * 2)

        self.skip_l2_reduce = nn.Conv3d(base_c * 4, base_c * 2, 1)
        self.skip_l1_reduce = nn.Conv3d(base_c * 4, base_c * 2, 1)
        self.skip_reduce = nn.Conv3d(base_c * 4, base_c * 2, 1)

        self.conv_dec1 = ConvBlock(base_c * 2, base_c * 2)
        self.conv_dec2 = ConvBlock(base_c * 2, base_c * 2)

        self.final_conv1 = nn.Conv3d(base_c * 2, base_c * 2, 3, padding=1)
        self.final_norm1 = nn.InstanceNorm3d(base_c * 2)

        self.final_conv2 = nn.Conv3d(base_c * 2, num_classes, 3, padding=1)

    def forward(self, t1c, t1n, t2f, t2w):

        t1c_s, t1c_f = self.cs_t1c(t1c)
        t1n_s, t1n_f = self.cs_t1n(t1n)
        t2f_s, t2f_f = self.cs_t2f(t2f)
        t2w_s, t2w_f = self.cs_t2w(t2w)

        t1 = torch.cat([t1c_f, t1n_f], dim=1)
        t2 = torch.cat([t2f_f, t2w_f], dim=1)

        t1 = self.t1_reduce(t1)
        t2 = self.t2_reduce(t2)

        t1_l1, t2_l1 = self.mcca1(t1, t2)
        t1_l2, t2_l2 = self.mcca2(t1_l1, t2_l1)
        t1_l3, t2_l3 = self.mcca3(t1_l2, t2_l2)

        x = torch.cat([t1_l3, t2_l3], dim=1)
        x = self.bottleneck(x)

        x = self.up3(x)

        skip1 = torch.cat([t1_l2, t2_l2], dim=1)
        skip1 = self.skip_l2_reduce(skip1)
        x = self.tcfc3(x, skip1)

        x = self.conv_dec1(x)

        x = self.up2(x)

        skip2 = torch.cat([t1_l1, t2_l1], dim=1)
        skip2 = self.skip_l1_reduce(skip2)
        x = self.tcfc2(x, skip2)

        x = self.conv_dec2(x)

        skip0 = torch.cat([t1c_s, t1n_s, t2f_s, t2w_s], dim=1)
        skip0 = self.skip_reduce(skip0)

        if x.shape[2:] != skip0.shape[2:]:
            x = F.interpolate(x, size=skip0.shape[2:], mode="trilinear", align_corners=False)

        x = x + skip0

        x = F.relu(self.final_norm1(self.final_conv1(x)))
        x = self.final_conv2(x)

        return x