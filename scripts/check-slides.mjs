// Inspect the portable RevealJS deck in Chromium and save one PNG per slide.
// PLAYWRIGHT_MODULE points to a temporary Playwright installation outside the repo.
import {createServer} from "node:http";
import {readFile, mkdir, writeFile} from "node:fs/promises";
import {resolve, join} from "node:path";
import {pathToFileURL} from "node:url";

const input = resolve(process.argv[2] || "presentation.html");
const output = resolve(process.argv[3] || "build-logs/browser");
const modulePath = process.env.PLAYWRIGHT_MODULE;
if (!modulePath) throw new Error("Set PLAYWRIGHT_MODULE to playwright/index.mjs.");
const {chromium} = await import(pathToFileURL(resolve(modulePath)).href);
await mkdir(output, {recursive: true});
const html = await readFile(input);
const report = {
  viewport: {width: 1600, height: 900},
  source: "presentation.html",
  slides: [],
  externalRequests: [],
  missingLocalResources: [],
  pageErrors: [],
  consoleErrors: [],
};
let activeSlide = "initialization";
const server = createServer((request, response) => {
  const pathname = new URL(request.url, "http://127.0.0.1").pathname;
  if (pathname === "/favicon.ico") {
    response.writeHead(204).end();
  } else if (pathname === "/" || pathname === "/presentation.html") {
    response.writeHead(200, {"Content-Type": "text/html; charset=utf-8"});
    response.end(html);
  } else {
    report.missingLocalResources.push({slide: activeSlide, pathname});
    response.writeHead(404).end("Portable deck resource missing");
  }
});
await new Promise((done, reject) => {
  server.once("error", reject);
  server.listen(0, "127.0.0.1", done);
});
const origin = `http://127.0.0.1:${server.address().port}`;
let browser;

try {
  browser = await chromium.launch({headless: true});
  const page = await browser.newPage({
    viewport: report.viewport,
    deviceScaleFactor: 1,
    reducedMotion: "reduce",
  });
  page.on("pageerror", (error) => {
    report.pageErrors.push({slide: activeSlide, message: error.message});
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      report.consoleErrors.push({slide: activeSlide, message: message.text()});
    }
  });
  await page.route("**/*", async (route) => {
    const url = new URL(route.request().url());
    if (url.origin === origin || ["data:", "blob:"].includes(url.protocol)) {
      await route.continue();
    } else {
      report.externalRequests.push({slide: activeSlide, url: url.href});
      await route.abort("blockedbyclient");
    }
  });
  await page.goto(`${origin}/presentation.html`, {waitUntil: "networkidle"});
  await page.waitForFunction(() => window.Reveal?.isReady(), undefined, {timeout: 30000});
  const slides = await page.evaluate(async () => {
    await document.fonts.ready;
    Reveal.configure({transition: "none", backgroundTransition: "none", autoAnimate: false});
    return Reveal.getSlides()
      .filter((slide) => !slide.classList.contains("stack") && !slide.querySelector(":scope > section"))
      .map((slide) => ({
        id: slide.id,
        title: slide.querySelector("h1, h2, h3")?.textContent.trim() || "Untitled slide",
        ...Reveal.getIndices(slide),
      }));
  });
  if (!slides.length) throw new Error("RevealJS did not expose any content slides.");

  for (const [index, slide] of slides.entries()) {
    activeSlide = slide.id || `${slide.h}.${slide.v || 0}`;
    const findings = await page.evaluate(async ({h, v = 0}) => {
      Reveal.slide(h, v);
      const current = Reveal.getCurrentSlide();
      const fragmentIndices = [...current.querySelectorAll(".fragment")]
        .map((element) => Number(element.dataset.fragmentIndex || 0));
      if (fragmentIndices.length) Reveal.navigateFragment(Math.max(...fragmentIndices));
      for (const image of current.querySelectorAll("img[data-src]")) {
        image.src = image.dataset.src;
        image.removeAttribute("data-src");
      }
      await document.fonts.ready;
      await Promise.all([...current.querySelectorAll("img")].map(async (image) => {
        try {
          await Promise.race([
            image.decode(),
            new Promise((_, reject) => setTimeout(() => reject(new Error("Image timeout")), 10000)),
          ]);
        } catch (_) {
          // Record the broken image below, while retaining the other screenshots.
        }
      }));
      Reveal.layout();
      await new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)));

      const canvas = document.querySelector(".reveal .slides").getBoundingClientRect();
      const bounds = {
        left: Math.max(0, canvas.left), top: Math.max(0, canvas.top),
        right: Math.min(innerWidth, canvas.right), bottom: Math.min(innerHeight, canvas.bottom),
      };
      const tolerance = 4;
      const outside = (rect) => ({
        left: Math.max(0, bounds.left - rect.left),
        top: Math.max(0, bounds.top - rect.top),
        right: Math.max(0, rect.right - bounds.right),
        bottom: Math.max(0, rect.bottom - bounds.bottom),
      });
      const visible = (element) => {
        if (element.closest("aside, .notes, .speaker-notes, .chapter-number, script, style, noscript, annotation, [aria-hidden='true']")) return false;
        for (let parent = element; parent && parent !== current.parentElement; parent = parent.parentElement) {
          const style = getComputedStyle(parent);
          if (style.display === "none" || style.visibility !== "visible" || Number(style.opacity) === 0) return false;
        }
        return element.getClientRects().length > 0;
      };
      const textOverflow = [];
      const seen = new Set();
      const walker = document.createTreeWalker(current, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const node = walker.currentNode;
        const element = node.parentElement;
        if (!node.textContent.trim() || !element || !visible(element)) continue;
        const range = document.createRange();
        range.selectNodeContents(node);
        const rects = [...range.getClientRects()].filter((rect) => rect.width > 0 && rect.height > 0);
        const excess = rects.map(outside).find((item) => Math.max(...Object.values(item)) > tolerance);
        if (!excess) continue;
        const block = element.closest("h1, h2, h3, p, li, pre, td, th, figcaption") || element;
        const text = block.textContent.replace(/\s+/g, " ").trim().slice(0, 180);
        if (!seen.has(text)) {
          seen.add(text);
          textOverflow.push({text, excessPixels: excess});
        }
      }
      const images = [...current.querySelectorAll("img")].filter(visible).map((image) => ({
        alt: image.alt,
        loaded: image.complete && image.naturalWidth > 0,
        naturalWidth: image.naturalWidth,
        naturalHeight: image.naturalHeight,
        excessPixels: outside(image.getBoundingClientRect()),
      }));
      const imageOverflow = images.filter((image) => Math.max(...Object.values(image.excessPixels)) > tolerance);
      return {bounds, textOverflow, images, imageOverflow, indices: Reveal.getIndices()};
    }, slide);
    const basename = `${String(index + 1).padStart(3, "0")}-${activeSlide.replace(/[^a-zA-Z0-9_-]+/g, "-")}.png`;
    await page.screenshot({path: join(output, basename), animations: "disabled"});
    report.slides.push({number: index + 1, ...slide, screenshot: basename, ...findings});
    console.log(`${String(index + 1).padStart(2)} ${slide.title}: ${findings.textOverflow.length} text overflow, ${findings.images.filter((image) => !image.loaded).length} broken images`);
  }
} catch (error) {
  report.fatalError = error.stack || String(error);
  process.exitCode = 1;
} finally {
  if (browser) await browser.close();
  await new Promise((done) => server.close(done));
  report.summary = {
    slideCount: report.slides.length,
    textOverflowSlides: report.slides.filter((slide) => slide.textOverflow.length).map((slide) => slide.number),
    imageOverflowSlides: report.slides.filter((slide) => slide.imageOverflow.length).map((slide) => slide.number),
    brokenImages: report.slides.flatMap((slide) => slide.images.filter((image) => !image.loaded).map((image) => ({slide: slide.number, alt: image.alt}))),
    externalRequestCount: report.externalRequests.length,
    missingLocalResourceCount: report.missingLocalResources.length,
    pageErrorCount: report.pageErrors.length,
  };
  await writeFile(join(output, "layout-report.json"), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report.summary, null, 2));
  if (report.summary.textOverflowSlides.length || report.summary.imageOverflowSlides.length ||
      report.summary.brokenImages.length || report.summary.externalRequestCount ||
      report.summary.missingLocalResourceCount || report.summary.pageErrorCount) process.exitCode = 1;
}
