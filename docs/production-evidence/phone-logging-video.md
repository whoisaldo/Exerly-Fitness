# Phone logging video on the landing page

September 22, 2026. Requested through `/brag`, then clarified to show logging on the phone and to contain no credits.

The finished film uses real iPhone 16 Pro simulator footage, recorded on iOS 18.6 against the isolated API on port 39003. A synthetic account chooses a recent chicken and avocado bowl, changes the quantity to 1.5 servings, saves it, and sees 780 calories in the diary. The native capture test also checks the saved entry count and water amount through the API.

The landing page has a 1920×1080 desktop cut and a 1080×1920 portrait cut below 640 px. Both run for 21 seconds at 30 fps. The phone fills more of the mobile frame so its logging controls remain readable. A poster loads before activation; no MP4 request is made until the person plays it. The player includes native controls, inline mobile playback, English captions, a text description and a load-error fallback. Reduced-motion preferences remove the section's entrance movement.

The user requested no credits. The final films use original synthesized instrumental music and original interface sounds. Credit text, links and the credit file were removed. No third-party music or sound effects remain in the delivered videos.

## Deliverables

- [Desktop video](../../brag-output/brag.mp4), 2,408,326 bytes.
- [Portrait video](../../brag-output/brag-portrait.mp4), 2,555,548 bytes.
- [Desktop poster](../../brag-output/brag.jpg) and [portrait poster](../../brag-output/brag-portrait.jpg).
- [Share caption](../../brag-output/share-copy.txt) and [rebuild instructions](../../brag-output/README.md).
- The corresponding public assets are in `apps/web/public/media`. [PhoneLoggingVideo](../../apps/web/src/components/landing/PhoneLoggingVideo.tsx) embeds them in the existing demo section.

## Verification

- `testLandingPagePhoneLoggingCapture` passes in `brag-output/phone-20260922-151853.xcresult`. The selected source, phase timestamps and reproducible capture script are retained. Earlier failed attempts exposed an off-screen final shot and the fixture's signup rate limit; neither take supplies the final film.
- Both Hyperframes checks pass with no runtime, layout, motion or contrast errors. Six reviewed authoring warnings per composition concern keeping the five short headline sections in one composition. [Desktop check](../../brag-output/verification/hyperframes-check.json), [portrait check](../../brag-output/verification/hyperframes-portrait-check.json).
- [Media inspection](../../brag-output/media-verification.json) confirms 630 frames, 21 seconds, the expected dimensions and unchanged audio after replacing frame zero with the selected poster.
- [Browser results](../../brag-output/verification/browser-results.json) pass desktop and mobile Chrome playback, keyboard or touch activation, seeking, captions, end-of-video behavior, absence of an initial MP4 download, mobile layout, and the network-error fallback. The mobile profile enables reduced motion. These are browser viewport checks, not a physical Safari result.
- [Desktop capture](../../brag-output/verification/desktop-poster.png) and [mobile capture](../../brag-output/verification/mobile-poster.png) show the final page.
- The web production build, TypeScript, changed-file ESLint and Prettier pass. The existing Vite bundle-size warning remains. The files are embedded in the local application; no public deployment occurred.

The preview is served on `http://100.80.149.7:3305/`. Both video URLs returned HTTP 200 through that address after packaging.
