"""
A1 mini 封箱 —— 几何/运动学自动验证

跑法:
    & 'C:\\Program Files\\FreeCAD 1.1\\bin\\python.exe' verify.py

做三件事:
  A. 正向测试  铰链轴在门「前表面」平面内 (PIVOT_Y=0) 时, 门从 0..150 度
              扫过, 与主框的交集体积必须 ≈ 0。
  B. 负向测试  把铰链轴内移到 PIVOT_Y=8, 必须【确实撞上】。
              (否则说明 A 的检查是空的 —— 空检查等于没检查)
  C. 静态检查  门/玻璃/机器包络 与主框 无干涉; 玻璃确实内凹。
"""
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _stl import measure

HERE = os.path.dirname(os.path.abspath(__file__))
OPENSCAD = r"C:\Program Files\OpenSCAD\openscad.exe"

# 与 .scad 保持一致
OUT_W, OUT_D, OUT_H, P = 460.0, 520.0, 460.0, 20.0
INT_W, INT_D, INT_H = 420.0, 480.0, 420.0
PANEL_REC, PANEL_T = 6.0, 4.0
PANEL_EN = 4.0
MACH_W, MACH_D, MACH_H, BED_OVER = 347.0, 315.0, 365.0, 60.0
DENSITY_AL = 2.70e-3   # g/mm^3
DENSITY_GLASS = 2.50e-3

RESULTS = []


def render(name, expr):
    """把 `expr` 写成一个临时 .scad, 渲染成 STL, 返回 (vol, bbox_min, bbox_max)。"""
    src = os.path.join(HERE, f"_t_{name}.scad")
    stl = os.path.join(HERE, f"_t_{name}.stl")
    for p in (src, stl):
        if os.path.exists(p):
            os.remove(p)
    with open(src, "w", encoding="utf-8") as f:
        f.write("use <a1mini_enclosure.scad>\n")
        f.write(expr + "\n")
    subprocess.run([OPENSCAD, "-o", stl, src], capture_output=True, text=True)
    vol, mn, mx, n = measure(stl)
    for p in (src, stl):
        if os.path.exists(p):
            os.remove(p)
    return vol, mn, mx


def check(label, ok, detail=""):
    RESULTS.append((label, ok, detail))
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}   {detail}")


# ---------------------------------------------------------------- A. 开门
print("\n=== A. 开门运动学: 铰链轴在门的前表面平面内 (PIVOT_Y = 0) ===")
ANGLES = [2, 4, 6, 8, 12, 18, 25, 35, 50, 70, 90, 120, 150]
worst = {}
for sgn, tag in ((-1, "left"), (1, "right")):
    w, wa = 0.0, None
    for a in ANGLES:
        vol, _, _ = render(f"sw_{tag}_{a}", f"intersection()"
                           f" {{ test_front_legs(); test_leaf({sgn}, {a}); }}")
        if vol > w:
            w, wa = vol, a
    worst[tag] = (w, wa)
    check(f"{tag} door 0..150 deg clear of frame", w < 1.0,
          f"max overlap {w:,.1f} mm^3" + (f" @ {wa} deg" if wa else ""))

# ------------------------------------------------------------ B. 负向对照
print("\n=== B. 负向对照: 铰链轴内移 PIVOT_Y = 8 (应当碰撞) ===")
for sgn, tag in ((-1, "left"), (1, "right")):
    hits = []
    for a in [8, 12, 20, 35, 60, 90]:
        vol, _, _ = render(f"neg_{tag}_{a}", f"intersection()"
                           f" {{ test_front_legs(); test_leaf({sgn}, {a}, 0, 8); }}")
        if vol > 1.0:
            hits.append((a, vol))
    check(f"{tag}: inset pivot MUST collide", len(hits) > 0,
          ("collides at " + ", ".join(f"{a}deg={v:,.0f}" for a, v in hits[:4]))
          if hits else "NO collision -> A 的检查可能是空的")

# ------------------------------------------------------------ C. 静态干涉
print("\n=== C. 静态干涉检查 ===")
for tag, label, expr in [
    ("static_doors", "doors(closed) vs frame",
     "intersection() { test_frame(); test_doors(); }"),
    ("static_panels", "panels vs frame",
     "intersection() { test_frame(); test_panels(); }"),
    ("static_pd", "panels vs doors",
     "intersection() { test_doors(); test_panels(); }"),
    ("static_mach", "machine env vs frame",
     "intersection() { test_frame(); test_machine(); }"),
]:
    vol, _, _ = render(tag, expr)
    check(label, vol < 1.0, f"{vol:,.1f} mm^3")

# -------------------------------------------------------- D. 玻璃内凹检查
print("\n=== D. 内嵌玻璃面板位置 ===")
_, pmn, pmx = render("panels_only", "test_panels();")
_, fmn, fmx = render("frame_only", "test_frame();")
rec = min(pmn - fmn)
rec_back = min(fmx - pmx)
check("panels recessed from frame outer face",
      rec > 0 and rec_back > 0,
      f"X front {pmn[0]-fmn[0]:.2f} / X back {fmx[0]-pmx[0]:.2f} / "
      f"Y front {pmn[1]-fmn[1]:.2f} / Z top {fmx[2]-pmx[2]:.2f} mm (期望 {PANEL_REC})")
check("panel outer faces all recessed by PANEL_REC",
      abs(pmn[0] - PANEL_REC) < 1e-6 and abs(pmx[2] - (OUT_H - PANEL_REC)) < 1e-6,
      f"min coord {pmn}  max coord {pmx}")

# ---------------------------------------------------------- E. 机器包络
print("\n=== E. A1 mini 机器包络余量 ===")
_, mmn, mmx = render("machine_only", "test_machine();")
margin_x = mmn[0] - P
margin_y = mmn[1] - P
margin_z = OUT_H - P - mmx[2]
swept_y = MACH_D + 2 * BED_OVER
print(f"      机器包络 (含床板摆程 {BED_OVER}mm/侧): "
      f"{mmx[0]-mmn[0]:.0f} x {mmx[1]-mmn[1]:.0f} x {mmx[2]-mmn[2]:.0f} mm")
check(f"X 余量 {margin_x:.1f} mm/side", margin_x > 10)
check(f"Y 余量 {margin_y:.1f} mm/side (床板摆程 {swept_y:.0f} mm)", margin_y > 10)
check(f"Z 余量 {margin_z:.1f} mm (走 PTFE 管/线)", margin_z > 30)

# ------------------------------------------------------------ F. 材料
print("\n=== F. 材料估算 ===")
LEAF_W, LEAF_H = 206.0, 415.0
beam_len = 4 * OUT_H + 4 * INT_W + 4 * INT_D + 2 * (2 * LEAF_H + 2 * (LEAF_W - 2 * P))
parea = 173.79  # mm^2, 2020 截面实心面积 (已独立标定)
al_kg = parea * beam_len * DENSITY_AL / 1000
glass_area = (2 * (INT_D + 2 * PANEL_EN) * (INT_H + 2 * PANEL_EN)
              + (INT_W + 2 * PANEL_EN) * (INT_H + 2 * PANEL_EN)
              + (INT_W + 2 * PANEL_EN) * (INT_D + 2 * PANEL_EN)
              + 2 * (LEAF_W - 2 * P + 2 * PANEL_EN) * (LEAF_H - 2 * P + 2 * PANEL_EN))
glass_kg = glass_area * PANEL_T * DENSITY_GLASS / 1e6
print(f"      2020 总长 {beam_len:,.0f} mm -> 铝重 {al_kg:.2f} kg")
print(f"      玻璃 {glass_area/1e6:.3f} m^2 ({PANEL_T}mm) -> {glass_kg:.2f} kg"
      f"   (亚克力约 {glass_kg*1190/2500:.2f} kg)")
print(f"      不含桌面/门五金 + 24 个 L 角件 + 铰链")

# ------------------------------------------------------------ 汇总
bad = [r for r in RESULTS if not r[1]]
print("\n" + "=" * 62)
print(f"结果: {len(RESULTS) - len(bad)}/{len(RESULTS)} 项通过")
if bad:
    for label, _, detail in bad:
        print(f"  FAIL: {label}  {detail}")
    sys.exit(1)
print("全部通过")
