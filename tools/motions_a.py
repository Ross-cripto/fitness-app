from skeleton import *

M = {}
def motion(id, frames, view='side', props=(), held=None, dur=0.9, loop='pingpong'):
    M[id] = dict(frames=frames, view=view, props=list(props), held=held, dur=dur, loop=loop)

AN = (0.0, STAND_ANKLE)          # standing ankle
def stand_leg(ax=0.0, ay=STAND_ANKLE, pref=F): return LR(ax, ay, pref, 90)

def upright(hip_x, hip_y, lean, arm, leg=None, head=None, farm=None, fleg=None, ax=0.0):
    """Feet planted at ax; hip anywhere; torso leaning `lean` degrees forward of vertical."""
    return pose((hip_x, hip_y), 180 - lean, head, arm, leg or stand_leg(ax), farm, fleg)

# ---------------- LEGS ----------------
motion('bw_squat', [
    upright(0, STAND_HIP, 0, A(10, 10)),
    upright(-0.30, 0.47, 42, A(90, 90)),
])
motion('goblet_squat', [
    upright(0, STAND_HIP, 0, A(20, 150)),
    upright(-0.26, 0.45, 25, A(20, 150)),
], held='dumbbell')
motion('jump_squat', [
    upright(-0.30, 0.47, 42, A(60, 60)),
    upright(0, STAND_HIP + 0.30, 0, A(-10, -10), leg=LR(0.0, STAND_ANKLE + 0.30, F, 140)),
], dur=0.7)
def bar_on_back(hip_x, hip_y, lean):
    torso = 180 - lean
    neck = add((hip_x, hip_y), d(torso), L['torso'])
    return pose((hip_x, hip_y), torso, arm=R(neck[0] - 0.02, neck[1] - 0.04, D), leg=stand_leg())
motion('back_squat', [bar_on_back(0, STAND_HIP, 0), bar_on_back(-0.32, 0.45, 45)], held='barbell_back')
motion('calf_raise', [
    pose((0, STAND_HIP), 180, arm=A(5, 5), leg=LA(0, 0, 90)),
    pose((0, STAND_HIP + 0.10), 180, arm=A(5, 5), leg=LR(0.03, STAND_ANKLE + 0.10, F, 55)),
])
motion('wall_sit', [
    pose((-0.36, 0.55), 180, arm=A(90, 90), leg=LR(0.10, STAND_ANKLE, F, 90)),
    pose((-0.36, 0.55), 180, arm=A(80, 80), leg=LR(0.10, STAND_ANKLE, F, 90)),
], props=[dict(t='line', p=[-0.42, 0, -0.42, 1.8])], dur=1.2)
motion('reverse_lunge', [
    upright(0, STAND_HIP, 0, A(0, 0)),
    pose((0.02, 0.50), 180 - 8, arm=A(0, 0),
         leg=LR(0.20, STAND_ANKLE, F, 90), fleg=LR(-0.60, 0.13, B, 40)),
])
motion('split_squat', [
    pose((0.02, 0.90), 180 - 4, arm=A(0, 0), leg=LR(0.15, STAND_ANKLE, F, 90), fleg=LR(-0.62, 0.50, B, 150)),
    pose((0.02, 0.52), 180 - 10, arm=A(0, 0), leg=LR(0.30, STAND_ANKLE, F, 90), fleg=LR(-0.62, 0.50, B, 150)),
], props=[dict(t='rect', p=[-0.88, 0, 0.42, 0.45])])
motion('db_lunge', [
    pose((0.02, 0.88), 180, arm=A(0, 0), leg=LR(0.20, STAND_ANKLE, F, 90), fleg=LR(-0.30, STAND_ANKLE, B, 90)),
    pose((0.02, 0.50), 180 - 5, arm=A(0, 0), leg=LR(0.42, STAND_ANKLE, F, 90), fleg=LR(-0.50, 0.13, B, 40)),
], held='dumbbell')
motion('glute_bridge', [
    pose((-0.10, 0.10), 262, head=270, arm=A(90, 90), leg=LR(0.45, 0.05, F, 90)),
    pose((0.05, 0.45), 227, head=270, arm=A(90, 90), leg=LR(0.75, 0.05, F, 90)),
])
motion('single_leg_bridge', [
    pose((-0.10, 0.10), 262, head=270, arm=A(90, 90), leg=LR(0.45, 0.05, F, 90), fleg=LA(90, 90, 90)),
    pose((0.05, 0.45), 227, head=270, arm=A(90, 90), leg=LR(0.75, 0.05, F, 90), fleg=LA(133, 133, 133)),
])
motion('db_rdl', [
    upright(0, STAND_HIP, 0, A(0, 0)),
    pose((-0.28, 0.84), 90, head=100, arm=A(0, 0), leg=LR(0.0, STAND_ANKLE, F, 90)),
], held='dumbbell')
motion('deadlift', [
    pose((-0.22, 0.62), 130, head=140, arm=A(15, 5), leg=LR(0.0, STAND_ANKLE, F, 90)),
    upright(0, STAND_HIP, 0, A(0, 0)),
], held='barbell')
motion('leg_press', [
    pose((-0.35, 0.30), 235, head=235, arm=A(60, 100), leg=LR(0.05, 0.55, F, 100)),
    pose((-0.35, 0.30), 235, head=235, arm=A(60, 100), leg=LR(0.28, 0.86, F, 100)),
], props=[dict(t='line', p=[-1.0, 0.05, -0.30, 0.62]), dict(t='line', p=[-0.10, 0.20, 0.60, 1.05])])
