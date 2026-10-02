/* =====================================================================
   Bambu Lab A1 mini 封箱 (Enclosure) —— 2020 铝型材
   ---------------------------------------------------------------------
   坐标系: 原点在【前-下-左 外角】
     X = 宽度 (左->右)   Y = 进深 (前->后)   Z = 高度 (向上)
   前门朝 -Y 方向, 箱体内部在 y > 0 一侧。

   组成:
     · 12 根 2020 型材主框 (4 腿 + 上下各 4 根横梁)
     · 2 扇双开前门 (2020 门框), 内嵌于前框开口内
     · 6 块内嵌玻璃 (左/右/后/顶 + 2 门), 边沿卡进 T 型槽
     · 8 个【三通角件】框角, 装在箱体外面: 1 腿 + 2 梁, 各 4 颗 M5
       8 个【二通角件】门角, 贴在门的内侧背面: 2 根共面型材, 各 2 颗 M5
     · 铰链 + 拉手 (示意)

   连接件说明:
     用 CONNECTOR 切换: "3WAY" = 外置三通/二通 (默认, 已验证无干涉)
                      "L"    = 原来的内置 L 角码 (与玻璃/门干涉, 仅对照)
     为什么外置: 玻璃吃掉了腿的 ±Y 槽和横梁的 ±Z 槽, 内嵌门又占了前框在内
     侧的全部空间 → 内置角件没有落脚点。外置件只吃【外表面槽】, 全空闲。

   重要假设 —— 请按自己机器实测修正:
     MACH_D = 315 是 A1 mini 静态外形; 它是【床板前后摆动机】,
     实际前后需要额外行程, 这里按每侧 BED_OVER = 60 mm 预留。
     请自行量一下床板到最前/最后位置的总深度再定 INT_D。

   用法:
     openscad a1mini_enclosure.scad                       # 预览 (F5)
     openscad -o box.stl a1mini_enclosure.scad            # 导出装配体
     openscad -o box.stl -D 'DOOR_ANGLE=90' a1mini_enclosure.scad
   ===================================================================== */

/* ============================== 参数 =============================== */

P      = 20;    // 2020 型材
$fn    = 24;

/* --- A1 mini 机器 --- */
MACH_W = 347;   // 机器宽
MACH_D = 315;   // 机器深 (静态)
MACH_H = 365;   // 机器高
BED_OVER = 60;  // 床板前后摆动余量 (每侧)  <-- 按实机实测调整
TOP_CLEAR = 55; // 顶部余量 (走 PTFE 管 / 电源线)

/* --- 箱内净空 = 机器 + 间隙 --- */
INT_W = 420;    // = 347 + 2*36.5
INT_D = 480;    // = 315 + 2*60 + 2*22.5
INT_H = 420;    // = 365 + 55

/* --- 外廓 = 净空 + 2P --- */
OUT_W = INT_W + 2*P;    // 460
OUT_D = INT_D + 2*P;    // 520
OUT_H = INT_H + 2*P;    // 460

/* --- 内嵌玻璃面板 --- */
PANEL_T   = 4;   // 玻璃厚
PANEL_EN  = 4;   // 板边卡进 T 型槽的深度 (槽深 6, 留 2 余量)
/* 内凹量必须让整块板落在槽【颈口】以内, 否则板边会啃到槽唇:
   2020 槽: 腔 x∈[4.5,15.5], 颈口 x∈[6.9,13.1] (相对型材中心)
   板厚 4 → 外表面 x 必须在 [6.9, 9.1] 之间, 取中值 8
   (旧的 6 会让板啃进槽唇 0.9 mm, 见 _diag 测得 15 638 mm^3 干涉) */
PANEL_REC = 8;   // 板外表面相对框体外表面的内凹量

/* --- 双开前门 --- */
DOOR_GAP = 2.5;  // 门与门框开口的四周间隙 (铰链侧/上下)
DOOR_MID = 3.0;  // 两扇门中间的缝
LEAF_W   = (INT_W - 2*DOOR_GAP - DOOR_MID) / 2;   // 206
LEAF_H   = INT_H - 2*DOOR_GAP;                     // 415
LEAF_XL  = P + DOOR_GAP;                           // 左门 左边缘 x = 22.5
LEAF_XR  = OUT_W - P - DOOR_GAP - LEAF_W;          // 右门 左边缘 x = 231.5
LEAF_Z0  = P + DOOR_GAP;                           // 门 下边缘 z = 22.5

DOOR_ANGLE  = 0;  // 开门角度 (预览用)
PIVOT_INSET = 0;  // 铰链轴相对门「外边缘」的横向内移量
PIVOT_Y     = 0;  // 铰链轴深度位置。★必须为 0★
/*  ^ 内嵌门的关键约束:
     门「前-外角」在铰链轴前方 t 处。轴若位于前表面之后 (PIVOT_Y = t > 0),
     开门 θ 时该角点扫到 x = -t·sinθ, 于是拐进门/腿里去 (实撞)。
     PIVOT_Y = 6~10 时约 15° 就开始干涉 —— verify.py 有专门的负向测试。
     所以铰链销必须落在门的前表面平面上, 这就需要「偏置/跨装」型铰链。 */

/* --- 型材连接件: 三通(框) / 二通(门) --- */
/* 为什么做成【外置】: 内嵌玻璃占掉了腿的 ±Y 槽和横梁的 ±Z 槽, 内嵌的门又
   占满了前框在室内侧的全部空间 —— 内置角件要么撞玻璃要么撞门 (实测: 旧版
   16 个 L 角码与玻璃干涉 6 032 mm^3、与门 2 350 mm^3、还有 4 个装反了
   埋进腿里 4 283 mm^3)。外置件只用型材的【外表面槽】, 这些槽全部空闲。 */
CONNECTOR = "3WAY";  // "3WAY" = 三通(框)+二通(门) 角件 ; "L" = 原内置 L 角码
CT        = 5;       // 角件板厚
CA        = 20;      // 沿横梁方向的臂长
CH        = P;       // 沿腿方向的臂高
                     /* ★约束: CH <= P★ 角件的 z 范围必须完全落在下圈内 (z<P),
                        否则内嵌门开启约 120° 起门体会扫到 z∈[22.5,40] 这段
                        角件 (推导见 verify.py H 段旁的注记 / 可自行放大 CH 复现) */
CL2       = 40;      // 门二通角件的臂长
CSCREW    = 5.2;     // 螺丝孔直径 (M5)
C_HOLE    = 13;      // 腿上螺丝孔位置 (自外角沿腿量)
C_HOLE_E  = 7;       // 横梁上螺丝孔到臂末端距离

/* 旧方案 (内置 L 角码) 用的尺寸 —— CONNECTOR = "L" 时才用到 */
BR_L = 20;  BR_W = 16;  BR_T = 5;   // 角件臂长 / 宽 / 厚

SHOW_BRACKETS = true;
SHOW_HINGES   = true;
SHOW_HANDLES  = true;
SHOW_MACHINE  = false;   // 显示 A1 mini 包络 (检查用)

/* ======================= 2020 型材截面 ============================ */
/* 单条 T 型槽的切口轮廓 (槽口朝 +X 面)
   槽口宽 6.2 / 内腔宽 11 / 槽深 6 / 唇厚 2.4                       */
module tslot_2d() {
    polygon(points = [
        [10.0,  3.1], [ 7.6,  3.1], [ 7.6,  5.5], [ 4.0,  5.5],
        [ 4.0, -5.5], [ 7.6, -5.5], [ 7.6, -3.1], [10.0, -3.1]
    ]);
}

/* 2020 截面, 居中于原点 */
module p2020_2d() {
    difference() {
        offset(r = 2) offset(delta = -2) square([P, P], center = true);
        for (a = [0, 90, 180, 270]) rotate(a) tslot_2d();
        circle(d = 4.2, $fn = 16);
    }
}

/* 一段型材: 沿 +Z 挤出, 截面中心在原点 */
module beam(len) { linear_extrude(height = len, convexity = 10) p2020_2d(); }

/* ------------------------- 摆放助手 ------------------------------ */
module beamX(x0, len, yc, zc) { translate([x0, yc, zc]) rotate([0, 90, 0])  beam(len); }
module beamY(y0, len, xc, zc) { translate([xc, y0, zc]) rotate([-90, 0, 0]) beam(len); }
module beamZ(z0, len, xc, yc) { translate([xc, yc, z0]) beam(len); }

/* ========================= 主框型材 ============================== */
/* 4 根通高腿 + 上下两个矩形圈
   前后横梁长 INT_W (夹在两腿之间), 左右横梁长 INT_D (夹在前后梁之间) */
module extrusions() {
    for (x = [P/2, OUT_W - P/2], y = [P/2, OUT_D - P/2])
        beamZ(0, OUT_H, x, y);

    for (z = [0, OUT_H - P]) {
        beamX(P, INT_W, P/2,           z + P/2);   // 前
        beamX(P, INT_W, OUT_D - P/2,   z + P/2);   // 后
        beamY(P, INT_D, P/2,           z + P/2);   // 左
        beamY(P, INT_D, OUT_W - P/2,   z + P/2);   // 右
    }
}

/* ================== 连接件: 三通角件 (外置) ======================= */
/* 一件连接 3 根型材 = 1 根腿 + 2 根横梁。装在箱体的【外角】上: 两块垂直的
   板分别贴住前/后横梁和左/右横梁的外表面 (同时盖住腿的外表面), 再用一个
   角柱包住型材的外棱。每根型材各配 1 个 T 型螺母 + M5 螺丝 —— 腿 2 个
   (两个面各 1), 两根梁各 1 个 → 共 4 个。
   这个形状对【角柱竖轴】有 90° 旋转对称 → 同一个零件用于全部 8 个框角,
   不需要左右件。

   局部坐标: 箱体外角在原点
     +X = 沿前/后横梁向箱内
     +Y = 沿左/右横梁向箱内
     +Z = 向上 (下圈) / 整体 mirror Z (上圈)
   型材位置: 腿 = [0,P]×[0,P];  X 向横梁 = x∈[P,P+CA], z∈[0,P];
             Y 向横梁 = y∈[P,P+CA], z∈[0,P]                        */
module corner3_outer() {
    difference() {
        union() {
            translate([0,  -CT, 0]) cube([P + CA, CT, CH]);   // 前面板: 腿 + X 向横梁
            translate([-CT, 0,  0]) cube([CT, P + CA, CH]);   // 侧面板: 腿 + Y 向横梁
            translate([-CT, -CT, 0]) cube([CT, CT, CH]);      // 角柱: 包住型材外棱
        }
        // 前面板: 1 孔进腿的槽 + 1 孔进横梁的槽
        translate([P/2, -CT - 1, C_HOLE]) rotate([-90, 0, 0]) cylinder(d = CSCREW, h = CT + 4);
        translate([P + CA - C_HOLE_E, -CT - 1, P/2])
            rotate([-90, 0, 0]) cylinder(d = CSCREW, h = CT + 4);
        // 侧面板: 1 孔进腿的槽 + 1 孔进横梁的槽
        translate([-CT - 1, P/2, C_HOLE]) rotate([0, 90, 0]) cylinder(d = CSCREW, h = CT + 4);
        translate([-CT - 1, P + CA - C_HOLE_E, P/2])
            rotate([0, 90, 0]) cylinder(d = CSCREW, h = CT + 4);
    }
}

/* 摆到 4 个外角 × 上/下圈: (x_neg, y_neg) 选哪一个角, top 选上圈 (整体 Z 反向) */
module corner3(x_neg, y_neg, top) {
    multmatrix([[x_neg ? -1 : 1, 0,              0,  x_neg ? OUT_W : 0],
                [0,              y_neg ? -1 : 1, 0,  y_neg ? OUT_D : 0],
                [0,              0,              top ? -1 : 1, top ? OUT_H : 0],
                [0,              0,              0,  1]])
        corner3_outer();
}

/* ================== 连接件: 二通角件 (门, 外置) =================== */
/* 门框角 = 2 根共面型材 90° 相接 → 二通。门玻璃吃掉了竖梃/横梃的【内侧】
   槽, 所以门角件只能吃它们剩下的槽。这里用门【背面】(朝向箱内一侧) 的槽:
     · 背面槽完全空着 (玻璃在 y∈[6,10], 而背面槽腔在 y∈[14,17.6])
     · 角件在 y∈[P,P+CT] = 门内侧, 不外凸 —— 内嵌门的铰链轴在 y=0,
       任何 y<0 的凸出物开门时都会扫进框里 (铰链只凸 3mm 且刚好卡在轴上)
   局部坐标: 门外角在原点, +X 沿横梃, +Z 沿竖梃, 板在 y = P..P+CT */
module corner2_outer() {
    difference() {
        union() {
            translate([0, P, 0]) cube([P,   CT, CL2]);   // 竖梃臂
            translate([0, P, 0]) cube([CL2, CT, P  ]);   // 横梃臂
        }
        translate([P/2,      P + CT + 1, CL2 - 13]) rotate([90, 0, 0])
            cylinder(d = CSCREW, h = CT + 4);
        translate([CL2 - 13, P + CT + 1, P/2     ]) rotate([90, 0, 0])
            cylinder(d = CSCREW, h = CT + 4);
    }
}

/* 门的一扇叶上 4 个角: (x_neg, z_neg) 选角 */
module door_corner2(x0, z0, x_neg, z_neg) {
    multmatrix([[x_neg ? -1 : 1, 0, 0,  x_neg ? x0 + LEAF_W : x0],
                [0,              1, 0,  0],
                [0,              0, z_neg ? -1 : 1, z_neg ? z0 + LEAF_H : z0],
                [0,              0, 0,  1]])
        corner2_outer();
}

/* ================ 旧方案: 内置 L 角码 (CONNECTOR = "L") ============= */
/* 局部坐标: 内角在原点, 臂1 沿 +X (厚 BR_T), 臂2 沿 +Z, 宽度沿 +Y
   ⚠ 仅留作对照。实测与内嵌玻璃干涉 6 032 mm^3、与门 2 350 mm^3 —— 这套
   内置方案在「玻璃吃槽 + 内嵌门占满前框」的前提下是装不出来的。 */
module Lbracket() {
    difference() {
        union() {
            cube([BR_L, BR_W, BR_T]);          // 水平臂
            cube([BR_T, BR_W, BR_L]);          // 竖直臂
        }
        translate([BR_L - 7, BR_W/2, -1])
            cylinder(d = 5.2, h = BR_T + 2);                       // 臂1 螺丝孔
        translate([-1, BR_W/2, BR_L - 7]) rotate([0, 90, 0])
            cylinder(d = 5.2, h = BR_T + 2);                       // 臂2 螺丝孔
    }
}
/* 把角件摆到「腿侧面 + 梁表面」的角上。
   xc,yc = 角点水平位置 (yc/xc 取型材槽中心), zc = 梁那一侧的配合面高度 */
module orient_x(sx) { rotate([0, 0, sx > 0 ? 0 : 180]) translate([0, -BR_W/2, 0]) children(); }
module orient_y(sy) { rotate([0, 0, sy > 0 ? 90 : -90]) translate([0, -BR_W/2, 0]) children(); }

module bracket_x(xc, yc, zc, sx, down = false) {
    translate([xc, yc, zc])
        if (down) { mirror([0, 0, 1]) orient_x(sx) Lbracket(); }
        else      {                   orient_x(sx) Lbracket(); }
}
module bracket_y(xc, yc, zc, sy, down = false) {
    translate([xc, yc, zc])
        if (down) { mirror([0, 0, 1]) orient_y(sy) Lbracket(); }
        else      {                   orient_y(sy) Lbracket(); }
}

module brackets() {
    if (CONNECTOR == "3WAY") {
        for (t = [0, 1], xn = [0, 1], yn = [0, 1])
            color([0.32, 0.33, 0.36]) corner3(xn == 1, yn == 1, t == 1);
    } else {
        color([0.32, 0.33, 0.36]) {
        // 旧方案: 下圈 (z = P) 角件贴在腿侧面 + 梁上表面
        bracket_x(P,       P/2, P, +1);   bracket_x(OUT_W-P, P/2,       P, -1);
        bracket_x(P, OUT_D-P/2, P, +1);   bracket_x(OUT_W-P, OUT_D-P/2, P, -1);
        bracket_y(P/2,       P, P, +1);   bracket_y(P/2, OUT_D-P,       P, -1);
        bracket_y(OUT_W-P/2, P, P, +1);   bracket_y(OUT_W-P/2, OUT_D-P, P, -1);
        // 旧方案: 上圈 (z = OUT_H-P) 角件贴在腿侧面 + 梁下表面
        bracket_x(P,       P/2, OUT_H-P, +1, true);  bracket_x(OUT_W-P, P/2,       OUT_H-P, -1, true);
        bracket_x(P, OUT_D-P/2, OUT_H-P, +1, true);  bracket_x(OUT_W-P, OUT_D-P/2, OUT_H-P, -1, true);
        bracket_y(P/2,       P, OUT_H-P, +1, true);  bracket_y(P/2, OUT_D-P,       OUT_H-P, -1, true);
        bracket_y(OUT_W-P/2, P, OUT_H-P, +1, true);  bracket_y(OUT_W-P/2, OUT_D-P, OUT_H-P, -1, true);
        }
    }
}

/* ========================= 双开前门 ============================== */
/* 单扇门框 (2020), 左下角在 (x0, z0), 厚度方向 y ∈ [0, P] */
module leaf_raw(x0, z0) {
    for (dx = [P/2, LEAF_W - P/2])
        beamZ(z0, LEAF_H, x0 + dx, P/2);                        // 竖梃
    for (dz = [P/2, LEAF_H - P/2])
        beamX(x0 + P, LEAF_W - 2*P, P/2, z0 + dz);              // 横梃
}
/* 门玻璃, 内凹 PANEL_REC */
module leaf_glass(x0, z0) {
    translate([x0 + P - PANEL_EN, PANEL_REC, z0 + P - PANEL_EN])
        cube([LEAF_W - 2*P + 2*PANEL_EN, PANEL_T, LEAF_H - 2*P + 2*PANEL_EN]);
}
/* 门角件 (4 个/扇) */
module leaf_brackets(x0, z0) {
    if (CONNECTOR == "3WAY") {
        color([0.32, 0.33, 0.36]) {
            door_corner2(x0, z0, false, false);
            door_corner2(x0, z0, true,  false);
            door_corner2(x0, z0, false, true );
            door_corner2(x0, z0, true,  true );
        }
    } else {
        color([0.32, 0.33, 0.36]) {
            bracket_x(x0 + P,          P/2, z0 + P, +1);
            bracket_x(x0 + LEAF_W - P, P/2, z0 + P, -1);
            bracket_x(x0 + P,          P/2, z0 + LEAF_H - P, +1, true);
            bracket_x(x0 + LEAF_W - P, P/2, z0 + LEAF_H - P, -1, true);
        }
    }
}
/* 门拉手: 竖杆 + 两个支撑柱, 装在内侧竖梃上 */
module leaf_handle(x0, sgn) {
    xc = sgn < 0 ? x0 + LEAF_W - 10 : x0 + 10;   // 内侧竖梃中心
    zb = LEAF_Z0 + LEAF_H / 2;
    color([0.25, 0.25, 0.28]) {
        for (dz = [-55, 55])
            translate([xc, 0, zb + dz]) rotate([90, 0, 0]) cylinder(d = 8, h = 14);
        translate([xc, -18, zb - 70]) cylinder(d = 12, h = 140);
    }
}

/* 整扇门 (含玻璃/角件/拉手), 绕铰链轴旋转 angle
   sgn = -1 : 左门, 铰链在左边 -> 逆时针(-angle) 向外开
   sgn = +1 : 右门, 铰链在右边 -> 顺时针(+angle) 向外开 */
module leaf(x0, z0, sgn, angle = 0, inset = 0, pivot_y = 0) {
    pivot = sgn < 0 ? x0 + inset : x0 + LEAF_W - inset;
    translate([pivot, pivot_y, 0])
        rotate([0, 0, sgn < 0 ? -angle : angle])
        translate([-pivot, -pivot_y, 0]) {
            color([0.78, 0.79, 0.82]) leaf_raw(x0, z0);
            if (SHOW_BRACKETS) leaf_brackets(x0, z0);
            color([0.62, 0.82, 0.90, 0.35]) leaf_glass(x0, z0);
            if (SHOW_HANDLES) leaf_handle(x0, sgn);
        }
}

module doors() {
    leaf(LEAF_XL, LEAF_Z0, -1, DOOR_ANGLE, PIVOT_INSET, PIVOT_Y);
    leaf(LEAF_XR, LEAF_Z0, +1, DOOR_ANGLE, PIVOT_INSET, PIVOT_Y);
}

/* ======================= 内嵌玻璃面板 ============================= */
/* 左 / 右 / 后 / 顶 四块固定玻璃, 边沿卡入 T 型槽, 外表面内凹 PANEL_REC
   (底面留空 —— 机器直接放在台面上, 也让床板摆动不受阻) */
module panels() {
    color([0.62, 0.82, 0.90, 0.35]) {
        // 左
        translate([PANEL_REC, P - PANEL_EN, P - PANEL_EN])
            cube([PANEL_T, INT_D + 2*PANEL_EN, INT_H + 2*PANEL_EN]);
        // 右
        translate([OUT_W - PANEL_REC - PANEL_T, P - PANEL_EN, P - PANEL_EN])
            cube([PANEL_T, INT_D + 2*PANEL_EN, INT_H + 2*PANEL_EN]);
        // 后
        translate([P - PANEL_EN, OUT_D - PANEL_REC - PANEL_T, P - PANEL_EN])
            cube([INT_W + 2*PANEL_EN, PANEL_T, INT_H + 2*PANEL_EN]);
        // 顶: ★十字形★。水平板的四条边都要卡进槽, 但 4 个角【不能】跟进腿里:
        // 腿上的槽是竖的 (沿 Z), 水平板的角在腿的内角处是实心 → 会啃 4x4x4 mm
        // 一块 (实测 241.7 mm^3)。所以把 4 个角剪掉 → 边长条各吃一条槽。
        translate([P - PANEL_EN, P, OUT_H - PANEL_REC - PANEL_T])
            cube([INT_W + 2*PANEL_EN, INT_D, PANEL_T]);              // 左右向长条
        translate([P, P - PANEL_EN, OUT_H - PANEL_REC - PANEL_T])
            cube([INT_W, INT_D + 2*PANEL_EN, PANEL_T]);              // 前后向长条
    }
}

/* ======================== 铰链 (示意) ============================= */
/* ======================== 铰链 (示意) ============================= */
/* 铰链轴正好在门「前-外角」上: x = 门的外边, y = 0
   这是内嵌门能正常开启的关键 —— 轴一旦内移就会撞框 (见 verify.py)
   door_dir = +1 : 门体在 x > x_pivot 一侧 (左门)
   door_dir = -1 : 门体在 x < x_pivot 一侧 (右门)                        */
module xspan(x1, x2, y0, dy, z0, dz) {
    translate([min(x1, x2), y0, z0]) cube([abs(x2 - x1), dy, dz]);
}
module hinge_unit(x_pivot, door_dir, zc, pivot_y = 0) {
    L = 60; E = 14.5;
    color([0.35, 0.36, 0.40]) {
        xspan(x_pivot - door_dir*E, x_pivot, -3, 3, zc - L/2, L);       // 框侧页板 (贴腿前面)
        xspan(x_pivot, x_pivot + door_dir*E, -3, 3, zc - L/2, L);       // 门侧页板 (贴门前面)
        translate([x_pivot, pivot_y - 1.5, zc - L/2])
            cylinder(r = 1.4, h = L);                                    // 轴销
    }
}
module hinges() {
    for (zc = [LEAF_Z0 + 70, LEAF_Z0 + LEAF_H - 70]) {
        hinge_unit(LEAF_XL + PIVOT_INSET, +1, zc, PIVOT_Y);
        hinge_unit(LEAF_XR + LEAF_W - PIVOT_INSET, -1, zc, PIVOT_Y);
    }
}

/* ===================== A1 mini 包络 (检查用) ====================== */
module machine_env() {
    color([0.9, 0.5, 0.3, 0.30])
        translate([(OUT_W - MACH_W)/2, (OUT_D - (MACH_D + 2*BED_OVER))/2, 0])
            cube([MACH_W, MACH_D + 2*BED_OVER, MACH_H]);
}

/* ============ 供 verify.py 调用的测试入口 (外部无法读变量) ========= */
module test_leaf(sgn, angle = 0, inset = 0, pivot_y = 0) {
    if (sgn < 0) leaf(LEAF_XL, LEAF_Z0, -1, angle, inset, pivot_y);
    else         leaf(LEAF_XR, LEAF_Z0, +1, angle, inset, pivot_y);
}
module test_machine()  { machine_env(); }
module test_panels()   { panels(); }
module test_frame()    { extrusions(); }
module test_doors()    { doors(); }
module test_brackets() { brackets(); }
module test_all_but_frame() { panels(); doors(); }

/* --- 单个连接件 & 只含该角 3 根型材的局部子集 (接触测试用, 渲染快) --- */
/* 局部坐标下的 3 根型材: 腿 + X 向横梁 + Y 向横梁 */
module corner3_members() {
    cube([P, P, OUT_H]);                        // 腿
    translate([P, 0, 0]) cube([INT_W, P, P]);   // X 向横梁
    translate([0, P, 0]) cube([P, INT_D, P]);   // Y 向横梁
}
module test_c3(xn, yn, top)  { corner3(xn == 1, yn == 1, top == 1); }
module test_c3_members(xn, yn, top) {
    multmatrix([[xn  ? -1 : 1, 0,            0, xn  ? OUT_W : 0],
                [0,            yn ? -1 : 1, 0, yn  ? OUT_D : 0],
                [0,            0,            top ? -1 : 1, top ? OUT_H : 0],
                [0,            0,            0, 1]])
        corner3_members();
}
/* 把连接件整体沿「插进型材」的方向平移 d (d>0 压进去, d<0 抽出来) */
module test_c3_shift(xn, yn, top, d) {
    translate([(xn ? -d : d), (yn ? -d : d), 0]) test_c3(xn, yn, top);
}

module test_c2(xl, zl, xn, zn) { door_corner2(xl, zl, xn == 1, zn == 1); }
/* 门角件贴在门【背面】(y=20), 所以压进去是 -Y */
module test_c2_shift(xl, zl, xn, zn, d) { translate([0, -d, 0]) test_c2(xl, zl, xn, zn); }module test_leaf_raw(xl, zl)  { leaf_raw(xl, zl); }
/* 开门运动学只需跟前腿求交: 门绕竖轴转, z 不变 (恒在上下横梁之间),
   且所有点的 y' = dx·sinθ + dy·cosθ <= 20, 永远到不了后腿。
   只取 2 根前腿可以让 CGAL 快 4 倍以上 (2021.01 没有 manifold 后端)。*/
module test_front_legs() {
    for (x = [P/2, OUT_W - P/2]) beamZ(0, OUT_H, x, P/2);
}

/* ============================ 装配 =============================== */
module assembly() {
    color([0.78, 0.79, 0.82]) extrusions();
    if (SHOW_BRACKETS) brackets();
    panels();
    doors();
    if (SHOW_HINGES) hinges();
    if (SHOW_MACHINE) machine_env();
}

assembly();

/* ========================== 切割清单 ============================= */
_leaf_beams = 2 * (2*LEAF_H + 2*(LEAF_W - 2*P));
echo("=========== 2020 extrusion cut list ===========");
echo(str("legs        x 4 : ", OUT_H, " mm"));
echo(str("front/back  x 4 : ", INT_W, " mm"));
echo(str("left/right  x 4 : ", INT_D, " mm"));
echo(str("door stiles x 4 : ", LEAF_H, " mm"));
echo(str("door rails  x 4 : ", LEAF_W - 2*P, " mm"));
echo(str("total length    : ", 4*OUT_H + 4*INT_W + 4*INT_D + _leaf_beams, " mm"));
echo(str("outer WxDxH     : ", OUT_W, " x ", OUT_D, " x ", OUT_H, " mm"));
echo(str("interior clear  : ", INT_W, " x ", INT_D, " x ", INT_H, " mm"));
echo(str("door opening    : ", INT_W, " x ", INT_H, " mm -> leaf ", LEAF_W, " x ", LEAF_H));
if (CONNECTOR == "3WAY") {
    echo(str("connector mode  : 三通(框)/二通(门) 角件"));
    echo(str("  三通角件 x 8  : 臂 ", P + CA, " 长, 高 ", CH, ", 厚 ", CT, ", 各 4x M5"));
    echo(str("  二通角件 x 8  : 臂 ", CL2, " 长, 厚 ", CT, ", 装在门背面, 各 2x M5"));
    echo(str("  五金合计      : M5x12 内六角 x ", 8*4 + 8*2, " + 2020 T 型螺母 x ", 8*4 + 8*2));
    echo(str("  外形(含角件)  : ", OUT_W + 2*CT, " x ", OUT_D + 2*CT, " x ", OUT_H, " mm"));
} else {
    echo("connector mode  : 内置 L 角码 (CONNECTOR=\"L\")");
    echo("  ! 此模式与内嵌玻璃/门干涉, 仅供对照");
}
echo("==============================================");
