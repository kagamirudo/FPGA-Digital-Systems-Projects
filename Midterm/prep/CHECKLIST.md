# Midterm Prep Checklist

Use this as a repeatable training checklist. Mark each item when done.

## 1) Environment and setup

- [ ] Vivado 2025.2 opens and can run simulation.
- [ ] Vitis 2025.2 opens and can build a standalone app.
- [ ] Board USB-JTAG/UART enumerates (`/dev/ttyUSB*` on Linux).
- [ ] UART terminal command is ready (`picocom` or `minicom`).

## 2) HW1 fundamentals (pure RTL)

- [ ] Re-run one combinational module and TB from `Homework_1/src` and `Homework_1/tb`.
- [ ] Re-run one sequential module and TB (clock + reset behavior).
- [ ] Confirm assertions pass and recognize failure location quickly.
- [ ] Practice wave inspection for signed vs unsigned interpretation.

## 3) HW3 flow: custom IP confidence

- [ ] Understand `fib_gen` register behavior and handshake.
- [ ] Understand `fix_acc` latency and "flush write" behavior.
- [ ] Practice setting file types correctly (`VHDL` for RTL, `VHDL 2008` for TB).
- [ ] Package IP without metadata warnings.
- [ ] Confirm AXI clock interface has `FREQ_HZ` and associated bus/reset parameters.

## 4) Block design correctness

- [ ] Connect PS clock/reset to all AXI clock/reset pins.
- [ ] Use correct interconnect type (AXI memory-mapped, not AXI4-Stream).
- [ ] Assign valid address ranges and verify base addresses.
- [ ] Generate wrapper and set wrapper as top before synthesis.
- [ ] Export hardware with bitstream.

## 5) Vitis bring-up and UART

- [ ] Platform created from correct XSA.
- [ ] `standalone_stdin` and `standalone_stdout` mapped to the UART used in PS.
- [ ] BSP regenerated after changing UART settings.
- [ ] Run config includes programming bitstream and running `ps7_init`.
- [ ] Serial monitor attached before clicking Run.

## 6) 5-minute debug drills

- [ ] Drill A: no UART output -> isolate UART mismatch vs missing `ps7_init`.
- [ ] Drill B: AXI clock/reset warning -> fix unconnected ACLK/ARESETN.
- [ ] Drill C: wrong top module -> correct to BD wrapper and rebuild.
- [ ] Drill D: stale BSP -> regenerate BSP and verify `bspconfig.h` macros.

## 7) Submission readiness

- [ ] User logic HDL paths are easy to point to.
- [ ] TB paths and pass evidence are captured.
- [ ] BD screenshot captured.
- [ ] C test app path and key snippet ready.
- [ ] UART output screenshot captured.
- [ ] Report draft completed from `REPORT_TEMPLATE.md`.
