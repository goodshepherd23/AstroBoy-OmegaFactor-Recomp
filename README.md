# Astro Boy: Omega Factor — native Windows port (gbarecomp)

A build-from-your-cartridge kit that turns **Astro Boy: Omega Factor** (Game Boy Advance, USA) into a
native Windows program with [gbarecomp](https://github.com/mstan/gbarecomp), mstan's GBA static
recompiler. The game's ARM/Thumb code is translated to C++ and compiled on your PC; it is not
emulated instruction by instruction.

**Nothing from the game or the GBA BIOS is in this kit.** You supply both, and setup checks them.

## What you need

- Windows 10 or 11, 64-bit, and about 2 GB of free disk space (most of it is the compiler).
- Your own dump of **Astro Boy: Omega Factor (USA)**, SHA-1 `4d652c24979dd7a08ee683b32d1d8986a5511a87`
  (game code BTAE, 8 MB). The European and Japanese versions, and patched or trimmed dumps, are not supported.
- Your own **Game Boy Advance BIOS** dump (`gba_bios.bin`, 16 KB), SHA-1
  `300c20df6731a33952ded8c436f7f186d25d3492`. gbarecomp runs the real BIOS; there is no built-in replacement.
- An internet connection the first time, for the downloads below.

## Install and play

Install it from the Quiver launcher, or unzip the release anywhere and run **AstroBoy.exe**.

The first run opens a setup window that asks for the ROM and then the BIOS, then:

1. downloads pinned, checksum-verified tools: llvm-mingw 20260616 (clang 22), CMake 3.31.12, Ninja 1.13.2 and SDL 2.32.10;
2. downloads gbarecomp's source at commit `c1a5fda` (tag v0.4.1) with arm-recomp-core `63dd32d` and toml++ `3017243`;
3. translates your BIOS and cartridge into C++ using this kit's `kit/game/game.toml`;
4. compiles the game (roughly 15–40 minutes, depending on the PC; it runs fewer jobs at once on PCs with little free memory).

After that, AstroBoy.exe starts the game straight away.

| Command | What it does |
| --- | --- |
| `AstroBoy.exe` | Play (runs setup first if needed) |
| `AstroBoy.exe --setup` | Choose the ROM and BIOS again |
| `AstroBoy.exe --rebuild` | Rebuild the game from scratch |

## Controls (keyboard)

| GBA | Key |
| --- | --- |
| D-pad | Arrow keys |
| A | X |
| B | Z |
| L / R | C / V |
| Start / Select | Enter / Right Shift |
| Save state / load state | Shift+F1–F9 / F1–F9 |
| Quit | Esc |

Keys can be rebound in `keybinds.ini` (`[player1]`, names `a b select start right left up down r l`)
in the game folder.

## Where things are

Everything you make or that setup downloads is kept in `%LOCALAPPDATA%\AstroBoy-OmegaFactor-Recomp`,
so updating or reinstalling the app leaves it alone:

- `game\` — the built game, your ROM and BIOS copies, `saves\` (the cartridge's EEPROM save) and `game.log`
- `tools\`, `build\` — the compiler and build cache (safe to delete; the next run rebuilds)
- `setup.log`, `launcher.log`

Put an empty `portable.txt` next to AstroBoy.exe to keep all of this in the app folder instead.

## Status

Played on the author's laptop from boot through the language select, title, story scenes, tutorial and
the first combat stages. The configuration lists the code entry points found while
playing (`[[extra_func]]` entries). Code in later stages that was never reached during testing still
runs: gbarecomp hands it to its built-in interpreter, which can make those moments slower. Reports
of places that slow down are welcome (issues on this repository); `game\recomp_master_misses_BTAE.toml.frag`
lists what the interpreter had to run and is the most useful thing to attach.

## Credits and license

- [gbarecomp](https://github.com/mstan/gbarecomp) and arm-recomp-core by Matthew Stanley (mstan), PolyForm Noncommercial 1.0.0.
  Setup downloads them; the built game is made with them and may only be used noncommercially.
- [toml++](https://github.com/marzer/tomlplusplus) (MIT), [SDL](https://www.libsdl.org/) (zlib),
  [llvm-mingw](https://github.com/mstorsjo/llvm-mingw).
- Astro Boy: Omega Factor is © Tezuka Productions / Sega, developed by Treasure and Hitmaker.
  This project is not affiliated with them.
- This kit (setup script, launcher, game configuration) is MIT; see LICENSE. It was made with the help of an AI coding assistant.
