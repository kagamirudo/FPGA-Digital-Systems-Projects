# Midterm Prep Framework (HW1 -> HW3)

This folder is a structured preparation kit for the ECEC 661 midterm.
It is based on the workflows and failure points you already hit in:

- `Homework_1` (pure RTL + testbenches)
- `Homework_2/gpio_leds` (first PS+PL flow)
- `Homework_3/fib_gen` and `Homework_3/fix_acc` (AXI4-Lite custom IP + Vitis app)

`Midterm/real` is intentionally left untouched for the actual exam work.

## What to use in this folder

- `CHECKLIST.md`: practical prep checklist you can execute line by line.
- `MIDTERM_RUNBOOK.md`: timed exam-day execution sequence.
- `REPORT_TEMPLATE.md`: quick report template for clean submission artifacts.

## Core outcomes to master

1. Build and simulate VHDL quickly (including VHDL vs VHDL-2008 file type handling).
2. Package custom AXI IP with correct metadata and clock interface parameters.
3. Build a valid Zynq block design with correct clocks, resets, and address map.
4. Export XSA and bring up Vitis bare-metal app with working UART output.
5. Debug common blockers in under 5 minutes (top module, BSP UART, ps7_init, serial port).

## Suggested prep cadence (repeatable)

- Session A (60 min): HW1-style RTL + TB speed run.
- Session B (75 min): HW3-style AXI IP package + BD + bitstream.
- Session C (45 min): Vitis bring-up + UART validation + troubleshooting drill.
- Session D (30 min): write a short report from template with screenshots.

Do at least two full cycles before the midterm.

## High-value habits

- Keep one notebook page of "known-good" Tcl snippets and base addresses.
- Screenshot early during successful runs (BD, waveform, UART output).
- After each drill, record one mistake and one prevention rule.
