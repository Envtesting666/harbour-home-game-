# Recorded contract audio

Retrieved 2026-11-04. All three distributed WAV files are derived from real recordings released under CC0 1.0; attribution is retained here as provenance. No musical chord, synthetic writing noise, pitch shift or time stretching is used for these contract sounds.

## Signing a signature — Froey_

- Original publisher and license: https://freesound.org/people/Froey_/sounds/818441/
- Author: Froey_; published 2025-08-04. Recording description: real pen signature, Sony ICD-UX570.
- The author's page explicitly labels this recording Creative Commons 0 and permits modification, distribution and commercial use.
- License: https://creativecommons.org/publicdomain/zero/1.0/
- Public high-quality preview used: https://cdn.freesound.org/previews/818/818441_8331855-hq.mp3
- `signature_pen.wav`: original-speed mono excerpt 0.68–1.28 s, high-pass 110 Hz / low-pass 5200 Hz, peak normalization to 0.62, 6 ms edge fades, 44.1 kHz / 16-bit PCM.
- `contract_paper.wav`: original-speed contact/rustle excerpt 0.29–0.46 s, high-pass 120 Hz / low-pass 4300 Hz, peak 0.20, 6 ms edge fades, 44.1 kHz / 16-bit PCM.

## Clicks pen — Joseph SARDIN / BigSoundBank

- Original publisher and license: https://bigsoundbank.com/clicks-pen-s0810.html
- Author: Joseph SARDIN. Sound number 810; studio recording of a retractable ballpoint pen.
- The author's page explicitly labels this sound CC0 (public domain), permits commercial redistribution and modification, and says attribution is optional.
- Publisher's license explanation: https://bigsoundbank.com/licenses.html
- Public original recording used: https://bigsoundbank.com/UPLOAD/bwf-en/0810.wav
- `signature_finish.wav`: original-speed single mechanical click excerpt 0.70–0.87 s, high-pass 90 Hz / low-pass 4000 Hz, peak 0.30, 6 ms edge fades, converted 48 kHz→44.1 kHz / 16-bit mono PCM. This is a pen click, not a recorded rubber stamp.

## Reproduction and evidence

The production preparation script, downloaded sources, primary publisher HTML evidence, WAV metrics and native playback test are stored outside the shipped game under `work/real-foley-qa`. `signature_demo.wav` (also exposed as `sounds.signature`) joins 0.55 s of pen writing to the 0.17 s mechanical finish for a 0.72 s demonstration. Game playback retains the existing `begin_pen`, `stop_pen`, `play_signature`, `play_paper` and volume/mute API.

All asset WAVs are imported as uncompressed PCM16 (`compress/mode=0`) to keep loop boundaries and native WAV QA deterministic.
