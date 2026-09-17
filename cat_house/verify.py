"""
3030 铝型材猫屋 —— 几何 / 运动学自动验证
=====================================================================
跑法:
    & 'C:\\Program Files\\FreeCAD 1.1\\bin\\python.exe' verify.py

做五件事:
  1. 截面校核   单独把 3030 截面挤 100 mm, 体积/100 = 真实截面积, 与手算公式对比。
  2. 整壳校核   test_shell() 的包围盒必须是 1200x600x2000; 体积必须等于
                「截面积 x 型材总长 + 各块板 + 角码」的手算和。
  3. 干涉检查   角码/层板/围板/门/顶板/箱内物 两两求交, 体积必须 ≈ 0。
  4. 开门运动学 门绕铰链扫 0~175 度, 与两根前腿的交集必须恒为 0;
                并且【负向对照】把铰链销内移 15 mm 后必须真的撞上
                (否则说明这个检查是空的)。
  5. 挖空校核   用探针盒子验证层板猫洞/爬柱孔确实被挖空,
                并在实心区域做同尺寸探针作为对照。
=====================================================================
"""
import os
import subprocess
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _stl import measure

HERE = os.path.dirname(os.path.abspath(__file__))
SC = r"C:\Program Files\OpenSCAD\openscad.exe"

# ------------------------- 与 .scad 保持一致的参数 -------------------------
P, OUT_W, OUT_D, OUT_H = 30.0, 1200.0, 600.0, 2000.0
INT_W, INT_D = OUT_W - 2 * P, OUT_D - 2 * P
T_WOOD, T_ACR, T_ROOF = 15.0, 5.0, 15.0
N_LEV, PITCH = 4, 500.0
TOP_RING_Z = OUT_H - P - T_ROOF

DOOR_GAP, DOOR_MID, PV_Y = 1.5, 3.0, -6.0
PV_Y_BAD = 9.0                    # 负向对照: 销内移 15 mm

BKT_L, BKT_T = 45.0, 8.0
NOTCH = P + 1.0                    # 层板四角方缺口边长
HOLE_D, POST_D = 200.0, 110.0
PLAT_Z = [380.0, 790.0, 1290.0]

LEAF_W = (INT_W - 2 * DOOR_GAP - DOOR_MID) / 2
L_TOTAL = 4 * (OUT_H - T_ROOF) + (N_LEV + 1) * (2 * INT_W + 2 * INT_D)
A_HAND = 900 - 4 * (1 - np.pi / 4) * 3**2 - 4 * (2.4 * 6.2 + 6.8 * 11.0) - np.pi * 3.4**2

RESULTS = []


def ring_z(i):
    return i * PITCH if i < N_LEV else TOP_RING_Z


def shelf_z0(i):
    return ring_z(i) + P


def shelf_z1(i):
    return shelf_z0(i) + T_WOOD


def wall_h(i):
    return ring_z(i + 1) - shelf_z1(i)


def sheet_t(i):
    return T_WOOD if i == 0 else T_ACR


def render(tag, expr, quiet=True):
    """把 expr 写成临时 .scad, 渲染成 STL, 返回 (vol, bbox_min, bbox_max, 秒)。"""
    src = os.path.join(HERE, f"_v_tmp_{os.getpid()}.scad")
    stl = os.path.join(HERE, f"_v_tmp_{os.getpid()}.stl")
    for p in (src, stl):
        if os.path.exists(p):
            os.remove(p)
    with open(src, "w", encoding="utf-8") as f:
        f.write("use <cat_house.scad>\n" + expr + "\n")
    t = time.time()
    r = subprocess.run([SC, "-o", stl, src], capture_output=True, text=True,
                       errors="replace")
    dt = time.time() - t
    vol, mn, mx, n = measure(stl)
    errs = [l for l in (r.stderr or "").splitlines() if "ERROR:" in l]
    if errs:
        print("      !! OpenSCAD: " + errs[0][:110])
    for p in (src, stl):
        if os.path.exists(p):
            os.remove(p)
    if not quiet:
        print(f"      ({tag}: {dt:.1f}s)")
    return vol, mn, mx, dt


def check(label, ok, detail=""):
    RESULTS.append((label, ok))
    print(f"  [{'PASS' if ok else 'FAIL'}] {label:44s} {detail}")


t_all = time.time()

# ============================================================ 1. 截面
print("\n=== 1. 3030 型材截面 ===")
v, _, _, dt = render("profile", "test_profile_100();")
A = v / 100.0
check("截面面积 vs 手算公式", abs(A - A_HAND) / A_HAND < 0.01,
      f"实测 {A:.2f} / 手算 {A_HAND:.2f} mm^2  ({A / A_HAND * 100 - 100:+.2f}%)")
print(f"       -> 3030 线密度 ≈ {A * 2.70e-3:.3f} kg/m   (真料 1.15~1.35 kg/m)")

# ============================================================ 2. 整壳
print("\n=== 2. 整壳体积 / 包围盒 ===")
exp = A * L_TOTAL                                    # 型材
shelf_exp = 0.0
for i in range(N_LEV):
    sv = OUT_W * OUT_D * T_WOOD
    sv -= 4 * (P / 2 + NOTCH / 2) ** 2 * T_WOOD      # 四角方缺口 (每角只有一半落在板上)
    if i >= 1:
        sv -= np.pi * (HOLE_D / 2) ** 2 * T_WOOD
        sv -= np.pi * (POST_D / 2 + 10) ** 2 * T_WOOD
    shelf_exp += sv
exp += shelf_exp                                     # 层板
exp += OUT_W * OUT_D * T_ROOF                        # 顶板

wood = acr = 0.0
for i in range(N_LEV):
    side = 2 * sheet_t(i) * INT_D * wall_h(i)                       # 左 / 右侧板
    door = 2 * LEAF_W * (wall_h(i) - 2 * DOOR_GAP) * sheet_t(i)     # 2 扇门
    if i == 0:
        door -= np.pi * 115**2 * T_WOOD                             # 木门上的猫洞
        wood += side + door
    else:
        acr += side + door
    wood += INT_W * T_WOOD * wall_h(i)                              # 背板 (永远木板)
exp += wood + acr
bkt = 4 * (N_LEV + 1) * (0.5 * BKT_L * BKT_L * BKT_T - 2 * np.pi * 3.3**2 * BKT_T)
exp += bkt

vs, mn, mx, dt = render("shell", "test_shell();")
size = mx - mn
print(f"      型材 {A * L_TOTAL / 1e6:8.3f} L   木 {wood / 1e6:8.3f} L   "
      f"亚克力 {acr / 1e6:8.3f} L   角码 {bkt / 1e6:7.3f} L")
check("包围盒 = 1200 x 600 x 2000",
      np.allclose(size, [OUT_W, OUT_D, OUT_H], atol=0.01),
      f"{size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}")
check("整壳体积 vs 手算", abs(vs - exp) / exp < 0.005,
      f"实测 {vs:,.0f} / 手算 {exp:,.0f} mm^3  ({(vs - exp) / exp * 100:+.3f}%)")
print(f"       木{wood / 1e6 * 650:.1f} kg  亚克力{acr / 1e6 * 1190:.1f} kg  "
      f"铝{A * L_TOTAL / 1e6 * 2700:.1f} kg  角码{bkt / 1e6 * 7850:.1f} kg")

# ============================================================ 3. 干涉
print("\n=== 3. 静态干涉检查 (交集体积必须 ≈ 0) ===")
SHELL_NO_DOOR = ("union() { test_frame(); test_brackets(); test_shelves(); "
                 "test_roof(); test_panels(); }")
for label, expr in [
    ("角码 vs 主框", "intersection() { test_brackets(); test_frame(); }"),
    ("层板 vs 腿", "intersection() { test_shelves(); test_legs(); }"),
    ("围板 vs 腿", "intersection() { test_panels(); test_legs(); }"),
    ("围板 vs 层板", "intersection() { test_panels(); test_shelves(); }"),
    ("门 vs 主框", "intersection() { test_doors(); test_frame(); }"),
    ("门 vs 围板", "intersection() { test_doors(); test_panels(); }"),
    ("门 vs 层板", "intersection() { test_doors(); test_shelves(); }"),
    ("顶板 vs 主框", "intersection() { test_roof(); test_frame(); }"),
    ("箱内物 vs 整壳",
     f"intersection() {{ test_contents(); {SHELL_NO_DOOR} }}"),
]:
    v, _, _, dt = render("ix", expr)
    check(label, v < 1.0, f"{v:,.1f} mm^3  ({dt:.0f}s)")

# ============================================================ 4. 开门
print("\n=== 4. 开门运动学 (铰链销在 y = -6) ===")
ANGLES = [5, 15, 30, 45, 60, 90, 120, 150, 175]
for lvl, tag in ((1, "L1亚克力门"), (0, "L0木门")):
    for sgn, side in ((-1, "左"), (1, "右")):
        worst, wa = 0.0, None
        for a in (ANGLES if lvl == 1 else [30, 90, 150]):
            v, _, _, _ = render("sw", f"intersection() {{ test_front_legs(); "
                                      f"test_leaf({lvl}, {sgn}, {a}); }}")
            if v > worst:
                worst, wa = v, a
        check(f"{tag} {side}扇 0~175° 不撞框", worst < 1.0,
              f"最大重叠 {worst:,.1f} mm^3" + (f" @ {wa}°" if wa else ""))

print("\n=== 4b. 负向对照: 铰链销内移 15 mm (必须碰撞) ===")
hits = []
for a in [20, 30, 45, 60, 90]:
    v, _, _, _ = render("neg", f"intersection() {{ test_front_legs(); "
                               f"test_leaf(1, -1, {a}, {PV_Y_BAD}); }}")
    if v > 1.0:
        hits.append((a, v))
check("内移销位必须撞腿", len(hits) > 0,
      "撞于 " + ", ".join(f"{a}°={v:,.0f}mm³" for a, v in hits[:4])
      if hits else "完全不撞 -> 上面的正向后检查可能是空的!")

# ============================================================ 5. 挖空
print("\n=== 5. 层板猫洞 / 爬柱孔 探针校核 ===")
PROBE = 120 * 120 * T_WOOD
v, _, _, _ = render("p1", "intersection() { test_shelf(1); test_cat_hole_probe(1); }")
check("层板猫洞处确实是空的", v < 1.0, f"{v:,.1f} mm^3")
v, _, _, _ = render("p2", "intersection() { test_shelf(1); test_post_hole_probe(1); }")
check("层板爬柱孔处确实是空的", v < 1.0, f"{v:,.1f} mm^3")
v, _, _, _ = render("p3", "intersection() { test_shelf(1); test_solid_probe(1); }")
check("对照: 实心区同尺寸探针 = 探针体积", abs(v - PROBE) / PROBE < 0.01,
      f"{v:,.0f} / 期望 {PROBE:,.0f} mm^3")

# ============================================================ 6. 物品不越界
print("\n=== 6. 箱内物品不越界 ===")
_, cmn, cmx, _ = render("cnt", "test_contents();")
lo_ok = cmn[0] > -0.01 and cmn[1] > -0.01 and cmn[2] > shelf_z1(0) - 0.01
hi_ok = cmx[0] < OUT_W + 0.01 and cmx[1] < OUT_D + 0.01 and cmx[2] < TOP_RING_Z + 0.01
check("物品完全落在箱内净空里", lo_ok and hi_ok,
      f"bbox {np.round(cmn, 1)} .. {np.round(cmx, 1)}")
check("每层净高 >= 400 mm",
      all(wall_h(i) - 2 * DOOR_GAP >= 400 for i in range(N_LEV)),
      " / ".join(f"{wall_h(i) - 2 * DOOR_GAP:.0f}" for i in range(N_LEV)) + " mm")

# ============================================================ 汇总
print("\n" + "=" * 62)
bad = [l for l, ok in RESULTS if not ok]
print(f"共 {len(RESULTS)} 项检查, 通过 {len(RESULTS) - len(bad)} 项, 失败 {len(bad)} 项"
      f"   总耗时 {time.time() - t_all:.0f} s")
for l in bad:
    print("   FAIL:", l)
print("=" * 62)
sys.exit(1 if bad else 0)
