-VGM Player (v0.63)
    VGM Player is a simple plugin for the NMI browser (ESXDOS) that allows playback of VGM audio files on ZX Spectrum-compatible hardware.

-Features
    Playback of VGM files
    Supported sound chips:
      AY-3-8910
      YMF262 (OPL3)
      YM3812 (OPL2)
      YM2203 and 2x YM2203 (compatible with the TSFM sound card)
      YM2413 (OPLL)
      SAA1099 and 2x SAA1099
      SN76489 and 2x SN76489
    Integration with NMI browser
    Lightweight and fast streaming playback

-Status
    This is alpha version (0.63).
    Expect bugs, incomplete features, and limited compatibility.

-Change history
    0.63 (2 September 2026)
      sound_off now mutes every chip declared in the VGM header
      (chips_mask), not only the chip shown in the "Chip:" line:
      multi-chip files (e.g. Robocop, YM2203+YM3812) no longer
      leave a hanging note after quitting the player.
    0.62 (1 September 2026, by azesmbog)
      Added SAA1099 / 2x SAA1099 (VGM cmd 0xBD, ports #01FF/#00FF
      and #03FF/#02FF), YM2413 (cmd 0x51, ports #C0/#C1) and
      SN76489 / 2x SN76489 (cmds 0x50/0x30, ports #C3/#C2).
      New "PLUG" plugin header format.
    0.61
      Support YM2203 and 2x YM2203 (TSFM sound card).
      Fixed minor bugs.
    0.5
      First public version: AY-3-8910, YM3812, YMF262.

-Usage
    Place the plugin in your ESXDOS plugins directory.("\BIN\BPLUGINS")
    Open the NMI browser.
    Select a .vgm file to start playback.

-Notes
    Timing accuracy and compatibility may vary depending on hardware.

-Author
    Created by AlexZor
    2 September 2026
