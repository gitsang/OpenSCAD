/* =====================================================================
   3030 铝型材猫屋 (Cat House / Cat Tower) —— OpenSCAD
   ---------------------------------------------------------------------
   外廓: 1200 (W) x 600 (D) x 2000 (H) mm   —— 即你要求的 120x60x200 cm

   坐标系 (原点在【前-下-左】外角):
       X = 宽度 (左 -> 右,  0 .. 1200)
       Y = 进深 (前 -> 后,  0 .. 600)   前脸在 y = 0
       Z = 高度 (下 -> 上,  0 .. 2000)

   分层 (从下到上, 每层净高约 450):
       L0  0    .. 500   猫厕所     —— 全木板, 不透光, 木门 + 猫洞 + 木翻板
       L1  500  .. 1000  吃饭喝水   —— 透明亚克力, 放自动喂食机 + 饮水机
       L2  1000 .. 1500  娱乐       —— 透明亚克力, 跳台 / 磨爪板 / 玩具
       L3  1500 .. 1952  休息观景   —— 透明亚克力, 猫窝 + 顶灯位置

   结构:
       · 4 根通高 3030 腿 + 5 道水平 3030 圈梁
       · 每道圈梁 4 个内角各 1 个 3030 三角角码 (共 20 个)
       · 4 块木层板 + 1 块木顶板 (1200x600, 四角按腿形挖缺口)
       · 每层 4 面围板, 板外表面与型材外表面齐平 (外观是一整片平面):
           L0        : 木板 (左/右/后/门)
           L1/L2/L3  : 左/右/前 亚克力, 背板仍为木板
       · 每层前脸 2 扇对开门 (L0 木门 / L1~L3 亚克力门)
       · 一根通高剑麻猫爬柱 + 3 个木跳台 + 磨爪板

   用法:
       openscad cat_house.scad                        # 预览 (F5)
       openscad -o cat_house.stl cat_house.scad       # 导出 (F6)
       openscad -D 'DOOR_ANG=45' cat_house.scad       # 开门预览
       python verify.py                               # 自动自检

   装配提示:
       · 这是【理想尺寸】模型。实际下料请给槽内连接件留 0.2~0.4 mm 间隙。
       · 型材端面攻 M8 螺纹, 三角角码用 T 型螺母 + M8 螺丝。
       · 亚克力板 5 mm 直接卡在型材外沿, 用压条/L 型小压片固定。
       · 层板 15 mm 多层板直接搭在圈梁上表面, 四边全支撑。
   ===================================================================== */

/* ============================== 参数 =============================== */

P       = 30;      // 3030 型材
$fn     = 24;

OUT_W   = 1200;    // 总宽
OUT_D   = 600;     // 总深
OUT_H   = 2000;    // 总高 (含顶板)
INT_W   = OUT_W - 2*P;    // 1140  腿内净宽
INT_D   = OUT_D - 2*P;    // 540   腿内净深

T_WOOD  = 15;      // 木板厚 (多层板)
T_ACR   = 5;       // 亚克力板厚
T_ROOF  = 15;      // 顶板厚

N_LEV      = 4;        // 层数
LEV_PITCH  = 500;      // 圈梁间距
TOP_RING_Z = OUT_H - P - T_ROOF;   // 1952  顶层圈梁底面 (顶板直接盖在上面)

/* --- 猫爬柱 / 跳台 / 层板猫洞 --- */
POST_D  = 110;     // 剑麻柱直径
POST_X  = 1060;    // 柱心 X (后右角附近)
POST_Y  = 450;     // 柱心 Y
HOLE_D  = 200;     // 层板猫洞直径
HOLE_X  = 1000;    // 猫洞中心 (L1~L3 层板, 位于柱旁边)
HOLE_Y  = 250;
PLAT_W  = 300;     // 跳台尺寸
PLAT_D  = 240;
PLAT_X  = 960;     // 跳台中心 (尽量落在层板猫洞正下方)
PLAT_Y  = 380;
PLAT_Z  = [380, 790, 1290];        // 三层跳台的底面高度

/* --- 门的间隙 --- */
DOOR_GAP  = 1.5;   // 门与门洞四周间隙
DOOR_MID  = 3.0;   // 两扇门之间的中缝
DOOR_ANG  = 0;     // 预览用开门角度
PV_Y      = -6;    // 铰链销的进深位置: 在型材前表面【之前】 6 mm
/*  为什么是 -6 而不是 0:
      铰链轴套半径 6, 若销在 y = 0, 轴套会向 -Y 伸到 x = px-6 = 25.5 < 30,
      正好插进前腿里。把销前移到 -6, 轴套完全落在 y ≤ 0 (型材前面以外),
      而门体 y ∈ [0, T] 绕该销转动时最靠内的点仍然是 x = px = 31.5 > 30,
      所以 0~180° 全程不会撞腿。verify.py 对此有正/负向双重测试。 */

/* --- 三角角码 --- */
BKT_L = 45;        // 直角边长
BKT_T = 8;         // 厚

/* --- 显示开关 --- */
SHOW_BRACKETS = true;
SHOW_DETAILS  = true;      // 铰链/拉手/翻板
SHOW_CONTENTS = true;      // 喂食机/饮水机/猫砂盆/猫爬柱等

/* --- 配色 --- */
C_AL   = [0.80, 0.81, 0.84];
C_BKT  = [0.32, 0.33, 0.36];
C_WOOD = [0.72, 0.53, 0.34];
C_ACR  = [0.62, 0.82, 0.90, 0.32];
C_SISA = [0.85, 0.76, 0.58];

/* ========================= 层高换算函数 ============================ */
function ring_z(i)   = i < N_LEV ? i*LEV_PITCH : TOP_RING_Z;
function shelf_z0(i) = ring_z(i) + P;              // 层板底面 (搭在圈梁上表面)
function shelf_z1(i) = shelf_z0(i) + T_WOOD;       // 层板顶面
function wall_z0(i)  = shelf_z1(i);                // 该层围板底
function wall_z1(i)  = ring_z(i + 1);              // 该层围板顶
function wall_h(i)   = wall_z1(i) - wall_z0(i);
function is_wood(i)  = i == 0;                     // 只有最底层用木板
function sheet_t(i)  = is_wood(i) ? T_WOOD : T_ACR;
function leaf_w()    = (INT_W - 2*DOOR_GAP - DOOR_MID) / 2;

/* ======================= 3030 型材截面 ============================= */
/* 单条 T 型槽 (槽口朝 +X 面), 含槽后减重腔
   槽口宽 6.2 / 唇厚 2.4 / 腔宽 11 / 总深 9.2                     */
module slot3030_2d() {
    polygon(points = [
        [15.0,  3.1], [12.6,  3.1], [12.6,  5.5], [ 5.8,  5.5],
        [ 5.8, -5.5], [12.6, -5.5], [12.6, -3.1], [15.0, -3.1]
    ]);
}

/* 3030 截面, 居中于原点. 截面面积 = 900 - 7.73(圆角) - 4*89.68(槽) - 36.32(中孔)
                              = 497.24 mm^2  (~55% 实心, 与真料 1.15~1.35 kg/m 相当) */
module p3030_2d() {
    difference() {
        offset(r = 3) offset(delta = -3) square([P, P], center = true);
        for (a = [0, 90, 180, 270]) rotate(a) slot3030_2d();
        circle(d = 6.8, $fn = 16);     // 中心孔, 攻 M8
    }
}

/* 一段型材: 沿 +Z 挤出, 长度 len, 截面中心在原点 */
module beam(len) { linear_extrude(height = len, convexity = 10) p3030_2d(); }

/* --------------------------- 摆放助手 ----------------------------- */
module beamX(x0, len, yc, zc) { translate([x0, yc, zc]) rotate([0, 90, 0])  beam(len); }
module beamY(y0, len, xc, zc) { translate([xc, y0, zc]) rotate([-90, 0, 0]) beam(len); }
module beamZ(z0, len, xc, yc) { translate([xc, yc, z0]) beam(len); }

/* ============================ 主框 ================================= */
module legs() {
    for (x = [P/2, OUT_W - P/2], y = [P/2, OUT_D - P/2])
        beamZ(0, OUT_H - T_ROOF, x, y);
}

module ring(i) {
    z = ring_z(i);
    beamX(P, INT_W, P/2,       z + P/2);   // 前
    beamX(P, INT_W, OUT_D-P/2, z + P/2);   // 后
    beamY(P, INT_D, P/2,       z + P/2);   // 左
    beamY(P, INT_D, OUT_W-P/2, z + P/2);   // 右
}

module rings() { for (i = [0 : N_LEV]) ring(i); }
module extrusions() { legs(); rings(); }

/* ======================== 3030 三角角码 ============================ */
/* 平放在圈梁内角上: 直角顶点在角上, 两直角边贴两根圈梁内侧面
   斜边朝向箱内, 两个 M6 沉孔拧进圈梁上表面 T 型槽                     */
module tri_bracket() {
    difference() {
        linear_extrude(height = BKT_T) polygon(points = [[0,0], [BKT_L,0], [0,BKT_L]]);
        translate([BKT_L-15, 7, -1]) cylinder(d = 6.6, h = BKT_T+2, $fn = 16);
        translate([7, BKT_L-15, -1]) cylinder(d = 6.6, h = BKT_T+2, $fn = 16);
    }
}
module bracket_at(x0, y0, z0, mx, my) {
    translate([x0, y0, z0]) mirror([mx, 0, 0]) mirror([0, my, 0]) tri_bracket();
}
module brackets() {
    for (i = [0 : N_LEV]) {
        z = ring_z(i);
        bracket_at(P,       P,       z, 0, 0);
        bracket_at(OUT_W-P, P,       z, 1, 0);
        bracket_at(P,       OUT_D-P, z, 0, 1);
        bracket_at(OUT_W-P, OUT_D-P, z, 1, 1);
    }
}

/* ============================ 层板 ================================= */
/* 1200x600 整板, 四角挖出「比腿大 NOTCH_CLR」的方缺口。
   ⚠ 不要用「按腿截面等比放大」的方式做挖缺: 3030 截面中心是空腔
     (Ø6.8 中心孔 + 4 条槽腔), 以截面中心缩放会把空腔也放大,
     于是腿的实体反而露出一圈 0.1~0.2 mm 的细条和层板干涉;
     而且缩小后的中心孔会在一片被挖掉的区域里留下一块「孤岛板」。
     用外接方形挖缺, 简单、正确, 实际加工也只要两刀。            */
NOTCH_CLR = 1.0;                       // 方缺口每边比腿大 0.5 mm
NOTCH     = P + NOTCH_CLR;             // 31 mm

module shelf_plate() {
    difference() {
        cube([OUT_W, OUT_D, T_WOOD]);
        for (x = [P/2, OUT_W-P/2], y = [P/2, OUT_D-P/2])
            translate([x - NOTCH/2, y - NOTCH/2, -1])
                cube([NOTCH, NOTCH, T_WOOD + 2]);
    }
}

module shelf(i) {
    translate([0, 0, shelf_z0(i)])
        difference() {
            shelf_plate();
            if (i >= 1) translate([HOLE_X, HOLE_Y, -1])
                            cylinder(d = HOLE_D, h = T_WOOD + 2, $fn = 48);   // 猫洞
            if (i >= 1) translate([POST_X, POST_Y, -1])
                            cylinder(d = POST_D + 20, h = T_WOOD + 2, $fn = 32);  // 柱孔
        }
}
module shelves() { for (i = [0 : N_LEV-1]) shelf(i); }

module roof() { translate([0, 0, OUT_H - T_ROOF]) cube([OUT_W, OUT_D, T_ROOF]); }

/* ========================== 竖向围板 =============================== */
/* 左 / 右侧板: 板外表面与型材外表面齐平 (x = 0 或 x = OUT_W) */
module side_panel(i, side) {
    T  = sheet_t(i);
    x0 = side < 0 ? 0 : OUT_W - T;
    translate([x0, P, wall_z0(i)]) cube([T, INT_D, wall_h(i)]);
}

/* 背板 (永远是木板) */
module back_panel(i) {
    translate([P, OUT_D - T_WOOD, wall_z0(i)]) cube([INT_W, T_WOOD, wall_h(i)]);
}

module panels() {
    for (i = [0 : N_LEV-1]) {
        color(is_wood(i) ? C_WOOD : C_ACR) { side_panel(i, -1); side_panel(i, +1); }
        color(C_WOOD) back_panel(i);
    }
}

/* ============================= 门 ================================== */
/* 内嵌式门: 门平面在 y ∈ [0, t], 铰链轴落在门洞的「前-外角」上
   —— 这是内嵌门唯一不会撞框的轴位 (轴内移就会在转动时扫进取)
   sgn = -1 左扇 (绕 -Z 旋转打开) / +1 右扇 (绕 +Z 旋转打开)          */
module leaf_board(i, x0, cat_hole = false) {
    T = sheet_t(i);
    difference() {
        translate([x0, 0, wall_z0(i) + DOOR_GAP])
            cube([leaf_w(), T, wall_h(i) - 2*DOOR_GAP]);
        if (cat_hole)                                 // 只开在 L0 左扇木门上
            translate([x0 + 150, -1, wall_z0(i) + DOOR_GAP + 165])
                rotate([-90, 0, 0]) cylinder(d = 230, h = T + 2, $fn = 48);
    }
}

/* pv_y: 铰链销的进深位置。正确值是 0 (销正好落在门洞「前-外角」)。
   内移(>0) 时, 门的前-外角会在转动中扫到 x = px - pv_y·sinθ, 直接拐进腿里 —— verify.py 有负向对照。 */
module leaf(i, sgn, ang, pv_y = PV_Y, hinges = true) {
    T  = sheet_t(i);
    px = sgn < 0 ? P + DOOR_GAP : OUT_W - P - DOOR_GAP;
    x0 = sgn < 0 ? px : px - leaf_w();
    translate([px, pv_y, 0]) rotate([0, 0, sgn < 0 ? -ang : ang]) translate([-px, -pv_y, 0]) {
        color(is_wood(i) ? C_WOOD : C_ACR) leaf_board(i, x0, i == 0 && sgn < 0);
        if (hinges) color(C_BKT) leaf_hinges(i, sgn, px, pv_y);
    }
}

/* 铰链: 合页轴套正好套在销 (px, pv_y) 上, 绕该轴自转不改变外形, 所以可以直接放进门的组里 */
module leaf_hinges(i, sgn, px, pv_y) {
    T = sheet_t(i);
    for (zc = [wall_z0(i) + 90, wall_z1(i) - 90]) {
        translate([px, pv_y, zc]) cylinder(r = 6, h = 62, center = true);
        // 门侧叶片: 压在门内表面 (y = T)
        translate([sgn < 0 ? px : px - 26, T, zc - 31]) cube([26, 3, 62]);
    }
}

module doors() {
    for (i = [0 : N_LEV-1]) { leaf(i, -1, DOOR_ANG); leaf(i, +1, DOOR_ANG); }
}

/* 门框侧叶片 (贴型材前表面, 不随门转动) */
module door_frame_hinges() {
    for (i = [0 : N_LEV-1])
        for (sgn = [-1, 1]) {
            px = sgn < 0 ? P + DOOR_GAP : OUT_W - P - DOOR_GAP;
            for (zc = [wall_z0(i) + 90, wall_z1(i) - 90])
                translate([sgn < 0 ? px - 26 : px, -3, zc - 31]) cube([26, 3, 62]);
        }
}

/* 拉手: 装在两扇门相对的内侧边 */
module handles() {
    for (i = [0 : N_LEV-1])
        for (sgn = [-1, 1]) {
            xc = sgn < 0 ? P + DOOR_GAP + leaf_w() - 40 : OUT_W - P - DOOR_GAP - leaf_w() + 40;
            zc = (wall_z0(i) + wall_z1(i)) / 2;
            color(C_BKT) {
                for (dz = [-60, 60])
                    translate([xc, 0, zc + dz]) rotate([90, 0, 0]) cylinder(d = 10, h = 28);
                translate([xc, -28, zc - 70]) cylinder(d = 12, h = 140);
            }
        }
}

/* L0 木门上的猫洞翻板: 顶部铰链, 预览时开 FLAP_ANG 度 */
FLAP_ANG = 10;
module flap() {
    zc = wall_z0(0) + DOOR_GAP + 165;          // 猫洞中心
    zt = zc + 130;                             // 铰链高度 (猫洞上沿)
    xc = P + DOOR_GAP + 150;
    translate([xc, 0, zt]) rotate([-FLAP_ANG, 0, 0]) translate([-xc, 0, -zt])
        color(C_WOOD) translate([xc - 135, -12, zt - 268]) cube([270, 12, 268]);
}

/* ======================= 箱内物品 / 猫爬系统 ======================== */
module sisal_post() {
    color(C_SISA) translate([POST_X, POST_Y, shelf_z1(0)])
        cylinder(d = POST_D, h = TOP_RING_Z - shelf_z1(0), $fn = 32);
    color(C_BKT) translate([POST_X, POST_Y, shelf_z1(0)]) cylinder(d = POST_D + 60, h = 6, $fn = 32);  // 底座法兰
    for (z = PLAT_Z) color([0.62, 0.55, 0.40])           // 缠绳分界环
        translate([POST_X, POST_Y, z - 4]) cylinder(d = POST_D + 6, h = 4, $fn = 32);
}

module platforms() {
    color(C_WOOD) for (z = PLAT_Z)
        translate([PLAT_X - PLAT_W/2, PLAT_Y - PLAT_D/2, z]) cube([PLAT_W, PLAT_D, T_WOOD]);
}

module scratch_board() {          // 挂在 L2 左侧的剑麻磨爪板
    color(C_SISA) translate([T_ACR, 200, 1150]) cube([20, 340, 300]);
}

/* 半封闭猫砂盆 (示意) 480x340x400, 放在右侧, 门前留 100 mm 走道,
   这样从 L0 木门的猫洞进来不会一头撞在砂盆上                        */
module litter_box() {
    color([0.78, 0.79, 0.81]) difference() {
        translate([320, 120, 49]) cube([480, 340, 400]);
        translate([335, 135, 64]) cube([450, 310, 400]);
        translate([320 + 130, 119, 64]) cube([220, 40, 220]);      // 前脸入口
    }
    color([0.55, 0.58, 0.62]) translate([300, 100, 45]) cube([520, 380, 4]);  // 猫砂垫
}

module feeder() {                 // 自动喂食机 (示意)
    color([0.95, 0.95, 0.96]) {
        translate([60, 60, shelf_z1(1)]) cube([260, 300, 60]);        // 底盘
        translate([85, 85, shelf_z1(1) + 60]) cube([210, 250, 360]);  // 粮桶
    }
    color([0.35, 0.37, 0.40]) translate([95, 55, shelf_z1(1) + 20]) cube([190, 60, 30]);  // 食盆
}

module fountain() {               // 饮水机 (示意)
    z0 = shelf_z1(1);
    color([0.62, 0.82, 0.90, 0.45]) translate([600, 190, z0]) cylinder(d = 250, h = 260, $fn = 48);
    color([0.95, 0.95, 0.96]) translate([600, 190, z0]) cylinder(d = 130, h = 290, $fn = 32);
}

module cat_bed() {                // L3 猫窝 (示意)
    z0 = shelf_z1(3);
    color(C_WOOD) difference() {
        translate([80, 80, z0]) cube([460, 380, 300]);
        translate([95, 95, z0 + 15]) cube([430, 350, 300]);
        translate([80, 79, z0 + 15]) cube([300, 100, 200]);           // 门口
    }
    color([0.85, 0.72, 0.72]) translate([95, 95, z0 + 15]) cube([430, 350, 60]);  // 垫子
}

module toy_ball() {
    color([0.90, 0.45, 0.35]) translate([600, 320, 1420]) sphere(d = 90, $fn = 24);
    color([0.45, 0.45, 0.48]) translate([600, 320, 1465]) cylinder(d = 2, h = 65, $fn = 8);
}

module contents() {
    sisal_post(); platforms(); scratch_board();
    litter_box(); feeder(); fountain(); cat_bed(); toy_ball();
}

/* ================== 供 verify.py 调用的测试入口 ==================== */
/* (OpenSCAD 外部读不到变量, 只能通过模块暴露) */
module test_frame()     { extrusions(); }
module test_brackets()  { brackets(); }
module test_shelves()   { shelves(); }
module test_roof()      { roof(); }
module test_panels()    { panels(); }
module test_doors()     { doors(); }
module test_doors_at(a) { for (i = [0:N_LEV-1]) { leaf(i, -1, a); leaf(i, +1, a); } }
module test_leaf(i, sgn, a, pv_y = PV_Y) { leaf(i, sgn, a, pv_y); }
module test_shell() {
    extrusions(); brackets(); shelves(); roof(); panels();
    for (i = [0 : N_LEV-1]) { leaf(i, -1, 0, PV_Y, false); leaf(i, +1, 0, PV_Y, false); }
}
module test_contents()  { contents(); }
module test_post()      { sisal_post(); }
module test_platforms() { platforms(); }
module test_scratch()   { scratch_board(); }
module test_furniture() { litter_box(); feeder(); fountain(); cat_bed(); toy_ball(); }
module test_legs() {
    for (x = [P/2, OUT_W - P/2], y = [P/2, OUT_D - P/2])
        beamZ(0, OUT_H - T_ROOF, x, y);
}
/* 只取「后右角」那根腿, 用来快速做门/箱内物的干涉检查 */
module test_leg_near_post() { beamZ(0, OUT_H - T_ROOF, OUT_W - P/2, OUT_D - P/2); }
/* 只取前脸两根腿 + 门, 用于开门运动学 */
module test_front_legs() {
    for (x = [P/2, OUT_W - P/2]) beamZ(0, OUT_H - T_ROOF, x, P/2);
}
/* 单层围板, 用于逐层干涉检查 */
module test_side_panel(i, s) { side_panel(i, s); }
module test_back_panel(i)    { back_panel(i); }
module test_shelf(i)         { shelf(i); }
/* 型材截面: 单独挤 100 mm, 体积/100 = 真实截面积 (独立校核手算值) */
module test_profile_100() { beam(100); }
/* 探针: 与层板求交可判断「该处是否真的被挖空」 */
module test_probe(x0, y0, z0, dx, dy, dz) { translate([x0, y0, z0]) cube([dx, dy, dz]); }
module test_cat_hole_probe(i) {
    translate([HOLE_X - 60, HOLE_Y - 60, shelf_z0(i) - 1]) cube([120, 120, T_WOOD + 2]);
}
module test_post_hole_probe(i) {
    translate([POST_X - 40, POST_Y - 40, shelf_z0(i) - 1]) cube([80, 80, T_WOOD + 2]);
}
/* 负向对照用: 层板上一块【实心】区域的同尺寸探针 */
module test_solid_probe(i) {
    translate([300, 300, shelf_z0(i) - 1]) cube([120, 120, T_WOOD + 2]);
}

/* ============================= 装配 =============================== */
module assembly() {
    color(C_AL)  extrusions();
    if (SHOW_BRACKETS) color(C_BKT) brackets();
    color(C_WOOD) { shelves(); roof(); }
    panels();
    doors();
    if (SHOW_DETAILS) { color(C_BKT) { door_frame_hinges(); handles(); } flap(); }    if (SHOW_CONTENTS) contents();
}

assembly();

/* =========================== 下料清单 ============================= */
_l_leg  = OUT_H - T_ROOF;
_l_fb   = INT_W;
_l_lr   = INT_D;
_n      = N_LEV + 1;
echo("================ 3030 型材 ================");
echo(str("腿        x 4   : ", _l_leg, " mm"));
echo(str("前后圈梁  x ", 2*_n, " : ", _l_fb, " mm"));
echo(str("左右圈梁  x ", 2*_n, " : ", _l_lr, " mm"));
echo(str("合计        : ", (4*_l_leg + 2*_n*(_l_fb + _l_lr)), " mm"));
echo(str("三角角码  x ", 4*_n, " : ", BKT_L, "x", BKT_L, "x", BKT_T, " mm"));
echo("================ 板材 ====================");
echo(str("木层板    x ", N_LEV, " : ", OUT_W, " x ", OUT_D, " x ", T_WOOD, " mm"));
echo(str("木顶板    x 1  : ", OUT_W, " x ", OUT_D, " x ", T_ROOF, " mm"));
for (i = [0 : N_LEV-1])
    echo(str("木背板    x 1  : ", INT_W, " x ", wall_h(i), " x ", T_WOOD, " mm   (L", i, ")"));
echo(str("木侧板    x 2  : ", INT_D, " x ", wall_h(0), " x ", T_WOOD, " mm   (L0)"));
echo(str("木门      x 2  : ", leaf_w(), " x ", wall_h(0)-2*DOOR_GAP, " x ", T_WOOD, " mm   (L0)"));
for (i = [1 : N_LEV-1]) {
    echo(str("亚克力侧板 x 2 : ", INT_D, " x ", wall_h(i), " x ", T_ACR, " mm   (L", i, ")"));
    echo(str("亚克力门  x 2  : ", leaf_w(), " x ", wall_h(i)-2*DOOR_GAP, " x ", T_ACR, " mm   (L", i, ")"));
}
echo("==========================================");
echo(str("整机外廓: ", OUT_W, " x ", OUT_D, " x ", OUT_H, " mm"));
echo(str("各层净高: ", wall_h(0)-2*DOOR_GAP, " / ", wall_h(1)-2*DOOR_GAP,
         " / ", wall_h(2)-2*DOOR_GAP, " / ", wall_h(3)-2*DOOR_GAP, " mm"));
