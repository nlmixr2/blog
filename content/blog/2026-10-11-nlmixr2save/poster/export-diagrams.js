#!/usr/bin/env node
//
// export-diagrams.js -- pull the inline SVG diagrams out of the slide deck
// and screenshot each one at poster resolution.
//
// The deck's SVGs are styled by the <style> block in its YAML header, so each
// one is wrapped in a standalone page carrying that same CSS rather than
// captured from reveal (which hides every slide but the current one).
//
// Usage (from poster/):  node export-diagrams.js
//
'use strict';

const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');

const QMD = path.join(__dirname, '..', 'presentation', 'nlmixr2save.qmd');
const OUT = path.join(__dirname, 'figs');
const SCALE = 3;   // 1000-px viewBox -> 3000 px, ~300 dpi at 10 in wide

// in the order they appear in the deck
const NAMES = ['diagram-serializer', 'diagram-fitzip', 'diagram-operator',
               'diagram-cachekey', 'diagram-seed'];

const qmd = fs.readFileSync(QMD, 'utf8');
const css = qmd.match(/<style>([\s\S]*?)<\/style>/)[1];
const svgs = [...qmd.matchAll(/```\{=html\}\s*(<svg[\s\S]*?<\/svg>)\s*```/g)].map(m => m[1]);
if (svgs.length !== NAMES.length) {
  console.error(`expected ${NAMES.length} diagrams in the deck, found ${svgs.length}`);
  process.exit(1);
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1100, height: 800, deviceScaleFactor: SCALE });
  for (let i = 0; i < svgs.length; i++) {
    // the deck caps svg height for a 16:9 slide; the poster wants it uncapped
    const html = `<!doctype html><html><head><style>${css}
      body { margin: 0; background: #ffffff; }
      svg.dg { max-height: none; width: 1000px; margin: 0; }
      </style></head><body>${svgs[i]}</body></html>`;
    await page.setContent(html, { waitUntil: 'load' });
    const el = await page.$('svg.dg');
    const file = path.join(OUT, NAMES[i] + '.png');
    await el.screenshot({ path: file, omitBackground: false });
    console.log(file);
  }
  await browser.close();
})();
