# Exerly iPhone composition brief

Make a 21-second landscape film, 1920×1080 at 30 fps, primarily showing real logging on an iPhone. Follow brag-plan.md. This replaces the initial desktop-focused draft after the user's clarification.

Source: iPhone 16 Pro simulator recording produced by record-phone.py and the opt-in testLandingPagePhoneLoggingCapture UI journey. The native app and real API handle all logging against a synthetic account on isolated port 39003. Use actual food selection, portion entry, save, and resulting diary totals. The phone must remain the largest product visual, with no desktop dashboard footage. Label iPhone app preview and demo data; do not imply App Store release.

Use one Hyperframes GSAP timeline with local media, music, Inter font, and runtime. Render the source footage inside a restrained phone frame. Preserve the native interface exactly. Use the catalog's line-by-line-slide recipe for the opening hook. Each selected source range is a separate framework-controlled media clip with explicit placement and source offset. No timers or runtime media seeking code.

Audio: original synthesized 110 BPM instrumental with fade, volume 0.55, and original soft interface sounds. No narration or credits. Use the same soundtrack and logging sequence in the 1080×1920 mobile version.

Validate runtime, layout, contrast, and motion with Hyperframes check; inspect settled and final frames and a phone-motion keyframe strip. Verify the MP4 and poster with ffprobe and frame extraction. Finally test landing-page playback, mobile layout, reduced motion, and absence of automatic playback or early video downloads.
