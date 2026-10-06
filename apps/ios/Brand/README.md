# Exerly brand artwork

The app uses Exerly's established purple E/pulse symbol. The source reference is
`apps/web/src/components/Assets/ExerlyLogo.jpg`. Ali asked to restore this identity
and the purple/pink interface on 2026-10-06 after rejecting the unrelated mint icon.

`ExerlyMark.png` was adapted with the built-in image tool: preserve the original
purple E/pulse symbol, remove the wordmark, center it on an opaque white square,
retain its geometry and color, and add no effects or extra details. The source is
preserved here. `swift apps/ios/scripts/render-icon.swift` packages it as an opaque
1024px sRGB app icon without changing the design. iOS supplies the corner mask.
