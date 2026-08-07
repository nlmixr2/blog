#!/usr/bin/env python3
"""Regenerate the per-slide narration from the deck's speaker notes.

The deck keeps the real spelling; only the text SENT to ElevenLabs is
respelled.  eleven_multilingual_v2 does not support <phoneme> tags, so
pronunciation is controlled by respelling, which works on every model.

  python3 tts_generate.py --dry-run     # print what would be spoken
  python3 tts_generate.py               # ONE take, cut into audio/slide<h>.0.mp3
  python3 tts_generate.py --per-slide   # legacy: one request per slide
  python3 tts_generate.py --recut       # re-cut the cached take, no API call
"""
import re, sys, html, time, pathlib, requests

DECK   = pathlib.Path(__file__).with_name("nlmixr2-7.html")
OUT    = pathlib.Path(__file__).with_name("audio")
VOICE  = "Q2BxE1QwrstK5TvS1kaT"
# Back to multilingual_v2: it matches the cloned voice better than eleven_v3,
# which was tried for its audio tags.  v2 has NO tag support -- it reads
# "[cheerful][smiling]" out loud -- so the tag is empty and the warmth has to
# come from `style` instead.  Every SAY entry below is re-measured under v2.
MODEL  = "eleven_multilingual_v2"
TAG    = ""

# Continuity across slides comes from recording ONE take (see single_take()),
# so stability can be lower here and let more expression through; style is what
# gives the read its smile.
VOICE_SETTINGS = {"stability": 0.35, "similarity_boost": 0.75,
                  "style": 0.55, "use_speaker_boost": True,
                  # Past ~1.2 the spelled-out method names slur (1.18 turned
                  # FOCEI into "FOCEA").  Further pace is added in post via
                  # TEMPO below, which is free to retune with --recut.
                  "speed": 1.06}

# Pitch shifting made it sound less like the real voice, so it is off.
PITCH = 1.0
# The technical terms drag at the slower global `speed`, while the prose reads
# well.  The API has no per-word speed, so they are sped back up in post:
# TERM_TEMPO is the ratio that restores the old pace (1.12 / 1.06) for those
# words only.  Set to 1.0 to disable.
TERM_TEMPO = 1.12 / 1.06

# Word sequences to speed up, as they appear in a Scribe TRANSCRIPT (not as
# they are spelled in SAY).  Matched case-insensitively against runs of 1-3
# consecutive words.
TERM_TRANSCRIPTS = [
    r"F-?O-?C-?E-?I", r"S-?A-?E-?M", r"N-?L-?M-?I-?N-?B",
    r"B-?O-?B-?Y-?Q-?A", r"NL\s*Mixer\s*2", r"Rx?-?ODE\s*2",
    r"D-?O-?P-?\s*853", r"N-?L-?M-?I-?X-?R?\s*2",
]

# Extra pace applied in post, on top of the model's own `speed`.  atempo keeps
# the pitch where it is, so this brightens the delivery without altering timbre.
TEMPO = 1.02

# The take carries room tone at about -47 dB, while the renderer pads each
# slide with DIGITAL silence at -91 dB.  That 45 dB step is what makes the gap
# between slides audible -- the hiss vanishes rather than continuing.  Two
# things fix it: pull the floor down (highpass removes rumble, afftdn the
# broadband hiss), and fade the last fraction of a second so what noise is left
# ramps out instead of being cut off.
DENOISE  = "highpass=f=70,afftdn=nf=-40"
FADE_IN  = 0.05
FADE_OUT = 0.20
DRY    = "--dry-run" in sys.argv

# --- pronunciation -------------------------------------------------------
# Ordered: longer/more specific keys first so phi0 is not eaten by phi.
#
# Every entry below was chosen by measurement, not guesswork: each candidate
# was synthesised and then transcribed with ElevenLabs Scribe, and the spelling
# kept is the one whose transcript came back as the intended word.  Re-run the
# experiment with /tmp/probe.py if a new term needs adding.
#
# HYPHEN-SEPARATED CAPITALS: every letter is sounded, with little space
# between them, which is how these are actually said out loud.  Spaces work too
# but the model breathes between the letters and it drags -- chosen by ear from
# pronunciation-samples/, and confirmed by clip duration in the same carrier
# sentence (FOCEI 4.73s spaced vs 4.13s hyphenated).
# Forms that FAIL outright:
#   periods   "F.O.C.E.I."  -> "FOCI"   (letters dropped)
#   plain     "SAEM"        -> "SAM";  "NLMINB" -> "NLMNB"
#   phonetic  "eff-oh-see-ee-eye" -> "FOCEA"
# rxode2 is the exception: the plain token "RXODE2" is spelled out correctly
# by itself and is the tightest of nine variants tried.
#
# Greek letters must NOT be left as plain words: "eta" is read as the
# initialism E-T-A (estimated time of arrival).  Of six spellings tried in the
# real carrier sentence, several spellings ("eeta", "aytuh", "eightuh", "aita")
# all transcribe back as a lowercase "eta", i.e. said as a word rather than the
# ETA acronym -- but transcription CANNOT tell the vowels apart, and the vowel
# is the whole point.  "eightuh" was picked by ear from eta-samples/; it gives
# the AY sound that matches how "theta" is already read.  Plain "eta" and
# "etah" come back as "ETA"; the literal Greek character is read as "eye".
# "theta"/"thetas" are already correct as plain words and are left alone.
SAY = [
    (r"\bphi0\b",            "phi zero"),
    (r"\bFOCEI\b",           "F-O-C-E-I"),
    (r"\bfocei\b",           "F-O-C-E-I"),
    (r"\bSAEM\b",            "S-A-E-M"),
    (r"\bsaem\b",            "S-A-E-M"),
    (r"\bBOBYQA\b",          "B-O-B-Y-Q-A"),
    (r"\bbobyqa\b",          "B-O-B-Y-Q-A"),
    (r"\bnlmixr2\b",         "N L mixer two"),
    (r"\brxode2\b",          "RXODE2"),
    (r"\bn1qn1\b",           "N one Q N one"),
    (r"\bnlminb\b",          "N-L-M-I-N-B"),
    (r"L-BFGS-B3c|\blbfgsb3c\b", "L B F G S B three C"),
    (r"\bDOP853\b",          "D-O-P 853"),       # letters, not "dop"
    (r"\bOctave\b",          "Ock-tayve"),       # GNU Octave: long a
    (r"\bHidde\b",           "Hiddee"),          # one word; "Hid-ee" split in two
    (r"\bBayesian\b",        "Bayzian"),
    (r"\betas\b",            "eightuhz"),   # plural: "eightuhs" was heard as "ADHS"
    (r"\beta\b",             "eightuh"),
]

# No inline <break> tags.  They were what made the delivery sound clipped and
# robotic; ordinary punctuation already gives the model natural sentence
# rhythm.  The audible gap BETWEEN slides is real silence added by ffmpeg in
# render_presentation.js, which is also what stops the first word being clipped.


def slides_from(deck: pathlib.Path):
    h = deck.read_text()
    body = h.split('<div class="slides">', 1)[1]
    secs = [s for s in re.split(r"(?=<section )", body)
            if s.lstrip().startswith("<section ")]
    out = []
    for i, s in enumerate(secs):
        m = re.search(r'<aside class="notes">(.*?)</aside>', s, re.S)
        if m:                                   # normal slide
            frag = re.sub(r"<(style|script)\b.*?</\1>", "", m.group(1), flags=re.S | re.I)
            # A markdown list in the notes becomes <li>...</li>; stripping tags
            # blindly welds the items into one run-on sentence that the model
            # reads without pausing.  Make each block a sentence boundary.
            frag = re.sub(r"</(li|p|h[1-6]|div)>", ". ", frag, flags=re.I)
            frag = re.sub(r"<br\s*/?>", ". ", frag, flags=re.I)
            t = html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", frag))).strip()
            t = re.sub(r"\s*\.\s*\.", ".", t)          # no ".." from items that
            t = re.sub(r"([,;:])\s*\.", r"\1", t)      # already ended in punctuation
            t = re.sub(r"\.\s*$", ".", t).strip()
        else:                                   # title slide uses data-notes
            d = re.search(r'data-notes="([^"]*)"', s)
            t = html.unescape(d.group(1)).strip() if d else ""
        sid = (re.search(r'id="([^"]+)"', s) or [None, f"slide-{i}"])[1]
        if not t:
            sys.exit(f"slide {i} ({sid}) has no transcript -- aborting")
        out.append({"h": i, "id": sid, "raw": t})
    return out


def spoken(text: str) -> str:
    t = text
    # An en/em dash marks a parenthetical.  Flattening it to "-" gives no
    # pause at all; a comma is what the model actually breathes on.
    for a, b in [("’", "'"), ("‘", "'"), ("“", '"'),
                 ("”", '"'), (" – ", ", "), (" — ", ", "),
                 ("–", ","), ("—", ",")]:
        t = t.replace(a, b)
    t = re.sub(r",\s*,", ",", t)
    t = re.sub(r",\s*([.!?])", r"\1", t)
    for pat, rep in SAY:
        t = re.sub(pat, rep, t)
    # an initialism already ends in "." -- collapse the doubled stop it makes
    # at the end of a sentence ("S.A.E.M.." -> "S.A.E.M.")
    t = re.sub(r"\.{2,}", ".", t)
    # a list item that already ended in punctuation leaves an orphan " ."
    t = re.sub(r"\s+\.(?=\s|$)", "", t)
    parts = [p for p in re.split(r"(?<=[.!?])\s+", t) if re.search(r"\w", p)]
    return re.sub(r"\s+", " ", " ".join(parts)).strip()


def speed_up_terms(path, key):
    """Re-time just the technical terms inside one finished clip.

    Word timings come from Scribe, i.e. from the RENDERED audio -- unlike the
    TTS character alignment, which drifts.  The clip is split at the silences
    BETWEEN words, so the joins land in gaps rather than mid-syllable.
    """
    import json, subprocess, tempfile
    if TERM_TEMPO == 1.0:
        return 0
    r = requests.post("https://api.elevenlabs.io/v1/speech-to-text",
                      headers={"xi-api-key": key}, data={"model_id": "scribe_v1"},
                      files={"file": open(path, "rb")}, timeout=180)
    if r.status_code != 200:
        return 0
    words = [w for w in r.json().get("words", []) if w.get("type") == "word"]
    if not words:
        return 0

    spans, i = [], 0
    while i < len(words):
        hit = None
        for n in (3, 2, 1):                       # longest match wins
            if i + n > len(words):
                continue
            joined = " ".join(w["text"] for w in words[i:i + n])
            if any(re.fullmatch(p, joined, re.I) for p in TERM_TRANSCRIPTS):
                hit = (words[i]["start"], words[i + n - 1]["end"], n)
                break
        if hit:
            spans.append((hit[0], hit[1])); i += hit[2]
        else:
            i += 1
    if not spans:
        return 0

    total = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                                  "format=duration", "-of", "default=nw=1:nk=1",
                                  str(path)], capture_output=True, text=True).stdout)
    # widen each span into the surrounding gap so the cut is in silence
    PAD = 0.02
    spans = [(max(0.0, a - PAD), min(total, b + PAD)) for a, b in spans]

    with tempfile.TemporaryDirectory() as td:
        td = pathlib.Path(td)
        parts, cur, n = [], 0.0, 0
        def seg(a, b, tempo):
            nonlocal n
            if b - a < 0.02:
                return
            out = td / f"{n:03d}.wav"; n += 1
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{a:.3f}",
                   "-to", f"{b:.3f}", "-i", str(path)]
            if tempo != 1.0:
                cmd += ["-af", f"atempo={tempo}"]
            cmd += ["-ar", "44100", "-ac", "1", str(out)]
            subprocess.run(cmd, check=True)
            parts.append(out)
        for a, b in spans:
            seg(cur, a, 1.0)
            seg(a, b, TERM_TEMPO)
            cur = b
        seg(cur, total, 1.0)
        lst = td / "list.txt"
        lst.write_text("".join(f"file '{p}'\n" for p in parts))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat",
                        "-safe", "0", "-i", str(lst),
                        "-c:a", "libmp3lame", "-b:a", "192k", str(path)], check=True)
    return len(spans)


def api_key() -> str:
    for line in (pathlib.Path.home() / ".bashrc").read_text().splitlines():
        if line.startswith("export ELEVENLABS_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("no ELEVENLABS_API_KEY in ~/.bashrc")


def single_take(slides, key):
    """Record all slides in ONE request, then cut it at the slide boundaries.

    Generating each slide separately made every clip its own performance --
    the speaker audibly reset between slides.  One request is one continuous
    read, so the tone carries across the whole deck; /with-timestamps gives
    per-character times, which is what lets it be cut back apart exactly.
    """
    import base64, json, subprocess, tempfile

    # The whole take is cached so the cutting can be re-tuned without paying
    # to synthesise it again -- see --recut.
    CACHE = pathlib.Path(__file__).with_name(".take")
    CACHE.mkdir(exist_ok=True)
    RECUT = "--recut" in sys.argv

    SEP = "\n\n"                       # a real beat between slides
    # eleven_v3 needs a run-up: the opening seconds of a take come out in the
    # wrong voice before it settles.  Record a throwaway line first and drop
    # its clip, so slide 0 begins on an already-warmed-up voice.
    PRIME = TAG + "Right, let us get started."
    combined, spans = PRIME + SEP, []
    for s in slides:
        start = len(combined)
        combined += TAG + s["say"]
        spans.append((start, len(combined)))
        combined += SEP
    combined = combined[: -len(SEP)]
    print(f"single take: {len(combined)} characters, {len(slides)} slides")

    if RECUT:
        if not (CACHE / "take.json").exists():
            sys.exit("no cached take to re-cut; run without --recut first")
        data = json.loads((CACHE / "take.json").read_text())
        print("re-cutting the cached take (no API call)")
    else:
        r = requests.post(
            f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE}/with-timestamps",
            headers={"xi-api-key": key, "Content-Type": "application/json"},
            json={"text": combined, "model_id": MODEL,
                  "voice_settings": VOICE_SETTINGS}, timeout=600)
        if r.status_code != 200:
            sys.exit(f"with-timestamps: HTTP {r.status_code} {r.text[:300]}")
        data = r.json()
        (CACHE / "take.json").write_text(json.dumps(data))
    al = data["alignment"]
    chars, ends = al["characters"], al["character_end_times_seconds"]
    starts = al["character_start_times_seconds"]
    if len(chars) != len(combined):
        sys.exit(f"alignment length {len(chars)} != text length {len(combined)}; "
                 "cannot cut safely")

    OUT.mkdir(exist_ok=True)
    if True:
        full = CACHE / "full.mp3"
        full.write_bytes(base64.b64decode(data["audio_base64"]))
        total = float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", str(full)],
            capture_output=True, text=True).stdout.strip())

        # The character alignment is only a HINT.  Under eleven_v3 it drifts
        # from the real audio (cuts landed mid-word: a clip would open with
        # "CEI." left over from the previous slide's "FOCEI").  The blank line
        # between slides produces genuine silence, so find those gaps and snap
        # each boundary to the nearest one.  Verified by transcribing every
        # clip afterwards -- see --verify.
        det = subprocess.run(
            ["ffmpeg", "-hide_banner", "-nostats", "-i", str(full),
             "-af", "silencedetect=noise=-32dB:d=0.18", "-f", "null", "-"],
            capture_output=True, text=True).stderr
        gaps = []
        for m in re.finditer(r"silence_start: ([\d.]+)(?:.|\n)*?silence_end: ([\d.]+)", det):
            gaps.append((float(m.group(1)), float(m.group(2))))
        print(f"detected {len(gaps)} silent gaps for {len(slides) - 1} boundaries")

        def snap(t, window=1.2):
            """Nearest silence midpoint WITHIN `window` seconds of t, else t.

            The window matters: an unbounded search let a boundary jump to a
            silence minutes away, which produced non-monotonic cuts
            (ffmpeg: "-to value smaller than -ss").  Keep it tight -- at 2.5s a
            boundary skipped a sentence-internal pause and swallowed "To
            summarize," off the front of a slide.
            """
            best, bd = t, window
            for g0, g1 in gaps:
                mid = (g0 + g1) / 2
                if abs(mid - t) < bd:
                    best, bd = mid, abs(mid - t)
            return best

        # bounds[0] ends the throwaway priming line; slide k spans
        # bounds[k] -> bounds[k+1].  Hints come from the alignment (monotonic
        # by construction); each is then snapped to nearby real silence.
        hints = [(ends[len(PRIME) - 1] + starts[spans[0][0]]) / 2]
        for k in range(len(slides) - 1):
            hints.append((ends[spans[k][1] - 1] + starts[spans[k + 1][0]]) / 2)
        bounds = []
        for h in hints:
            b = snap(h)
            # never go backwards, and always leave room for the next clip
            if bounds and b <= bounds[-1] + 0.30:
                b = max(h, bounds[-1] + 0.30)
            bounds.append(min(max(b, 0.0), total - 0.05))
        bounds.append(total)
        assert all(bounds[i] < bounds[i + 1] for i in range(len(bounds) - 1)), \
            f"non-monotonic cut boundaries: {bounds}"
        print(f"discarding {bounds[0]:.2f}s of priming audio")

        for idx, (s, (a, b)) in enumerate(zip(slides, spans)):
            t0, t1 = bounds[idx], bounds[idx + 1]
            t0 = max(0.0, t0 - 0.10)
            t1 = min(total, t1 + 0.10)
            dest = OUT / f"slide{s['h']}.0.mp3"
            # -ss/-to MUST come before -i.  As output options they make ffmpeg
            # seek within the decoded stream, which fails on the last frames of
            # an mp3 ("Could not seek to ...") and writes a truncated file --
            # the final slide came out as 671 bytes of nothing.
            cmd = ["ffmpeg", "-y", "-loglevel", "error",
                   "-ss", f"{t0:.3f}", "-to", f"{t1:.3f}", "-i", str(full)]
            af = []
            if DENOISE:
                af.append(DENOISE)
            if PITCH != 1.0:
                af.append(f"rubberband=pitch={PITCH}:formant=preserved")
            if TEMPO != 1.0:
                af.append(f"atempo={TEMPO}")
            # fades come last, so their times are on the post-tempo timeline
            out_dur = (t1 - t0) / TEMPO
            if FADE_IN:
                af.append(f"afade=t=in:st=0:d={FADE_IN}")
            if FADE_OUT and out_dur > FADE_OUT * 2:
                af.append(f"afade=t=out:st={out_dur - FADE_OUT:.3f}:d={FADE_OUT}")
            if af:
                cmd += ["-af", ",".join(af)]
            cmd += ["-c:a", "libmp3lame", "-b:a", "192k", str(dest)]
            subprocess.run(cmd, check=True)
            nterms = speed_up_terms(dest, key)
            print(f"slide{s['h']}.0  {t0:7.2f}-{t1:7.2f}s  "
                  f"{t1 - t0:5.1f}s  {dest.stat().st_size:>7} bytes"
                  f"{f'  ({nterms} terms re-timed)' if nterms else ''}")
    print(f"\ncut {len(slides)} clips from one {total:.1f}s take")


def main():
    slides = slides_from(DECK)
    for s in slides:
        s["say"] = spoken(s["raw"])

    if DRY:
        for s in slides:
            print(f"--- slide{s['h']}.0  ({s['id'][:44]}) ---")
            print(s["say"])
            print()
        print(f"{len(slides)} slides, {sum(len(s['say']) for s in slides)} characters")
        return

    key = api_key()
    if "--per-slide" not in sys.argv:
        return single_take(slides, key)

    OUT.mkdir(exist_ok=True)
    sess, billed = requests.Session(), 0
    for k, s in enumerate(slides):
        payload = {
            "text": s["say"],
            "model_id": MODEL,
            "voice_settings": VOICE_SETTINGS,
        }
        if k:                       # context only -- never spoken
            payload["previous_text"] = slides[k - 1]["say"]
        if k + 1 < len(slides):
            payload["next_text"] = slides[k + 1]["say"]

        for attempt in (1, 2, 3):
            r = sess.post(f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE}",
                          headers={"xi-api-key": key, "Content-Type": "application/json"},
                          json=payload, timeout=180)
            if r.status_code == 200:
                break
            if r.status_code == 429 and attempt < 3:
                time.sleep(5 * attempt)
                continue
            sys.exit(f"slide{s['h']}.0: HTTP {r.status_code} {r.text[:200]}")

        dest = OUT / f"slide{s['h']}.0.mp3"
        dest.write_bytes(r.content)
        billed += len(s["say"])
        print(f"slide{s['h']}.0  {len(s['say']):>5} chars -> {dest.stat().st_size:>8} bytes")
        time.sleep(0.3)
    print(f"\n{len(slides)} clips, {billed} characters billed")


if __name__ == "__main__":
    main()
