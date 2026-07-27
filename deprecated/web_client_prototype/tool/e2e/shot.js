const puppeteer = require('puppeteer-core');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

(async () => {
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new' });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });

  await page.goto('http://localhost:8081/sutta/dn-1', { waitUntil: 'networkidle2', timeout: 60000 });
  await new Promise((r) => setTimeout(r, 1500));
  await page.screenshot({ path: '/tmp/proto_reader.png' });

  // open mn-1 + run a search so the workspace looks lived-in
  const items = await page.$$('.nav-item');
  await items[2].click();
  await new Promise((r) => setTimeout(r, 2000));
  await page.type('.search-box input', 'bhagavaa');
  await page.click('.search-btn');
  await new Promise((r) => setTimeout(r, 2500));
  await page.screenshot({ path: '/tmp/proto_workspace.png' });

  // single-language layout
  const btns = await page.$$('.layout-btn');
  await btns[0].click(); // pali only
  await new Promise((r) => setTimeout(r, 800));
  await page.screenshot({ path: '/tmp/proto_pali_only.png' });

  await browser.close();
  console.log('done');
})();
