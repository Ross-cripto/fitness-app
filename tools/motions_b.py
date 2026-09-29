from skeleton import *

M = {}
def motion(id, frames, view='side', props=(), held=None, dur=0.9, loop='pingpong'):
    M[id] = dict(frames=frames, view=view, props=list(props), held=held, dur=dur, loop=loop)

BODY = L['torso'] + L['thigh'] + L['shin']      # shoulder -> ankle when straight
ARM = L['upper'] + L['fore']
SEAT = STAND_ANKLE


def front_support(sy, ankle_y=0.12, hand_y=0.0, foot=25, pref=B, hx=0.0, knees=False, far_hand=None, head_tilt=6):
    """Push-up / plank family. Hands are fixed at (hx, hand_y); feet fixed so the arms are vertical
    when the shoulder is at its top height. `sy` is the current shoulder height."""
    length = L['torso'] + (L['thigh'] if knees else L['thigh'] + L['shin'])
    base_y = 0.06 if knees else ankle_y
    top = hand_y + ARM - 0.02
    ax = hx - math.sqrt(length ** 2 - (top - base_y) ** 2)
    sx = ax + math.sqrt(length ** 2 - (sy - base_y) ** 2)
    sh = (sx, sy); pivot = (ax, base_y)
    u = (sh[0] - pivot[0], sh[1] - pivot[1]); n = math.hypot(*u); u = (u[0] / n, u[1] / n)
    hip = (sh[0] - u[0] * L['torso'], sh[1] - u[1] * L['torso'])
    torso = ang(u)
    if knees:
        leg = LA(ang((-u[0], -u[1])), -110, -90)
    else:
        leg = LR(ax, ankle_y, U, foot)
    farm = None if far_hand is None else far_hand
    return pose(hip, torso, head=torso + head_tilt, arm=R(hx, hand_y, pref), leg=leg, farm=farm)

def wall_lean(phi, hand=(0.55, 1.30)):
    """Standing lean against a wall: feet fixed, body straight at phi degrees above horizontal."""
    ax, ay = -0.62, STAND_ANKLE
    sh = (ax + BODY * math.cos(math.radians(phi)), ay + BODY * math.sin(math.radians(phi)))
    u = (sh[0] - ax, sh[1] - ay); n = math.hypot(*u); u = (u[0] / n, u[1] / n)
    hip = (sh[0] - u[0] * L['torso'], sh[1] - u[1] * L['torso'])
    return pose(hip, ang(u), arm=R(hand[0], hand[1], D), leg=LR(ax, ay, F, 90))

def lying(hip, arm, leg, head_extra=0, torso=270):
    return pose(hip, torso, head=torso + head_extra, arm=arm, leg=leg)

BENCH = [dict(t='rect', p=[-1.05, 0.40, 1.15, 0.07]), dict(t='line', p=[-0.95, 0, -0.95, 0.40]), dict(t='line', p=[0.0, 0, 0.0, 0.40])]

# ---------------- CHEST ----------------
motion('wall_pushup', [wall_lean(64), wall_lean(46)], props=[dict(t='line', p=[0.62, 0, 0.62, 1.9])])
motion('knee_pushup', [front_support(0.55, knees=True), front_support(0.20, knees=True)])
motion('pushup', [front_support(0.55), front_support(0.17)])
motion('decline_pushup', [front_support(0.60, ankle_y=0.55), front_support(0.24, ankle_y=0.55)],
       props=[dict(t='rect', p=[-1.55, 0, 0.55, 0.42])])
motion('close_pushup', [front_support(0.55, pref=D), front_support(0.17, pref=D)])
motion('diamond_pushup', [front_support(0.55, pref=D), front_support(0.17, pref=D)])

bench_legs = LR(0.30, 0.05, F, 90)
motion('db_bench', [lying((-0.20, 0.55), A(180, 180), bench_legs), lying((-0.20, 0.55), A(15, 180), bench_legs)],
       props=BENCH, held='dumbbell')
motion('bench_press', [lying((-0.20, 0.55), A(180, 180), bench_legs), lying((-0.20, 0.55), A(15, 180), bench_legs)],
       props=BENCH, held='barbell')
motion('db_fly', [lying((-0.20, 0.55), A(180, 180), bench_legs), lying((-0.20, 0.55), A(-115, -125), bench_legs)],
       props=BENCH, held='dumbbell')
inc_legs = LR(0.35, 0.05, F, 90)
def incline(arm): return pose((0.05, 0.52), 225, head=225, arm=arm, leg=inc_legs)
motion('db_incline_press', [incline(A(178, 178)), incline(A(30, 175))],
       props=[dict(t='line', p=[0.10, 0.40, -0.62, 1.10]), dict(t='rect', p=[-0.10, 0.36, 0.5, 0.05]), dict(t='line', p=[0.15, 0, 0.15, 0.36])],
       held='dumbbell')
def seated_press(arm): return pose((-0.30, 0.46), 176, arm=arm, leg=LA(90, 0, 90))
motion('machine_chest_press', [seated_press(A(90, 90)), seated_press(A(20, 90))],
       props=[dict(t='line', p=[-0.44, 0.40, -0.40, 1.3]), dict(t='rect', p=[-0.44, 0.38, 0.55, 0.05])])

# ---------------- BACK ----------------
def prone(torso, arm, leg, hx=0.0):
    return pose((hx, 0.10), torso, head=torso, arm=arm, leg=leg)
motion('superman', [prone(90, A(90, 90), LA(-90, -90, -90)), prone(108, A(104, 104), LA(-102, -102, -102))])
motion('reverse_snow_angel', [prone(104, A(-100, -100), LA(-96, -96, -96)), prone(104, A(100, 100), LA(-96, -96, -96))], dur=1.4)

def inv_row(sh_y, bar_y=0.88, hand_x=0.55):
    ay = 0.09
    sx = -0.90 + math.sqrt(BODY ** 2 - (sh_y - ay) ** 2)
    sh = (sx, sh_y); an = (-0.90, ay)
    u = (sh[0] - an[0], sh[1] - an[1]); n = math.hypot(*u); u = (u[0] / n, u[1] / n)
    hip = (sh[0] - u[0] * L['torso'], sh[1] - u[1] * L['torso'])
    return pose(hip, ang(u), head=ang(u) - 8, arm=R(hand_x, bar_y, D), leg=LR(an[0], an[1], U, 60))
motion('inverted_row', [inv_row(0.30), inv_row(0.66)],
       props=[dict(t='rect', p=[0.30, 0.82, 0.60, 0.06]), dict(t='line', p=[0.35, 0, 0.35, 0.82]), dict(t='line', p=[0.85, 0, 0.85, 0.82])])

def row_one(arm):
    return pose((-0.55, 0.86), 100, head=105, arm=arm, leg=LR(-0.35, 0.05, F, 90),
                farm=R(0.05, 0.47, B))
motion('db_row', [row_one(A(0, 0)), row_one(A(-95, -10))],
       props=[dict(t='rect', p=[-1.15, 0.40, 1.3, 0.07]), dict(t='line', p=[-1.05, 0, -1.05, 0.40]), dict(t='line', p=[0.05, 0, 0.05, 0.40])],
       held='dumbbell')
def bent(arm): return pose((-0.30, 0.84), 100, head=110, arm=arm, leg=LR(0.02, 0.05, F, 90))
motion('db_bent_row', [bent(A(0, 0)), bent(A(-105, -20))], held='dumbbell')
motion('barbell_row', [bent(A(5, 5)), bent(A(-105, -20))], held='barbell')

def seated_pull(wrist_y, wrist_x, pref=D):
    return pose((-0.30, 0.46), 174, arm=R(wrist_x, wrist_y, pref), leg=LA(90, 0, 90))
motion('lat_pulldown', [seated_pull(1.62, 0.16), seated_pull(1.02, 0.10)],
       props=[dict(t='rect', p=[-0.42, 0.38, 0.55, 0.05]), dict(t='cable', p=[0.15, 2.05]), dict(t='rect', p=[0.02, 0.62, 0.30, 0.05])])
def floor_row(x, y): return pose((-0.55, 0.10), 180, arm=R(x, y, B), leg=LA(85, 85, 90))
motion('seated_row', [floor_row(0.20, 0.72), floor_row(-0.25, 0.62)],
       props=[dict(t='cable', p=[1.35, 0.55])])
def hang(sy, legs=LA(0, -60, -60)):
    return pose((0.0, sy - L['torso']), 180, arm=R(0.0, 2.0, D), leg=legs)
motion('pullup', [hang(1.43), hang(1.86, LA(-5, -70, -70))],
       props=[dict(t='line', p=[-0.5, 2.0, 0.5, 2.0])], dur=1.3)

# ---------------- SHOULDERS ----------------
def plank_tap(lift):
    fa = R(0.10, 0.06 + 0.98, U) if lift else None
    return front_support(0.55, far_hand=(R(-0.2, 1.05, U) if False else None))
def tap_frame(lift):
    base = front_support(0.55)
    if not lift:
        return base
    j = joints(base)
    sh = j['neck']
    return pose((base[0], base[1]), base[2], head=base[3], arm=R(0.0, 0.0, B), leg=LR(j['an_n'][0], j['an_n'][1], U, 25),
                farm=R(sh[0] + 0.05, sh[1] - 0.12, U))
motion('plank_tap', [tap_frame(False), tap_frame(True)], dur=0.7)

def pike(hip, torso, hand, ankle, pref=B):
    return pose(hip, torso, head=torso - 20, arm=R(hand[0], hand[1], pref), leg=LR(ankle[0], ankle[1], U, 25))
motion('pike_pushup', [pike((-0.28, 0.95), 38, (0.20, 0.0), (-0.64, 0.12)), pike((-0.10, 0.95), 14, (0.20, 0.0), (-0.64, 0.12))])
motion('elevated_pike', [pike((-0.24, 1.0), 25, (0.14, 0.0), (-0.85, 0.57)), pike((-0.10, 0.98), 10, (0.14, 0.0), (-0.85, 0.57))],
       props=[dict(t='rect', p=[-1.1, 0, 0.5, 0.45])])

def front(arm, legs=LA(4, 0, 90)):
    return pose((0, STAND_HIP), 180, arm=arm, leg=legs, farm='m', fleg='m', view='front')
motion('db_shoulder_press', [front(A(88, 178)), front(A(165, 176))], view='front', held='dumbbell')
motion('arnold_press', [front(A(15, 160)), front(A(165, 176))], view='front', held='dumbbell')
motion('lateral_raise', [front(A(4, 4)), front(A(86, 86))], view='front', held='dumbbell')
motion('shoulder_circles', [front(A(88, 88)), front(A(150, 150)), front(A(88, 88)), front(A(30, 30))], view='front', loop='cycle', dur=0.9)

def stand_arm(arm, leg=LA(0, 0, 90)): return pose((0, STAND_HIP), 180, arm=arm, leg=leg)
motion('face_pull', [stand_arm(A(90, 90)), stand_arm(A(-95, 110))], props=[dict(t='cable', p=[1.0, 1.36])])
motion('overhead_press', [stand_arm(A(60, 180)), stand_arm(A(178, 178))], held='barbell')

# ---------------- ARMS ----------------
chair = [dict(t='rect', p=[-0.62, 0.40, 0.50, 0.05]), dict(t='line', p=[-0.58, 0, -0.58, 0.40]), dict(t='line', p=[-0.16, 0, -0.16, 0.40])]
def dip(sh_y):
    hip = (-0.04, sh_y - L['torso'])
    return pose(hip, 180, arm=R(-0.14, 0.47, B), leg=LR(0.72, 0.06, F, 60))
motion('chair_dip', [dip(1.03), dip(0.70)], props=chair)
motion('db_curl', [stand_arm(A(3, 3)), stand_arm(A(4, 155))], held='dumbbell')
motion('hammer_curl', [stand_arm(A(3, 3)), stand_arm(A(4, 155))], held='dumbbell', dur=1.0)
motion('barbell_curl', [stand_arm(A(4, 4)), stand_arm(A(4, 150))], held='barbell')
motion('db_tricep_ext', [stand_arm(A(178, 178)), stand_arm(A(178, -8))], held='dumbbell')
motion('tricep_pushdown', [stand_arm(A(4, 100)), stand_arm(A(4, 6))], props=[dict(t='cable', p=[0.45, 2.0])])
