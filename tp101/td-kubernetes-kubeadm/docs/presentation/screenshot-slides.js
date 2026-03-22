const { chromium } = require('playwright');
const path = require('path');

async function screenshotSlides(slideNumbers) {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    await page.setViewportSize({ width: 1920, height: 1080 });
    const htmlPath = path.join(__dirname, '..', 'slides-instructeur.html');
    await page.goto(`file://${htmlPath}`);
    await page.waitForTimeout(2000);

    for (const slideNum of slideNumbers) {
        await page.goto(`file://${htmlPath}#${slideNum}`);
        await page.waitForTimeout(500);
        await page.screenshot({
            path: path.join(__dirname, `slide-${slideNum}.png`),
            fullPage: false
        });
        console.log(`Screenshot saved: slide-${slideNum}.png`);
    }
    await browser.close();
}

screenshotSlides([171, 172]).catch(console.error);
