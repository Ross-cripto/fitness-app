"""Render a gallery image in the app's style (dark cards, white figure, pink gear)."""
import json, math, sys
from PIL import Image, ImageDraw, ImageFont
from skeleton import *
from preview import TF, bbox
import motions_a, motions_b, motions_c

allm = {}
for m in (motions_a, motions_b, motions_c): allm.update(m.M)

GRAD = {  # muscle -> (top-left, bottom-right)
    'legs': ((0x4A, 0x3A, 0x2A), (0x14, 0x11, 0x0E)), 'chest': ((0x5B, 0x2A, 0x3A), (0x14, 0x12, 0x1A)),
    'back': ((0x2A, 0x3F, 0x5F), (0x10, 0x13, 0x1A)), 'shoulders': ((0x3D, 0x2F, 0x5C), (0x12, 0x10, 0x1A)),
    'arms': ((0x5C, 0x3A, 0x2A), (0x15, 0x10, 0x0E)), 'core': ((0x2A, 0x5C, 0x4F), (0x0E, 0x17, 0x14)),
    'cardio': ((0x6B, 0x24, 0x38), (0x15, 0x0C, 0x10)), 'fullBody': ((0x3A, 0x3F, 0x52), (0x0F, 0x10, 0x15)),
    'mobility': ((0x2A, 0x4F, 0x5C), (0x0D, 0x15, 0x19)),
}
PINK = (255, 45, 107)
SEL = [
    ('bw_squat', 'Bodyweight Squat', 'legs'), ('pushup', 'Push-Up', 'chest'), ('pullup', 'Pull-Up', 'back'),
    ('db_bench', 'Dumbbell Bench Press', 'chest'), ('deadlift', 'Barbell Deadlift', 'legs'), ('plank', 'Plank', 'core'),
    ('jumping_jacks', 'Jumping Jacks', 'cardio'), ('db_curl', 'Dumbbell Curl', 'arms'), ('reverse_lunge', 'Reverse Lunge', 'legs'),
    ('lateral_raise', 'Lateral Raise', 'shoulders'), ('mountain_climber', 'Mountain Climber', 'cardio'), ('lat_pulldown', 'Lat Pulldown', 'back'),
    ('chair_dip', 'Chair Dip', 'arms'), ('pike_pushup', 'Pike Push-Up', 'shoulders'), ('glute_bridge', 'Glute Bridge', 'legs'),
    ('hip_flexor_stretch', 'Hip Flexor Stretch', 'mobility'),
]
S = 2
CW, CH = 360 * S, 270 * S
COLS = 4


def gradient(w, h, c1, c2):
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w + y / h) / 2
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return img


def fig(dr, tf, fr, view, color, w, held, alpha_bg=None):
    j = joints(fr, view)
    P = lambda k: tf(j[k])
    def seg(pts, col, width):
        dr.line([P(k) for k in pts], fill=col, width=int(width), joint='curve')
        for k in pts:
            x, y = P(k); r = width / 2
            dr.ellipse([x - r, y - r, x + r, y + r], fill=col)
    far = tuple(int(c * 0.55 + 20) for c in color)
    seg(['sh_f', 'el_f', 'wr_f'], far, w); seg(['hp_f', 'kn_f', 'an_f', 'to_f'], far, w)
    if view == 'front': seg(['sh_n', 'sh_f'], color, w); seg(['hp_n', 'hp_f'], color, w)
    seg(['hip', 'neck'], color, w * 1.35)
    seg(['sh_n', 'el_n', 'wr_n'], color, w); seg(['hp_n', 'kn_n', 'an_n', 'to_n'], color, w)
    if held == 'dumbbell':
        for s, a in (('n', fr[5]), ('f', fr[7])):
            x, y = P('wr_' + s); r = math.radians(a); h = 0.075 * tf.scale
            dr.line([(x - math.cos(r) * h, y + math.sin(r) * h), (x + math.cos(r) * h, y - math.sin(r) * h)], fill=PINK, width=int(w * 1.25))
    elif held in ('barbell', 'barbell_back'):
        x, y = P('wr_n') if held == 'barbell' else P('neck'); r = 0.105 * tf.scale
        dr.ellipse([x - r, y - r, x + r, y + r], fill=PINK); r2 = r * .38
        dr.ellipse([x - r2, y - r2, x + r2, y + r2], fill=color)
    hx, hy = P('head'); r = L['headR'] * tf.scale
    dr.ellipse([hx - r, hy - r, hx + r, hy + r], fill=color)


rows = math.ceil(len(SEL) / COLS)
pad = 24 * S
sheet = Image.new('RGB', (COLS * CW + (COLS + 1) * pad, rows * (CH + 44 * S) + pad), (18, 18, 22))
font = ImageFont.load_default()
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 15 * S)
    small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 11 * S)
except Exception:
    small = font
for n, (id, title, muscle) in enumerate(SEL):
    m = allm[id]
    cx = pad + (n % COLS) * (CW + pad); cy = pad + (n // COLS) * (CH + 44 * S)
    card = gradient(CW, CH, *GRAD[muscle])
    dr = ImageDraw.Draw(card)
    bb = bbox(m)
    tf = TF(bb, (16 * S, 16 * S, CW - 32 * S, CH - 32 * S))
    fl = m['frames']
    for pr in m.get('props', []):
        p = pr['p']
        if pr['t'] == 'rect':
            dr.rectangle([tf((p[0], p[1] + p[3])), tf((p[0] + p[2], p[1]))], fill=(70, 70, 76))
        elif pr['t'] == 'line':
            dr.line([tf((p[0], p[1])), tf((p[2], p[3]))], fill=(110, 110, 118), width=4 * S)
        elif pr['t'] == 'cable':
            dr.line([tf((p[0], p[1])), tf(joints(fl[0], m['view'])['wr_n'])], fill=(140, 140, 148), width=S)
    dr.line([tf((bb[0], 0)), tf((bb[1], 0))], fill=(90, 90, 96), width=S)
    w = 0.055 * tf.scale
    if len(fl) >= 2:
        fig(dr, tf, fl[0], m['view'], (120, 120, 130), w, m.get('held'))
    fig(dr, tf, fl[min(1, len(fl) - 1)], m['view'], (255, 255, 255), w, m.get('held'))
    sheet.paste(card.convert('RGB'), (cx, cy))
    d2 = ImageDraw.Draw(sheet)
    d2.text((cx + 4 * S, cy + CH + 6 * S), title, fill=(255, 255, 255), font=font)
    d2.text((cx + 4 * S, cy + CH + 26 * S), muscle, fill=(160, 160, 170), font=small)
sheet = sheet.resize((sheet.width // 2 * 1, sheet.height // 2 * 1), Image.LANCZOS) if False else sheet
sheet.save(sys.argv[1])
print(sheet.size)
