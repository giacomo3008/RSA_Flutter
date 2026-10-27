"""Release-browser smoke test. Requires Python Playwright and a running web build.
Runs in a fresh browser context, never the user's existing demo session.
"""
import argparse
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

parser=argparse.ArgumentParser()
parser.add_argument('--url',default='http://127.0.0.1:8080')
parser.add_argument('--browser',default='/usr/bin/chromium')
args=parser.parse_args()
shots=Path(__file__).resolve().parents[1]/'docs'/'screenshots'
shots.mkdir(parents=True,exist_ok=True)

def semantics(page):
    page.wait_for_selector('flutter-view',state='attached',timeout=60000)
    placeholder=page.locator('flt-semantics-placeholder')
    if placeholder.count():
        placeholder.evaluate('(element)=>element.click()')

with sync_playwright() as p:
    browser=p.chromium.launch(executable_path=args.browser,headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
    context=browser.new_context(viewport={'width':1440,'height':1000})
    page=context.new_page()
    errors=[]
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.goto(args.url,wait_until='domcontentloaded')
    semantics(page)
    expect(page.get_by_role('button',name='Check out',exact=True)).to_be_visible(timeout=30000)
    page.screenshot(path=str(shots/'desktop.png'))
    # Verify a real persisted attendance mutation, not only an open port.
    page.get_by_role('button',name='Check out',exact=True).click()
    expect(page.get_by_role('button',name='Check in',exact=True)).to_be_visible()
    page.reload(wait_until='domcontentloaded')
    semantics(page)
    expect(page.get_by_role('button',name='Check in',exact=True)).to_be_visible(timeout=30000)
    # An installed worker must cache the complete engine/font/SQLite shell.
    page.evaluate('''async()=>{await navigator.serviceWorker.ready;
      if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));}''')
    cached=page.evaluate('''async()=>{const names=await caches.keys();const cache=await caches.open(names.find(n=>n.startsWith('rsa-shell-')));return (await cache.keys()).length;}''')
    assert cached>20,f'Incomplete app shell: {cached}'
    context.set_offline(True)
    page.reload(wait_until='domcontentloaded')
    semantics(page)
    expect(page.get_by_role('button',name='Check in',exact=True)).to_be_visible(timeout=30000)
    context.set_offline(False)
    page.get_by_role('button',name='Check in',exact=True).click()
    expect(page.get_by_role('button',name='Check out',exact=True)).to_be_visible()
    page.set_viewport_size({'width':390,'height':844})
    page.screenshot(path=str(shots/'home-mobile.png'))
    page.get_by_role('button',name='Report event',exact=True).last.click()
    expect(page.get_by_role('button',name='Send event',exact=True)).to_be_visible()
    page.screenshot(path=str(shots/'report-mobile.png'))
    assert not errors,errors
    print(f'PASS: release startup, attendance mutation, refresh persistence, offline reopening ({cached} cached static assets), mobile navigation/report; no page errors.')
    context.close()
    browser.close()
