YM2203 chip-select test files
=============================

Three tiny hand-crafted VGM 1.51 files that make it obvious, on any
hardware or emulator, whether the second YM2203 of a 2xYM2203 (TSFM)
setup is actually being addressed by the plugin. All tones use the
SSG (AY-compatible) part, channel A only.

ym2203_chip1.vgm  - chip 1 only (VGM command 0x55):
                    two LONG LOW beeps (~440 Hz).

ym2203_chip2.vgm  - chip 2 only (VGM command 0xA5, header declares
                    2xYM2203): four SHORT HIGH beeps (~660 Hz).
                    If this file plays silence, the second chip is
                    not receiving writes on this device.

ym2203_both.vgm   - chip 1 holds the LOW tone while chip 2 plays
                    three SHORT HIGH beeps on top.
                    Correct routing: low tone sounds continuously,
                    high beeps are added over it.
                    Broken routing (both streams land on one chip):
                    the high beeps REPLACE the low tone (same SSG
                    registers get overwritten) and after the first
                    beep ends everything goes silent.

Generated for plugin debugging; pitch values assume the usual TSFM
YM2203 clock (~3.58 MHz, SSG behaving like an AY at ~1.79 MHz) -
absolute pitch does not matter for the test, only low vs high and
silence vs sound.
