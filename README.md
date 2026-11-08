# MazzleForever

An independent port of the original MazzleUI 1.18 compilation to **WoW: Forever 1.60.1.70862 (Interface 16001)**.

Current build: **1.18-forever.8 — GUI work in progress**. This is a compatibility preview, not a finished port. GUI fidelity to the original UI is the current priority.

## Install

[Download the install ZIP](MazzleUI-Forever.zip?raw=true), then follow [FOREVER-INSTALL.txt](FOREVER-INSTALL.txt). Extract the ZIP into `_forever_/Interface/AddOns/`; do not install the repository's development tree. Keep a backup of existing addons and settings. The package contains the modern runtime and original artwork, not the old executable addon stack.

Use `/mazzify` for setup and `/mazzle restore` to restore the previous native layout. The detailed install notes describe commands, what is ported and the remaining limitations.

## Preview 8

- Original four-piece panels, 14 skins, target cave, curved HUD, and player/pet/party model panels.
- Native action bars, minimap, auras, chat, bags and group controls adapted around the original artwork.
- A right information strip above separate outgoing-damage and native combat-log panes, following the supplied original UI reference.
- Time, FPS, latency, addon memory, money and bag capacity; in-panel bags and options; a full native damage-meter popout.
- A secure two-page action grid and restoration of native presentation/settings.
- A minimap aligned with its native Edit Mode selection, a collapsible micro menu, and a compact group-control drawer.

FauxMazzle has been consulted for compatibility hints. Its implementation, assets, fonts, settings and tests are not copied into this port.

## Validation and remaining work

See [VALIDATION.txt](VALIDATION.txt) for the current milestone evidence. Offline checks cover geometry, native setting encodings, restoration, combat deferral, opaque restricted values and packaging. They do not prove in-game secure behavior.

Preview 8's live idle check verified the Menu toggle, expanded/collapsed group drawer, bottom-center minimap selection and native size adjustment. No Lua error was observed. The drag test did not produce the expected displacement, with snapping either enabled or disabled; movement remains unresolved. Temporary test changes were reverted and snapping restored. Preview 7 verified backpack controls, damage-meter toggling and combat-log options. Actual log-text wrapping and fresh combat updates remain unverified. Target auras, text readability and other GUI details still need work. The broader compilation's unported features remain in scope.

Compatibility is verified against the stated client build; future clients require another review.

## Build and test

Python 3, Pillow and Lupa with Lua 5.1 support are required:

```sh
python -m pip install --target .validation/python lupa Pillow
git clone --branch forever https://github.com/Gethe/wow-ui-source.git .validation/wow-ui-source
git -C .validation/wow-ui-source checkout 9dc84f0d3bbae1768ac3405b3716000bd93eda06
python tools/build_forever.py
python tools/test_forever.py
python tools/preview_forever.py
```

The build derives presentation data and masks from the included original Mazzifier profiles and MazzleUI artwork. `SOURCE-HASHES.json` inside the ZIP records packaged source hashes. Preview images are geometry proofs with placeholder models/maps, not game captures.

Repository updates are made at completed development milestones, with the matching install ZIP and validation notes. Local game settings, backups, screenshots and downloaded test dependencies are excluded.

See [NOTICE.txt](NOTICE.txt) for the original materials' attribution and copyright notices. The repository's existing Apache license does not replace the original authors' terms for those materials.
