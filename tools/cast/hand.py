# the hand the drawn people reach with: m1's raised hand, cut from its picture, turned upright (fingers up, wrist down), the cuff faded away
import cv2, numpy as np, sys
from PIL import Image
CUT = sys.argv[1].rstrip('/') + '/'; OUT = sys.argv[2]
im = np.asarray(Image.open(CUT + 'm1.png')).astype(np.float32) / 255
c = im[238:356, 2:92].copy()                      # the raised hand and its cuff
lum = c[:, :, :3] @ np.array([.3, .59, .11])
h0, w0 = c.shape[:2]; Y, X = np.mgrid[0:h0, 0:w0]
c[:, :, 3] *= np.where((X > 52) & (Y > 80), np.clip((lum - .22) / .12, 0, 1), 1)    # the black sleeve (low right) goes
# holes inside the hand (dark creases of the original cut) closed again
a0 = (c[:, :, 3] > .4).astype(np.uint8); cl = cv2.morphologyEx(a0, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
inv = 1 - cl; n2, lab2, st2, _ = cv2.connectedComponentsWithStats(inv, 4)
for j in range(1, n2):
    x, y, ww, hh, ar = st2[j]
    if x > 0 and y > 0 and x + ww < w0 and y + hh < h0: cl[lab2 == j] = 1
c[:, :, 3] = np.maximum(c[:, :, 3], cv2.GaussianBlur(cl.astype(np.float32), (0, 0), .8) * (cl > 0))
# the cuff (white, below the wrist) fades out: rows from the wrist down
h, w = c.shape[:2]; yy = np.arange(h)[:, None]
white = (c[:, :, :3].min(2) > .78) & (yy > h * .62)
c[:, :, 3] *= np.where(white, 0, 1)
# the largest piece only
a = (c[:, :, 3] > .5).astype(np.uint8); n, lab, st, _ = cv2.connectedComponentsWithStats(a, 8)
if n > 1:
    k = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA])); c[:, :, 3] *= cv2.dilate((lab == k).astype(np.uint8), np.ones((3, 3), np.uint8))
# axis: from the wrist (lowest third) to the fingertips (top third)
ys, xs = np.nonzero(c[:, :, 3] > .5); top = ys < ys.min() + (ys.max() - ys.min()) * .3; bot = ys > ys.max() - (ys.max() - ys.min()) * .25
tip = np.array([xs[top].mean(), ys[top].mean()]); wr = np.array([xs[bot].mean(), ys[bot].mean()]); ang = np.degrees(np.arctan2(tip[0] - wr[0], wr[1] - tip[1]))
print('tip', tip, 'wrist', wr, 'angle', ang)
pm = np.dstack([c[:, :, :3] * c[:, :, 3:4], c[:, :, 3:4]])
S = 3.0; big = cv2.resize(pm, None, fx=S, fy=S, interpolation=cv2.INTER_CUBIC)
H, W = big.shape[:2]; M = cv2.getRotationMatrix2D((wr[0] * S, wr[1] * S), ang, 1.0)
rot = cv2.warpAffine(big, M, (W, H), flags=cv2.INTER_CUBIC, borderValue=(0, 0, 0, 0))
ys, xs = np.nonzero(rot[:, :, 3] > .05); x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
crop = rot[y0:y1 + 1, x0:x1 + 1]
# onto 128x192: fingers at the top, wrist at the bottom middle
TW, TH = 128, 256; ch, cw = crop.shape[:2]; k = min((TW - 8) / cw, (TH - 6) / ch); crop = cv2.resize(crop, (max(1, int(cw * k)), max(1, int(ch * k))), interpolation=cv2.INTER_AREA)
ch, cw = crop.shape[:2]; out = np.zeros((TH, TW, 4), np.float32); wx = (wr[0] * S - x0) * k
ox = int(round(TW / 2 - wx)); ox = max(0, min(TW - cw, ox)); oy = TH - ch - 2
out[oy:oy + ch, ox:ox + cw] = crop
# the wrist end fades so the sleeve takes over
yy = np.arange(TH)[:, None, None]; out *= np.clip((TH - 2 - yy) / 22, 0, 1)
A = out[:, :, 3:4]; P = out[:, :, :3]; fill = np.zeros_like(P); have = np.zeros_like(A)
for s in [1, 2, 4, 8, 16]:
    bp = cv2.GaussianBlur(P, (0, 0), s); ba = cv2.GaussianBlur(A[:, :, 0], (0, 0), s)[:, :, None]; need = (have < .5) & (ba > 1e-3)
    fill = np.where(need, bp / np.maximum(ba, 1e-4), fill); have = np.where(need, 1, have)
rgb = np.where(A > 1e-3, P / np.maximum(A, 1e-4), fill)
Image.fromarray((np.concatenate([np.clip(rgb, 0, 1), A], 2) * 255 + .5).astype(np.uint8), 'RGBA').save(OUT, quality=90, method=6)
print('hand', cw, ch, 'at', ox, oy)
