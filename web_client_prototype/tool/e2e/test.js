// Interactive prototype verification for the Jaspr web client prototype.
// Drives the real app in headless Chrome and reports PASS/FAIL per flow.
const puppeteer = require('puppeteer-core');

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BASE = 'http://localhost:8081';

const results = [];
function report(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}: ${name}${detail ? ' — ' + detail : ''}`);
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-first-run'],
  });
  const page = await browser.newPage();
  const consoleErrors = [];
  page.on('pageerror', (e) => consoleErrors.push(String(e)));
  page.on('console', (m) => {
    if (m.type() === 'error') consoleErrors.push(m.text());
  });

  // ---- 1. Deep link seeds the workspace -------------------------------
  await page.goto(`${BASE}/sutta/dn-1`, { waitUntil: 'networkidle2', timeout: 60000 });
  await page.waitForSelector('.tab-bar .tab', { timeout: 30000 });
  let tabCount = (await page.$$('.tab-strip .tab')).length;
  report('deep link seeds 1 tab', tabCount === 1, `tabs=${tabCount}`);

  const ssrTextVisible = await page.evaluate(() =>
    document.body.innerText.includes('සුත්තන්තපිටකෙ'));
  report('sutta text visible after hydration', ssrTextVisible);

  // ---- 2. Open a second sutta from the nav (client-side, no reload) ---
  const navItems = await page.$$('.nav-item');
  await navItems[2].click(); // mn-1
  await new Promise((r) => setTimeout(r, 2500)); // doc fetch + render
  tabCount = (await page.$$('.tab-strip .tab')).length;
  report('nav click opens 2nd tab', tabCount === 2, `tabs=${tabCount}`);

  let url = page.url();
  report('URL reflects active tab (mn-1)', url.endsWith('/sutta/mn-1'), url);

  const mn1Loaded = await page.evaluate(() => {
    const host = document.querySelector('.tab-host.active');
    return host && host.innerText.length > 100;
  });
  report('2nd tab rendered content', !!mn1Loaded);

  // ---- 3. Scroll, switch back, verify restore -------------------------
  await page.evaluate(() => {
    const pane = document.querySelector('.tab-host.active .reader-pane');
    pane.scrollTop = 1500;
    pane.dispatchEvent(new Event('scroll'));
  });
  await new Promise((r) => setTimeout(r, 300));

  // switch to tab 0 (dn-1)
  const labels = await page.$$('.tab-strip .tab .tab-label');
  await labels[0].click();
  await new Promise((r) => setTimeout(r, 500));
  url = page.url();
  report('URL follows switch back (dn-1)', url.endsWith('/sutta/dn-1'), url);

  // switch again to tab 1 (mn-1) and check scroll restored
  const labels2 = await page.$$('.tab-strip .tab .tab-label');
  await labels2[1].click();
  await new Promise((r) => setTimeout(r, 500));
  const restored = await page.evaluate(
    () => document.querySelector('.tab-host.active .reader-pane').scrollTop);
  report('scroll restored on tab switch', Math.abs(restored - 1500) < 50,
    `scrollTop=${restored}`);

  // ---- 4. Search (Singlish) opens result into a tab --------------------
  await page.type('.search-box input', 'bhagavaa');
  await page.click('.search-btn');
  await page.waitForSelector('.search-result', { timeout: 20000 })
    .catch(() => {});
  const resultCount = (await page.$$('.search-result')).length;
  report('singlish FTS search returns results', resultCount > 0,
    `results=${resultCount}`);

  const converted = await page.$eval('.search-converted', (el) => el.innerText)
    .catch(() => '');
  report('singlish converted in-process', converted.includes('භගවා'),
    converted);

  if (resultCount > 0) {
    await page.click('.search-result');
    await new Promise((r) => setTimeout(r, 2500));
    tabCount = (await page.$$('.tab-strip .tab')).length;
    report('search result opened as 3rd tab', tabCount === 3, `tabs=${tabCount}`);

    const anchorScrolled = await page.evaluate(
      () => document.querySelector('.tab-host.active .reader-pane').scrollTop);
    report('scrolled to matched entry', anchorScrolled > 0,
      `scrollTop=${anchorScrolled}`);
  }

  // ---- 5. Keep-alive: open many tabs, count mounted hosts --------------
  for (let i = 0; i < 4; i++) {
    const items = await page.$$('.nav-item');
    await items[i % items.length].click();
    await new Promise((r) => setTimeout(r, 1200));
  }
  const counts = await page.evaluate(() => ({
    tabs: document.querySelectorAll('.tab-strip .tab').length,
    hosts: document.querySelectorAll('.tab-host').length,
  }));
  report('keep-alive caps mounted DOM hosts',
    counts.hosts <= 4 && counts.tabs >= 6,
    `tabs=${counts.tabs} mountedHosts=${counts.hosts} (cap=3 + active)`);

  // ---- 6. Close tab ----------------------------------------------------
  const before = (await page.$$('.tab-strip .tab')).length;
  await page.click('.tab.active .tab-close');
  await new Promise((r) => setTimeout(r, 400));
  const after = (await page.$$('.tab-strip .tab')).length;
  report('close tab works', after === before - 1, `${before}→${after}`);

  // ---- console errors ---------------------------------------------------
  const realErrors = consoleErrors.filter(
    (e) => !e.includes('favicon') && !e.includes('DevTools'));
  report('no console errors', realErrors.length === 0,
    realErrors.slice(0, 3).join(' | '));

  await browser.close();
  const failed = results.filter((r) => !r.ok).length;
  console.log(`\n${results.length - failed}/${results.length} checks passed`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.error('SCRIPT ERROR:', e); process.exit(2); });
