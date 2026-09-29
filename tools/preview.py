"""Render ghosted contact sheets of all motions so poses can be checked by eye."""
import math, sys
from PIL import Image, ImageDraw, ImageFont
from skeleton import *

COLORS = [(40, 90, 220), (230, 50, 70), (30, 160, 80), (230, 150, 20), (150, 60, 200), (0, 160, 170)]


def cycle_frames(m):
    fr = m['frames']
    if m.get('loop', 'pingpong') == 'pingpong' and len(fr) > 2:
        return fr + fr[-2:0:-1]
    if m.get('loop', 'pingpong') == 'pingpong':
        return fr + [fr[0]]
    return fr + [fr[0]]


def bbox(m):
    xs, ys = [], []
    for fr in m['frames']:
        j = joints(fr, m['view'])
        for k, p in j.items():
            xs.append(p[0]); ys.append(p[1])
        xs.append(j['head'][0] + L['headR']); ys.append(j['head'][1] + L['headR'])
    for pr in m.get('props', []):
        p = pr['p']
        if pr['t'] == 'line': xs += [p[0], p[2]]; ys += [p[1], p[3]]
        elif pr['t'] == 'rect': xs += [p[0], p[0] + p[2]]; ys += [p[1], p[1] + p[3]]
        elif pr['t'] == 'circle': xs += [p[0] - p[2], p[0] + p[2]]; ys += [p[1] - p[2], p[1] + p[2]]
        elif pr['t'] == 'cable': xs.append(p[0]); ys.append(p[1])
    ys.append(0)
    x0, x1, y0, y1 = min(xs) - .12, max(xs) + .12, min(ys) - .06, max(ys) + .12
    w, h = x1 - x0, y1 - y0
    if w < 1.5:
        cx = (x0 + x1) / 2; x0, x1 = cx - .75, cx + .75
    if h < 1.1:
        y1 = y0 + 1.1
    return [round(x0, 3), round(x1, 3), round(y0, 3), round(y1, 3)]


def draw_fig(dr, tf, fr, view, color, width, held=None):
    j = joints(fr, view)
    def P(k): return tf(j[k])
    def seg(a, b, w=width): dr.line([P(a), P(b)], fill=color, width=w)
    seg('hip', 'neck', width + 2)
    for s in ('f', 'n'):
        seg('sh_' + s, 'el_' + s); seg('el_' + s, 'wr_' + s)
        seg('hp_' + s, 'kn_' + s); seg('kn_' + s, 'an_' + s); seg('an_' + s, 'to_' + s)
    if view == 'front':
        seg('sh_n', 'sh_f'); seg('hp_n', 'hp_f')
    hx, hy = P('head'); r = L['headR'] * tf.scale
    dr.ellipse([hx - r, hy - r, hx + r, hy + r], outline=color, width=width)
    if held == 'barbell_back':
        x, y = P('neck'); dr.ellipse([x - 10, y - 10, x + 10, y + 10], outline=(60, 60, 60), width=3)
    elif held:
        for s in ('n', 'f'):
            x, y = P('wr_' + s)
            if held == 'dumbbell': dr.rectangle([x - 6, y - 3, x + 6, y + 3], fill=(60, 60, 60))
            else: dr.ellipse([x - 10, y - 10, x + 10, y + 10], outline=(60, 60, 60), width=3)
            if held == 'barbell': break


class TF:
    def __init__(self, bb, box):
        x0, x1, y0, y1 = bb; bx, by, bw, bh = box
        self.scale = min(bw / (x1 - x0), bh / (y1 - y0))
        self.ox = bx + (bw - (x1 - x0) * self.scale) / 2 - x0 * self.scale
        self.oy = by + (bh + (y1 - y0) * self.scale) / 2 + y0 * self.scale
    def __call__(self, p): return (self.ox + p[0] * self.scale, self.oy - p[1] * self.scale)


def draw_props(dr, tf, m, frames):
    for pr in m.get('props', []):
        p = pr['p']
        if pr['t'] == 'line':
            dr.line([tf((p[0], p[1])), tf((p[2], p[3]))], fill=(120, 120, 120), width=4)
        elif pr['t'] == 'rect':
            a = tf((p[0], p[1] + p[3])); b = tf((p[0] + p[2], p[1])); dr.rectangle([a, b], fill=(190, 190, 190))
        elif pr['t'] == 'circle':
            c = tf((p[0], p[1])); r = p[2] * tf.scale; dr.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=(120, 120, 120), width=3)
        elif pr['t'] == 'cable':
            j = joints(frames[0], m['view']); dr.line([tf((p[0], p[1])), tf(j['wr_n'])], fill=(120, 120, 120), width=2)


def sheet(motions, path, cols=4, cw=340, ch=250):
    rows = math.ceil(len(motions) / cols)
    img = Image.new('RGB', (cols * cw, rows * ch), 'white')
    dr = ImageDraw.Draw(img)
    for i, (name, m) in enumerate(motions):
        cx, cy = (i % cols) * cw, (i // cols) * ch
        dr.rectangle([cx, cy, cx + cw - 1, cy + ch - 1], outline=(200, 200, 200))
        dr.text((cx + 6, cy + 4), name, fill=(0, 0, 0))
        tf = TF(bbox(m), (cx + 8, cy + 20, cw - 16, ch - 28))
        draw_props(dr, tf, m, m['frames'])
        dr.line([tf((-5, 0)), tf((5, 0))], fill=(150, 150, 150), width=1)
        # clip ground line to cell
        for k, fr in enumerate(m['frames']):
            draw_fig(dr, tf, fr, m['view'], COLORS[k % len(COLORS)], 3, m.get('held'))
    img.save(path)


def filmstrip(motions, path, cell=125, maxf=6):
    rows = len(motions)
    img = Image.new('RGB', (maxf * cell + 110, rows * cell), 'white')
    dr = ImageDraw.Draw(img)
    for i, (name, m) in enumerate(motions):
        y0 = i * cell
        dr.text((4, y0 + 4), name, fill=(0, 0, 0))
        bb = bbox(m)
        for k, fr in enumerate(m['frames'][:maxf]):
            x0 = 110 + k * cell
            dr.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], outline=(220, 220, 220))
            tf = TF(bb, (x0 + 4, y0 + 4, cell - 8, cell - 8))
            draw_props(dr, tf, m, [fr])
            dr.line([tf((-5, 0)), tf((5, 0))], fill=(150, 150, 150), width=1)
            draw_fig(dr, tf, fr, m['view'], (30, 30, 30) if k % 2 == 0 else (200, 40, 60), 3, m.get('held'))
    img.save(path)
