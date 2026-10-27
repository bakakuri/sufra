# pack the ten cut-outs into the picture the card table draws them from, and the faces for the name plates.
# every figure is scaled so the distance from the eyes to the chin is the same, and set with its eyes on one line;
# where the picture stops above the waist (a prop of the neighbour's in front) the lowest row is carried on down: it ends up under the table.
# usage: python3 atlas.py SHEET.jpg CUTDIR OUTDIR
import cv2, numpy as np, json, sys
from PIL import Image
SRC, CUT, OUT = sys.argv[1], sys.argv[2].rstrip('/') + '/', sys.argv[3].rstrip('/') + '/'
# eyes (midpoint) and chin, measured on the sheet
EYE = {'m1': (240, 400, 477), 'm2': (468, 435, 528), 'm3': (708, 430, 535), 'm4': (943, 430, 528), 'm5': (1174, 403, 492),
       'f1': (210, 1623, 1700), 'f2': (432, 1622, 1705), 'f3': (693, 1647, 1735), 'f4': (965, 1632, 1710), 'f5': (1247, 1660, 1735)}
ORDER = ['m1', 'm2', 'm3', 'm4', 'm5', 'f1', 'f2', 'f3', 'f4', 'f5']
AW, AH, CW, CH, SX, SY = 2048, 1024, 400, 508, 409, 516   # atlas, cell, cell stride
EC, EX, EY = 72, 200, 160                                   # eyes to chin in pixels; where the eyes sit in a cell
OPQ, END = EY + 3.7 * EC, EY + 4.15 * EC                    # fully there down to here, gone by here (the table line is 3.4 below the eyes)
meta = json.load(open(CUT + 'meta.json'))
sheet = cv2.cvtColor(cv2.imread(SRC), cv2.COLOR_BGR2RGB)
atlas = np.zeros((AH, AW, 4), np.float32)
cells = {}
for i, n in enumerate(ORDER):
    x0, y0, x1, y1 = meta[n]['box']; ex, ey, chin = EYE[n]; k = EC / (chin - ey)
    im = np.asarray(Image.open(CUT + n + '.png')).astype(np.float32) / 255
    a = im[:, :, 3:4]; pm = np.concatenate([im[:, :, :3] * a, a], 2)   # premultiplied, so the edge does not darken when scaled
    h, w = pm.shape[:2]; sw, sh = max(1, round(w * k)), max(1, round(h * k))
    pm = cv2.resize(pm, (sw, sh), interpolation=cv2.INTER_AREA)
    ox, oy = round(EX - (ex - x0) * k), round(EY - (ey - y0) * k)    # where the crop's corner lands in the cell
    cell = np.zeros((CH, CW, 4), np.float32)
    for yy in range(sh):
        cy = oy + yy
        if 0 <= cy < CH:
            xa, xb = max(0, ox), min(CW, ox + sw)
            if xb > xa: cell[cy, xa:xb] = pm[yy, xa - ox:xb - ox]
    # carry the last row down if the picture stops short, a little darker as it goes: it is in the shadow of the table
    last = min(CH, oy + sh) - 1
    if last < END:
        row = cell[last].copy()
        for cy in range(last + 1, int(END) + 2):
            if cy >= CH: break
            d = 1 - .25 * min(1, (cy - last) / (END - last)); r = row.copy(); r[:, :3] *= d; cell[cy] = r
    # below the table the figure fades away
    yy = np.arange(CH, dtype=np.float32); t = np.clip((yy - OPQ) / (END - OPQ), 0, 1); f = 1 - t * t * (3 - 2 * t)
    cell *= f[:, None, None]
    # keep a hair's width clear round the cell, so neighbours never bleed in when the picture is shrunk
    cell[:2] = 0; cell[-2:] = 0; cell[:, :2] = 0; cell[:, -2:] = 0
    cx, cy = (i % 5) * SX, (i // 5) * SY
    atlas[cy:cy + CH, cx:cx + CW] = cell
    cells[n] = [cx / AW, cy / AH, CW / AW, CH / AH]
    print(n, 'scale', round(k, 3), 'crop ends at', round((last - EY) / EC, 2), 'EC below the eyes')
# colour pushed out under the transparent part (pull-push), so the soft edge keeps its colour in every mip level
A = atlas[:, :, 3:4]; P = atlas[:, :, :3]
fill = np.zeros_like(P); have = np.zeros_like(A)
for s in [1, 2, 4, 8, 16, 32]:
    bp = cv2.GaussianBlur(P, (0, 0), s); ba = cv2.GaussianBlur(A[:, :, 0], (0, 0), s)[:, :, None]
    c = bp / np.maximum(ba, 1e-4); need = (have < .5) & (ba > 1e-3)
    fill = np.where(need, c, fill); have = np.where(need, 1, have)
rgb = np.where(A > 1e-3, P / np.maximum(A, 1e-4), fill)
out = np.concatenate([np.clip(rgb, 0, 1), A], 2)
Image.fromarray((out * 255 + .5).astype(np.uint8), 'RGBA').save(OUT + 'cast1.webp', quality=88, method=6)
# faces: a square round each face, the cut-out on a warm lamplit glow (the sheet behind has the neighbours' shoulders in it)
F = 128; faces = Image.new('RGB', (F * 10, F))
yy, xx = np.mgrid[0:F, 0:F].astype(np.float32); rr = np.hypot(xx - F * .5, yy - F * .38) / F
glow = np.clip(1 - rr * 1.25, 0, 1)[:, :, None]; bgc = (np.array([58, 34, 24]) * (1 - glow) + np.array([196, 128, 70]) * glow).astype(np.uint8)
for i, n in enumerate(ORDER):
    x0, y0 = meta[n]['box'][:2]; ex, ey, chin = EYE[n]; e = chin - ey; c = (ex - x0, ey - y0 + .5 * e); r = 1.7 * e
    cut = Image.open(CUT + n + '.png')
    sq = cut.crop((round(c[0] - r), round(c[1] - r), round(c[0] + r), round(c[1] + r))).resize((F, F), Image.LANCZOS)
    b = Image.fromarray(bgc).convert('RGBA'); b.alpha_composite(sq); faces.paste(b.convert('RGB'), (i * F, 0))
faces.save(OUT + 'cast1f.webp', quality=86, method=6)
json.dump({'cells': cells, 'ec': EC / CH, 'eye': [EX / CW, EY / CH], 'aspect': CW / CH}, open(OUT + 'cast1.json', 'w'))
# a check on a checker board
pv = Image.fromarray((out * 255).astype(np.uint8), 'RGBA'); bg = Image.new('RGBA', pv.size, (40, 60, 90, 255))
for yy in range(0, AH, 32):
    for xx in range(0, AW, 32):
        if (xx // 32 + yy // 32) % 2: bg.paste((60, 80, 110, 255), (xx, yy, xx + 32, yy + 32))
bg.alpha_composite(pv); d = np.asarray(bg).copy()
for yl, col in [(EY, (255, 255, 0)), (EY + 3.4 * EC, (255, 0, 0))]:
    for r in range(2): d[int(yl) + r::SY, :] = d[int(yl) + r::SY, :]; d[[int(yl) + r, int(yl) + r + SY], :, :3] = col
Image.fromarray(d).convert('RGB').resize((AW // 2, AH // 2)).save(OUT + 'atlas_check.png')
