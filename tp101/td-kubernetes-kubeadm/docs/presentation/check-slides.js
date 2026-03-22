const { chromium } = require('playwright');
const path = require('path');

async function checkSlides() {
    const browser = await chromium.launch();
    const page = await browser.newPage();

    // Set viewport to 16:9 aspect ratio (common for presentations)
    await page.setViewportSize({ width: 1920, height: 1080 });

    const htmlPath = path.join(__dirname, '..', 'slides-instructeur.html');
    await page.goto(`file://${htmlPath}`);

    // Wait for Marp to load
    await page.waitForTimeout(2000);

    // Get total number of slides
    const totalSlides = await page.evaluate(() => {
        const sections = document.querySelectorAll('section');
        return sections.length;
    });

    console.log(`Total slides: ${totalSlides}\n`);

    const problemSlides = [];

    for (let i = 1; i <= totalSlides; i++) {
        // Navigate to slide
        await page.goto(`file://${htmlPath}#${i}`);
        await page.waitForTimeout(100);

        // Check if content overflows
        const overflowInfo = await page.evaluate((slideNum) => {
            const section = document.querySelector(`section:nth-of-type(${slideNum})`);
            if (!section) return { hasOverflow: false };

            // Get all content elements
            const elements = section.querySelectorAll('*');
            let lastElementBottom = 0;
            let lastElement = null;

            elements.forEach(el => {
                const rect = el.getBoundingClientRect();
                if (rect.bottom > lastElementBottom) {
                    lastElementBottom = rect.bottom;
                    lastElement = el;
                }
            });

            const sectionRect = section.getBoundingClientRect();
            const sectionHeight = sectionRect.height;
            const viewportHeight = window.innerHeight;

            // Check if content exceeds visible area (with some margin)
            const margin = 50; // 50px margin from bottom
            const hasOverflow = lastElementBottom > (sectionRect.top + sectionHeight - margin);

            // Get slide title
            const h1 = section.querySelector('h1');
            const h2 = section.querySelector('h2');
            const title = h1?.textContent || h2?.textContent || '(no title)';

            return {
                hasOverflow,
                sectionHeight,
                contentBottom: lastElementBottom - sectionRect.top,
                title: title.substring(0, 60),
                overflow: lastElementBottom - (sectionRect.top + sectionHeight)
            };
        }, i);

        if (overflowInfo.hasOverflow) {
            problemSlides.push({
                slide: i,
                ...overflowInfo
            });
            console.log(`[OVERFLOW] Slide ${i}: "${overflowInfo.title}" - overflow: ${Math.round(overflowInfo.overflow)}px`);
        } else {
            // Show progress every 10 slides
            if (i % 10 === 0) {
                console.log(`Checked ${i}/${totalSlides} slides...`);
            }
        }
    }

    console.log('\n========================================');
    console.log(`SUMMARY: ${problemSlides.length} slides with potential overflow`);
    console.log('========================================\n');

    if (problemSlides.length > 0) {
        console.log('Problematic slides:');
        problemSlides.forEach(s => {
            console.log(`  - Slide ${s.slide}: "${s.title}" (overflow: ${Math.round(s.overflow)}px)`);
        });
    }

    await browser.close();
    return problemSlides;
}

checkSlides().catch(console.error);
