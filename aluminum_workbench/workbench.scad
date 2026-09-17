/* =====================================================================
   3030 铝型材工作台 (Workbench) —— OpenSCAD
   ---------------------------------------------------------------------
   坐标系: 原点 = 前-左-地 角
     X = 宽度 (左 -> 右)      0 .. W = 1400
     Y = 进深 (前 -> 后)      0 .. D =  400
     Z = 高度 (地 -> 顶)      0 .. H = 2000

   X 方向分区:
     |<----- 600 ----->|<----- 500 ----->|<- 300 ->|
     0                600               1100      1400
     · 左区 : 下部 60 宽 x 70 高的收纳空腔(空着), 台面高 700
              -> 台面上放 A1 mini 封箱
     · 中区 : 台面高 600 (膝下空着)
     · 右区 : 台面高 600 + 底部 300 宽的抽屉柜
     主台面(600)后侧 : 方孔洞洞板 + 2 块 100mm 深的小层板

   构造约定:
     · 台面板【上表面】= H_LEFT / H_MAIN (即用户说的 70 / 60 cm)
       台面板直接坐在型材横框上, 所以横框高 = 台面高 - 30 - 18
     · 所有型材端面互不相交(件与件只在面/端面处相挨), 因此总长 x 截面
       面积 = 型材总体积, 自检脚本靠这一点校验有没有漏件/重件
     · 通高竖柱 6 根 (x=15/585/1385), 顶框 + 底框 + 各层横框把它们连成整体
     · A1 mini 封箱外形按 a1mini_enclosure.scad: 460 x 520 x 460
       ★ 注意: 520 进深 > 工作台 400 进深, 封箱会向前探出 120mm (见 SHOW_ENCLOSURE)

   用法:
     openscad workbench.scad                       # F5 预览
     openscad -o wb.stl workbench.scad             # 导出 STL
     openscad -D 'D=550' -o wb.stl workbench.scad  # 改尺寸
     # 自检用 (check.py 会自动调用):
     openscad -D 'PART="probe"' -D 'PROBE_PART="frame"' \
              -D 'PROBE_BOX=[30,30,31,540,340,600]' -o p.stl workbench.scad

   这是【理想尺寸】模型: 型材之间用 T 型螺母 / 内置角件 / 端面攻丝连接,
   实际装配按实机留 0.2~0.4mm 间隙。模型里没画连接件。
   ===================================================================== */

/* ============================== 参数 ============================== */

/* --- 总体 --- */
W = 1400;   // 总宽 (X)
D =  400;   // 总深 (Y)
H = 2000;   // 总高 (Z)
P =   30;   // 3030 型材

/* --- 台面 (台面板【上表面】高度) --- */
H_LEFT  = 700;   // 左台面
H_MAIN  = 600;   // 中/右台面
PANEL_T =  18;   // 台面板厚 (18mm 多层板)

/* --- X 分区: 竖柱中心线 --- */
X_DIV = 585;     // 左区 <-> 中区 的分隔柱
X_CAB = 1115;    // 抽屉柜 左柱 (柜体外沿 1100..1400 = 300 宽)

/* --- 型材横框高度 (由台面高度反推) --- */
Z_BOT  = 0;                      // 底框  梁 0..30
Z_LEFT = H_LEFT - P - PANEL_T;   // 652   梁 652..682, 台面板 682..700
Z_MAIN = H_MAIN - P - PANEL_T;   // 552   梁 552..582, 台面板 582..600
CAB_H  = Z_MAIN;                 // 抽屉柜竖柱顶 = 552
Z_TOP  = H - P;                  // 1970  顶框 1970..2000

/* --- 洞洞板 --- */
PEG_H      = 820;    // 板高 (从主台面 600 起)
PEG_T      =  10;    // 板厚
PEG_HOLE   =  10;    // 方孔边长
PEG_PITCH  =  38;    // 方孔中心距
PEG_MARGIN =  22;    // 板边到孔阵列的最小边距
Z_PEG      = H_MAIN + PEG_H;   // 1420 -> 板顶横梁 1420..1450
PEG_NX     = floor((W - P - (X_DIV + P/2) - 2*PEG_MARGIN - PEG_HOLE) / PEG_PITCH) + 1;
PEG_NZ     = floor((PEG_H - 2*PEG_MARGIN - PEG_HOLE) / PEG_PITCH) + 1;

/* --- 台面上方的 10cm 深小层板 --- */
SHOW_LEDGE = true;
LEDGE_D    = 100;
LEDGE_T    =  18;
LEDGE_ZS   = [950, 1250];   // 层板【上表面】高度

/* --- 右侧抽屉 --- */
N_DRAWER  = 2;
DRW_GAP   = 3;     // 面板缝
DRW_W     = 300;   // 抽屉面板宽 (顶到右端 = 柜体外沿宽)
CAB_T     = 18;    // 柜体板厚
CAB_SLIDE = 13;    // 每侧滑轨占位

/* --- 左区收纳空腔 右侧封板 (把 60cm 空间跟中区隔开) --- */
DIVIDER_PANEL = true;

/* --- 型材开槽开关 (只给自检做负向测试用, 正常别关) --- */
SLOT_ON = true;
/* --- 自检加速: 用实心方钢截面代替 T 型槽截面 ---
       SIMPLE=true 的模型是真实模型的【超集】(只是多了槽里那点料),
       所以 "探测盒里没料" 的结论在真模型上依然成立, 但渲染快 ~10 倍。
       ★ 体积校验不能用 SIMPLE ★                                        */
SIMPLE = false;

/* --- A1 mini 封箱包络 (检查干涉用) --- */
SHOW_ENCLOSURE = true;
ENC_W = 460;  ENC_D = 520;  ENC_H = 460;

/* --- 颜色 --- */
C_AL    = [0.78, 0.79, 0.82];
C_WOOD  = [0.72, 0.55, 0.34];
C_STEEL = [0.30, 0.31, 0.34];

$fn = 24;

/* ======================== 3030 T 型槽截面 ========================= */
/* 单条 T 型槽切口 (槽口朝 +X 面)
   槽口宽 8.2 / 内腔宽 13 / 槽深 9 / 唇厚 2.6                       */
module tslot30_2d() {
    polygon(points = [
        [15.0,  4.1], [12.4,  4.1], [12.4,  6.5], [ 6.0,  6.5],
        [ 6.0, -6.5], [12.4, -6.5], [12.4, -4.1], [15.0, -4.1]
    ]);
}

/* 3030 截面, 居中于原点: 30x30, 四角 R3, 中心 M6 底孔 */
module p3030_2d() {
    difference() {
        offset(r = 3) offset(delta = -3) square([P, P], center = true);
        if (SLOT_ON) for (a = [0, 90, 180, 270]) rotate(a) tslot30_2d();
        circle(d = 6.8, $fn = 16);
    }
}

/* 一段型材: 沿 +Z 挤出, 长度 len, 截面中心在原点 */
module beam_section() {
    if (SIMPLE) square([P, P], center = true);
    else        p3030_2d();
}
module beam(len) { linear_extrude(height = len, convexity = 10) beam_section(); }

/* ------------------------- 摆放助手 ------------------------------ */
module beamX(x0, x1, yc, zc) { translate([x0, yc, zc]) rotate([0, 90, 0])  beam(x1 - x0); }
module beamY(y0, y1, xc, zc) { translate([xc, y0, zc]) rotate([-90, 0, 0]) beam(y1 - y0); }
module beamZ(z0, z1, xc, yc) { translate([xc, yc, z0])                     beam(z1 - z0); }

/* ============================ 网格位置 ============================ */
X_POSTS = [P/2, X_DIV, W - P/2];   // 15 / 585 / 1385
Y_POSTS = [P/2, D - P/2];          // 15 / 385

/* ============================= 竖柱 ============================== */
module posts() {
    for (x = X_POSTS, y = Y_POSTS) beamZ(0, H, x, y);          // 6 根通高柱
    for (y = Y_POSTS)              beamZ(P, CAB_H, X_CAB, y);  // 抽屉柜左柱 (坐在底框上)
}

/* ======================= 一层水平矩形框 =========================== */
/* 梁占 z0 .. z0+P
   xA..xB  = 前后两根 X 梁的净跨 (端面顶到竖柱上)
   yL/yR   = 该侧是否再加一根 Y 梁 (若该侧是通高竖柱就不需要)       */
module hframe(z0, xA, xB, yL = true, yR = true) {
    beamX(xA, xB, P/2,     z0 + P/2);
    beamX(xA, xB, D - P/2, z0 + P/2);
    if (yL) beamY(P, D - P, xA - P/2, z0 + P/2);
    if (yR) beamY(P, D - P, xB + P/2, z0 + P/2);
}

module extrusions() {
    posts();

    hframe(Z_BOT,  P,           X_DIV - P/2, true,  false);   // 底框 左区
    hframe(Z_BOT,  X_DIV + P/2, W - P,       false, true );   // 底框 中+右区
    hframe(Z_LEFT, P,           X_DIV - P/2, true,  false);   // 左台面框
    hframe(Z_MAIN, X_DIV + P/2, W - P,       false, true );   // 主台面框
    hframe(Z_PEG,  X_DIV + P/2, W - P,       false, true );   // 洞洞板顶梁
    hframe(Z_TOP,  P,           X_DIV - P/2, true,  false);   // 顶框 左区
    hframe(Z_TOP,  X_DIV + P/2, W - P,       false, true );   // 顶框 中+右区
}

/* ============================ 台面板 ============================== */
/* 台面板坐在横框上, 上表面 = zTop; 在竖柱处挖缺口 */
module desk_panel(x0, x1, zTop) {
    difference() {
        translate([x0, 0, zTop - PANEL_T]) cube([x1 - x0, D, PANEL_T]);
        for (x = X_POSTS, y = Y_POSTS)
            translate([x - P/2, y - P/2, zTop - PANEL_T - 1])
                cube([P, P, PANEL_T + 2]);
    }
}

module desks() {
    desk_panel(0,             X_DIV - P/2, H_LEFT);   // 左台面: x 0..570
    desk_panel(X_DIV + P/2,   W,           H_MAIN);   // 中/右台面: x 600..1400
}

/* ======================= 方孔洞洞板 (背板) ======================== */
/* 用「横条 ∪ 竖条」拼出带方孔的板 —— 比 400 次 difference 快几十倍
   (OpenSCAD 2021.01 只有 CGAL 后端)                                */
module pegboard() {
    x0 = X_DIV + P/2;  x1 = W - P;              // 600 .. 1370
    z0 = H_MAIN;       z1 = H_MAIN + PEG_H;     // 600 .. 1420
    y0 = D - P - PEG_T;                         // 360 (前表面)

    bx = x1 - x0;  bz = z1 - z0;
    nx = PEG_NX;   nz = PEG_NZ;
    ox = x0 + (bx - ((nx-1)*PEG_PITCH + PEG_HOLE)) / 2;   // 第一列孔左边缘
    oz = z0 + (bz - ((nz-1)*PEG_PITCH + PEG_HOLE)) / 2;

    color(C_WOOD * 0.85) union() {
        // 竖条 (不含孔列)
        translate([x0, y0, z0]) cube([ox - x0, PEG_T, bz]);
        for (k = [0 : nx-2])
            translate([ox + k*PEG_PITCH + PEG_HOLE, y0, z0])
                cube([PEG_PITCH - PEG_HOLE, PEG_T, bz]);
        translate([ox + (nx-1)*PEG_PITCH + PEG_HOLE, y0, z0])
            cube([x1 - (ox + (nx-1)*PEG_PITCH + PEG_HOLE), PEG_T, bz]);
        // 横条 (不含孔行)
        translate([x0, y0, z0]) cube([bx, PEG_T, oz - z0]);
        for (k = [0 : nz-2])
            translate([x0, y0, oz + k*PEG_PITCH + PEG_HOLE])
                cube([bx, PEG_T, PEG_PITCH - PEG_HOLE]);
        translate([x0, y0, oz + (nz-1)*PEG_PITCH + PEG_HOLE])
            cube([bx, PEG_T, z1 - (oz + (nz-1)*PEG_PITCH + PEG_HOLE)]);
    }
}

/* ===================== 台面上方 10cm 深小层板 ===================== */
module ledge_brk(x, zb) {          // zb = 层板下表面
    yb = D - P - PEG_T;            // 洞洞板前表面 360
    color(C_STEEL) {
        translate([x - 15, yb - 4,  zb - 46]) cube([30, 4, 42]);   // 竖片贴洞洞板
        translate([x - 15, yb - 96, zb - 4])  cube([30, 96, 4]);   // 横片托层板
    }
}

module ledges() {
    if (SHOW_LEDGE) {
        for (zt = LEDGE_ZS) {
            color(C_WOOD)
                translate([X_DIV + P/2, D - P - PEG_T - LEDGE_D, zt - LEDGE_T])
                    cube([W - P - (X_DIV + P/2), LEDGE_D, LEDGE_T]);
            for (x = [X_DIV + P/2 + 20, (X_DIV + P/2 + W - P)/2, W - P - 20])
                ledge_brk(x, zt - LEDGE_T);
        }
    }
}

/* ========================== 抽屉柜体 ============================== */
module cabinet() {
    xa = X_CAB + P/2;      // 1130
    xb = W - P;            // 1370
    color(C_WOOD * 0.9) {
        // 背板
        translate([xa, D - P - CAB_T, P]) cube([xb - xa, CAB_T, CAB_H - P]);
        // 底板
        translate([xa, P, P]) cube([xb - xa, D - 2*P - CAB_T, CAB_T]);
    }
}

/* ============================ 抽屉 ================================ */
module drawers() {
    use_h = CAB_H - P;                                  // 522 (开口净高)
    fh    = (use_h - (N_DRAWER + 1) * DRW_GAP) / N_DRAWER;
    xf    = W - DRW_W;                                  // 1100

    for (i = [0 : N_DRAWER-1]) {
        z0 = P + DRW_GAP + i * (fh + DRW_GAP);
        // 面板
        color(C_WOOD)
            translate([xf, 0, z0]) cube([DRW_W, PANEL_T, fh]);
        // 拉手 (示意): 竖杆 Ø12 + 两个 Ø8 支柱沿 +Y 撑到面板
        color(C_STEEL) {
            translate([W - DRW_W/2, -28, z0 + fh/2]) rotate([0, 90, 0])
                cylinder(d = 12, h = 200, center = true);
            for (dx = [-80, 80])
                translate([W - DRW_W/2 + dx, -28, z0 + fh/2]) rotate([-90, 0, 0])
                    cylinder(d = 8, h = 28);
        }
    }
}

/* ======================= 底部收纳腔底板 =========================== */
module bottom_panel() {
    color(C_WOOD)
        translate([P, P, P - PANEL_T]) cube([X_DIV - P - P/2, D - 2*P, PANEL_T]);
}

/* =================== 左区收纳空腔 右侧封板 ======================== */
/* 夹在两根分隔柱之间, 把 60cm 收纳空间跟中区隔开 (也顺带加强整体刚度) */
module divider_panel() {
    if (DIVIDER_PANEL)
        color(C_WOOD)
            translate([X_DIV - CAB_T/2, P, P])
                cube([CAB_T, D - 2*P, Z_LEFT - P]);
}

/* ===================== A1 mini 封箱包络 (检查) ==================== */
module enclosure_env() {
    color([0.90, 0.55, 0.25, 0.28])
        translate([(X_DIV - P/2 - ENC_W)/2, D - ENC_D, H_LEFT])
            cube([ENC_W, ENC_D, ENC_H]);
}

/* ============================ 装配 ================================ */
module bench() {
    color(C_AL) extrusions();
    desks();
    bottom_panel();
    divider_panel();
    pegboard();
    ledges();
    cabinet();
    drawers();
}

module assembly() {
    bench();
    if (SHOW_ENCLOSURE) enclosure_env();
}

/* ==================== 分件输出 (供 check.py 探测) ================= */
/* PART     : all / bench / frame / decks / pegboard / cabinet /
            drawers / ledges / structure / enclosure / beam / probe
   PROBE_PART + PROBE_BOX : 与立方体求交, 用来做"空/不空"的判别测试 */
PART       = "all";
PROBE_PART = "frame";
PROBE_BOX  = [0, 0, 0, 1, 1, 1];

module part(name) {
    if      (name == "all")       assembly();
    else if (name == "bench")     bench();
    else if (name == "frame")     color(C_AL) extrusions();
    else if (name == "decks")     desks();
    else if (name == "pegboard")  pegboard();
    else if (name == "cabinet")   cabinet();
    else if (name == "drawers")   drawers();
    else if (name == "ledges")    ledges();
    else if (name == "divider")   divider_panel();
    else if (name == "structure") { color(C_AL) extrusions(); desks();
                                    bottom_panel(); divider_panel(); cabinet(); }
    else if (name == "enclosure") enclosure_env();
    else if (name == "beam")      color(C_AL) beam(1000);
}

module probe_part() {
    intersection() {
        part(PROBE_PART);
        translate([PROBE_BOX[0], PROBE_BOX[1], PROBE_BOX[2]])
            cube([PROBE_BOX[3], PROBE_BOX[4], PROBE_BOX[5]]);
    }
}

if (PART == "probe") probe_part(); else part(PART);

/* ======================== 切割清单 / 校核 ========================= */
/* 截面实心面积 (手工推导, 与上面的 2D 轮廓一致):
     30x30 正方形                      900.00
     - 四角 R3 圆角            (4-π)R²    7.73
     - 4 条 T 槽  4x(2.6x8.2 + 6.4x13) 418.08
     + 相邻槽转角重叠 4x0.5x0.5           1.00
     - 中心 Ø6.8 孔           π x 3.4²   36.32
     ----------------------------------------
     截面面积                          438.88 mm²  (48.8% 实体)          */
A_BEAM = 900 - (4 - 3.14159265)*3*3
             - (4*(2.6*8.2 + 6.4*13.0) - 4*0.5*0.5)
             - 3.14159265*3.4*3.4;

/* 横框表 (与 extrusions() 里一一对应):
     [z0, xA, xB, 左侧加 Y 梁?, 右侧加 Y 梁?]                        */
_hf = [
    [Z_BOT,  P,           X_DIV - P/2, 1, 0],
    [Z_BOT,  X_DIV + P/2, W - P,       0, 1],
    [Z_LEFT, P,           X_DIV - P/2, 1, 0],
    [Z_MAIN, X_DIV + P/2, W - P,       0, 1],
    [Z_PEG,  X_DIV + P/2, W - P,       0, 1],
    [Z_TOP,  P,           X_DIV - P/2, 1, 0],
    [Z_TOP,  X_DIV + P/2, W - P,       0, 1]
];

_len_x = X_DIV - P/2 - P;            // 左区前后梁 净跨     = 540
_len_y = D - 2*P;                    // 左右横梁 净跨       = 340
_len_w = (W - P) - (X_DIV + P/2);    // 中/右区前后梁 净跨  = 770

_n_x_rail = 2 * len(_hf);                        // 14 根前后梁
_n_y_rail = 3 + 4;                               //  7 根左右横梁
_len_legs = 6 * H;                               //  6 根通高竖柱
_len_cab  = 2 * (CAB_H - P);                     //  2 根柜体竖柱
_len_hf   = 6*_len_x + 8*_len_w + _n_y_rail*_len_y;

TOTAL_BEAM_LEN  = _len_legs + _len_cab + _len_hf;
TOTAL_FRAME_VOL = TOTAL_BEAM_LEN * A_BEAM;

echo("============== 3030 切割清单 ==============");
echo(str("竖柱 通高      x 6 : ", H, " mm"));
echo(str("抽屉柜竖柱     x 2 : ", CAB_H - P, " mm"));
echo(str("左区 前后梁    x 6 : ", _len_x, " mm"));
echo(str("中/右 前后梁   x 8 : ", _len_w, " mm"));
echo(str("左右 横梁      x ", _n_y_rail, " : ", _len_y, " mm"));
echo(str("型材总长           : ", TOTAL_BEAM_LEN, " mm  (", TOTAL_BEAM_LEN/1000, " m)"));
echo(str("截面面积           : ", A_BEAM, " mm^2"));
echo(str("CHECK|A_BEAM|", A_BEAM));
echo(str("CHECK|TOTAL_BEAM_LEN|", TOTAL_BEAM_LEN));
echo(str("CHECK|TOTAL_FRAME_VOL|", TOTAL_FRAME_VOL));
echo(str("CHECK|SIZE|W|", W, "|D|", D, "|H|", H, "|P|", P));
echo(str("CHECK|ZLEV|Z_LEFT|", Z_LEFT, "|Z_MAIN|", Z_MAIN, "|CAB_H|", CAB_H,
         "|Z_TOP|", Z_TOP));
echo(str("CHECK|XZON|X_DIV|", X_DIV, "|X_CAB|", X_CAB, "|PANEL_T|", PANEL_T));
echo(str("CHECK|PEG|", PEG_NX, "|", PEG_NZ, "|", PEG_T, "|", PEG_H, "|",
         W - P - (X_DIV + P/2), "|", H_MAIN));
echo(str("CHECK|DRW|", N_DRAWER, "|", DRW_W, "|", DRW_GAP));
echo(str("CHECK|LEDGE|", len(LEDGE_ZS), "|", LEDGE_D, "|", LEDGE_T));
echo(str("CHECK|CAB|", CAB_T, "|", D - P - CAB_T, "|", D - 2*P - CAB_T));
echo(str("CHECK|ENC|", ENC_W, "|", ENC_D, "|", ENC_H));
echo("===========================================");
echo(str("净空: 左区收纳 ", X_DIV - P/2 - P, " x ", D - 2*P, " x ",
         Z_LEFT + P - P, " mm (宽x深x高, 中间区域净高)"));
echo(str("      贴着前后横梁处净高 ", Z_LEFT - P - P, " mm; 地台面离地 ", P, " mm"));
echo(str("净空: 抽屉口   ", (W-P) - (X_CAB+P/2), " x ", D - 2*P - CAB_T, " x ", CAB_H - P, " mm"));
echo(str("净空: 中区膝下 ", (W - DRW_W) - (X_DIV + P/2), " mm 宽 x ", CAB_H - P, " mm 高"));
echo(str("台面: 左 ", H_LEFT, " / 中右 ", H_MAIN, " / 总高 ", H, " mm"));
echo(str("A1mini 封箱 ", ENC_W, "x", ENC_D, "x", ENC_H,
         " -> 前面探出 ", max(0, ENC_D - D), " mm"));
