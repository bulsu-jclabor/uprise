const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push('console.error: ' + msg.text());
  });

  await page.goto('http://localhost:8765', { waitUntil: 'load', timeout: 60000 });
  // Flutter web boots into a canvas/DOM tree asynchronously after `load`.
  await page.waitForTimeout(8000);
  await page.screenshot({ path: '.tmp_screenshot_1_initial.png', fullPage: true });

  console.log('--- ERRORS SO FAR ---');
  console.log(errors.length ? errors.join('\n') : '(none)');
  console.log('--- TITLE ---');
  console.log(await page.title());

  await browser.close();
})();
