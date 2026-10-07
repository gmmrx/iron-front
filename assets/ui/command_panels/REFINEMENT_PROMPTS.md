# Flag material and government research artwork

Generated with the built-in ImageGen tool (not the API/CLI). Source outputs are retained in the Codex generated-images directory. Both final PNGs are copied into this directory and used by the actual Godot UI.

## Integration and verification — 2026-10-06

- Politics: national-condition cards replace the visible State Program block. The State Program runtime is disabled separately; see `docs/focus-disabled.md` for legacy-save limits.
- Diplomacy: the cloth shader retains the actual national flag texture and aspect ratio. Portrait and flag form a compact dossier vignette.
- Research: project catalog, independent dossier scrolling, persistent start/cancel action, and themed confirmation for government changes. Military/industry technologies and existing research progress remain intact.
- New government choices: democratic, fascist, communist and non-aligned. Authoritative costs/conditions are in `data/common/technologies.json::government_projects`; 180 calendar days, 100 upfront influence, one slot, temporary administrative penalties. Loading does not charge again.
- 91 targeted tests passed across command panels (7), dossiers (7), government research (9), Focus disabled (7), politics (14), history (7), UI panels (5), world events (8), save/load (3), open-game/repeat research (10), and data (14). Data validation retains an existing warning for 88 missing English descriptions in the now-inactive Focus definitions.
- Actual game captures checked at 1920×1080 and 1280×720 using Forward+/Metal and Compatibility/OpenGL, including government cards, military catalog and confirmation dialog. Panel bounds, caption bounds, pinned action and rapid-refresh scroll checks pass. This is not a browser-export test.
- Captures: `art/previews/command_panels/` and `art/previews/command_panels/gl_compatibility/`. Runtime capture logger: `COMMAND_PANELS errors=[]` in both renderers. Known engine teardown RID/resource warnings remain after capture; this does not claim a clean shutdown audit.

## `flag_cloth_v1.png`

Reference: the user-supplied `Sovyetler Birliği Diplomasi Ekranı.png`, used only as a material/style reference. The game uses the existing historical flag image, preserving its colors, emblem and aspect ratio; this neutral texture supplies static cloth lighting through `dossier_flag.gdshader`. No per-frame waving or procedural flag replacement.

Prompt:

> Use case: product-mockup. Asset type: grayscale lighting and fabric material texture for a WW2 strategy game's diplomatic flag, to multiply with an existing correctly colored national flag at runtime. Input image 1 is STYLE REFERENCE ONLY: emulate the subtle real cloth folds of the red Soviet flag in the central dossier, NOT the screen itself. Generate ONLY ONE plain monochrome gray-white fabric surface, entire canvas covered edge-to-edge, landscape 3:2 ratio, orthographic flat front view. Refined matte woven silk/cotton with two or three gentle broad diagonal undulations, shallow depth, very fine weave, softly lit upper left, grayscale luminosity predominantly 70 to 95 percent with soft muted valleys. This is a neutral shading texture: NO national colors, NO symbols, NO insignia, NO text, NO frame, NO border, NO UI, NO dark background, NO surrounding empty space, no extreme black folds, no crumpled paper. Keep the cloth predominantly calm and readable when displayed as a 180px flag.

## `statecraft_v1.png`

Reference: user-supplied `Panel de Política y Estrategia Nacional.png`, used only as an illustration/style reference. This is the common constitutional-reform illustration for government-transition research, not a specific ideology's emblem.

Prompt:

> Use case: historical-scene. Asset type: square illustrated research card artwork for a 1936 grand strategy game. Input image is a style reference ONLY: match its national spirit illustrations, desaturated sepia oil-painted realism, almost black navy shadows, aged warm brass highlights and restrained archival atmosphere. Create a SINGLE square full-bleed high-detail scene representing constitutional and government reform: a 1930s oak cabinet table seen in three-quarter close-up, an open unmarked constitutional document with a fountain pen, a brass seal and a distant softly lit parliamentary chamber beyond, no people in foreground. Clear recognisable forms even at 100 pixels. Serious period strategy artwork, dark edges and luminous warm center, authentic paper, metal and wood. No legible text, no numbers, no national flag, no extremist symbol, no banners, no frame or UI, no modern items. Whole canvas must be the illustration, not an icon floating on a background.
