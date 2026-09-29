from skeleton import *
from motions_b import front_support, BODY

M = {}
def motion(id, frames, view='side', props=(), held=None, dur=0.9, loop='pingpong'):
    M[id] = dict(frames=frames, view=view, props=list(props), held=held, dur=dur, loop=loop)

def upright(hip_x, hip_y, lean, arm, leg=None, head=None, farm=None, fleg=None, ax=0.0):
    return pose((hip_x, hip_y), 180 - lean, head, arm, leg or LR(ax, STAND_ANKLE, F, 90), farm, fleg)

def lie(torso, arm, leg, farm=None, fleg=None, hip=(0.0, 0.10), head=None):
    return pose(hip, torso, head=torso if head is None else head, arm=arm, leg=leg, farm=farm, fleg=fleg)

# ---------------- CORE ----------------
def forearm_plank(sy, ankle_y=0.12):
    ax = -0.05 - math.sqrt(BODY ** 2 - (0.30 - ankle_y) ** 2)
    sx = ax + math.sqrt(BODY ** 2 - (sy - ankle_y) ** 2)
    sh = (sx, sy); u = (sh[0] - ax, sh[1] - ankle_y); n = math.hypot(*u); u = (u[0] / n, u[1] / n)
    hip = (sh[0] - u[0] * L['torso'], sh[1] - u[1] * L['torso'])
    return pose(hip, ang(u), head=ang(u) + 8, arm=A(0, 90), leg=LR(ax, ankle_y, U, 25))
motion('plank', [forearm_plank(0.30), forearm_plank(0.34)], dur=1.4)

def side_plank(sag):
    sh = (0.50, 0.31); an = (-0.86, 0.06)
    u = (sh[0] - an[0], sh[1] - an[1]); n = math.hypot(*u); u = (u[0] / n, u[1] / n)
    hip = (sh[0] - u[0] * L['torso'], sh[1] - u[1] * L['torso'] - sag)
    torso = ang((sh[0] - hip[0], sh[1] - hip[1]))
    return pose(hip, torso, head=torso + 4, arm=A(0, 90), farm=A(178, 178), leg=LR(an[0], an[1], U, 90))
motion('side_plank', [side_plank(0.14), side_plank(0.0)], dur=1.2)

tabletop = LA(180, 90, 90)
motion('dead_bug', [
    lie(270, A(180, 180), tabletop),
    lie(270, A(-100, -100), tabletop, farm=A(180, 180), fleg=LA(94, 94, 90)),
])
crunch_legs = LR(0.45, 0.05, F, 90)
motion('crunch', [lie(270, A(230, 265), crunch_legs, head=262), lie(238, A(215, 260), crunch_legs, head=225)])
motion('bicycle_crunch', [
    lie(248, A(215, 255), LA(135, 70, 90), fleg=LA(98, 98, 90), head=238),
    lie(248, A(215, 255), LA(98, 98, 90), fleg=LA(135, 70, 90), head=238),
], loop='cycle', dur=0.8)
motion('leg_raise', [lie(270, A(90, 90), LA(96, 96, 96)), lie(270, A(90, 90), LA(178, 178, 178))], dur=1.1)
def v_sit(arm, lean=20, thigh=132, shin=68): return pose((0.0, 0.12), 180 + lean, arm=arm, leg=LA(thigh, shin, 90))
motion('russian_twist', [v_sit(A(30, 30)), v_sit(A(128, 128))], dur=0.7)
motion('hollow_hold', [lie(258, A(-104, -104), LA(98, 98, 98)), lie(254, A(-108, -108), LA(102, 102, 102))], dur=1.4)
motion('v_up', [lie(270, A(-90, -90), LA(90, 90, 90)), lie(212, A(130, 130), LA(140, 140, 140))], dur=1.1)

# ---------------- CARDIO ----------------
def front(arm, legs=LA(4, 0, 90), hip_y=STAND_HIP, hip_x=0.0, torso=180):
    return pose((hip_x, hip_y), torso, arm=arm, leg=legs, farm='m', fleg='m', view='front')
spread = math.cos(math.radians(20))
motion('jumping_jacks', [front(A(4, 4)), front(A(158, 158), LA(20, 20, 90), hip_y=STAND_ANKLE + 0.87 * spread + 0.06)], view='front', dur=0.6)

def knee_frame(near_up):
    up = LA(104, 6, 90); down = LA(0, 0, 90)
    arm_a = A(60, 175); arm_b = A(-45, 20)
    if near_up:
        return pose((0, STAND_HIP), 178, arm=arm_b, leg=up, farm=arm_a, fleg=down)
    return pose((0, STAND_HIP), 178, arm=arm_a, leg=down, farm=arm_b, fleg=up)
motion('high_knees', [knee_frame(True), knee_frame(False)], loop='cycle', dur=0.5)

def box(punch_near):
    guard = A(50, 165)
    kw = dict(hip=(0.0, 0.86), torso=172, leg=LR(0.28, STAND_ANKLE, F, 90), fleg=LR(-0.30, STAND_ANKLE, B, 90))
    if punch_near:
        return pose(kw['hip'], kw['torso'], arm=A(90, 90), farm=guard, leg=kw['leg'], fleg=kw['fleg'])
    return pose(kw['hip'], 168, arm=guard, farm=A(90, 90), leg=kw['leg'], fleg=kw['fleg'])
motion('shadow_boxing', [box(True), box(False)], loop='cycle', dur=0.5)

def squat_hands(): return pose((-0.30, 0.45), 128, arm=R(0.30, 0.0, B), leg=LR(0.0, STAND_ANKLE, F, 90))
motion('burpee', [
    upright(0, STAND_HIP, 0, A(0, 0)),
    squat_hands(),
    front_support(0.55, hx=0.30),
    squat_hands(),
    upright(0, STAND_HIP + 0.28, 0, A(172, 172), leg=LR(0.0, STAND_ANKLE + 0.28, F, 130)),
], loop='cycle', dur=0.7)

def climber(near_in):
    base = front_support(0.55)
    j = joints(base)
    hip = j['hip']; an = j['an_n']
    tuck = LR(hip[0] + 0.32, 0.30, F, 60)
    straight = LR(an[0], an[1], U, 25)
    if near_in:
        return pose(hip, base[2], head=base[3], arm=R(j['wr_n'][0], 0.0, B), leg=tuck, fleg=straight)
    return pose(hip, base[2], head=base[3], arm=R(j['wr_n'][0], 0.0, B), leg=straight, fleg=tuck)
motion('mountain_climber', [climber(True), climber(False)], loop='cycle', dur=0.5)

def skater(right):
    if right:   # weight on the screen-right leg, screen-left leg swept behind
        return pose((0.30, STAND_HIP - 0.03), 170, arm=A(-30, -30), leg=LA(0, 0, 90),
                    farm=A(50, 50), fleg=LA(-28, -75, -90), view='front')
    return pose((-0.30, STAND_HIP - 0.03), 190, arm=A(-50, -50), leg=LA(28, 75, 90),
                farm=A(30, 30), fleg=LA(0, 0, -90), view='front')
# front view: near = screen-right limb
motion('skater_hops', [skater(True), skater(False)], view='front', loop='cycle', dur=0.7)

# ---------------- FULL BODY ----------------
fold = pose((0.0, STAND_HIP), 28, arm=R(0.34, 0.0, B), leg=LR(0.0, STAND_ANKLE, F, 90))
motion('inchworm', [upright(0, STAND_HIP, 0, A(170, 170)), fold, front_support(0.55, hx=0.34)], dur=1.0)

def crawl(shift):
    return pose((-0.50 + shift, 0.66), 92, arm=R(0.02 + shift, 0.0, B), leg=LR(-0.86 + shift, 0.12, F, 25),
                farm=R(0.02 - shift, 0.0, B), fleg=LR(-0.86 - shift, 0.12, F, 25))
motion('bear_crawl', [crawl(0.08), crawl(-0.08)], loop='cycle', dur=0.6)

motion('db_thruster', [upright(-0.28, 0.47, 25, A(60, 170)), upright(0, STAND_HIP, 0, A(178, 178))], held='dumbbell')

def maker_row(lift):
    base = front_support(0.55, hx=0.30)
    j = joints(base)
    sh = j['neck']
    return pose(j['hip'], base[2], head=base[3], arm=R(j['wr_n'][0], 0.0, B), leg=LR(j['an_n'][0], j['an_n'][1], U, 25),
                farm=(R(sh[0] - 0.22, sh[1] - 0.20, B) if lift else R(j['wr_n'][0], 0.0, B)))
motion('man_maker', [
    maker_row(False), maker_row(True), squat_hands(),
    upright(-0.28, 0.47, 25, A(60, 170)), upright(0, STAND_HIP, 0, A(178, 178)),
], held='dumbbell', loop='cycle', dur=0.75)

# ---------------- MOBILITY ----------------
def quad(torso, head, arm=None, farm=None):
    return pose((-0.43, 0.50), torso, head=head, arm=arm or R(0.07, 0.0, B), farm=farm, leg=LA(0, -90, -90))
motion('cat_cow', [quad(96, 30), quad(80, 135)], dur=1.6)
def child(torso, head, hy=0.28):
    return pose((-0.35, hy), torso, head=head, arm=A(92, 92), leg=LA(70, -100, -90))
motion('childs_pose', [child(82, 60), child(76, 52, 0.30)], dur=1.8)

def hip_flexor(hx, arms):
    return pose((hx, 0.47), 180, arm=arms, leg=LR(0.42, STAND_ANKLE, F, 90), fleg=LA(-20, -90, -90))
motion('hip_flexor_stretch', [hip_flexor(0.02, A(10, 10)), hip_flexor(0.16, A(172, 172))], dur=1.6)

def hamstring(torso, arm): return pose((-0.30, 0.10), torso, head=torso - 10, arm=arm, leg=LA(90, 90, 90))
motion('hamstring_stretch', [hamstring(176, A(80, 80)), hamstring(112, A(96, 96))], dur=1.6)

def thoracic(open_up):
    if open_up:
        return quad(92, 120, arm=A(150, -60), farm=R(0.07, 0.0, B))
    return quad(92, 80, arm=A(20, 200), farm=R(0.07, 0.0, B))
motion('thoracic_rotation', [thoracic(False), thoracic(True)], dur=1.4)

def wgs(torso, arm):
    return pose((0.0, 0.38), torso, head=torso, arm=arm, farm=R(0.42, 0.0, B), leg=LR(0.45, STAND_ANKLE, F, 90), fleg=LR(-0.78, 0.10, B, 20))
motion('worlds_greatest', [wgs(70, R(0.42, 0.0, B)), wgs(158, A(178, 178))], dur=1.6)

def cobra(torso): return pose((-0.05, 0.10), torso, head=torso - 6, arm=R(0.36, 0.0, B), leg=LA(-90, -90, -90))
motion('cobra_stretch', [cobra(118), cobra(140)], dur=1.8)
motion('shoulder_circles', [
    front(A(88, 88)), front(A(150, 150)), front(A(178, 178)), front(A(150, 150)), front(A(88, 88)), front(A(30, 30)),
], view='front', loop='cycle', dur=0.7)
