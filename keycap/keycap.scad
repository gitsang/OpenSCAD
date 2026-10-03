// ============================================================================
//  笔记本式 1u 薄键帽  (low-profile / scissors keycap)
//  ---------------------------------------------------------------------------
//  外形 : 顶面 18.0 x 18.0  ->  底面外缘 15.6 x 15.6,  总高 5.5 mm
//         笔记本键帽是「上大下小」的倒锥台(侧裙向外张开), 与机械键帽相反。
//  底面 : 2 个卡勾(前) + 2 个卡槽(后) + 中央橡胶碗定位坑 -- 剪刀脚支架接口。
//  顶面 : 浅球面指窝 (R60 / 深 0.30)。
//
//  预览 : openscad keycap.scad
//  导出 : openscad -o keycap.stl keycap.scad
//  自检 : run_verify.bat        (几何 / 探针 / 连通性 / 负向对照)
// ============================================================================

FN = 64;

/* ------------------------------- 外形 ------------------------------- */
TOP_W  = 18.0;   // 顶面边长
BOT_W  = 15.6;   // 底面外缘边长
H      = 5.5;    // 总高
WALL   = 1.4;    // 侧壁厚 (= 未扣凹坑时的顶板厚)
R_BOT  = 1.9;    // 底面圆角 (顶面圆角 = R_BOT*TOP_W/BOT_W ≈ 2.19)
DISH   = 0.30;   // 顶面指窝深
R_SPH  = 60.0;   // 指窝球面半径
DISH_FN = 32;    // 指窝球面细分 (只有 Ø12 的浅坑, 32 足够; 64 会让 CGAL 慢 4 倍)

/* ----------------------------- 底面接口 ----------------------------- */
HOOK_X    = 4.4; // 卡勾中心 +/-x
HOOK_W    = 3.0; // 卡勾宽
HOOK_YIN  = 5.9; // 竖块内表面 |y| (越小凸出越多)
HOOK_YLIP = 4.5; // 卡唇内表面 |y|
HOOK_Z0   = 1.0; // 竖块下沿
HOOK_Z1   = 3.2; // 竖块上沿 = 卡唇下沿
LIP_Z     = 4.3; // 卡唇上沿 (> CAV_H, 与顶板融合)

SLOT_X    = 4.4; // 卡槽中心 +/-x
SLOT_W    = 3.0; // 卡槽宽
SLOT_Z0   = 1.4; // 卡槽下沿
SLOT_Z1   = 3.2; // 卡槽上沿

PAD_R     = 4.0; // 橡胶碗定位坑半径
PAD_D     = 0.2; // 定位坑深

/* ------------------------------ 派生量 ------------------------------ */
SLOPE   = (TOP_W - BOT_W) / 2 / H;      // 外壁半宽随 z 的斜率 (0.2182)
CAV_BOT = BOT_W - 2 * WALL;             // 内腔底面边长
CAV_H   = H - WALL;                     // 内腔顶面 z (= 顶板下表面)
CAV_TOP = CAV_BOT + 2 * SLOPE * CAV_H;  // 内腔顶部边长 (与外壳同斜度 -> 等壁厚)
R_CAV   = R_BOT - WALL;                 // 内腔圆角

function h_in(z)  = CAV_BOT / 2 + SLOPE * z;   // 内壁 |y|
function h_out(z) = BOT_W  / 2 + SLOPE * z;    // 外壁 |y|

// ---------------------------------------------------------------------------
//  几何基元
// ---------------------------------------------------------------------------
// 圆角方锥台: 底面 w0 -> 顶面 w1, 高 h, 底面圆角 r0
module frustum(w0, w1, h, r0) {
    linear_extrude(height = h, scale = w1 / w0, convexity = 10)
        offset(r = r0)
            square([w0 - 2 * r0, w0 - 2 * r0], center = true);
}

module shell() {                       // 实心外壳 (未挖腔)
    frustum(BOT_W, TOP_W, H, R_BOT);
}

module cavity() {                      // 内腔 (向下多切 0.5, 避免与底面共面)
    over = 0.5;
    translate([0, 0, -over])
        frustum(2 * h_in(-over), 2 * h_in(CAV_H), CAV_H + over, R_CAV);
}

module dish() {                        // 顶面指窝：用垂直缩放的浅球冠实现
    translate([0, 0, H])
        scale([1, 1, DISH / R_SPH])
            sphere(r = R_SPH, $fn = DISH_FN);
}

module pad_pocket() {                  // 橡胶碗定位坑
    translate([0, 0, CAV_H - 0.6]) cylinder(r = PAD_R, h = 0.6 + PAD_D + 0.03);
}

// 卡勾本体: 与外壳【求交】, 于是勾的外表面天然与侧裙齐平 ——
// 既不会在外表面留下台阶, 也不会在壁里留一条薄片/缝隙。
module hook_tab(yin, ylip, z0, z1, lz) {
    intersection() {
        union() {
            translate([0, -20, z0])  cube([HOOK_W, 20 - yin,  z1 - z0]);   // 竖块
            translate([0, -20, z1])  cube([HOOK_W, 20 - ylip, lz - z1]);   // 卡唇
        }
        shell();
    }
}

module hooks(yin, ylip) {              // 2 个卡勾 (前侧, y<0)
    for (sx = [HOOK_X - HOOK_W / 2, -HOOK_X - HOOK_W / 2])
        translate([sx, 0, 0]) hook_tab(yin, ylip, HOOK_Z0, HOOK_Z1, LIP_Z);
}

module slot_cuts() {                   // 2 个卡槽 (后侧, 通孔)
    for (sx = [SLOT_X, -SLOT_X])
        translate([sx - SLOT_W / 2, 4.0, SLOT_Z0])
            cube([SLOT_W, 20 - 4.0, SLOT_Z1 - SLOT_Z0]);
}

// ---------------------------------------------------------------------------
//  成品    (show_* 只给 verify.py 的负向对照用; 正常渲染不用改)
// ---------------------------------------------------------------------------
module keycap(show_dish = true, show_pad = true, show_hook = true, show_slot = true,
              hook_yin = HOOK_YIN, hook_ylip = HOOK_YLIP) {
    $fn = FN;
    union() {
        difference() {
            shell();
            cavity();
            if (show_dish) dish();
            if (show_pad)  pad_pocket();
            if (show_slot) slot_cuts();
        }
        // 卡勾必须在挖腔【之后】并回, 否则会被内腔切掉
        if (show_hook) hooks(hook_yin, hook_ylip);
    }
}

keycap();
