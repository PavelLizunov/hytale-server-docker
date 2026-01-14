const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const DOCS_DIR = './docs';

async function fetchDoc(url, outputName) {
    if (!fs.existsSync(DOCS_DIR)) {
        fs.mkdirSync(DOCS_DIR, { recursive: true });
    }

    console.log(`Fetching: ${url}`);

    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    try {
        const page = await browser.newPage();

        await page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

        await page.goto(url, {
            waitUntil: 'networkidle2',
            timeout: 60000
        });

        // Wait for Cloudflare challenge to complete
        await page.waitForFunction(() => {
            return !document.body.innerText.includes('Just a moment');
        }, { timeout: 30000 }).catch(() => {
            console.log('Warning: Cloudflare check may still be present');
        });

        // Additional wait for content to load
        await new Promise(r => setTimeout(r, 3000));

        // Get the HTML content
        const html = await page.content();
        const htmlFile = path.join(DOCS_DIR, `${outputName}.html`);
        fs.writeFileSync(htmlFile, html);
        console.log(`HTML saved to: ${htmlFile}`);

        // Extract text content from article
        const textContent = await page.evaluate(() => {
            const article = document.querySelector('article') || document.querySelector('.article-body') || document.querySelector('main') || document.body;

            // Remove scripts, styles, nav, etc.
            const clone = article.cloneNode(true);
            clone.querySelectorAll('script, style, nav, header, footer, aside').forEach(el => el.remove());

            return clone.innerText;
        });

        const txtFile = path.join(DOCS_DIR, `${outputName}.txt`);
        fs.writeFileSync(txtFile, textContent.trim());
        console.log(`Text saved to: ${txtFile}`);

    } finally {
        await browser.close();
    }
}

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 2) {
    console.log('Usage: node fetch-docs.js <url> <output_name>');
    console.log('Example: node fetch-docs.js https://support.hytale.com/... server-manual');
    process.exit(1);
}

fetchDoc(args[0], args[1]).catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
});
