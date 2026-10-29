"""Release-browser checks in an isolated profile, including public access guards."""
import argparse
import re
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:8080')
parser.add_argument('--browser', default='/usr/bin/chromium')
args = parser.parse_args()
shots = Path(__file__).resolve().parents[1] / 'docs' / 'screenshots'
shots.mkdir(parents=True, exist_ok=True)


def semantics(page):
    page.wait_for_selector('flutter-view', state='attached', timeout=60000)
    placeholder = page.locator('flt-semantics-placeholder')
    if placeholder.count():
        placeholder.evaluate('(element)=>element.click()')


def login(page):
    semantics(page)
    submit = page.get_by_role('button', name='Login', exact=True).last
    expect(submit).to_be_visible(timeout=30000)
    assert page.get_by_role('button', name='Report event', exact=True).count() == 0
    submit.click()
    expect(page.get_by_role('button', name=re.compile('^Check (in|out)$'))).to_be_visible(timeout=30000)


def navigate(page, route):
    page.evaluate('(route)=>{window.location.hash="/"+route;}', route)


with sync_playwright() as p:
    browser = p.chromium.launch(executable_path=args.browser, headless=True,
        args=['--no-sandbox', '--disable-dev-shm-usage'])
    context = browser.new_context(viewport={'width': 1440, 'height': 1000})
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto(args.url.rstrip('/') + '/#/handover', wait_until='domcontentloaded')
    semantics(page)
    expect(page.get_by_role('button', name='Login', exact=True).last).to_be_visible(timeout=30000)
    assert page.get_by_role('button', name='Report event', exact=True).count() == 0
    page.screenshot(path=str(shots / 'login-desktop.png'))
    page.set_viewport_size({'width': 390, 'height': 844})
    page.screenshot(path=str(shots / 'login-mobile.png'))
    page.set_viewport_size({'width': 1440, 'height': 1000})
    page.get_by_role('button', name='Registration', exact=True).click()
    expect(page.get_by_role('button', name='Continue to login', exact=True)).to_be_visible()
    page.screenshot(path=str(shots / 'registration-desktop.png'))
    page.get_by_role('button', name='Continue to login', exact=True).click()
    login(page)  # No email or password is supplied.
    expect(page.get_by_role('button', name='Check out', exact=True)).to_be_visible()
    page.screenshot(path=str(shots / 'desktop.png'))

    for route, action, filename in [
        ('handover', re.compile('^Outgoing shift'), 'handover-desktop.png'),
        ('documents', 'Upload image', 'documents-desktop.png'),
        ('chat', 'New conversation', 'conversations-desktop.png'),
    ]:
        navigate(page, route)
        expect(page.get_by_role('button', name=action).last).to_be_visible(timeout=30000)
        if route == 'chat':
            assert page.locator('[aria-label*="Fall · R-014"]').count() == 0
            page.get_by_role('button', name=re.compile('^Sarah Mitchell')).first.click()
            expect(page.get_by_role('textbox', name=re.compile('Write a message'))).to_be_visible()
        page.screenshot(path=str(shots / filename))
        if route == 'handover':
            update = page.get_by_role('textbox', name='Your update', exact=True)
            update.click()
            page.wait_for_timeout(100)
            page.keyboard.type('Equipment follow-up recorded for coordinator review.', delay=2)
            send = page.get_by_role('button', name='Send update', exact=True)
            expect(send).to_be_enabled()
            send.click()
            saved = page.get_by_text('Update sent for coordinator review. The signed version is preserved.', exact=True).last
            expect(saved).to_be_visible()
            expect(update).to_be_enabled()
            expect(send).to_be_disabled()
            page.reload(wait_until='domcontentloaded')
            login(page)
            navigate(page, 'handover')
            expect(page.get_by_role('button', name=re.compile('^Document version Version 1 · Signed'))).to_be_visible()
            expect(page.get_by_role('textbox', name='Your update', exact=True)).to_have_value('')
            page.get_by_role('button', name='Version history', exact=True).click()
            expect(page.get_by_role('button', name='View activity', exact=True)).to_be_visible()
            page.wait_for_timeout(350)
            page.screenshot(path=str(shots / 'handover-history-desktop.png'))
            page.reload(wait_until='domcontentloaded')
            login(page)
            navigate(page, 'handover')
            expect(page.get_by_role('button', name=re.compile('^Document version Version 1 · Signed'))).to_be_visible()
            page.mouse.move(1050, 700)
            page.mouse.wheel(0, 430)
            page.wait_for_timeout(350)
            page.screenshot(path=str(shots / 'handover-record-desktop.png'))

    navigate(page, 'home')
    expect(page.get_by_role('button', name='Check out', exact=True)).to_be_visible()
    page.get_by_role('button', name='Check out', exact=True).click()
    expect(page.get_by_role('button', name='Check in', exact=True)).to_be_visible()
    page.reload(wait_until='domcontentloaded')
    login(page)
    expect(page.get_by_role('button', name='Check in', exact=True)).to_be_visible()
    page.evaluate('''async()=>{await navigator.serviceWorker.ready;
      if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));}''')
    cached = page.evaluate('''async()=>{const names=await caches.keys();const cache=await caches.open(names.find(n=>n.startsWith('rsa-shell-')));return (await cache.keys()).length;}''')
    assert cached > 20, f'Incomplete app shell: {cached}'
    context.set_offline(True)
    page.reload(wait_until='domcontentloaded')
    login(page)
    expect(page.get_by_role('button', name='Check in', exact=True)).to_be_visible()
    context.set_offline(False)
    page.get_by_role('button', name='Check in', exact=True).click()
    expect(page.get_by_role('button', name='Check out', exact=True)).to_be_visible()
    page.set_viewport_size({'width': 390, 'height': 844})
    page.screenshot(path=str(shots / 'home-mobile.png'))
    page.reload(wait_until='domcontentloaded')
    login(page)
    navigate(page, 'handover')
    expect(page.get_by_role('button', name=re.compile('^Outgoing shift'))).to_be_visible()
    page.screenshot(path=str(shots / 'handover-mobile.png'))
    navigate(page, 'home')
    page.get_by_role('button', name='Report event', exact=True).last.click()
    expect(page.get_by_role('button', name='Send event', exact=True)).to_be_visible()
    page.screenshot(path=str(shots / 'report-mobile.png'))
    page.get_by_role('button', name='Back to workspace', exact=True).click()

    page.set_viewport_size({'width': 1440, 'height': 1000})
    navigate(page, 'home')
    expect(page.get_by_role('button', name='Check out', exact=True)).to_be_visible()
    # The persistent shell header sits outside the active route's web semantics.
    # Exercise its visible avatar/name target; Flutter tests also use account-menu.
    page.mouse.click(1360, 40)
    page.wait_for_timeout(300)
    page.mouse.move(1100, 700)
    page.mouse.wheel(0, 900)
    logout = page.get_by_role('button', name='Log out', exact=True)
    expect(logout).to_be_visible()
    page.screenshot(path=str(shots / 'account-desktop.png'))
    logout.click()
    page.get_by_role('button', name='Stay signed in', exact=True).click()
    expect(logout).to_be_visible()
    logout.click()
    page.get_by_role('button', name='Log out', exact=True).last.click()
    expect(page.get_by_role('button', name='Login', exact=True).last).to_be_visible()
    assert page.get_by_role('button', name='Report event', exact=True).count() == 0
    page.go_back(wait_until='domcontentloaded')
    expect(page.get_by_role('button', name='Login', exact=True).last).to_be_visible()
    navigate(page, 'chat/direct-emily-sarah')
    expect(page.get_by_role('button', name='Login', exact=True).last).to_be_visible()
    assert page.get_by_role('button', name='Report event', exact=True).count() == 0
    login(page)
    expect(page.get_by_role('button', name='Check out', exact=True)).to_be_visible()
    assert not errors, errors
    print(f'PASS: public login/registration, empty login as Emily, confirmed/cancelled logout, signed-out URL/back guards, first chat open, handover/documents/conversations, durable records and offline reopening ({cached} cached assets), mobile navigation; no page errors.')
    context.close()
    browser.close()
