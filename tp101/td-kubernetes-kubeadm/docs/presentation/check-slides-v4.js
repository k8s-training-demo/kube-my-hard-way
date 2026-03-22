const { chromium } = require('playwright');
const path = require('path');

async function checkSlides() {
    const browser = await chromium.launch();
    const page = await browser.newPage();

    await page.setViewportSize({ width: 1280, height: 720 });

    const htmlPath = path.join(__dirname, '..', 'slides-instructeur.html');
    await page.goto(`file://${htmlPath}`);
    await page.waitForTimeout(1000);

    const totalSlides = await page.evaluate(() => {
        return document.querySelectorAll('section').length;
    });

    console.log(`Total slides: ${totalSlides}\n`);

    // Only show slides with significant overflow (>20px)
    const problemSlides = [];

    for (let i = 1; i <= totalSlides; i++) {
        await page.goto(`file://${htmlPath}#${i}`);
        await page.waitForTimeout(50);

        const info = await page.evaluate((slideNum) => {
            const sections = document.querySelectorAll('section');
            const section = sections[slideNum - 1];
            if (!section) return null;

            const sectionRect = section.getBoundingClientRect();

            let maxBottom = 0;
            const allElements = section.querySelectorAll('*');
            allElements.forEach(el => {
                const rect = el.getBoundingClientRect();
                const style = getComputedStyle(el);
                if (style.display === 'none' || style.visibility === 'hidden') return;
                if (rect.bottom > maxBottom) maxBottom = rect.bottom;
            });

            const h1 = section.querySelector('h1, h2');
            const title = h1?.textContent?.trim().substring(0, 50) || '(no title)';

            const contentHeight = maxBottom - sectionRect.top;
            const overflow = contentHeight - sectionRect.height;

            return {
                title,
                sectionHeight: Math.round(sectionRect.height),
                contentHeight: Math.round(contentHeight),
                overflow: Math.round(overflow)
            };
        }, i);

        if (!info) continue;

        // Only report slides with >20px overflow
        if (info.overflow > 20) {
            problemSlides.push({ slide: i, ...info });
        }

        if (i % 30 === 0) console.log(`Progress: ${i}/${totalSlides}`);
    }

    console.log('\n========================================');
    console.log(`Slides with overflow >20px: ${problemSlides.length}`);
    console.log('========================================\n');

    problemSlides.forEach(s => {
        console.log(`Slide ${s.slide}: "${s.title}" - overflow ${s.overflow}px`);
    });

    await browser.close();
}

checkSlides().catch(console.error);
