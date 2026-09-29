"""Render mockups of the app screens to PNG (needs: pip install playwright; uses the preinstalled Chromium)."""
import os, re, sys, urllib.request
import screens as S

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'docs')
FONTS = os.path.join(HERE, '.cache', 'fonts')


def ensure_fonts():
    os.makedirs(FONTS, exist_ok=True)
    if all(os.path.exists(os.path.join(FONTS, f'{w}.ttf')) for w in (400, 500, 600, 700, 800)):
        return
    css = urllib.request.urlopen('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800').read().decode()
    blocks = re.findall(r'font-weight:\s*(\d+);.*?url\((https://[^)]+)\)', css, re.S)
    for weight, url in blocks:
        open(os.path.join(FONTS, f'{weight}.ttf'), 'wb').write(urllib.request.urlopen(url).read())


def page(phones):
    body = ''.join(f'<div style="margin:0 22px">{p}</div>' for p in phones)
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{S.CSS}</style></head><body><div id="wrap" style="display:inline-flex;padding:40px 18px 40px">{body}</div></body></html>'


def main():
    from playwright.sync_api import sync_playwright
    ensure_fonts()
    sets = {
        'app-screens-1': [S.home(), S.detail(), S.player(), S.sheet()],
        'app-screens-2': [S.progress_top(), S.progress_scrolled(), S.onboarding_level(), S.onboarding_health()],
    }
    os.makedirs(OUT, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM', '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'), args=['--no-sandbox'])
        for name, phones in sets.items():
            html = os.path.join(HERE, '.cache', f'{name}.html')
            open(html, 'w').write(page(phones).replace('url(fonts/', 'url(fonts/'))
            pg = browser.new_page(device_scale_factor=1.5, viewport={'width': 2000, 'height': 1100})
            pg.goto('file://' + html)
            pg.wait_for_timeout(500)
            pg.locator('#wrap').screenshot(path=os.path.join(OUT, name + '.png'), omit_background=False)
            print('wrote', name)
        browser.close()


if __name__ == '__main__':
    main()
