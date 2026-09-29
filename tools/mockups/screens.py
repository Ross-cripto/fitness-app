"""HTML/CSS renderings of the app's screens, laid out like the SwiftUI views and driven by the real pose data."""
from figs import fig_svg

PINK, GREEN, BLUE, AMBER, HEALTH = '#ff2d6b', '#34c759', '#2033d9', '#ff9f0a', '#ff3b5c'
GRAD = {  # MuscleGroup.colors from Theme.swift
    'legs': ('#4a3a2a', '#14110e'), 'chest': ('#5b2a3a', '#14121a'), 'back': ('#2a3f5f', '#10131a'),
    'shoulders': ('#3d2f5c', '#12101a'), 'arms': ('#5c3a2a', '#15100e'), 'core': ('#2a5c4f', '#0e1714'),
    'cardio': ('#6b2438', '#150c10'), 'fullBody': ('#3a3f52', '#0f1015'), 'mobility': ('#2a4f5c', '#0d1519'),
}
I = {  # icons (24px grid)
    'flame': '<path d="M12 2c1 3.5 5 5.5 5 10.5A5 5 0 0 1 7 13c0-2 1-3 2-4-.3 2 .7 3 2 3 0-3-.5-6 1-10z" fill="currentColor"/>',
    'timer': '<circle cx="12" cy="13" r="8" fill="none" stroke="currentColor" stroke-width="2.6"/><path d="M12 8v5l3 2M9 2h6" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>',
    'walk': '<circle cx="13" cy="4.5" r="2.2" fill="currentColor"/><path d="M12 8l-3 3.5 1 3-2.5 6M12 8l3 3 3 1M12 8l-1 5 3.5 3v5" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    'check': '<path d="M5 12.5l4.5 4.5L19 7" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>',
    'chev': '<path d="M9 5l7 7-7 7" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>',
    'swap': '<path d="M4 8h14m-4-4l4 4-4 4M20 16H6m4-4l-4 4 4 4" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
    'x': '<path d="M6 6l12 12M18 6L6 18" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>',
    'chart': '<circle cx="12" cy="12" r="9" fill="currentColor"/><path d="M12 3v9h9" fill="none" stroke="#fff" stroke-width="2" opacity=".9"/>',
    'search': '<circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="currentColor" stroke-width="2.6"/><path d="M15.5 15.5L21 21" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>',
    'heart': '<path d="M12 21s-8-5.2-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.8-8 11-8 11z" fill="currentColor"/>',
    'scale': '<rect x="3.5" y="3.5" width="17" height="17" rx="5" fill="none" stroke="currentColor" stroke-width="2.4"/><path d="M8 10.5a5.5 5.5 0 0 1 8 0M12 10.6l1.8-2" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round"/>',
    'trophy': '<path d="M7 3h10v6a5 5 0 0 1-10 0V3zM7 5H3v2a4 4 0 0 0 4 4M17 5h4v2a4 4 0 0 1-4 4M9 21h6M12 14v7" fill="currentColor" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
    'play': '<rect x="2" y="5" width="20" height="14" rx="4" fill="currentColor"/><path d="M10 9l5 3-5 3z" fill="#fff"/>',
    'up': '<path d="M7 17L17 7M8 7h9v9" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
    'hare': '<path d="M4 16c0-4 4-6 8-6s8 2 8 6-3 4-8 4-8 0-8-4zM14 10c0-4 1-7 3-7s1 5-1 8" fill="currentColor"/>',
    'thumb': '<path d="M7 11v9H4v-9h3zm2 9V11l4-8c1.5 0 2.5 1 2.2 2.5L15 9h5a2 2 0 0 1 2 2.4l-1.3 6A2 2 0 0 1 18.8 19H9z" fill="currentColor"/>',
}


def ic(name, size=20, color='currentColor', extra=''):
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" style="color:{color};flex:none;{extra}">{I[name]}</svg>'


CSS = """
@font-face{font-family:Inter;font-weight:400;src:url(fonts/400.ttf)}
@font-face{font-family:Inter;font-weight:500;src:url(fonts/500.ttf)}
@font-face{font-family:Inter;font-weight:600;src:url(fonts/600.ttf)}
@font-face{font-family:Inter;font-weight:700;src:url(fonts/700.ttf)}
@font-face{font-family:Inter;font-weight:800;src:url(fonts/800.ttf)}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:Inter,-apple-system,sans-serif;background:transparent;-webkit-font-smoothing:antialiased}
.row{display:flex;align-items:center}
.phone{width:433px;height:892px;border-radius:66px;background:#0b0b0d;padding:20px;position:relative;box-shadow:inset 0 0 0 2px #303035,0 0 0 1.5px #1c1c1f}
.screen{width:393px;height:852px;border-radius:47px;overflow:hidden;position:relative;background:#fff;color:#000}
.screen.dark{background:#000;color:#fff}
.island{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:122px;height:35px;border-radius:20px;background:#000;z-index:60}
.status{position:absolute;top:0;left:0;right:0;height:56px;display:flex;justify-content:space-between;align-items:center;padding:8px 32px 0 48px;font-weight:600;font-size:16.5px;z-index:55}
.status .r{display:flex;gap:6px;align-items:center}
.hb{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:138px;height:5px;border-radius:3px;background:#000;z-index:60}
.dark .hb{background:#fff}
.tabbar{position:absolute;left:0;right:0;bottom:0;height:86px;background:#fff;border-top:1px solid #e3e3e8;display:flex;justify-content:space-around;padding-top:13px;z-index:30}
.pill{display:inline-block;background:__PINK__;color:#fff;font-weight:700;font-size:16px;padding:14px 34px;border-radius:99px;box-shadow:0 8px 16px rgba(255,45,107,.35)}
.card{background:#fff;border-radius:20px;padding:18px;box-shadow:0 4px 18px rgba(0,0,0,.09);border:1px solid rgba(0,0,0,.03)}
.gcard{position:relative;height:136px;overflow:hidden;color:#fff}
.gcard .fig{position:absolute;right:0;top:2px;opacity:.6}
.gcard .t{position:absolute;left:20px;bottom:15px}
.gcard .lab{font-size:11px;font-weight:600;color:__PINK__}
.gcard .name{font-size:19px;font-weight:600;margin:2px 0}
.gcard .meta{font-size:12px;font-weight:500;color:rgba(255,255,255,.65);display:flex;gap:10px}
.gcard .chev{position:absolute;right:20px;bottom:17px;color:rgba(255,255,255,.5)}
.pillstat{display:flex;align-items:baseline;gap:5px}
.pillstat b{font-weight:700;letter-spacing:-.5px}
.pillstat span{color:#8e8e93;font-weight:500}
.dark .pillstat span{color:rgba(255,255,255,.6)}
.stepper{display:inline-flex;background:rgba(120,120,128,.16);border-radius:9px;overflow:hidden;height:32px}
.stepper i{display:block;width:47px;text-align:center;line-height:30px;font-style:normal;font-size:20px;font-weight:400}
.stepper i+i{border-left:1px solid rgba(60,60,67,.25)}
.dark .stepper{background:rgba(120,120,128,.32)}
.tog{width:51px;height:31px;border-radius:99px;background:#34c759;position:relative;flex:none}
.tog:after{content:"";position:absolute;right:2px;top:2px;width:27px;height:27px;border-radius:50%;background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.25)}
.tog.off{background:#e5e5ea}.tog.off:after{right:auto;left:2px}
""".replace("__PINK__", PINK)


def status_bar(dark=False):
    c = '#fff' if dark else '#000'
    return f'''<div class="status" style="color:{c}"><span>9:41</span><span class="r">
<svg width="18" height="12" viewBox="0 0 18 12" fill="{c}"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5" width="3" height="7" rx="1"/><rect x="10" y="2.5" width="3" height="9.5" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
<svg width="17" height="12" viewBox="0 0 17 12" fill="none" stroke="{c}" stroke-width="2" stroke-linecap="round"><path d="M1 4.2a11 11 0 0 1 15 0M3.5 7a7.3 7.3 0 0 1 10 0"/><circle cx="8.5" cy="10" r="1.3" fill="{c}" stroke="none"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="22" height="12" rx="3.5" fill="none" stroke="{c}" opacity=".45"/><rect x="2" y="2" width="19" height="9" rx="2.2" fill="{c}"/><rect x="24" y="4.2" width="2" height="4.6" rx="1" fill="{c}" opacity=".5"/></svg></span></div>'''


def phone(inner, dark=False, tabbar=None):
    tb = ''
    if tabbar is not None:
        icons = [('chart', 0), ('flame', 1), ('search', 2)]
        tb = '<div class="tabbar">' + ''.join(ic(n, 27, PINK if i == tabbar else '#8e8e93') for n, i in icons) + '</div>'
    return f'''<div class="phone"><div class="screen {'dark' if dark else ''}"><div class="island"></div>{status_bar(dark)}{inner}{tb}<div class="hb"></div></div></div>'''


def stat(icon, value, unit, color, size=26, dark=False):
    return f'<div class="pillstat">{ic(icon, size-4, color)}<b style="font-size:{size}px">{value}</b><span style="font-size:{size/2+1:.0f}px">{unit}</span></div>'


def gcard(label, name, mins, cal, muscle, ex_id, frame=1):
    a, b = GRAD[muscle]
    return f'''<div class="gcard" style="background:linear-gradient(135deg,{a},{b})"><div class="fig">{fig_svg(ex_id, 230, 132, frame=frame, ghost=True, ground=False)}</div>
<div class="t"><div class="lab">{label}</div><div class="name">{name}</div><div class="meta"><span>{mins} min</span><span>{cal} cal</span></div></div><div class="chev">{ic('chev', 15)}</div></div>'''


def week_strip(states):
    days = 'MTWTFSS'
    out = ''
    for d, s in zip(days, states):
        today = s.endswith('*')
        s = s.rstrip('*')
        fill = PINK if s == 'done' else 'transparent'
        ring = PINK if s in ('done', 'plan') else 'rgba(0,0,0,.12)'
        check = ic('check', 14, '#fff') if s == 'done' else ''
        out += f'''<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px"><span style="font-size:12px;font-weight:{700 if today else 500};color:{PINK if today else '#8e8e93'}">{d}</span>
<div style="width:28px;height:28px;border-radius:50%;background:{fill};border:2px solid {ring};display:flex;align-items:center;justify-content:center">{check}</div></div>'''
    return f'<div style="display:flex;padding:0 12px 16px">{out}</div>'


# ---------------------------------------------------------------- screens
def home():
    return phone(f'''<div style="padding:62px 0 0">
<div class="row" style="justify-content:space-between;align-items:flex-start;padding:16px 20px 0">
 <div><div style="position:relative;display:inline-block;font-size:64px;font-weight:800;letter-spacing:-2px;line-height:1">12<i style="position:absolute;right:-16px;top:6px;width:11px;height:11px;border-radius:50%;background:{PINK}"></i></div>
 <div style="font-size:12px;font-weight:500;color:#8e8e93;margin-top:4px">workout streak</div></div>
 <div style="text-align:right;font-size:20px;color:#8e8e93;line-height:1.25;margin-top:10px">September 29,<br>2026</div></div>
<div style="padding:12px 20px 0;font-size:17px;font-weight:500;line-height:1.3">Today's workout is scheduled. You have <b style="font-weight:700">1 workout</b> session.</div>
<div class="row" style="gap:14px;padding:16px 20px">{stat('flame', '289', 'cal', PINK, 24)}{stat('timer', '44', 'min', GREEN, 24)}{stat('walk', '6,482', 'steps', AMBER, 24)}</div>
{week_strip(['done', 'plan*', 'rest', 'plan', 'plan', 'rest', 'rest'])}
<div style="display:flex;flex-direction:column;gap:2px">
{gcard("Today's Workout", 'Lower Body', 44, 289, 'legs', 'goblet_squat', 1)}
{gcard('Quick Workout', 'Short Workout', 11, 96, 'cardio', 'burpee', 1)}
{gcard('Quick Workout', 'Wall Workouts', 32, 180, 'fullBody', 'wall_pushup', 1)}
{gcard('Quick Workout', 'Mobility &amp; Stretch', 10, 41, 'mobility', 'hip_flexor_stretch', 1)}
</div></div>''', tabbar=1)


def detail_row(ex_id, name, sub, mins, cal, muscle):
    a, b = GRAD[muscle]
    return f'''<div class="row" style="gap:12px;margin-bottom:14px"><div style="width:76px;height:56px;border-radius:8px;background:linear-gradient(135deg,{a},{b});overflow:hidden;display:flex;align-items:center;justify-content:center">{fig_svg(ex_id, 68, 48, frame=1, ghost=False, ground=False)}</div>
<div style="flex:1"><div style="font-size:15px;font-weight:600">{name}</div><div style="font-size:12px;font-weight:500;color:rgba(255,255,255,.6);margin-top:3px">{sub}</div><div style="font-size:11px;color:rgba(255,255,255,.4);margin-top:3px">{mins} min · {cal} cal</div></div>
<div style="width:40px;text-align:center;color:rgba(255,255,255,.75)">{ic('swap', 18)}</div></div>'''


def detail():
    a, b = GRAD['legs']
    rows = [
        ('db_lunge', 'Dumbbell Walking Lunge', '3 × 10 · 11 kg', 6, 46, 'legs'),
        ('goblet_squat', 'Goblet Squat', '3 × 10 · 18 kg', 6, 44, 'legs'),
        ('db_rdl', 'Dumbbell Romanian Deadlift', '3 × 10 · 14 kg', 6, 41, 'legs'),
        ('jump_squat', 'Jump Squat', '3 × 10', 5, 52, 'legs'),
        ('plank', 'Plank', '3 × 45s', 5, 26, 'core'),
        ('mountain_climber', 'Mountain Climber', '3 × 40s', 5, 55, 'cardio'),
    ]
    return phone(f'''<div style="position:absolute;inset:0;background:#000"></div>
<div style="position:absolute;left:0;right:0;top:0;height:520px;background:linear-gradient(180deg,{a},#000 78%)"></div>
<div style="position:absolute;right:10px;top:58px;opacity:.55">{fig_svg('goblet_squat', 210, 160, frame=1, ghost=True, ground=False)}</div>
<div style="position:absolute;left:14px;top:62px;color:#fff">{ic('chev', 26, '#fff', 'transform:rotate(180deg)')}</div>
<div style="position:absolute;left:20px;right:20px;top:236px">
 <div class="row" style="gap:20px;margin-bottom:8px">{stat('flame', '289', 'cal', PINK, 20)}{stat('timer', '44', 'min', GREEN, 20)}</div>
 <div style="font-size:44px;font-weight:700;letter-spacing:-1px;line-height:1.05">Lower Body</div>
 <div style="font-size:15px;font-weight:500;color:rgba(255,255,255,.65);margin:2px 0 14px">Quads, glutes, hamstrings</div>
 <div style="font-size:11px;font-weight:600;color:rgba(255,255,255,.6);margin-bottom:8px">Set 1</div>
 {''.join(detail_row(*r) for r in rows)}</div>
<div style="position:absolute;left:0;right:0;bottom:0;height:130px;background:linear-gradient(180deg,transparent,#000 60%)"></div>
<div style="position:absolute;left:0;right:0;bottom:34px;text-align:center"><span class="pill">Start Workout</span></div>''', dark=True)


def player():
    a, b = GRAD['legs']

    def setrow(n, reps, kg, done, active=False):
        circ = f'background:{GREEN}' if done else 'background:rgba(255,255,255,.12)'
        icon = ic('check', 18, '#fff') if done else ic('check', 18, 'rgba(255,255,255,.55)')
        return f'''<div class="row" style="gap:14px;padding:14px;border-radius:16px;background:rgba(255,255,255,{'.09' if active else '.06'});margin-bottom:10px;{'outline:1.5px solid rgba(255,45,107,.6)' if active else ''}">
<div style="width:30px;height:30px;border-radius:50%;background:rgba(255,255,255,.1);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:15px">{n}</div>
<div style="flex:1;display:flex;flex-direction:column;gap:8px">
 <div class="row" style="justify-content:space-between;font-size:16px;font-weight:600">{reps} reps<span class="stepper"><i>−</i><i>+</i></span></div>
 <div class="row" style="justify-content:space-between;font-size:14px;font-weight:500;color:rgba(255,255,255,.7)">{kg}<span class="stepper"><i>−</i><i>+</i></span></div></div>
<div style="width:46px;height:46px;border-radius:50%;{circ};display:flex;align-items:center;justify-content:center">{icon}</div></div>'''
    return phone(f'''<div style="padding:62px 20px 0;height:706px;overflow:hidden">
 <div class="row" style="justify-content:space-between"><div style="width:40px;height:40px;border-radius:50%;background:rgba(255,255,255,.1);display:flex;align-items:center;justify-content:center">{ic('x', 16, '#fff')}</div>
 <span style="font-size:14px;font-weight:600;color:rgba(255,255,255,.7)">Exercise 2 of 6</span><span style="width:40px"></span></div>
 <div style="height:6px;border-radius:9px;background:rgba(255,255,255,.1);margin:12px 0 18px"><div style="width:29%;height:100%;border-radius:9px;background:{PINK}"></div></div>
 <div style="height:216px;border-radius:20px;background:linear-gradient(135deg,{a},{b});display:flex;align-items:center;justify-content:center;margin-bottom:12px">{fig_svg('goblet_squat', 330, 190, frame=1, ghost=True)}</div>
 <div style="font-size:26px;font-weight:700">Goblet Squat</div>
 <div style="font-size:14px;font-weight:500;color:rgba(255,255,255,.6);margin:2px 0 10px">Legs · 3 × 10</div>
 <div class="row" style="justify-content:space-between;font-size:14px;font-weight:600;margin-bottom:12px"><span>How to do it</span><span style="color:{PINK}">{ic('chev', 14, PINK, 'transform:rotate(90deg)')}</span></div>
 {setrow(1, 10, '18 kg', True)}{setrow(2, 10, '18 kg', False, True)}{setrow(3, 10, '18 kg', False)}</div>
<div style="position:absolute;left:0;right:0;bottom:90px;height:56px;background:#1c1c1e" class="row"><div class="row" style="width:100%;padding:0 20px;gap:12px">{ic('timer', 20, GREEN)}<span style="font-size:18px;font-weight:700">Rest  0:48</span><span style="flex:1"></span><span style="font-size:14px;font-weight:600">+15s</span><span style="font-size:14px;font-weight:600;color:{PINK};margin-left:8px">Skip</span></div></div>
<div class="row" style="position:absolute;left:0;right:0;bottom:24px;justify-content:space-between;padding:0 20px"><span style="font-size:16px;font-weight:600;color:rgba(255,255,255,.7)">Previous</span><span class="pill" style="background:#4d4d4f;box-shadow:none">Next exercise</span></div>''', dark=True)


def progress_top():
    bars = [0, 0, 44, 0, 38, 0, 0, 46, 0, 0, 41, 0, 52, 0, 0, 44, 0, 40, 0, 0, 47, 0, 0, 43, 0, 50, 0, 44]
    bar_svg = ''.join(f'<rect x="{i*11+2}" y="{46-(v/52*44):.1f}" width="5" height="{max(2,v/52*44):.1f}" rx="2" fill="{GREEN}" opacity="{1 if v else .25}"/>' for i, v in enumerate(bars))
    chips = ''.join(f'<span style="font-size:15px;font-weight:500;color:#8e8e93;padding:8px 9px">{d}</span>' for d in (24, 25, 26, 27, 28))
    return phone(f'''<div style="padding:62px 20px 0">
 <div class="row" style="justify-content:space-between"><span style="font-size:30px;font-weight:700;letter-spacing:-.5px">Your Progress</span>
 <div style="width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg,{PINK},#ff7a45);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center">A</div></div>
 <div class="row" style="margin:14px 0 18px;gap:0;overflow:hidden">{chips}<span style="background:{BLUE};color:#fff;font-size:15px;font-weight:700;padding:8px 14px;border-radius:10px;margin-left:4px">Today, 29 Sep</span></div>
 <div class="card" style="margin-bottom:16px">
  <div style="width:42px;height:42px;border-radius:50%;background:{PINK};display:flex;align-items:center;justify-content:center">{ic('flame', 20, '#fff')}</div>
  <div style="font-size:17px;font-weight:600;color:{PINK};margin:12px 0 6px">Calorie</div>
  <div style="font-size:14px;line-height:1.3;margin-bottom:10px">Well done! You're well on your way with your calorie burn this week.</div>
  <div class="row" style="justify-content:space-between;align-items:baseline"><div style="font-size:30px;font-weight:700;letter-spacing:-.5px"><span style="color:#8e8e93">812</span><span style="color:{PINK}">/1160 Cal.</span></div><span style="font-size:11px;color:#8e8e93">70% Completed</span></div>
  <div style="height:6px;border-radius:9px;background:rgba(0,0,0,.08);margin-top:12px"><div style="width:70%;height:100%;border-radius:9px;background:{PINK}"></div></div></div>
 <div class="card">
  <div style="width:42px;height:42px;border-radius:50%;background:{GREEN};display:flex;align-items:center;justify-content:center">{ic('timer', 20, '#fff')}</div>
  <div style="font-size:17px;font-weight:600;color:{GREEN};margin:12px 0 6px">Duration</div>
  <div style="font-size:14px;line-height:1.3;margin-bottom:10px">Well done! You're well on your way with your training time this week.</div>
  <div class="row" style="justify-content:space-between;align-items:baseline"><div style="font-size:30px;font-weight:700;letter-spacing:-.5px"><span style="color:#8e8e93">118</span><span style="color:{GREEN}">/176 mins.</span></div><span style="font-size:11px;color:#8e8e93">67% Completed</span></div>
  <svg width="313" height="48" style="margin-top:10px">{bar_svg}</svg></div></div>''', tabbar=0)


def progress_scrolled():
    pts = [(0, 74.0), (1, 73.6), (2, 73.9), (3, 73.1), (4, 72.8), (5, 72.9), (6, 72.2), (7, 72.0)]
    xy = ' '.join(f'{12+i*41:.0f},{80-(v-71.5)/3*70:.0f}' for i, v in pts)
    dots = ''.join(f'<circle cx="{12+i*41}" cy="{80-(v-71.5)/3*70:.0f}" r="3.5" fill="{BLUE}"/>' for i, v in pts)
    return phone(f'''<div style="padding:62px 20px 0">
 <div class="card" style="margin-bottom:16px">
  <div class="row" style="justify-content:space-between"><div style="width:42px;height:42px;border-radius:50%;background:{BLUE};display:flex;align-items:center;justify-content:center">{ic('scale', 22, '#fff')}</div><span style="font-size:14px;font-weight:600;color:{BLUE}">Log weight</span></div>
  <div style="font-size:17px;font-weight:600;color:{BLUE};margin:12px 0 4px">Body weight</div>
  <div class="row" style="justify-content:space-between;align-items:baseline"><span style="font-size:30px;font-weight:700;letter-spacing:-.5px">72 kg</span><span style="font-size:12px;color:#8e8e93">-2 kg since start</span></div>
  <svg width="313" height="96" style="margin-top:8px"><polyline points="{xy}" fill="none" stroke="{BLUE}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>{dots}</svg></div>
 <div class="card" style="margin-bottom:16px">
  <div style="width:42px;height:42px;border-radius:50%;background:{HEALTH};display:flex;align-items:center;justify-content:center">{ic('heart', 21, '#fff')}</div>
  <div style="font-size:17px;font-weight:600;color:{HEALTH};margin:12px 0 10px">Apple Health</div>
  <div class="row" style="gap:24px">{stat('walk', '6,482', 'steps today', AMBER, 20)}{stat('flame', '412', 'active cal', PINK, 20)}</div>
  <div style="font-size:13px;color:#8e8e93;margin-top:10px;line-height:1.35">Workouts and body weight you log here are saved to Apple Health.</div></div>
 <div class="card" style="margin-bottom:16px">
  <div style="width:42px;height:42px;border-radius:50%;background:{AMBER};display:flex;align-items:center;justify-content:center">{ic('trophy', 21, '#fff')}</div>
  <div style="font-size:17px;font-weight:600;color:{AMBER};margin:12px 0 10px">Personal records</div>
  {''.join(f'<div class="row" style="justify-content:space-between;padding:4px 0"><span style="font-size:15px;font-weight:500">{n}</span><b style="font-size:15px">{v}</b></div>' for n, v in [('Barbell Deadlift', '82.5 kg'), ('Goblet Squat', '22 kg'), ('Incline Dumbbell Press', '18 kg'), ('One-Arm Dumbbell Row', '20 kg')])}</div>
 <div style="font-size:17px;font-weight:600;margin:6px 0 10px">Today's sessions</div>
 <div class="row" style="justify-content:space-between;padding:14px;border-radius:14px;background:#f2f2f7"><div><div style="font-size:15px;font-weight:600">Lower Body</div><div style="font-size:12px;color:#8e8e93;margin-top:2px">7:12 AM</div></div><span style="font-size:13px;font-weight:500;color:#8e8e93">46 min · 301 cal</span></div></div>''', tabbar=0)


def sheet():
    a, b = GRAD['chest']
    return phone(f'''<div style="position:absolute;inset:0;background:#7d7d80"></div>
<div style="position:absolute;left:0;right:0;top:64px;bottom:0;background:#f2f2f7;border-radius:38px 38px 0 0;padding:16px 20px">
 <div class="row" style="justify-content:flex-end;margin-bottom:8px"><span style="font-size:17px;font-weight:600;color:{PINK}">Done</span></div>
 <div style="height:220px;border-radius:20px;background:linear-gradient(135deg,{a},{b});display:flex;align-items:center;justify-content:center">{fig_svg('db_incline_press', 320, 200, frame=1, ghost=True)}</div>
 <div style="font-size:28px;font-weight:700;margin:16px 0 8px;letter-spacing:-.4px">Incline Dumbbell Press</div>
 <div class="row" style="gap:8px;margin-bottom:16px">{''.join(f'<span style="font-size:12px;font-weight:600;padding:5px 10px;border-radius:99px;background:rgba(0,0,0,.07)">{t}</span>' for t in ('Chest', 'Dumbbells', 'Intermediate'))}</div>
 <div style="font-size:17px;font-weight:600;margin-bottom:10px">How to</div>
 {''.join(f'<div class="row" style="gap:12px;align-items:flex-start;margin-bottom:9px"><span style="width:24px;height:24px;border-radius:50%;background:{PINK};color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;flex:none">{i+1}</span><span style="font-size:15px;line-height:1.3">{t}</span></div>' for i, t in enumerate(['Set a bench to about 30°–45° and lie back with dumbbells at shoulder height.', 'Press the weights up until arms are straight.', 'Lower slowly to the start.']))}
 <div class="row" style="gap:10px;padding:14px;border-radius:14px;background:#fff;margin-top:14px">{ic('play', 26, '#ff0000')}<div style="flex:1"><div style="font-size:15px;font-weight:600">Watch a video on YouTube</div><div style="font-size:12px;color:#8e8e93;margin-top:1px">Proper-form tutorials for Incline Dumbbell Press</div></div>{ic('up', 15, '#8e8e93')}</div>
 <div class="card" style="margin-top:14px;padding:16px"><div style="font-size:17px;font-weight:600">Your best</div><div style="font-size:22px;font-weight:700;color:{PINK};margin-top:4px">18 kg × 10</div></div></div>''')


def opt(icon, title, sub, sel):
    return f'''<div class="row" style="gap:14px;padding:14px;border-radius:16px;background:#f2f2f7;margin-bottom:12px;border:2px solid {PINK if sel else 'transparent'}">
<div style="width:42px;height:42px;border-radius:50%;background:{PINK if sel else 'rgba(142,142,147,.55)'};display:flex;align-items:center;justify-content:center">{ic(icon, 20, '#fff')}</div>
<div style="flex:1"><div style="font-size:17px;font-weight:600">{title}</div><div style="font-size:13px;color:#8e8e93;margin-top:2px;line-height:1.25">{sub}</div></div>
<span style="width:22px;height:22px;border-radius:50%;border:2px solid {PINK if sel else 'rgba(0,0,0,.2)'};background:{PINK if sel else 'transparent'};display:flex;align-items:center;justify-content:center">{ic('check', 12, '#fff') if sel else ''}</span></div>'''


def onboarding_top(step):
    caps = ''.join(f'<i style="flex:1;height:4px;border-radius:9px;background:{PINK if i <= step else "rgba(0,0,0,.12)"}"></i>' for i in range(5))
    return f'<div style="display:flex;gap:6px;padding:68px 24px 0">{caps}</div>'


def onboarding_level():
    return phone(onboarding_top(1) + f'''<div style="padding:24px">
 <div style="font-size:32px;font-weight:700;letter-spacing:-.6px">Your experience</div>
 <div style="font-size:16px;color:#8e8e93;margin:8px 0 18px;line-height:1.35">We start at the right difficulty and adjust automatically after each workout.</div>
 {opt('walk', 'Beginner', 'New to training or coming back after a long break.', False)}
 {opt('walk', 'Intermediate', 'Training regularly and comfortable with the basics.', True)}
 {opt('flame', 'Advanced', 'Years of consistent training. Ready for volume and load.', False)}</div>
<div class="row" style="position:absolute;left:0;right:0;bottom:30px;justify-content:space-between;padding:0 24px"><span style="font-size:16px;font-weight:600;color:#8e8e93">Back</span><span class="pill">Continue</span></div>''')


def onboarding_health():
    def step(label, val):
        return f'<div class="row" style="justify-content:space-between;font-size:16px"><span>{label} <b>{val}</b></span><span class="stepper"><i>−</i><i>+</i></span></div>'
    return phone(onboarding_top(4) + f'''<div style="padding:24px">
 <div style="font-size:32px;font-weight:700;letter-spacing:-.6px">About you</div>
 <div style="font-size:16px;color:#8e8e93;margin:8px 0 18px;line-height:1.35">Used for calorie estimates and to pick starting weights. You can change it any time.</div>
 <div class="row" style="background:rgba(120,120,128,.12);border-radius:9px;padding:2px;margin-bottom:18px"><span style="flex:1;text-align:center;background:#fff;border-radius:7px;padding:6px;font-size:14px;font-weight:600;box-shadow:0 1px 3px rgba(0,0,0,.15)">Metric</span><span style="flex:1;text-align:center;font-size:14px;padding:6px">Imperial</span></div>
 <div style="display:flex;flex-direction:column;gap:16px">{step('Weight', '72 kg')}{step('Height', '178 cm')}{step('Age', '29')}</div>
 <div class="row" style="gap:12px;padding:14px;border-radius:16px;background:#f2f2f7;margin-top:22px"><div style="flex:1"><div style="font-size:16px;font-weight:600;display:flex;gap:8px;align-items:center">{ic('heart', 17, HEALTH)}Connect Apple Health</div><div style="font-size:13px;color:#8e8e93;margin-top:3px;line-height:1.3">Save workouts and weight to Health and show your steps.</div></div><div class="tog"></div></div>
 <div class="row" style="gap:8px;font-size:13px;color:#8e8e93;margin-top:16px">🔒 Nothing leaves your phone. There is no account and no tracking.</div></div>
<div class="row" style="position:absolute;left:0;right:0;bottom:30px;justify-content:space-between;padding:0 24px"><span style="font-size:16px;font-weight:600;color:#8e8e93">Back</span><span class="pill">Build my plan</span></div>''')
