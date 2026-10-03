"""
笔记本式 1u 键帽 —— 几何自动验证
=====================================================================
跑法:
    run_verify.bat
    (等价于 & 'C:\\Program Files\\FreeCAD 1.1\\bin\\python.exe' verify.py)

做四件事:
  1. 外形 / 体积   包围盒必须 18 x 18 x 5.5; 体积必须等于解析公式
                   (圆角方锥台 - 内腔 - 指窝 - 橡胶碗坑 - 卡槽 + 卡勾)。
  2. 特征探针      用「探针盒 - 模型」的【差集】体积判断该区域是实心还是空的。
                   用 difference 而不是 intersection: CGAL Nef_3 在两个互不相交
                   的实体上求交会断言失败并悄悄返回垃圾几何。
  3. 连通性        解析 STL, 按共享边做并查集 —— 必须是【单一连通体】。
                   (卡勾是「求交+并回」做出来的, 这一条专门防它变成孤岛)
  4. 负向对照      逐条关掉特征 (show_dish/pad/hook/slot), 对应的探针检查必须
                   【真的失败】; 另喂一个「故意断开」的模型给连通性检查, 必须
                   报 2 块。空检查 = 没检查。
=====================================================================
"""
import os
import subprocess
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stl_util import measure, n_components

HERE = os.path.dirname(os.path.abspath(__file__))
SC = r"C:\Program Files\OpenSCAD\openscad.exe"

# ------------------------- 与 keycap.scad 保持一致的参数 -------------------------
TOP_W, BOT_W, H = 18.0, 15.6, 5.5
WALL, R_BOT = 1.4, 1.9
DISH, R_SPH = 0.30, 60.0

HOOK_X, HOOK_W = 4.4, 3.0
HOOK_YIN, HOOK_YLIP = 5.9, 4.5
HOOK_Z0, HOOK_Z1, LIP_Z = 1.0, 3.2, 4.3

SLOT_X, SLOT_W = 4.4, 3.0
SLOT_Z0, SLOT_Z1 = 1.4, 3.2

PAD_R, PAD_D, PAD_OVER = 4.0, 0.2, 0.03

SLOPE = (TOP_W - BOT_W) / 2 / H
CAV_BOT = BOT_W - 2 * WALL
CAV_H = H - WALL
CAV_TOP = CAV_BOT + 2 * SLOPE * CAV_H
R_CAV = R_BOT - WALL


def h_in(z):
    return CAV_BOT / 2 + SLOPE * z


def h_out(z):
    return BOT_W / 2 + SLOPE * z


# ------------------------------ 解析体积 ------------------------------
def frustum_vol(w0, w1, h, r0):
    """圆角方锥台体积: 截面是「边长 w、圆角 r」的圆角方形, 且整体等比缩放。"""
    a0 = w0 * w0 - (4 - np.pi) * r0 * r0
    a1 = w1 * w1 - (4 - np.pi) * (r0 * w1 / w0) ** 2
    return h / 3 * (a0 + a1 + np.sqrt(a0 * a1))


V_OUT = frustum_vol(BOT_W, TOP_W, H, R_BOT)
V_CAV = frustum_vol(CAV_BOT, CAV_TOP, CAV_H, R_CAV)
V_DISH = np.pi * DISH ** 2 * (3 * R_SPH - DISH) / 3
V_PAD = np.pi * PAD_R ** 2 * (PAD_D + PAD_OVER)
# 卡槽是【竖直】长方体刀具; 内外壁是平行斜面, 水平间距恒为 WALL
V_SLOT = 2 * SLOT_W * (SLOT_Z1 - SLOT_Z0) * WALL


def _hook_add():
    vol = 0.0
    for y, z0, z1 in ((HOOK_YIN, HOOK_Z0, HOOK_Z1), (HOOK_YLIP, HOOK_Z1, CAV_H)):
        # 卡勾与内壁之间被填回的那块: 竖直方向线性, 取两端平均
        vol += HOOK_W * (h_in(z0) - y + h_in(z1) - y) / 2 * (z1 - z0)
    return 2 * vol


V_HOOK = _hook_add()
V_EXP = V_OUT - V_CAV - V_DISH - V_PAD - V_SLOT + V_HOOK

RESULTS = []
CGAL = []          # 出现 CGAL/断言 -> STL 里的几何是垃圾, 必须记下来
HARNESS_OK = [True]   # `use` 语义自检: 模块文件顶层调用不能参与渲染
_PROBE_N = 0


def render(name, expr, quiet=True, keep=False):
    """把 `use <keycap.scad>` + expr 写成临时 .scad, 渲染成 STL, 返回 (vol, bbox)。

    keep=True 时保留 _t_<name>.stl (连通性检查要拿它做并查集)。
    """
    src = os.path.join(HERE, f"_t_{name}.scad")
    stl = os.path.join(HERE, f"_t_{name}.stl")
    for p in (src, stl):
        if os.path.exists(p):
            os.remove(p)
    with open(src, "w", encoding="utf-8") as f:
        f.write(f"use <keycap.scad>\n$fn = 64;\n{expr}\n")
    t = time.time()
    r = subprocess.run([SC, "-o", stl, src], capture_output=True, text=True,
                       errors="replace")
    dt = time.time() - t
    for line in (r.stderr or "").splitlines():
        s = line.strip()
        # 只看真正的失败; "CGAL Polyhedrons in cache" 之类的统计行要滤掉
        if "ERROR:" in s or "assertion" in s or "CGAL ERROR" in s:
            CGAL.append((name, s[:100]))
            print(f"      !! OpenSCAD: {s[:110]}")
    vol, mn, mx, nfac = measure(stl)
    if not keep:
        for p in (src, stl):
            if os.path.exists(p):
                os.remove(p)
    else:
        os.remove(src)
    if not quiet:
        print(f"      ({name}: {dt:.1f}s, {nfac} facets)")
    return vol, mn, mx


def check(label, ok, detail=""):
    RESULTS.append((label, ok))
    print(f"  [{'PASS' if ok else 'FAIL'}] {label:40s} {detail}")


def probe(label, box, expect, call="keycap()"):
    """探针盒 (x0,y0,z0,x1,y1,z1)。coverage = (V盒 - V(盒-模型)) / V盒。

    临时文件名用 ASCII 序号 —— 中文文件名喂给 OpenSCAD 在 Windows 上不可靠。
    """
    global _PROBE_N
    _PROBE_N += 1
    x0, y0, z0, x1, y1, z1 = box
    vp = (x1 - x0) * (y1 - y0) * (z1 - z0)
    expr = (f"difference() {{\n"
            f"  translate([{x0}, {y0}, {z0}]) "
            f"cube([{x1 - x0}, {y1 - y0}, {z1 - z0}]);\n"
            f"  {call};\n}}")
    v, _, _ = render(f"p{_PROBE_N:02d}", expr)
    cov = (vp - v) / vp
    ok = cov > 0.98 if expect == "solid" else cov < 0.02
    check(label, ok,
          f"coverage={cov * 100:5.1f}%  期望 {'实心' if expect == 'solid' else '空'}")
    return cov


t0 = time.time()

# ==================================================== 0. 测试装置自检
print("\n=== 0. 测试装置自检 (`use` 语义) ===")
v, mn, mx = render("harness", "translate([0, 0, 0]) cube([1, 1, 1], center = true);")
ok = abs(v - 1.0) < 1e-6 and abs(mx[0] - 0.5) < 1e-4
HARNESS_OK[0] = ok
check("use 的顶层调用不参与渲染", ok,
      f"V={v:.4f} (应为 1.0000), xmax={mx[0]:.3f} (应为 0.500)")

# ==================================================== 1. 外形 / 体积
print("\n=== 1. 外形 / 体积 ===")
v, mn, mx = render("full", "keycap();", quiet=False)
size = mx - mn
check("包围盒 = 18 x 18 x 5.5",
      abs(size[0] - TOP_W) < 0.25 and abs(size[1] - TOP_W) < 0.25 and abs(size[2] - H) < 0.25,
      f"实测 {size[0]:.3f} x {size[1]:.3f} x {size[2]:.3f}")
check("底面坐在 z=0 (可打印朝向)", abs(mn[2]) < 1e-3, f"zmin={mn[2]:.4f}")
check("体积 = 解析公式",
      abs(v - V_EXP) / V_EXP < 0.15,
      f"实测 {v:.1f} / 解析 {V_EXP:.1f} mm^3 ({v / V_EXP * 100 - 100:+.2f}%)")
print(f"       -> 分项: 外壳{V_OUT:.1f} - 内腔{V_CAV:.1f} - 指窝{V_DISH:.1f} "
      f"- 碗坑{V_PAD:.1f} - 卡槽{V_SLOT:.1f} + 卡勾{V_HOOK:.1f}")
print(f"       -> 单只质量 ≈ {v * 1.04e-3:.3f} g (ABS) / {v * 1.20e-3:.3f} g (PC)")

# ==================================================== 2. 特征探针
print("\n=== 2. 特征探针 (实心 / 空) ===")
probe("顶板中心为实心",        (-1.0, -1.0, 4.60, 1.0, 1.0, 5.00), "solid")
probe("底面内腔为空的",        (-2.0, -2.0, 0.05, 2.0, 2.0, 0.90), "empty")
probe("内腔中段为空的",        (-2.0, -2.0, 1.20, 2.0, 2.0, 2.20), "empty")
probe("顶面指窝被挖掉",        (-1.0, -1.0, 5.30, 1.0, 1.0, 5.45), "empty")
probe("指窝外顶面仍是实心(对照)", (7.5, -0.5, 5.30, 8.5, 0.5, 5.45), "solid")
probe("橡胶碗坑被挖掉",        (-1.5, -1.5, 4.14, 1.5, 1.5, 4.29), "empty")
probe("侧壁为实心(对照)",      (7.4, -0.5, 1.50, 7.9, 0.5, 2.50), "solid")
probe("前侧卡勾竖块为实心",    (3.3, -6.8, 1.60, 5.5, -6.1, 2.80), "solid")
probe("前侧卡勾卡唇为实心",    (3.3, -6.6, 3.50, 5.5, -5.2, 4.00), "solid")
probe("卡唇下方口袋为空的",    (3.3, -5.8, 2.00, 5.5, -4.7, 2.90), "empty")
probe("后侧卡槽是通孔",        (3.3,  7.15, 1.80, 5.5, 8.00, 2.80), "empty")

# ==================================================== 3. 连通性
print("\n=== 3. 连通性 (单一实体) ===")
_, _, _ = render("conn", "keycap();", keep=True)
nc = n_components(os.path.join(HERE, "_t_conn.stl"))
check("模型是单一连通体", nc == 1, f"连通块数 = {nc}")

# ==================================================== 4. 负向对照
print("\n=== 4. 负向对照 (关掉特征, 检查必须真的失败) ===")
probe("N1 关指窝 -> 该探针变实心", (-1.0, -1.0, 5.30, 1.0, 1.0, 5.45),
      "solid", call="keycap(show_dish = false)")
probe("N2 关碗坑 -> 该探针变实心", (-1.5, -1.5, 4.14, 1.5, 1.5, 4.29),
      "solid", call="keycap(show_pad = false)")
probe("N3 关卡勾 -> 竖块变空",     (3.3, -6.8, 1.60, 5.5, -6.1, 2.80),
      "empty", call="keycap(show_hook = false)")
probe("N4 关卡勾 -> 卡唇变空",     (3.3, -6.6, 3.50, 5.5, -5.2, 4.00),
      "empty", call="keycap(show_hook = false)")
probe("N5 关卡槽 -> 该处变实心",   (3.3, 7.15, 1.80, 5.5, 8.00, 2.80),
      "solid", call="keycap(show_slot = false)")

render("nc",
       "union() { keycap(); translate([40, 0, 0]) cube([2, 2, 2], center = true); }",
       keep=True)
nc2 = n_components(os.path.join(HERE, "_t_nc.stl"))
check("N6 故意断开 -> 连通性检查能报 2 块", nc2 == 2, f"连通块数 = {nc2}")

# ==================================================== 汇总
n_fail = sum(1 for _, ok in RESULTS if not ok)
print("\n" + "=" * 68)
print(f"汇总: {len(RESULTS) - n_fail}/{len(RESULTS)} 通过,  "
      f"耗时 {time.time() - t0:.0f}s")
if CGAL:
    print(f"!! CGAL / 断言告警 {len(CGAL)} 条 (几何可能不可信):")
    for name, msg in CGAL[:5]:
        print(f"   - [{name}] {msg}")
print("=" * 68)
sys.exit(1 if n_fail else 0)
