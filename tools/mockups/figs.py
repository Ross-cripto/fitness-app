"""SVG rendering of the exact same poses the app animates (reads Momentum/Design/MotionData.swift)."""
import json, math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from skeleton import joints, L

_src = open(os.path.join(os.path.dirname(__file__), '..', '..', 'Momentum', 'Design', 'MotionData.swift')).read()
DATA = json.loads(_src[_src.index('{\n"'):_src.rindex('}\n"""#') + 1])


def fig_svg(ex_id, w, h, frame=1, ghost=True, figure='#fff', accent='#ff2d6b', ground=True, stroke=1.0, ghost_opacity=0.32):
    m = DATA[ex_id]
    x0, x1, y0, y1 = m['bounds']
    s = min(w / (x1 - x0), h / (y1 - y0))
    ox = (w - (x1 - x0) * s) / 2 - x0 * s
    oy = (h + (y1 - y0) * s) / 2 + y0 * s
    P = lambda p: (ox + p[0] * s, oy - p[1] * s)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">']
    if ground:
        a, b = P((x0, 0)), P((x1, 0))
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{figure}" stroke-opacity=".22" stroke-width="1.5" stroke-dasharray="4 5" stroke-linecap="round"/>')
    for pr in m['props']:
        p = pr['p']
        if pr['t'] == 'rect':
            a = P((p[0], p[1] + p[3]))
            out.append(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{p[2]*s:.1f}" height="{p[3]*s:.1f}" rx="3" fill="{figure}" fill-opacity=".2"/>')
        elif pr['t'] == 'line':
            a, b = P((p[0], p[1])), P((p[2], p[3]))
            out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="{figure}" stroke-opacity=".35" stroke-width="{0.055*s*.7:.1f}" stroke-linecap="round"/>')
    limb = max(2.5, 0.055 * s) * stroke

    def draw(fr, op):
        j = joints(fr, m['view'])
        def seg(keys, color, width, o):
            pts = ' '.join(f'{P(j[k])[0]:.1f},{P(j[k])[1]:.1f}' for k in keys)
            out.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-opacity="{o}" stroke-width="{width:.1f}" stroke-linecap="round" stroke-linejoin="round"/>')
        seg(['sh_f', 'el_f', 'wr_f'], figure, limb, .5 * op); seg(['hp_f', 'kn_f', 'an_f', 'to_f'], figure, limb, .5 * op)
        if m['view'] == 'front':
            seg(['sh_n', 'sh_f'], figure, limb, op); seg(['hp_n', 'hp_f'], figure, limb, op)
        seg(['hip', 'neck'], figure, limb * 1.35, op)
        seg(['sh_n', 'el_n', 'wr_n'], figure, limb, op); seg(['hp_n', 'kn_n', 'an_n', 'to_n'], figure, limb, op)
        held = m.get('held')
        if held == 'dumbbell':
            for side, a in (('n', fr[5]), ('f', fr[7])):
                x, y = P(j['wr_' + side]); r = math.radians(a); hh = 0.075 * s
                out.append(f'<line x1="{x-math.cos(r)*hh:.1f}" y1="{y+math.sin(r)*hh:.1f}" x2="{x+math.cos(r)*hh:.1f}" y2="{y-math.sin(r)*hh:.1f}" stroke="{accent}" stroke-opacity="{op}" stroke-width="{limb*1.25:.1f}" stroke-linecap="round"/>')
        elif held in ('barbell', 'barbell_back'):
            x, y = P(j['wr_n']) if held == 'barbell' else P(j['neck']); r = 0.105 * s
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{accent}" fill-opacity="{op}"/><circle cx="{x:.1f}" cy="{y:.1f}" r="{r*.38:.1f}" fill="{figure}" fill-opacity="{op}"/>')
        hx, hy = P(j['head'])
        out.append(f'<circle cx="{hx:.1f}" cy="{hy:.1f}" r="{L["headR"]*s:.1f}" fill="{figure}" fill-opacity="{op}"/>')

    frames = m['frames']
    if ghost and len(frames) > 1:
        draw(frames[0], ghost_opacity)
    draw(frames[min(frame, len(frames) - 1)], 1.0)
    out.append('</svg>')
    return ''.join(out)


if __name__ == '__main__':
    print(fig_svg('bw_squat', 200, 150)[:200])
