# Work History

## 2026-10-10 OPLL Reset Clock Enable

User reported that SSG audio worked with the sound cartridge attached to Cartridge Stack, but OPLL audio did not. Inspected the slot receiver, 7Ch/7Dh decoder, dual_opll wrapper, IKAOPLL reset synchronizer and mixer connections.

The top stopped ff_enable during slot reset. IKAOPLL synchronizes IC_n only on enabled master-clock edges, so the reset-low state never entered its reset pipeline. This is different from the SSG's direct synchronous reset. Added a real-core slot-write tone test; the original gating reproduced unknown internal state and no known nonzero audio samples even with conservative register-write spacing.

Changed only the production top clock-enable divider to free-run through reset, with ff_divider=0 and ff_enable=0 power-up initial values. The corrected-reset test accepted six writes and generated 17280 nonzero sample clocks. Standard 7Ch/7Dh selects OPLL0; 7Ah/7Bh selects OPLL1. Mixer, port mapping and IKAOPLL sources were not modified.

Added src/ikaopll_patch/test_opll/tb.sv, run.bat and readme.md. Compiled the changed top and dependencies with ModelSim, errors/warnings 0. Tone test passed; +legacy_reset intentionally reproduces the failure. This test uses approximately 28us write gaps and does not verify minimum write timing, MSX-MUSIC software initialization or physical I2S audio output.

GOWIN EDA was not run. User-side synthesis/programming and hardware OPLL playback confirmation remain required. No CPU-board RTL, timing constraints or existing user changes were reverted.