#!/usr/bin/env node
//
// render_presentation.js -- flatten the reveal.js deck into a single .mp4.
//
//   1. serve the deck over http (reveal + the audio plugin do XHR, which
//      file:// blocks, so a static server is not optional)
//   2. drive it with puppeteer, screenshotting each slide at 1920x1080
//   3. read each clip's true duration with ffprobe
//   4. ffmpeg: still image + its clip -> one chunk per slide
//   5. ffmpeg concat -> <deck>.mp4
//
// Usage:  node render_presentation.js [--keep]
//         --keep   leave build/ (pngs, chunks, concat list) in place
//
'use strict';

const http = require('http');
const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
const puppeteer = require('puppeteer');

const DECK = 'nlmixr2-7.html';
const AUDIO_DIR = 'audio';
const BUILD = 'build';
// name the video after the deck, so <deck>.qmd -> <deck>.mp4
const OUT = DECK.replace(/\.html?$/i, '') + '.mp4';
const WIDTH = 1920, HEIGHT = 1080;
const KEEP = process.argv.includes('--keep');

// Silence padded around each slide's narration.
//
// LEAD fixes the first word being clipped: the AAC encoder's priming samples
// sit at the very start of a chunk, and concatenating with `-c copy` lets a
// player swallow them.  With a lead-in it eats silence instead of "Hi".
//
// TAIL is the audible gap between slides.  Without it each clip's last word
// runs straight into the next slide's first word.
const LEAD_S = 0.45;
const TAIL_S = 1.20;

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
  '.mp3': 'audio/mpeg', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.json': 'application/json', '.woff': 'font/woff',
  '.woff2': 'font/woff2', '.ttf': 'font/ttf',
};

function serve(root) {
  const server = http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '');
    const file = path.resolve(root, rel);
    if (!file.startsWith(path.resolve(root))) { res.writeHead(403).end(); return; }
    fs.readFile(file, (err, buf) => {
      if (err) { res.writeHead(404).end(); return; }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
      res.end(buf);
    });
  });
  return new Promise(resolve =>
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port })));
}

const run = (cmd, args) =>
  execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });

function duration(file) {
  const out = run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration',
                              '-of', 'default=nw=1:nk=1', file]).trim();
  const d = parseFloat(out);
  if (!isFinite(d) || d <= 0) throw new Error(`bad duration for ${file}: ${out}`);
  return d;
}

(async () => {
  const root = __dirname;
  for (const f of [DECK, AUDIO_DIR]) {
    if (!fs.existsSync(path.join(root, f))) throw new Error(`missing ${f}`);
  }
  fs.rmSync(path.join(root, BUILD), { recursive: true, force: true });
  fs.mkdirSync(path.join(root, BUILD));

  const { server, port } = await serve(root);
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [`--window-size=${WIDTH},${HEIGHT}`, '--hide-scrollbars', '--mute-audio'],
    protocolTimeout: 180000,
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: WIDTH, height: HEIGHT, deviceScaleFactor: 1 });

    // Block the narration entirely.  We only need pictures, and letting the
    // audio-slideshow plugin have its clips is actively harmful headless: with
    // autoplay on it retries play(), Chrome refuses without a user gesture
    // (NotAllowedError), and the retry loop pins the main thread so every CDP
    // call -- goto, evaluate, screenshot -- times out.
    await page.setRequestInterception(true);
    page.on('request', req =>
      /\.mp3(\?|$)/i.test(req.url()) ? req.abort() : req.continue());
    // NOT networkidle*: the audio-slideshow plugin holds a connection open for
    // each of the 21 clips, so the network never goes idle and goto() times out.
    // Wait for the DOM, then for reveal itself to report ready.
    await page.goto(`http://127.0.0.1:${port}/${DECK}`,
                    { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForFunction(() => window.Reveal && Reveal.isReady(),
                               { timeout: 120000 });

    // The audio plugin paints a player over the deck and would auto-advance
    // mid-capture; neither belongs in a screenshot.
    await page.addStyleTag({ content: '.audio-controls{display:none !important}' });
    await page.evaluate(() => {
      document.querySelectorAll('audio').forEach(a => { a.pause(); a.autoplay = false; });
      Reveal.configure({ autoSlide: 0, loop: false, transition: 'none' });
    });

    const slides = await page.evaluate(() =>
      Reveal.getHorizontalSlides().map((s, h) => ({ h, id: s.id || `slide-${h}` })));
    console.log(`deck: ${slides.length} slides`);

    const chunks = [];
    let totalAudio = 0;

    for (const { h, id } of slides) {
      const png = path.join(BUILD, `slide${h}.png`);
      const mp3 = path.join(AUDIO_DIR, `slide${h}.0.mp3`);
      if (!fs.existsSync(path.join(root, mp3))) throw new Error(`missing audio: ${mp3}`);

      await page.evaluate(i => Reveal.slide(i, 0), h);
      // Wait on the NODE side.  An in-page promise built on requestAnimationFrame
      // never settles headless -- rAF is throttled when nothing is visible, which
      // hung evaluate() indefinitely.
      await new Promise(r => setTimeout(r, 450));
      // images: bounded in-page wait, never an open-ended promise
      await page.evaluate(() => Promise.race([
        Promise.all([...document.querySelectorAll('.present img')]
          .filter(i => !i.complete)
          .map(i => new Promise(r => { i.onload = i.onerror = r; }))),
        new Promise(r => setTimeout(r, 3000)),
      ]));
      await page.screenshot({ path: path.join(root, png), type: 'png' });

      const secs = duration(path.join(root, mp3));
      totalAudio += secs;

      // `-shortest` cannot be used with apad (it would cut the padding back
      // off), so the chunk length is set explicitly instead.
      const chunkSecs = LEAD_S + secs + TAIL_S;
      const chunk = path.join(BUILD, `chunk${h}.mp4`);
      run('ffmpeg', ['-y', '-loglevel', 'error',
        '-loop', '1', '-i', path.join(root, png),
        '-i', path.join(root, mp3),
        // adelay=...:all=1 applies to every channel whatever the layout;
        // a bare "adelay=450|450" errors on the mono clips ElevenLabs returns.
        '-af', `adelay=${Math.round(LEAD_S * 1000)}:all=1,apad`,
        '-c:v', 'libx264', '-tune', 'stillimage',
        '-c:a', 'aac', '-b:a', '192k',
        '-pix_fmt', 'yuv420p', '-r', '30',
        '-t', chunkSecs.toFixed(3), path.join(root, chunk)]);

      chunks.push(chunk);
      console.log(`  slide${h}  ${secs.toFixed(1)}s speech + ${(LEAD_S + TAIL_S).toFixed(2)}s pad = ${chunkSecs.toFixed(1)}s  ${id.slice(0, 34)}`);
    }

    const list = path.join(root, BUILD, 'concat.txt');
    fs.writeFileSync(list, chunks.map(c => `file '${path.join(root, c)}'`).join('\n') + '\n');

    run('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0',
                   '-i', list, '-c', 'copy', path.join(root, OUT)]);

    const got = duration(path.join(root, OUT));
    const want = totalAudio + slides.length * (LEAD_S + TAIL_S);
    console.log(`\n${OUT}  ${(fs.statSync(path.join(root, OUT)).size / 1e6).toFixed(1)} MB  ${got.toFixed(1)}s`);
    console.log(`speech ${totalAudio.toFixed(1)}s + padding ${(slides.length * (LEAD_S + TAIL_S)).toFixed(1)}s = ${want.toFixed(1)}s expected  (drift ${(got - want).toFixed(2)}s)`);
    if (Math.abs(got - want) > 1.5) {
      console.warn('WARNING: video length differs from the expected total by more than 1.5s');
    }
  } finally {
    await browser.close();
    server.close();
    if (!KEEP) fs.rmSync(path.join(root, BUILD), { recursive: true, force: true });
  }
})().catch(err => { console.error('FAILED:', err.message); process.exit(1); });
