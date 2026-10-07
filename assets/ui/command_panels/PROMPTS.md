# Reference-derived command panel assets — v3

Generated with the built-in ImageGen tool (not CLI), using the user's supplied diplomacy screenshot as the explicit visual reference. Each image was generated individually and copied unmodified into this directory; original source outputs are retained. No UI labels, values or actions are baked into these assets.

Runtime integration: `game/ui/command_panel_skin.gd` + `command_panel_surface.gd`. Independent source/display nine-slice margins keep ornamental edges small and consistent. The header source contains two strips; only the first strip's `Rect2(2, 3, 2168, 154)` is used, excluding white gutters. Texture assets are scoped to framed panels; top HUD/navigation are unchanged.

## Validation (2026-10-06)

- `test_command_panels`: 5 tests passed (asset bindings, real alpha, local theme, research filtering/start/cancel, uncropped artwork).
- `test_command_dossiers`: 6 tests passed (real data, read-only foreign laws, country search/actions, minimum widths, scroll retention).
- Existing `test_ui_panels`: 5 tests passed.
- Actual Main-scene captures at 1920×1080 and 1280×720 for all three panels; no panel or research-caption overflow. Forward+ captures additionally exercise scroll preservation across refresh.
- Both Forward+/Metal and Compatibility/OpenGL rendering paths exercised. This is not a browser-export test.
- Captures: `art/previews/command_panels/` and its `gl_compatibility/` subdirectory.
- Runtime capture logger reports `errors=[]`. Godot still prints resource/RID cleanup diagnostics during process teardown; these are not counted as a clean shutdown. The existing top HUD utility/time overlap at 1280 is outside this panel-interior change.
- Existing advisor illustrations and technology plates are reused; global HUD/navigation, gameplay rules, country values and save formats are not redesigned.

## window_v3.png

Use case: stylized-concept.
Asset type: production bitmap UI asset for the interior of a WWII grand strategy game. One standalone EMPTY main window panel backplate.
Input Image 1 is the exact STYLE REFERENCE, especially the large diplomacy window frame and its blue-black inside. Match it faithfully, not a different design language.
Generate a landscape 3:2 rectangle, perfectly frontal orthographic, fills the entire canvas edge to edge. One thin precisely machined aged brass/gold outer frame with extremely small elegant ornamental corner fittings, slim black inner bevel. Broad uninterrupted EMPTY blue-black charcoal satin steel interior, almost smooth with very subtle low-contrast grain, darkest around #071015, center around #0b151a. Refined game interface craftsmanship, subtle physically plausible edge specular highlights; not bright gold jewelry, not steampunk.
Frame lies right at image edges. Keep all corner decoration within the outermost 3 percent so this works as a nine-slice game panel. Interior has NO subdivisions, no header band, no slots, no separate frames, no objects. No letters, words, typography, symbols, flags, pictures or UI content. No map, no external background, no perspective or cast shadow outside. No noisy speckled grunge, no heavy scratches, no big gradients, no bright center glow. Crisp production asset, NOT a full screen mockup. Opaque image.

## inset_v3.png

Use case: stylized-concept.
Asset type: one EMPTY inset section panel backplate for a WWII strategy game, production bitmap UI asset.
Image1 is exact style reference: match the subdued inset boxes around NATIONAL SPIRIT and DIPLOMATIC ACTIONS inside that diplomacy screen, NOT the ornamental gold outer window.
Landscape 3:2 rectangular plate, perfectly front-facing, fills canvas edge to edge. A very thin subtle gunmetal-steel raised perimeter bevel, crisp outer dark outline and faint cool silver upper edge. Interior nearly black charcoal with hint of navy #0b1317, almost smooth satin metal, only faint refined micrograin. Lighting extremely restrained, deliberately quiet behind dense readable text. No gold ornaments. Edges straight and square, corner radius at most 4 pixels at 1536 wide. All frame pixels within outermost 2 percent for nine-slice scaling.
One empty uninterrupted interior. No header bar, subdivisions, icons, text, labels, pictures, slots, contents or symbols. No map or external scene. No perspective, no outside shadows. No leather texture, scratches, patches, speckled noise, industrial grunge or obvious glow. Match the reference UI as an authentic game asset, not a website card. Opaque output.

## header_sheet_v3.png

Use case: stylized-concept.
Asset type: ONE empty SECTION TITLE BAR game UI sprite.
Image1 is exact reference. Reconstruct the narrow dark slate heading strips above DIPLOMATIC ACTIONS, NATIONAL SPIRIT and RELATION HISTORY, but with absolutely NO text.
Output very wide landscape 3:1 aspect ratio, edge-to-edge single rectangular horizontal title strip. Face-on orthographic. Restrained blue-charcoal almost-smooth satin steel, slightly lighter than the black content areas, faint convincing fine patina, thin dark-steel edge at top and sides, one hairline muted aged-gold divider running continuously along bottom edge. Tiny precise inset bevel. Elegant WWII strategy-game military dossier interface, matches Image1 closely.
Entire canvas is the one bar. All edge detail within outermost 2 percent. Interior blank, uninterrupted, quiet. No icons, letters, words, text, corner scrollwork, rivets, boxes, subdivisions or extra bars. No background outside, no external shadow, no perspective, no thick gold border, no noisy grunge. Opaque production-ready asset suitable for nine-slice scaling.

## button_v3.png

Use case: stylized-concept.
Asset type: ONE empty rectangular inactive button / action row UI backplate for a WWII grand strategy game.
Image 1 is style reference. Match the understated action buttons inside DIPLOMATIC ACTIONS: nearly black blue-slate satin metal with a very fine steel edge and small precise bevel. Subtle soft upper edge highlight, deep navy black interior. Premium restrained historical military strategy interface, NOT steampunk or fantasy.
Landscape 3:1 composition. The SINGLE rectangle fills the ENTIRE canvas: no whitespace, margins, gaps, outside background or duplicates. All detail within outermost 1.5 percent; the blank centre is very smooth and quiet, minimal fine microtexture.
No text, icons, symbols, gold decorations, pictures, contents, rows, subdivisions or internal frames. No gradients or bright spots inside. Exact straight frontal shape suitable for nine-slice UI integration. Opaque.

## selected_v3.png

Use case: stylized-concept.
Asset type: ONE empty SELECTED button / selected country row UI backplate for a WWII grand strategy game.
Image1 is exact style reference. Match the selected Soviet Union country-list row and selected gold tabs. Landscape 3:1. Single rectangle filling every pixel of canvas edge-to-edge, no external space. Front-facing blue-black steel button with a very thin warm aged-brass gold perimeter and delicate inner gold highlight, gently warm dark central surface. Dark interior remains near #101615, no large gradients; fine smooth satin microtexture. Refined restrained historical strategy UI, entirely usable behind ivory text.
Small cut/beveled corners, all edge detail within outermost 1.5 percent for nine-slice scaling. Selected state should be unmistakable yet dignified: precise bright muted-gold outline, NOT glowing neon and NOT a thick ornate frame.
NO text, symbols, icons, subdivisions, multiple buttons, extra rows, whitespace, map, objects, pictures or outside shadow. Opaque production bitmap, ONE backplate only.

## diplomacy_v3.png

Use case: stylized-concept.
Asset type: standalone transparent gold diplomacy icon for this WWII strategy-game UI.
Image1 is exact style reference. Make one readable simple clasped handshake emblem in the same warm brushed brass/gold sculpted illustration style as the scales, helmet and diplomatic-action pictograms in that screen. Two natural human hands firmly shaking, short period military/civilian dark cuffs, compact clear side/front three-quarter silhouette. Tasteful dimensional highlights, realistic subtle metal, dark engraved recesses, warm ivory top light. Clear at 32–48px, strong recognizable silhouette, fine detail only supporting the silhouette.
Centered, fills about85% of square canvas. Isolated on genuinely transparent background. Absolutely no square plate, frame, badge, pedestal, laurel, writing, map, trophy display, background scene, floating gold particles or external glow. One icon only, no other items.

## research_v3.png

Use case: stylized-concept.
Asset type: ONE transparent research laboratory flask icon for a WWII grand strategy game's panel heading and research tabs.
Image1 is exact art direction reference. Match the small warm brass/alabaster flask pictogram used in the research navigation at left. Single recognizable Erlenmeyer flask, broad conical base, slim neck, warm brushed gold collar and rim, smoky ivory translucent glass with subtle amber contents in lower quarter. Tasteful dimensional metal highlights, darkengravedrecesses, clean silhouette, painterly realist game UI finish, readable at32–48px.
Centered, fills about85% square canvas; genuinely transparent background. No square plate or button, no pedestal, no scene, no symbols, labels, letters, text, glow, bubbles outside, extra instruments or trophies. Just the flask. Period-neutral1930s style, restrained and elegant not cartoon or sci-fi.

