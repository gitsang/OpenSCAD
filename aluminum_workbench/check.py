# -*- coding: utf-8 -*-
"""
3030 铝型材工作台 —— 自检脚本
=====================================================================
做法: 用 openscad 命令行做【布尔求交】(在 .scad 里定义 PART="probe"),
      再回读导出的 binary STL 算体积/包围盒。

检查三类东西:
  1. 包围盒 + 体积 ── 有没有漏件 / 重件 / 尺寸写错
  2. 探测盒求交 ── 该空的地方必须真的空(收纳腔 / 抽屉口 / 膝下),
                    该有料的地方必须有料
  3. 负向测试 ── 每个"应该为空"的检查都配一个"挪 30mm 就该有料"的
                 对照, 否则根本不知道这个检查是不是恒真(永远 PASS)

用法:
    & 'C:\\Program Files\\FreeCAD 1.1\\bin\\python.exe' check.py
    ... check.py --quick      # 跳过慢的体积探测
    ... check.py --png        # 顺便出几张预览图
=====================================================================
"""
import os
import re
import struct
import subprocess
import sys

import numpy as np

OPENSCAD = r"C:\Program Files\OpenSCAD\openscad.exe"
HERE = os.path.dirname(os.path.abspath(__file__))
SCAD = os.path.join(HERE, "workbench.scad")
TMP = os.path.join(HERE, "_tmp")
os.makedirs(TMP, exist_ok=True)

QUICK = "--quick" in sys.argv
MAKE_PNG = "--png" in sys.argv

# ---------------------------------------------------------------- 工具
_RESULT = []


def chk(name, ok, detail=""):
    _RESULT.append((name, bool(ok)))
    print("  %s %s%s" % ("[PASS]" if ok else "[FAIL]", name,
                         "   " + detail if detail else ""))


def near(a, b, tol=0.005):
    return abs(a - b) <= tol * max(abs(b), 1e-9)


def gt0(a, tol=1.0):
    return a > tol


def run(part="all", probe_part=None, probe_box=None, out=None, extra=()):
    """跑一次 openscad, 返回它的 stdout+stderr 文本。"""
    if out is None:
        out = os.path.join(TMP, "tmp.stl")
    cmd = [OPENSCAD, "-o", out, "--export-format", "binstl"]
    for e in extra:
        cmd += ["-D", e]
    cmd += ["-D", 'PART="%s"' % part]
    if probe_part is not None:
        cmd += ["-D", 'PROBE_PART="%s"' % probe_part]
    if probe_box is not None:
        cmd += ["-D", "PROBE_BOX=[%s]" % ",".join("%.4f" % v for v in probe_box)]
    cmd.append(SCAD)
    p = subprocess.run(cmd, cwd=HERE, capture_output=True)
    txt = (p.stdout + p.stderr).decode("utf-8", "replace")
    bad = [l for l in txt.splitlines()
           if ("ERROR" in l or "WARNING" in l) and "CHECK|" not in l]
    for l in bad:
        print("      ! " + l.strip())
    return txt


def measure(path):
    """binary STL -> (体积, bbox_min, bbox_max, 三角面数)"""
    data = open(path, "rb").read()
    if len(data) < 84:
        return 0.0, np.zeros(3), np.zeros(3), 0
    n = struct.unpack_from("<I", data, 80)[0]
    if len(data) != 84 + 50 * n:
        raise ValueError("%s: 不是 binary STL (len=%d, n=%d)" % (path, len(data), n))
    if n == 0:
        return 0.0, np.zeros(3), np.zeros(3), 0
    arr = np.frombuffer(data[84:], dtype=np.uint8).reshape(n, 50)
    v = arr[:, 12:48].copy().view("<f4").reshape(n, 3, 3).astype(np.float64)
    vol = abs(np.einsum("ij,ij->i", v[:, 0], np.cross(v[:, 1], v[:, 2])).sum() / 6.0)
    flat = v.reshape(-1, 3)
    return vol, flat.min(0), flat.max(0), n


def export(part, tag=None, extra=()):
    out = os.path.join(TMP, "%s.stl" % (tag or part))
    run(part=part, out=out, extra=extra)
    return out


def probe(part, box, tag, simple=True):
    """布尔求交的体积。SIMPLE=true 用实心方钢截面 -> 快 ~10 倍,
       且它是真模型的超集, 所以 '= 0' 的结论依然成立。"""
    out = os.path.join(TMP, "p_%s.stl" % tag)
    run(part="probe", probe_part=part, probe_box=box, out=out,
        extra=(("SIMPLE=true",) if simple else ()))
    return measure(out)[0]


# ================================================================ 主流程
print("=" * 74)
print("3030 铝型材工作台 自检")
print("=" * 74)

# --- 从 .scad 的 echo 里读回尺寸常量 (避免两边各写一份而漂移) -------
txt = run(part="beam", out=os.path.join(TMP, "beam.stl"))
C = {}
for m in re.finditer(r'CHECK\|([^"]*)"', txt):
    f = m.group(1).split("|")
    C[f[0]] = f[1:]


def num(s):
    try:
        return float(s)
    except ValueError:
        return s


A_BEAM = float(C["A_BEAM"][0])
BEAM_LEN = float(C["TOTAL_BEAM_LEN"][0])
FRAME_VOL = float(C["TOTAL_FRAME_VOL"][0])


def kv(key):
    """CHECK|<key>|<名1>|<值1>|<名2>|<值2>... -> {名: 值}"""
    f = C[key]
    return {f[i]: float(f[i + 1]) for i in range(0, len(f) - 1, 2)}


S = kv("SIZE")
Z = kv("ZLEV")
X = kv("XZON")
W, D, H, P = S["W"], S["D"], S["H"], S["P"]
Z_LEFT, Z_MAIN, CAB_H, Z_TOP = Z["Z_LEFT"], Z["Z_MAIN"], Z["CAB_H"], Z["Z_TOP"]
X_DIV, X_CAB, PANEL_T = X["X_DIV"], X["X_CAB"], X["PANEL_T"]
PEG_NX, PEG_NZ, PEG_T, PEG_H, PEG_W, PEG_Z0 = [float(x) for x in C["PEG"]]
NDRW, DRW_W, DRW_GAP = [float(x) for x in C["DRW"]]
NLG, LEDGE_D, LEDGE_T = [float(x) for x in C["LEDGE"]]
CAB_T, CAB_YD, CAB_ZD = [float(x) for x in C["CAB"]]
ENC_W, ENC_D, ENC_H = [float(x) for x in C["ENC"]]

FH = (CAB_H - P - (NDRW + 1) * DRW_GAP) / NDRW          # 抽屉面板高
X_CAV0, X_CAV1 = P, X_DIV - P / 2                        # 左区腔 30..570
Y_CAV0, Y_CAV1 = P, D - P                                # 30..370
Z_FLOOR = P                                              # 地台面 30
Z_CAV = Z_LEFT + P                                       # 腔顶(台面板下沿) 682
Z_RAIL = Z_LEFT                                          # 腔顶(梁下沿) 652

print("\n从 .scad 读到的常量:")
print("  W,D,H,P          = %.0f, %.0f, %.0f, %.0f" % (W, D, H, P))
print("  截面面积 A_BEAM   = %.4f mm^2" % A_BEAM)
print("  型材总长          = %.1f mm (%.3f m)" % (BEAM_LEN, BEAM_LEN / 1000))
print("  型材体积(理论)    = {:,} mm^3".format(int(FRAME_VOL)))
print("  Z_LEFT/Z_MAIN    = %.0f / %.0f   X_DIV/X_CAB = %.0f / %.0f"
      % (Z_LEFT, Z_MAIN, X_DIV, X_CAB))
print("  洞洞板            = %d x %d 孔, %.0f x %.0f x %.0f"
      % (PEG_NX, PEG_NZ, PEG_W, PEG_H, PEG_T))

# ---------------------------------------------------------------- 1
print("\n[1] 3030 型材截面")
v, mn, mx, nf = measure(os.path.join(TMP, "beam.stl"))
area = v / 1000.0
# 实测会比手算略大一点点: 圆角和中心孔是多边形近似 ($fn=24/16),
# 16 边形孔比真圆小 ~0.9mm^2, 所以容差放到 0.4%
chk("截面面积 = %.3f mm^2  (实测 %.4f)" % (A_BEAM, area), near(area, A_BEAM, 0.004),
    "%.4f mm^2 (%+.3f%% , 多边形近似), 轮廓 %d 面"
    % (area, (area - A_BEAM) / A_BEAM * 100, nf))
chk("截面 bbox = 30 x 30 x 1000", np.allclose(mx - mn, [P, P, 1000], atol=0.02),
    "%.2f x %.2f x %.2f" % tuple(mx - mn))
chk("T 槽确实开出来了 (截面 < 60% 实体)", area < 0.60 * P * P,
    "%.1f%% 实体" % (area / (P * P) * 100))
# 负向测试: 关掉槽 -> 面积必须变成 ~856 (方钢 - 圆角 - 中心孔)
run(part="beam", out=os.path.join(TMP, "beam_noslot.stl"), extra=("SLOT_ON=false",))
a2 = measure(os.path.join(TMP, "beam_noslot.stl"))[0] / 1000.0
chk("负向测试: 关掉 T 槽 -> 面积应回到 ~855.96", near(a2, 855.957, 0.004),
    "%.3f mm^2" % a2)

# ---------------------------------------------------------------- 2
print("\n[2] 型材整体 (对比 总长 x 截面面积)")
v, mn, mx, nf = measure(export("frame"))
chk("型材体积 = 总长 x 截面积", near(v, FRAME_VOL, 0.006),
    "实测 %.5g, 理论 %.5g, 偏差 %+.3f%%"
    % (v, FRAME_VOL, (v - FRAME_VOL) / FRAME_VOL * 100))
chk("型材 bbox = W x D x H", np.allclose(mx - mn, [W, D, H], atol=0.02),
    "%.1f x %.1f x %.1f" % tuple(mx - mn))

# ---------------------------------------------------------------- 3
print("\n[3] 整台包围盒")
v, mn, mx, nf = measure(export("bench"))
chk("工作台 bbox = %.0f x %.0f x %.0f" % (W, D, H),
    np.allclose(mx - mn, [W, D, H], atol=0.02),
    "实测 %.1f x %.1f x %.1f" % tuple(mx - mn))
chk("底面贴地 z_min = 0", abs(mn[2]) < 0.02, "z_min=%.3f" % mn[2])

v, mn, mx, nf = measure(export("enclosure"))
chk("A1mini 封箱包络 bbox = 460 x 520 x 460",
    np.allclose(mx - mn, [ENC_W, ENC_D, ENC_H], atol=0.02),
    "实测 %.0f x %.0f x %.0f" % tuple(mx - mn))
chk("封箱底部正好落在左台面 700 上", abs(mn[2] - 700) < 0.02, "z_min=%.1f" % mn[2])
chk("★ 封箱前探 %.0fmm (台面只有 %.0f 深)" % (D - mn[1] if mn[1] < 0 else 0, D),
    mn[1] < -1, "封箱 y_min = %.1f, 台面 y_min = 0" % mn[1])

# ---------------------------------------------------------------- 4
print("\n[4] 台面高度 (台面板上表面)")
if not QUICK:
    e = 570 * 400 * PANEL_T - 2 * P * P * PANEL_T
    v = probe("decks", [0, 0, 680, 570, 400, 30], "left_deck")
    chk("左台面板: 570x400x18 挖 2 个柱角 = %.0f" % e, near(v, e, 0.002),
        "实测 %.0f" % v)
    v = probe("decks", [0, 0, 700.5, 570, 400, 300], "left_above")
    chk("左台面 700 以上是空的 (0)", v < 1, "实测 %.1f" % v)
    chk("  负向: 往下降 25mm 必须撞到台面板", 
        probe("decks", [0, 0, 675, 570, 400, 30], "left_below") > 1e5)

    e = 800 * 400 * PANEL_T - 2 * P * P * PANEL_T
    v = probe("decks", [600, 0, 580, 800, 400, 30], "main_deck")
    chk("中/右台面板: 800x400x18 挖 2 个柱角 = %.0f" % e, near(v, e, 0.002),
        "实测 %.0f" % v)
    v = probe("decks", [600, 0, 600.5, 800, 400, 300], "main_above")
    chk("中/右台面 600 以上是空的 (0)", v < 1, "实测 %.1f" % v)

# ---------------------------------------------------------------- 5
print("\n[5] 左区 60cm 收纳空腔 —— 必须是空的")
if not QUICK:
    box_cav = [X_CAV0 + 1, Y_CAV0 + 1, Z_FLOOR + 1,
               X_CAV1 - X_CAV0 - 2, Y_CAV1 - Y_CAV0 - 2, Z_RAIL - Z_FLOOR - 2]
    v = probe("structure", box_cav, "cavity")
    chk("空腔 540 x 340 x 620 内无料 (0)", v < 1, "实测 %.1f mm^3  %s"
        % (v, box_cav))
    # 负向 1: 往下探到地台板 -> 必须有料 (=538*338*15)
    e = 538 * 338 * 15
    v = probe("structure", [31, 31, 15, 538, 338, 30], "cav_floor")
    chk("  负向: 探到地台板应有 %.0f" % e, near(v, e, 0.002), "实测 %.0f" % v)
    # 负向 2: 往上探到台面板 -> 必须有料 (=538*338*18)
    e = 538 * 338 * 18
    v = probe("structure", [31, 31, 640, 538, 338, 60], "cav_top")
    chk("  负向: 探到台面板应有 %.0f" % e, near(v, e, 0.002), "实测 %.0f" % v)
    # 负向 3: 往右探到分隔封板 -> 必须有料 (=18*338*620)
    e = 18 * 338 * 620
    v = probe("structure", [X_CAV1 + 0.1, 31, 31, 29, 338, 620], "cav_div")
    chk("  负向: 探到右侧隔板应有 %.0f" % e, near(v, e, 0.002), "实测 %.0f" % v)
    v = probe("structure", [500, 31, 31, 69, 338, 620], "cav_free")
    chk("  空腔右边缘确实在 x=570 (500..569 内无料)", v < 1, "实测 %.1f" % v)

# ---------------------------------------------------------------- 6
print("\n[6] 抽屉柜")
if not QUICK:
    v = probe("structure", [1131, 31, 49, 238, 320, 502], "cab_open")
    chk("抽屉口 240 x 322 x 522 内无料 (0)", v < 1, "实测 %.1f" % v)
    e = 238 * 320 * 17
    v = probe("structure", [1131, 31, 30, 238, 320, 17], "cab_bot")
    chk("  负向: 探到柜底板应有 %.0f" % e, near(v, e, 0.002), "实测 %.0f" % v)
    e = 238 * 18 * 502
    v = probe("structure", [1131, 351, 49, 238, 19, 502], "cab_back")
    chk("  负向: 探到柜背板应有 %.0f" % e, near(v, e, 0.002), "实测 %.0f" % v)
    v = probe("structure", [1099.9, 31, 100, 5, 338, 300], "cab_post")
    chk("  负向: 往左 20mm 应撞上柜体竖柱", v > 1e4, "实测 %.0f" % v)

    v = probe("drawers", [1100, 0, 0, 301, 19, 600], "drw_front")
    e = NDRW * DRW_W * PANEL_T * FH
    chk("抽屉面板 %d 块 = %.0f" % (NDRW, e), near(v, e, 0.002), "实测 %.0f" % v)
    v = probe("drawers", [1000, 0, 0, 99, 400, 600], "drw_left")
    chk("抽屉面板确实在 x>=1100 (左侧无料)", v < 1, "实测 %.1f" % v)
    # 负向: 取一块完全落在第 1 块面板内部的小盒子, 体积必须 = 盒子体积
    v = probe("drawers", [1150, 0, 100, 200, 10, 100], "drw_inside")
    chk("  负向: 第 1 块面板内部 200x10x100 的盒子应被填满",
        near(v, 200 * 10 * 100, 0.002), "实测 %.0f" % v)

# ---------------------------------------------------------------- 7
print("\n[7] 洞洞板 (方孔 %dx%d 间距)" % (PEG_NX, PEG_NZ))
v = measure(export("pegboard"))
e = (PEG_W * PEG_H - PEG_NX * PEG_NZ * 10 * 10) * PEG_T
chk("板体积 = 770x820x10 挖 %d 个 10x10 方孔 = %.0f"
    % (PEG_NX * PEG_NZ, e), near(v, e, 0.002), "实测 %.0f" % v)
chk("  负向: 比整块实心板小 (孔确实挖了)", v < PEG_W * PEG_H * PEG_T * 0.99,
    "%.1f%% of 实心" % (v / (PEG_W * PEG_H * PEG_T) * 100))
v, mn, mx, nf = measure(os.path.join(TMP, "pegboard.stl"))
chk("洞洞板贴在背柱内侧 y=360..370", abs(mn[1] - 360) < 0.02 and abs(mx[1] - 370) < 0.02,
    "y %.1f..%.1f" % (mn[1], mx[1]))

# ---------------------------------------------------------------- 8
print("\n[8] 台面上方 10cm 深小层板")
if not QUICK:
    v = probe("ledges", [600, 265, 940, 770, 90, 2], "ledge1")
    chk("第 1 块层板 (顶面 950) 在 y=265..355", near(v, 770 * 90 * 2, 0.002),
        "实测 %.0f" % v)
    v = probe("ledges", [600, 265, 1240, 770, 90, 2], "ledge2")
    chk("第 2 块层板 (顶面 1250)", near(v, 770 * 90 * 2, 0.002), "实测 %.0f" % v)
    v = probe("ledges", [600, 265, 1100, 770, 90, 2], "ledge_gap")
    chk("  负向: 两层之间 (1100) 没有层板 (0)", v < 1, "实测 %.1f" % v)
    v = probe("ledges", [600, 100, 940, 770, 100, 2], "ledge_fwd")
    chk("  负向: 往前 160mm 处没有层板 (0)", v < 1, "实测 %.1f" % v)

# ---------------------------------------------------------------- 汇总
print("\n" + "=" * 74)
ok = sum(1 for _, r in _RESULT if r)
print("结果: %d / %d 通过" % (ok, len(_RESULT)))
for nm, r in _RESULT:
    if not r:
        print("   FAIL: " + nm)
print("=" * 74)

if MAKE_PNG:
    VIEWS = [
        ("preview_iso.png",   "1600,-1400,1500,700,200,1000"),
        ("preview_front.png", "700,-2500,1000,700,200,1000"),
        ("preview_right.png", "2600,200,1000,700,200,1000"),
        ("preview_top.png",   "700,200,3200,700,200,1000"),
    ]
    for name, cam in VIEWS:
        subprocess.run([OPENSCAD, "-o", os.path.join(HERE, name),
                        "--imgsize=1400,1100", "--viewall", "--autocenter",
                        "--camera=" + cam, "--projection=o",
                        "--colorscheme=Tomorrow", SCAD], cwd=HERE,
                       capture_output=True)
        try:
            from PIL import Image
            im = np.asarray(Image.open(os.path.join(HERE, name)).convert("RGB"))
            bg = im[0, 0].astype(int)
            cover = (np.abs(im.astype(int) - bg).sum(2) > 24).mean()
            print("  渲染 %-18s 非背景像素占比 %.1f%%" % (name, cover * 100))
        except ImportError:
            print("  渲染 %s (无 PIL, 跳过空白检查)" % name)

sys.exit(0 if ok == len(_RESULT) else 1)
