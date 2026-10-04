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
              = 3030 外框 +【2020 铝型材抽屉框 (三通连接件)】+ 三节滑轨, 3 层抽屉
     主台面(600)后侧 : 方孔洞洞板 + 2 块 100mm 深的小层板

   构造约定:
     · 台面板【上表面】= H_LEFT / H_MAIN (即用户说的 70 / 60 cm)
       台面板直接坐在型材横框上, 所以横框高 = 台面高 - 30 - 18
     · 所有型材端面互不相交(件与件只在面/端面处相挨), 因此总长 x 截面
       面积 = 型材总体积, 自检脚本靠这一点校验有没有漏件/重件
     · 竖柱 6 根 (x=15/585/1385) 通高, 下端面 z = CASTER_H (坐在福马轮顶面),
       所以立柱长度 = H - CASTER_H (总高仍 2000)
     · 底框 中/右区(600..1370)【前端】那根 X 向横梁取消 —— 抽屉面不挡,
       膝下也不挡脚 (左区前端那根保留, 它托着收纳腔地台板)
     · 抽屉: 每层左右各一根 2020【滑轨梁】(沿 Y, 两端顶在前后 3030 立柱内侧面上),
       三节滑轨拧在梁的内侧面; 抽屉框 = 2020 4 壁 + 4 个三通角块 + 9mm 底板,
       挂在滑轨上 (3030 立柱只在前后各 30mm, 自己挂不住 320 长滑轨)
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

/* --- 福马轮 (调节脚轮): 撑着 6 根立柱, 型材按 CASTER_H 截短 --- */
CASTER_H  = 71;    // 支撑高度 (地面 -> 底板顶面) = 立柱下端面高度
CASTER_PL = 55;    // 底板边长 55 x 55
CASTER_BS = 42;    // 安装孔距 42 (正方形)
CASTER_BD = 40;    // 轮径
CASTER_W  = 20;    // 轮宽
CASTER_T  =  6;    // 底板厚

/* --- 台面 (台面板【上表面】高度) --- */
H_LEFT  = 700;   // 左台面
H_MAIN  = 600;   // 中/右台面
PANEL_T =  18;   // 台面板厚 (18mm 多层板)

/* --- X 分区: 竖柱中心线 --- */
X_DIV = 585;     // 左区 <-> 中区 的分隔柱
X_CAB = 1115;    // 抽屉柜 左柱 (柜体外沿 1100..1400 = 300 宽)

/* --- 型材横框高度 (由台面高度反推) --- */
Z_BOT  = CASTER_H;               // 底框  梁 71..101 (立柱坐福马轮上, 型材截短 71)
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

/* --- 右侧抽屉单元: 3030 外框 + 2020 抽屉框 + 三节滑轨 --- */
N_DRAWER  = 3;     // 三层抽屉
DRW_GAP   = 3;     // 面板缝
DRW_FCLR  = 1;     // 面板与柜口(3030 柱内侧面)的单侧间隙
CAB_T     = 18;    // 柜体板厚
E20       = 20;    // 2020 型材
SLIDE_T   = 12.7;  // 单侧滑轨厚 (三节珠轨)
SLIDE_H   = 45;    // 滑轨高
SLIDE_L   = 320;   // 滑轨长
SLIDE_DZ  = 25;    // 滑轨底面相对抽屉框底面的抬高
SLIDE_GAP = 10;    // 滑轨端到 3030 立柱内侧面的距离
SLIDE_CLR = 1.5;   // 抽屉框外侧面与滑轨的单侧间隙
DRW_BD    = 330;   // 抽屉框进深 (Y)
DRW_BH    = 120;   // 抽屉框高
BOT_T     =  9;    // 抽屉底板厚
COR20     = 20;    // 三通连接件(内角块)边长
HANDLE_Y  = 28;    // 拉手杆中心到面板前面的距离
HANDLE_D  = 12;    // 拉手杆直径

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

/* --- 自检加速: 关掉 400 孔的洞洞板 (它对整台包围盒没贡献), 正常别关 --- */
PEGBOARD_ON = true;

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

/* ======================== 2020 T 型槽截面 ======================== */
/* 抽屉框用 2020. 单条槽 (槽口朝 +X 面):
   槽口宽 6.0 / 唇厚 1.8 (槽深 6.0) / 内腔宽 10.2 / 中心 Ø4.2 通孔
   ★ 注意: 内腔半宽 5.1 > 腔底距中心 4.0, 所以相邻两条垂直槽在四个角上
     【相交】, 每处重叠 1.1 x 1.1 mm; 算截面面积时要补回来 (4 处)      */
module tslot20_2d() {
    polygon(points = [
        [10.0,  3.0], [ 8.2,  3.0], [ 8.2,  5.1], [ 4.0,  5.1],
        [ 4.0, -5.1], [ 8.2, -5.1], [ 8.2, -3.0], [10.0, -3.0]
    ]);
}

/* 2020 截面, 居中于原点: 20x20, 四角 R2, 中心 Ø4.2 通孔 */
module p2020_2d() {
    difference() {
        offset(r = 2) offset(delta = -2) square([E20, E20], center = true);
        if (SLOT_ON) for (a = [0, 90, 180, 270]) rotate(a) tslot20_2d();
        circle(d = 4.2, $fn = 16);
    }
}
module beam20_section() {
    if (SIMPLE) square([E20, E20], center = true);
    else        p2020_2d();
}
module beam20(len) { linear_extrude(height = len, convexity = 10) beam20_section(); }

/* --------------------- 2020 摆放助手 ----------------------------- */
module b20X(x0, x1, yc, zc) { translate([x0, yc, zc]) rotate([0, 90, 0])  beam20(x1 - x0); }
module b20Y(y0, y1, xc, zc) { translate([xc, y0, zc]) rotate([-90, 0, 0]) beam20(y1 - y0); }

/* ============================ 网格位置 ============================ */
X_POSTS = [P/2, X_DIV, W - P/2];   // 15 / 585 / 1385
Y_POSTS = [P/2, D - P/2];          // 15 / 385

/* ============================= 竖柱 ============================== */
/* 立柱下端面 = CASTER_H (福马轮顶面), 所以长度 = H - CASTER_H */
module posts() {
    for (x = X_POSTS, y = Y_POSTS) beamZ(Z_BOT, H, x, y);            // 6 根通高柱(已截短)
    for (y = Y_POSTS)              beamZ(Z_BOT + P, CAB_H, X_CAB, y); // 抽屉柜左柱 (坐在底框上)
}

/* ======================= 一层水平矩形框 =========================== */
/* 梁占 z0 .. z0+P
   xA..xB  = 前后两根 X 梁的净跨 (端面顶到竖柱上)
   yL/yR   = 该侧是否再加一根 Y 梁 (若该侧是通高竖柱就不需要)
   xF/xR   = 前/后那根 X 梁要不要 (中/右区底框前端取消)               */
module hframe(z0, xA, xB, yL = true, yR = true, xF = true, xR = true) {
    if (xF) beamX(xA, xB, P/2,     z0 + P/2);
    if (xR) beamX(xA, xB, D - P/2, z0 + P/2);
    if (yL) beamY(P, D - P, xA - P/2, z0 + P/2);
    if (yR) beamY(P, D - P, xB + P/2, z0 + P/2);
}

module extrusions() {
    posts();

    hframe(Z_BOT,  P,           X_DIV - P/2, true,  false);              // 底框 左区
    hframe(Z_BOT,  X_DIV + P/2, W - P,       false, true, false, true);  // 底框 中+右区(★前梁取消)
    hframe(Z_LEFT, P,           X_DIV - P/2, true,  false);              // 左台面框
    hframe(Z_MAIN, X_DIV + P/2, W - P,       false, true);               // 主台面框
    hframe(Z_PEG,  X_DIV + P/2, W - P,       false, true);               // 洞洞板顶梁
    hframe(Z_TOP,  P,           X_DIV - P/2, true,  false);              // 顶框 左区
    hframe(Z_TOP,  X_DIV + P/2, W - P,       false, true);               // 顶框 中+右区
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
/* 只留背板 + 地台板 (承重靠 3030 外框, 抽屉靠滑轨) */
module cabinet() {
    xa = X_CAB + P/2;      // 1130
    xb = W - P;            // 1370
    z0 = Z_BOT + P;        // 101
    color(C_WOOD * 0.9) {
        // 背板
        translate([xa, D - P - CAB_T, z0]) cube([xb - xa, CAB_T, CAB_H - z0]);
        // 地台板
        translate([xa, P, z0]) cube([xb - xa, D - 2*P - CAB_T, CAB_T]);
    }
}

/* ==================== 右侧抽屉单元 (2020 + 滑轨) =================== */
/* 柜口      : x 1130..1370 (240 宽), 地 101, 顶 552 —— 由 3030 外框围成
   滑轨梁    : 每层左右各一根 2020 沿 Y (长 D-2P=340, 端面顶在前后 3030 柱内侧面上)
   滑轨      : 三节珠轨, 拧在滑轨梁的【内侧面】上, 每层 2 条
   抽屉框    : 2020 型材 4 壁 + 4 个三通连接件(内角块) + 9mm 底板, 挂滑轨上
   面板/拉手 : 18mm 面板嵌在柜口里(单边留 DRW_FCLR), 前面与 3030 齐平
   三层高度  : 柜口净高 451 减 4 条缝 = 3 x 140.33                       */
CAB_X0 = X_CAB + P/2;                                  // 1130  柜口左壁
CAB_X1 = W - P;                                        // 1370  柜口右壁
CAB_Z0 = Z_BOT + P;                                    // 101   柜口地面
DRW_W  = (CAB_X1 - CAB_X0) - 2*DRW_FCLR;               // 238   面板宽
/* 抽屉框外宽 = 柜口 - 2x(滑轨梁 20 + 滑轨 12.7 + 缝 1.5) */
DRW_BW = (CAB_X1 - CAB_X0) - 2*(E20 + SLIDE_T + SLIDE_CLR);      // 171.6
DRW_Y0 = PANEL_T;                                      // 18    抽屉框前端面
DRW_Y1 = DRW_Y0 + DRW_BD;                              // 348   抽屉框后端面
DRW_L0 = CAB_Z0 + CAB_T;                               // 119   第 1 层面板下沿
DRW_FH = (CAB_H - DRW_L0 - (N_DRAWER + 1) * DRW_GAP) / N_DRAWER;   // 140.33
DRW_DZ = (DRW_FH - DRW_BH) / 2;                        // 10.17 框比面板抬升
SLIDE_Y0 = P + SLIDE_GAP;                              // 40    滑轨前端

function drw_zf(i) = DRW_L0 + DRW_GAP + i * (DRW_FH + DRW_GAP);   // 面板下沿
function drw_zb(i) = drw_zf(i) + DRW_DZ;                          // 框下沿
function drw_zc(i) = drw_zb(i) + SLIDE_DZ + SLIDE_H/2;            // 滑轨/滑轨梁中心

/* 单个抽屉的 2020 框 (4 壁, 只含型材) */
module drawer_frame20(i) {
    zb = drw_zb(i);
    x0 = CAB_X0 + E20 + SLIDE_T + SLIDE_CLR;   // 1164.2 左壁外表面
    x1 = x0 + E20;                             // 1184.2 左壁内表面
    x2 = x0 + DRW_BW;                          // 1335.8 右壁外表面
    x3 = x2 - E20;                             // 1315.8 右壁内表面
    zc = zb + DRW_BH/2;
    color(C_AL) {
        b20Y(DRW_Y0, DRW_Y1, (x0 + x1)/2, zc);        // 左壁
        b20Y(DRW_Y0, DRW_Y1, (x2 + x3)/2, zc);        // 右壁
        b20X(x1, x3, DRW_Y0 + E20/2, zc);             // 前壁
        b20X(x1, x3, DRW_Y1 - E20/2, zc);             // 后壁
    }
}

/* 每层的 2 根 2020 滑轨梁 (沿 Y, 端面顶在前后 3030 立柱内侧面上) */
module slide_rails20(i) {
    zc = drw_zc(i);
    color(C_AL) for (x = [CAB_X0 + E20/2, CAB_X1 - E20/2])
        b20Y(P, D - P, x, zc);
}

module drw20() {
    for (i = [0 : N_DRAWER-1]) { drawer_frame20(i); slide_rails20(i); }
}

module drawer(i) {
    zb = drw_zb(i);
    zf = drw_zf(i);
    x1 = CAB_X0 + E20 + SLIDE_T + SLIDE_CLR + E20;  // 1184.2 左壁内侧
    x3 = CAB_X0 + E20 + SLIDE_T + SLIDE_CLR + DRW_BW - E20;   // 1315.8 右壁内侧
    xc = CAB_X0 + (CAB_X1 - CAB_X0)/2;              // 1250

    drawer_frame20(i);

    // 4 个三通连接件 (内角块): 同时连前/后壁 + 侧壁 + 底板 (三通)
    color(C_STEEL)
        for (cx = [x1, x3 - COR20], cy = [DRW_Y0 + E20, DRW_Y1 - E20 - COR20])
            translate([cx, cy, zb]) cube([COR20, COR20, COR20]);

    // 9mm 底板 (落在 4 个角块上)
    color(C_WOOD * 0.8)
        translate([x1 + 1, DRW_Y0 + E20 + 1, zb + COR20])
            cube([x3 - x1 - 2, DRW_BD - 2*E20 - 2, BOT_T]);

    // 18mm 面板 (嵌在柜口里, 前面与 3030 前表面齐平)
    color(C_WOOD)
        translate([CAB_X0 + DRW_FCLR, 0, zf]) cube([DRW_W, PANEL_T, DRW_FH]);

    // 拉手 (示意): 横杆 Ø12 + 两个 Ø8 支柱沿 +Y 撑到面板
    color(C_STEEL) {
        translate([xc, -HANDLE_Y, zf + DRW_FH/2]) rotate([0, 90, 0])
            cylinder(d = HANDLE_D, h = 200, center = true);
        for (dx = [-80, 80])
            translate([xc + dx, -HANDLE_Y, zf + DRW_FH/2]) rotate([-90, 0, 0])
                cylinder(d = 8, h = HANDLE_Y);
    }
}
module drawers() { for (i = [0 : N_DRAWER-1]) drawer(i); }

/* ----------------------------- 滑轨 ------------------------------- */
/* 三节珠轨, 拧在每层那两根 2020 滑轨梁的【内侧面】上 */
module slide_one(i, x0) {
    zc = drw_zc(i);
    color(C_STEEL)
        translate([x0, SLIDE_Y0, zc - SLIDE_H/2]) cube([SLIDE_T, SLIDE_L, SLIDE_H]);
}
module slides() {
    for (i = [0 : N_DRAWER-1]) {
        slide_one(i, CAB_X0 + E20);
        slide_one(i, CAB_X1 - E20 - SLIDE_T);
    }
}

/* ============================= 福马轮 ============================= */
/* 底板 55x55 比 30x30 立柱端面大, 所以底板【外沿与工作台外沿齐平】:
   立柱整个 30x30 端面都踩在底板上 (真要装配需一块 55->30 转接板) */
function cax(x) = (x < P)     ? CASTER_PL/2     : ((x > W - P) ? W - CASTER_PL/2 : x);
function cay(y) = (y < P)     ? CASTER_PL/2     : ((y > D - P) ? D - CASTER_PL/2 : y);

module caster(x, y) {
    cx = cax(x);   cy = cay(y);
    p0 = CASTER_H - CASTER_T;      // 底板底面 65
    color(C_STEEL) difference() {
        translate([cx - CASTER_PL/2, cy - CASTER_PL/2, p0])
            cube([CASTER_PL, CASTER_PL, CASTER_T]);
        for (dx = [-CASTER_BS/2, CASTER_BS/2], dy = [-CASTER_BS/2, CASTER_BS/2])
            translate([cx + dx, cy + dy, p0 - 1]) cylinder(d = 9, h = CASTER_T + 2);
    }
    color(C_STEEL) {
        translate([cx, cy, p0 - 6]) cylinder(d = 45, h = 6);          // 承重转盘
        for (dy = [-12.5, 12.5])                                       // 叉架
            translate([cx - 27, cy + dy - 2.5, 20]) cube([40, 5, p0 - 26]);
        translate([cx - 7, cy, 26]) rotate([90, 0, 0])                 // 轮
            cylinder(d = CASTER_BD, h = CASTER_W, center = true);
        translate([cx + 12, cy, 7]) cylinder(d = 12, h = p0 - 7);      // 调节脚杆
        translate([cx + 12, cy, 0]) cylinder(d = 30, h = 7);           // 调节底盘
    }
}
module casters() { for (x = X_POSTS, y = Y_POSTS) caster(x, y); }

/* ======================= 底部收纳腔底板 =========================== */
module bottom_panel() {
    color(C_WOOD)
        translate([P, P, Z_BOT + P - PANEL_T]) cube([X_DIV - P - P/2, D - 2*P, PANEL_T]);
}

/* =================== 左区收纳空腔 右侧封板 ======================== */
/* 夹在两根分隔柱之间, 把 60cm 收纳空间跟中区隔开 (也顺带加强整体刚度) */
module divider_panel() {
    if (DIVIDER_PANEL)
        color(C_WOOD)
            translate([X_DIV - CAB_T/2, P, Z_BOT + P])
                cube([CAB_T, D - 2*P, Z_LEFT - (Z_BOT + P)]);
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
    if (PEGBOARD_ON) pegboard();
    ledges();
    cabinet();
    casters();
    slides();
    drawers();
}

module assembly() {
    bench();
    if (SHOW_ENCLOSURE) enclosure_env();
}

/* ==================== 分件输出 (供 check.py 探测) ================= */
/* PART     : all / bench / frame / decks / pegboard / cabinet /
            drawers / drw20 / slides / casters / ledges / divider /
            structure / enclosure / beam / beam20 / probe
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
    else if (name == "drw20")     drw20();
    else if (name == "slides")    slides();
    else if (name == "casters")   casters();
    else if (name == "ledges")    ledges();
    else if (name == "divider")   divider_panel();
    else if (name == "structure") { color(C_AL) extrusions(); desks();
                                    bottom_panel(); divider_panel(); cabinet(); }
    else if (name == "enclosure") enclosure_env();
    else if (name == "beam")      color(C_AL) beam(1000);
    else if (name == "beam20")    color(C_AL) beam20(1000);
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
     [z0, xA, xB, 左侧加 Y 梁?, 右侧加 Y 梁?, 前 X 梁?, 后 X 梁?]    */
_hf = [
    [Z_BOT,  P,           X_DIV - P/2, 1, 0, 1, 1],
    [Z_BOT,  X_DIV + P/2, W - P,       0, 1, 0, 1],   // ★ 底框前端 X 梁取消
    [Z_LEFT, P,           X_DIV - P/2, 1, 0, 1, 1],
    [Z_MAIN, X_DIV + P/2, W - P,       0, 1, 1, 1],
    [Z_PEG,  X_DIV + P/2, W - P,       0, 1, 1, 1],
    [Z_TOP,  P,           X_DIV - P/2, 1, 0, 1, 1],
    [Z_TOP,  X_DIV + P/2, W - P,       0, 1, 1, 1]
];

_len_x = X_DIV - P/2 - P;            // 左区前后梁 净跨     = 540
_len_y = D - 2*P;                    // 左右横梁 净跨       = 340
_len_w = (W - P) - (X_DIV + P/2);    // 中/右区前后梁 净跨  = 770

_n_x_l    = len([for (r = _hf) if (r[1] ==  P && r[5] == 1) r])
          + len([for (r = _hf) if (r[1] ==  P && r[6] == 1) r]);   // 6 根 左区前后梁
_n_x_r    = len([for (r = _hf) if (r[1] != P && r[5] == 1) r])
          + len([for (r = _hf) if (r[1] != P && r[6] == 1) r]);   // 7 根 中/右前后梁
_n_y_rail = len([for (r = _hf) if (r[3] == 1) r])
          + len([for (r = _hf) if (r[4] == 1) r]);                // 7 根 左右横梁
_len_legs = 6 * (H - Z_BOT);               //  6 根通高竖柱 (截短 CASTER_H)
_n_cab    = 2 * (CAB_H - P - Z_BOT);       //  2 根柜体竖柱 (截短 CASTER_H)
_len_hf    = _n_x_l*_len_x + _n_x_r*_len_w + _n_y_rail*_len_y;

TOTAL_BEAM_LEN  = _len_legs + _n_cab + _len_hf;
TOTAL_FRAME_VOL = TOTAL_BEAM_LEN * A_BEAM;

/* ---- 2020 抽屉框料单 ---- */
/* 2020 截面实心面积:
     20x20 正方形                      400.00
     - 四角 R2 圆角            (4-π)2²    3.43
     - 4 条 T 槽  4x(1.8x6.0 + 4.2x10.2) 214.56
     + 相邻槽转角重叠 4x1.1x1.1           4.84
     - 中心 Ø4.2 孔           π x 2.1²  13.85
     -----------------------------------------
     截面面积                          172.99 mm²  (43.2% 实体)          */
A20 = 400 - (4 - 3.14159265)*2*2
          - (4*(1.8*6.0 + 4.2*10.2) - 4*1.1*1.1)
          - 3.14159265*2.1*2.1;

_len20_side = DRW_BD;                  // 330   抽屉侧壁 x2 (每层)
_len20_fb   = DRW_BW - 2*E20;          // 131.6 抽屉前/后壁 x2 (每层)
_len20_rail = D - 2*P;                 // 340   2020 滑轨梁 x2 (每层)
L20_FRAMES  = N_DRAWER * 2 * (_len20_side + _len20_fb);
L20_RAILS   = N_DRAWER * 2 * _len20_rail;
L20_TOTAL   = L20_FRAMES + L20_RAILS;
HANDLE_OUT  = HANDLE_Y + HANDLE_D/2;   // 拉手突出台面外沿的距离 34

echo("============== 3030 切割清单 ==============");
echo(str("竖柱 通高(截短) x 6 : ", H - Z_BOT, " mm  (总高 ", H, " - 福马轮 ", CASTER_H, ")"));
echo(str("抽屉柜竖柱     x 2 : ", CAB_H - P - Z_BOT, " mm"));
echo(str("左区 前后梁    x ", _n_x_l, " : ", _len_x, " mm"));
echo(str("中/右 前后梁   x ", _n_x_r, " : ", _len_w, " mm  (底框前端 X 梁已取消)"));
echo(str("左右 横梁      x ", _n_y_rail, " : ", _len_y, " mm"));
echo(str("型材总长           : ", TOTAL_BEAM_LEN, " mm  (", TOTAL_BEAM_LEN/1000, " m)"));
echo(str("截面面积           : ", A_BEAM, " mm^2"));
echo("============== 2020 抽屉框料单 ============");
echo(str("2020 抽屉侧壁  x 6 : ", _len20_side, " mm"));
echo(str("2020 抽屉前/后 x 6 : ", _len20_fb, " mm"));
echo(str("2020 滑轨梁    x 6 : ", _len20_rail, " mm  (端面顶前后 3030 立柱)"));
echo(str("2020 三通角块 x 12 : ", COR20, " mm 立方 (三通连接件)"));
echo(str("2020 总长          : ", L20_TOTAL, " mm  (框 ", L20_FRAMES,
         " + 梁 ", L20_RAILS, ")"));
echo(str("2020 截面面积      : ", A20, " mm^2"));
echo(str("滑轨(三节)     x 6 : ", SLIDE_L, " mm, 单侧厚 ", SLIDE_T, " x 高 ", SLIDE_H));
echo(str("福马轮         x 6 : 高 ", CASTER_H, " 底板 ", CASTER_PL, "x", CASTER_PL,
         " 孔距 ", CASTER_BS, " 轮 Ø", CASTER_BD, "x", CASTER_W));
echo("===========================================");
echo(str("CHECK|A_BEAM|", A_BEAM));
echo(str("CHECK|TOTAL_BEAM_LEN|", TOTAL_BEAM_LEN));
echo(str("CHECK|TOTAL_FRAME_VOL|", TOTAL_FRAME_VOL));
echo(str("CHECK|SIZE|W|", W, "|D|", D, "|H|", H, "|P|", P));
echo(str("CHECK|ZLEV|Z_BOT|", Z_BOT, "|Z_LEFT|", Z_LEFT, "|Z_MAIN|", Z_MAIN,
         "|CAB_H|", CAB_H, "|Z_TOP|", Z_TOP));
echo(str("CHECK|XZON|X_DIV|", X_DIV, "|X_CAB|", X_CAB, "|PANEL_T|", PANEL_T));
echo(str("CHECK|PEG|", PEG_NX, "|", PEG_NZ, "|", PEG_T, "|", PEG_H, "|",
         W - P - (X_DIV + P/2), "|", H_MAIN));
echo(str("CHECK|DRW|", N_DRAWER, "|", DRW_W, "|", DRW_GAP, "|", DRW_BW, "|",
         DRW_BD, "|", DRW_BH, "|", DRW_FH, "|", DRW_L0, "|", DRW_DZ, "|",
         BOT_T, "|", COR20, "|", DRW_FCLR));
echo(str("CHECK|DRWZ|", drw_zf(0), "|", drw_zf(1), "|", drw_zf(2), "|",
         drw_zb(0), "|", drw_zb(1), "|", drw_zb(2)));
echo(str("CHECK|X20|", CAB_X0, "|", CAB_X1, "|", CAB_Z0, "|", E20, "|", DRW_Y0));
echo(str("CHECK|A20|", A20));
echo(str("CHECK|L20|", L20_TOTAL));
echo(str("CHECK|CAST|", CASTER_H, "|", CASTER_PL, "|", CASTER_BS, "|",
         CASTER_BD, "|", CASTER_W, "|", CASTER_T));
echo(str("CHECK|SLIDE|", SLIDE_T, "|", SLIDE_H, "|", SLIDE_L, "|", SLIDE_CLR,
         "|", SLIDE_DZ, "|", SLIDE_GAP));
echo(str("CHECK|HANDLE|", HANDLE_Y, "|", HANDLE_D, "|", HANDLE_OUT));
echo(str("CHECK|LEDGE|", len(LEDGE_ZS), "|", LEDGE_D, "|", LEDGE_T));
echo(str("CHECK|CAB|", CAB_T, "|", D - P - CAB_T, "|", D - 2*P - CAB_T));
echo(str("CHECK|ENC|", ENC_W, "|", ENC_D, "|", ENC_H));
echo("===========================================");
echo(str("净空: 左区收纳 ", X_DIV - P/2 - P, " x ", D - 2*P, " x ",
         Z_LEFT + P - (Z_BOT + P), " mm (宽x深x高, 中间区域净高)"));
echo(str("      贴着前后横梁处净高 ", Z_LEFT - (Z_BOT + P), " mm; 地台面离地 ",
         Z_BOT + P, " mm"));
echo(str("净空: 抽屉口   ", (W-P) - (X_CAB+P/2), " x ", D - 2*P - CAB_T, " x ",
         CAB_H - (Z_BOT + P), " mm; 三层面板各 ", DRW_FH, " mm"));
echo(str("净空: 中区膝下 ", (W - DRW_W) - (X_DIV + P/2), " mm 宽 x ", CAB_H - P, " mm 高"));
echo(str("台面: 左 ", H_LEFT, " / 中右 ", H_MAIN, " / 总高 ", H,
         " (含福马轮 ", CASTER_H, ") mm"));
echo(str("A1mini 封箱 ", ENC_W, "x", ENC_D, "x", ENC_H,
         " -> 前面探出 ", max(0, ENC_D - D), " mm"));
