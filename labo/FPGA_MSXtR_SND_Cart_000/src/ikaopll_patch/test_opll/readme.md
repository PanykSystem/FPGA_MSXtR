# OPLL Slot Tone Test

Run `run.bat` with ModelSim on PATH. This test connects the real cartridge slot receiver, address decoder, dual_opll wrapper and IKAOPLL cores. It writes registers 30h=10h, 10h=80h and 20h=15h through ports 7Ch/7Dh, then checks that six transactions were accepted and the selected OPLL produced known nonzero audio samples. Stimulus uses posedge clocks.

The 3.579545MHz clock enable runs through reset. Writes have conservative approximately 28us gaps; this test does not establish the minimum supported write interval. The final sound sample may be zero even when earlier samples were nonzero.

After the normal runner, the original reset defect can be reproduced with:

```text
vsim -c -t 1ps -l legacy_reset.log tb +legacy_reset -do "run -all; quit -f"
```

This mode intentionally stops enable during reset and is expected to fail the tone assertion. IKAOPLL's reset synchronizer advances only on enabled master-clock edges. With no enabled edges during reset it never captures IC_n=0, and internal phase/register state remains uninitialized. Standard ports 7Ch/7Dh select OPLL0 (address bit1=0); 7Ah/7Bh select OPLL1.

2026-10-10: normal tone test passed with 17280 nonzero sample clocks, errors/warnings 0. Legacy reset gating reproduced unknown internal state and zero known audio samples. The production top divider was changed to free-run with FPGA power-up initialization. Physical cartridge, mixer/I2S output and software initialization require hardware verification after user-side synthesis.