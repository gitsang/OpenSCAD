"""极简 ASCII-STL 量测工具。

注意: OpenSCAD 的 `-o x.stl` 输出的是【ASCII】STL (即使文件头写着
`solid OpenSCAD_Model`)。用二进制方式解析会读到垃圾三角面数, 所以这里
统一按 ASCII 文本正则提取顶点。
"""
import re

import numpy as np

_VERTEX = re.compile(
    r"vertex\s+(-?[\d.eE+-]+)\s+(-?[\d.eE+-]+)\s+(-?[\d.eE+-]+)"
)


def triangles(path):
    """返回 (n, 3, 3) 的三角形顶点数组; 文件不存在/为空返回 shape (0,3,3)。"""
    try:
        txt = open(path, "r", errors="ignore").read()
    except OSError:
        return np.zeros((0, 3, 3), dtype=np.float64)
    v = np.array(_VERTEX.findall(txt), dtype=np.float64)
    if v.size == 0:
        return np.zeros((0, 3, 3), dtype=np.float64)
    return v.reshape(-1, 3, 3)


def measure(path):
    """返回 (volume, bbox_min, bbox_max, n_facets)。

    空模型 (交集为空 / 文件缺失) 返回 volume=0 且 bbox 全 0。
    """
    tris = triangles(path)
    if len(tris) == 0:
        return 0.0, np.zeros(3), np.zeros(3), 0

    vol = abs(np.einsum("ij,ij->i", tris[:, 0],
                        np.cross(tris[:, 1], tris[:, 2])).sum() / 6.0)
    flat = tris.reshape(-1, 3)
    return vol, flat.min(0), flat.max(0), len(tris)


def n_components(path):
    """按「共享边」做并查集, 返回 STL 里的连通块数量。

    单一实体必须返回 1。悬空的卡勾/孤岛会在这里暴露出来。
    """
    tris = triangles(path)
    n = len(tris)
    if n == 0:
        return 0

    flat = np.round(tris.reshape(-1, 3), 4)
    _, inv = np.unique(flat, axis=0, return_inverse=True)
    idx = inv.reshape(-1, 3)

    par = np.arange(n)

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a

    seen = {}
    for t in range(n):
        a, b, c = int(idx[t, 0]), int(idx[t, 1]), int(idx[t, 2])
        for e in ((a, b), (b, c), (c, a)):
            key = e if e[0] < e[1] else (e[1], e[0])
            other = seen.get(key)
            if other is None:
                seen[key] = t
            else:
                ra, rb = find(t), find(other)
                if ra != rb:
                    par[rb] = ra
    return len({find(t) for t in range(n)})
