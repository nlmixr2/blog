#!/usr/bin/env node
//
// render_presentation.js -- flatten the reveal.js deck into a single .mp4.
//
//   1. serve the deck over http (reveal + the audio plugin do XHR, which
//      file:// blocks, so a static server is not optional)
//   2. drive it with puppeteer, screenshotting each slide at 1920x1080
//   3. read each clip's true duration with ffprobe
//   4. ffmpeg: still image + its clip -> one chunk per slide
//      ...EXCEPT a slide carrying data-background-video, whose chunk is built
//      from the real .mp4 so the motion survives into the render
//   5. ffmpeg concat -> <deck>.mp4
//
// Usage:  node render_presentation.js [deck.html] [--keep]
//         --keep   leave build/ (pngs, chunks, concat list) in place
//
'use strict';

const http = require('http');
const path = require('path');
const fs = require('fs');
const { execFileSync } = require('child_process');
const puppeteer = require('puppeteer');

// Which narration to flatten in.  The ElevenLabs clips live in audio/ as
// .mp3; the free Piper draft pass writes audio-draft/ as .wav.  Both are
// named slide<h>.<v> + ext, so only the directory and extension change:
//   AUDIO_DIR=audio-draft AUDIO_EXT=.wav OUT_SUFFIX=-draft node render_presentation.js
const AUDIO_DIR = process.env.AUDIO_DIR || 'audio';
const AUDIO_EXT = process.env.AUDIO_EXT || '.mp3';
const OUT_SUFFIX = process.env.OUT_SUFFIX || '';
const BUILD = 'build';
const WIDTH = 1920, HEIGHT = 1080;
const FPS = 30;
const KEEP = process.argv.includes('--keep');

// Every chunk that goes into the concat must agree on these, because
// `-f concat -c copy` splices streams without re-encoding.  A background-video
// slide brings its own resolution, frame rate, SAR and audio layout, so they
// are normalised here rather than assumed.
const ARATE = 44100, ACH = 2, ABITS = '192k';

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

// The deck: first CLI arg, else the only .html sitting next to this script.
function findDeck(root) {
  const arg = process.argv.slice(2).find(a => /\.html?$/i.test(a));
  if (arg) return arg;
  const html = fs.readdirSync(root).filter(f => /\.html?$/i.test(f));
  if (html.length === 1) return html[0];
  throw new Error(html.length
    ? `several .html here (${html.join(', ')}) -- name one: node render_presentation.js <deck>.html`
    : 'no .html next to render_presentation.js -- render the .qmd first');
}

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
  '.mp3': 'audio/mpeg', '.mp4': 'video/mp4', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.json': 'application/json', '.woff': 'font/woff', '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
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

function hasAudio(file) {
  return run('ffprobe', ['-v', 'error', '-select_streams', 'a',
                         '-show_entries', 'stream=codec_type',
                         '-of', 'csv=p=0', file]).trim().length > 0;
}

// Fit any source into the deck's frame without cropping or stretching it:
// scale down to fit, then letterbox.  setsar=1 matters as much as the size --
// a mismatched sample aspect ratio breaks a `-c copy` concat.
const VFIT = `scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,`
           + `pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black,`
           + `setsar=1,fps=${FPS},format=yuv420p`;

const VENC = ['-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
              '-pix_fmt', 'yuv420p', '-r', String(FPS)];
const AENC = ['-c:a', 'aac', '-b:a', ABITS, '-ar', String(ARATE), '-ac', String(ACH)];

// A still frame held for `secs`, narrated by `mp3`.
function stillChunk(png, mp3, secs, out) {
  run('ffmpeg', ['-y', '-loglevel', 'error',
    '-loop', '1', '-i', png,
    '-i', mp3,
    // adelay=...:all=1 applies to every channel whatever the layout;
    // a bare "adelay=450|450" errors on the mono clips ElevenLabs returns.
    '-af', `adelay=${Math.round(LEAD_S * 1000)}:all=1,apad`,
    '-vf', VFIT,
    ...VENC, '-tune', 'stillimage', ...AENC,
    '-t', secs.toFixed(3), out]);
}

// The real video, re-encoded into the deck's frame and held for `secs`.
//
// `mp3` non-null  -> the slide is narrated: the video is the picture only, is
//                    looped to cover the narration, and the clip is the audio.
// `mp3` null      -> the video speaks for itself: its own audio is used, or
//                    silence if it has none.
function videoChunk(video, mp3, secs, out) {
  const args = ['-y', '-loglevel', 'error'];
  // -stream_loop repeats the input so a short sting can cover a longer
  // narration; -t below is what actually ends the chunk.
  args.push('-stream_loop', '-1', '-i', video);

  let afilter, amap;
  if (mp3) {
    args.push('-i', mp3);
    afilter = `[1:a]adelay=${Math.round(LEAD_S * 1000)}:all=1,apad[a]`;
    amap = '[a]';
  } else if (hasAudio(video)) {
    // apad, not loop: the sting's audio plays once and the tail is silence,
    // which is what a repeated whoosh under a held logo should sound like.
    afilter = '[0:a]apad[a]';
    amap = '[a]';
  } else {
    args.push('-f', 'lavfi', '-i', `anullsrc=r=${ARATE}:cl=stereo`);
    afilter = null;
    amap = '1:a';
  }

  const filter = `[0:v]${VFIT}[v]` + (afilter ? `;${afilter}` : '');
  args.push('-filter_complex', filter, '-map', '[v]', '-map', amap,
            ...VENC, ...AENC, '-t', secs.toFixed(3), out);
  run('ffmpeg', args);
}

(async () => {
  const root = __dirname;
  const DECK = findDeck(root);
  const OUT = DECK.replace(/\.html?$/i, '') + OUT_SUFFIX + '.mp4';

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
    //
    // Background videos are blocked for the same reason and one more: their
    // frames never reach the render anyway, because a background-video slide is
    // spliced from the file itself further down rather than screenshotted.
    await page.setRequestInterception(true);
    page.on('request', req =>
      /\.(mp3|mp4|m4a|webm|ogg)(\?|$)/i.test(req.url()) ? req.abort() : req.continue());
    // NOT networkidle*: the audio-slideshow plugin holds a connection open for
    // each clip, so the network never goes idle and goto() times out.
    // Wait for the DOM, then for reveal itself to report ready.
    await page.goto(`http://127.0.0.1:${port}/${DECK}`,
                    { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForFunction(() => window.Reveal && Reveal.isReady(),
                               { timeout: 120000 });

    // Anything painted OVER the deck has to go before capturing.  Two things
    // qualify: the audio plugin's player, and the click-to-start overlay the
    // deck shows so browsers will allow autoplay -- that one is
    // position:fixed;inset:0, is never dismissed headless, and so covers every
    // single screenshot.
    await page.addStyleTag({ content:
      '.audio-controls,#audio-start{display:none !important}' });
    await page.evaluate(() => {
      const o = document.getElementById('audio-start');
      if (o) o.remove();
      document.querySelectorAll('audio').forEach(a => { a.pause(); a.autoplay = false; });
      Reveal.configure({ autoSlide: 0, loop: false, transition: 'none' });
    });

    const slides = await page.evaluate(() =>
      Reveal.getHorizontalSlides().map((s, h) => {
        // data-background-video takes a comma-separated source list; the first
        // entry is the one a browser would actually play.
        const raw = s.getAttribute('data-background-video');
        return {
          h,
          id: s.id || `slide-${h}`,
          video: raw ? raw.split(',')[0].trim() : null,
          // An unmuted background video is the author saying its own audio is
          // the point; a muted one is a picture, so the narration is the audio.
          videoMuted: s.getAttribute('data-background-video-muted') === 'true',
        };
      }));
    console.log(`deck: ${slides.length} slides`);

    const chunks = [];
    let totalAudio = 0;

    for (const { h, id, video, videoMuted } of slides) {
      const chunk = path.join(BUILD, `chunk${h}.mp4`);
      const mp3 = path.join(AUDIO_DIR, `slide${h}.0${AUDIO_EXT}`);
      const hasMp3 = fs.existsSync(path.join(root, mp3));

      if (video) {
        const src = path.join(root, video);
        if (!fs.existsSync(src)) throw new Error(`missing background video: ${video}`);
        const vdur = duration(src);

        // Muted + narrated: the clip drives the length and the video loops
        // under it.  Otherwise the video drives the length and keeps its
        // own audio -- a narration clip would talk over it, so it is skipped
        // out loud rather than silently.
        const narrate = videoMuted && hasMp3;
        if (!narrate && hasMp3) {
          console.warn(`  slide${h}  NOTE: background video is unmuted, so ${mp3} is not used`);
        }
        if (videoMuted && !hasMp3) {
          console.warn(`  slide${h}  NOTE: background video is muted and has no narration clip -- using its own audio`);
        }

        const secs = narrate ? duration(path.join(root, mp3)) : vdur;
        const chunkSecs = narrate ? LEAD_S + secs + TAIL_S : secs + TAIL_S;
        totalAudio += secs;

        videoChunk(src, narrate ? path.join(root, mp3) : null, chunkSecs,
                   path.join(root, chunk));

        const how = narrate ? `${secs.toFixed(1)}s speech over ${vdur.toFixed(1)}s video (looped)`
                            : `${vdur.toFixed(1)}s video, own audio`;
        console.log(`  slide${h}  ${how} = ${chunkSecs.toFixed(1)}s  ${id.slice(0, 34)}  [VIDEO]`);
      } else {
        if (!hasMp3) throw new Error(`missing audio: ${mp3}`);
        const png = path.join(BUILD, `slide${h}.png`);

        await page.evaluate(i => Reveal.slide(i, 0), h);
        // Wait on the NODE side.  An in-page promise built on
        // requestAnimationFrame never settles headless -- rAF is throttled when
        // nothing is visible, which hung evaluate() indefinitely.
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
        stillChunk(path.join(root, png), path.join(root, mp3), chunkSecs,
                   path.join(root, chunk));

        console.log(`  slide${h}  ${secs.toFixed(1)}s speech + ${(LEAD_S + TAIL_S).toFixed(2)}s pad = ${chunkSecs.toFixed(1)}s  ${id.slice(0, 34)}`);
      }

      chunks.push(chunk);
    }

    const list = path.join(root, BUILD, 'concat.txt');
    fs.writeFileSync(list, chunks.map(c => `file '${path.join(root, c)}'`).join('\n') + '\n');

    run('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0',
                   '-i', list, '-c', 'copy', path.join(root, OUT)]);

    const got = duration(path.join(root, OUT));
    const pad = slides.reduce((s, x) => s + (x.video && !x.videoMuted ? TAIL_S : LEAD_S + TAIL_S), 0);
    const want = totalAudio + pad;
    console.log(`\n${OUT}  ${(fs.statSync(path.join(root, OUT)).size / 1e6).toFixed(1)} MB  ${got.toFixed(1)}s`);
    console.log(`content ${totalAudio.toFixed(1)}s + padding ${pad.toFixed(1)}s = ${want.toFixed(1)}s expected  (drift ${(got - want).toFixed(2)}s)`);
    if (Math.abs(got - want) > 1.5) {
      console.warn('WARNING: video length differs from the expected total by more than 1.5s');
    }
  } finally {
    await browser.close();
    server.close();
    if (!KEEP) fs.rmSync(path.join(root, BUILD), { recursive: true, force: true });
  }
})().catch(err => { console.error('FAILED:', err.message); process.exit(1); });
