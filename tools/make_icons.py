#!/usr/bin/env python3
"""Generate the complete strategic UI icon family from one visual system."""

from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "ui" / "icons"

DEFS = """
<defs>
  <linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#48515a"/><stop offset=".5" stop-color="#252c33"/><stop offset="1" stop-color="#11161b"/></linearGradient>
  <linearGradient id="brass" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#f3dc91"/><stop offset=".42" stop-color="#b88a3d"/><stop offset="1" stop-color="#6b431d"/></linearGradient>
  <linearGradient id="ivory" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#fff7d5"/><stop offset="1" stop-color="#c9b87b"/></linearGradient>
  <linearGradient id="red" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#c95d4d"/><stop offset="1" stop-color="#68251f"/></linearGradient>
  <linearGradient id="buildingPlate" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#26343b"/><stop offset=".5" stop-color="#131b20"/><stop offset="1" stop-color="#080d11"/></linearGradient>
  <linearGradient id="resourcePlate" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#2b3133"/><stop offset=".55" stop-color="#121719"/><stop offset="1" stop-color="#070a0c"/></linearGradient>
  <linearGradient id="equipmentPlate" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#27302b"/><stop offset=".48" stop-color="#151b19"/><stop offset="1" stop-color="#080c0c"/></linearGradient>
  <radialGradient id="softGlow" cx="35%" cy="24%" r="75%"><stop stop-color="#fff2b0" stop-opacity=".22"/><stop offset=".55" stop-color="#b8d2d7" stop-opacity=".06"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  <filter id="shadow" x="-30%" y="-30%" width="160%" height="170%"><feGaussianBlur in="SourceAlpha" stdDeviation="1.6"/><feOffset dy="2"/><feComponentTransfer><feFuncA type="linear" slope=".65"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="objectShadow" x="-35%" y="-35%" width="180%" height="190%"><feGaussianBlur in="SourceAlpha" stdDeviation="1.25"/><feOffset dx="1.2" dy="2.2"/><feComponentTransfer><feFuncA type="linear" slope=".88"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>"""

FRAME = """
<path d="M32 3 53 11 60 32 52 53 32 61 11 53 4 32 12 11Z" fill="#090d11" opacity=".8"/>
<path d="M32 5 51 12 58 32 50 51 32 58 13 51 6 32 14 13Z" fill="url(#steel)" stroke="url(#brass)" stroke-width="2.2"/>
<path d="M32 10 48 16 53 32 47 47 32 53 17 47 11 32 17 17Z" fill="#171d22" stroke="#737a77" stroke-width=".8"/>
<path d="M18 16Q32 9 46 16" fill="none" stroke="#d9c47b" stroke-width="1" opacity=".45"/>
"""

SYMBOLS = {
    "politics": '<path d="M17 27 32 16l15 11H17Zm3 3h24v4H20Zm2 5h4v10h-4Zm8 0h4v10h-4Zm8 0h4v10h-4ZM18 46h28v4H18Z" fill="url(#ivory)" stroke="#16140f" stroke-width="1.2"/>',
    "research": '<path d="M25 16h14v4l-3 2v8l10 16q2 4-3 4H21q-5 0-3-4l10-16v-8l-3-2Zm1 23h12l-4-7V21h-4v11Z" fill="url(#ivory)" stroke="#15191b" stroke-width="1.5"/><path d="M22 45h20l-4-7H26Z" fill="#5c9aa2" opacity=".9"/><circle cx="31" cy="42" r="2" fill="#dff4e9"/>',
    "diplomacy": '<circle cx="32" cy="29" r="13" fill="#5d7f8f" stroke="url(#ivory)" stroke-width="2"/><path d="M20 28h24M32 16c-7 8-7 18 0 26M32 16c7 8 7 18 0 26" fill="none" stroke="#e9ddb0" stroke-width="1.5"/><path d="m20 43 7-5 5 4 5-4 7 5-8 7-4-3-4 3Z" fill="url(#brass)" stroke="#21170d" stroke-width="1.2"/>',
    "trade": '<path d="M14 39h36l-5 9H21Z" fill="url(#brass)" stroke="#141719" stroke-width="1.4"/><path d="M20 27h21l5 12H17Zm5-8h12v8H25Z" fill="url(#ivory)" stroke="#141719" stroke-width="1.4"/><path d="M16 51q5 3 10 0 6 3 12 0 5 3 10 0" fill="none" stroke="#739ba3" stroke-width="2"/>',
    "construction": '<path d="m18 46 22-25 5 5-22 25Z" fill="url(#ivory)" stroke="#121619" stroke-width="1.5"/><path d="M15 18q9-5 16 4l-5 5-5-4-4 2Z" fill="url(#brass)" stroke="#121619" stroke-width="1.5"/><path d="m38 19 8-3 3 3-4 7Z" fill="#8f9898" stroke="#121619" stroke-width="1.2"/>',
    "production": '<path d="m32 15 4 5 7-1 1 7 6 4-4 6 2 7-7 2-3 6-6-3-6 3-3-6-7-2 2-7-4-6 6-4 1-7 7 1Z" fill="url(#brass)" stroke="#121619" stroke-width="1.6"/><circle cx="32" cy="33" r="8" fill="#1a2228" stroke="url(#ivory)" stroke-width="2"/><circle cx="32" cy="33" r="3" fill="#b88a3d"/>',
    "army": '<path d="M17 21h30v25H17Z" fill="#52694b" stroke="url(#ivory)" stroke-width="2"/><path d="m23 26 18 15m0-15L23 41" stroke="#efe2b6" stroke-width="3"/><path d="M14 18h36v5H14Z" fill="url(#brass)" stroke="#17130d"/>',
    "political_power": '<path d="m32 14 5 11 12 1-9 8 3 12-11-6-11 6 3-12-9-8 12-1Z" fill="url(#brass)" stroke="#15130d" stroke-width="1.5"/><circle cx="32" cy="32" r="6" fill="#8d2f29" stroke="#f2dda0" stroke-width="1.4"/>',
    "stability": '<path d="M31 18h2v28h-2Zm-9 3h20v3H22Z" fill="url(#ivory)"/><path d="m22 24-7 14h14Zm20 0-7 14h14Z" fill="url(#brass)" stroke="#17140e" stroke-width="1.3"/><path d="M24 47h16" stroke="#e9d493" stroke-width="4" stroke-linecap="round"/>',
    "war_support": '<path d="M32 14 47 20v11q0 13-15 20Q17 44 17 31V20Z" fill="url(#red)" stroke="url(#ivory)" stroke-width="2"/><path d="m26 42 10-21 4 2-10 21Zm5-16 9 11" stroke="#f4e9c4" stroke-width="3" stroke-linecap="round"/>',
    "manpower": '<circle cx="32" cy="24" r="7" fill="url(#ivory)" stroke="#161719"/><circle cx="19" cy="29" r="5" fill="#b6a76f" stroke="#161719"/><circle cx="45" cy="29" r="5" fill="#b6a76f" stroke="#161719"/><path d="M20 49q1-15 12-15t12 15Zm-10 0q1-11 9-11 4 0 6 4m29 7q-1-11-9-11-4 0-6 4" fill="url(#ivory)" stroke="#161719" stroke-width="1.4"/>',
    "factory": '<path d="M15 49V28l10 6v-7l11 7V18h10v31Z" fill="url(#ivory)" stroke="#151719" stroke-width="1.5"/><path d="M21 40h5v5h-5Zm10 0h5v5h-5Zm10 0h5v5h-5Z" fill="#3f5961"/>',
    "military_factory": '<path d="M14 49V30l10 5v-7l10 6V20h10v29Z" fill="#858d88" stroke="#121619" stroke-width="1.5"/><path d="M19 42h7v5h-7Zm11 0h7v5h-7Z" fill="#26343a"/><path d="m45 18 5 3-12 18-5-3Z" fill="url(#brass)" stroke="#14130e" stroke-width="1.2"/>',
    "battle": '<path d="m18 17 6 2 22 27-5 4-22-27Zm28 0-6 2-22 27 5 4 22-27Z" fill="url(#ivory)" stroke="#141719" stroke-width="1.5"/><path d="m17 42 6 6m24-6-6 6" stroke="#c18d3d" stroke-width="4"/>',
}

CONTROLS = {
    "add_line": '<path d="M10 36h44" stroke="url(#ivory)" stroke-width="5" stroke-linecap="round"/><circle cx="32" cy="36" r="5" fill="url(#brass)"/>',
    "plus": '<path d="M32 17v30M17 32h30" stroke="url(#ivory)" stroke-width="6" stroke-linecap="round"/>',
    "minus": '<path d="M17 32h30" stroke="url(#ivory)" stroke-width="6" stroke-linecap="round"/>',
    "close": '<path d="m20 20 24 24m0-24L20 44" stroke="url(#ivory)" stroke-width="6" stroke-linecap="round"/>',
    "up": '<path d="m17 39 15-15 15 15" fill="none" stroke="url(#ivory)" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>',
    "down": '<path d="m17 25 15 15 15-15" fill="none" stroke="url(#ivory)" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>',
    "play": '<path d="m24 17 25 15-25 15Z" fill="url(#ivory)" stroke="#151719" stroke-width="1.5"/>',
    "pause": '<path d="M20 17h9v30h-9Zm15 0h9v30h-9Z" fill="url(#ivory)" stroke="#151719" stroke-width="1.2"/>',
}

MAP_SYMBOLS = {
    "map_port": '<path d="M48 18v49M34 31h28M39 18a9 9 0 1 0 18 0 9 9 0 1 0-18 0ZM21 54q5 23 27 25 22-2 27-25l-12-3q-3 12-10 15V43H43v23q-7-3-10-15Z" fill="none" stroke="#f7e9ba" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>',
    "map_airbase": '<path d="m48 12 7 25 25 13v7l-26-6-2 22 10 7v5l-14-3-14 3v-5l10-7-2-22-26 6v-7l25-13Z" fill="#f7e9ba" stroke="#11171c" stroke-width="2" stroke-linejoin="round"/>',
    "map_city": '<path d="M20 73V42l15 8V38l15 9V25h12v22l14-7v33Z" fill="#f4e6b6" stroke="#12171b" stroke-width="3"/><path d="M27 58h7v8h-7Zm14 0h7v8h-7Zm14 0h7v8h-7Zm14 0h4v8h-4Z" fill="#35434a"/>',
    "map_capital": '<path d="m48 19 7 15 17 2-13 12 4 17-15-8-15 8 4-17-13-12 17-2Z" fill="url(#brass)" stroke="#11171c" stroke-width="3"/><path d="M22 75h52" stroke="#f4e6b6" stroke-width="6" stroke-linecap="round"/>',
}

BUILDINGS = {
    "civilian_factory": '<path d="M15 48V29l10 6v-8l11 7V18h10v30Z" fill="url(#ivory)" stroke="#11171b" stroke-width="1.5"/><path d="M20 40h5v5h-5Zm10 0h5v5h-5Zm10 0h5v5h-5Z" fill="#49616a"/><path d="M38 18h8v-4h-8Z" fill="url(#brass)"/>',
    "military_factory": '<path d="M14 49V31l10 5v-8l10 7V20h10v29Z" fill="#909994" stroke="#11171b" stroke-width="1.5"/><path d="M19 42h7v5h-7Zm11 0h7v5h-7Z" fill="#26343a"/><path d="m43 17 7 3-12 20-6-3Z" fill="url(#brass)" stroke="#17130d"/><path d="m47 15 5 2-2 4-7-3Z" fill="#b54d3e"/>',
    "dockyard": '<path d="M13 45h38l-5 6H19Z" fill="#6c8390" stroke="#10171b" stroke-width="1.5"/><path d="M19 36h25l5 9H15Z" fill="url(#ivory)" stroke="#10171b" stroke-width="1.5"/><path d="M19 16h3v22h-3Zm2 2h18v3H21Zm15 2h3v12h-3Z" fill="url(#brass)" stroke="#17130c"/><path d="M15 54q5 2 10 0 6 2 12 0 5 2 11 0" fill="none" stroke="#6fa4b5" stroke-width="2"/>',
    "synthetic_refinery": '<ellipse cx="23" cy="24" rx="8" ry="4" fill="url(#ivory)" stroke="#11171b"/><path d="M15 24v20q8 7 16 0V24" fill="#9a9278" stroke="#11171b"/><ellipse cx="41" cy="31" rx="8" ry="4" fill="url(#brass)" stroke="#11171b"/><path d="M33 31v15q8 6 16 0V31M31 38h5" fill="#756a4d" stroke="#11171b"/><path d="M20 18v-5h5v7m17 7V16h5v13" fill="none" stroke="#d9c67e" stroke-width="3"/>',
    "infrastructure": '<path d="M16 49 29 15h6l13 34Z" fill="#666e70" stroke="#11171b" stroke-width="1.5"/><path d="M31 18h2v8h-2Zm0 13h2v8h-2Zm0 12h2v5h-2Z" fill="#f2dfa1"/><path d="M13 49h38" stroke="url(#brass)" stroke-width="4"/><path d="m16 43 32-11" stroke="#b9b197" stroke-width="2"/>',
    "air_base": '<path d="M15 46h34v4H15Z" fill="#8b8e87" stroke="#11171b"/><path d="M21 42h22" stroke="#f3dda0" stroke-width="3" stroke-dasharray="5 3"/><path d="m32 13 4 13 14 8v5l-15-4-1 11h-4l-1-11-15 4v-5l14-8Z" fill="url(#ivory)" stroke="#11171b" stroke-width="1.3"/>',
    "naval_base": '<path d="M16 46h32v5H16Z" fill="#89928e" stroke="#11171b"/><path d="M20 31h24v15H20Zm4-8h16v8H24Z" fill="url(#ivory)" stroke="#11171b"/><path d="M32 15v24m-7-17h14M22 34q2 11 10 12 8-1 10-12" fill="none" stroke="url(#brass)" stroke-width="3"/>',
    "anti_air": '<path d="M18 45h28v5H18Z" fill="#777f7c" stroke="#11171b"/><path d="M27 34h10l5 11H22Z" fill="#8c948e" stroke="#11171b"/><path d="m28 36-7-19 4-2 8 20m3 1 5-21 4 1-4 22" fill="url(#ivory)" stroke="#11171b" stroke-width="1.2"/><circle cx="32" cy="37" r="5" fill="url(#brass)" stroke="#11171b"/>',
}

RESOURCES = {
    "oil": '<path d="M32 14q13 17 13 25a13 13 0 1 1-26 0q0-8 13-25Z" fill="#20282b" stroke="#d0be7b" stroke-width="2"/><path d="M27 42q2 5 8 3" fill="none" stroke="#7f9598" stroke-width="2"/>',
    "steel": '<path d="M16 20h32v7H36v10h12v7H16v-7h12V27H16Z" fill="#9aa7ad" stroke="#11171b" stroke-width="1.7"/><path d="M19 22h26M19 40h26" stroke="#e7e3cf" stroke-width="1.5"/>',
    "aluminium": '<path d="m18 42 9-24h10l9 24-8 5H26Z" fill="#d9e0df" stroke="#11171b" stroke-width="1.6"/><path d="m24 36 8-14 8 14-8-4Z" fill="#8fa7ad"/><path d="M19 44h26" stroke="#f4edcf" stroke-width="2"/>',
    "tungsten": '<path d="M22 17h20l-3 13 6 18H19l6-18Z" fill="#59636a" stroke="#11171b" stroke-width="1.7"/><path d="M26 21h12l-2 8h-8Z" fill="#c5b776"/><path d="m24 44 16-10" stroke="#dce1dd" stroke-width="2"/>',
    "chromium": '<path d="m32 15 15 9v17l-15 9-15-9V24Z" fill="#9fb5bd" stroke="#11171b" stroke-width="1.8"/><path d="m32 21 9 5v10l-9 5-9-5V26Z" fill="#26343a" stroke="#f0e7c5" stroke-width="1.5"/><circle cx="32" cy="31" r="4" fill="#b9c9cb"/>',
    "rubber": '<circle cx="32" cy="32" r="17" fill="#202426" stroke="#d0b96f" stroke-width="2"/><circle cx="32" cy="32" r="8" fill="#778085" stroke="#11171b" stroke-width="2"/><path d="M32 15v9m0 16v9M15 32h9m16 0h9" stroke="#5b6264" stroke-width="2"/>',
}

EQUIPMENT = {
    "infantry_equipment": '<path d="m15 43 29-26 4 4-29 26Z" fill="url(#ivory)" stroke="#11171b" stroke-width="1.4"/><path d="m25 37 8 9m6-22 7 8M16 45l-3 5" stroke="url(#brass)" stroke-width="3"/><path d="m32 29 9 1" stroke="#9a4b35" stroke-width="3"/>',
    "support_equipment": '<path d="M16 24h32v25H16Z" fill="#56664f" stroke="#11171b" stroke-width="1.7"/><path d="M23 24v-6h18v6M20 32h24" fill="none" stroke="url(#brass)" stroke-width="2"/><circle cx="32" cy="39" r="5" fill="#232d31" stroke="#e4d69d"/><path d="M32 36v6m-3-3h6" stroke="#d5bc69" stroke-width="2"/>',
    "artillery_equipment": '<circle cx="24" cy="44" r="7" fill="#30383b" stroke="url(#ivory)" stroke-width="2"/><path d="M24 38h15l8-20 4 2-7 24H31" fill="#7e877f" stroke="#11171b" stroke-width="1.5"/><path d="M43 18h10" stroke="url(#brass)" stroke-width="4"/>',
    "anti_tank_equipment": '<circle cx="25" cy="44" r="7" fill="#30383b" stroke="url(#ivory)" stroke-width="2"/><path d="M22 38h20l5 7H31Z" fill="#7c857d" stroke="#11171b"/><path d="m32 36 19-18" stroke="url(#ivory)" stroke-width="5"/><path d="M46 18h8" stroke="url(#brass)" stroke-width="3"/>',
    "anti_air_equipment": '<circle cx="25" cy="45" r="6" fill="#30383b" stroke="url(#ivory)" stroke-width="2"/><path d="M20 39h22l5 7H31Z" fill="#7c857d" stroke="#11171b"/><path d="m31 39 3-22m4 22 7-21" stroke="url(#ivory)" stroke-width="4"/><path d="M32 17h5m7 1h5" stroke="url(#brass)" stroke-width="3"/>',
    "motorized_equipment": '<path d="M15 27h25l8 9v12H15Z" fill="#667356" stroke="#11171b" stroke-width="1.6"/><path d="M40 30h5l5 8H40Z" fill="#a9c0c3" stroke="#11171b"/><circle cx="23" cy="48" r="5" fill="#23282a" stroke="#c9bd88"/><circle cx="43" cy="48" r="5" fill="#23282a" stroke="#c9bd88"/><path d="M20 20h18v7H20Z" fill="#8c7654" stroke="#11171b"/>',
    "light_tank_equipment": '<path d="M15 39h35l-5 11H20Z" fill="#5e704f" stroke="#11171b" stroke-width="1.7"/><path d="M23 29h17l6 10H19Z" fill="#71815f" stroke="#11171b"/><path d="M28 24h10v7H28Zm10 2h15v3H38Z" fill="url(#ivory)" stroke="#11171b"/><circle cx="25" cy="44" r="3" fill="#252d2d"/><circle cx="40" cy="44" r="3" fill="#252d2d"/>',
    "medium_tank_equipment": '<path d="M13 38h39l-5 13H18Z" fill="#56694a" stroke="#11171b" stroke-width="1.8"/><path d="M20 27h23l6 11H16Z" fill="#70805d" stroke="#11171b"/><path d="M26 21h14l4 8H23Zm13 3h17v4H39Z" fill="url(#ivory)" stroke="#11171b"/><circle cx="22" cy="45" r="4" fill="#252d2d"/><circle cx="43" cy="45" r="4" fill="#252d2d"/>',
    "fighter_equipment": '<path d="m32 14 5 14 16 8v5l-17-4-2 12h-4l-2-12-17 4v-5l16-8Z" fill="url(#ivory)" stroke="#11171b" stroke-width="1.5"/><path d="M32 18v27" stroke="#a54a39" stroke-width="2"/>',
    "cas_equipment": '<path d="m35 15 3 15 15 11-1 5-17-7-5 11-4-1 1-13-16-1 1-5 17 1Z" fill="#879483" stroke="#11171b" stroke-width="1.5"/><path d="m18 32 31 11" stroke="#d1b96c" stroke-width="2"/>',
    "tactical_bomber_equipment": '<path d="m32 17 5 13 18 7v5l-19-4-2 11h-4l-2-11-19 4v-5l18-7Z" fill="#8b9189" stroke="#11171b" stroke-width="1.5"/><circle cx="20" cy="35" r="4" fill="#26343a" stroke="#d9cc9b"/><circle cx="44" cy="35" r="4" fill="#26343a" stroke="#d9cc9b"/>',
    "convoy": '<path d="M13 42h39l-7 9H21Z" fill="#667f89" stroke="#11171b" stroke-width="1.6"/><path d="M21 30h24l5 12H17Zm5-8h13v8H26Z" fill="url(#ivory)" stroke="#11171b"/><path d="M16 54q6 2 11 0 6 2 12 0 5 2 10 0" fill="none" stroke="#6da1b2" stroke-width="2"/>',
    "destroyer": '<path d="M11 43h44l-9 8H20Z" fill="#71838a" stroke="#11171b" stroke-width="1.6"/><path d="M23 33h21l7 10H17Zm7-10h10v10H30Z" fill="#aeb6ae" stroke="#11171b"/><path d="m39 29 9-6" stroke="url(#brass)" stroke-width="3"/>',
    "submarine": '<path d="M13 39q7-10 19-10t19 10q-7 11-19 11T13 39Z" fill="#53636a" stroke="#11171b" stroke-width="1.7"/><path d="M27 29v-8h8v8m-4-8v-5h8" fill="none" stroke="url(#ivory)" stroke-width="3"/><circle cx="22" cy="39" r="2" fill="#d4c279"/>',
    "cruiser": '<path d="M9 43h47l-10 9H19Z" fill="#687b82" stroke="#11171b" stroke-width="1.7"/><path d="M18 33h31l5 10H13Zm10-11h15v11H28Z" fill="#a5ada7" stroke="#11171b"/><path d="M24 31 14 24m31 7 10-7" stroke="url(#brass)" stroke-width="3"/><circle cx="25" cy="45" r="3" fill="#313b3e"/><circle cx="41" cy="45" r="3" fill="#313b3e"/>',
    "battleship": '<path d="M7 42h50L46 53H18Z" fill="#5e727a" stroke="#11171b" stroke-width="1.8"/><path d="M14 31h38l4 11H10Zm15-13h15v13H29Z" fill="#a4aca7" stroke="#11171b"/><path d="m22 31-12-9m39 9 12-9M32 23 19 16m23 7 13-7" stroke="url(#brass)" stroke-width="3"/><circle cx="21" cy="45" r="3" fill="#263136"/><circle cx="32" cy="45" r="3" fill="#263136"/><circle cx="44" cy="45" r="3" fill="#263136"/>',
}


def icon_svg(body: str, framed: bool = True) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">{DEFS}<g filter="url(#shadow)">{FRAME if framed else ""}{body}</g></svg>\n'


def asset_svg(body: str, category: str) -> str:
    """Full-canvas game asset: restrained plate, large readable object, category color."""
    if category == "building":
        plate = '''
<rect x="2.5" y="2.5" width="59" height="59" rx="10" fill="#05080a" stroke="#050708" stroke-width="3"/>
<rect x="4.5" y="4.5" width="55" height="55" rx="8" fill="url(#buildingPlate)" stroke="#b68b42" stroke-width="1.5"/>
<path d="M9 51.5h46" stroke="#d0a151" stroke-width="1.4" opacity=".8"/>
<path d="M9 10h20" stroke="#f0d78b" stroke-width="1" opacity=".35"/>
<circle cx="9" cy="9" r="1.4" fill="#d1b26a"/><circle cx="55" cy="55" r="1.4" fill="#6f5226"/>'''
        transform = "translate(-3 -3) scale(1.10)"
    elif category == "resource":
        plate = '''
<circle cx="32" cy="32" r="29.5" fill="#05080a" stroke="#050708" stroke-width="3"/>
<circle cx="32" cy="32" r="27" fill="url(#resourcePlate)" stroke="#9da6a3" stroke-width="1.4"/>
<path d="M13 19A23 23 0 0 1 48 13" fill="none" stroke="#f0dc95" stroke-width="1.4" opacity=".55"/>
<path d="M14 49A23 23 0 0 0 51 45" fill="none" stroke="#57401f" stroke-width="2" opacity=".8"/>'''
        transform = "translate(-8 -8) scale(1.25)"
    else:
        plate = '''
<path d="M6 5h48l5 5v44l-5 5H10l-5-5V10Z" fill="#05080a" stroke="#050708" stroke-width="3"/>
<path d="M8 7h44l5 5v40l-5 5H12l-5-5V12Z" fill="url(#equipmentPlate)" stroke="#7f8e87" stroke-width="1.4"/>
<path d="M11 11h24" stroke="#e5d185" stroke-width="1.2" opacity=".55"/>
<path d="M29 54h24" stroke="#4f653f" stroke-width="1.5" opacity=".8"/>'''
        transform = "translate(-3 -3) scale(1.10)"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">{DEFS}
<g filter="url(#shadow)">{plate}<rect x="6" y="6" width="52" height="52" rx="8" fill="url(#softGlow)"/></g>
<g transform="{transform}" filter="url(#objectShadow)">{body}</g>
</svg>\n'''


def map_svg(body: str) -> str:
    defs = DEFS.replace('viewBox="0 0 64 64"', '')
    frame = '<circle cx="48" cy="48" r="43" fill="#0d1318" stroke="#0a0d10" stroke-width="6"/><circle cx="48" cy="48" r="39" fill="url(#steel)" stroke="url(#brass)" stroke-width="4"/><circle cx="48" cy="48" r="33" fill="#172027" stroke="#737a77" stroke-width="1.5"/><path d="M21 30Q48 10 75 30" fill="none" stroke="#ead586" stroke-width="2" opacity=".4"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">{defs}<g filter="url(#shadow)">{frame}{body}</g></svg>\n'


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, body in SYMBOLS.items():
        (OUT / f"{name}.svg").write_text(icon_svg(body), encoding="utf-8")
    for name, body in CONTROLS.items():
        (OUT / f"{name}.svg").write_text(icon_svg(body, framed=False), encoding="utf-8")
    for name, body in MAP_SYMBOLS.items():
        (OUT / f"{name}.svg").write_text(map_svg(body), encoding="utf-8")
    for name, body in BUILDINGS.items():
        (OUT / f"building_{name}.svg").write_text(asset_svg(body, "building"), encoding="utf-8")
    for name, body in RESOURCES.items():
        (OUT / f"resource_{name}.svg").write_text(asset_svg(body, "resource"), encoding="utf-8")
    for name, body in EQUIPMENT.items():
        (OUT / f"equipment_{name}.svg").write_text(asset_svg(body, "equipment"), encoding="utf-8")
    count = sum(map(len, (SYMBOLS, CONTROLS, MAP_SYMBOLS, BUILDINGS, RESOURCES, EQUIPMENT)))
    print(f"wrote {count} icons to {OUT}")


if __name__ == "__main__":
    main()
