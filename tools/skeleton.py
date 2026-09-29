"""Skeleton math shared (by hand) with Momentum/Design/FigureView.swift.

World coordinates: x to the right, y UP, ground at y = 0. A segment angle is
measured from "straight down": 0 = down, 90 = toward +x, 180 = up, -90 = toward -x.
"""
import math

L = dict(torso=0.50, neck=0.16, upper=0.29, fore=0.27, thigh=0.44, shin=0.43, foot=0.14, headR=0.10)
SW = 0.17   # half shoulder width (front view)
HW = 0.10   # half hip width (front view)
STAND_ANKLE = 0.05
STAND_HIP = STAND_ANKLE + L['thigh'] + L['shin']

F = (1, 0); B = (-1, 0); U = (0, 1); D = (0, -1)


def d(a):
    r = math.radians(a)
    return (math.sin(r), -math.cos(r))


def add(p, v, s=1.0):
    return (p[0] + v[0] * s, p[1] + v[1] * s)


def ang(v):
    return math.degrees(math.atan2(v[0], -v[1]))


def ik(root, target, l1, l2, pref):
    dx, dy = target[0] - root[0], target[1] - root[1]
    dist = math.hypot(dx, dy)
    dist = max(abs(l1 - l2) + 1e-4, min(l1 + l2 - 1e-4, dist))
    cosA = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    a = math.acos(max(-1, min(1, cosA)))
    base = math.atan2(dy, dx)
    best = None
    for s in (1, -1):
        j = (root[0] + l1 * math.cos(base + s * a), root[1] + l1 * math.sin(base + s * a))
        mid = ((root[0] + target[0]) / 2, (root[1] + target[1]) / 2)
        score = (j[0] - mid[0]) * pref[0] + (j[1] - mid[1]) * pref[1]
        if best is None or score > best[0]:
            best = (score, j)
    j = best[1]
    a1 = ang((j[0] - root[0], j[1] - root[1]))
    reach = (root[0] + dx / math.hypot(dx, dy) * dist, root[1] + dy / math.hypot(dx, dy) * dist) if math.hypot(dx, dy) else target
    a2 = ang((reach[0] - j[0], reach[1] - j[1]))
    return a1, a2


# ---- limb specs -------------------------------------------------------------
def A(a1, a2): return ('a', a1, a2)
def R(x, y, pref=B): return ('r', x, y, pref)
def LA(t, s, f=90): return ('a', t, s, f)
def LR(x, y, pref=F, f=90): return ('r', x, y, pref, f)


def mirror_spec(spec):
    if spec[0] == 'a':
        return ('a',) + tuple(-v for v in spec[1:])
    if spec[0] == 'r':
        rest = spec[3:]
        pref = (-spec[3][0], spec[3][1]) if len(spec) > 3 else B
        if len(spec) == 4:   # arm
            return ('r', -spec[1], spec[2], pref)
        return ('r', -spec[1], spec[2], pref, -spec[4])
    return spec


def pose(hip, torso, head=None, arm=A(0, 0), leg=LA(0, 0), farm=None, fleg=None, view='side'):
    head = torso if head is None else head
    neck = add(hip, d(torso), L['torso'])
    if view == 'side':
        sh_n = sh_f = neck
        hp_n = hp_f = hip
    else:
        sh_n = (neck[0] + SW, neck[1]); sh_f = (neck[0] - SW, neck[1])
        hp_n = (hip[0] + HW, hip[1]); hp_f = (hip[0] - HW, hip[1])

    def arm_of(spec, root):
        if spec[0] == 'a':
            return spec[1], spec[2]
        return ik(root, (spec[1], spec[2]), L['upper'], L['fore'], spec[3])

    def leg_of(spec, root):
        if spec[0] == 'a':
            return spec[1], spec[2], spec[3]
        a1, a2 = ik(root, (spec[1], spec[2]), L['thigh'], L['shin'], spec[3])
        return a1, a2, spec[4]

    na = arm_of(arm, sh_n)
    nl = leg_of(leg, hp_n)
    if farm == 'm':
        fa = arm_of(mirror_spec(arm), sh_f)
    elif farm is None:
        fa = na
    else:
        fa = arm_of(farm, sh_f)
    if fleg == 'm':
        fl = leg_of(mirror_spec(leg), hp_f)
    elif fleg is None:
        fl = nl
    else:
        fl = leg_of(fleg, hp_f)
    return [hip[0], hip[1], torso, head, na[0], na[1], fa[0], fa[1], nl[0], nl[1], nl[2], fl[0], fl[1], fl[2]]


def joints(fr, view='side'):
    hx, hy, tor, head, na1, na2, fa1, fa2, nt, ns, nf, ft, fs, ff = fr
    hip = (hx, hy)
    neck = add(hip, d(tor), L['torso'])
    headc = add(neck, d(head), L['neck'])
    if view == 'side':
        sh_n = sh_f = neck; hp_n = hp_f = hip
    else:
        sh_n = (neck[0] + SW, neck[1]); sh_f = (neck[0] - SW, neck[1])
        hp_n = (hx + HW, hy); hp_f = (hx - HW, hy)
    j = {'hip': hip, 'neck': neck, 'head': headc, 'sh_n': sh_n, 'sh_f': sh_f, 'hp_n': hp_n, 'hp_f': hp_f}
    j['el_n'] = add(sh_n, d(na1), L['upper']); j['wr_n'] = add(j['el_n'], d(na2), L['fore'])
    j['el_f'] = add(sh_f, d(fa1), L['upper']); j['wr_f'] = add(j['el_f'], d(fa2), L['fore'])
    j['kn_n'] = add(hp_n, d(nt), L['thigh']); j['an_n'] = add(j['kn_n'], d(ns), L['shin']); j['to_n'] = add(j['an_n'], d(nf), L['foot'])
    j['kn_f'] = add(hp_f, d(ft), L['thigh']); j['an_f'] = add(j['kn_f'], d(fs), L['shin']); j['to_f'] = add(j['an_f'], d(ff), L['foot'])
    return j
