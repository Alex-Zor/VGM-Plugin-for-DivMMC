# VGM-Plugin-for-DivMMC
VGM Player is a simple plugin for the NMI browser (ESXDOS) that allows playback of VGM audio files on ZX Spectrum-compatible hardware. Supported sound chips: AY-3-8910, YMF262 (OPL3), YM3812 (OPL2), YM2203 / 2x YM2203 (TSFM), YM2413 (OPLL), SAA1099 / 2x SAA1099, SN76489 / 2x SN76489

Current version: 0.63

Changes:
- 0.63: sound_off mutes every chip declared in the VGM header (chips_mask), not only the one shown in "Chip:" — multi-chip files (e.g. Robocop, YM2203+YM3812) no longer leave a hanging note after exit
- 0.63: YM2203 on FPGA implementations that use the canonical chip-select values on port #FFFD — VGM commands 0x55/0xA5 now emit the canonical select first ($FB = chip 1, $FA = chip 2; f=0 un-gates the FM part / clears FM_DIS) followed by the plugin-style select (#F0/#F1, note the opposite meaning of bit 0), so 2xYM2203 files address both chips correctly on either kind of hardware; $FB is also written once before playback starts and the mute routine writes $FB/$FA before silencing each chip
- 0.63: YM2203 clock conversion — arcade VGM rips are logged for a different chip clock (e.g. 1943: 1.5 MHz) and used to play ~15 semitones too high on TSFM (~3.55 MHz). When the header clock differs from the TSFM clock by more than ~3%, FM F-num/block values and SSG tone/noise/envelope periods are now rescaled on the fly by the clock ratio, so such rips play at their original pitch. Native TSFM rips (3.5/3.58 MHz) are passed through untouched
- 0.63: the same clock conversion for AY-3-8910 — rips logged for a non-ZX AY clock (Amstrad CPC 1 MHz ≈ +10 semitones, Atari ST 2 MHz, Vectrex 1.5 MHz) now play at their original pitch; ZX/Pentagon/MSX-clock rips (within ~3% of 1.7734 MHz) are passed through untouched
- 0.62: added SAA1099, YM2413, SN76489 support and the "PLUG" plugin header (by azesmbog)
- 0.61: YM2203 / 2x YM2203 (TSFM) support

https://t.me/pentadiv

![Top](img/VGM0.5.png)
