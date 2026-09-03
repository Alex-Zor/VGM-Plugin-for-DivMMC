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
      YM2203 fix for FPGA implementations that use the canonical
      chip-select values on port #FFFD: VGM commands 0x55/0xA5
      now emit the canonical select first ($FB = chip 1,
      $FA = chip 2; f=0 un-gates the FM part / clears FM_DIS)
      followed by the plugin-style select (#F0/#F1), so
      2xYM2203 files address both chips correctly on either
      kind of hardware. $FB is also written once before playback
      of a YM2203 file starts, and the mute routine writes the
      canonical selects $FB/$FA before silencing each chip.
      Hardware and emulators that only understand #F0/#F1 still
      get those selects last and are unaffected (note: the
      meaning of bit 0 in the canonical selects is opposite to
      the plugin-style ones).
      YM2203 clock conversion: arcade VGM rips are logged for a
      different chip clock (e.g. 1943 - 1.5 MHz) and used to
      play about 15 semitones too high on TSFM (~3.55 MHz).
      When the YM2203 clock in the VGM header differs from the
      TSFM clock by more than ~3%, FM F-num/block values and SSG
      tone/noise/envelope periods are rescaled on the fly by the
      clock ratio, so such rips play at their original pitch.
      Native TSFM rips (3.5/3.58 MHz) are passed through
      untouched.
      The same clock conversion is applied to AY-3-8910 rips
      logged for a non-ZX clock (header offset 0x74): Amstrad
      CPC 1 MHz (about +10 semitones on ZX), Atari ST 2 MHz,
      Vectrex 1.5 MHz now play at their original pitch;
      ZX/Pentagon/MSX-clock rips (within ~3% of 1.7734 MHz) are
      passed through untouched.
      The plugin now uses RAM up to #9BFF (frequency scaling
      tables and the file buffer moved to #9300-#9BFF).
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
