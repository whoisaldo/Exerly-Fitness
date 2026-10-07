# Exerly phone logging video

The film records the actual iPhone app choosing a recent meal, changing its portion to 1.5 servings, saving it, and showing the updated diary. The synthetic meal becomes 780 calories. Footage came from the iPhone 16 Pro simulator on iOS 18.6 and an isolated local API.

Both cuts run for 21 seconds at 30 fps. `brag.mp4` is 1920×1080 for desktop. `brag-portrait.mp4` is 1080×1920 for narrow screens. The landing page chooses a format when playback starts and keeps that choice if the window resizes. Posters load first; the MP4 is requested only after activation. Native controls, captions and a text description are included.

The soundtrack and interface sounds are original synthesized audio, with source in `make-soundtrack.py`. The delivered films and landing-page player have no credits. Font and runtime license files remain with the development assets.

## Rebuild

From the repository root:

```sh
uv run --with numpy python brag-output/make-soundtrack.py
uv run --with numpy python /Users/aldo/.agents/skills/hyperframes-creative/scripts/extract-audio-data.py brag-output/composition/assets/music/bed.wav -o brag-output/composition/assets/music/energy.json
python3 brag-output/build-composition.py
npx --yes hyperframes@0.8.61 check brag-output/composition
npx --yes hyperframes@0.8.61 check brag-output/portrait
npx --yes hyperframes@0.8.61 render brag-output/composition --quality high --fps 30 --workers 4 --video-frame-format png --output brag-output/brag.render.mp4
npx --yes hyperframes@0.8.61 render brag-output/portrait --quality high --fps 30 --workers 4 --video-frame-format png --output brag-output/brag-portrait.render.mp4
python3 brag-output/package-video.py
node scripts/verify-phone-video.cjs
```

The packaging script extracts the settled portion frame at 12.8 seconds, replaces only frame zero, preserves the encoded audio, verifies all 630 frames and dimensions, and installs both MP4s and posters in `apps/web/public/media`. Verification expects the landing-page server on port 3305, or `PLAYWRIGHT_BASE_URL`.

`phone-capture.json` records the successful capture and phase timestamps. `composition/assets/ui/phone-source.mp4` preserves the original footage. The builder can use this copy if the timestamped raw take is absent. Raw takes and Xcode bundles remain local and are ignored by Git. New takes require an isolated API on port 39003, the selected simulator and `record-phone.py`; they must be visually reviewed before editing.

`share-copy.txt` contains the caption. `verification/` holds browser results, screenshots and composition checks. `media-verification.json` records dimensions, frame counts, duration and audio hashes before and after poster insertion.
