# cut each character out of the sheet: GrabCut seeded with the head and the chest as sure foreground,
# the crop's rim as sure background; then the largest piece (and any seeded one), holes filled, a soft edge.
# usage: python3 cut.py SHEET.jpg OUTDIR [names...]
import cv2, numpy as np, json, sys
from PIL import Image
SRC, OUT = sys.argv[1], sys.argv[2].rstrip('/') + '/'
img = cv2.imread(SRC)
# box (x0,y0,x1,y1), head (cx,cy,rx,ry), chest (cx,cy,rx,ry); extra: background strokes as polygons in sheet coordinates
C = [
 dict(n='m1', box=(30, 268, 400, 760), head=(240, 405, 70, 95), chest=(245, 640, 95, 90), bg=[[(340,560),(400,560),(400,760),(340,760)]]),
 dict(n='m2', box=(300, 288, 600, 760), head=(458, 430, 70, 95), chest=(455, 650, 90, 90), bg=[[(300,440),(378,440),(378,545),(340,575),(300,575)]]),
 dict(n='m3', box=(545, 288, 880, 790), head=(700, 420, 85, 105), chest=(705, 670, 120, 95), bg=[[(545,560),(585,560),(585,790),(545,790)],[(842,540),(880,540),(880,660),(850,660)]]),
 dict(n='m4', box=(815, 288, 1110, 770), head=(955, 420, 70, 95), chest=(960, 660, 90, 85), bg=[[(815,590),(872,600),(878,770),(815,770)],[(1070,560),(1110,560),(1110,770),(1070,770)]]),
 dict(n='m5', box=(1040, 270, 1360, 780), head=(1190, 420, 75, 100), chest=(1200, 660, 100, 90), bg=[[(1040,560),(1090,560),(1098,780),(1040,780)]]),
 dict(n='f1', box=(10, 1462, 330, 1855), head=(212, 1690, 75, 100), chest=(215, 1830, 70, 40), fg=[('e',(215,1565,70,60)),('e',(214,1500,40,25))]),
 dict(n='f2', box=(330, 1446, 595, 1855), head=(440, 1690, 75, 105), chest=(440, 1830, 80, 40), fg=[('e',(440,1490,30,28)),('e',(440,1585,72,50))]),
 dict(n='f3', box=(565, 1480, 830, 1980), head=(700, 1705, 85, 110), chest=(705, 1900, 80, 70), fg=[('e',(700,1560,80,45)),('r',(598,1600,628,1820)),('r',(775,1600,805,1820))]),
 dict(n='f4', box=(840, 1480, 1110, 1960), head=(985, 1700, 80, 105), chest=(985, 1890, 80, 60), fg=[('e',(978,1560,85,50)),('r',(892,1610,905,1690)),('r',(1060,1610,1072,1690))], bg=[[(840,1640),(884,1640),(884,1960),(840,1960)],[(1058,1725),(1110,1725),(1110,1960),(1058,1960)]]),
 dict(n='f5', box=(1105, 1520, 1415, 1980), head=(1262, 1720, 75, 100), chest=(1255, 1910, 75, 65), fg=[('e',(1262,1600,80,48)),('r',(1160,1650,1172,1780)),('r',(1272,1650,1285,1740)),('p',[(1323,1724),(1402,1758),(1384,1798),(1304,1790)]),('e',(1345,1845,12,22))], bg=[[(1105,1560),(1150,1560),(1150,1770),(1105,1770)],[(1297,1545),(1415,1545),(1415,1750),(1405,1750),(1322,1714),(1297,1714)],[(1297,1714),(1323,1716),(1303,1790),(1297,1790)],[(1297,1793),(1330,1797),(1333,1828),(1297,1840)],[(1105,1520),(1415,1520),(1415,1547),(1105,1547)],[(1284,1547),(1297,1547),(1297,1600),(1292,1600)],[(1105,1738),(1162,1738),(1162,1772),(1105,1772)],[(1370,1805),(1415,1805),(1415,1980),(1370,1980)]]),
]
only = sys.argv[3:] or None
meta = {}
for c in C:
    if only and c['n'] not in only: continue
    x0, y0, x1, y1 = c['box']; crop = img[y0:y1, x0:x1].copy(); h, w = crop.shape[:2]
    m = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    def ell(e, v, k=1.0):
        cx, cy, rx, ry = e; cv2.ellipse(m, (cx - x0, cy - y0), (int(rx * k), int(ry * k)), 0, 0, 360, int(v), -1)
    # probable foreground: a generous silhouette (head and body joined), sure foreground: the cores
    ell(c['head'], cv2.GC_PR_FGD, 1.35); ell(c['chest'], cv2.GC_PR_FGD, 1.6)
    hx, hy = c['head'][0] - x0, c['head'][1] - y0; cx, cy = c['chest'][0] - x0, c['chest'][1] - y0
    cv2.rectangle(m, (min(hx, cx) - 40, hy), (max(hx, cx) + 40, cy), int(cv2.GC_PR_FGD), -1)
    ell(c['head'], cv2.GC_FGD, .62); ell(c['chest'], cv2.GC_FGD, .55)
    for kind, sh in c.get('fg', []):
        if kind == 'e': cxx, cyy, rx, ry = sh; cv2.ellipse(m, (cxx - x0, cyy - y0), (int(rx * 1.3), int(ry * 1.3)), 0, 0, 360, int(cv2.GC_PR_FGD), -1); cv2.ellipse(m, (cxx - x0, cyy - y0), (rx, ry), 0, 0, 360, int(cv2.GC_FGD), -1)
        elif kind == 'p': cv2.fillPoly(m, [np.array([(px - x0, py - y0) for px, py in sh], np.int32)], int(cv2.GC_FGD))
        else: a0, b0, a1, b1 = sh; cv2.rectangle(m, (a0 - x0, b0 - y0), (a1 - x0, b1 - y0), int(cv2.GC_FGD), -1)
    m[:3, :] = cv2.GC_BGD; m[:, :3] = cv2.GC_BGD; m[:, -3:] = cv2.GC_BGD
    for poly in c.get('bg', []):
        cv2.fillPoly(m, [np.array([(px - x0, py - y0) for px, py in poly], np.int32)], int(cv2.GC_BGD))
    seed = m == cv2.GC_FGD
    bgd = np.zeros((1, 65), np.float64); fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(crop, m, None, bgd, fgd, 8, cv2.GC_INIT_WITH_MASK)
    fg = np.where((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    # the largest piece, with its holes filled
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    if n > 1:
        # the largest piece and any piece holding a sure-foreground seed (a card held clear of the hand)
        k = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA])); keep = {k} | set(int(v) for v in np.unique(lab[seed]) if v)
        fg = np.where(np.isin(lab, list(keep)), 255, 0).astype(np.uint8)
    inv = 255 - fg; n2, lab2, st2, _ = cv2.connectedComponentsWithStats(inv, 4)
    for j in range(1, n2):
        x, y, ww, hh, a = st2[j]
        if x > 0 and y > 0 and x + ww < w and y + hh < h: fg[lab2 == j] = 255
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    a = cv2.GaussianBlur(cv2.erode(fg, np.ones((2, 2), np.uint8)), (0, 0), 1.2).astype(np.float32) / 255
    rgba = np.dstack([cv2.cvtColor(crop, cv2.COLOR_BGR2RGB), (a * 255).astype(np.uint8)])
    Image.fromarray(rgba).save(OUT + c['n'] + '.png')
    meta[c['n']] = dict(box=c['box'], head=c['head'])
    print(c['n'], w, h, 'fg', round(float(a.mean()), 3))
json.dump(meta, open(OUT + 'meta.json', 'w'))
# a check sheet: each cut-out on a checker board
tiles = []
for c in C:
    try: t = Image.open(OUT + c['n'] + '.png')
    except Exception: continue
    t.thumbnail((300, 420)); bg = Image.new('RGBA', (300, 420), (255, 0, 255, 255))
    for yy in range(0, 420, 20):
        for xx in range(0, 300, 20):
            if (xx // 20 + yy // 20) % 2: bg.paste((40, 200, 90, 255), (xx, yy, xx + 20, yy + 20))
    bg.alpha_composite(t, ((300 - t.width) // 2, 420 - t.height)); tiles.append(bg)
sheet = Image.new('RGBA', (300 * 5, 420 * 2), 'black')
for i, t in enumerate(tiles): sheet.paste(t, ((i % 5) * 300, (i // 5) * 420))
sheet.convert('RGB').save(OUT + 'check.png')
