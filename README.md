# VGM-Plugin-for-DivMMC
VGM Player is a simple plugin for the NMI browser (ESXDOS) that allows playback of VGM audio files on ZX Spectrum-compatible hardware. Supported sound chips: AY-3-8910, YMF262 (OPL3), YM3812 (OPL2), YM2203 / 2x YM2203 (TSFM), YM2413 (OPLL), SAA1099 / 2x SAA1099, SN76489 / 2x SN76489

Current version: 0.63

Changes:
- 0.63: sound_off mutes every chip declared in the VGM header (chips_mask), not only the one shown in "Chip:" — multi-chip files (e.g. Robocop, YM2203+YM3812) no longer leave a hanging note after exit
- 0.63: YM2203 on FPGA implementations that use the canonical chip-select values — a single $FB write (chip 1, FM on) to #FFFD before playing a YM2203 track un-gates the FM part (clears FM_DIS), and the mute routine now writes the canonical selects $FB/$FA before silencing each chip; the plugin-style #F0/#F1 selects are kept as-is, so hardware/emulators that understand them are unaffected
- 0.62: added SAA1099, YM2413, SN76489 support and the "PLUG" plugin header (by azesmbog)
- 0.61: YM2203 / 2x YM2203 (TSFM) support

https://t.me/pentadiv

![Top](img/VGM0.5.png)
