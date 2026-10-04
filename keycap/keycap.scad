// ============================================================================
//  笔记本 1u 薄键帽  (直壁 · 底面 2+2 卡扣)
//  ---------------------------------------------------------------------------
//  适配 : 富士通 Lifebook U9311X 一类 13.3" 笔记本的剪刀脚键盘
//
//  外形 : 侧壁【竖直, 没有内收】(TAPER = 0), 四角圆角, 顶缘 45 度倒角,
//         顶面浅球冠指窝。
//  底面 : 上/下两边各 2 个卡扣, 共 4 个。卡扣形式由 CLIP 选择:
//           "hook"   L 形卡爪  -- 竖片 + 底部外翻卡唇, 钩住横杆
//           "fork"   双柱夹口  -- 两片柱夹住横销 (靠弹性/摩擦)
//           "boss"   凸台通孔  -- 圆柱凸台 + 横向通孔, 销子穿进去
//           "snap"   悬臂弹片  -- 45 度导入斜面 + 止退面
//           "none"   底板无卡扣
//
//  预览 : openscad keycap.scad
//  导出 : openscad -o keycap.stl keycap.scad
//  自检 : run_verify.bat        (外形 / 探针 / 连通性 / 负向对照)
// ============================================================================

FN = 32;

/* ------------------------------- 外形 ------------------------------- */
OUT_W  = 17.4;   // 顶面外廓边长 (= 直壁外廓)
TAPER  = 0.0;    // 每侧向内收的量。0 = 直壁(默认); >0 会做成上大下小
H      = 4.6;    // 总高
WALL   = 1.2;    // 侧壁厚 (= 顶板厚)
R_OUT  = 1.6;    // 四角圆角
CHAMF  = 0.45;   // 顶缘倒角高度
DISH   = 0.25;   // 顶面指窝深
R_SPH  = 55.0;   // 指窝球面半径
DISH_FN = 32;    // 指窝球面细分

/* ----------------------------- 底面卡扣 ----------------------------- */
CLIP   = "hook"; // hook | fork | boss | snap | none
CLIP_X = 4.9;    // 卡扣中心 +/-(x)
CLIP_Y = 6.0;    // 卡扣中心 +/-(y)

/* ------------------------------ 派生量 ------------------------------ */
SLOPE = TAPER / H;                        // 外壁半宽随 z 的斜率
R_CAV = max(0.05, R_OUT - WALL);          // 内腔圆角
CAV_H = H - WALL;                         // 内腔顶面 z (= 顶板下表面)
Z_TOP = CAV_H + 0.4;                      // 卡扣顶 (埋进顶板 0.4, 保证融合)

function w_out(z) = OUT_W - 2 * TAPER + 2 * SLOPE * z;            // 外壁边长
function w_in(z)  = OUT_W - 2 * TAPER - 2 * WALL + 2 * SLOPE * z; // 内壁边长

// ---------------------------------------------------------------------------
//  几何基元
// ---------------------------------------------------------------------------
// 圆角方台: 底面边长 w0 -> 顶面边长 w1, 高 h, 底面圆角 r
module slab(w0, w1, h, r) {
    linear_extrude(height = h, scale = w1 / w0, convexity = 10)
        offset(r = r) square([w0 - 2 * r, w0 - 2 * r], center = true);
}

// 在 (z, y) 平面画多边形 [[z, y], ...] 并沿 x 拉伸 w (居中) —— 用来做卡唇/斜面
module prof(w, pts) {
    rotate([0, -90, 0])
        linear_extrude(height = w, center = true, convexity = 10) polygon(pts);
}

module shell() {
    difference() {
        slab(w_out(0), w_out(H), H, R_OUT);
        chamfer_cut();
    }
}

// 顶缘倒角: 从 z = H-CHAMF 起, 把目标外形之外的料切掉。
// 刀具内孔底面与主体截面【完全一致】(零厚度切口), 所以不会在侧壁上留台阶。
module chamfer_cut() {
    zc = H - CHAMF;
    wc = w_out(zc);
    wt = w_out(H) - 2 * CHAMF;
    translate([0, 0, zc])
        difference() {
            translate([-OUT_W, -OUT_W, 0]) cube([2 * OUT_W, 2 * OUT_W, CHAMF + 1]);
            linear_extrude(height = CHAMF + 1, scale = wt / wc, convexity = 10)
                offset(r = R_OUT) square([wc - 2 * R_OUT, wc - 2 * R_OUT], center = true);
        }
}

module cavity() {                       // 内腔 (向下多切 0.5, 避免与底面共面)
    over = 0.5;
    translate([0, 0, -over]) slab(w_in(-over), w_in(CAV_H), CAV_H + over, R_CAV);
}

// 顶面指窝。★必须用「真实球心偏移」的真球, 不能用 scale() 压扁球体★
// 非等比 scale 会把球面四边形拉成非平面多边形, CGAL 求差会静默出错
// (实测: 包围盒从 18.000 掉到 17.872, 体积偏 -10%)。
module dish() {
    translate([0, 0, H + R_SPH - DISH]) sphere(r = R_SPH, $fn = DISH_FN);
}

// ---------------------------------------------------------------------------
//  底面卡扣 (局部坐标: 原点在卡扣中心, 外法线 = +y, 顶面 = Z_TOP)
// ---------------------------------------------------------------------------
CW = 2.3;   // 卡扣宽 (x)
TH = 0.9;   // 卡爪 / 弹片厚 (y)
Z0 = 1.15;  // 卡扣下沿

module clip(kind) {
    if (kind == "hook") {
        // L 形卡爪: 竖片 + 底部外翻卡唇 (钩住剪刀脚顶板上的横杆)
        translate([-CW / 2, -TH / 2, Z0]) cube([CW, TH, Z_TOP - Z0]);
        prof(CW, [[Z0, -TH / 2], [Z0 + 0.9, -TH / 2],
                  [Z0 + 0.9, TH / 2 + 0.8], [Z0, TH / 2 + 0.8]]);
    } else if (kind == "fork") {
        // 双柱夹口: 两片柱子夹住横销 (靠弹性/摩擦, 不需要倒扣)
        GAP = 1.3; PW = 0.8; PH = 1.0;
        for (s = [-1, 1])
            translate([-CW / 2, s > 0 ? GAP / 2 : -GAP / 2 - PW, PH])
                cube([CW, PW, Z_TOP - PH]);
    } else if (kind == "boss") {
        // 圆柱凸台 + 横向通孔 (销子直接穿进去)
        difference() {
            translate([0, 0, 1.0]) cylinder(r = 1.3, h = Z_TOP - 1.0);
            translate([0, 0, 1.7]) rotate([0, 90, 0]) cylinder(r = 0.75, h = 8, center = true);
        }
    } else if (kind == "snap") {
        // 悬臂弹片: 下方 45 度导入斜面 + 上方止退面
        translate([-CW / 2, -TH / 2, 0.9]) cube([CW, TH, Z_TOP - 0.9]);
        prof(CW, [[1.50, -TH / 2], [2.35, -TH / 2],
                  [2.35, 1.30], [2.05, 1.30], [1.50, 0.80]]);
    }
    // "none" -> 什么都不画
}

module clips(kind) {
    if (kind != "none")
        for (sx = [-1, 1]) {
            translate([sx * CLIP_X,  CLIP_Y, 0]) clip(kind);            // 后边 2 个
            translate([sx * CLIP_X, -CLIP_Y, 0]) rotate([0, 0, 180]) clip(kind); // 前边 2 个
        }
}

// ---------------------------------------------------------------------------
//  成品    (show_* 只给 verify.py 的负向对照用; 正常渲染不用改)
// ---------------------------------------------------------------------------
module keycap(kind = CLIP, show_dish = true, show_clips = true) {
    $fn = FN;
    union() {
        difference() {
            shell();
            cavity();
            if (show_dish) dish();
        }
        // 卡扣必须在挖腔【之后】并回, 否则会被内腔切掉
        if (show_clips) clips(kind);
    }
}

keycap();
