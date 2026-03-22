const { chromium } = require('playwright');
const path = require('path');

async function checkSlides() {
    const browser = await chromium.launch();
    const page = await browser.newPage();

    // Set viewport to typical presentation size
    await page.setViewportSize({ width: 1280, height: 720 });

    const htmlPath = path.join(__dirname, '..', 'slides-instructeur.html');
    await page.goto(`file://${htmlPath}`);
    await page.waitForTimeout(1000);

    // Get total number of slides
    const totalSlides = await page.evaluate(() => {
        return document.querySelectorAll('section').length;
    });

    console.log(`Total slides: ${totalSlides}\n`);

    const problemSlides = [];

    for (let i = 1; i <= totalSlides; i++) {
        await page.goto(`file://${htmlPath}#${i}`);
        await page.waitForTimeout(50);

        const info = await page.evaluate((slideNum) => {
            const sections = document.querySelectorAll('section');
            const section = sections[slideNum - 1];
            if (!section) return null;

            // Get computed style
            const computedStyle = getComputedStyle(section);
            const sectionRect = section.getBoundingClientRect();

            // Find the lowest visible element
            let maxBottom = 0;
            let overflowingElements = [];

            // Check direct children and all descendants
            const allElements = section.querySelectorAll('*');
            allElements.forEach(el => {
                const rect = el.getBoundingClientRect();
                const style = getComputedStyle(el);

                // Skip hidden elements
                if (style.display === 'none' || style.visibility === 'hidden') return;

                const relativeBottom = rect.bottom - sectionRect.top;

                if (rect.bottom > maxBottom) {
                    maxBottom = rect.bottom;
                }

                // Check if element exceeds section bounds
                if (relativeBottom > sectionRect.height) {
                    overflowingElements.push({
                        tag: el.tagName,
                        text: el.textContent?.substring(0, 30) || '',
                        overflow: Math.round(relativeBottom - sectionRect.height)
                    });
                }
            });

            // Get title
            const h1 = section.querySelector('h1, h2');
            const title = h1?.textContent?.trim().substring(0, 50) || '(no title)';

            // Calculate content height vs section height
            const contentHeight = maxBottom - sectionRect.top;
            const hasOverflow = contentHeight > sectionRect.height + 10;

            // Also check scrollHeight
            const scrollOverflow = section.scrollHeight > section.clientHeight;

            return {
                title,
                sectionHeight: Math.round(sectionRect.height),
                contentHeight: Math.round(contentHeight),
                hasOverflow,
                scrollOverflow,
                overflow: Math.round(contentHeight - sectionRect.height),
                overflowingElements: overflowingElements.slice(0, 3)
            };
        }, i);

        if (!info) continue;

        if (info.hasOverflow || info.scrollOverflow || info.overflow > 0) {
            problemSlides.push({ slide: i, ...info });
            console.log(`[ISSUE] Slide ${i}: "${info.title}"`);
            console.log(`        Section: ${info.sectionHeight}px, Content: ${info.contentHeight}px, Overflow: ${info.overflow}px`);
        }

        if (i % 20 === 0) {
            console.log(`Progress: ${i}/${totalSlides}`);
        }
    }

    console.log('\n========================================');
    console.log(`SUMMARY: Found ${problemSlides.length} slides with issues`);
    console.log('========================================\n');

    if (problemSlides.length > 0) {
        problemSlides.forEach(s => {
            console.log(`Slide ${s.slide}: "${s.title}" - overflow ${s.overflow}px`);
        });
    }

    await browser.close();
}

checkSlides().catch(console.error);
